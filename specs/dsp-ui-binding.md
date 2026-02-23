# DSP → UI Binding Specification

> This document defines the **exact mathematical mapping** from DSP outputs to UI state, visuals, motion, color, shape deformation, and haptics.
> If DSP output is identical, UI output MUST be identical across platforms.

---

## 0. DSP Output Contract (Single Source of Truth)

For every processed audio frame, DSP emits **one immutable structure**:

```json
{
  "timestamp_ms": number,
  "freq_hz": number | null,
  "midi_float": number | null,
  "nearest_midi": number | null,
  "cents_error": number | null,
  "confidence": number,            // 0.0 – 1.0
  "vibrato": {
    "detected": boolean,
    "rate_hz": number | null,
    "depth_cents": number | null
  }
}
```

Rules:

* If pitch cannot be determined → `freq_hz = null`, `midi_float = null`, `cents_error = null`
* `confidence` MUST still be reported even if pitch is null
* All UI decisions derive **only** from this structure + exercise configuration

---

## 1. Confidence → UI Gating (First Decision Layer)

### 1.1 Confidence Thresholds (Global Constants)

```text
MIN_CONFIDENCE = 0.60
RECOVERY_CONFIDENCE = 0.65
```

### 1.2 Confidence State Machine

| Condition                        | UI State               |
| -------------------------------- | ---------------------- |
| confidence < MIN_CONFIDENCE      | LOW_CONFIDENCE         |
| confidence ≥ RECOVERY_CONFIDENCE | previous non-LOW state |

Rules:

* LOW_CONFIDENCE **overrides all other states**
* Scoring and drift logic are paused
* Visual feedback continues but muted

### 1.3 LOW_CONFIDENCE Visual Mapping

* Saturation multiplier = `0.30`
* Shape opacity = `0.50`
* Shape jitter amplitude = `2 px` (random, non-directional)
* Halo disabled
* Error readout hidden (`—`)

---

## 2. Pitch Error Normalization

### 2.1 Raw cents error

From DSP:

```text
cents_error_raw ∈ (-50, +50)
```

### 2.2 Clamped cents error (used everywhere)

```text
cents_error = clamp(cents_error_raw, -50, +50)
```

### 2.3 Absolute error

```text
abs_error = abs(cents_error)
```

---

## 3. Pitch Line Mapping (Spatial)

### 3.1 Constants

```text
SEMITONE_WIDTH_PX = W   // defined per layout, constant per screen
```

### 3.2 Horizontal Position

```text
x_offset_px = (cents_error / 100) * SEMITONE_WIDTH_PX
```

Applied to:

* pitch dot
* ghost trail
* drift markers

### 3.3 Ghost Trail Opacity

For trail sample at age `t` seconds (0 ≤ t ≤ 2):

```text
opacity = exp(-t / 0.6) * 0.30
```

---

## 4. Lock / Drift Mathematical Criteria

(All values come from Exercise Config or global defaults)

### 4.1 Lock Conditions

```text
abs_error ≤ tolerance_cents
confidence ≥ MIN_CONFIDENCE
duration ≥ LOCK_ACQUIRE_TIME_MS
```

### 4.2 Drift Candidate

```text
abs_error > DRIFT_THRESHOLD_CENTS
duration ≥ DRIFT_CANDIDATE_TIME_MS
```

### 4.3 Drift Confirmed

```text
abs_error > DRIFT_THRESHOLD_CENTS
duration ≥ DRIFT_CONFIRM_TIME_MS
```

These transitions MUST match the **Interaction & State Transition Specification** exactly.

---

## 5. Shape Deformation Math (Core Visual Feedback)

### 5.1 Normalized Error Factor

```text
E = clamp(abs_error / DRIFT_THRESHOLD_CENTS, 0.0, 1.0)
```

This single scalar `E` drives:

* shape deformation
* tremble intensity
* halo instability
* haptic frequency

---

### 5.2 Direction Sign

```text
D = sign(cents_error)   // -1 = too low, +1 = too high
```

---

### 5.3 Shape Deformation Amplitude

```text
DEFORM_PX = E * MAX_DEFORM_PX
MAX_DEFORM_PX = 18 px
```

### 5.4 Deformation Application Rules

| Pitch Direction | Transformation            |
| --------------- | ------------------------- |
| cents_error > 0 | Vertical stretch (+Y)     |
| cents_error < 0 | Vertical compression (-Y) |

