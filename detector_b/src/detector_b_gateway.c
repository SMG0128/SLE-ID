#include "detector_b_gateway.h"

#include <string.h>

static uint16_t read_u16(const uint8_t *data)
{
    return (uint16_t)((uint16_t)data[0] | ((uint16_t)data[1] << 8));
}

static uint32_t read_u32(const uint8_t *data)
{
    return (uint32_t)data[0] | ((uint32_t)data[1] << 8) |
           ((uint32_t)data[2] << 16) | ((uint32_t)data[3] << 24);
}

static void write_u16(uint8_t *data, uint16_t value)
{
    data[0] = (uint8_t)value;
    data[1] = (uint8_t)(value >> 8);
}

static void write_u32(uint8_t *data, uint32_t value)
{
    data[0] = (uint8_t)value;
    data[1] = (uint8_t)(value >> 8);
    data[2] = (uint8_t)(value >> 16);
    data[3] = (uint8_t)(value >> 24);
}

static bool time_reached(uint32_t now_ms, uint32_t deadline_ms)
{
    return (int32_t)(now_ms - deadline_ms) >= 0;
}

static uint32_t next_nonzero(uint32_t *value)
{
    uint32_t current = (*value)++;
    if (current == 0U) current = (*value)++;
    return current;
}

static bool transmit(detector_b_gateway_t *gateway, uint8_t type, uint8_t flags,
                     uint32_t message_id, const uint8_t *payload,
                     uint16_t payload_length)
{
    uint8_t frame[AB_MAX_FRAME];
    ab_frame_header_t header = { 0 };
    size_t frame_length;
    header.type = type;
    header.flags = flags;
    header.source_role = AB_ROLE_DETECTOR_B;
    header.source_id = gateway->source_id;
    header.boot_id = gateway->boot_id;
    header.message_id = message_id;
    frame_length = ab_frame_encode(&header, payload, payload_length, frame, sizeof(frame));
    if (frame_length != 0U && gateway->tx != NULL &&
        gateway->tx(frame, frame_length, gateway->user)) {
        gateway->frames_sent++;
        return true;
    }
    gateway->send_failures++;
    return false;
}

static bool send_direct(detector_b_gateway_t *gateway, uint8_t type,
                        const uint8_t *payload, uint16_t payload_length)
{
    return transmit(gateway, type, AB_FLAG_RESPONSE,
                    next_nonzero(&gateway->next_message_id), payload, payload_length);
}

static bool enqueue(detector_b_gateway_t *gateway, uint8_t type,
                    const uint8_t *payload, uint16_t payload_length)
{
    detector_b_gateway_queue_entry_t *entry;
    if (gateway == NULL || payload == NULL || payload_length > AB_MAX_PAYLOAD) return false;
    if (gateway->queue_count >= DETECTOR_B_GATEWAY_QUEUE_CAPACITY) {
        gateway->queue_overflows++;
        return false;
    }
    entry = &gateway->queue[gateway->queue_tail];
    (void)memset(entry, 0, sizeof(*entry));
    entry->valid = true;
    entry->type = type;
    entry->payload_length = payload_length;
    (void)memcpy(entry->payload, payload, payload_length);
    entry->message_id = next_nonzero(&gateway->next_message_id);
    gateway->queue_tail = (uint8_t)((gateway->queue_tail + 1U) %
                                     DETECTOR_B_GATEWAY_QUEUE_CAPACITY);
    gateway->queue_count++;
    return true;
}

static void pop_head(detector_b_gateway_t *gateway)
{
    if (gateway->queue_count == 0U) return;
    (void)memset(&gateway->queue[gateway->queue_head], 0,
                 sizeof(gateway->queue[gateway->queue_head]));
    gateway->queue_head = (uint8_t)((gateway->queue_head + 1U) %
                                     DETECTOR_B_GATEWAY_QUEUE_CAPACITY);
    gateway->queue_count--;
}

static void mark_online(detector_b_gateway_t *gateway, uint32_t now_ms)
{
    gateway->last_host_rx_ms = now_ms;
    if (!gateway->host_online) {
        gateway->host_online = true;
        if (gateway->online_changed != NULL)
            gateway->online_changed(true, gateway->user);
    }
}

static detector_b_gateway_command_cache_t *find_command(
    detector_b_gateway_t *gateway, uint32_t request_id, uint8_t command_type)
{
    uint8_t i;
    for (i = 0U; i < DETECTOR_B_GATEWAY_COMMAND_CACHE; ++i) {
        if (gateway->command_cache[i].valid &&
            gateway->command_cache[i].request_id == request_id &&
            gateway->command_cache[i].command_type == command_type)
            return &gateway->command_cache[i];
    }
    return NULL;
}

