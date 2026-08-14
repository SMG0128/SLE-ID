#ifndef SLE_PASSAGE_FSM_H
#define SLE_PASSAGE_FSM_H

#include "hw_types.h"

typedef struct {
    uint8_t min_confidence;
    uint32_t approach_timeout_ms;
    uint32_t in_zone_timeout_ms;
    uint32_t cooldown_ms;
} passage_fsm_config_t;

typedef struct {
    hw_event_state_t state;
    uint32_t state_since_ms;
    uint32_t cooldown_until_ms;
    passage_fsm_config_t config;
} passage_fsm_t;

typedef struct {
    bool target_seen;
    bool first_zone_active;
    bool second_zone_active;
    uint16_t distance_cm;
    uint8_t confidence;
    hw_direction_t direction_hint;
} passage_observation_t;

typedef enum { PASSAGE_NO_OUTPUT = 0, PASSAGE_COMPLETED, PASSAGE_CANCELLED } passage_result_t;

void passage_fsm_init(passage_fsm_t *fsm, const passage_fsm_config_t *config);
passage_result_t passage_fsm_step(passage_fsm_t *fsm, const passage_observation_t *obs,
                                  uint32_t now_ms, hw_passage_event_t *completed_event);

#endif
