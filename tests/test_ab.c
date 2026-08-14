#include <assert.h>
#include <stdio.h>
#include <string.h>

#include "ab_messages.h"
#include "ab_protocol.h"
#include "detector_a_core.h"
#include "detector_b_core.h"

typedef struct {
    detector_a_t a;
    detector_b_t b;
    uint32_t now_ms;
    unsigned actuator_count;
    unsigned report_count;
    unsigned drop_a_frames;
    unsigned drop_b_ack_frames;
    unsigned drop_b_decision_frames;
    bool auto_grant;
    uint32_t next_auth_session;
    ab_decision_t last_report;
    hw_passage_event_t last_event;
} test_link_t;

static bool authorize_event(const hw_passage_event_t *event, void *user)
{
    test_link_t *link = (test_link_t *)user;
    (void)link;
    return event->auth == HW_AUTHORIZED && event->auth_session_id != 0U &&
           event->permission_id == 7U && event->auth_counter != 0U;
}

static void grant_once(test_link_t *link)
{
    ab_auth_result_t result = { 0 };
    result.session_id = ++link->next_auth_session;
    result.card_id = 0xCA000001U;
    result.permission_id = 7U;
    result.auth = HW_AUTHORIZED;
    result.reason = AB_REASON_NONE;
    result.counter = result.session_id;
    assert(detector_a_set_auth_result(&link->a, &result));
}

static bool a_to_b(const uint8_t *data, size_t length, void *user)
{
    test_link_t *link = (test_link_t *)user;
    if (link->drop_a_frames != 0U) {
        link->drop_a_frames--;
        return false;
    }
    detector_b_receive(&link->b, data, length, link->now_ms);
    return true;
}

static bool b_to_a(const uint8_t *data, size_t length, void *user)
{
    test_link_t *link = (test_link_t *)user;
    assert(length >= AB_FRAME_OVERHEAD);
    if (data[3] == AB_MSG_ACK && link->drop_b_ack_frames != 0U) {
        link->drop_b_ack_frames--;
        return false;
    }
    if (data[3] == AB_MSG_DECISION && link->drop_b_decision_frames != 0U) {
        link->drop_b_decision_frames--;
        return false;
    }
    detector_a_receive(&link->a, data, length);
    return true;
}

static bool actuator(uint32_t event_id, void *user)
{
    test_link_t *link = (test_link_t *)user;
    assert(event_id != 0U);
    link->actuator_count++;
    return true;
}

static void report(const hw_passage_event_t *event, const ab_decision_t *decision, void *user)
{
    test_link_t *link = (test_link_t *)user;
    assert(event->event_id == decision->event_id);
    link->report_count++;
    link->last_report = *decision;
    link->last_event = *event;
}

static void link_init(test_link_t *link)
{
    memset(link, 0, sizeof(*link));
    detector_a_init(&link->a, a_to_b, NULL, link);
    detector_b_init(&link->b, b_to_a, actuator, report, link);
    detector_b_set_authorizer(&link->b, authorize_event);
    detector_a_set_identity(&link->a, 0xA0000042U, 0x11110001U);
    detector_b_set_identity(&link->b, 0xB0000042U, 0x22220001U);
    link->b.permission.permission_id = 7U;
    link->auto_grant = true;
}

static passage_result_t observe(test_link_t *link, uint32_t now, bool seen, bool z1, bool z2)
{
    passage_observation_t obs = { seen, z1, z2, 80U, 90U, HW_DIRECTION_ENTER };
    link->now_ms = now;
    return detector_a_observe(&link->a, &obs, now);
}

static void valid_enter(test_link_t *link, uint32_t base)
{
    if (link->auto_grant) grant_once(link);
    assert(observe(link, base, true, false, false) == PASSAGE_NO_OUTPUT);
    assert(observe(link, base + 100U, true, true, false) == PASSAGE_NO_OUTPUT);
    assert(observe(link, base + 200U, true, true, true) == PASSAGE_COMPLETED);
}

static size_t make_passage_frame(uint32_t source_id, uint32_t boot_id, uint32_t message_id,
                                 uint32_t event_id, uint8_t *frame, size_t capacity)
{
    hw_passage_event_t event;
    ab_frame_header_t header;
    uint8_t payload[AB_MAX_PAYLOAD];
    size_t payload_len;
    memset(&event, 0, sizeof(event));
    event.event_id = event_id;
    event.card_anon_id = 0xCA000001U;
    event.timestamp_ms = 1234U;
    event.distance_cm = 80U;
    event.confidence = 95U;
    event.direction = HW_DIRECTION_ENTER;
    event.state = HW_EVENT_COMPLETED;
    event.auth = HW_AUTHORIZED;
    header.type = AB_MSG_PASSAGE_EVENT;
    header.flags = AB_FLAG_ACK_REQUIRED;
    header.source_role = AB_ROLE_DETECTOR_A;
    header.source_id = source_id;
    header.boot_id = boot_id;
    header.message_id = message_id;
    payload_len = ab_passage_encode(&event, payload, sizeof(payload));
    return ab_frame_encode(&header, payload, (uint16_t)payload_len, frame, capacity);
}