static void cache_command(detector_b_gateway_t *gateway, uint32_t request_id,
                          uint8_t command_type, uint16_t payload_crc,
                          detector_b_gateway_status_t status, uint32_t result_value)
{
    detector_b_gateway_command_cache_t *entry =
        &gateway->command_cache[gateway->command_cache_next];
    entry->valid = true;
    entry->request_id = request_id;
    entry->command_type = command_type;
    entry->payload_crc = payload_crc;
    entry->status = status;
    entry->result_value = result_value;
    gateway->command_cache_next = (uint8_t)((gateway->command_cache_next + 1U) %
                                             DETECTOR_B_GATEWAY_COMMAND_CACHE);
}

static void send_policy_result(detector_b_gateway_t *gateway, uint32_t request_id,
                               detector_b_gateway_status_t status,
                               uint32_t policy_version)
{
    uint8_t payload[DETECTOR_B_POLICY_RESULT_SIZE];
    write_u32(&payload[0], request_id);
    payload[4] = (uint8_t)status;
    write_u32(&payload[5], policy_version);
    (void)send_direct(gateway, AB_MSG_POLICY_RESULT, payload, sizeof(payload));
}

static void send_command_result(detector_b_gateway_t *gateway, uint32_t request_id,
                                uint8_t command_type,
                                detector_b_gateway_status_t status,
                                uint32_t result_value)
{
    uint8_t payload[DETECTOR_B_COMMAND_RESULT_SIZE];
    write_u32(&payload[0], request_id);
    payload[4] = command_type;
    payload[5] = (uint8_t)status;
    write_u32(&payload[6], result_value);
    (void)send_direct(gateway, AB_MSG_COMMAND_RESULT, payload, sizeof(payload));
}

static void handle_ack(detector_b_gateway_t *gateway, const ab_frame_t *frame)
{
    ab_ack_t ack;
    detector_b_gateway_queue_entry_t *head;
    if (!ab_ack_decode(frame->payload, frame->payload_length, &ack) ||
        (ack.status != AB_ACK_ACCEPTED && ack.status != AB_ACK_DUPLICATE)) {
        gateway->malformed_commands++;
        return;
    }
    if (gateway->queue_count == 0U) {
        gateway->unknown_acks++;
        return;
    }
    head = &gateway->queue[gateway->queue_head];
    if (!head->valid || head->message_id != ack.message_id) {
        gateway->unknown_acks++;
        return;
    }
    gateway->acknowledgements++;
    pop_head(gateway);
}

static void handle_policy(detector_b_gateway_t *gateway, const ab_frame_t *frame)
{
    detector_b_policy_command_t command;
    detector_b_gateway_command_cache_t *cached;
    detector_b_gateway_status_t status;
    uint16_t payload_crc;
    if (frame->payload_length != DETECTOR_B_POLICY_PAYLOAD_SIZE) {
        gateway->malformed_commands++;
        return;
    }
    command.request_id = read_u32(&frame->payload[0]);
    command.permission_id = read_u32(&frame->payload[4]);
    command.policy_version = read_u32(&frame->payload[8]);
    command.organization_id = read_u32(&frame->payload[12]);
    command.flags = read_u16(&frame->payload[16]);
    if (command.request_id == 0U || command.permission_id == 0U ||
        command.policy_version == 0U || command.organization_id == 0U ||
        (command.flags & (uint16_t)~(DETECTOR_B_POLICY_ALLOW_EXECUTION |
                                    DETECTOR_B_POLICY_ADMIN_CONFIRM |
                                    DETECTOR_B_POLICY_USER_CONFIRM |
                                    DETECTOR_B_POLICY_ALLOW_OFFLINE |
                                    DETECTOR_B_POLICY_ALERT_ON_DENIAL)) != 0U ||
        frame->payload[18] != 0U || frame->payload[19] != 0U) {
        gateway->malformed_commands++;
        send_policy_result(gateway, command.request_id,
                           DETECTOR_B_GATEWAY_INVALID, gateway->policy_version);
        return;
    }
    payload_crc = ab_crc16_ccitt(frame->payload, frame->payload_length);
    cached = find_command(gateway, command.request_id, AB_MSG_POLICY_SYNC);
    if (cached != NULL) {
        if (cached->payload_crc != payload_crc) {
            gateway->conflicting_commands++;
            send_policy_result(gateway, command.request_id,
                               DETECTOR_B_GATEWAY_REQUEST_MISMATCH,
                               gateway->policy_version);
            return;
        }
        gateway->duplicate_commands++;
        send_policy_result(gateway, command.request_id,
                           cached->status, cached->result_value);
        return;
    }
    status = gateway->apply_policy == NULL ? DETECTOR_B_GATEWAY_INVALID :
        gateway->apply_policy(&command, gateway->user);
    if (status == DETECTOR_B_GATEWAY_OK) gateway->policy_version = command.policy_version;
    cache_command(gateway, command.request_id, AB_MSG_POLICY_SYNC, payload_crc,
                  status, gateway->policy_version);
    send_policy_result(gateway, command.request_id, status, gateway->policy_version);
}

