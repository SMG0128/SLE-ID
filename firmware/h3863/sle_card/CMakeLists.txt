# Independent WS63/H3863 Card C sample.
set(SOURCES_LIST
    ${CMAKE_CURRENT_SOURCE_DIR}/h3863_sle_card.c
    ${CMAKE_CURRENT_SOURCE_DIR}/../common/src/ab_protocol.c
    ${CMAKE_CURRENT_SOURCE_DIR}/../card_ws63/src/credential_store.c
    ${CMAKE_CURRENT_SOURCE_DIR}/../card_ws63/src/card_service.c
    ${CMAKE_CURRENT_SOURCE_DIR}/../card_ws63/src/card_crypto.c
    ${CMAKE_CURRENT_SOURCE_DIR}/../card_ws63/src/card_auth.c
    ${CMAKE_CURRENT_SOURCE_DIR}/../card_ws63/platform/ws63/ws63_card_sle_server.c
)

if(DEFINED CONFIG_SLE_CARD_STORE_NV)
    list(APPEND SOURCES_LIST
        ${CMAKE_CURRENT_SOURCE_DIR}/../card_ws63/platform/ws63/ws63_card_nv_port.c
    )
endif()

set(HEADER_LIST
    ${CMAKE_CURRENT_SOURCE_DIR}/../common/include
    ${CMAKE_CURRENT_SOURCE_DIR}/../card_ws63/include
    ${CMAKE_CURRENT_SOURCE_DIR}/../card_ws63/platform/ws63
)

set(SOURCES "${SOURCES}" ${SOURCES_LIST} PARENT_SCOPE)
set(PUBLIC_HEADER "${PUBLIC_HEADER}" ${HEADER_LIST} PARENT_SCOPE)
