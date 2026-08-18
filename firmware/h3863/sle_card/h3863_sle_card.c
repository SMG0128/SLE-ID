#include <stdbool.h>
#include <stdint.h>
#include <string.h>

#include "ab_protocol.h"
#include "app_init.h"
#include "card_auth.h"
#include "card_service.h"
#include "common_def.h"
#include "credential_store.h"
#include "pinctrl.h"
#include "sle_errcode.h"
#include "soc_osal.h"
#include "tcxo.h"
#include "trng.h"
#include "uart.h"
#include "ws63_card_sle_server.h"

#if defined(CONFIG_SLE_CARD_STORE_NV)
#include "ws63_card_nv_port.h"
#endif

#define CARD_TASK_STACK_SIZE 0x1800U
#define CARD_TASK_PRIORITY 27U
#define CARD_COMMAND_QUEUE_DEPTH 8U
#define CARD_COMMAND_QUEUE_ITEM_SIZE 96U
#define CARD_REMOTE_WRITE_WINDOW_MS 60000U
#define CARD_STATUS_INTERVAL_MS 5000U
#define CARD_UART_BAUDRATE 115200U
#define CARD_UART_RX_BUFFER_SIZE 256U
#define CARD_CONSOLE_RING_SIZE 256U
#define CARD_CONSOLE_LINE_SIZE 192U

static unsigned long g_command_queue_id;
static card_store_t g_store;
static card_service_t g_service;
static card_authenticator_t g_auth;
static ab_stream_parser_t g_parser;
static uint32_t g_boot_id;
static uint32_t g_message_id = 1U;
static uint8_t g_uart_driver_buffer[CARD_UART_RX_BUFFER_SIZE];
static uart_buffer_config_t g_uart_buffer_config = {
    .rx_buffer = g_uart_driver_buffer,
    .rx_buffer_size = sizeof(g_uart_driver_buffer)
};
static volatile uint16_t g_console_head;
static volatile uint16_t g_console_tail;
static uint8_t g_console_ring[CARD_CONSOLE_RING_SIZE];
static bool g_console_response_mode;
static uint32_t g_remote_write_until_ms;

static uint8_t card_capabilities(void)
{
    uint8_t flags = CARD_CAP_ATOMIC_USAGE_COUNTER;
#if defined(CONFIG_SLE_CARD_STORE_NV)
    flags |= CARD_CAP_PERSISTENT_STORE;
#endif
#if defined(CONFIG_SLE_CARD_SERIAL_PROVISIONING)
    flags |= CARD_CAP_SERIAL_PROVISIONING;
#endif
    return flags;
}

#if defined(CONFIG_SLE_CARD_STORE_RAM)
typedef struct {
    uint8_t slots[CARD_STORE_SLOT_COUNT][CARD_STORE_SLOT_SIZE];
    bool present[CARD_STORE_SLOT_COUNT];
} ram_store_t;

static ram_store_t g_ram_store;

static bool ram_read(uint8_t slot, uint8_t *data, size_t length, void *user)
{
    ram_store_t *store = (ram_store_t *)user;
    if (slot >= CARD_STORE_SLOT_COUNT || length != CARD_STORE_SLOT_SIZE ||
        !store->present[slot]) return false;
    (void)memcpy(data, store->slots[slot], length);
    return true;
}

static bool ram_write(uint8_t slot, const uint8_t *data, size_t length, void *user)
{
    ram_store_t *store = (ram_store_t *)user;
    if (slot >= CARD_STORE_SLOT_COUNT || length != CARD_STORE_SLOT_SIZE) return false;
    (void)memcpy(store->slots[slot], data, length);
    store->present[slot] = true;
    return true;
}
#endif

static uint32_t now_ms(void)
{
    return (uint32_t)uapi_tcxo_get_ms();
}

static bool remote_write_armed(void)
{
    return g_remote_write_until_ms != 0U &&
           (int32_t)(g_remote_write_until_ms - now_ms()) > 0;
}

static uint32_t new_boot_id(void)
{
    uint32_t value = 0U;
    if (uapi_drv_cipher_trng_get_random(&value) == ERRCODE_SUCC && value != 0U) return value;
    return now_ms() | 1U;
}

static void write_u32(uint8_t *output, uint32_t value)
{
    output[0] = (uint8_t)value;
    output[1] = (uint8_t)(value >> 8);
    output[2] = (uint8_t)(value >> 16);
    output[3] = (uint8_t)(value >> 24);
}