static void handle_confirm(detector_b_gateway_t *gateway, const ab_frame_t *frame)
{
    detector_b_confirm_command_t command;
    detector_b_gateway_command_cache_t *cached;
    detector_b_gateway_status_t status;
    uint16_t payload_crc;
    if (frame->payload_length != DETECTOR_B_CONFIRM_RESULT_SIZE) {
        gateway->malformed_commands++;
        return;
    }
    command.request_id = read_u32(&frame->payload[0]);
    command.event_id = read_u32(&frame->payload[4]);
    command.result = (hw_confirm_state_t)frame->payload[8];
    if (command.request_id == 0U || command.event_id == 0U ||
        (command.result != HW_CONFIRM_APPROVED &&
         command.result != HW_CONFIRM_REJECTED)) {
        gateway->malformed_commands++;
        send_command_result(gateway, command.request_id, AB_MSG_CONFIRM_RESULT,
                            DETECTOR_B_GATEWAY_INVALID, command.event_id);
        return;
    }
    payload_crc = ab_crc16_ccitt(frame->payload, frame->payload_length);
    cached = find_command(gateway, command.request_id, AB_MSG_CONFIRM_RESULT);
    if (cached != NULL) {
        if (cached->payload_crc != payload_crc) {
            gateway->conflicting_commands++;
            send_command_result(gateway, command.request_id, AB_MSG_CONFIRM_RESULT,
                                DETECTOR_B_GATEWAY_REQUEST_MISMATCH,
                                command.event_id);
            return;
        }
        gateway->duplicate_commands++;
        send_command_result(gateway, command.request_id, AB_MSG_CONFIRM_RESULT,
                            cached->status, cached->result_value);
        return;
    }
    if (!gateway->confirm_request_active ||
        gateway->confirm_request_id != command.request_id ||
        gateway->confirm_event_id != command.event_id) {
        status = DETECTOR_B_GATEWAY_NOT_FOUND;
    } else {
        status = gateway->apply_confirm == NULL ? DETECTOR_B_GATEWAY_INVALID :
            gateway->apply_confirm(&command, gateway->user);
        if (status == DETECTOR_B_GATEWAY_OK) gateway->confirm_request_active = false;
    }
    cache_command(gateway, command.request_id, AB_MSG_CONFIRM_RESULT, payload_crc,
                  status, command.event_id);
    send_command_result(gateway, command.request_id, AB_MSG_CONFIRM_RESULT,
                        status, command.event_id);
}

static void on_frame(const ab_frame_t *frame, void *user)
{
    detector_b_gateway_t *gateway = (detector_b_gateway_t *)user;
    if (frame->header.source_role != AB_ROLE_HOST) {
        gateway->malformed_commands++;
        return;
    }
    mark_online(gateway, gateway->last_host_rx_ms);
    switch (frame->header.type) {
        case AB_MSG_ACK:
            handle_ack(gateway, frame);
            break;
        case AB_MSG_POLICY_SYNC:
            handle_policy(gateway, frame);
            break;
        case AB_MSG_CONFIRM_RESULT:
            handle_confirm(gateway, frame);
            break;
        case AB_MSG_HEARTBEAT:
            break;
        default:
            gateway->malformed_commands++;
            break;
    }
}

void detector_b_gateway_init(detector_b_gateway_t *gateway,
                             detector_b_gateway_tx_fn tx,
                             detector_b_gateway_policy_fn apply_policy,
                             detector_b_gateway_confirm_fn apply_confirm,
                             detector_b_gateway_online_fn online_changed,
                             void *user)
{
    if (gateway == NULL) return;
    (void)memset(gateway, 0, sizeof(*gateway));
    gateway->tx = tx;
    gateway->apply_policy = apply_policy;
    gateway->apply_confirm = apply_confirm;
    gateway->online_changed = online_changed;
    gateway->user = user;
    gateway->source_id = 0xB0000001U;
    gateway->boot_id = 1U;
    gateway->next_message_id = 1U;
    gateway->next_request_id = 1U;
    ab_parser_init(&gateway->parser, on_frame, gateway);
}

