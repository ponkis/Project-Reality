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

set(TITLE_LOGO_PNG
    "${CMAKE_CURRENT_SOURCE_DIR}/assets/title/title_logo.rgba32.png"
)
set(TITLE_LOGO_CONVERTER
    "${CMAKE_CURRENT_SOURCE_DIR}/tools/png_to_rgba32_otex.py"
)
set(TITLE_LOGO_RESOURCE
    "${OUTPUT_DIR}/project_reality/title_logo"
)
set(AUDIO_ASSET_NAMES
    "haha.wav"
    "yeah.wav"
    "comeon.wav"
    "input.wav"
)
set(AUDIO_OVERRIDE_RELATIVE_PATHS
    "sound/samples/sfx_mario/19_mario_yippee"
    "sound/samples/sfx_mario_peach/08_mario_punch_yah"
    "sound/samples/sfx_mario/13_mario_press_start_to_play"
    "sound/samples/sfx_mario/12_mario_hello"
)

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

set(AUDIO_OUTPUTS "")
foreach(AUDIO_NAME IN LISTS AUDIO_ASSET_NAMES)
    set(AUDIO_SOURCE "${CMAKE_CURRENT_SOURCE_DIR}/assets/audio/${AUDIO_NAME}")
    set(AUDIO_OUTPUT "${OUTPUT_DIR}/project_reality/audio/${AUDIO_NAME}")
    add_custom_command(
        OUTPUT "${AUDIO_OUTPUT}"
        COMMAND "${CMAKE_COMMAND}" -E make_directory
                "${OUTPUT_DIR}/project_reality/audio"
        COMMAND "${CMAKE_COMMAND}" -E copy_if_different
                "${AUDIO_SOURCE}"
                "${AUDIO_OUTPUT}"
        DEPENDS "${AUDIO_SOURCE}"
        COMMENT "Packaging Project Reality audio ${AUDIO_NAME}"
        VERBATIM
    )
    list(APPEND AUDIO_OUTPUTS "${AUDIO_OUTPUT}")
endforeach()

set(AUDIO_OVERRIDE_OUTPUTS "")
foreach(OVERRIDE_PATH IN LISTS AUDIO_OVERRIDE_RELATIVE_PATHS)
    set(OVERRIDE_SOURCE
        "${CMAKE_CURRENT_SOURCE_DIR}/assets/overrides/${OVERRIDE_PATH}"
    )
    set(OVERRIDE_OUTPUT "${OUTPUT_DIR}/${OVERRIDE_PATH}")
    get_filename_component(OVERRIDE_OUTPUT_PARENT "${OVERRIDE_OUTPUT}" DIRECTORY)
    add_custom_command(
        OUTPUT "${OVERRIDE_OUTPUT}"
        COMMAND "${CMAKE_COMMAND}" -E make_directory
                "${OVERRIDE_OUTPUT_PARENT}"
        COMMAND "${CMAKE_COMMAND}" -E copy_if_different
                "${OVERRIDE_SOURCE}"
                "${OVERRIDE_OUTPUT}"
        DEPENDS "${OVERRIDE_SOURCE}"
        COMMENT "Packaging audio override ${OVERRIDE_PATH}"
        VERBATIM
    )
    list(APPEND AUDIO_OVERRIDE_OUTPUTS "${OVERRIDE_OUTPUT}")
endforeach()

add_custom_command(
    OUTPUT "${TITLE_LOGO_RESOURCE}"
    COMMAND "${CMAKE_COMMAND}" -E make_directory
            "${OUTPUT_DIR}/project_reality"
    COMMAND "${Python3_EXECUTABLE}" "${TITLE_LOGO_CONVERTER}"
            --input "${TITLE_LOGO_PNG}"
            --output "${TITLE_LOGO_RESOURCE}"
            --width 1000
            --height 444
    DEPENDS "${TITLE_LOGO_PNG}" "${TITLE_LOGO_CONVERTER}"
    COMMENT "Converting Project Reality title logo to RGBA32"
    VERBATIM
)

add_custom_target(project_reality_mod ALL
    DEPENDS
        ${GENERATED_SOURCES}
        "${OUTPUT_MANIFEST}"
        "${TITLE_LOGO_RESOURCE}"
        ${AUDIO_OUTPUTS}
        ${AUDIO_OVERRIDE_OUTPUTS}
)
