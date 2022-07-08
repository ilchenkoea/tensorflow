#
# Copyright 2021 The TensorFlow Authors. All Rights Reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      https://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

cmake_minimum_required(VERSION 3.16)
project(tensorflow-lite-c C CXX)

option(TFLITE_C_BUILD_SHARED_LIBS "Build shared libraries" ON)

set(TENSORFLOW_SOURCE_DIR "" CACHE PATH
  "Directory that contains the TensorFlow project"
)
if (NOT TENSORFLOW_SOURCE_DIR)
  get_filename_component(TENSORFLOW_SOURCE_DIR
    "${CMAKE_CURRENT_LIST_DIR}/../../../"
    ABSOLUTE
  )
endif()

add_subdirectory(
  "${TENSORFLOW_SOURCE_DIR}/tensorflow/lite"
  "${CMAKE_CURRENT_BINARY_DIR}/tensorflow-lite"
  EXCLUDE_FROM_ALL
)

set(CMAKE_CXX_STANDARD 11)

if(CMAKE_SYSTEM_NAME MATCHES "Windows"
    AND (MSVC AND (CMAKE_SIZEOF_VOID_P EQUAL 4)))
  message("Disabling MSVC /O2 optimization for Win32")
  set(CompFlags
    CMAKE_CXX_FLAGS_RELEASE
    CMAKE_CXX_FLAGS_MINSIZEREL
    CMAKE_CXX_FLAGS_RELWITHDEBINFO
    CMAKE_C_FLAGS_RELEASE
    CMAKE_C_FLAGS_MINSIZEREL
    CMAKE_C_FLAGS_RELWITHDEBINFO
  )
  foreach (CompFlag ${CompFlags})
    string(REGEX REPLACE "(\/Ob. )" "" ${CompFlag} "${${CompFlag}}")
    string(REPLACE "/O2" "/O1" ${CompFlag} "${${CompFlag}}")
    list(REMOVE_DUPLICATES ${CompFlag})
    set(${CompFlag} "${${CompFlag}}" CACHE INTERNAL "")
  endforeach()
endif()

set(TFLITE_C_LIBTYPE STATIC)
if (TFLITE_C_BUILD_SHARED_LIBS)
  set(TFLITE_C_LIBTYPE SHARED)
endif()

add_library(tensorflowlite_c ${TFLITE_C_LIBTYPE}
  builtin_op_data.h
  common.h
  common.cc
  c_api_types.h
  c_api.h
  c_api.cc
  c_api_experimental.h
  c_api_experimental.cc
  c_api_internal.h
)

if (TFLITE_C_BUILD_SHARED_LIBS)
  if (WIN32)
    target_compile_definitions(tensorflowlite_c PRIVATE TFL_COMPILE_LIBRARY)
  elseif (APPLE)
    target_link_options(tensorflowlite_c PRIVATE "-Wl,-exported_symbols_list,${TENSORFLOW_SOURCE_DIR}/tensorflow/lite/c/exported_symbols.lds")
  else ()
    target_link_options(tensorflowlite_c PRIVATE "-Wl,--version-script,${TENSORFLOW_SOURCE_DIR}/tensorflow/lite/c/version_script.lds")
  endif()
endif()

target_link_libraries(tensorflowlite_c
  tensorflow-lite
)

