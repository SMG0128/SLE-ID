#include "sle_ab_dual_client.h"

#include <string.h>

#include "common_def.h"
#include "securec.h"
#include "sle_connection_manager.h"
#include "sle_device_discovery.h"
#include "sle_errcode.h"
#include "sle_ssap_client.h"
#include "sle_ssap_stru.h"
#include "soc_osal.h"
#include "ws63_card_sle_server.h"

#define DUAL_LOG "[A][dual]"
#define DUAL_CLIENT_ID 0U
#define DUAL_WAIT_CORE_MS 5000U
#define DUAL_SEEK_INTERVAL 100U
#define DUAL_SEEK_WINDOW 100U
#define DUAL_MTU_SIZE CONFIG_SLE_UART_MTU_SIZE
#define CARD_UUID_VALUE_INDEX 14U

typedef enum {
    DUAL_ROLE_NONE = 0,
    DUAL_ROLE_B,
    DUAL_ROLE_CARD
} dual_role_t;

typedef struct {
    sle_addr_t addr;
    uint16_t conn_id;
    uint16_t write_handle;
    uint16_t response_handle;
    bool address_valid;
    bool connected;
    bool paired;
    bool ready;
} dual_endpoint_t;

static sle_ab_dual_client_callbacks_t g_callbacks;
static dual_endpoint_t g_b;
static dual_endpoint_t g_card;
static dual_role_t g_pending_role;
static bool g_seeking;
static sle_announce_seek_callbacks_t g_seek_callbacks;
static sle_connection_callbacks_t g_connection_callbacks;
static ssapc_callbacks_t g_ssap_callbacks;

static bool data_contains(const uint8_t *data, uint8_t length, const char *needle)
{
    size_t needle_length;
    uint8_t i;
    if (data == NULL || needle == NULL) return false;
    needle_length = strlen(needle);
    if (needle_length == 0U || needle_length > length) return false;
    for (i = 0U; (size_t)i + needle_length <= length; ++i) {
        if (memcmp(&data[i], needle, needle_length) == 0) return true;
    }
    return false;
}

static bool addr_equal(const sle_addr_t *left, const sle_addr_t *right)
{
    return left != NULL && right != NULL && left->type == right->type &&
           memcmp(left->addr, right->addr, SLE_ADDR_LEN) == 0;
}

static dual_endpoint_t *endpoint_for_role(dual_role_t role)
{
    if (role == DUAL_ROLE_B) return &g_b;
    if (role == DUAL_ROLE_CARD) return &g_card;
    return NULL;
}

static dual_endpoint_t *endpoint_for_conn(uint16_t conn_id, dual_role_t *role)
{
    if (g_b.connected && g_b.conn_id == conn_id) {
        if (role != NULL) *role = DUAL_ROLE_B;
        return &g_b;
    }
    if (g_card.connected && g_card.conn_id == conn_id) {
        if (role != NULL) *role = DUAL_ROLE_CARD;
        return &g_card;
    }
    if (role != NULL) *role = DUAL_ROLE_NONE;
    return NULL;
}

static void start_seek_if_needed(void)
{
    sle_seek_param_t parameter = { 0 };
    errcode_t result;
    if (g_seeking || g_pending_role != DUAL_ROLE_NONE ||
        (g_b.ready && g_card.ready)) return;
    parameter.own_addr_type = 0U;
    parameter.filter_duplicates = 0U;
    parameter.seek_filter_policy = 0U;
    parameter.seek_phys = 1U;
    parameter.seek_type[0] = 1U;
    parameter.seek_interval[0] = DUAL_SEEK_INTERVAL;
    parameter.seek_window[0] = DUAL_SEEK_WINDOW;
    result = sle_set_seek_param(&parameter);
    if (result == ERRCODE_SLE_SUCCESS) result = sle_start_seek();
    if (result == ERRCODE_SLE_SUCCESS) {
        g_seeking = true;
        osal_printk("%s seeking target=%s\r\n", DUAL_LOG,
                    !g_b.ready ? "B" : "Card");
    } else {
        osal_printk("%s seek start failed=%d\r\n", DUAL_LOG, result);
    }
}

