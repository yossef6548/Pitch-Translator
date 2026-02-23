# Full Product Specification

## 0) One-sentence definition

A cross-platform, real-time pitch perception and pitch production training system that **translates pitch into stable visual–numeric representations**, detects and quantifies **drift** instantly, and trains users to lock pitch alone, with audio references, and in “group singing” scenarios.

---

## 1) Goals & Success Criteria

### 1.1 Primary user outcomes

1. User can **hear a pitch** and reproduce it within **±20 cents** on first attempt.
2. User can **sustain a pitch** for 10 seconds with drift ≤ **±15 cents**.
3. User can sing along with a “group” audio track and remain within **±25 cents** of the reference for 80% of the time.
4. User develops automatic internal mapping: pitch → **note name + numeric index + visual signature**.

### 1.2 App performance outcomes

* End-to-end latency (mic → pitch estimate → visuals/haptics) ≤ **30 ms** target, ≤ **50 ms** maximum.
* Pitch detection accuracy for voice (80 Hz–1100 Hz) within **±5 cents** in clean conditions, **±10 cents** in typical noise.
* Stable tracking under vibrato without false “off-pitch” flags (configurable).

### 1.3 Measurable metrics (captured locally, optional cloud sync)

* “On-target time %” per exercise
* Median cents error
* Drift rate (cents/sec)
* Recovery time after drift (ms)
* Relative-interval accuracy (semitones and cents)
* Consistency score across sessions

---

## 2) Target Users / Personas

### 2.1 Primary persona: “Unaware Drifter”

* Cannot reliably detect when pitch drifts.
* Responds well to numeric/visual feedback.
* Wants fast improvement and “proof” of progress.

### 2.2 Secondary persona: “Relative Pitch Builder”

* Can match pitch sometimes but fails on intervals/melodies.
* Needs discrete steps and arithmetic-like training.

### 2.3 Tertiary persona: “Choir / Group Integrator”

* Fine alone, fails in group/noisy environments.
* Needs tracking + locking with competing audio.

---

## 3) Platforms & Device Support

### 3.1 Platforms

* iOS (iPhone + iPad)
* Android

Pitch Translator is **mobile-only**. No desktop application is in scope for this repository/spec set.

### 3.2 Hardware requirements

* Microphone access (required)
* Optional: headphones strongly recommended for certain modes
* Optional: Bluetooth MIDI device for reference / external input (future-proofed, not required for initial implementation)

---

## 4) Key Concepts & Terminology

* **Pitch**: perceived frequency (Hz) mapped to musical note space.
* **Cents**: logarithmic pitch difference. 100 cents = 1 semitone.
* **Target**: pitch user must match.
* **Lock**: state where user is within threshold for a minimum time.
* **Drift**: sustained departure from a locked pitch beyond threshold.
* **Reference**: audio played by app (tone/choir/song) or external audio being analyzed.
* **Representation**: visual+numeric mapping (color/shape/note number) for each pitch class.

---

## 5) Non-Functional Requirements

### 5.1 Audio / DSP performance

* Real-time processing on device with CPU budget:

  * Mobile: ≤ 10% CPU average on mid-tier device during training
* Must handle:

  * background noise
  * mild reverb
  * typical phone mic quality

### 5.2 Privacy

* Default: all analysis local, no audio uploaded.
* User can opt-in to cloud sync of **features** (pitch traces), never raw audio unless explicitly enabled for coach sharing.

### 5.3 Accessibility

* Color-blind modes (alternate palettes)
* Shapes + patterns always accompany color
* Screen reader labels for major UI elements
* Haptic feedback for “too high/too low” + lock state

---

## 6) Core Product Pillars (must ship in final app)