function(bundle_static_library tgt_name bundled_tgt_name)
  list(APPEND static_libs ${tgt_name})

  function(_recursively_collect_dependencies input_target)
    set(_input_link_libraries LINK_LIBRARIES)
    get_target_property(_input_type ${input_target} TYPE)
    if (${_input_type} STREQUAL "INTERFACE_LIBRARY")
      set(_input_link_libraries INTERFACE_LINK_LIBRARIES)
    endif()
    get_target_property(public_dependencies ${input_target} ${_input_link_libraries})
    foreach(dependency IN LISTS public_dependencies)
      if(TARGET ${dependency})
        get_target_property(alias ${dependency} ALIASED_TARGET)
        if (TARGET ${alias})
          set(dependency ${alias})
        endif()
        get_target_property(_type ${dependency} TYPE)
        if (${_type} STREQUAL "STATIC_LIBRARY")
          list(APPEND static_libs ${dependency})
        endif()

        get_property(library_already_added
                GLOBAL PROPERTY _${tgt_name}_static_bundle_${dependency})
        if (NOT library_already_added)
          set_property(GLOBAL PROPERTY _${tgt_name}_static_bundle_${dependency} ON)
          _recursively_collect_dependencies(${dependency})
        endif()
      endif()
    endforeach()
    set(static_libs ${static_libs} PARENT_SCOPE)
  endfunction()

  _recursively_collect_dependencies(${tgt_name})

  message("${static_libs}")
  list(REMOVE_DUPLICATES static_libs)
  message("${static_libs}")

  message(${CMAKE_BINARY_DIR})
  set(CONFIG_SUFFIX "$<IF:$<CONFIG:Debug>,Debug,$<IF:$<CONFIG:Release>,Release,$<IF:$<CONFIG:MinSizeRel>,MinSizeRel,RelWithDebInfo>>>")
  #  set(bundled_tgt_full_name
  #          ${CMAKE_BINARY_DIR}/${CMAKE_STATIC_LIBRARY_PREFIX}${bundled_tgt_name}${CMAKE_STATIC_LIBRARY_SUFFIX})
  set(bundled_tgt_full_name
          ${CMAKE_BINARY_DIR}/${CMAKE_STATIC_LIBRARY_PREFIX}${bundled_tgt_name}${CMAKE_STATIC_LIBRARY_SUFFIX})
  message("${bundled_tgt_full_name}")

  message(${CMAKE_CXX_COMPILER_ID})
  if (CMAKE_CXX_COMPILER_ID MATCHES "^(Clang|GNU|AppleClang)$")
    file(WRITE "${CMAKE_BINARY_DIR}/${bundled_tgt_name}-${CONFIG_SUFFIX}.ar.in"
            "CREATE ${bundled_tgt_full_name}\n" )

    foreach(tgt IN LISTS static_libs)
      file(APPEND "${CMAKE_BINARY_DIR}/${bundled_tgt_name}-${CONFIG_SUFFIX}.ar.in"
              "ADDLIB $<TARGET_FILE:${tgt}>\n")
    endforeach()

    file(APPEND ${CMAKE_BINARY_DIR}/${bundled_tgt_name}-${CONFIG_SUFFIX}.ar.in "SAVE\n")
    file(APPEND ${CMAKE_BINARY_DIR}/${bundled_tgt_name}-${CONFIG_SUFFIX}.ar.in "END\n")

    message("Done writng to AR")

    file(GENERATE
            OUTPUT ${CMAKE_BINARY_DIR}/${bundled_tgt_name}-${CONFIG_SUFFIX}.ar
            INPUT ${CMAKE_BINARY_DIR}/${bundled_tgt_name}-${CONFIG_SUFFIX}.ar.in)

    message("Done generating, ${CMAKE_AR}")

    set(ar_tool ${CMAKE_AR})
    if (CMAKE_INTERPROCEDURAL_OPTIMIZATION)
      set(ar_tool ${CMAKE_CXX_COMPILER_AR})
    endif()

    add_custom_command(
            COMMAND ${ar_tool} -M < ${CMAKE_BINARY_DIR}/${bundled_tgt_name}-${CONFIG_SUFFIX}.ar
            OUTPUT ${bundled_tgt_full_name}
            COMMENT "Bundling ${bundled_tgt_name}"
            VERBATIM)
  elseif(MSVC)
    find_program(lib_tool lib)

    foreach(tgt IN LISTS static_libs)
      list(APPEND static_libs_full_names $<TARGET_FILE:${tgt}>)
    endforeach()

    add_custom_command(
            COMMAND ${lib_tool} /NOLOGO /OUT:${bundled_tgt_full_name} ${static_libs_full_names}
            OUTPUT ${bundled_tgt_full_name}
            COMMENT "Bundling ${bundled_tgt_name}"
            VERBATIM)
  else()
    message(FATAL_ERROR "Unknown bundle scenario!")
  endif()

  message("${CMAKE_CONFIGURATION_TYPES}")
  message("${bundled_tgt_full_name} ${tgt_name}")
  add_custom_target(bundling_target ALL DEPENDS ${bundled_tgt_full_name})
  add_dependencies(bundling_target ${tgt_name})

  add_library(${bundled_tgt_name} STATIC IMPORTED)
  set_target_properties(${bundled_tgt_name}
          PROPERTIES
          IMPORTED_LOCATION ${bundled_tgt_full_name}
          INTERFACE_INCLUDE_DIRECTORIES $<TARGET_PROPERTY:${tgt_name},INTERFACE_INCLUDE_DIRECTORIES>)
  add_dependencies(${bundled_tgt_name} bundling_target)

endfunction()

bundle_static_library(tensorflowlite_c tensorflow-lite-bundled)