static void seek_enable_callback(errcode_t status)
{
    if (status != ERRCODE_SLE_SUCCESS) {
        g_seeking = false;
        osal_printk("%s seek enable failed=%d\r\n", DUAL_LOG, status);
    }
}

static void seek_result_callback(sle_seek_result_info_t *result)
{
    dual_role_t role = DUAL_ROLE_NONE;
    dual_endpoint_t *endpoint;
    if (result == NULL || result->data == NULL || !g_seeking) return;
    if (!g_b.ready && data_contains(result->data, result->data_length, "uart_server"))
        role = DUAL_ROLE_B;
    else if (g_b.ready && !g_card.ready &&
             data_contains(result->data, result->data_length, "sle_card"))
        role = DUAL_ROLE_CARD;
    if (role == DUAL_ROLE_NONE) return;
    endpoint = endpoint_for_role(role);
    if (endpoint == NULL || memcpy_s(&endpoint->addr, sizeof(endpoint->addr),
                                     &result->addr, sizeof(result->addr)) != EOK) return;
    endpoint->address_valid = true;
    g_pending_role = role;
    osal_printk("%s found %s, stopping seek\r\n", DUAL_LOG,
                role == DUAL_ROLE_B ? "B" : "Card");
    (void)sle_stop_seek();
}

static void seek_disable_callback(errcode_t status)
{
    dual_endpoint_t *endpoint = endpoint_for_role(g_pending_role);
    dual_role_t role = g_pending_role;
    g_seeking = false;
    if (status != ERRCODE_SLE_SUCCESS || endpoint == NULL || !endpoint->address_valid) {
        osal_printk("%s seek stop failed=%d role=%u\r\n", DUAL_LOG, status, role);
        g_pending_role = DUAL_ROLE_NONE;
        start_seek_if_needed();
        return;
    }
    (void)sle_remove_paired_remote_device(&endpoint->addr);
    status = sle_connect_remote_device(&endpoint->addr);
    osal_printk("%s connect %s result=%d\r\n", DUAL_LOG,
                role == DUAL_ROLE_B ? "B" : "Card", status);
    if (status != ERRCODE_SLE_SUCCESS) {
        g_pending_role = DUAL_ROLE_NONE;
        start_seek_if_needed();
    }
}

static void read_rssi_callback(uint16_t conn_id, int8_t rssi, errcode_t status)
{
    unused(conn_id);
    if (status != ERRCODE_SLE_SUCCESS) return;
    if (g_callbacks.card_rssi != NULL) g_callbacks.card_rssi(rssi);
}

static void exchange_and_discover(dual_endpoint_t *endpoint, dual_role_t role)
{
    ssap_exchange_info_t info = { 0 };
    errcode_t result;
    if (endpoint == NULL || !endpoint->connected) return;
    info.mtu_size = DUAL_MTU_SIZE;
    info.version = 1U;
    result = ssapc_exchange_info_req(DUAL_CLIENT_ID, endpoint->conn_id, &info);
    osal_printk("%s exchange %s conn=%u result=%d\r\n", DUAL_LOG,
                role == DUAL_ROLE_B ? "B" : "Card", endpoint->conn_id, result);
}