static void console_rx_callback(const void *buffer, uint16_t length, bool error)
{
    const uint8_t *bytes = (const uint8_t *)buffer;
    uint16_t i;
    unused(error);
    if (bytes == NULL) return;
    for (i = 0U; i < length; ++i) {
        uint16_t next = (uint16_t)((g_console_head + 1U) % CARD_CONSOLE_RING_SIZE);
        if (next == g_console_tail) break;
        g_console_ring[g_console_head] = bytes[i];
        g_console_head = next;
    }
}

static void console_init(void)
{
    uart_attr_t attr = {
        .baud_rate = CARD_UART_BAUDRATE,
        .data_bits = UART_DATA_BIT_8,
        .stop_bits = UART_STOP_BIT_1,
        .parity = UART_PARITY_NONE
    };
    uart_pin_config_t pins = {
        .tx_pin = CONFIG_SLE_CARD_UART_TX_PIN,
        .rx_pin = CONFIG_SLE_CARD_UART_RX_PIN,
        .cts_pin = PIN_NONE,
        .rts_pin = PIN_NONE
    };
    (void)uapi_pin_set_mode(CONFIG_SLE_CARD_UART_TX_PIN, PIN_MODE_1);
    (void)uapi_pin_set_mode(CONFIG_SLE_CARD_UART_RX_PIN, PIN_MODE_1);
    (void)uapi_uart_deinit(CONFIG_SLE_CARD_UART_BUS);
    (void)uapi_uart_init(CONFIG_SLE_CARD_UART_BUS, &pins, &attr, NULL,
                         &g_uart_buffer_config);
    (void)uapi_uart_unregister_rx_callback(CONFIG_SLE_CARD_UART_BUS);
    (void)uapi_uart_register_rx_callback(CONFIG_SLE_CARD_UART_BUS,
        UART_RX_CONDITION_FULL_OR_SUFFICIENT_DATA_OR_IDLE, 1U, console_rx_callback);
}

static bool console_read_line(char *line, size_t capacity)
{
    static size_t used;
    size_t start;
    uint8_t byte;
    while (g_console_tail != g_console_head) {
        byte = g_console_ring[g_console_tail];
        g_console_tail = (uint16_t)((g_console_tail + 1U) % CARD_CONSOLE_RING_SIZE);
        if (byte == '\b' || byte == 0x7FU) {
            if (used != 0U) used--;
            continue;
        }
        if (byte == '\r' || byte == '\n') {
            while (used != 0U && (line[used - 1U] == ' ' || line[used - 1U] == '\t')) used--;
            start = 0U;
            while (start < used && (line[start] == ' ' || line[start] == '\t')) start++;
            if (start != 0U && start < used) (void)memmove(line, line + start, used - start);
            used -= start;
            if (used == 0U) continue;
            line[used] = '\0';
            used = 0U;
            return true;
        }
        if (used + 1U < capacity) line[used++] = (char)byte;
    }
    return false;
}

#if defined(CONFIG_SLE_CARD_SERIAL_PROVISIONING)
static int8_t hex_nibble(char value)
{
    if (value >= '0' && value <= '9') return (int8_t)(value - '0');
    if (value >= 'a' && value <= 'f') return (int8_t)(value - 'a' + 10);
    if (value >= 'A' && value <= 'F') return (int8_t)(value - 'A' + 10);
    return -1;
}

static size_t hex_decode(const char *text, uint8_t *output, size_t capacity)
{
    size_t text_length;
    size_t i;
    if (text == NULL || output == NULL) return 0U;
    text_length = strlen(text);
    if (text_length == 0U || (text_length & 1U) != 0U || text_length / 2U > capacity)
        return 0U;
    for (i = 0U; i < text_length; i += 2U) {
        int8_t high = hex_nibble(text[i]);
        int8_t low = hex_nibble(text[i + 1U]);
        if (high < 0 || low < 0) return 0U;
        output[i / 2U] = (uint8_t)(((uint8_t)high << 4) | (uint8_t)low);
    }
    return text_length / 2U;
}
#endif

