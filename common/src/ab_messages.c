#include "ab_messages.h"

static uint16_t read_u16(const uint8_t *p) { return (uint16_t)(p[0] | ((uint16_t)p[1] << 8)); }
static uint32_t read_u32(const uint8_t *p)
{
    return (uint32_t)p[0] | ((uint32_t)p[1] << 8) | ((uint32_t)p[2] << 16) | ((uint32_t)p[3] << 24);
}
static void write_u16(uint8_t *p, uint16_t v) { p[0] = (uint8_t)v; p[1] = (uint8_t)(v >> 8); }
static void write_u32(uint8_t *p, uint32_t v)
{
    p[0] = (uint8_t)v; p[1] = (uint8_t)(v >> 8); p[2] = (uint8_t)(v >> 16); p[3] = (uint8_t)(v >> 24);
}

size_t ab_passage_encode(const hw_passage_event_t *event, uint8_t *out, size_t capacity)
{
    if (event == NULL || out == NULL || capacity < AB_PASSAGE_PAYLOAD_SIZE) return 0U;
    write_u32(&out[0], event->event_id);
    write_u32(&out[4], event->card_anon_id);
    write_u32(&out[8], event->timestamp_ms);
    write_u16(&out[12], event->distance_cm);
    out[14] = event->confidence;
    out[15] = (uint8_t)event->direction;
    out[16] = (uint8_t)event->state;
    out[17] = (uint8_t)event->auth;
    write_u32(&out[18], event->auth_session_id);
    write_u32(&out[22], event->permission_id);
    write_u32(&out[26], event->auth_counter);
    return AB_PASSAGE_PAYLOAD_SIZE;
}

bool ab_passage_decode(const uint8_t *data, size_t length, hw_passage_event_t *event)
{
    if (data == NULL || event == NULL || length != AB_PASSAGE_PAYLOAD_SIZE) return false;
    event->source_id = 0U;
    event->boot_id = 0U;
    event->event_id = read_u32(&data[0]);
    event->card_anon_id = read_u32(&data[4]);
    event->timestamp_ms = read_u32(&data[8]);
    event->distance_cm = read_u16(&data[12]);
    event->confidence = data[14];
    event->direction = (hw_direction_t)data[15];
    event->state = (hw_event_state_t)data[16];
    event->auth = (hw_auth_result_t)data[17];
    event->auth_session_id = read_u32(&data[18]);
    event->permission_id = read_u32(&data[22]);
    event->auth_counter = read_u32(&data[26]);
    return event->state == HW_EVENT_COMPLETED && event->direction <= HW_DIRECTION_EXIT &&
           event->auth <= HW_REPLAY_SUSPECTED;
}

size_t ab_decision_encode(const ab_decision_t *decision, uint8_t *out, size_t capacity)
{
    if (decision == NULL || out == NULL || capacity < AB_DECISION_PAYLOAD_SIZE) return 0U;
    write_u32(&out[0], decision->event_id);
    out[4] = (uint8_t)decision->action;
    out[5] = (uint8_t)decision->confirm;
    out[6] = (uint8_t)decision->execution;
    out[7] = (uint8_t)decision->reason;
    write_u32(&out[8], decision->timestamp_ms);
    return AB_DECISION_PAYLOAD_SIZE;
}

bool ab_decision_decode(const uint8_t *data, size_t length, ab_decision_t *decision)
{
    if (data == NULL || decision == NULL || length != AB_DECISION_PAYLOAD_SIZE) return false;
    decision->event_id = read_u32(&data[0]);
    decision->action = (hw_action_t)data[4];
    decision->confirm = (hw_confirm_state_t)data[5];
    decision->execution = (hw_execution_state_t)data[6];
    decision->reason = (ab_reason_t)data[7];
    decision->timestamp_ms = read_u32(&data[8]);
    return decision->action <= HW_ACTION_ALERT && decision->confirm <= HW_CONFIRM_OFFLINE &&
           decision->execution <= HW_EXEC_FAILED && decision->reason <= AB_REASON_BAD_MESSAGE;
}

size_t ab_ack_encode(const ab_ack_t *ack, uint8_t *out, size_t capacity)
{
    if (ack == NULL || out == NULL || capacity < AB_ACK_PAYLOAD_SIZE || ack->status > AB_ACK_BUSY)
        return 0U;
    write_u32(&out[0], ack->message_id);
    out[4] = (uint8_t)ack->status;
    return AB_ACK_PAYLOAD_SIZE;
}

bool ab_ack_decode(const uint8_t *data, size_t length, ab_ack_t *ack)
{
    if (data == NULL || ack == NULL || length != AB_ACK_PAYLOAD_SIZE) return false;
    ack->message_id = read_u32(&data[0]);
    ack->status = (ab_ack_status_t)data[4];
    return ack->status <= AB_ACK_BUSY;
}

size_t ab_auth_result_encode(const ab_auth_result_t *result, uint8_t *out, size_t capacity)
{
    if (result == NULL || out == NULL || capacity < AB_AUTH_RESULT_PAYLOAD_SIZE ||
        result->session_id == 0U ||
        result->auth > HW_REPLAY_SUSPECTED || result->reason > AB_REASON_BAD_MESSAGE)
        return 0U;
    write_u32(&out[0], result->session_id);
    write_u32(&out[4], result->card_id);
    write_u32(&out[8], result->permission_id);
    out[12] = (uint8_t)result->auth;
    out[13] = (uint8_t)result->reason;
    out[14] = 0U;
    out[15] = 0U;
    write_u32(&out[16], result->counter);
    return AB_AUTH_RESULT_PAYLOAD_SIZE;
}

bool ab_auth_result_decode(const uint8_t *data, size_t length, ab_auth_result_t *result)
{
    if (data == NULL || result == NULL || length != AB_AUTH_RESULT_PAYLOAD_SIZE) return false;
    result->session_id = read_u32(&data[0]);
    result->card_id = read_u32(&data[4]);
    result->permission_id = read_u32(&data[8]);
    result->auth = (hw_auth_result_t)data[12];
    result->reason = (ab_reason_t)data[13];
    result->counter = read_u32(&data[16]);
    return data[14] == 0U && data[15] == 0U && result->session_id != 0U &&
           result->auth <= HW_REPLAY_SUSPECTED && result->reason <= AB_REASON_BAD_MESSAGE;
}
