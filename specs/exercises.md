# Exercise Catalog & Progression Specification

> This document defines **every exercise type**, **all concrete exercises**, **difficulty parameters**, **unlock rules**, **mastery conditions**, and **adaptive progression logic**.

---

## 0. Core Training Principles (Global)

1. **One skill per exercise**
2. **No melody before stability**
3. **No speed before accuracy**
4. **No silence removal until reference mastery**
5. **Progression is earned, never assumed**

---

## 1. Exercise Taxonomy (Authoritative)

All exercises belong to exactly one **Mode**.

| Mode ID   | Mode Name                   |
| --------- | --------------------------- |
| `MODE_PF` | Pitch Freezing              |
| `MODE_DA` | Drift Awareness             |
| `MODE_RP` | Relative Pitch (Arithmetic) |
| `MODE_GS` | Group Simulation            |
| `MODE_LT` | Listening & Translation     |

---

## 2. Difficulty Levels (Shared Across All Modes)

| Level ID | Name     | Tolerance | Drift Threshold |
| -------- | -------- | --------- | --------------- |
| `L1`     | Beginner | ±35c      | ±45c            |
| `L2`     | Standard | ±20c      | ±30c            |
| `L3`     | Advanced | ±10c      | ±20c            |

Rules:

* Difficulty level affects **default config only**
* User may override tolerance manually, but:

  * mastery credit is reduced or denied if tolerance > level default

---

## 3. Mastery Scoring (Global)

### 3.1 Core Metrics (used everywhere)

* `AvgError` = mean(abs(effective_error))
* `Stability` = std deviation of effective_error
* `LockRatio` = locked_time / active_time
* `DriftCount`
* `RecoveryTime` = mean time to re-lock after drift

---

### 3.2 Mastery Condition Template

An exercise is **Mastered** if **all** conditions are met:

```text
AvgError ≤ level_avg_error_limit
Stability ≤ level_stability_limit
LockRatio ≥ level_lock_ratio_limit
DriftCount ≤ level_drift_limit
```

Limits depend on level (see below).

---

### 3.3 Level-Based Mastery Thresholds

| Level | AvgError | Stability | LockRatio | DriftCount |
| ----- | -------- | --------- | --------- | ---------- |
| L1    | ≤ 25c    | ≤ 18c     | ≥ 60%     | ≤ 4        |
| L2    | ≤ 15c    | ≤ 10c     | ≥ 75%     | ≤ 2        |
| L3    | ≤ 8c     | ≤ 5c      | ≥ 85%     | ≤ 1        |

---

## 4. MODE_PF — Pitch Freezing

### Goal

Develop **absolute pitch stability** without movement.

---

### 4.1 Exercise PF-1: Single Pitch Hold (Referenced)

**ID:** `PF_1`

* Target: fixed pitch
* Reference tone: ON
* Duration: 5s (L1), 8s (L2), 12s (L3)

Unlock:

* Always available

Mastery:

* As per level thresholds

---

### 4.2 Exercise PF-2: Single Pitch Hold (Silent)

**ID:** `PF_2`

* Reference tone: OFF after initial cue
* Hold must be internalized

Unlock:

* PF_1 mastered at same level

Additional condition:

* Lock must be achieved within 2s of silence start

---

### 4.3 Exercise PF-3: Random Pitch Hold

**ID:** `PF_3`

* Target randomly selected within user range
* Reference tone: ON for 1s, then OFF

Unlock:

* PF_2 mastered at same level

---

### 4.4 Exercise PF-4: Fatigue Hold

**ID:** `PF_4`

* Same pitch repeated 3 times
* Minimal rest between holds

Unlock:

* PF_3 mastered

Purpose:

* Prevents “first-hold-only” illusion of control

---

## 5. MODE_DA — Drift Awareness

### Goal

Make **pitch drift perceptually obvious and correctable**.

---

### 5.1 Exercise DA-1: Drift Detection

**ID:** `DA_1`

* Same as PF_2
* Drift Replay enabled
* Session pauses automatically on drift

Unlock:

* PF_2 mastered

Mastery requirement:

* User must correctly identify:

  * direction of drift (↑/↓)
  * approximate magnitude category (small / medium / large)

---

### 5.2 Exercise DA-2: Drift Recovery

**ID:** `DA_2`

* After drift replay, user must re-lock within:

  * 3s (L1)
  * 2s (L2)
  * 1.5s (L3)

Unlock:

* DA_1 mastered

---

### 5.3 Exercise DA-3: Drift Under Vibrato

