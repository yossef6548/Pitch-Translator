cmake_minimum_required(VERSION 3.16)
project(pitch_translator_dsp LANGUAGES C CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

add_library(pt_dsp STATIC
    src/dsp_core.cpp
)

target_include_directories(pt_dsp PUBLIC include)

enable_testing()

add_executable(pt_dsp_tests
    tests/test_smoke.cpp
)
target_link_libraries(pt_dsp_tests PRIVATE pt_dsp)
add_test(NAME pt_dsp_tests COMMAND pt_dsp_tests)

add_executable(pt_dsp_voice_validation
    tests/voice_validation.cpp
)
target_link_libraries(pt_dsp_voice_validation PRIVATE pt_dsp)
add_test(NAME pt_dsp_voice_validation COMMAND pt_dsp_voice_validation)
set_tests_properties(pt_dsp_voice_validation PROPERTIES
    DISABLED TRUE
    LABELS "burn_in"
    TIMEOUT 1800
)

add_executable(pt_dsp_recorded_validation
    tests/recorded_validation.cpp
)
target_link_libraries(pt_dsp_recorded_validation PRIVATE pt_dsp)
target_compile_definitions(pt_dsp_recorded_validation PRIVATE
    PT_FIXTURE_PATH="${CMAKE_CURRENT_SOURCE_DIR}/tests/samples/fixtures.txt"
    PT_GENERATED_DIR="${CMAKE_CURRENT_SOURCE_DIR}/tests/samples/generated"
)
add_test(NAME pt_dsp_recorded_validation COMMAND pt_dsp_recorded_validation)