static void connection_state_callback(uint16_t conn_id, const sle_addr_t *addr,
                                      sle_acb_state_t state, sle_pair_state_t pair_state,
                                      sle_disc_reason_t reason)
{
    dual_endpoint_t *endpoint = NULL;
    dual_role_t role = DUAL_ROLE_NONE;
    unused(reason);
    if (state == SLE_ACB_STATE_CONNECTED) {
        if (g_pending_role != DUAL_ROLE_NONE) {
            endpoint = endpoint_for_role(g_pending_role);
            role = g_pending_role;
        } else if (addr_equal(addr, &g_b.addr)) {
            endpoint = &g_b;
            role = DUAL_ROLE_B;
        } else if (addr_equal(addr, &g_card.addr)) {
            endpoint = &g_card;
            role = DUAL_ROLE_CARD;
        }
        if (endpoint == NULL) {
            osal_printk("%s ignored unknown connection=%u\r\n", DUAL_LOG, conn_id);
            return;
        }
        endpoint->conn_id = conn_id;
        endpoint->connected = true;
        endpoint->paired = pair_state == SLE_PAIR_PAIRED;
        endpoint->ready = false;
        endpoint->write_handle = 0U;
        endpoint->response_handle = 0U;
        g_pending_role = DUAL_ROLE_NONE;
        osal_printk("%s connected %s conn=%u pair=%u\r\n", DUAL_LOG,
                    role == DUAL_ROLE_B ? "B" : "Card", conn_id, pair_state);
        if (endpoint->paired) exchange_and_discover(endpoint, role);
        else (void)sle_pair_remote_device(&endpoint->addr);
        return;
    }
    if (state != SLE_ACB_STATE_DISCONNECTED) return;
    endpoint = endpoint_for_conn(conn_id, &role);
    if (endpoint == NULL) return;
    osal_printk("%s disconnected %s conn=%u\r\n", DUAL_LOG,
                role == DUAL_ROLE_B ? "B" : "Card", conn_id);
    endpoint->conn_id = 0U;
    endpoint->connected = false;
    endpoint->paired = false;
    endpoint->ready = false;
    endpoint->write_handle = 0U;
    endpoint->response_handle = 0U;
    (void)sle_remove_paired_remote_device(&endpoint->addr);
    start_seek_if_needed();
}

static void pair_complete_callback(uint16_t conn_id, const sle_addr_t *addr, errcode_t status)
{
    dual_role_t role;
    dual_endpoint_t *endpoint = endpoint_for_conn(conn_id, &role);
    unused(addr);
    if (endpoint == NULL) return;
    osal_printk("%s pair %s conn=%u status=%d\r\n", DUAL_LOG,
                role == DUAL_ROLE_B ? "B" : "Card", conn_id, status);
    if (status == ERRCODE_SLE_SUCCESS) {
        endpoint->paired = true;
        exchange_and_discover(endpoint, role);
    } else {
        (void)sle_disconnect_remote_device(&endpoint->addr);
    }
}

static void exchange_info_callback(uint8_t client_id, uint16_t conn_id,
                                   ssap_exchange_info_t *info, errcode_t status)
{
    ssapc_find_structure_param_t find = { 0 };
    dual_role_t role;
    dual_endpoint_t *endpoint = endpoint_for_conn(conn_id, &role);
    unused(client_id);
    unused(info);
    if (endpoint == NULL || status != ERRCODE_SLE_SUCCESS) {
        osal_printk("%s exchange callback conn=%u status=%d\r\n", DUAL_LOG,
                    conn_id, status);
        return;
    }
    find.type = SSAP_FIND_TYPE_PROPERTY;
    find.start_hdl = 1U;
    find.end_hdl = 0xFFFFU;
    status = ssapc_find_structure(DUAL_CLIENT_ID, conn_id, &find);
    osal_printk("%s discover %s conn=%u result=%d\r\n", DUAL_LOG,
                role == DUAL_ROLE_B ? "B" : "Card", conn_id, status);
}

static void find_structure_callback(uint8_t client_id, uint16_t conn_id,
                                    ssapc_find_service_result_t *service,
                                    errcode_t status)
{
    unused(client_id);
    unused(conn_id);
    unused(service);
    unused(status);
}

static uint16_t property_uuid_value(const ssapc_find_property_result_t *property)
{
    if (property == NULL) return 0U;
    return (uint16_t)((uint16_t)property->uuid.uuid[CARD_UUID_VALUE_INDEX] |
                      ((uint16_t)property->uuid.uuid[CARD_UUID_VALUE_INDEX + 1U] << 8));
}

