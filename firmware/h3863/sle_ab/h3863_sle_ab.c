#include <stdbool.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>

#include "app_init.h"
#include "ab_protocol.h"
#include "common_def.h"
#include "pinctrl.h"
#include "soc_osal.h"
#include "tcxo.h"
#include "trng.h"
#include "uart.h"

#define AB_TASK_STACK_SIZE 0x1800
#define AB_TASK_PRIORITY 27
#define AB_UART_BAUDRATE 115200
#define AB_UART_RX_BUFFER_SIZE 256U
#define AB_CONSOLE_RING_SIZE 256U
#define AB_CONSOLE_LINE_SIZE 192U
#define AB_GATEWAY_UART_RING_SIZE 256U

static uint8_t g_uart_driver_buffer[AB_UART_RX_BUFFER_SIZE];
static uart_buffer_config_t g_uart_buffer_config = {
    .rx_buffer = g_uart_driver_buffer,
    .rx_buffer_size = sizeof(g_uart_driver_buffer)
};
static volatile uint16_t g_console_head;
static volatile uint16_t g_console_tail;
static uint8_t g_console_ring[AB_CONSOLE_RING_SIZE];
static volatile uint16_t g_gateway_uart_head;
static volatile uint16_t g_gateway_uart_tail;
static uint8_t g_gateway_uart_ring[AB_GATEWAY_UART_RING_SIZE];
static volatile bool g_gateway_uart_enabled;
static uint8_t g_uart_frame_candidate[AB_MAX_FRAME];
static uint16_t g_uart_frame_used;
static uint16_t g_uart_frame_expected;
static volatile uint32_t g_gateway_uart_overflows;

static uint32_t now_ms(void)
{
    return (uint32_t)uapi_tcxo_get_ms();
}

static uint32_t new_boot_id(void)
{
    uint32_t boot_id = 0U;
    if (uapi_drv_cipher_trng_get_random(&boot_id) == ERRCODE_SUCC && boot_id != 0U)
        return boot_id;
    return now_ms() | 1U;
}

static void console_push_byte(uint8_t byte)
{
    uint16_t next = (uint16_t)((g_console_head + 1U) % AB_CONSOLE_RING_SIZE);
    if (next == g_console_tail) return;
    g_console_ring[g_console_head] = byte;
    g_console_head = next;
}

static void console_flush_candidate(void)
{
    uint16_t i;
    for (i = 0U; i < g_uart_frame_used; ++i) console_push_byte(g_uart_frame_candidate[i]);
    g_uart_frame_used = 0U;
    g_uart_frame_expected = 0U;
}

static void gateway_queue_candidate(void)
{
    uint16_t next;
    uint16_t i;
    uint16_t free_bytes = (uint16_t)((g_gateway_uart_tail +
        AB_GATEWAY_UART_RING_SIZE - g_gateway_uart_head - 1U) % AB_GATEWAY_UART_RING_SIZE);
    if (free_bytes < g_uart_frame_used) {
        g_gateway_uart_overflows++;
    } else {
        for (i = 0U; i < g_uart_frame_used; ++i) {
            next = (uint16_t)((g_gateway_uart_head + 1U) % AB_GATEWAY_UART_RING_SIZE);
            g_gateway_uart_ring[g_gateway_uart_head] = g_uart_frame_candidate[i];
            g_gateway_uart_head = next;
        }
    }
    g_uart_frame_used = 0U;
    g_uart_frame_expected = 0U;
}

static void route_uart_byte(uint8_t byte)
{
    uint16_t payload_length;
    if (!g_gateway_uart_enabled) {
        console_push_byte(byte);
        return;
    }
    if (g_uart_frame_used == 0U) {
        if (byte == 0x53U) g_uart_frame_candidate[g_uart_frame_used++] = byte;
        else console_push_byte(byte);
        return;
    }
    if (g_uart_frame_used == 1U) {
        if (byte == 0x4CU) {
            g_uart_frame_candidate[g_uart_frame_used++] = byte;
        } else {
            console_push_byte(0x53U);
            if (byte == 0x53U) g_uart_frame_candidate[0] = byte;
            else {
                g_uart_frame_used = 0U;
                console_push_byte(byte);
            }
        }
        return;
    }
    if (g_uart_frame_used >= AB_MAX_FRAME) {
        console_flush_candidate();
        route_uart_byte(byte);
        return;
    }
    g_uart_frame_candidate[g_uart_frame_used++] = byte;
    if (g_uart_frame_used == 3U && g_uart_frame_candidate[2] != AB_PROTOCOL_VERSION) {
        console_flush_candidate();
        return;
    }
    if (g_uart_frame_used == AB_FRAME_HEADER_SIZE) {
        payload_length = (uint16_t)((uint16_t)g_uart_frame_candidate[18] |
                                    ((uint16_t)g_uart_frame_candidate[19] << 8));
        if (g_uart_frame_candidate[5] > AB_ROLE_HOST || payload_length > AB_MAX_PAYLOAD) {
            console_flush_candidate();
            return;
        }
        g_uart_frame_expected = (uint16_t)(AB_FRAME_OVERHEAD + payload_length);
    }
    if (g_uart_frame_expected != 0U && g_uart_frame_used == g_uart_frame_expected)
        gateway_queue_candidate();
}

