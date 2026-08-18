#include "passage_fsm.h"

#include <string.h>

void passage_fsm_init(passage_fsm_t *fsm, const passage_fsm_config_t *config)
{
    /* The default cooldown keeps demo-driven sequences snappy. When a target
     * stays in range continuously (e.g. RSSI-driven proximity), a longer
     * cooldown prevents an event storm; the A firmware overrides this via
     * detector_a_set_passage_config() for RSSI mode. */
    static const passage_fsm_config_t defaults = { 50U, 2000U, 2500U, 8000U };
    if (fsm == NULL) return;
    (void)memset(fsm, 0, sizeof(*fsm));
    fsm->state = HW_EVENT_IDLE;
    fsm->config = config != NULL ? *config : defaults;
}

static passage_result_t cancel_event(passage_fsm_t *fsm, uint32_t now_ms)
{
    fsm->state = HW_EVENT_COOLDOWN;
    fsm->cooldown_until_ms = now_ms + fsm->config.cooldown_ms;
    return PASSAGE_CANCELLED;
}

passage_result_t passage_fsm_step(passage_fsm_t *fsm, const passage_observation_t *obs,
                                  uint32_t now_ms, hw_passage_event_t *event)
{
    if (fsm == NULL || obs == NULL) return PASSAGE_NO_OUTPUT;
    if (fsm->state == HW_EVENT_COOLDOWN) {
        if ((int32_t)(now_ms - fsm->cooldown_until_ms) >= 0) fsm->state = HW_EVENT_IDLE;
        else return PASSAGE_NO_OUTPUT;
    }
    if (fsm->state == HW_EVENT_IDLE) {
        if (obs->target_seen && obs->confidence >= fsm->config.min_confidence) {
            fsm->state = HW_EVENT_APPROACHING;
            fsm->state_since_ms = now_ms;
        }
        return PASSAGE_NO_OUTPUT;
    }
    if (fsm->state == HW_EVENT_APPROACHING) {
        if (obs->second_zone_active && !obs->first_zone_active) return cancel_event(fsm, now_ms);
        if (obs->first_zone_active) {
            fsm->state = HW_EVENT_IN_ZONE;
            fsm->state_since_ms = now_ms;
            return PASSAGE_NO_OUTPUT;
        }
        if (!obs->target_seen || now_ms - fsm->state_since_ms > fsm->config.approach_timeout_ms)
            return cancel_event(fsm, now_ms);
    } else if (fsm->state == HW_EVENT_IN_ZONE) {
        if (obs->second_zone_active) {
            if (event != NULL) {
                event->timestamp_ms = now_ms;
                event->distance_cm = obs->distance_cm;
                event->confidence = obs->confidence;
                event->direction = obs->direction_hint;
                event->state = HW_EVENT_COMPLETED;
            }
            fsm->state = HW_EVENT_COOLDOWN;
            fsm->cooldown_until_ms = now_ms + fsm->config.cooldown_ms;
            return PASSAGE_COMPLETED;
        }
        if (!obs->target_seen || now_ms - fsm->state_since_ms > fsm->config.in_zone_timeout_ms)
            return cancel_event(fsm, now_ms);
    }
    return PASSAGE_NO_OUTPUT;
}
