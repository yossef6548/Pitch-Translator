# pt_audio_plugin

`pt_audio_plugin` is the canonical Flutter native audio plugin for Pitch Translator.

## Public channel contract

- EventChannel: `pt/audio/frames`
- MethodChannel: `pt/audio/control`
  - supported methods: `start`, `stop`

## Frame payload shape

Each emitted frame map follows:

- `timestamp_ms` (int)
- `freq_hz` (double?)
- `midi_float` (double?)
- `nearest_midi` (int?)
- `cents_error` (double?)
- `confidence` (double)
- `vibrato` (map)
  - `detected` (bool)
  - `rate_hz` (double?)
  - `depth_cents` (double?)

## Platform responsibilities

- permission workflow and denial handling
- start/stop capture lifecycle
- route/interruption handling
- DSP frame emission over channel contract

## Expected failure modes

- microphone permission denied
- plugin unavailable/miswired host app
- audio start succeeds but no frames arrive
- route/focus interruptions requiring restart

## Test notes

Validate behavior in debug/test/release for:

1. plugin absent/unavailable path (graceful failure)
2. denied permission path
3. first-frame timeout path
4. interruption + route-change restart behavior