static void print_protocol_frame(const uint8_t *frame, size_t length)
{
    static const char digits[] = "0123456789abcdef";
    char encoded[AB_MAX_FRAME * 2U + 1U];
    size_t i;
    if (frame == NULL || length == 0U || length > AB_MAX_FRAME) return;
    for (i = 0U; i < length; ++i) {
        encoded[i * 2U] = digits[frame[i] >> 4];
        encoded[i * 2U + 1U] = digits[frame[i] & 0x0FU];
    }
    encoded[length * 2U] = '\0';
    osal_printk("[C][PROTO] %s\r\n", encoded);
}

static size_t make_frame(uint8_t message_type, uint8_t flags, const uint8_t *payload,
                         uint16_t payload_length, uint8_t *output, size_t capacity)
{
    ab_frame_header_t header = { 0 };
    header.type = message_type;
    header.flags = flags;
    header.source_role = AB_ROLE_CARD;
    header.source_id = CONFIG_SLE_CARD_ID;
    header.boot_id = g_boot_id;
    header.message_id = g_message_id++;
    return ab_frame_encode(&header, payload, payload_length, output, capacity);
}

static bool send_service_response(uint8_t message_type, uint8_t flags,
                                  const uint8_t *payload, uint16_t payload_length,
                                  void *user)
{
    uint8_t frame[AB_MAX_FRAME];
    size_t length;
    unused(user);
    length = make_frame(message_type, flags, payload, payload_length, frame, sizeof(frame));
    if (length != 0U && g_console_response_mode) {
        print_protocol_frame(frame, length);
        return true;
    }
    return length != 0U && length <= UINT16_MAX &&
           ws63_card_sle_send_response(frame, (uint16_t)length) == ERRCODE_SLE_SUCCESS;
}

static void console_command(const char *line)
{
    if (strcmp(line, "status") == 0) {
        osal_printk("[C] card=%08x count=%u generation=%u caps=%02x connected=%u commands=%u "
                    "bad=%u dup=%u send_fail=%u crc=%u format=%u\r\n",
                    CONFIG_SLE_CARD_ID, g_store.credential_count, g_store.generation,
                    card_capabilities(), ws63_card_sle_is_connected(),
                    g_service.commands_received,
                    g_service.malformed_commands, g_service.duplicate_requests,
                    g_service.send_failures, g_parser.crc_errors, g_parser.format_errors);
        osal_printk("[C] auth rx=%u ok=%u deny=%u dup=%u replay=%u commits=%u "
                    "store_fail=%u send_fail=%u\r\n",
                    g_auth.challenges_received, g_auth.successful_responses,
                    g_auth.denied_responses, g_auth.duplicate_challenges,
                    g_auth.replay_rejections, g_auth.usage_commits,
                    g_auth.store_failures, g_auth.send_failures);
        return;
    }
#if defined(CONFIG_SLE_CARD_SERIAL_PROVISIONING)
    if (strcmp(line, "write unlock") == 0) {
        g_remote_write_until_ms = now_ms() + CARD_REMOTE_WRITE_WINDOW_MS;
        osal_printk("[C] remote write armed for %u ms; disconnect or commit closes window\r\n",
                    CARD_REMOTE_WRITE_WINDOW_MS);
        return;
    }
    if (strncmp(line, "proto ", 6U) == 0) {
        uint8_t frame[AB_MAX_FRAME];
        size_t length = hex_decode(line + 6U, frame, sizeof(frame));
        uint32_t old_crc = g_parser.crc_errors;
        uint32_t old_format = g_parser.format_errors;
        if (length == 0U) {
            osal_printk("[C][PROTO-ERROR] invalid hex or frame too long\r\n");
            return;
        }
        g_console_response_mode = true;
        ab_parser_feed(&g_parser, frame, length);
        g_console_response_mode = false;
        if (g_parser.crc_errors != old_crc || g_parser.format_errors != old_format)
            osal_printk("[C][PROTO-ERROR] rejected crc=%u format=%u\r\n",
                        g_parser.crc_errors, g_parser.format_errors);
        return;
    }
#endif
    osal_printk("[C] commands: status"
#if defined(CONFIG_SLE_CARD_SERIAL_PROVISIONING)
                ", write unlock, proto <Protocol-V2-frame-hex>"
#endif
                "\r\n");
}

