#include "ws63_card_sle_server.h"

#include <string.h>

#include "card_service.h"
#include "common_def.h"
#include "securec.h"
#include "sle_connection_manager.h"
#include "sle_device_discovery.h"
#include "sle_errcode.h"
#include "sle_ssap_server.h"
#include "soc_osal.h"
#include "trng.h"

#define CARD_SLE_LOG "[sle card]"
#define CARD_SLE_UUID_LEN 2U
#define CARD_SLE_UUID_INDEX 14U
#define CARD_SLE_ADV_HANDLE 2U
#define CARD_SLE_ADV_DATA_MAX 251U
#define CARD_SLE_ADV_INTERVAL 0xC8U
#define CARD_SLE_CONN_TIMEOUT 0x1F4U
#define CARD_SLE_CONN_LATENCY 0U
#define CARD_SLE_TX_POWER_DBM 10
#define CARD_SLE_NAME "sle_card"
#define CARD_SLE_READ_BUFFER_SIZE 96U
#define CARD_SLE_RSP_FAILED 1U

#define CARD_ADV_TYPE_DISCOVERY_LEVEL 0x01U
#define CARD_ADV_TYPE_ACCESS_MODE 0x02U
#define CARD_ADV_TYPE_COMPLETE_UUID16 0x05U
#define CARD_ADV_TYPE_COMPLETE_NAME 0x0BU

static const uint8_t g_card_base_uuid[SLE_UUID_LEN] = {
    0x37, 0xBE, 0xA8, 0x80, 0xFC, 0x70, 0x11, 0xEA,
    0xB7, 0x20, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
};
static const uint8_t g_card_app_uuid[CARD_SLE_UUID_LEN] = { 0xCA, 0x4D };

static ws63_card_sle_callbacks_t g_callbacks;
static uint8_t g_server_id;
static uint16_t g_conn_id;
static uint16_t g_service_handle;
static uint16_t g_info_handle;
static uint16_t g_command_handle;
static uint16_t g_response_handle;
static uint16_t g_status_handle;
static bool g_connected;
static bool g_paired;

static void encode_u16(uint8_t *output, uint16_t value)
{
    output[0] = (uint8_t)value;
    output[1] = (uint8_t)(value >> 8);
}

static bool make_uuid(uint16_t value, sle_uuid_t *uuid)
{
    if (uuid == NULL || memcpy_s(uuid->uuid, SLE_UUID_LEN, g_card_base_uuid,
                                 sizeof(g_card_base_uuid)) != EOK) return false;
    uuid->len = CARD_SLE_UUID_LEN;
    encode_u16(&uuid->uuid[CARD_SLE_UUID_INDEX], value);
    return true;
}

static errcode_t add_cccd(uint16_t property_handle)
{
    uint8_t initial_value[] = { 0x01U, 0x00U };
    ssaps_desc_info_t descriptor = { 0 };
    descriptor.permissions = SSAP_PERMISSION_READ | SSAP_PERMISSION_WRITE |
                             SSAP_PERMISSION_ENCRYPTION_NEED;
    descriptor.type = SSAP_DESCRIPTOR_CLIENT_CONFIGURATION;
    descriptor.operate_indication = SSAP_OPERATE_INDICATION_BIT_READ |
                                    SSAP_OPERATE_INDICATION_BIT_WRITE;
    descriptor.value = initial_value;
    descriptor.value_len = sizeof(initial_value);
    return ssaps_add_descriptor_sync(g_server_id, g_service_handle, property_handle,
                                     &descriptor);
}

static errcode_t add_property(uint16_t uuid_value, uint16_t permissions,
                              uint32_t operations, bool with_cccd, uint16_t *handle)
{
    uint8_t initial_value = 0U;
    ssaps_property_info_t property = { 0 };
    errcode_t result;
    if (!make_uuid(uuid_value, &property.uuid)) return ERRCODE_SLE_FAIL;
    property.permissions = permissions;
    property.operate_indication = operations;
    property.value = &initial_value;
    property.value_len = sizeof(initial_value);
    result = ssaps_add_property_sync(g_server_id, g_service_handle, &property, handle);
    if (result != ERRCODE_SLE_SUCCESS) return result;
    return with_cccd ? add_cccd(*handle) : ERRCODE_SLE_SUCCESS;
}