1. **Pitch Translation Layer**
   Converts live pitch into:

   * Note name (A4, C#3)
   * MIDI note number (integer)
   * cents deviation from nearest semitone
   * pitch class color
   * geometric shape + stability animation
   * optional “numeric pitch line” position

2. **Unmissable Error Feedback**
   Off-pitch must be detectable even for users who cannot hear it:

   * visual instability
   * “distance” meter
   * directional cue (up/down)
   * optional haptic pulses (frequency proportional to error magnitude)

3. **Drift Detection & Replay**
   Identify exact drift moments, replay them, show quantitative deltas.

4. **Training Engine**
   Structured exercises with:

   * adaptive difficulty
   * mastery criteria
   * spaced repetition scheduling

5. **Group Simulation**
   Virtual choir / multi-voice reference with adjustable complexity.

---

## 7) User Experience & Information Architecture

### 7.1 Top-level navigation

* Home (Today’s Training)
* Train (Catalog)
* Analyze (History + Replays)
* Library (Reference tones, choir, songs/imports)
* Settings

### 7.2 First-run onboarding (mandatory)

1. Permissions: microphone, notifications (optional), health/haptics (optional)
2. Calibration:

   * noise floor measurement (10 sec)
   * microphone latency estimation
   * headset detection & recommendation
3. Voice range quick test:

   * find comfortable low/high pitch
   * set initial exercise octave range
4. Representation choice:

   * default color palette
   * shape set
   * numeric mode on/off
5. “Baseline assessment” (5 minutes) to set initial difficulty.

---

## 8) Detailed Feature Requirements

## 8.1 Live Pitch Screen (core screen used everywhere)

### 8.1.1 Display elements (always visible)

* Current detected note (e.g., **G3**)
* MIDI number (e.g., **55**)
* Current frequency (Hz) (optional toggle)
* Cents deviation from target (e.g., **-23 cents**) with sign and direction arrow
* Target note + target MIDI + target frequency
* Confidence indicator (0–1) showing detection reliability

### 8.1.2 Visual translation widgets

All can be toggled, but default is ON:

**A) Pitch Line (Numeric Number Line)**

* horizontal axis: semitones
* center: target note
* user dot moves continuously in cents (smooth)
* snap lines at each semitone

**B) Color Flood / Halo**

* When locked: stable color fill/halo
* When off: desaturate + flicker proportional to error

**C) Shape Stability**

* Each pitch class maps to a base shape
* On target: shape rigid
* Off target: shape warps in direction:

  * too low: compress down
  * too high: stretch up
* Magnitude of warp proportional to cents error

**D) Drift Trail**

* leaving a ghost trail of last 2 seconds of pitch path
* color-coded by “on/off” state

### 8.1.3 Control elements

* Start / Pause / Stop / Restart / Exit
* Input source selector:
  * Microphone (live)
  * Imported audio file analysis (offline) — from Library → Imported Audio
* Reference playback:
  * On/Off
  * Volume
  * Type (sine / piano / choir / instrument)
* Latency compensation toggle (auto/manual)
* “Lock threshold” quick selector:
  * Strict (±10c)
  * Standard (±20c)
  * Lenient (±35c)

---

## 8.2 Pitch Freezing Mode (foundation exercise)

### 8.2.1 Goal

Maintain a single pitch with maximum stability.

### 8.2.2 Flow

1. App plays target pitch (optional).
2. Countdown 3…2…1
3. User sings/holds vowel “ah” (configurable).
4. Lock is achieved if within threshold for **300 ms** continuous.
5. Timer runs until:

   * user reaches required duration (e.g., 10 sec), or
   * fails conditions too often

### 8.2.3 Scoring

* Lock acquisition time
* Stability score (std dev of cents)
* Drift events count
* Longest continuous lock streak

### 8.2.4 Adaptive difficulty

* Start with ±35c, 3 sec
* Progressively tighten threshold and duration
* Introduce “silent reference” (no tone) once user reaches mastery

---

## 8.3 Drift Awareness Mode (your “main fix”)

### 8.3.1 Drift definition (authoritative)

A drift event occurs when:

1) The user has been in `LOCKED` state for at least `LOCK_REQUIRED_BEFORE_DRIFT_MS`, then  
2) `abs(effective_error) > DRIFT_THRESHOLD_CENTS` continuously for at least `DRIFT_CONFIRM_TIME_MS`.

Notes:
* `DRIFT_THRESHOLD_CENTS` is provided by the **exercise configuration** (defaults depend on difficulty level as defined in `exercises.md`).
* `effective_error` is defined in `dsp-ui-binding.md` (vibrato-aware).
* All timing constants are defined in `dsp-ui-binding.md` under “Global Defaults & Constants”.

### 8.3.2 Detection requirements

* Must ignore vibrato within vibrato_profile (config):

  * vibrato freq 4–8 Hz
  * vibrato depth up to 30 cents (default)
* Must distinguish:

  * drift (gradual deviation)
  * jump (sudden pitch shift)
  * drop-out (no reliable pitch detected)

### 8.3.3 Replay UX

After each drift event:

