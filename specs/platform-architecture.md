# Platform & Architecture Specification

> This document defines **how the product is implemented**, not what it does.
> It realizes all previous specifications on **mobile-native platforms** with **deterministic real-time audio behavior**.

---

## 0. Architectural Goals (Non-Negotiable)

1. **Real-time audio determinism**
2. **Single DSP truth across platforms**
3. **UI strictly driven by state, never by audio callbacks**
4. **Identical behavior on iOS and Android**
5. **Offline-first, no runtime dependency on network**
6. **Testability at every layer**

---

## 1. Target Platforms

### 1.1 Supported Platforms

* **iOS 16+**
* **Android 10+**

Tablets supported automatically via responsive UI.

---

## 2. Technology Stack (Authoritative)

### 2.1 High-Level Stack

| Layer                    | Technology                   |
| ------------------------ | ---------------------------- |
| UI                       | **Flutter**                  |
| Audio Capture / Playback | Native (iOS + Android)       |
| DSP Core                 | **C++ (shared)**             |
| Platform Bridge          | FFI (Flutter ↔ Native ↔ C++) |
| Local Storage            | SQLite                       |
| Analytics                | Local computation only       |
| Cloud Sync               | Optional, future-proofed     |

---

## 3. System Architecture Overview

```text
┌────────────────────────────┐
│        Flutter UI          │
│  (State-driven rendering)  │
└────────────┬───────────────┘
             │ FFI
┌────────────▼───────────────┐
│   Native Audio Layer       │
│ (iOS / Android specific)  │
└────────────┬───────────────┘
             │ C ABI
┌────────────▼───────────────┐
│     DSP Core (C++)         │
│ Pitch, Drift, Metrics     │
└────────────────────────────┘
```

---

## 4. Layer Responsibilities (Strict Separation)

---

## 4.1 DSP Core (C++)

### Responsibilities

* Audio frame processing (real-time safe)
* Pitch detection
* Confidence estimation
* Vibrato detection
* Deterministic DSP frame output (per `dsp-ui-binding.md`)

### Explicitly NOT responsible for

* UI logic
* Animations
* Rendering
* Persistence
* Thread management above frame boundary

---

### 4.1.1 DSP API (Authoritative)

DSP exposes **pure functions** via C ABI:

```c
struct DSPFrameOutput {
    double timestamp_ms;
    double freq_hz;
    double midi_float;
    int    nearest_midi;
    double cents_error;
    double confidence;
    bool   vibrato_detected;
    double vibrato_rate_hz;
    double vibrato_depth_cents;
};
```

DSP guarantees:

* No allocation during processing
* No global mutable state except explicit session state
* Same input → same output (bitwise where possible)

---

## 4.2 Native Audio Layer

### Purpose

Provide **low-latency, stable audio I/O** and feed raw samples to DSP.

---

### 4.2.1 iOS Audio Stack

* **AVAudioEngine**
* Audio Session:

  * category: `playAndRecord`
  * mode: `measurement`
  * preferred sample rate: 48 kHz
  * buffer duration: as low as device allows
* Echo cancellation:

  * OFF by default
  * Configurable in Settings

### Audio Flow

1. Mic input → audio tap
2. Frames buffered (fixed size)
3. Passed to DSP via C ABI
4. DSP output returned
5. UI notified via Flutter event channel

---

### 4.2.2 Android Audio Stack

* **AAudio** (preferred)
* **Oboe** abstraction (fallback)
* Sample rate negotiated at startup
* Low-latency performance mode

Audio Flow mirrors iOS exactly.

---

### 4.2.3 Audio Threading Rules

* Audio callback runs on **real-time thread**
* DSP execution must:

  * complete within buffer duration
  * never block
* UI updates **never** run on audio thread

---

## 4.3 Flutter UI Layer

### Responsibilities

* Render UI based on state
* Animate transitions
* Handle gestures
* Display analytics
* Drive training flow

### Explicitly NOT responsible for

* Audio timing
* Pitch detection
* DSP confidence/vibrato classification
* Lock/drift threshold definitions (these come from specs + exercise config)

---

### 4.3.1 State Management

* **Single source of truth:** AppState
* State updates only via:

  * DSP frame stream
  * User input
  * Training Engine decisions

Recommended pattern:

* Redux-like or Riverpod with immutable state updates

---

### 4.3.2 Frame Update Flow

```text
DSP Frame →
Native →
Flutter Event →
State Reducer →
UI Rebuild →
Animation Tick
```

Guarantee:

* UI frame rate independent of audio rate
* No visual stutter affects DSP correctness

---

## 5. Training Engine Placement

### Location

* **Flutter layer**, pure logic

### Why

* Easier iteration
* Uses DSP outputs only
* Deterministic based on inputs

Training Engine:

* consumes DSP frames
* applies exercise rules
* emits state transitions (LOCKED, DRIFT, etc.)
  The Training Engine owns the Live Pitch state machine defined in `interaction.md` and uses the constants in `dsp-ui-binding.md`.

---

## 6. Persistence & Data Model

### 6.1 Storage

* SQLite
* One database file per user

### 6.2 Stored Data

* Sessions
* Exercises
* Metrics summaries
* User mappings (color/shape)
* Settings

### 6.3 Not Stored

* Raw audio (unless explicitly enabled)
* DSP internal state

---

## 7. Threading Model (Critical)

| Thread             | Responsibility     |
| ------------------ | ------------------ |
| Audio Thread       | Capture + DSP      |
| Native Worker      | Buffering, routing |
| Flutter Main       | UI rendering       |
| Flutter Background | Persistence        |

Rules:

* Audio thread never waits
* UI thread never blocks audio
* DSP never touches UI state

---

## 8. Determinism Guarantees

To satisfy QA spec:

* DSP compiled with:

  * fixed math flags
  * consistent floating-point behavior
* Same DSP binary used on both platforms
* UI math uses same formulas everywhere

---

## 9. Testing Architecture

---

### 9.1 DSP Unit Tests

* Offline sample input
* Golden output frames
* Bitwise comparison where feasible

---

### 9.2 Integration Tests

* Inject prerecorded DSP streams
* Verify UI state transitions
* Verify pixel outputs (tolerance-based)

---

### 9.3 Performance Tests

* Audio underrun detection
* Latency measurement
* Stress tests under background load

---

## 10. Build & CI Strategy

### 10.1 DSP Build

* CMake
* Built once per platform
* Versioned as artifact

### 10.2 Mobile Builds

* iOS: Xcode + Fastlane
* Android: Gradle

### 10.3 CI Checks

* DSP tests
* UI snapshot tests
* QA scenario replay tests

---

## 11. Feature Flag Strategy

* All optional features behind flags:

  * Cloud sync
  * Audio recording
  * Advanced haptics
* Flags default OFF
* No flag affects core DSP behavior

---

## 12. Future-Proofing (Without Commitment)

Designed to allow:

* Wearable haptics
* External MIDI reference
* Coach sharing
* Desktop port

Without changing:

* DSP core
* Training logic
* UI state machines

---

## 13. Final Architecture Consistency Check

| Spec Area          | Covered |
| ------------------ | ------- |
| Real-time audio    | ✅       |
| Determinism        | ✅       |
| UI state machine   | ✅       |
| DSP math           | ✅       |
| QA reproducibility | ✅       |
| Offline support    | ✅       |


