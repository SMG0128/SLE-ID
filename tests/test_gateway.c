#include <assert.h>
#include <stdio.h>
#include <string.h>

#include "detector_b_gateway.h"

#define CAPTURE_MAX 128U

typedef struct {
    ab_stream_parser_t parser;
    ab_frame_t frames[CAPTURE_MAX];
    uint16_t count;
    bool fail_tx;
    uint32_t policy_calls;
    uint32_t confirm_calls;
    uint32_t current_policy_version;
    bool online;
    uint32_t online_changes;
} gateway_fixture_t;

static void capture_frame(const ab_frame_t *frame, void *user)
{
    gateway_fixture_t *fixture = (gateway_fixture_t *)user;
    assert(fixture->count < CAPTURE_MAX);
    fixture->frames[fixture->count++] = *frame;
}

static bool capture_tx(const uint8_t *data, size_t length, void *user)
{
    gateway_fixture_t *fixture = (gateway_fixture_t *)user;
    if (fixture->fail_tx) return false;
    ab_parser_feed(&fixture->parser, data, length);
    return true;
}

static detector_b_gateway_status_t apply_policy(
    const detector_b_policy_command_t *command, void *user)
{
    gateway_fixture_t *fixture = (gateway_fixture_t *)user;
    fixture->policy_calls++;
    if (command->policy_version < fixture->current_policy_version)
        return DETECTOR_B_GATEWAY_STALE;
    fixture->current_policy_version = command->policy_version;
    return DETECTOR_B_GATEWAY_OK;
}

static detector_b_gateway_status_t apply_confirm(
    const detector_b_confirm_command_t *command, void *user)
{
    gateway_fixture_t *fixture = (gateway_fixture_t *)user;
    fixture->confirm_calls++;
    return command->result == HW_CONFIRM_APPROVED ?
        DETECTOR_B_GATEWAY_OK : DETECTOR_B_GATEWAY_INVALID;
}

