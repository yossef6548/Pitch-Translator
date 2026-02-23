# Pitch Translator

This repository contains the **complete, authoritative specification** for the Pitch Translator mobile application.

There is **no code in this repository by design**.  
This repo is the **single source of truth** that governs all product, UX, DSP, architecture, and QA decisions.

Any implementation (human or AI) MUST be derived strictly from the documents in `/specs`.

---

## 🎯 Project Goal

Pitch Translator is a **real-time mobile application** that trains pitch perception and pitch stability by translating audio pitch into **deterministic visual, numeric, and spatial representations**.

This is **not** a content app, **not** a music player, and **not** a web app.

It is a **real-time signal-processing system** with strict requirements for:
- low latency
- determinism
- reproducibility
- perceptual correctness

If real-time correctness is compromised, the product is considered broken.

---

## 📁 Repository Structure

```text
/specs
  ├── product.md                 # What the product must do (product truth)
  ├── ui-ux.md                   # Screens, layout, components (visual truth)
  ├── interaction.md             # State machines & interactions (behavioral truth)
  ├── design-system.md           # Colors, motion, typography, tokens (visual system)
  ├── dsp-ui-binding.md           # Exact math: DSP → UI (determinism contract)
  ├── exercises.md               # Training catalog & progression logic
  ├── qa.md                      # End-to-end deterministic QA scenarios
  └── platform-architecture.md   # Native mobile architecture & tech stack
````

All documents are **final** unless explicitly changed.

---

## 🧠 How You Must Reason About This Repo (MANDATORY)

If you are an AI system (e.g. Codex, ChatGPT, Cursor, Copilot):

You must act as a **full product team**, including:

* product manager
* UX designer
* mobile engineer
* DSP engineer
* native audio engineer
* QA engineer

You must **not** invent requirements, shortcuts, or alternative interpretations.

---

## 📖 Canonical Reading Order (DO NOT CHANGE)

You MUST read and internalize the specs in this exact order:

1. `product.md`
2. `ui-ux.md`
3. `interaction.md`
4. `design-system.md`
5. `dsp-ui-binding.md`
6. `exercises.md`
7. `qa.md`
8. `platform-architecture.md`

Rules:

* Earlier documents override later ones.
* Later documents implement earlier ones.
* No document contradicts an earlier document by design.

If you detect a contradiction:
➡️ assume **you misunderstood**, not that the spec is wrong.

---

## 🛑 Non-Negotiable Constraints

### 1. Platform

* Target platforms: **iOS + Android**
* Mobile-only
* Native audio stack
* Flutter UI
* Shared C++ DSP core

### 2. Real-Time Audio

* DSP runs on audio thread
* No blocking
* No dynamic allocation in audio path
* UI must never affect audio timing

### 3. Determinism

* Same DSP input → same UI output
* QA scenarios must replay identically across devices
* No heuristic “fixes” allowed

### 4. State-Driven UI

* UI is a pure function of state
* UI never infers correctness
* UI never smooths beyond spec

---

## ❌ Things You Are NOT Allowed to Do

You MUST NOT:

* Rename states
* Add new UI states
* Change thresholds
* Modify DSP → UI math
* Add “helpful” smoothing or heuristics
* Assume web / PWA constraints
* Bypass QA scenarios
* Skip vibrato handling rules
* Replace native audio with web audio

If something feels unclear:
➡️ re-read the specs.
➡️ do not invent behavior.

---

## ✅ What You ARE Allowed to Do

You MAY:

* Implement the system end-to-end
* Create internal modules and abstractions
* Optimize performance within constraints
* Write tests derived from `qa.md`
* Add tooling (DSP replay, QA harness)
* Propose spec changes **only if explicitly requested**

---

## 🧪 Definition of “Correct Implementation”

An implementation is considered **correct** if and only if:

* All QA scenarios in `qa.md` pass
* DSP → UI mappings match `dsp-ui-binding.md`
* UI states match `interaction.md`
* Visual behavior matches `design-system.md`
* Exercise logic matches `exercises.md`
* Architecture matches `platform-architecture.md`

“Feels good” or “looks right” is **not** sufficient.

---

## 🧭 How to Proceed (For Codex / AI)

You should:

1. Read all specs in order
2. Design the full system architecture
3. Implement DSP core
4. Implement native audio layers
5. Implement Flutter UI
6. Bind DSP frames to UI strictly via spec
7. Implement training engine
8. Implement persistence
9. Implement QA harness
10. Validate against all QA scenarios

You must behave as if **this will ship to real users**.

---

## 🔒 Final Authority Rule

This repository **is the product**.

If behavior is not specified here:

* it does not exist
* it must not be added

If behavior is specified here:

* it must exist
* it must behave exactly as described

---

## ✅ Acknowledgment

By implementing from this repository, you acknowledge that:

* the specs are complete
* the specs are consistent
* correctness matters more than speed
