#ifndef SLE_DETECTOR_B_GATEWAY_H
#define SLE_DETECTOR_B_GATEWAY_H

#include "ab_messages.h"
#include "ab_protocol.h"

#define DETECTOR_B_GATEWAY_QUEUE_CAPACITY 32U
#define DETECTOR_B_GATEWAY_COMMAND_CACHE 8U
#define DETECTOR_B_GATEWAY_RETRY_MS 500U
#define DETECTOR_B_GATEWAY_RETRY_BACKOFF_MS 2000U
#define DETECTOR_B_GATEWAY_MAX_FAST_RETRIES 3U
#define DETECTOR_B_GATEWAY_HEARTBEAT_MS 1000U
#define DETECTOR_B_GATEWAY_HOST_TIMEOUT_MS 5000U

#define DETECTOR_B_POLICY_PAYLOAD_SIZE 20U
#define DETECTOR_B_POLICY_RESULT_SIZE 9U
#define DETECTOR_B_EVENT_REPORT_SIZE 40U
#define DETECTOR_B_CONFIRM_REQUEST_SIZE 24U
#define DETECTOR_B_CONFIRM_RESULT_SIZE 9U
#define DETECTOR_B_COMMAND_RESULT_SIZE 10U

#define DETECTOR_B_POLICY_ALLOW_EXECUTION 0x0001U
#define DETECTOR_B_POLICY_ADMIN_CONFIRM 0x0002U
#define DETECTOR_B_POLICY_USER_CONFIRM 0x0004U
#define DETECTOR_B_POLICY_ALLOW_OFFLINE 0x0008U
#define DETECTOR_B_POLICY_ALERT_ON_DENIAL 0x0010U

typedef enum {
    DETECTOR_B_GATEWAY_OK = 0,
    DETECTOR_B_GATEWAY_DUPLICATE = 1,
    DETECTOR_B_GATEWAY_INVALID = 2,
    DETECTOR_B_GATEWAY_STALE = 3,
    DETECTOR_B_GATEWAY_BUSY = 4,
    DETECTOR_B_GATEWAY_REQUEST_MISMATCH = 5,
    DETECTOR_B_GATEWAY_NOT_FOUND = 6
} detector_b_gateway_status_t;

typedef struct {
    uint32_t request_id;
    uint32_t permission_id;
    uint32_t policy_version;
    uint32_t organization_id;
    uint16_t flags;
} detector_b_policy_command_t;

typedef struct {
    uint32_t request_id;
    uint32_t event_id;
    hw_confirm_state_t result;
} detector_b_confirm_command_t;

typedef bool (*detector_b_gateway_tx_fn)(const uint8_t *data, size_t length, void *user);
typedef detector_b_gateway_status_t (*detector_b_gateway_policy_fn)(
    const detector_b_policy_command_t *command, void *user);
typedef detector_b_gateway_status_t (*detector_b_gateway_confirm_fn)(
    const detector_b_confirm_command_t *command, void *user);
typedef void (*detector_b_gateway_online_fn)(bool online, void *user);

typedef struct {
    bool valid;
    uint8_t type;
    uint16_t payload_length;
    uint8_t payload[AB_MAX_PAYLOAD];
    uint32_t message_id;
    bool sent;
    uint8_t fast_retries;
    uint32_t next_send_ms;
} detector_b_gateway_queue_entry_t;

typedef struct {
    bool valid;
    uint32_t request_id;
    uint8_t command_type;
    uint16_t payload_crc;
    detector_b_gateway_status_t status;
    uint32_t result_value;
} detector_b_gateway_command_cache_t;

typedef struct {
    ab_stream_parser_t parser;
    detector_b_gateway_tx_fn tx;
    detector_b_gateway_policy_fn apply_policy;
    detector_b_gateway_confirm_fn apply_confirm;
    detector_b_gateway_online_fn online_changed;
    void *user;
    uint32_t source_id;
    uint32_t boot_id;
    uint32_t firmware_version;
    uint32_t policy_version;
    uint32_t next_message_id;
    uint32_t next_request_id;
    detector_b_gateway_queue_entry_t queue[DETECTOR_B_GATEWAY_QUEUE_CAPACITY];
    uint8_t queue_head;
    uint8_t queue_tail;
    uint8_t queue_count;
    detector_b_gateway_command_cache_t command_cache[DETECTOR_B_GATEWAY_COMMAND_CACHE];
    uint8_t command_cache_next;
    bool host_online;
    uint32_t last_host_rx_ms;
    uint32_t next_heartbeat_ms;
    bool confirm_request_active;
    uint32_t confirm_request_id;
    uint32_t confirm_event_id;
    uint32_t frames_sent;
    uint32_t send_failures;
    uint32_t retry_attempts;
    uint32_t retry_cycles;
    uint32_t acknowledgements;
    uint32_t unknown_acks;
    uint32_t queue_overflows;
    uint32_t malformed_commands;
    uint32_t duplicate_commands;
    uint32_t conflicting_commands;
} detector_b_gateway_t;

void detector_b_gateway_init(detector_b_gateway_t *gateway,
                             detector_b_gateway_tx_fn tx,
                             detector_b_gateway_policy_fn apply_policy,
                             detector_b_gateway_confirm_fn apply_confirm,
                             detector_b_gateway_online_fn online_changed,
                             void *user);
void detector_b_gateway_set_identity(detector_b_gateway_t *gateway,
                                     uint32_t source_id, uint32_t boot_id,
                                     uint32_t firmware_version);
void detector_b_gateway_set_policy_version(detector_b_gateway_t *gateway,
                                           uint32_t policy_version);
void detector_b_gateway_receive(detector_b_gateway_t *gateway,
                                const uint8_t *data, size_t length,
                                uint32_t now_ms);
void detector_b_gateway_tick(detector_b_gateway_t *gateway, uint32_t now_ms);
bool detector_b_gateway_report(detector_b_gateway_t *gateway,
                               const hw_passage_event_t *event,
                               const ab_decision_t *decision);
uint8_t detector_b_gateway_queue_depth(const detector_b_gateway_t *gateway);

#endif