* freeze screen
* show “Before” pitch signature (note + color + shape)
* show “After” pitch signature
* show numeric delta:

  * semitones difference (e.g., +1)
  * cents difference (e.g., +43c)
  * time to drift (ms)
* play back:

  * reference tone for before pitch (500 ms)
  * reference tone for after pitch (500 ms)
  * optional: user recorded audio snippet (if enabled)

---

## 8.4 Relative Pitch as Arithmetic Mode

### 8.4.1 Concept

Intervals are presented as numeric operations:

* +1, +2, +3… semitones
* user learns mapping between change and target

### 8.4.2 Exercise types

* “Step” drills: +1/-1 only
* “Jump” drills: +4, +7, -5 etc.
* “Two-step” drills: +3 then -2 (melody micro-sequences)

### 8.4.3 Presentation

Screen shows:

* Base note: MIDI integer
* Operation: +N
* Target note predicted
  User must sing target.

### 8.4.4 Mastery criteria

* 10 correct in a row within ±20c
* response time under 2 seconds (configurable)

---

## 8.5 Group Simulation Mode (Virtual Choir)

### 8.5.1 Audio generation

Choir is synthesized or sample-based with:

* 4 voices (SATB) minimum
* adjustable:

  * vibrato
  * dynamic swells
  * slight pitch spread (humanization)
  * room reverb

### 8.5.2 Scenarios

1. **Unison lock**: choir holds one pitch, user matches.
2. **Chord anchor**: choir sings chord, user matches a chosen chord tone.
3. **Moving anchor**: choir modulates slowly, user must follow.
4. **Distraction**: extra voices/sounds added, user must stick to target.

### 8.5.3 Visual alignment

* Choir target shown as thick stable bar
* User pitch dot must stay within bar area
* If user drifts, dot separates with elastic animation

### 8.5.4 Evaluation

* percentage of time within tolerance
* “stickiness” score: how often user returns to anchor after leaving
* confusion score: jumps to wrong chord tones

---

## 8.6 Pitch-to-Note “Translator” Mode (Listening, not singing)

### 8.6.1 Goal

Train auditory identification: hear a pitch → internal representation.

### 8.6.2 Tasks

* App plays a note, user must select:

  * note name, OR
  * MIDI number, OR
  * “color+shape” signature
* Adaptive:

  * start with few notes
  * expand to full octave
  * then multiple octaves

### 8.6.3 “Synesthesia Builder”

User can design their own mapping:

* pitch class → color
* pitch class → shape
* octave → brightness / size
  App must keep mapping stable forever unless user explicitly changes it.

---

## 8.7 Full Session Analytics & History

### 8.7.1 Data recorded per exercise (feature-level)

* timestamps
* pitch trace (Hz)
* note trace (nearest semitone)
* cents error trace
* confidence trace
* drift markers
* lock markers
* reference pitch trace (if any)

### 8.7.2 Visualizations (Analyze tab)

* timeline graph of cents error (scrollable)
* drift events list (tap to replay)
* heatmap: which notes are weakest
* trend charts:

  * median cents error over days
  * stability score trend
  * drift count trend

### 8.7.3 Export

* JSON export of sessions
* CSV export of metrics
* optional share report PDF

---

## 9) Audio & Pitch Detection Specification (DSP)

## 9.1 Sampling & buffering

* Sample rate: 48k preferred, 44.1k acceptable
* Frame size: 1024 samples (approx 21ms @48k) with overlap
* Hop size: 256 samples (approx 5.3ms @48k)
* Total latency must remain within constraints.

## 9.2 Pitch detection algorithm requirements

Must support:

* monophonic voice
* handle formants / noise
* robust tracking during vowel changes

Suggested approach (implementation team decides, must meet metrics):

* multi-method ensemble:

  * YIN or McLeod Pitch Method (MPM)
  * autocorrelation refinement
  * harmonic product spectrum cross-check
* choose estimate with highest confidence

## 9.3 Confidence scoring

Confidence ∈ [0,1] computed from:

* periodicity measure
* harmonicity
* SNR
* stability across recent frames

When confidence < threshold (default 0.6):

* UI shows “low confidence”
* drift detection pauses
* score is not penalized

## 9.4 Note mapping

Given frequency f:

* midi = 69 + 12 * log2(f / 440)
* nearestMidi = round(midi)
* cents = (midi - nearestMidi) * 100

Support configurable tuning reference:

* A4 = 440 default
* allow 432 / custom