static void read_request_callback(uint8_t server_id, uint16_t conn_id,
                                  ssaps_req_read_cb_t *request, errcode_t status)
{
    uint8_t value[CARD_SLE_READ_BUFFER_SIZE];
    ssaps_send_rsp_t response = { 0 };
    uint16_t value_length = 0U;
    if (request == NULL || !request->need_rsp) return;
    response.request_id = request->request_id;
    response.status = CARD_SLE_RSP_FAILED;
    if (status == ERRCODE_SLE_SUCCESS && g_connected && g_paired &&
        conn_id == g_conn_id && g_callbacks.read != NULL &&
        (request->handle == g_info_handle || request->handle == g_status_handle)) {
        value_length = g_callbacks.read(request->handle, value, sizeof(value), g_callbacks.user);
        if (value_length != 0U && value_length <= sizeof(value)) {
            response.status = ERRCODE_SLE_SUCCESS;
            response.value = value;
            response.value_len = value_length;
        }
    }
    (void)ssaps_send_response(server_id, conn_id, &response);
}

static void write_request_callback(uint8_t server_id, uint16_t conn_id,
                                   ssaps_req_write_cb_t *request, errcode_t status)
{
    bool accepted = false;
    ssaps_send_rsp_t response = { 0 };
    if (request == NULL) return;
    if (request->type == SSAP_DESCRIPTOR_CLIENT_CONFIGURATION) {
        if (request->need_rsp) {
            response.request_id = request->request_id;
            response.status = (status == ERRCODE_SLE_SUCCESS && g_connected && g_paired &&
                               conn_id == g_conn_id) ?
                ERRCODE_SLE_SUCCESS : CARD_SLE_RSP_FAILED;
            (void)ssaps_send_response(server_id, conn_id, &response);
        }
        return;
    }
    if (status == ERRCODE_SLE_SUCCESS && g_connected && g_paired &&
        conn_id == g_conn_id && request->handle == g_command_handle &&
        request->value != NULL && request->length != 0U && g_callbacks.command != NULL) {
        accepted = g_callbacks.command(request->value, request->length, g_callbacks.user);
    }
    if (request->need_rsp) {
        response.request_id = request->request_id;
        response.status = accepted ? ERRCODE_SLE_SUCCESS : CARD_SLE_RSP_FAILED;
        (void)ssaps_send_response(server_id, conn_id, &response);
    }
}

static void connect_state_callback(uint16_t conn_id, const sle_addr_t *addr,
                                   sle_acb_state_t conn_state, sle_pair_state_t pair_state,
                                   sle_disc_reason_t reason)
{
    unused(addr);
    unused(pair_state);
    unused(reason);
    if (conn_state == SLE_ACB_STATE_CONNECTED) {
        g_conn_id = conn_id;
        g_connected = true;
        g_paired = false;
        osal_printk("%s connected conn=%u\r\n", CARD_SLE_LOG, conn_id);
    } else if (conn_state == SLE_ACB_STATE_DISCONNECTED) {
        if (!g_connected || conn_id != g_conn_id) {
            osal_printk("%s ignored stale disconnect conn=%u current=%u\r\n",
                        CARD_SLE_LOG, conn_id, g_conn_id);
            return;
        }
        g_conn_id = 0U;
        g_connected = false;
        g_paired = false;
        osal_printk("%s disconnected\r\n", CARD_SLE_LOG);
        if (g_callbacks.connection != NULL) g_callbacks.connection(false, g_callbacks.user);
        (void)sle_start_announce(CARD_SLE_ADV_HANDLE);
    }
}

static void pair_complete_callback(uint16_t conn_id, const sle_addr_t *addr, errcode_t status)
{
    ssap_exchange_info_t info = { 0 };
    unused(addr);
    if (!g_connected || conn_id != g_conn_id) {
        osal_printk("%s ignored stale pair conn=%u current=%u status=%d\r\n",
                    CARD_SLE_LOG, conn_id, g_conn_id, status);
        return;
    }
    info.mtu_size = CONFIG_SLE_CARD_MTU_SIZE;
    info.version = CARD_SERVICE_PROTOCOL_VERSION;
    (void)ssaps_set_info(g_server_id, &info);
    if (status == ERRCODE_SLE_SUCCESS) {
        g_paired = true;
        if (g_callbacks.connection != NULL) g_callbacks.connection(true, g_callbacks.user);
        osal_printk("%s pair complete conn=%u status=%d, service ready\r\n",
                    CARD_SLE_LOG, conn_id, status);
    } else {
        osal_printk("%s pair failed conn=%u status=%d, service locked\r\n",
                    CARD_SLE_LOG, conn_id, status);
    }
}