static void console_rx_callback(const void *buffer, uint16_t length, bool error)
{
    const uint8_t *bytes = (const uint8_t *)buffer;
    uint16_t i;
    unused(error);
    if (bytes == NULL) return;
    for (i = 0; i < length; ++i) route_uart_byte(bytes[i]);
}

#if defined(CONFIG_SLE_AB_ROLE_B)
static size_t gateway_uart_read(uint8_t *buffer, size_t capacity)
{
    size_t used = 0U;
    if (buffer == NULL) return 0U;
    while (used < capacity && g_gateway_uart_tail != g_gateway_uart_head) {
        buffer[used++] = g_gateway_uart_ring[g_gateway_uart_tail];
        g_gateway_uart_tail = (uint16_t)((g_gateway_uart_tail + 1U) %
                                         AB_GATEWAY_UART_RING_SIZE);
    }
    return used;
}
#endif

static void console_init(void)
{
    uart_attr_t attr = {
        .baud_rate = AB_UART_BAUDRATE,
        .data_bits = UART_DATA_BIT_8,
        .stop_bits = UART_STOP_BIT_1,
        .parity = UART_PARITY_NONE
    };
    uart_pin_config_t pins = {
        .tx_pin = CONFIG_SLE_AB_UART_TX_PIN,
        .rx_pin = CONFIG_SLE_AB_UART_RX_PIN,
        .cts_pin = PIN_NONE,
        .rts_pin = PIN_NONE
    };
    (void)uapi_pin_set_mode(CONFIG_SLE_AB_UART_TX_PIN, PIN_MODE_1);
    (void)uapi_pin_set_mode(CONFIG_SLE_AB_UART_RX_PIN, PIN_MODE_1);
    (void)uapi_uart_deinit(CONFIG_SLE_AB_UART_BUS);
    (void)uapi_uart_init(CONFIG_SLE_AB_UART_BUS, &pins, &attr, NULL, &g_uart_buffer_config);
    (void)uapi_uart_unregister_rx_callback(CONFIG_SLE_AB_UART_BUS);
    (void)uapi_uart_register_rx_callback(CONFIG_SLE_AB_UART_BUS,
        UART_RX_CONDITION_FULL_OR_SUFFICIENT_DATA_OR_IDLE, 1, console_rx_callback);
}

