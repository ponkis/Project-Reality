cmake_minimum_required(VERSION 3.20)
project(ProjectRealityCore LANGUAGES NONE)

find_package(Python3 REQUIRED COMPONENTS Interpreter)

set(ENGINE_DIR "${CMAKE_CURRENT_SOURCE_DIR}/../engine" CACHE PATH "Path to the pinned Ghostship tree")
get_filename_component(ENGINE_DIR "${ENGINE_DIR}" ABSOLUTE)

if(NOT EXISTS "${ENGINE_DIR}/tools/merge.py")
    message(FATAL_ERROR "Ghostship merge tool not found: ${ENGINE_DIR}/tools/merge.py")
endif()

# merge.py imports Pillow even for code-only mods.
execute_process(
    COMMAND "${Python3_EXECUTABLE}" -c "import PIL"
    RESULT_VARIABLE PIL_IMPORT_RESULT
    OUTPUT_QUIET
    ERROR_QUIET
)
if(NOT PIL_IMPORT_RESULT EQUAL 0)
    message(FATAL_ERROR "Python package Pillow is required by engine/tools/merge.py")
endif()

set(LOCAL_INCLUDE_DIR "${CMAKE_CURRENT_SOURCE_DIR}/include")
set(INCLUDE_DIRS
    "${LOCAL_INCLUDE_DIR}"
    "${CMAKE_CURRENT_SOURCE_DIR}/src"
    "${ENGINE_DIR}"
    "${ENGINE_DIR}/include"
    "${ENGINE_DIR}/src"
    "${ENGINE_DIR}/libultraship/src"
    "${ENGINE_DIR}/libultraship/include"
    "${ENGINE_DIR}/libultraship/include/libultraship"
)

file(GLOB_RECURSE SOURCE_FILES CONFIGURE_DEPENDS "${CMAKE_CURRENT_SOURCE_DIR}/src/*.c")
list(FILTER SOURCE_FILES EXCLUDE REGEX "[.]inc[.]c$")
file(GLOB_RECURSE LOCAL_HEADERS CONFIGURE_DEPENDS "${LOCAL_INCLUDE_DIR}/*.h")

if(NOT SOURCE_FILES)
    message(FATAL_ERROR "No C mod sources found under project/src")
endif()

set(OUTPUT_DIR "${CMAKE_CURRENT_SOURCE_DIR}/output")
set(DIST_DIR "${OUTPUT_DIR}/dist")
file(MAKE_DIRECTORY "${DIST_DIR}")

set(GENERATED_SOURCES "")
set(BUILD_GEN_ENTRIES "")

foreach(SOURCE_FILE IN LISTS SOURCE_FILES)
    file(RELATIVE_PATH RELATIVE_FILE "${CMAKE_CURRENT_SOURCE_DIR}/src" "${SOURCE_FILE}")
    file(TO_CMAKE_PATH "${RELATIVE_FILE}" RELATIVE_FILE)
    set(OUTPUT_FILE "${DIST_DIR}/${RELATIVE_FILE}")
    get_filename_component(OUTPUT_PARENT "${OUTPUT_FILE}" DIRECTORY)

    add_custom_command(
        OUTPUT "${OUTPUT_FILE}"
        COMMAND "${CMAKE_COMMAND}" -E make_directory "${OUTPUT_PARENT}"
        COMMAND "${Python3_EXECUTABLE}" "${ENGINE_DIR}/tools/merge.py"
                --out "${OUTPUT_FILE}"
                --assets-dir "${OUTPUT_DIR}"
                --includes ${INCLUDE_DIRS}
                --srcs "${SOURCE_FILE}"
        DEPENDS "${SOURCE_FILE}" ${LOCAL_HEADERS} "${ENGINE_DIR}/tools/merge.py"
        COMMENT "Amalgamating ${RELATIVE_FILE}"
        VERBATIM
    )

    list(APPEND GENERATED_SOURCES "${OUTPUT_FILE}")
    list(APPEND BUILD_GEN_ENTRIES "dist/${RELATIVE_FILE}")
endforeach()

string(ASCII 10 NEWLINE)
string(JOIN "${NEWLINE}" BUILD_GEN_CONTENT ${BUILD_GEN_ENTRIES})
file(WRITE "${OUTPUT_DIR}/build.gen" "${BUILD_GEN_CONTENT}${NEWLINE}")

set(OUTPUT_MANIFEST "${OUTPUT_DIR}/manifest.json")
add_custom_command(
    OUTPUT "${OUTPUT_MANIFEST}"
    COMMAND "${CMAKE_COMMAND}" -E copy_if_different
            "${CMAKE_CURRENT_SOURCE_DIR}/manifest.json"
            "${OUTPUT_MANIFEST}"
    DEPENDS "${CMAKE_CURRENT_SOURCE_DIR}/manifest.json"
    VERBATIM
)

add_custom_target(project_reality_mod ALL
    DEPENDS ${GENERATED_SOURCES} "${OUTPUT_MANIFEST}"
)
