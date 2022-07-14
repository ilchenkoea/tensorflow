if(coremltools_POPULATED)
    return()
endif()

include(OverridableFetchContent)

OverridableFetchContent_Declare(
    coremltools
    URL https://github.com/apple/coremltools/archive/3.3.zip
    URL_HASH SHA256=0d594a714e8a5fd5bd740ad112ef59155c0482e25fdc8f8efa5758f90abdcf1e
    SOURCE_DIR "${CMAKE_BINARY_DIR}/coremltools-3.3/"
)

OverridableFetchContent_GetProperties(coremltools)

if(NOT coremltools_POPULATED)
    OverridableFetchContent_Populate(coremltools)
endif()

file(GLOB COREML_PROTO
        ${coremltools_SOURCE_DIR}/mlmodel/format/*.proto
        )

protobuf_generate(
        OUT_VAR COREMLTOOLS_PROTO_SRCS
        LANGUAGE cpp
        PROTOC_OUT_DIR ${CMAKE_CURRENT_BINARY_DIR}/mlmodel/format
        PROTOS ${COREML_PROTO}
        APPEND_PATH
)
include_directories(${CMAKE_CURRENT_BINARY_DIR})