static bool console_read_line(char *line, size_t capacity)
{
    static size_t used;
    size_t start;
    uint8_t byte;
    while (g_console_tail != g_console_head) {
        byte = g_console_ring[g_console_tail];
        g_console_tail = (uint16_t)((g_console_tail + 1U) % AB_CONSOLE_RING_SIZE);
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

#if defined(CONFIG_SLE_AB_ROLE_A)

#include "detector_a_auth_relay.h"
#include "detector_a_core.h"
#include "sle_errcode.h"
#include "sle_ab_dual_client.h"

static detector_a_t g_detector_a;
static detector_a_auth_relay_t g_auth_relay;

static bool a_sle_tx(const uint8_t *data, size_t length, void *user)
{
    unused(user);
    return length <= UINT16_MAX &&
           sle_ab_dual_client_send_b(data, (uint16_t)length);
}

static bool a_card_tx(const uint8_t *data, size_t length, void *user)
{
    static const char digits[] = "0123456789abcdef";
    char encoded[AB_MAX_FRAME * 2U + 1U];
    size_t i;
    unused(user);
    if (data == NULL || length == 0U || length > AB_MAX_FRAME) return false;
    if (sle_ab_dual_client_send_card(data, (uint16_t)length)) {
        osal_printk("[A] card SLE tx bytes=%u\r\n", (unsigned int)length);
        return true;
    }
#if defined(CONFIG_SLE_AB_TEST_MODE)
    /* Keep the staged serial bridge available while bringing up real Card SLE. */
    for (i = 0U; i < length; ++i) {
        encoded[i * 2U] = digits[data[i] >> 4];
        encoded[i * 2U + 1U] = digits[data[i] & 0x0FU];
    }
    encoded[length * 2U] = '\0';
    osal_printk("[A][CARD-TX] %s\r\n", encoded);
    return true;
#else
    return false;
#endif
}

static void a_auth_result(const ab_auth_result_t *result, void *user)
{
    unused(user);
    (void)detector_a_set_auth_result(&g_detector_a, result);
    osal_printk("[A] auth result session=%08x card=%08x permission=%u auth=%u "
                "reason=%u counter=%u\r\n",
                result->session_id, result->card_id, result->permission_id,
                result->auth, result->reason, result->counter);
}

static int8_t a_hex_nibble(char value)
{
    if (value >= '0' && value <= '9') return (int8_t)(value - '0');
    if (value >= 'a' && value <= 'f') return (int8_t)(value - 'a' + 10);
    if (value >= 'A' && value <= 'F') return (int8_t)(value - 'A' + 10);
    return -1;
}

static size_t a_hex_decode(const char *text, uint8_t *output, size_t capacity)
{
    size_t text_length;
    size_t i;
    if (text == NULL || output == NULL) return 0U;
    text_length = strlen(text);
    if (text_length == 0U || (text_length & 1U) != 0U || text_length / 2U > capacity)
        return 0U;
    for (i = 0U; i < text_length; i += 2U) {
        int8_t high = a_hex_nibble(text[i]);
        int8_t low = a_hex_nibble(text[i + 1U]);
        if (high < 0 || low < 0) return 0U;
        output[i / 2U] = (uint8_t)(((uint8_t)high << 4) | (uint8_t)low);
    }
    return text_length / 2U;
}

static void a_decision(const ab_decision_t *decision, void *user)
{
    unused(user);
    osal_printk("[A] decision event=%u action=%u confirm=%u exec=%u reason=%u\r\n",
        decision->event_id, decision->action, decision->confirm,
        decision->execution, decision->reason);
}

static void a_b_receive(const uint8_t *data, uint16_t length, void *user)
{
    unused(user);
    if (data == NULL || length == 0U) return;
    detector_a_receive(&g_detector_a, data, length);
    detector_a_auth_relay_receive_b(&g_auth_relay, data, length, now_ms());
}

static void a_card_receive(const uint8_t *data, uint16_t length, void *user)
{
    unused(user);
    if (data == NULL || length == 0U) return;
    detector_a_auth_relay_receive_card(&g_auth_relay, data, length, now_ms());
}

static void observe(bool seen, bool zone1, bool zone2, uint16_t distance, uint8_t confidence)
{
    passage_observation_t observation = {
        seen, zone1, zone2, distance, confidence, HW_DIRECTION_ENTER
    };
    passage_result_t result = detector_a_observe(&g_detector_a, &observation, now_ms());
    osal_printk("[A] observe state=%u result=%u sent=%u fail=%u\r\n",
        g_detector_a.passage.state, result, g_detector_a.sent_events, g_detector_a.send_failures);
}

#if defined(CONFIG_SLE_AB_TEST_MODE)
static void demo_enter(void)
{
    observe(true, false, false, 300U, 80U); osal_msleep(150);
    observe(true, true, false, 140U, 85U); osal_msleep(150);
    observe(true, true, true, 70U, 90U);
}

static void demo_reverse(void)
{
    observe(true, false, false, 250U, 80U); osal_msleep(150);
    observe(true, false, true, 120U, 85U);
}

static void demo_timeout(void)
{
    observe(true, false, false, 250U, 80U); osal_msleep(150);
    observe(true, true, false, 120U, 85U); osal_msleep(2700);
    observe(true, true, false, 120U, 85U);
}
#endif

static void a_command(const char *line)
{
#if defined(CONFIG_SLE_AB_TEST_MODE)
    if (strncmp(line, "card proto ", 11U) == 0) {
        uint8_t frame[AB_MAX_FRAME];
        size_t length = a_hex_decode(line + 11U, frame, sizeof(frame));
        if (length == 0U)
            osal_printk("[A] card proto invalid hex or frame too long\r\n");
        else {
            detector_a_auth_relay_receive_card(&g_auth_relay, frame, length, now_ms());
            osal_printk("[A] card proto accepted bytes=%u\r\n", (unsigned int)length);
        }
    } else if (strcmp(line, "demo enter") == 0) {
        osal_printk("[A] OK demo=enter\r\n");
        demo_enter();
    } else if (strcmp(line, "demo reverse") == 0) {
        osal_printk("[A] OK demo=reverse\r\n");
        demo_reverse();
    } else if (strcmp(line, "demo timeout") == 0) {
        osal_printk("[A] OK demo=timeout\r\n");
        demo_timeout();
    } else if (strcmp(line, "auth ok") == 0) {
        detector_a_set_auth(&g_detector_a, HW_AUTHORIZED);
        osal_printk("[A] OK auth=ok\r\n");
    } else if (strcmp(line, "auth deny") == 0) {
        detector_a_set_auth(&g_detector_a, HW_UNAUTHORIZED);
        osal_printk("[A] OK auth=deny\r\n");
    } else if (strcmp(line, "auth key") == 0) {
        detector_a_set_auth(&g_detector_a, HW_KEY_FAILED);
        osal_printk("[A] OK auth=key\r\n");
    } else if (strcmp(line, "auth replay") == 0) {
        detector_a_set_auth(&g_detector_a, HW_REPLAY_SUSPECTED);
        osal_printk("[A] OK auth=replay\r\n");
    } else
#endif
    if (strcmp(line, "status") == 0) {
        osal_printk("[A] state=%u auth=%u sent=%u ack=%u retry=%u exhausted=%u "
                    "pending=%u failures=%u crc=%u\r\n",
            g_detector_a.passage.state, g_detector_a.simulated_auth,
            g_detector_a.sent_events, g_detector_a.acknowledged_events,
            g_detector_a.retry_attempts, g_detector_a.retry_exhausted,
            g_detector_a.pending_active, g_detector_a.send_failures,
            g_detector_a.parser.crc_errors);
        osal_printk("[A] auth_relay challenge=%u response=%u result=%u dup=%u replay=%u "
                    "challenge_retry=%u response_retry=%u card_fail=%u b_fail=%u\r\n",
            g_auth_relay.challenges_forwarded, g_auth_relay.responses_forwarded,
            g_auth_relay.results_received, g_auth_relay.duplicate_messages,
            g_auth_relay.replay_rejections, g_auth_relay.challenge_retry_attempts,
            g_auth_relay.response_retry_attempts, g_auth_relay.card_send_failures,
            g_auth_relay.b_send_failures);
        sle_ab_dual_client_status();
    }
#if defined(CONFIG_SLE_AB_TEST_MODE)
    else osal_printk("[A] commands: demo enter|reverse|timeout, auth ok|deny|key|replay, "
                     "card proto <frame-hex>, status\r\n");
#else
    else osal_printk("[A] commands: status (test mode disabled)\r\n");
#endif
}

static void *ab_task(const char *arg)
{
    char line[AB_CONSOLE_LINE_SIZE];
    sle_ab_dual_client_callbacks_t callbacks = { 0 };
    errcode_t client_result;
    unused(arg);
    console_init();
    detector_a_init(&g_detector_a, a_sle_tx, a_decision, NULL);
    detector_a_set_identity(&g_detector_a, 0xA0000001U, new_boot_id());
    detector_a_auth_relay_init(&g_auth_relay, a_sle_tx, a_card_tx, a_auth_result, NULL);
    detector_a_auth_relay_set_identity(&g_auth_relay, g_detector_a.source_id,
                                       g_detector_a.boot_id);
    osal_printk("[A] boot: SLE client, source=%08x boot=%08x simulated card=%08x protocol=%u\r\n",
        g_detector_a.source_id, g_detector_a.boot_id, g_detector_a.card_anon_id,
        AB_PROTOCOL_VERSION);
    callbacks.b_receive = a_b_receive;
    callbacks.card_receive = a_card_receive;
    callbacks.user = NULL;
    osal_printk("[A] starting dual SLE client (core wait is 5 seconds)\r\n");
    client_result = sle_ab_dual_client_init(&callbacks);
    osal_printk("[A] dual SLE client init returned=%d\r\n", client_result);
    while (1) {
        if (console_read_line(line, sizeof(line))) a_command(line);
        detector_a_tick(&g_detector_a, now_ms());
        detector_a_auth_relay_tick(&g_auth_relay, now_ms());
        osal_msleep(20);
    }
    return NULL;
}

#elif defined(CONFIG_SLE_AB_ROLE_B)

#include "card_crypto.h"
#include "detector_b_auth.h"
#include "detector_b_core.h"
#include "detector_b_gateway.h"
#include "gpio.h"
#include "sle_errcode.h"
#include "sle_uart_server.h"
#include "sle_uart_server_adv.h"

/* Required by the official SLE UART server when it drains stale data after disconnect. */
unsigned long g_sle_uart_server_msgq_id;

static detector_b_t g_detector_b;
static detector_b_auth_t g_b_auth;
static detector_b_gateway_t g_b_gateway;
static ab_stream_parser_t g_b_auth_parser;
static uint32_t g_actuator_until_ms;
static uint32_t g_policy_organization_id;

#define SLE_AB_FIRMWARE_VERSION 0x00010002U

static bool b_auth_random(uint8_t *output, size_t length, void *user)
{
    size_t offset = 0U;
    unused(user);
    while (offset < length) {
        uint32_t value;
        size_t amount;
        if (uapi_drv_cipher_trng_get_random(&value) != ERRCODE_SUCC) return false;
        amount = length - offset;
        if (amount > sizeof(value)) amount = sizeof(value);
        (void)memcpy(&output[offset], &value, amount);
        offset += amount;
    }
    return true;
}

static bool b_sle_tx(const uint8_t *data, size_t length, void *user)
{
    unused(user);
    if (!sle_uart_server_is_connected() || length > UINT16_MAX) return false;
    return sle_uart_server_send_notification(data, (uint16_t)length) == ERRCODE_SLE_SUCCESS;
}

static bool b_gateway_tx(const uint8_t *data, size_t length, void *user)
{
    int32_t written;
    unused(user);
    if (data == NULL || length == 0U || length > UINT32_MAX) return false;
    written = uapi_uart_write(CONFIG_SLE_AB_UART_BUS, data, (uint32_t)length, 0U);
    return written == (int32_t)length;
}

static uint16_t b_policy_flags(void)
{
    uint16_t flags = 0U;
    if (g_detector_b.permission.allow_execution)
        flags |= DETECTOR_B_POLICY_ALLOW_EXECUTION;
    if (g_detector_b.permission.admin_confirm_required)
        flags |= DETECTOR_B_POLICY_ADMIN_CONFIRM;
    if (g_detector_b.policy_input.user_confirm_enabled)
        flags |= DETECTOR_B_POLICY_USER_CONFIRM;
    if (g_detector_b.permission.allow_offline)
        flags |= DETECTOR_B_POLICY_ALLOW_OFFLINE;
    if (g_detector_b.policy_input.alert_on_denial)
        flags |= DETECTOR_B_POLICY_ALERT_ON_DENIAL;
    return flags;
}

static detector_b_gateway_status_t b_gateway_apply_policy(
    const detector_b_policy_command_t *command, void *user)
{
    unused(user);
    if (command == NULL) return DETECTOR_B_GATEWAY_INVALID;
    if (g_detector_b.pending_valid) return DETECTOR_B_GATEWAY_BUSY;
    if (command->policy_version < g_detector_b.permission.policy_version)
        return DETECTOR_B_GATEWAY_STALE;
    if (command->policy_version == g_detector_b.permission.policy_version) {
        return command->permission_id == g_detector_b.permission.permission_id &&
               command->organization_id == g_policy_organization_id &&
               command->flags == b_policy_flags() ?
               DETECTOR_B_GATEWAY_OK : DETECTOR_B_GATEWAY_STALE;
    }
    g_detector_b.permission.permission_id = command->permission_id;
    g_detector_b.permission.policy_version = command->policy_version;
    g_detector_b.permission.allow_execution =
        (command->flags & DETECTOR_B_POLICY_ALLOW_EXECUTION) != 0U;
    g_detector_b.permission.admin_confirm_required =
        (command->flags & DETECTOR_B_POLICY_ADMIN_CONFIRM) != 0U;
    g_detector_b.permission.allow_offline =
        (command->flags & DETECTOR_B_POLICY_ALLOW_OFFLINE) != 0U;
    g_detector_b.policy_input.user_confirm_enabled =
        (command->flags & DETECTOR_B_POLICY_USER_CONFIRM) != 0U;
    g_detector_b.policy_input.alert_on_denial =
        (command->flags & DETECTOR_B_POLICY_ALERT_ON_DENIAL) != 0U;
    g_policy_organization_id = command->organization_id;
    osal_printk("[B][GW] policy applied request=%u version=%u permission=%u org=%u "
                "flags=%04x\r\n", command->request_id, command->policy_version,
                command->permission_id, command->organization_id, command->flags);
    return DETECTOR_B_GATEWAY_OK;
}

static detector_b_gateway_status_t b_gateway_apply_confirm(
    const detector_b_confirm_command_t *command, void *user)
{
    bool approved;
    unused(user);
    if (command == NULL || !g_detector_b.pending_valid ||
        g_detector_b.pending_event.event_id != command->event_id)
        return DETECTOR_B_GATEWAY_NOT_FOUND;
    approved = command->result == HW_CONFIRM_APPROVED;
    return detector_b_confirm(&g_detector_b, approved, now_ms()) ?
        DETECTOR_B_GATEWAY_OK : DETECTOR_B_GATEWAY_STALE;
}

static void b_gateway_online_changed(bool online, void *user)
{
    unused(user);
    g_detector_b.policy_input.backend_online = online;
    osal_printk("[B][GW] host %s\r\n", online ? "online" : "offline");
}

static bool b_send_auth_payload(uint8_t type, const uint8_t *payload, uint16_t payload_length)
{
    uint8_t frame[AB_MAX_FRAME];
    ab_frame_header_t header = { 0 };
    size_t frame_length;
    header.type = type;
    header.source_role = AB_ROLE_DETECTOR_B;
    header.source_id = g_detector_b.source_id;
    header.boot_id = g_detector_b.boot_id;
    header.message_id = g_detector_b.next_message_id++;
    frame_length = ab_frame_encode(&header, payload, payload_length, frame, sizeof(frame));
    return frame_length != 0U && b_sle_tx(frame, frame_length, NULL);
}

static void b_auth_frame(const ab_frame_t *frame, void *user)
{
    ab_auth_result_t result = { 0 };
    uint8_t payload[AB_AUTH_RESULT_PAYLOAD_SIZE];
    size_t payload_length;
    bool verified;
    unused(user);
    if (frame == NULL || frame->header.source_role != AB_ROLE_DETECTOR_A ||
        frame->header.type != AB_MSG_AUTH_RESPONSE) return;
    verified = detector_b_auth_verify(&g_b_auth, frame->payload, frame->payload_length,
                                      now_ms(), &result);
    payload_length = result.session_id == 0U ? 0U :
        ab_auth_result_encode(&result, payload, sizeof(payload));
    if (payload_length != 0U)
        (void)b_send_auth_payload(AB_MSG_AUTH_RESULT, payload, (uint16_t)payload_length);
    osal_printk("[B] auth verify=%u session=%08x card=%08x permission=%u auth=%u "
                "reason=%u counter=%u\r\n",
                verified, result.session_id, result.card_id, result.permission_id,
                result.auth, result.reason, result.counter);
}

static bool b_authorize_event(const hw_passage_event_t *event, void *user)
{
    bool granted;
    unused(user);
    if (event == NULL) return false;
    granted = detector_b_auth_consume(&g_b_auth, event->auth_session_id,
                                      event->card_anon_id, event->permission_id,
                                      event->auth_counter, now_ms());
    osal_printk("[B] auth consume=%u session=%08x card=%08x permission=%u counter=%u\r\n",
                granted, event->auth_session_id, event->card_anon_id,
                event->permission_id, event->auth_counter);
    return granted;
}

static bool b_actuator(uint32_t event_id, void *user)
{
    unused(user);
    (void)uapi_gpio_set_val(CONFIG_SLE_AB_ACTUATOR_PIN, GPIO_LEVEL_HIGH);
    g_actuator_until_ms = now_ms() + 500U;
    osal_printk("[B] actuator ON event=%u pin=%u\r\n", event_id, CONFIG_SLE_AB_ACTUATOR_PIN);
    return true;
}

static void b_report(const hw_passage_event_t *event, const ab_decision_t *decision, void *user)
{
    unused(user);
    if (!detector_b_gateway_report(&g_b_gateway, event, decision))
        osal_printk("[B][GW] report queue full event=%u\r\n", event->event_id);
    osal_printk("[B] EVENT event=%u card=%08x auth=%u session=%08x permission=%u "
                "counter=%u action=%u confirm=%u exec=%u reason=%u\r\n",
        event->event_id, event->card_anon_id, event->auth, event->auth_session_id,
        event->permission_id, event->auth_counter, decision->action,
        decision->confirm, decision->execution, decision->reason);
}

static void b_read_callback(uint8_t server_id, uint16_t conn_id,
                            ssaps_req_read_cb_t *request, errcode_t status)
{
    unused(server_id); unused(conn_id); unused(request); unused(status);
}

static void b_write_callback(uint8_t server_id, uint16_t conn_id,
                             ssaps_req_write_cb_t *request, errcode_t status)
{
    unused(server_id); unused(conn_id); unused(status);
    if (request != NULL && request->value != NULL && request->length != 0U) {
        detector_b_receive(&g_detector_b, request->value, request->length, now_ms());
        ab_parser_feed(&g_b_auth_parser, request->value, request->length);
    }
}

#if defined(CONFIG_SLE_AB_TEST_MODE)
static int8_t b_hex_nibble(char value)
{
    if (value >= '0' && value <= '9') return (int8_t)(value - '0');
    if (value >= 'a' && value <= 'f') return (int8_t)(value - 'a' + 10);
    if (value >= 'A' && value <= 'F') return (int8_t)(value - 'A' + 10);
    return -1;
}

static size_t b_hex_decode(const char *text, uint8_t *output, size_t capacity)
{
    size_t text_length;
    size_t i;
    if (text == NULL || output == NULL) return 0U;
    text_length = strlen(text);
    if (text_length == 0U || (text_length & 1U) != 0U || text_length / 2U > capacity)
        return 0U;
    for (i = 0U; i < text_length; i += 2U) {
        int8_t high = b_hex_nibble(text[i]);
        int8_t low = b_hex_nibble(text[i + 1U]);
        if (high < 0 || low < 0) return 0U;
        output[i / 2U] = (uint8_t)(((uint8_t)high << 4) | (uint8_t)low);
    }
    return text_length / 2U;
}

static void b_install_test_credential(void)
{
    detector_b_auth_credential_t credential = { 0 };
    credential.permission_id = 7U;
    credential.organization_id = 100U;
    credential.expected_card_id = 0xC0000001U;
    credential.usage_limit = 100U;
    credential.credential_version = 3U;
    credential.key_version = 2U;
    credential.state = DETECTOR_B_CREDENTIAL_ACTIVE;
    (void)memset(credential.key, 0x11, sizeof(credential.key));
    osal_printk("[B] auth test credential installed=%u permission=7 org=100 "
                "card=c0000001 key=TEST-ONLY-11x32\r\n",
                detector_b_auth_upsert(&g_b_auth, &credential));
    g_detector_b.permission.permission_id = credential.permission_id;
}

/* Install the credential that was actually provisioned onto Card C by the
 * backend write-package. The 32-byte key is passed over the local UART console
 * as hex, matching permission/org/version fields of the provisioned payload, so
 * Detector B can authenticate the real card without embedding any key in code. */
static void b_install_provisioned_credential(const char *hex)
{
    detector_b_auth_credential_t credential = { 0 };
    uint8_t key[DETECTOR_B_AUTH_KEY_SIZE];
    if (hex == NULL) return;
    if (b_hex_decode(hex, key, sizeof(key)) != DETECTOR_B_AUTH_KEY_SIZE) {
        osal_printk("[B] auth key: expected %u hex chars\r\n", DETECTOR_B_AUTH_KEY_SIZE * 2U);
        return;
    }
    credential.permission_id = 1U;
    credential.organization_id = 100U;
    credential.expected_card_id = 0xC0000001U;
    credential.usage_limit = 0xFFFFFFFFU;
    credential.credential_version = 2U;
    credential.key_version = 1U;
    credential.state = DETECTOR_B_CREDENTIAL_ACTIVE;
    (void)memcpy(credential.key, key, sizeof(credential.key));
    osal_printk("[B] auth provisioned credential installed=%u permission=1 org=100 "
                "card=c0000001 version=%u key_version=%u\r\n",
                detector_b_auth_upsert(&g_b_auth, &credential),
                credential.credential_version, credential.key_version);
    g_detector_b.permission.permission_id = credential.permission_id;
}

/* Authenticate against the provisioned permission=1 credential rather than the
 * demo permission=7 test key. Card C was provisioned with a real validity
 * window (2026-08-15..2026-12-31), so the challenge must carry a Unix time in
 * seconds inside that window. This board has no RTC; the caller supplies the
 * time on the console (auth start <unix-seconds>). */
static void b_start_provisioned_auth(const char *arg)
{
    detector_b_auth_request_t request = { 100U, 1U, 0U, 0U };
    uint8_t challenge[DETECTOR_B_AUTH_CHALLENGE_SIZE];
    ab_reason_t reason;
    bool started;
    bool sent;
    if (arg != NULL && arg[0] != '\0') {
        request.unix_time = (uint32_t)strtoul(arg, NULL, 10);
    }
    started = detector_b_auth_start(&g_b_auth, &request, now_ms(), challenge, &reason);
    sent = started && b_send_auth_payload(AB_MSG_AUTH_CHALLENGE, challenge,
                                          sizeof(challenge));
    if (started && !sent) {
        uint32_t session_id = (uint32_t)challenge[0] | ((uint32_t)challenge[1] << 8) |
                              ((uint32_t)challenge[2] << 16) |
                              ((uint32_t)challenge[3] << 24);
        detector_b_auth_cancel(&g_b_auth, session_id);
        reason = AB_REASON_LINK_LOST;
    }
    osal_printk("[B] auth start=%u sent=%u reason=%u time=%u\r\n", started, sent, reason,
                request.unix_time);
}
#endif

static void b_command(const char *line)
{
#if defined(CONFIG_SLE_AB_TEST_MODE)
    if (strcmp(line, "auth testkey") == 0) {
        b_install_test_credential();
    } else if (strncmp(line, "auth key ", 9U) == 0) {
        b_install_provisioned_credential(line + 9U);
    } else if (strncmp(line, "auth start", 10U) == 0) {
        const char *arg = line[10U] == ' ' ? line + 11U : NULL;
        b_start_provisioned_auth(arg);
    } else
#endif
    if (strcmp(line, "policy record") == 0) {
        g_detector_b.permission.allow_execution = false;
        g_detector_b.permission.admin_confirm_required = false;
        osal_printk("[B] OK policy=record execute=0 confirm=0\r\n");
    } else if (strcmp(line, "policy execute") == 0) {
        g_detector_b.permission.allow_execution = true;
        g_detector_b.permission.admin_confirm_required = false;
        osal_printk("[B] OK policy=execute execute=1 confirm=0\r\n");
    } else if (strcmp(line, "policy confirm") == 0) {
        g_detector_b.permission.allow_execution = true;
        g_detector_b.permission.admin_confirm_required = true;
        osal_printk("[B] OK policy=confirm execute=1 confirm=1\r\n");
    } else if (strcmp(line, "confirm yes") == 0) {
        osal_printk("[B] confirm result=%u\r\n", detector_b_confirm(&g_detector_b, true, now_ms()));
    } else if (strcmp(line, "confirm no") == 0) {
        osal_printk("[B] confirm result=%u\r\n", detector_b_confirm(&g_detector_b, false, now_ms()));
    } else if (strcmp(line, "online on") == 0) {
        g_detector_b.policy_input.backend_online = true;
        osal_printk("[B] OK online=1\r\n");
    } else if (strcmp(line, "online off") == 0) {
        g_detector_b.policy_input.backend_online = false;
        osal_printk("[B] OK online=0\r\n");
    }
    else if (strcmp(line, "status") == 0) {
        osal_printk("[B] rx=%u dup=%u bad=%u busy=%u pending=%u execute=%u confirm=%u "
                    "online=%u ack_fail=%u decision_fail=%u decision_retry=%u crc=%u\r\n",
            g_detector_b.received_events, g_detector_b.duplicate_events,
            g_detector_b.malformed_events, g_detector_b.busy_events, g_detector_b.pending_valid,
            g_detector_b.permission.allow_execution, g_detector_b.permission.admin_confirm_required,
            g_detector_b.policy_input.backend_online, g_detector_b.ack_send_failures,
            g_detector_b.decision_send_failures, g_detector_b.decision_retries,
            g_detector_b.parser.crc_errors);
        osal_printk("[B] auth challenge=%u success=%u consumed=%u duplicate=%u denied=%u "
                    "replay=%u expired=%u auth_crc=%u\r\n",
            g_b_auth.challenges_created, g_b_auth.successful_responses,
            g_b_auth.consumed_grants, g_b_auth.duplicate_responses, g_b_auth.denied_responses,
            g_b_auth.replay_rejections, g_b_auth.expired_sessions,
            g_b_auth_parser.crc_errors);
        osal_printk("[B][GW] host=%u queue=%u sent=%u send_fail=%u retry=%u ack=%u "
                    "unknown_ack=%u overflow=%u uart_overflow=%u cmd_bad=%u cmd_dup=%u "
                    "cmd_conflict=%u policy=%u org=%u crc=%u\r\n",
            g_b_gateway.host_online, detector_b_gateway_queue_depth(&g_b_gateway),
            g_b_gateway.frames_sent, g_b_gateway.send_failures,
            g_b_gateway.retry_attempts, g_b_gateway.acknowledgements,
            g_b_gateway.unknown_acks, g_b_gateway.queue_overflows,
            g_gateway_uart_overflows, g_b_gateway.malformed_commands,
            g_b_gateway.duplicate_commands, g_b_gateway.conflicting_commands,
            g_b_gateway.policy_version, g_policy_organization_id,
            g_b_gateway.parser.crc_errors);
    }
    else osal_printk("[B] commands: policy record|execute|confirm, confirm yes|no, "
                     "online on|off, auth testkey|key <hex64>|start [<unix-seconds>], status\r\n");
}

static void *ab_task(const char *arg)
{
    char line[AB_CONSOLE_LINE_SIZE];
    uint8_t gateway_data[AB_MAX_FRAME];
    errcode_t sle_ret;
    unused(arg);
    console_init();
    (void)uapi_pin_set_mode(CONFIG_SLE_AB_ACTUATOR_PIN, PIN_MODE_0);
    (void)uapi_gpio_set_dir(CONFIG_SLE_AB_ACTUATOR_PIN, GPIO_DIRECTION_OUTPUT);
    (void)uapi_gpio_set_val(CONFIG_SLE_AB_ACTUATOR_PIN, GPIO_LEVEL_LOW);
    detector_b_init(&g_detector_b, b_sle_tx, b_actuator, b_report, NULL);
    detector_b_set_authorizer(&g_detector_b, b_authorize_event);
    detector_b_set_identity(&g_detector_b, 0xB0000001U, new_boot_id());
    detector_b_gateway_init(&g_b_gateway, b_gateway_tx, b_gateway_apply_policy,
                            b_gateway_apply_confirm, b_gateway_online_changed, NULL);
    detector_b_gateway_set_identity(&g_b_gateway, g_detector_b.source_id,
                                    g_detector_b.boot_id, SLE_AB_FIRMWARE_VERSION);
    detector_b_gateway_set_policy_version(&g_b_gateway,
                                          g_detector_b.permission.policy_version);
    g_detector_b.policy_input.backend_online = false;
    g_gateway_uart_enabled = true;
    detector_b_auth_init(&g_b_auth, g_detector_b.source_id, b_auth_random,
                         card_hmac_sha256, NULL);
    ab_parser_init(&g_b_auth_parser, b_auth_frame, NULL);
    osal_printk("[B] boot: SLE server, source=%08x boot=%08x actuator pin=%u protocol=%u\r\n",
        g_detector_b.source_id, g_detector_b.boot_id, CONFIG_SLE_AB_ACTUATOR_PIN,
        AB_PROTOCOL_VERSION);
    (void)osal_msg_queue_create("sle_ab_srv_msgq", 4U, &g_sle_uart_server_msgq_id,
                                0U, CONFIG_SLE_UART_MSGQ_ITEM_SIZE);
    sle_ret = sle_uart_server_init(b_read_callback, b_write_callback);
    osal_printk("[B] SLE server init ret=%d\r\n", sle_ret);
    if (sle_ret == ERRCODE_SLE_SUCCESS) {
        sle_ret = sle_uart_server_adv_init();
        osal_printk("[B] SLE announce init ret=%d\r\n", sle_ret);
    }
    while (1) {
        uint32_t current = now_ms();
        size_t gateway_length = gateway_uart_read(gateway_data, sizeof(gateway_data));
        if (gateway_length != 0U)
            detector_b_gateway_receive(&g_b_gateway, gateway_data, gateway_length, current);
        if (console_read_line(line, sizeof(line))) b_command(line);
        detector_b_tick(&g_detector_b, current);
        detector_b_auth_tick(&g_b_auth, current);
        detector_b_gateway_tick(&g_b_gateway, current);
        if (g_actuator_until_ms != 0U && (int32_t)(current - g_actuator_until_ms) >= 0) {
            (void)uapi_gpio_set_val(CONFIG_SLE_AB_ACTUATOR_PIN, GPIO_LEVEL_LOW);
            g_actuator_until_ms = 0U;
            osal_printk("[B] actuator OFF\r\n");
        }
        osal_msleep(20);
    }
    return NULL;
}

#endif

static void sle_ab_entry(void)
{
    osal_task *task;
    osal_kthread_lock();
    task = osal_kthread_create((osal_kthread_handler)ab_task, NULL, "SleAbTask", AB_TASK_STACK_SIZE);
    if (task != NULL) osal_kthread_set_priority(task, AB_TASK_PRIORITY);
    osal_kthread_unlock();
}

app_run(sle_ab_entry);