static unsigned parser_frames;
static void parser_callback(const ab_frame_t *frame, void *user)
{
    const char *expected = (const char *)user;
    assert(frame->header.type == AB_MSG_HEARTBEAT);
    assert(frame->header.flags == AB_FLAG_ACK_REQUIRED);
    assert(frame->header.source_role == AB_ROLE_HOST);
    assert(frame->header.source_id == 0x12345678U);
    assert(frame->header.boot_id == 0xABCDEF01U);
    assert(frame->header.message_id == 7U);
    assert(frame->payload_length == strlen(expected));
    assert(memcmp(frame->payload, expected, frame->payload_length) == 0);
    parser_frames++;
}

static void test_protocol(void)
{
    uint8_t frame[AB_MAX_FRAME];
    uint8_t bad[AB_MAX_FRAME];
    const uint8_t noise[] = { 0x00U, 0x53U, 0x00U, 0xFFU };
    const uint8_t payload[] = "fragmented";
    ab_frame_header_t header = {
        AB_MSG_HEARTBEAT, AB_FLAG_ACK_REQUIRED, AB_ROLE_HOST,
        0x12345678U, 0xABCDEF01U, 7U
    };
    size_t length = ab_frame_encode(&header, payload, sizeof(payload) - 1U, frame, sizeof(frame));
    ab_stream_parser_t parser;
    assert(length == AB_FRAME_OVERHEAD + sizeof(payload) - 1U);
    parser_frames = 0U;
    ab_parser_init(&parser, parser_callback, (void *)payload);
    ab_parser_feed(&parser, noise, sizeof(noise));
    ab_parser_feed(&parser, frame, 3U);
    ab_parser_feed(&parser, frame + 3U, length - 3U);
    assert(parser_frames == 1U);

    memcpy(bad, frame, length);
    bad[length - 1U] ^= 1U;
    ab_parser_feed(&parser, bad, length);
    ab_parser_feed(&parser, frame, length);
    assert(parser.crc_errors == 1U);
    assert(parser_frames == 2U);

    memcpy(bad, frame, length);
    bad[2] = 0xFFU;
    ab_parser_feed(&parser, bad, AB_FRAME_HEADER_SIZE);
    ab_parser_feed(&parser, frame, length);
    assert(parser.format_errors == 1U);
    assert(parser_frames == 3U);
}

static void test_execute_and_filter(void)
{
    test_link_t link;
    link_init(&link);
    valid_enter(&link, 1000U);
    assert(link.a.sent_events == 1U);
    assert(link.a.acknowledged_events == 1U);
    assert(!link.a.pending_active);
    assert(link.b.received_events == 1U);
    assert(link.last_event.source_id == link.a.source_id);
    assert(link.last_event.boot_id == link.a.boot_id);
    assert(link.actuator_count == 1U);
    assert(link.last_report.action == HW_ACTION_EXECUTE);
    assert(link.last_report.execution == HW_EXEC_SUCCESS);

    (void)observe(&link, 1300U, true, false, false);
    (void)observe(&link, 1400U, true, true, false);
    (void)observe(&link, 1500U, true, true, true);
    assert(link.a.sent_events == 1U);

    assert(observe(&link, 3000U, true, false, false) == PASSAGE_NO_OUTPUT);
    assert(observe(&link, 3100U, true, false, true) == PASSAGE_CANCELLED);
    assert(link.b.received_events == 1U);
}

