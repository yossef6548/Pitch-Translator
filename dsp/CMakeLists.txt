cmake_minimum_required(VERSION 3.16)
project(pitch_translator_dsp LANGUAGES C CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

add_library(pt_dsp STATIC
    src/dsp_core.cpp
    src/pitch_detector_stub.cpp
)

target_include_directories(pt_dsp PUBLIC include)

add_executable(pt_dsp_tests
    tests/test_smoke.cpp
)
target_link_libraries(pt_dsp_tests PRIVATE pt_dsp)

add_executable(pt_dsp_voice_validation
    tests/voice_validation.cpp
)
target_link_libraries(pt_dsp_voice_validation PRIVATE pt_dsp)