static void find_property_callback(uint8_t client_id, uint16_t conn_id,
                                   ssapc_find_property_result_t *property,
                                   errcode_t status)
{
    dual_role_t role;
    dual_endpoint_t *endpoint = endpoint_for_conn(conn_id, &role);
    uint16_t uuid_value;
    unused(client_id);
    if (endpoint == NULL || property == NULL || status != ERRCODE_SLE_SUCCESS) return;
    if (role == DUAL_ROLE_B) {
        if ((property->operate_indication & (SSAP_OPERATE_INDICATION_BIT_WRITE |
                                             SSAP_OPERATE_INDICATION_BIT_WRITE_NO_RSP)) != 0U)
            endpoint->write_handle = property->handle;
        return;
    }
    uuid_value = property_uuid_value(property);
    if (uuid_value == WS63_CARD_COMMAND_UUID) endpoint->write_handle = property->handle;
    else if (uuid_value == WS63_CARD_RESPONSE_UUID)
        endpoint->response_handle = property->handle;
}

static void find_complete_callback(uint8_t client_id, uint16_t conn_id,
                                   ssapc_find_structure_result_t *result,
                                   errcode_t status)
{
    dual_role_t role;
    dual_endpoint_t *endpoint = endpoint_for_conn(conn_id, &role);
    unused(client_id);
    unused(result);
    if (endpoint == NULL) return;
    endpoint->ready = status == ERRCODE_SLE_SUCCESS && endpoint->write_handle != 0U &&
        (role == DUAL_ROLE_B || endpoint->response_handle != 0U);
    osal_printk("%s ready %s=%u conn=%u write=%u response=%u status=%d\r\n", DUAL_LOG,
                role == DUAL_ROLE_B ? "B" : "Card", endpoint->ready,
                conn_id, endpoint->write_handle, endpoint->response_handle, status);
    if (role == DUAL_ROLE_B && endpoint->ready)
        osal_printk("[sle uart client] === bridge ready ===\r\n");
    start_seek_if_needed();
}

static void notification_callback(uint8_t client_id, uint16_t conn_id,
                                  ssapc_handle_value_t *data, errcode_t status)
{
    dual_role_t role;
    dual_endpoint_t *endpoint = endpoint_for_conn(conn_id, &role);
    unused(client_id);
    if (endpoint == NULL || data == NULL || data->data == NULL || data->data_len == 0U ||
        status != ERRCODE_SLE_SUCCESS) return;
    if (role == DUAL_ROLE_B && g_callbacks.b_receive != NULL) {
        g_callbacks.b_receive(data->data, data->data_len, g_callbacks.user);
    } else if (role == DUAL_ROLE_CARD && data->handle == endpoint->response_handle &&
               g_callbacks.card_receive != NULL) {
        g_callbacks.card_receive(data->data, data->data_len, g_callbacks.user);
    }
}

static void write_confirm_callback(uint8_t client_id, uint16_t conn_id,
                                   ssapc_write_result_t *result, errcode_t status)
{
    unused(client_id);
    unused(conn_id);
    unused(result);
    if (status != ERRCODE_SLE_SUCCESS)
        osal_printk("%s write confirmation failed conn=%u status=%d\r\n",
                    DUAL_LOG, conn_id, status);
}

static void dual_sle_enable_callback(errcode_t status)
{
    osal_printk("%s SLE enabled status=%d\r\n", DUAL_LOG, status);
    if (status == ERRCODE_SLE_SUCCESS) start_seek_if_needed();
}

static bool send_endpoint(dual_endpoint_t *endpoint, const uint8_t *data, uint16_t length)
{
    ssapc_write_param_t write = { 0 };
    if (endpoint == NULL || !endpoint->ready || data == NULL || length == 0U) return false;
    write.handle = endpoint->write_handle;
    write.type = SSAP_PROPERTY_TYPE_VALUE;
    write.data_len = length;
    write.data = (uint8_t *)data;
    return ssapc_write_req(DUAL_CLIENT_ID, endpoint->conn_id, &write) ==
           ERRCODE_SLE_SUCCESS;
}