static errcode_t register_callbacks(void)
{
    ssaps_callbacks_t ssaps = { 0 };
    sle_connection_callbacks_t connection = { 0 };
    errcode_t result;
    ssaps.read_request_cb = read_request_callback;
    ssaps.write_request_cb = write_request_callback;
    result = ssaps_register_callbacks(&ssaps);
    if (result != ERRCODE_SLE_SUCCESS) return result;
    connection.connect_state_changed_cb = connect_state_callback;
    connection.pair_complete_cb = pair_complete_callback;
    return sle_connection_register_callbacks(&connection);
}

static errcode_t add_service(void)
{
    sle_uuid_t app_uuid = { 0 };
    sle_uuid_t service_uuid = { 0 };
    errcode_t result;
    app_uuid.len = sizeof(g_card_app_uuid);
    if (memcpy_s(app_uuid.uuid, sizeof(app_uuid.uuid), g_card_app_uuid,
                 sizeof(g_card_app_uuid)) != EOK ||
        !make_uuid(WS63_CARD_SERVICE_UUID, &service_uuid)) return ERRCODE_SLE_FAIL;
    result = ssaps_register_server(&app_uuid, &g_server_id);
    if (result != ERRCODE_SLE_SUCCESS) return result;
    result = ssaps_add_service_sync(g_server_id, &service_uuid, true, &g_service_handle);
    if (result != ERRCODE_SLE_SUCCESS) return result;
    result = add_property(WS63_CARD_INFO_UUID,
                          SSAP_PERMISSION_READ | SSAP_PERMISSION_ENCRYPTION_NEED,
                          SSAP_OPERATE_INDICATION_BIT_READ, false, &g_info_handle);
    if (result != ERRCODE_SLE_SUCCESS) return result;
    result = add_property(WS63_CARD_COMMAND_UUID,
                          SSAP_PERMISSION_WRITE | SSAP_PERMISSION_ENCRYPTION_NEED |
                              SSAP_PERMISSION_AUTHENTICATION_NEED,
                          SSAP_OPERATE_INDICATION_BIT_WRITE, false, &g_command_handle);
    if (result != ERRCODE_SLE_SUCCESS) return result;
    result = add_property(WS63_CARD_RESPONSE_UUID,
                          SSAP_PERMISSION_READ | SSAP_PERMISSION_ENCRYPTION_NEED,
                          SSAP_OPERATE_INDICATION_BIT_READ |
                              SSAP_OPERATE_INDICATION_BIT_NOTIFY,
                          true, &g_response_handle);
    if (result != ERRCODE_SLE_SUCCESS) return result;
    result = add_property(WS63_CARD_STATUS_UUID,
                          SSAP_PERMISSION_READ | SSAP_PERMISSION_ENCRYPTION_NEED,
                          SSAP_OPERATE_INDICATION_BIT_READ |
                              SSAP_OPERATE_INDICATION_BIT_NOTIFY,
                          true, &g_status_handle);
    if (result != ERRCODE_SLE_SUCCESS) return result;
    result = ssaps_start_service(g_server_id, g_service_handle);
    if (result == ERRCODE_SLE_SUCCESS)
        osal_printk("%s service=%x info=%x command=%x response=%x status=%x\r\n",
                    CARD_SLE_LOG, g_service_handle, g_info_handle, g_command_handle,
                    g_response_handle, g_status_handle);
    return result;
}

static void announce_enable_callback(uint32_t announce_id, errcode_t status)
{
    osal_printk("%s announce id=%u status=%d\r\n", CARD_SLE_LOG, announce_id, status);
}

static uint16_t build_announce_data(uint8_t *data)
{
    uint16_t index = 0U;
    data[index++] = 2U;
    data[index++] = CARD_ADV_TYPE_DISCOVERY_LEVEL;
    data[index++] = SLE_ANNOUNCE_LEVEL_NORMAL;
    data[index++] = 2U;
    data[index++] = CARD_ADV_TYPE_ACCESS_MODE;
    data[index++] = 0U;
    data[index++] = 3U;
    data[index++] = CARD_ADV_TYPE_COMPLETE_UUID16;
    encode_u16(&data[index], WS63_CARD_SERVICE_UUID);
    index += 2U;
    return index;
}

static uint16_t build_seek_response(uint8_t *data)
{
    const char name[] = CARD_SLE_NAME;
    uint16_t name_length = (uint16_t)(sizeof(name) - 1U);
    data[0] = (uint8_t)(name_length + 1U);
    data[1] = CARD_ADV_TYPE_COMPLETE_NAME;
    if (memcpy_s(&data[2], CARD_SLE_ADV_DATA_MAX - 2U, name, name_length) != EOK) return 0U;
    return (uint16_t)(name_length + 2U);
}

