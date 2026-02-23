# Design System Specification

> This document defines **all visual primitives**: colors, typography, spacing, motion, animation curves, and visual semantics.
> Any UI not defined elsewhere must be constructed *only* from components and rules defined here.

---

## 0. Design Philosophy (Non-Negotiable)

1. **Pitch is continuous → visuals are continuous**
2. **Correctness feels calm, incorrectness feels unstable**
3. **Motion communicates state, not decoration**
4. **Nothing flashy when correct, nothing subtle when wrong**

---

## 1. Color System

### 1.1 Color roles (semantic, not decorative)

Every color has a **role**.
Never reference raw hex values in code — only roles.

#### Primary semantic roles

| Role            | Description                  |
| --------------- | ---------------------------- |
| `PitchColor`    | Color bound to pitch class   |
| `CorrectState`  | Stable, calm success         |
| `WarningState`  | Near error / drift candidate |
| `ErrorState`    | Drift confirmed              |
| `NeutralUI`     | Backgrounds, chrome          |
| `DisabledUI`    | Inactive states              |
| `LowConfidence` | Unreliable pitch             |

---

### 1.2 Pitch Class Color Mapping (Default)

This mapping is **global and immutable unless user edits it**.

| Pitch Class | Color Role | Default Hue  |
| ----------- | ---------- | ------------ |
| C           | `Pitch_C`  | Deep Blue    |
| C#          | `Pitch_Cs` | Blue–Teal    |
| D           | `Pitch_D`  | Teal         |
| D#          | `Pitch_Ds` | Teal–Green   |
| E           | `Pitch_E`  | Green        |
| F           | `Pitch_F`  | Yellow–Green |
| F#          | `Pitch_Fs` | Yellow       |
| G           | `Pitch_G`  | Amber        |
| G#          | `Pitch_Gs` | Orange       |
| A           | `Pitch_A`  | Red          |
| A#          | `Pitch_As` | Magenta      |
| B           | `Pitch_B`  | Purple       |

Rules:

* Adjacent semitones must be perceptually close
* Octave never changes hue — only brightness/size

---

### 1.3 State Overlays (Applied on top of pitch color)

| State           | Effect                                        |
| --------------- | --------------------------------------------- |
| Locked          | 100% saturation, no motion                    |
| Seeking Lock    | 80% saturation, slow pulse                    |
| Drift Candidate | Saturation oscillates ±15%                    |
| Drift Confirmed | Saturation drops to 40%, red fracture overlay |
| Low Confidence  | 30% saturation + grayscale mix                |

---

### 1.4 Colorblind Modes (Mandatory)

3 alternative palettes:

* Protanopia-safe
* Deuteranopia-safe
* Tritanopia-safe

Rule:

> Colorblind mode NEVER changes pitch → shape mapping.

---

## 2. Shape System

### 2.1 Pitch Class Shapes (Default)

Shapes are **topologically distinct**, not stylistic.

| Pitch Class | Shape                |
| ----------- | -------------------- |
| C           | Square               |
| C#          | Square (rotated 45°) |
| D           | Triangle             |
| D#          | Triangle (inverted)  |
| E           | Circle               |
| F           | Hexagon              |
| F#          | Hexagon (elongated)  |
| G           | Pentagon             |
| G#          | Pentagon (concave)   |
| A           | Diamond              |
| A#          | Star (5-point)       |
| B           | Rounded Square       |

Rules:

* Shape identity must be recognizable even at small size
* Shape identity never changes across app

---

### 2.2 Shape Deformation Rules (Pitch Error)

Shape deformation is **the primary off-pitch indicator**.

| Pitch Error                | Shape Behavior        |
| -------------------------- | --------------------- |
| ≤ tolerance                | Rigid                 |
| tolerance → driftThreshold | Subtle elastic wobble |
| driftCandidate             | Directional stretch   |
| driftConfirmed             | Fracture / split      |
| lowConfidence              | Blur + jitter         |

Direction:

* Too low → downward compression
* Too high → upward stretch

Magnitude proportional to `abs(centsError)`.

---

## 3. Typography

### 3.1 Font Families

#### Primary UI Font