static uint16_t build_info_value(uint8_t *output, uint16_t capacity)
{
    uint8_t payload[CARD_SERVICE_INFO_SIZE] = { 0U };
    size_t length;
    if (capacity < AB_FRAME_OVERHEAD + sizeof(payload)) return 0U;
    payload[0] = CARD_SERVICE_PROTOCOL_VERSION;
    payload[1] = CARD_MAX_CREDENTIALS;
    payload[2] = g_store.credential_count;
    payload[3] = card_capabilities();
    write_u32(&payload[4], CONFIG_SLE_CARD_ID);
    write_u32(&payload[8], CONFIG_SLE_CARD_FIRMWARE_VERSION);
    write_u32(&payload[12], g_store.generation);
    length = make_frame(AB_MSG_CARD_INFO, AB_FLAG_RESPONSE, payload, sizeof(payload),
                        output, capacity);
    return (uint16_t)length;
}

static uint16_t build_status_value(uint8_t *output, uint16_t capacity)
{
    uint8_t payload[16] = { 0U };
    size_t length;
    payload[0] = CARD_SERVICE_PROTOCOL_VERSION;
    payload[1] = g_store.credential_count;
    payload[2] = g_service.transaction.active ? 1U : 0U;
    payload[3] = ws63_card_sle_is_connected() ? 1U : 0U;
    write_u32(&payload[4], g_store.generation);
    write_u32(&payload[8], g_service.commands_received);
    write_u32(&payload[12], g_service.malformed_commands);
    length = make_frame(AB_MSG_HEARTBEAT, AB_FLAG_RESPONSE, payload, sizeof(payload),
                        output, capacity);
    return (uint16_t)length;
}

static uint16_t read_property(uint16_t property_handle, uint8_t *output,
                              uint16_t capacity, void *user)
{
    unused(user);
    /* Accept both the assigned attribute handle (SSAP read path) and the short
     * UUID value (registration-time initial value seeding). */
    if (property_handle == ws63_card_sle_info_handle() ||
        property_handle == WS63_CARD_INFO_UUID)
        return build_info_value(output, capacity);
    if (property_handle == ws63_card_sle_status_handle() ||
        property_handle == WS63_CARD_STATUS_UUID)
        return build_status_value(output, capacity);
    return 0U;
}

static bool queue_command(const uint8_t *data, uint16_t length, void *user)
{
    unused(user);
    if (data == NULL || length == 0U || length > CARD_COMMAND_QUEUE_ITEM_SIZE) return false;
    return osal_msg_queue_write_copy(g_command_queue_id, (void *)data, length, 0U) == OSAL_SUCCESS;
}

static void connection_changed(bool connected, void *user)
{
    unused(user);
    if (!connected) {
        card_service_abort_transaction(&g_service);
        g_remote_write_until_ms = 0U;
    }
}

static void frame_received(const ab_frame_t *frame, void *user)
{
    unused(user);
    if (frame == NULL) {
        g_service.malformed_commands++;
        return;
    }
    if (frame->header.type == AB_MSG_AUTH_CHALLENGE) {
        if (frame->header.source_role != AB_ROLE_DETECTOR_A) {
            g_service.malformed_commands++;
            return;
        }
        card_auth_status_t auth_result = card_auth_handle_challenge(
            &g_auth, frame->payload, frame->payload_length);
        if (auth_result == CARD_AUTH_INTERNAL || auth_result == CARD_AUTH_BAD_CHALLENGE)
            osal_printk("[C] auth transport_result=%u\r\n", auth_result);
    } else if (frame->header.source_role == AB_ROLE_HOST &&
               (g_console_response_mode ||
                (ws63_card_sle_is_connected() && remote_write_armed()))) {
        card_service_status_t result = card_service_handle_command(
            &g_service, frame->header.type, frame->payload, frame->payload_length);
        if (!g_console_response_mode && frame->header.type == AB_MSG_CREDENTIAL_COMMIT)
            g_remote_write_until_ms = 0U;
        if (result != CARD_SERVICE_OK)
            osal_printk("[C] command type=%u transport_result=%u\r\n",
                        frame->header.type, result);
    } else {
        g_service.malformed_commands++;
        osal_printk("[C] rejected remote management type=%u role=%u\r\n",
                    frame->header.type, frame->header.source_role);
    }
}