static errcode_t configure_advertising(void)
{
    sle_announce_param_t parameter = { 0 };
    sle_announce_data_t announce = { 0 };
    uint8_t data[CARD_SLE_ADV_DATA_MAX] = { 0 };
    uint8_t seek_response[CARD_SLE_ADV_DATA_MAX] = { 0 };
    uint8_t local_address[SLE_ADDR_LEN] = { 0x0C, 0xA4, 0x00, 0x00, 0x00, 0x00 };
    uint32_t random_address = 0U;
    errcode_t result;
    parameter.announce_mode = SLE_ANNOUNCE_MODE_CONNECTABLE_SCANABLE;
    parameter.announce_handle = CARD_SLE_ADV_HANDLE;
    parameter.announce_gt_role = SLE_ANNOUNCE_ROLE_T_CAN_NEGO;
    parameter.announce_level = SLE_ANNOUNCE_LEVEL_NORMAL;
    parameter.announce_channel_map = 0x07U;
    parameter.announce_interval_min = CARD_SLE_ADV_INTERVAL;
    parameter.announce_interval_max = CARD_SLE_ADV_INTERVAL;
    parameter.conn_interval_min = CONFIG_SLE_CARD_CONN_INTERVAL;
    parameter.conn_interval_max = CONFIG_SLE_CARD_CONN_INTERVAL;
    parameter.conn_max_latency = CARD_SLE_CONN_LATENCY;
    parameter.conn_supervision_timeout = CARD_SLE_CONN_TIMEOUT;
    parameter.announce_tx_power = CARD_SLE_TX_POWER_DBM;
    parameter.own_addr.type = 0U;
    if (uapi_drv_cipher_trng_get_random(&random_address) == ERRCODE_SUCC) {
        local_address[2] = (uint8_t)random_address;
        local_address[3] = (uint8_t)(random_address >> 8);
        local_address[4] = (uint8_t)(random_address >> 16);
        local_address[5] = (uint8_t)(random_address >> 24);
    }
    if (memcpy_s(parameter.own_addr.addr, sizeof(parameter.own_addr.addr),
                 local_address, sizeof(local_address)) != EOK) return ERRCODE_SLE_FAIL;
    result = sle_set_announce_param(CARD_SLE_ADV_HANDLE, &parameter);
    if (result != ERRCODE_SLE_SUCCESS) return result;
    announce.announce_data = data;
    announce.announce_data_len = build_announce_data(data);
    announce.seek_rsp_data = seek_response;
    announce.seek_rsp_data_len = build_seek_response(seek_response);
    return sle_set_announce_data(CARD_SLE_ADV_HANDLE, &announce);
}

errcode_t ws63_card_sle_server_init(const ws63_card_sle_callbacks_t *callbacks)
{
    sle_announce_seek_callbacks_t announce = { 0 };
    errcode_t result;
    if (callbacks == NULL || callbacks->command == NULL || callbacks->read == NULL)
        return ERRCODE_SLE_FAIL;
    g_callbacks = *callbacks;
    if (enable_sle() != ERRCODE_SUCC) return ERRCODE_SLE_FAIL;
    announce.announce_enable_cb = announce_enable_callback;
    result = sle_announce_seek_register_callbacks(&announce);
    if (result != ERRCODE_SLE_SUCCESS) return result;
    result = register_callbacks();
    if (result != ERRCODE_SLE_SUCCESS) return result;
    return add_service();
}

errcode_t ws63_card_sle_start_advertising(void)
{
    errcode_t result = configure_advertising();
    return result == ERRCODE_SLE_SUCCESS ?
        sle_start_announce(CARD_SLE_ADV_HANDLE) : result;
}

static errcode_t send_notification(uint16_t handle, const uint8_t *data, uint16_t length)
{
    ssaps_ntf_ind_t notification = { 0 };
    if (!g_connected || !g_paired || data == NULL || length == 0U) return ERRCODE_SLE_FAIL;
    notification.handle = handle;
    notification.type = SSAP_PROPERTY_TYPE_VALUE;
    notification.value = (uint8_t *)data;
    notification.value_len = length;
    return ssaps_notify_indicate(g_server_id, g_conn_id, &notification);
}

errcode_t ws63_card_sle_send_response(const uint8_t *data, uint16_t length)
{
    return send_notification(g_response_handle, data, length);
}

errcode_t ws63_card_sle_send_status(const uint8_t *data, uint16_t length)
{
    return send_notification(g_status_handle, data, length);
}

bool ws63_card_sle_is_connected(void)
{
    return g_connected && g_paired;
}

uint16_t ws63_card_sle_info_handle(void)
{
    return g_info_handle;
}

uint16_t ws63_card_sle_status_handle(void)
{
    return g_status_handle;
}
