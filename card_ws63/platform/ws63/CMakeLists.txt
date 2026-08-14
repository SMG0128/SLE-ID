set(SOURCES_LIST
    ${CMAKE_CURRENT_SOURCE_DIR}/../../src/credential_store.c
    ${CMAKE_CURRENT_SOURCE_DIR}/../../src/card_service.c
    ${CMAKE_CURRENT_SOURCE_DIR}/../../src/card_crypto.c
    ${CMAKE_CURRENT_SOURCE_DIR}/../../src/card_auth.c
    ${CMAKE_CURRENT_SOURCE_DIR}/ws63_card_nv_port.c
    ${CMAKE_CURRENT_SOURCE_DIR}/ws63_card_sle_server.c
)

set(HEADER_LIST
    ${CMAKE_CURRENT_SOURCE_DIR}/../../include
    ${CMAKE_CURRENT_SOURCE_DIR}/../../../common/include
    ${CMAKE_CURRENT_SOURCE_DIR}
)

set(SOURCES "${SOURCES}" ${SOURCES_LIST} PARENT_SCOPE)
set(PUBLIC_HEADER "${PUBLIC_HEADER}" ${HEADER_LIST} PARENT_SCOPE)
