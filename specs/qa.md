# End-to-End QA Specification

> This document defines **deterministic test scenarios** mapping **DSP input streams → expected UI state, visuals, scoring, and progression results**.

---

## 0. QA Philosophy

1. **DSP is truth**
2. **UI must be deterministic**
3. **Same input → same output**
4. **No “looks OK” checks — only measurable assertions**

All tests are **black-box** from DSP output onward.

---

## 1. Test Harness Requirements

### 1.1 DSP Frame Injection

QA system must be able to inject a prerecorded stream of DSP frames:

```json
{
  "timestamp_ms": number,
  "freq_hz": number | null,
  "midi_float": number | null,
  "nearest_midi": number | null,
  "cents_error": number | null,
  "confidence": number,
  "vibrato": { "detected": boolean, "rate_hz": number, "depth_cents": number }
}
```

* Timestamp spacing: 5–10 ms
* Frames must be consumed in real time
* No UI-side smoothing allowed beyond spec

---

### 1.2 Observable Outputs (Must Be Inspectable)

QA must be able to read:

* Current **UI state** (`IDLE`, `LOCKED`, etc.)
* Pitch dot X position (px)
* Shape deformation amplitude (px)
* Color saturation value
* Halo intensity
* Haptic trigger events (logical)
* Exercise metrics (AvgError, DriftCount, etc.)

---

## 2. Global Sanity Tests

### QA-G-01: Null Pitch Handling

**Input**

* 5 seconds of frames:

  * `freq_hz = null`
  * `confidence = 0.8`

**Expected**

* UI state: `LOW_CONFIDENCE`
* Shape visible but:

  * opacity = 0.5
  * saturation = 0.3
* No lock, no drift
* No scoring accumulation

---

### QA-G-02: Confidence Override

**Input**

* Stable pitch within tolerance
* `confidence = 0.55` for 500 ms

**Expected**

* Immediate transition to `LOW_CONFIDENCE`
* Lock broken
* Halo disabled
* Error readout hidden

---

## 3. Pitch Freezing Mode Tests (MODE_PF)

---

### QA-PF-01: Basic Lock Acquisition

**Exercise**

* PF_1 (L1)
* tolerance = ±35c

**Input**

* cents_error = +5c
* confidence = 0.9
* duration = LOCK_ACQUIRE_TIME + 100 ms

**Expected**

* State transition:

  * SEEKING_LOCK → LOCKED
* Shape:

  * rigid
  * no deformation
* Halo intensity = 1.0
* Lock sound + haptic triggered once

---

### QA-PF-02: Lock Failure (Near Miss)

**Input**

* cents_error oscillates between +33c and +37c

**Expected**

* Never enters LOCKED
* Shape wobble visible
* Halo pulsing continues
* LockRatio remains 0

---

### QA-PF-03: Silent Hold Failure

**Exercise**

* PF_2
* Reference OFF after cue

**Input**

* Lock achieved
* Drift to +28c after 3s

**Expected**

* DriftCandidate → DriftConfirmed
* PF_2 marked failed
* DriftCount = 1

---

## 4. Drift Awareness Mode Tests (MODE_DA)

---

### QA-DA-01: Drift Candidate Recovery

**Input**

* Locked
* cents_error increases to +31c for 200 ms
* then returns to +10c

**Expected**

* LOCKED → DRIFT_CANDIDATE → LOCKED
* No drift logged
* Shape tremble stops
* No replay triggered

---

### QA-DA-02: Drift Replay Trigger

**Input**

* Locked
* cents_error = +40c for DRIFT_CONFIRM_TIME

**Expected**

* Transition:

  * LOCKED → DRIFT_CONFIRMED → DRIFT_REPLAY
* Live pitch paused
* Replay panels show:

  * before pitch
  * after pitch
  * delta ≈ +40c

---

### QA-DA-03: Drift Recovery Timing

**Exercise**

* DA_2 (L2)

