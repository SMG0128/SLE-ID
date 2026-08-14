# SLE A/B detector sample for fbb_ws63.
set(SLE_AB_ROOT ${CMAKE_CURRENT_SOURCE_DIR}/../../../..)
set(SLE_UART_SAMPLE ${SLE_AB_ROOT}/application/samples/bt/sle/sle_uart)

set(SOURCES_LIST
    ${CMAKE_CURRENT_SOURCE_DIR}/h3863_sle_ab.c
    ${CMAKE_CURRENT_SOURCE_DIR}/../common/src/ab_protocol.c
    ${CMAKE_CURRENT_SOURCE_DIR}/../common/src/ab_messages.c
)

set(HEADER_LIST
    ${CMAKE_CURRENT_SOURCE_DIR}/../common/include
)

if(DEFINED CONFIG_SLE_AB_ROLE_A)
    list(APPEND SOURCES_LIST
        ${CMAKE_CURRENT_SOURCE_DIR}/sle_ab_dual_client.c
        ${CMAKE_CURRENT_SOURCE_DIR}/../detector_a/src/passage_fsm.c
        ${CMAKE_CURRENT_SOURCE_DIR}/../detector_a/src/detector_a_core.c
        ${CMAKE_CURRENT_SOURCE_DIR}/../detector_a/src/detector_a_auth_relay.c
    )
    list(APPEND HEADER_LIST
        ${CMAKE_CURRENT_SOURCE_DIR}
        ${CMAKE_CURRENT_SOURCE_DIR}/../detector_a/include
        ${CMAKE_CURRENT_SOURCE_DIR}/../card_ws63/platform/ws63
    )
elseif(DEFINED CONFIG_SLE_AB_ROLE_B)
    list(APPEND SOURCES_LIST
        ${CMAKE_CURRENT_SOURCE_DIR}/../detector_b/src/policy_engine.c
        ${CMAKE_CURRENT_SOURCE_DIR}/../detector_b/src/detector_b_core.c
        ${CMAKE_CURRENT_SOURCE_DIR}/../detector_b/src/detector_b_auth.c
        ${CMAKE_CURRENT_SOURCE_DIR}/../detector_b/src/detector_b_gateway.c
        ${CMAKE_CURRENT_SOURCE_DIR}/../card_ws63/src/card_crypto.c
        ${SLE_UART_SAMPLE}/sle_uart_server/src/sle_uart_server.c
        ${SLE_UART_SAMPLE}/sle_uart_server/src/sle_uart_server_adv.c
    )
    list(APPEND HEADER_LIST
        ${CMAKE_CURRENT_SOURCE_DIR}/../detector_b/include
        ${CMAKE_CURRENT_SOURCE_DIR}/../card_ws63/include
        ${SLE_UART_SAMPLE}/sle_uart_server/src
    )
endif()

set(SOURCES "${SOURCES}" ${SOURCES_LIST} PARENT_SCOPE)
set(PUBLIC_HEADER "${PUBLIC_HEADER}" ${HEADER_LIST} PARENT_SCOPE)