## 9.5 Vibrato handling

Compute short-time pitch modulation:

* if modulation freq in 4–8Hz and depth < vibratoDepthLimit,

  * treat as “on pitch” if mean within tolerance
  * display optional vibrato indicator

---

## 10) Architecture Specification

## 10.1 High-level components

1. **Audio Engine (Realtime)**

   * capture mic
   * playback reference
   * mixing / routing
   * echo cancellation option

2. **Pitch Analyzer (DSP)**

   * pitch estimation
   * confidence
   * smoothing / outlier rejection
   * vibrato detection

3. **Training Engine**

   * exercise state machine
   * adaptive difficulty logic
   * mastery tracking
   * spaced repetition scheduler

4. **Visualization Engine**

   * rendering pitch line
   * shape warping
   * color floods
   * animations tied to cents error

5. **Data Layer**

   * local database (SQLite)
   * session storage
   * export/import

6. **Cloud Sync (optional)**

   * user auth optional (Apple/Google/email)
   * encrypted sync of metrics/traces
   * coach sharing mode

## 10.2 Data model (simplified)

* UserProfile

  * representationMapping (colors/shapes)
  * tuningSettings
  * thresholds
  * voiceRange
* Session

  * date
  * mode
  * targetConfig
  * metricsSummary
* Trace

  * arrays: time, freq, midi, cents, confidence
  * markers: lock, drift, jump, dropout

## 10.3 Internal APIs (module boundaries)

* AudioEngine:

  * startMic(), stopMic()
  * playReference(pitch, timbre, volume)
  * setOutputRoute(headphones/speaker)
* PitchAnalyzer:

  * processAudioFrame(samples) -> PitchFrame {freq, midiFloat, cents, confidence, vibratoInfo}
* TrainingEngine:

  * startExercise(config)
  * onPitchFrame(frame)
  * getState() -> UIState
  * endExercise()
* Analytics:

  * computeMetrics(trace, markers) -> summary
  * generateReports()

---

## 11) Settings (must be exhaustive)

### 11.1 Pitch feedback settings

* tolerance presets and custom (±cents)
* drift threshold
* lock acquisition time
* vibrato depth tolerance
* smoothing level (low/med/high) — DSP-side only, must remain deterministic and must not modify DSP → UI binding math

### 11.2 Representation settings

* mapping editor (pitch class → color/shape)
* octave mapping rule (brightness/size)
* colorblind palettes
* numeric overlays on/off
* “minimal mode” toggle

### 11.3 Audio settings

* reference timbre (sine/piano/choir)
* reference volume
* latency compensation (auto/manual slider)
* noise gate sensitivity
* headphone recommended prompts

### 11.4 Data & privacy

* local-only vs cloud sync
* store raw audio snippets for drift replay (default OFF)
* export controls
* delete account / delete data

---

## 12) QA & Test Plan Requirements

### 12.1 Functional tests

* correct pitch mapping across full voice range
* drift detection triggers correctly
* vibrato not misclassified
* replay shows correct before/after deltas
* adaptive difficulty updates correctly

### 12.2 Performance tests

* latency measurement harness
* CPU usage on low/mid/high devices
* memory constraints with long sessions

### 12.3 Audio edge cases

* background music
* noisy room
* mic clipping
* low voice volume
* falsetto transitions

### 12.4 Accessibility tests

* colorblind mode verified by simulation
* no color-only critical cues
* haptics optional but usable

---

## 13) Deliverables for the Dev Team

1. UI/UX designs for all screens + interactions
2. Audio engine implementation per platform
3. DSP pitch analyzer meeting accuracy & latency
4. Training engine with defined state machines
5. Local persistence + analytics computations
6. Export/share pipeline
7. Optional cloud sync (feature flags)
8. Automated tests + performance benchmarks

---

# Appendix A — State Machines (High-level)

### A1 Pitch Freezing state machine

* Idle → Countdown → SeekingLock → Locked → Drifted → Completed/Failed

Transitions determined by:

* confidence
* cents error within threshold
* time conditions

### A2 Drift Awareness state machine

* Locked → Monitoring → DriftCandidate → DriftConfirmed → Replay → Resume

---

# Appendix B — Mastery Definitions (Defaults)

* Freeze Mastery:

  * 10 sec hold
  * std dev ≤ 12 cents
  * max drift events ≤ 1
* Group Unison Mastery:


  * 80% within ±25c for 30 sec
