# Interaction & State Transition Specification

> This document defines **every user interaction**, **gesture**, **tap**, **long-press**, **drag**, **system event**, and **automatic transition**.
> It extends the UI spec and does **not** introduce new concepts or rename existing ones.

---

## 0. Global Interaction Rules (Applies Everywhere)

### 0.1 Input types supported

* Tap
* Long press (≥500 ms)
* Drag (horizontal / vertical)
* Pinch (zoom only where explicitly stated)
* System events:

  * app backgrounded
  * mic permission revoked
  * audio route changed (speaker ↔ headphones)

No hidden gestures.
No gesture overloading unless explicitly stated.

---

### 0.2 Visual feedback invariants

Every interaction MUST result in:

* immediate visual response ≤ 16 ms
* state change animation ≤ 250 ms
* audio/haptic feedback if enabled

If feedback cannot be shown (e.g. low confidence), UI must explicitly signal why.

---

## 1. Navigation Interactions

### 1.1 Bottom Tab Bar / Sidebar

**Component:** `GLOBAL_NAV`

#### Tap behavior

* Single tap on tab:

  * navigates immediately
  * preserves last internal state of that tab
* Re-tap active tab:

  * scrolls to top (if applicable)
  * does NOT reset state

#### Disabled states

* If mic permission missing:

  * Train, Home Quick Monitor, Live Pitch blocked
  * Analyze, Settings remain accessible

---

## 2. Home Screen (`HOME_TODAY`) Interactions

---

### 2.1 Focus Card (`FOCUS_CARD`)

#### Tap: Start

* Event: `FOCUS_START_TAPPED`
* Transition:

  * → `EXERCISE_CONFIG`
  * config pre-filled by Training Engine
* Animation:

  * card expands → fade → new screen slide in

#### Swipe left (optional)

* Dismiss current recommendation
* Training Engine provides next recommendation
* Max 3 dismissals/day

---

### 2.2 Quick Monitor (`QUICK_MONITOR`)

#### Tap

* Event: `QUICK_MONITOR_OPEN`
* Transition:

  * → `LIVE_PITCH`
  * Mode: passive (no scoring, no training engine)
* State:

  * mic starts immediately
  * reference OFF
  * tolerance = Standard

#### Background behavior

* If app returns from background:

  * mic restarts automatically
  * if permission revoked → error overlay

---

## 3. Train Catalog (`TRAIN_CATALOG`) Interactions

---

### 3.1 Mode Card (`MODE_CARD`)

#### Tap: Open

* Event: `MODE_OPEN`
* Transition:

  * → `MODE_<MODE>_OVERVIEW`
* No modal overlays here

---

## 4. Mode Overview Screen Interactions

---

### 4.1 Exercise Item (`EXERCISE_ITEM`)

#### Tap

* Event: `EXERCISE_SELECTED`
* Transition:

  * → `EXERCISE_CONFIG`
* Config values:

  * defaults defined by exercise template
  * user last-used values prefilled if compatible

---

## 5. Exercise Configuration (`EXERCISE_CONFIG`) Interactions

---

### 5.1 Target Selector

#### Tap on note name

* Opens modal picker:

  * vertical scroll: notes
  * horizontal scroll: octave
* Confirm → update target

#### Toggle “Randomize”

* If ON:

  * picker disabled
  * range selector appears

---

### 5.2 Tolerance Presets

#### Tap preset

* Immediately highlights
* Updates internal tolerance value
* If “Custom” was active → deactivates

#### Drag custom slider

* Slider snap: 1 cent increments
* Live preview of tolerance ring on mini pitch preview

---

### 5.3 Start Button

#### Tap

* Event: `EXERCISE_START`
* Transition:

  * → `LIVE_PITCH`
* Training Engine initialized
* Countdown starts automatically

---

## 6. Live Pitch Screen (`LIVE_PITCH`) — Interaction Core

This is the most critical section.

---

### 6.1 Screen States (Authoritative)

`LIVE_PITCH` always exists in exactly ONE of these states:

1. `IDLE`
2. `COUNTDOWN`
3. `SEEKING_LOCK`
4. `LOCKED`
5. `DRIFT_CANDIDATE`
6. `DRIFT_CONFIRMED`
7. `LOW_CONFIDENCE`
8. `PAUSED`
9. `COMPLETED`

State transitions are **event-driven**, not UI-driven.

---

### 6.2 Transport Controls (`SESSION_CONTROLS`)

#### Start (IDLE only)

* Event: `SESSION_START`
* Transition: `IDLE → COUNTDOWN`

#### Pause (any active state)

* Event: `SESSION_PAUSE`
* Transition: `ANY → PAUSED`
* Effects:

  * mic continues
  * scoring paused
  * visuals dimmed
  * shape frozen

#### Resume (PAUSED)

* Event: `SESSION_RESUME`
* Transition: `PAUSED → previous state`

#### Stop