static void online_changed(bool online, void *user)
{
    gateway_fixture_t *fixture = (gateway_fixture_t *)user;
    fixture->online = online;
    fixture->online_changes++;
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

static uint32_t read_u32(const uint8_t *data)
{
    return (uint32_t)data[0] | ((uint32_t)data[1] << 8) |
           ((uint32_t)data[2] << 16) | ((uint32_t)data[3] << 24);
}

static size_t host_frame(uint8_t type, uint32_t message_id,
                         const uint8_t *payload, uint16_t payload_length,
                         uint8_t *output)
{
    ab_frame_header_t header = { 0 };
    header.type = type;
    header.source_role = AB_ROLE_HOST;
    header.source_id = 0x48000001U;
    header.boot_id = 0x48000002U;
    header.message_id = message_id;
    return ab_frame_encode(&header, payload, payload_length, output, AB_MAX_FRAME);
}

static void fixture_init(detector_b_gateway_t *gateway, gateway_fixture_t *fixture)
{
    (void)memset(fixture, 0, sizeof(*fixture));
    ab_parser_init(&fixture->parser, capture_frame, fixture);
    detector_b_gateway_init(gateway, capture_tx, apply_policy, apply_confirm,
                            online_changed, fixture);
    detector_b_gateway_set_identity(gateway, 0xB0000042U, 0xB0070042U, 0x00010001U);
    gateway->next_heartbeat_ms = 100000U;
}

static hw_passage_event_t sample_event(uint32_t event_id)
{
    hw_passage_event_t event;
    (void)memset(&event, 0, sizeof(event));
    event.event_id = event_id;
    event.source_id = 0xA0000001U;
    event.boot_id = 0xA0070001U;
    event.card_anon_id = 0xCA000001U;
    event.permission_id = 7U;
    event.timestamp_ms = 1000U + event_id;
    event.distance_cm = 80U;
    event.confidence = 90U;
    event.direction = HW_DIRECTION_ENTER;
    event.state = HW_EVENT_COMPLETED;
    event.auth = HW_AUTHORIZED;
    return event;
}

static ab_decision_t sample_decision(uint32_t event_id, hw_action_t action)
{
    ab_decision_t decision;
    (void)memset(&decision, 0, sizeof(decision));
    decision.event_id = event_id;
    decision.action = action;
    decision.execution = action == HW_ACTION_EXECUTE ?
        HW_EXEC_SUCCESS : HW_EXEC_NOT_REQUESTED;
    decision.confirm = action == HW_ACTION_WAIT_CONFIRM ?
        HW_CONFIRM_PENDING : HW_CONFIRM_NOT_REQUIRED;
    decision.timestamp_ms = 2000U + event_id;
    return decision;
}

static void acknowledge(detector_b_gateway_t *gateway, uint32_t message_id,
                        uint32_t now_ms)
{
    ab_ack_t ack = { message_id, AB_ACK_ACCEPTED };
    uint8_t payload[AB_ACK_PAYLOAD_SIZE];
    uint8_t frame[AB_MAX_FRAME];
    size_t payload_length = ab_ack_encode(&ack, payload, sizeof(payload));
    size_t frame_length = host_frame(AB_MSG_ACK, message_id, payload,
                                     (uint16_t)payload_length, frame);
    detector_b_gateway_receive(gateway, frame, frame_length, now_ms);
}

static void test_reliable_offline_queue(void)
{
    detector_b_gateway_t gateway;
    gateway_fixture_t fixture;
    hw_passage_event_t event = sample_event(1U);
    ab_decision_t decision = sample_decision(1U, HW_ACTION_EXECUTE);
    uint32_t message_id;
    fixture_init(&gateway, &fixture);
    assert(detector_b_gateway_report(&gateway, &event, &decision));
    assert(detector_b_gateway_queue_depth(&gateway) == 1U);
    fixture.fail_tx = true;
    detector_b_gateway_tick(&gateway, 100U);
    assert(fixture.count == 0U && gateway.send_failures == 1U);
    fixture.fail_tx = false;
    detector_b_gateway_tick(&gateway, 600U);
    assert(fixture.count == 1U);
    assert(fixture.frames[0].header.type == AB_MSG_EVENT_REPORT);
    assert((fixture.frames[0].header.flags & AB_FLAG_RETRY) != 0U);
    assert(read_u32(&fixture.frames[0].payload[0]) == 1U);
    message_id = fixture.frames[0].header.message_id;
    detector_b_gateway_tick(&gateway, 1099U);
    assert(fixture.count == 1U);
    detector_b_gateway_tick(&gateway, 1100U);
    assert(fixture.count == 2U);
    assert(fixture.frames[1].header.message_id == message_id);
    acknowledge(&gateway, message_id, 1110U);
    assert(detector_b_gateway_queue_depth(&gateway) == 0U);
    assert(gateway.acknowledgements == 1U);
    assert(fixture.online && fixture.online_changes == 1U);
    detector_b_gateway_tick(&gateway, 6110U);
    assert(!fixture.online && fixture.online_changes == 2U);
}

static void make_policy_payload(uint8_t *payload, uint32_t request_id,
                                uint32_t policy_version, uint16_t flags)
{
    (void)memset(payload, 0, DETECTOR_B_POLICY_PAYLOAD_SIZE);
    write_u32(&payload[0], request_id);
    write_u32(&payload[4], 7U);
    write_u32(&payload[8], policy_version);
    write_u32(&payload[12], 100U);
    write_u16(&payload[16], flags);
}

static void test_policy_idempotency_and_rollback(void)
{
    detector_b_gateway_t gateway;
    gateway_fixture_t fixture;
    uint8_t payload[DETECTOR_B_POLICY_PAYLOAD_SIZE];
    uint8_t frame[AB_MAX_FRAME];
    size_t length;
    fixture_init(&gateway, &fixture);
    fixture.current_policy_version = 1U;
    detector_b_gateway_set_policy_version(&gateway, 1U);
    make_policy_payload(payload, 100U, 2U,
                        DETECTOR_B_POLICY_ALLOW_EXECUTION |
                        DETECTOR_B_POLICY_ALLOW_OFFLINE);
    length = host_frame(AB_MSG_POLICY_SYNC, 1U, payload, sizeof(payload), frame);
    detector_b_gateway_receive(&gateway, frame, length / 2U, 100U);
    detector_b_gateway_receive(&gateway, frame + length / 2U,
                               length - length / 2U, 101U);
    assert(fixture.policy_calls == 1U && gateway.policy_version == 2U);
    assert(fixture.frames[0].header.type == AB_MSG_POLICY_RESULT);
    assert(fixture.frames[0].payload[4] == DETECTOR_B_GATEWAY_OK);
    detector_b_gateway_receive(&gateway, frame, length, 102U);
    assert(fixture.policy_calls == 1U && gateway.duplicate_commands == 1U);
    assert(fixture.frames[1].payload[4] == DETECTOR_B_GATEWAY_OK);

    payload[16] ^= DETECTOR_B_POLICY_ADMIN_CONFIRM;
    length = host_frame(AB_MSG_POLICY_SYNC, 2U, payload, sizeof(payload), frame);
    detector_b_gateway_receive(&gateway, frame, length, 103U);
    assert(fixture.policy_calls == 1U && gateway.conflicting_commands == 1U);
    assert(fixture.frames[2].payload[4] == DETECTOR_B_GATEWAY_REQUEST_MISMATCH);

    make_policy_payload(payload, 101U, 1U, DETECTOR_B_POLICY_ALLOW_EXECUTION);
    length = host_frame(AB_MSG_POLICY_SYNC, 3U, payload, sizeof(payload), frame);
    detector_b_gateway_receive(&gateway, frame, length, 104U);
    assert(fixture.policy_calls == 2U);
    assert(fixture.frames[3].payload[4] == DETECTOR_B_GATEWAY_STALE);
    assert(gateway.policy_version == 2U);
}

static void test_confirmation_and_alert(void)
{
    detector_b_gateway_t gateway;
    gateway_fixture_t fixture;
    hw_passage_event_t event = sample_event(9U);
    ab_decision_t pending = sample_decision(9U, HW_ACTION_WAIT_CONFIRM);
    uint8_t result[DETECTOR_B_CONFIRM_RESULT_SIZE];
    uint8_t frame[AB_MAX_FRAME];
    size_t length;
    uint32_t event_message_id;
    uint32_t confirm_message_id;
    uint32_t request_id;
    fixture_init(&gateway, &fixture);
    assert(detector_b_gateway_report(&gateway, &event, &pending));
    assert(detector_b_gateway_queue_depth(&gateway) == 2U);
    detector_b_gateway_tick(&gateway, 100U);
    assert(fixture.frames[0].header.type == AB_MSG_EVENT_REPORT);
    event_message_id = fixture.frames[0].header.message_id;
    acknowledge(&gateway, event_message_id, 110U);
    detector_b_gateway_tick(&gateway, 111U);
    assert(fixture.frames[1].header.type == AB_MSG_CONFIRM_REQUEST);
    assert(fixture.frames[1].payload_length == DETECTOR_B_CONFIRM_REQUEST_SIZE);
    request_id = read_u32(&fixture.frames[1].payload[0]);
    assert(read_u32(&fixture.frames[1].payload[4]) == event.event_id);
    confirm_message_id = fixture.frames[1].header.message_id;
    acknowledge(&gateway, confirm_message_id, 112U);

    write_u32(&result[0], request_id);
    write_u32(&result[4], event.event_id);
    result[8] = HW_CONFIRM_APPROVED;
    length = host_frame(AB_MSG_CONFIRM_RESULT, 10U, result, sizeof(result), frame);
    detector_b_gateway_receive(&gateway, frame, length, 120U);
    assert(fixture.confirm_calls == 1U && !gateway.confirm_request_active);
    assert(fixture.frames[2].header.type == AB_MSG_COMMAND_RESULT);
    assert(fixture.frames[2].payload[5] == DETECTOR_B_GATEWAY_OK);
    detector_b_gateway_receive(&gateway, frame, length, 121U);
    assert(fixture.confirm_calls == 1U && gateway.duplicate_commands == 1U);

    pending = sample_decision(10U, HW_ACTION_ALERT);
    pending.reason = AB_REASON_REPLAY_SUSPECTED;
    event = sample_event(10U);
    assert(detector_b_gateway_report(&gateway, &event, &pending));
    assert(detector_b_gateway_queue_depth(&gateway) == 2U);
    assert(gateway.queue[gateway.queue_head].type == AB_MSG_EVENT_REPORT);
    assert(gateway.queue[(gateway.queue_head + 1U) %
                         DETECTOR_B_GATEWAY_QUEUE_CAPACITY].type == AB_MSG_ALERT_REPORT);
}

static void test_policy_and_device_request_id_namespaces(void)
{
    detector_b_gateway_t gateway;
    gateway_fixture_t fixture;
    hw_passage_event_t event = sample_event(20U);
    ab_decision_t pending = sample_decision(20U, HW_ACTION_WAIT_CONFIRM);
    uint8_t policy[DETECTOR_B_POLICY_PAYLOAD_SIZE];
    uint8_t result[DETECTOR_B_CONFIRM_RESULT_SIZE];
    uint8_t frame[AB_MAX_FRAME];
    size_t length;
    uint32_t event_message_id;
    uint32_t confirm_message_id;

    fixture_init(&gateway, &fixture);
    fixture.current_policy_version = 1U;
    detector_b_gateway_set_policy_version(&gateway, 1U);
    make_policy_payload(policy, 1U, 2U, DETECTOR_B_POLICY_ADMIN_CONFIRM);
    length = host_frame(AB_MSG_POLICY_SYNC, 1U, policy, sizeof(policy), frame);
    detector_b_gateway_receive(&gateway, frame, length, 10U);
    assert(fixture.policy_calls == 1U);

    assert(detector_b_gateway_report(&gateway, &event, &pending));
    detector_b_gateway_tick(&gateway, 20U);
    event_message_id = fixture.frames[1].header.message_id;
    acknowledge(&gateway, event_message_id, 21U);
    detector_b_gateway_tick(&gateway, 22U);
    assert(fixture.frames[2].header.type == AB_MSG_CONFIRM_REQUEST);
    assert(read_u32(&fixture.frames[2].payload[0]) == 1U);
    confirm_message_id = fixture.frames[2].header.message_id;
    acknowledge(&gateway, confirm_message_id, 23U);

    write_u32(&result[0], 1U);
    write_u32(&result[4], event.event_id);
    result[8] = HW_CONFIRM_APPROVED;
    length = host_frame(AB_MSG_CONFIRM_RESULT, 2U, result, sizeof(result), frame);
    detector_b_gateway_receive(&gateway, frame, length, 24U);
    assert(fixture.confirm_calls == 1U);
    assert(fixture.frames[3].header.type == AB_MSG_COMMAND_RESULT);
    assert(fixture.frames[3].payload[5] == DETECTOR_B_GATEWAY_OK);
}

static void test_stale_confirm_removed_from_queue(void)
{
    detector_b_gateway_t gateway;
    gateway_fixture_t fixture;
    hw_passage_event_t event = sample_event(21U);
    ab_decision_t pending = sample_decision(21U, HW_ACTION_WAIT_CONFIRM);
    ab_decision_t timeout = sample_decision(21U, HW_ACTION_DENY);
    uint8_t i;

    fixture_init(&gateway, &fixture);
    assert(detector_b_gateway_report(&gateway, &event, &pending));
    assert(gateway.confirm_request_active && gateway.queue_count == 2U);
    timeout.confirm = HW_CONFIRM_TIMEOUT;
    timeout.reason = AB_REASON_CONFIRM_TIMEOUT;
    assert(detector_b_gateway_report(&gateway, &event, &timeout));
    assert(!gateway.confirm_request_active);
    assert(gateway.queue_count == 3U);
    for (i = 0U; i < gateway.queue_count; ++i) {
        uint8_t index = (uint8_t)((gateway.queue_head + i) %
                                  DETECTOR_B_GATEWAY_QUEUE_CAPACITY);
        assert(gateway.queue[index].type != AB_MSG_CONFIRM_REQUEST);
    }
}

static void test_full_queue_does_not_create_undeliverable_confirm(void)
{
    detector_b_gateway_t gateway;
    gateway_fixture_t fixture;
    uint32_t i;
    hw_passage_event_t event;
    ab_decision_t pending;

    fixture_init(&gateway, &fixture);
    for (i = 1U; i < DETECTOR_B_GATEWAY_QUEUE_CAPACITY; ++i) {
        event = sample_event(i);
        pending = sample_decision(i, HW_ACTION_RECORD);
        assert(detector_b_gateway_report(&gateway, &event, &pending));
    }
    event = sample_event(100U);
    pending = sample_decision(100U, HW_ACTION_WAIT_CONFIRM);
    assert(!detector_b_gateway_report(&gateway, &event, &pending));
    assert(gateway.queue_count == DETECTOR_B_GATEWAY_QUEUE_CAPACITY);
    assert(!gateway.confirm_request_active);
}

static void test_queue_capacity(void)
{
    detector_b_gateway_t gateway;
    gateway_fixture_t fixture;
    uint32_t i;
    fixture_init(&gateway, &fixture);
    for (i = 1U; i <= DETECTOR_B_GATEWAY_QUEUE_CAPACITY; ++i) {
        hw_passage_event_t event = sample_event(i);
        ab_decision_t decision = sample_decision(i, HW_ACTION_RECORD);
        assert(detector_b_gateway_report(&gateway, &event, &decision));
    }
    {
        hw_passage_event_t event = sample_event(99U);
        ab_decision_t decision = sample_decision(99U, HW_ACTION_RECORD);
        assert(!detector_b_gateway_report(&gateway, &event, &decision));
    }
    assert(detector_b_gateway_queue_depth(&gateway) ==
           DETECTOR_B_GATEWAY_QUEUE_CAPACITY);
    assert(gateway.queue_overflows == 1U);
}

int main(void)
{
    test_reliable_offline_queue();
    test_policy_idempotency_and_rollback();
    test_confirmation_and_alert();
    test_policy_and_device_request_id_namespaces();
    test_stale_confirm_removed_from_queue();
    test_full_queue_does_not_create_undeliverable_confirm();
    test_queue_capacity();
    puts("All Detector B single-USB gateway tests passed.");
    return 0;
}