void detector_b_gateway_set_identity(detector_b_gateway_t *gateway,
                                     uint32_t source_id, uint32_t boot_id,
                                     uint32_t firmware_version)
{
    if (gateway == NULL || source_id == 0U || boot_id == 0U) return;
    gateway->source_id = source_id;
    gateway->boot_id = boot_id;
    gateway->firmware_version = firmware_version;
}

void detector_b_gateway_set_policy_version(detector_b_gateway_t *gateway,
                                           uint32_t policy_version)
{
    if (gateway != NULL) gateway->policy_version = policy_version;
}

void detector_b_gateway_receive(detector_b_gateway_t *gateway,
                                const uint8_t *data, size_t length,
                                uint32_t now_ms)
{
    if (gateway == NULL || data == NULL) return;
    gateway->last_host_rx_ms = now_ms;
    ab_parser_feed(&gateway->parser, data, length);
}

static void send_heartbeat(detector_b_gateway_t *gateway, uint32_t now_ms)
{
    uint8_t payload[20] = { 0 };
    write_u32(&payload[0], now_ms);
    write_u32(&payload[4], gateway->firmware_version);
    write_u32(&payload[8], gateway->policy_version);
    payload[12] = gateway->queue_count;
    payload[13] = gateway->host_online ? 1U : 0U;
    write_u16(&payload[14], (uint16_t)gateway->queue_overflows);
    write_u32(&payload[16], gateway->frames_sent);
    (void)transmit(gateway, AB_MSG_HEARTBEAT, 0U,
                   next_nonzero(&gateway->next_message_id), payload, sizeof(payload));
}

void detector_b_gateway_tick(detector_b_gateway_t *gateway, uint32_t now_ms)
{
    detector_b_gateway_queue_entry_t *entry;
    if (gateway == NULL) return;
    if (gateway->host_online &&
        time_reached(now_ms, gateway->last_host_rx_ms + DETECTOR_B_GATEWAY_HOST_TIMEOUT_MS)) {
        gateway->host_online = false;
        if (gateway->online_changed != NULL)
            gateway->online_changed(false, gateway->user);
    }
    if (time_reached(now_ms, gateway->next_heartbeat_ms)) {
        gateway->next_heartbeat_ms = now_ms + DETECTOR_B_GATEWAY_HEARTBEAT_MS;
        send_heartbeat(gateway, now_ms);
    }
    if (gateway->queue_count == 0U) return;
    entry = &gateway->queue[gateway->queue_head];
    if (!entry->valid || (entry->sent && !time_reached(now_ms, entry->next_send_ms))) return;
    if (entry->sent) {
        gateway->retry_attempts++;
        entry->fast_retries++;
    }
    (void)transmit(gateway, entry->type,
                   (uint8_t)(AB_FLAG_ACK_REQUIRED |
                             (entry->sent ? AB_FLAG_RETRY : 0U)),
                   entry->message_id, entry->payload, entry->payload_length);
    entry->sent = true;
    if (entry->fast_retries >= DETECTOR_B_GATEWAY_MAX_FAST_RETRIES) {
        entry->fast_retries = 0U;
        entry->next_send_ms = now_ms + DETECTOR_B_GATEWAY_RETRY_BACKOFF_MS;
        gateway->retry_cycles++;
    } else {
        entry->next_send_ms = now_ms + DETECTOR_B_GATEWAY_RETRY_MS;
    }
}

static void encode_event(const hw_passage_event_t *event,
                         const ab_decision_t *decision, uint8_t *payload)
{
    (void)memset(payload, 0, DETECTOR_B_EVENT_REPORT_SIZE);
    write_u32(&payload[0], event->event_id);
    write_u32(&payload[4], event->source_id);
    write_u32(&payload[8], event->boot_id);
    write_u32(&payload[12], event->card_anon_id);
    write_u32(&payload[16], event->permission_id);
    write_u32(&payload[20], event->timestamp_ms);
    payload[24] = (uint8_t)event->direction;
    payload[25] = (uint8_t)event->auth;
    payload[26] = (uint8_t)decision->action;
    payload[27] = (uint8_t)decision->confirm;
    payload[28] = (uint8_t)decision->execution;
    payload[29] = (uint8_t)decision->reason;
    write_u16(&payload[30], event->distance_cm);
    payload[32] = event->confidence;
    payload[33] = (uint8_t)event->state;
    write_u32(&payload[34], decision->timestamp_ms);
}