**ID:** `DA_3`

* Artificial vibrato added to reference
* DSP vibrato handling active

Unlock:

* DA_2 mastered

Purpose:

* Teaches distinction between **expressive motion** and **error**

---

## 6. MODE_RP — Relative Pitch (Arithmetic)

### Goal

Build **interval accuracy using numeric cognition**.

---

### 6.1 Exercise RP-1: ±1 Semitone

**ID:** `RP_1`

* Base pitch provided
* Operation: +1 or -1
* Reference plays base only

Unlock:

* PF_3 mastered

Mastery:

* 10 correct in a row

---

### 6.2 Exercise RP-2: ±2, ±3 Semitones

**ID:** `RP_2`

Unlock:

* RP_1 mastered

---

### 6.3 Exercise RP-3: Mixed Jumps

**ID:** `RP_3`

* ±4, ±5, ±7

Unlock:

* RP_2 mastered

---

### 6.4 Exercise RP-4: Two-Step Arithmetic

**ID:** `RP_4`

* Example: +3 then -2
* Must sing final pitch

Unlock:

* RP_3 mastered

---

### 6.5 Exercise RP-5: Silent Arithmetic

**ID:** `RP_5`

* No reference playback
* Internal base pitch only

Unlock:

* RP_4 mastered

---

## 7. MODE_GS — Group Simulation

### Goal

Maintain pitch in **complex auditory environments**.

---

### 7.1 Exercise GS-1: Unison Lock

**ID:** `GS_1`

* Virtual choir holds single pitch

Unlock:

* PF_3 mastered

---

### 7.2 Exercise GS-2: Chord Anchor

**ID:** `GS_2`

* Choir sings triad
* User assigned fixed chord tone

Unlock:

* GS_1 mastered

---

### 7.3 Exercise GS-3: Moving Anchor

**ID:** `GS_3`

* Choir modulates slowly (≤ 1 semitone / 3s)

Unlock:

* GS_2 mastered

---

### 7.4 Exercise GS-4: Distraction Layer

**ID:** `GS_4`

* Background noise or extra voices added

Unlock:

* GS_3 mastered

---

## 8. MODE_LT — Listening & Translation

### Goal

Build **sound → internal representation** without voice.

---

### 8.1 Exercise LT-1: Note Identification

**ID:** `LT_1`

* App plays pitch
* User selects:

  * note name OR
  * MIDI number

Unlock:

* PF_1 mastered

---

### 8.2 Exercise LT-2: Color & Shape Match

**ID:** `LT_2`

* User selects visual representation

Unlock:

* LT_1 mastered

---

### 8.3 Exercise LT-3: Octave Discrimination

**ID:** `LT_3`

* Same pitch class, different octaves

Unlock:

* LT_2 mastered

---

## 9. Progression & Unlock Logic (Global)

### 9.1 Mode Unlocks

* Modes unlock in this order:

  1. Pitch Freezing
  2. Drift Awareness
  3. Relative Pitch
  4. Group Simulation
  5. Listening & Translation

### 9.2 Level Progression

* Levels unlock **per mode**
* L2 unlock:

  * ≥ 70% exercises mastered in L1
* L3 unlock:

  * ≥ 80% exercises mastered in L2

---

## 10. Adaptive Training Engine Rules

### 10.1 Automatic Adjustments

If user fails same exercise 3×:

* widen tolerance by +5c temporarily
* reduce duration by 20%
* mark as “assisted”

Assisted completions:

* do NOT count toward mastery

---

### 10.2 Skill Decay Handling

If mastery older than 30 days:

* exercise marked “needs refresh”
* refresh requires 1 successful repetition

---

## 11. Visual Progress Indicators (UI Binding)

| State         | Visual              |
| ------------- | ------------------- |
| Locked        | gray                |
| In progress   | blue                |
| Assisted      | dashed              |
| Mastered      | solid color + check |
| Needs refresh | faded               |

---

## 12. Data Model Additions

Each Exercise instance stores:

* attempts
* assisted_attempts
* mastery_date
* last_attempt_date
* best_metrics

---

## 13. Completion Definition (Product-Level)

User is considered **“Pitch Stable”** when:

* All PF exercises mastered at L3
* All DA exercises mastered at L2
* AvgError ≤ 10c over last 10 sessions

This is a **celebrated milestone**, not end of app.

---

## 14. Final Consistency Check

* Uses same:

  * tolerance
  * drift
  * lock
  * confidence
* No new UI states
* No DSP logic duplication
* All exercises map cleanly to existing screens