**Input**

* Drift confirmed
* User re-locks in 1.8s

**Expected**

* Recovery success
* RecoveryTime ≤ 2s
* Counts toward mastery

---

## 5. Vibrato Handling Tests

---

### QA-VB-01: Valid Vibrato Ignored

**Input**

* cents_error oscillates ±25c
* vibrato.rate = 6 Hz
* vibrato.depth = 25c

**Expected**

* LOCKED maintained
* No drift
* Vibrato visual indicator active
* Stability computed from mean error

---

### QA-VB-02: Excessive Vibrato Misclassified

**Input**

* vibrato.depth = 45c

**Expected**

* Treated as pitch error
* Drift logic applies
* Shape deformation visible

---

## 6. Relative Pitch Tests (MODE_RP)

---

### QA-RP-01: Arithmetic Correctness

**Exercise**

* RP_1
* Base MIDI = 60
* Operation = +1

**Input**

* User sings MIDI 61 ±10c

**Expected**

* Correct
* Success count increments
* Visual target shows MIDI 61

---

### QA-RP-02: Arithmetic Failure

**Input**

* User sings MIDI 62

**Expected**

* Immediate failure
* No partial credit
* Error feedback shown

---

## 7. Group Simulation Tests (MODE_GS)

---

### QA-GS-01: Unison Lock

**Input**

* Choir holds pitch
* User stays within ±20c

**Expected**

* Lock maintained
* Dot stays inside choir bar
* LockRatio ≥ 80%

---

### QA-GS-02: Chord Confusion

**Input**

* Choir sings C major
* User jumps between E and G

**Expected**

* Confusion detected
* Drift events logged
* GS_2 fails mastery

---

## 8. Listening & Translation Tests (MODE_LT)

---

### QA-LT-01: Note Identification

**Input**

* App plays A4

**User Action**

* Selects “A4” or MIDI 69

**Expected**

* Correct
* Progress increments

---

### QA-LT-02: Octave Discrimination

**Input**

* App plays C3
* User selects C4

**Expected**

* Incorrect
* Error shown
* No progression

---

## 9. Analytics Validation

---

### QA-AN-01: AvgError Calculation

**Input**

* Effective error trace: [10, 12, 8, 10]

**Expected**

* AvgError = 10c
* Stability ≈ 1.63c

---

### QA-AN-02: Drift Count Accuracy

**Input**

* 3 confirmed drifts

**Expected**

* DriftCount = 3
* Exactly 3 replay entries

---

## 10. Progression & Unlock Tests

---

### QA-PR-01: Mode Unlock

**Condition**

* PF_3 mastered

**Expected**

* MODE_DA unlocked
* Visible in Train Catalog

---

### QA-PR-02: Level Unlock

**Condition**

* 80% of L2 exercises mastered

**Expected**

* L3 unlocked
* UI badge updated

---

## 11. Visual Determinism Tests

---

### QA-VD-01: Pixel Mapping

**Input**

* cents_error = +50c

**Expected**

* Pitch dot offset = +0.5 × SEMITONE_WIDTH_PX

---

### QA-VD-02: Shape Deformation

**Input**

* abs_error = DRIFT_THRESHOLD

**Expected**

* DEFORM_PX = MAX_DEFORM_PX
* Shape stretched exactly by spec

---

## 12. Failure Mode Tests

---

### QA-FM-01: Backgrounding App

**Event**

* App backgrounded mid-session

**Expected**

* Session paused
* Resume prompt on return
* No metric corruption

---

### QA-FM-02: Audio Route Change

**Event**

* Speaker → headphones

**Expected**

* Banner shown
* Latency recalculated
* No crash

---

## 13. Acceptance Criteria (Ship Blockers)

App **cannot ship** if:

* Any test above fails
* Same DSP trace produces different UI on different devices
* Drift misfires under valid vibrato
* LOW_CONFIDENCE does not override state machine