Implementation:

* Scale or vertex displacement must preserve shape identity
* No rotation used for pitch error

---

### 5.5 Drift Tremble (DRIFT_CANDIDATE)

Frequency:

```text
TREMOR_FREQ_HZ = 6 + (E * 2)   // 6–8 Hz
```

Amplitude:

```text
TREMOR_PX = 2 + (E * 4)
```

Motion curve:

* `ElasticError` spring

---

### 5.6 Drift Fracture (DRIFT_CONFIRMED)

Fracture magnitude:

```text
FRACTURE_PX = 10 + (E * 10)
```

Duration:

```text
180 ms (fixed)
```

Overlay:

* Red fracture lines
* Opacity = `0.8`

---

## 6. Color & Saturation Binding

### 6.1 Saturation Multiplier

```text
SATURATION = 1.0 - (E * 0.6)
```

| State           | Override         |
| --------------- | ---------------- |
| LOCKED          | SATURATION = 1.0 |
| SEEKING_LOCK    | SATURATION = 0.8 |
| DRIFT_CONFIRMED | SATURATION = 0.4 |
| LOW_CONFIDENCE  | SATURATION = 0.3 |

---

### 6.2 Color Selection

```text
base_color = PitchClassColor(nearest_midi % 12)
final_color = apply_saturation(base_color, SATURATION)
```

---

## 7. Halo Binding

### 7.1 Halo Intensity

```text
HALO_INTENSITY = clamp(1.0 - (E * 0.7), 0.3, 1.0)
```

State overrides:

* LOCKED → 1.0
* SEEKING_LOCK → pulsing 0.5–0.8
* DRIFT_CONFIRMED → 0.2
* LOW_CONFIDENCE → 0.0

---

### 7.2 Halo Pulse (Seeking Lock)

Pulse function:

```text
pulse(t) = 0.65 + 0.15 * sin(2π * t / 1.2s)
```

---

## 8. Vibrato Handling (Critical)

### 8.1 Vibrato Qualification

Vibrato is considered **valid** if:

```text
4 Hz ≤ vibrato.rate_hz ≤ 8 Hz
vibrato.depth_cents ≤ VIBRATO_DEPTH_LIMIT
```

(Default `VIBRATO_DEPTH_LIMIT = 30 cents`)

---

### 8.2 Effective Error with Vibrato

If vibrato is valid:

```text
effective_error = mean(cents_error over last 150 ms)
```

Otherwise:

```text
effective_error = cents_error
```

All lock/drift logic uses `effective_error`.

---

### 8.3 Vibrato Visual Indicator

* Subtle radial ripple
* No shape deformation
* No error penalty

---

## 9. Error Readout Binding

### 9.1 Numeric Display

```text
DISPLAY_CENTS = round(cents_error)
```

### 9.2 Arrow Direction

```text
arrow = ↑ if cents_error > 0
arrow = ↓ if cents_error < 0
arrow hidden if abs_error ≤ tolerance
```

---

## 10. Haptic Binding (If Enabled)

### 10.1 Continuous Correction Feedback

Pulse frequency:

```text
HAPTIC_FREQ_HZ = 2 + (E * 6)   // 2–8 Hz
```

Disabled when:

* LOCKED
* LOW_CONFIDENCE

---

### 10.2 Event Haptics

| Event           | Pattern              |
| --------------- | -------------------- |
| Lock achieved   | single soft tap      |
| Drift candidate | repeating light taps |
| Drift confirmed | strong double tap    |

---

## 11. Frame Update Ordering (Critical)

Per audio frame:

1. Receive DSP frame
2. Update confidence state
3. Compute `effective_error`
4. Update lock/drift state machine
5. Compute `E`, `D`
6. Update visuals (position → deformation → color → halo)
7. Trigger haptics (if any)

No reordering allowed.

---

## 12. Determinism Guarantee (QA Requirement)

Given:

* identical DSP frame stream
* identical exercise config
* identical device DPI scaling

→ UI output MUST be pixel-identical (within floating point tolerance).

---

## 13. Validation Checklist (Engineering Sign-off)

* [ ] cents → pixel mapping correct
* [ ] vibrato not misclassified as drift
* [ ] LOW_CONFIDENCE overrides everything
* [ ] shape identity preserved under deformation
* [ ] color saturation follows formula
* [ ] haptics proportional to error
* [ ] state transitions match Interaction Spec