* Event: `SESSION_STOP`
* Transition:

  * → confirmation modal
  * confirm → `COMPLETED`
  * cancel → return

---

### 6.3 Pitch Detection → UI Binding

For each audio frame:

**Input:**

```json
{
  "freq": float,
  "midiFloat": float,
  "nearestMidi": int,
  "cents": float,
  "confidence": float,
  "vibrato": {
    "detected": boolean,
    "depth": float,
    "rate": float
  }
}
```

---

### 6.4 State Transitions (Exact Logic)

#### IDLE → COUNTDOWN

* Trigger: `SESSION_START`
* Visual:

  * countdown numbers
  * no pitch feedback

---

#### COUNTDOWN → SEEKING_LOCK

* Trigger: countdown finished
* Visual:

  * pitch line activates
  * shape appears semi-transparent

---

#### SEEKING_LOCK → LOCKED

* Condition:

  * |cents| ≤ tolerance
  * confidence ≥ minConfidence
  * duration ≥ lockAcquireTime
* Visual:

  * halo solidifies
  * shape rigid
  * lock sound (optional)

---

#### LOCKED → DRIFT_CANDIDATE

* Condition:

  * |cents| > driftThreshold
  * duration ≥ driftCandidateTime
* Visual:

  * shape tremble
  * halo flicker

---

#### DRIFT_CANDIDATE → LOCKED

* Condition:

  * |cents| ≤ tolerance
* Visual:

  * tremble stops
  * no penalty

---

#### DRIFT_CANDIDATE → DRIFT_CONFIRMED

* Condition:

  * |cents| > driftThreshold
  * duration ≥ driftConfirmTime
* Visual:

  * shape fractures
  * screen dims
* Event logged: `DRIFT_EVENT`

---

#### DRIFT_CONFIRMED → DRIFT_REPLAY

* Only in Drift Awareness mode
* Automatic transition
* No user input

---

#### ANY → LOW_CONFIDENCE

* Condition:

  * confidence < minConfidence
* Visual:

  * desaturation
  * “?” icon
* Scoring paused

#### LOW_CONFIDENCE → previous state

* Condition:

  * confidence restored

---

### 6.5 Direct Gestures on Live Pitch Screen

#### Horizontal drag on Pitch Line

* Disabled during active session
* Enabled only in passive Quick Monitor mode:

  * shifts visual center reference
  * does NOT affect scoring

#### Long press on Shape

* Opens **Pitch Info Overlay**:

  * freq
  * midi
  * cents
* Overlay disappears on release

---

## 7. Drift Replay Screen (`DRIFT_REPLAY`) Interactions

---

### 7.1 Automatic Entry

* Triggered ONLY by `DRIFT_CONFIRMED`
* Live Pitch pauses underneath

---

### 7.2 Replay Controls

#### Tap “Play Before”

* Plays reference tone at previous locked pitch

#### Tap “Play After”

* Plays reference tone at drifted pitch

#### Tap “Play User”

* Plays recorded snippet
* Disabled if audio recording OFF

---

### 7.3 Resume Button

#### Tap

* Event: `DRIFT_REPLAY_RESUME`
* Transition:

  * → `LIVE_PITCH`
  * state resets to `SEEKING_LOCK`
* No score penalty for replay duration

---

## 8. Analyze Screens Interactions

---

### 8.1 Session List (`ANALYZE_SESSIONS`)

#### Tap session item

* → `SESSION_DETAIL`

---

### 8.2 Session Detail (`SESSION_DETAIL`)

#### Drag timeline

* Horizontal scroll through time
* Vertical pinch zoom:

  * zooms cents scale

#### Tap drift marker

* Opens `DRIFT_REPLAY` (read-only mode)

---

## 9. Library Interactions

---

### 9.1 Reference Tone Editor (`REFERENCE_EDITOR`)

#### Drag pitch wheel

* Snaps to semitone
* Plays preview in real time

#### Tap “Save”

* Adds preset to library
* Available everywhere as reference

---

## 10. Settings Interactions

---

### 10.1 Representation Editor (`REPRESENTATION_EDITOR`)

#### Tap color

* Opens color picker
* Live preview updates everywhere instantly

#### Tap shape

* Opens shape selector
* Immediate global update

⚠️ Confirmation required before closing if mapping changed.

---

## 11. System & Edge Case Interactions

---

### 11.1 App Backgrounded

* Session auto-paused
* Resume prompt shown on return

---

### 11.2 Audio Route Change

* Show banner:

  > “Audio output changed”
* Auto-adjust latency compensation

---

### 11.3 Mic Permission Revoked

* Immediate session stop
* Full-screen error
* CTA to system settings

---

## 12. Consistency Guarantees

| Concept    | Screen         | Interaction     |
| ---------- | -------------- | --------------- |
| Drift      | Live Pitch     | Same thresholds |
| Lock       | All modes      | Same visual     |
| Pitch Line | Everywhere     | Same behavior   |
| Replay     | Live + Analyze | Same UI         |

No special cases.