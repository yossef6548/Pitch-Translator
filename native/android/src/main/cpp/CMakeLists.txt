cmake_minimum_required(VERSION 3.18)
project(pt_audio_engine)

add_library(pt_audio_engine SHARED
  pt_audio_engine.cpp
)

target_include_directories(pt_audio_engine PRIVATE
  ../../../../../dsp/include
)

target_sources(pt_audio_engine PRIVATE
  ../../../../../dsp/src/dsp_core.cpp
  ../../../../../dsp/src/pitch_detector_stub.cpp
)

target_link_libraries(pt_audio_engine
  aaudio
  android
  log
)