static bool init_store(void)
{
    card_store_backend_t backend = { 0 };
    card_store_result_t result;
#if defined(CONFIG_SLE_CARD_STORE_NV)
    static ws63_card_nv_context_t nv_context;
    if (!ws63_card_nv_backend_init(&backend, &nv_context,
                                   CONFIG_SLE_CARD_NV_SLOT_A_KEY,
                                   CONFIG_SLE_CARD_NV_SLOT_B_KEY)) {
        osal_printk("[C] REFUSED: NV keys must be distinct and inside 0x5c00-0x5cff\r\n");
        return false;
    }
    osal_printk("[C] persistent NV store slots=%04x/%04x size=%u\r\n",
                CONFIG_SLE_CARD_NV_SLOT_A_KEY, CONFIG_SLE_CARD_NV_SLOT_B_KEY,
                CARD_STORE_SLOT_SIZE);
#else
    (void)memset(&g_ram_store, 0, sizeof(g_ram_store));
    backend.read_slot = ram_read;
    backend.write_slot = ram_write;
    backend.user = &g_ram_store;
    osal_printk("[C] WARNING: volatile RAM credential store; reset clears credentials\r\n");
#endif
    result = card_store_init(&g_store, &backend);
    if (result != CARD_STORE_OK) {
        osal_printk("[C] credential store init failed=%u\r\n", result);
        return false;
    }
    return true;
}

static void *card_task(const char *argument)
{
    uint8_t command[CARD_COMMAND_QUEUE_ITEM_SIZE];
    uint8_t status_frame[AB_MAX_FRAME];
    char console_line[CARD_CONSOLE_LINE_SIZE];
    uint32_t next_status;
    ws63_card_sle_callbacks_t callbacks = { 0 };
    errcode_t result;
    unused(argument);
    g_boot_id = new_boot_id();
    if (!init_store()) return NULL;
    card_service_init(&g_service, &g_store, CONFIG_SLE_CARD_ID,
                      CONFIG_SLE_CARD_FIRMWARE_VERSION, send_service_response, NULL);
    card_service_set_capabilities(&g_service, card_capabilities());
    card_auth_init(&g_auth, &g_store, CONFIG_SLE_CARD_ID, g_boot_id,
                   send_service_response, NULL);
    ab_parser_init(&g_parser, frame_received, NULL);
    console_init();
    if (osal_msg_queue_create("sle_card_cmd", CARD_COMMAND_QUEUE_DEPTH,
                              &g_command_queue_id, 0U,
                              CARD_COMMAND_QUEUE_ITEM_SIZE) != OSAL_SUCCESS) {
        osal_printk("[C] command queue create failed\r\n");
        return NULL;
    }
    callbacks.command = queue_command;
    callbacks.read = read_property;
    callbacks.connection = connection_changed;
    result = ws63_card_sle_server_init(&callbacks);
    osal_printk("[C] boot card=%08x boot=%08x protocol=%u service_init=%d\r\n",
                CONFIG_SLE_CARD_ID, g_boot_id, AB_PROTOCOL_VERSION, result);
#if defined(CONFIG_SLE_CARD_SERIAL_PROVISIONING)
    osal_printk("[C] WARNING: local serial provisioning is enabled\r\n");
#endif
    if (result != ERRCODE_SLE_SUCCESS) return NULL;
    result = ws63_card_sle_start_advertising();
    osal_printk("[C] advertising result=%d\r\n", result);
    next_status = now_ms() + CARD_STATUS_INTERVAL_MS;
    while (1) {
        uint32_t length = sizeof(command);
        uint32_t current;
        if (osal_msg_queue_read_copy(g_command_queue_id, command, &length, 20U) == OSAL_SUCCESS)
            ab_parser_feed(&g_parser, command, length);
        if (console_read_line(console_line, sizeof(console_line)))
            console_command(console_line);
        current = now_ms();
        if (ws63_card_sle_is_connected() && (int32_t)(current - next_status) >= 0) {
            uint16_t status_length = build_status_value(status_frame, sizeof(status_frame));
            if (status_length != 0U)
                (void)ws63_card_sle_send_status(status_frame, status_length);
            next_status = current + CARD_STATUS_INTERVAL_MS;
        }
    }
    return NULL;
}

static void sle_card_entry(void)
{
    osal_task *task;
    osal_kthread_lock();
    task = osal_kthread_create((osal_kthread_handler)card_task, NULL,
                               "SleCardTask", CARD_TASK_STACK_SIZE);
    if (task != NULL) osal_kthread_set_priority(task, CARD_TASK_PRIORITY);
    osal_kthread_unlock();
}

app_run(sle_card_entry);