* **Inter**
* Used for: labels, buttons, settings, descriptions

#### Numeric / Pitch Font

* **JetBrains Mono**
* Used for:

  * cents
  * MIDI numbers
  * frequencies
  * countdowns

Reason:

> Monospaced numbers reduce perceived jitter and improve tracking.

---

### 3.2 Type Scale (Fixed)

| Token            | Size | Usage            |
| ---------------- | ---- | ---------------- |
| `H1`             | 32   | Mode titles      |
| `H2`             | 24   | Screen headers   |
| `H3`             | 18   | Section headers  |
| `Body`           | 16   | Main text        |
| `Small`          | 13   | Secondary labels |
| `Numeric_Large`  | 40   | Cents readout    |
| `Numeric_Medium` | 24   | MIDI / Hz        |

Line height = 1.25× font size everywhere.

---

## 4. Spacing & Layout

### 4.1 Base Unit

* **8 px grid**
* All spacing = multiples of 8

### 4.2 Safe Zones

* No critical pitch info within:

  * 16 px of screen edges
  * system gesture areas

---

## 5. Motion & Animation System

This is **extremely important**.

---

### 5.1 Motion Principles

1. Motion = information
2. Stability = stillness
3. Error = instability
4. Motion speed scales with error magnitude

---

### 5.2 Global Animation Curves

Only these curves are allowed:

| Name             | Curve                               |
| ---------------- | ----------------------------------- |
| `LinearFeedback` | linear                              |
| `EaseInOut_UI`   | cubic-bezier(0.4, 0.0, 0.2, 1)      |
| `SnapIn`         | cubic-bezier(0.2, 0.0, 0.0, 1.0)    |
| `ElasticError`   | spring (damping 0.6, stiffness 120) |

---

### 5.3 Animation Durations (Strict)

| Interaction        | Duration                   |
| ------------------ | -------------------------- |
| Pitch dot movement | frame-synced (no duration) |
| Shape deformation  | 80–120 ms                  |
| Halo pulse         | 1.2 s loop                 |
| Drift tremble      | 6–8 Hz                     |
| Drift fracture     | 180 ms                     |
| Screen transitions | 220 ms                     |
| Modal open/close   | 180 ms                     |

---

## 6. Pitch Line Visual Math

### 6.1 Geometry

* Center = target pitch
* 1 semitone = fixed width `W`
* 1 cent = `W / 100`

User dot position:

```
x = center + (centsError * (W / 100))
```

### 6.2 Ghost Trail

* Length: 2 seconds
* Opacity decays exponentially
* Color follows pitch color but with 30% opacity

---

## 7. Halo System

### 7.1 Halo Layers

1. Inner solid ring → lock state
2. Outer glow → pitch confidence
3. Pulse ring → seeking lock

### 7.2 Halo Intensity

| Condition       | Intensity           |
| --------------- | ------------------- |
| Locked          | 1.0                 |
| Seeking         | 0.7 pulsing         |
| Drift Candidate | oscillating 0.5–0.8 |
| Drift Confirmed | 0.2 + red overlay   |
| Low Confidence  | 0.3 grayscale       |

---

## 8. Haptics (If Enabled)

### 8.1 Haptic Patterns

| Event                | Pattern                                      |
| -------------------- | -------------------------------------------- |
| Lock achieved        | Single soft tap                              |
| Drift candidate      | Light repeating pulse                        |
| Drift confirmed      | Strong double tap                            |
| Correction direction | Continuous light pulses (rate ∝ cents error) |

---

## 9. Iconography

* Line-based
* 2 px stroke
* Rounded caps
* No filled icons except warnings

Icons must never encode pitch or correctness alone.

---

## 10. Visual Consistency Rules (QA Checklist)

* Same pitch → same color + shape everywhere
* Same cents error → same deformation magnitude
* Same state → same animation
* No color-only feedback
* No motion without semantic meaning

---

## 11. Token Naming Convention (For Code & Design)

Example:

```
Color.Pitch.G
Shape.Pitch.A
Motion.ElasticError
Font.Numeric.Medium
Spacing.16
```

No ad-hoc values allowed.