static void test_ack_retry_and_dedup(void)
{
    test_link_t link;
    uint8_t frame[AB_MAX_FRAME];
    size_t length;
    link_init(&link);
    link.drop_b_ack_frames = 1U;
    link.drop_b_decision_frames = 1U;
    valid_enter(&link, 1000U);
    assert(link.a.pending_active);
    assert(link.b.received_events == 1U);
    assert(link.actuator_count == 1U);
    link.now_ms = 1700U;
    detector_a_tick(&link.a, link.now_ms);
    assert(!link.a.pending_active);
    assert(link.a.retry_attempts == 1U);
    assert(link.a.acknowledged_events == 1U);
    assert(link.b.received_events == 1U);
    assert(link.b.duplicate_events == 1U);
    assert(link.actuator_count == 1U);

    length = make_passage_frame(0xA1U, 0xB1U, 10U, 1U, frame, sizeof(frame));
    detector_b_receive(&link.b, frame, length, 3000U);
    length = make_passage_frame(0xA1U, 0xB1U, 11U, 2U, frame, sizeof(frame));
    detector_b_receive(&link.b, frame, length, 3100U);
    length = make_passage_frame(0xA1U, 0xB1U, 12U, 1U, frame, sizeof(frame));
    detector_b_receive(&link.b, frame, length, 3200U);
    assert(link.b.received_events == 3U);
    assert(link.b.duplicate_events == 2U);

    length = make_passage_frame(0xA1U, 0xB2U, 13U, 1U, frame, sizeof(frame));
    detector_b_receive(&link.b, frame, length, 3300U);
    assert(link.b.received_events == 4U);
}

static void test_retry_exhaustion(void)
{
    test_link_t link;
    unsigned i;
    link_init(&link);
    link.drop_a_frames = 4U;
    valid_enter(&link, 1000U);
    assert(link.a.pending_active);
    for (i = 1U; i <= 4U; ++i) {
        link.now_ms = 1200U + i * DETECTOR_A_ACK_TIMEOUT_MS;
        detector_a_tick(&link.a, link.now_ms);
    }
    assert(!link.a.pending_active);
    assert(link.a.retry_attempts == DETECTOR_A_MAX_RETRIES);
    assert(link.a.retry_exhausted == 1U);
    assert(link.a.send_failures == 4U);
    assert(link.b.received_events == 0U);
}

static void test_unbound_authorization_rejected(void)
{
    test_link_t link;
    link_init(&link);
    link.auto_grant = false;
    detector_a_set_auth(&link.a, HW_AUTHORIZED);
    valid_enter(&link, 1000U);
    assert(link.actuator_count == 0U);
    assert(link.last_event.auth == HW_UNAUTHORIZED);
    assert(link.last_report.action == HW_ACTION_ALERT);
    assert(link.last_report.reason == AB_REASON_NO_PERMISSION);
}

static void test_security_confirmation_and_busy(void)
{
    test_link_t link;
    uint32_t pending_event_id;
    link_init(&link);
    link.auto_grant = false;
    detector_a_set_auth(&link.a, HW_KEY_FAILED);
    valid_enter(&link, 1000U);
    assert(link.last_report.action == HW_ACTION_ALERT);
    assert(link.last_report.reason == AB_REASON_NO_PERMISSION);
    assert(link.actuator_count == 0U);

    link.auto_grant = true;
    link.b.permission.admin_confirm_required = true;
    valid_enter(&link, 3000U);
    assert(link.b.pending_valid);
    pending_event_id = link.b.pending_event.event_id;
    assert(link.last_report.action == HW_ACTION_WAIT_CONFIRM);
    valid_enter(&link, 5000U);
    assert(link.b.pending_valid);
    assert(link.b.pending_event.event_id == pending_event_id);
    assert(link.last_report.reason == AB_REASON_BUSY);
    assert(link.b.busy_events == 1U);
    assert(detector_b_confirm(&link.b, true, 5300U));
    assert(link.last_report.confirm == HW_CONFIRM_APPROVED);
    assert(link.last_report.execution == HW_EXEC_SUCCESS);
    assert(link.actuator_count == 1U);

    valid_enter(&link, 7000U);
    assert(link.b.pending_valid);
    assert(!detector_b_confirm(&link.b, true, 17201U));
    assert(!link.b.pending_valid);
    assert(link.last_report.confirm == HW_CONFIRM_TIMEOUT);
    assert(link.last_report.reason == AB_REASON_CONFIRM_TIMEOUT);
    assert(link.actuator_count == 1U);
}

static void test_offline_reason_and_tx_failure(void)
{
    test_link_t link;
    link_init(&link);
    link.b.permission.allow_offline = false;
    link.b.policy_input.backend_online = false;
    link.drop_b_decision_frames = 1U;
    valid_enter(&link, 1000U);
    assert(link.last_report.action == HW_ACTION_DENY);
    assert(link.last_report.reason == AB_REASON_BACKEND_OFFLINE);
    assert(link.b.decision_send_failures == 1U);
    assert(link.actuator_count == 0U);
}

int main(void)
{
    test_protocol();
    test_execute_and_filter();
    test_ack_retry_and_dedup();
    test_unbound_authorization_rejected();
    test_retry_exhaustion();
    test_security_confirmation_and_busy();
    test_offline_reason_and_tx_failure();
    puts("All SLE A/B protocol V2 and core tests passed.");
    return 0;
}