static bool requires_alert(const ab_decision_t *decision)
{
    return decision->action == HW_ACTION_ALERT ||
           decision->execution == HW_EXEC_FAILED ||
           decision->confirm == HW_CONFIRM_REJECTED ||
           decision->confirm == HW_CONFIRM_TIMEOUT ||
           decision->confirm == HW_CONFIRM_OFFLINE ||
           decision->reason == AB_REASON_FROZEN ||
           decision->reason == AB_REASON_LOST ||
           decision->reason == AB_REASON_REVOKED ||
           decision->reason == AB_REASON_KEY_FAILED ||
           decision->reason == AB_REASON_REPLAY_SUSPECTED;
}

static void remove_queued_confirm(detector_b_gateway_t *gateway, uint32_t event_id)
{
    uint8_t logical;
    if (gateway == NULL || event_id == 0U) return;
    for (logical = 0U; logical < gateway->queue_count; ++logical) {
        uint8_t index = (uint8_t)((gateway->queue_head + logical) %
                                  DETECTOR_B_GATEWAY_QUEUE_CAPACITY);
        detector_b_gateway_queue_entry_t *entry = &gateway->queue[index];
        uint8_t move;
        if (!entry->valid || entry->type != AB_MSG_CONFIRM_REQUEST ||
            entry->payload_length != DETECTOR_B_CONFIRM_REQUEST_SIZE ||
            read_u32(&entry->payload[4]) != event_id)
            continue;
        for (move = logical; move + 1U < gateway->queue_count; ++move) {
            uint8_t current = (uint8_t)((gateway->queue_head + move) %
                                        DETECTOR_B_GATEWAY_QUEUE_CAPACITY);
            uint8_t next = (uint8_t)((current + 1U) %
                                     DETECTOR_B_GATEWAY_QUEUE_CAPACITY);
            gateway->queue[current] = gateway->queue[next];
        }
        gateway->queue_tail = (uint8_t)((gateway->queue_tail +
            DETECTOR_B_GATEWAY_QUEUE_CAPACITY - 1U) %
            DETECTOR_B_GATEWAY_QUEUE_CAPACITY);
        (void)memset(&gateway->queue[gateway->queue_tail], 0,
                     sizeof(gateway->queue[gateway->queue_tail]));
        gateway->queue_count--;
        return;
    }
}

bool detector_b_gateway_report(detector_b_gateway_t *gateway,
                               const hw_passage_event_t *event,
                               const ab_decision_t *decision)
{
    uint8_t payload[DETECTOR_B_EVENT_REPORT_SIZE];
    bool ok;
    if (gateway == NULL || event == NULL || decision == NULL || event->event_id == 0U)
        return false;
    if (gateway->confirm_request_active && gateway->confirm_event_id == event->event_id &&
        !(decision->action == HW_ACTION_WAIT_CONFIRM &&
          decision->confirm == HW_CONFIRM_PENDING)) {
        gateway->confirm_request_active = false;
        remove_queued_confirm(gateway, event->event_id);
    }
    encode_event(event, decision, payload);
    ok = enqueue(gateway, AB_MSG_EVENT_REPORT, payload, sizeof(payload));
    if (requires_alert(decision))
        ok = enqueue(gateway, AB_MSG_ALERT_REPORT, payload, sizeof(payload)) && ok;
    if (decision->action == HW_ACTION_WAIT_CONFIRM &&
        decision->confirm == HW_CONFIRM_PENDING) {
        uint8_t confirm_payload[DETECTOR_B_CONFIRM_REQUEST_SIZE] = { 0 };
        uint32_t request_id = next_nonzero(&gateway->next_request_id);
        write_u32(&confirm_payload[0], request_id);
        write_u32(&confirm_payload[4], event->event_id);
        write_u32(&confirm_payload[8], event->card_anon_id);
        write_u32(&confirm_payload[12], event->permission_id);
        write_u32(&confirm_payload[16], decision->timestamp_ms);
        confirm_payload[20] = (uint8_t)decision->action;
        confirm_payload[21] = (uint8_t)event->direction;
        if (enqueue(gateway, AB_MSG_CONFIRM_REQUEST, confirm_payload,
                    sizeof(confirm_payload))) {
            gateway->confirm_request_active = true;
            gateway->confirm_request_id = request_id;
            gateway->confirm_event_id = event->event_id;
        } else {
            ok = false;
        }
    }
    return ok;
}

uint8_t detector_b_gateway_queue_depth(const detector_b_gateway_t *gateway)
{
    return gateway == NULL ? 0U : gateway->queue_count;
}