errcode_t sle_ab_dual_client_init(const sle_ab_dual_client_callbacks_t *callbacks)
{
    errcode_t result;
    if (callbacks == NULL || callbacks->b_receive == NULL || callbacks->card_receive == NULL)
        return ERRCODE_SLE_FAIL;
    (void)memset(&g_b, 0, sizeof(g_b));
    (void)memset(&g_card, 0, sizeof(g_card));
    g_callbacks = *callbacks;
    g_pending_role = DUAL_ROLE_NONE;
    g_seeking = false;
    (void)memset(&g_seek_callbacks, 0, sizeof(g_seek_callbacks));
    g_seek_callbacks.sle_enable_cb = dual_sle_enable_callback;
    g_seek_callbacks.seek_enable_cb = seek_enable_callback;
    g_seek_callbacks.seek_result_cb = seek_result_callback;
    g_seek_callbacks.seek_disable_cb = seek_disable_callback;
    result = sle_announce_seek_register_callbacks(&g_seek_callbacks);
    if (result != ERRCODE_SLE_SUCCESS) return result;
    (void)memset(&g_connection_callbacks, 0, sizeof(g_connection_callbacks));
    g_connection_callbacks.connect_state_changed_cb = connection_state_callback;
    g_connection_callbacks.pair_complete_cb = pair_complete_callback;
    g_connection_callbacks.read_rssi_cb = read_rssi_callback;
    result = sle_connection_register_callbacks(&g_connection_callbacks);
    if (result != ERRCODE_SLE_SUCCESS) return result;
    (void)memset(&g_ssap_callbacks, 0, sizeof(g_ssap_callbacks));
    g_ssap_callbacks.exchange_info_cb = exchange_info_callback;
    g_ssap_callbacks.find_structure_cb = find_structure_callback;
    g_ssap_callbacks.ssapc_find_property_cbk = find_property_callback;
    g_ssap_callbacks.find_structure_cmp_cb = find_complete_callback;
    g_ssap_callbacks.notification_cb = notification_callback;
    g_ssap_callbacks.write_cfm_cb = write_confirm_callback;
    result = ssapc_register_callbacks(&g_ssap_callbacks);
    if (result != ERRCODE_SLE_SUCCESS) return result;
    (void)osal_msleep(DUAL_WAIT_CORE_MS);
    result = enable_sle();
    if (result != ERRCODE_SUCC) return result;
    return ERRCODE_SLE_SUCCESS;
}

bool sle_ab_dual_client_send_b(const uint8_t *data, uint16_t length)
{
    return send_endpoint(&g_b, data, length);
}

bool sle_ab_dual_client_send_card(const uint8_t *data, uint16_t length)
{
    return send_endpoint(&g_card, data, length);
}

bool sle_ab_dual_client_b_ready(void)
{
    return g_b.ready;
}

bool sle_ab_dual_client_card_ready(void)
{
    return g_card.ready;
}

bool sle_ab_dual_client_sample_card_rssi(void)
{
    if (!g_card.connected || g_card.conn_id == 0U) return false;
    return sle_read_remote_device_rssi(g_card.conn_id) == ERRCODE_SLE_SUCCESS;
}

void sle_ab_dual_client_status(void)
{
    osal_printk("%s B connected=%u paired=%u ready=%u conn=%u write=%u; "
                "Card connected=%u paired=%u ready=%u conn=%u command=%u response=%u "
                "seeking=%u pending=%u\r\n",
                DUAL_LOG, g_b.connected, g_b.paired, g_b.ready, g_b.conn_id,
                g_b.write_handle, g_card.connected, g_card.paired, g_card.ready,
                g_card.conn_id, g_card.write_handle, g_card.response_handle,
                g_seeking, g_pending_role);
}
