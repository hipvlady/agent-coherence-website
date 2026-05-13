# Planner / Executor Demo — Recording Assets

> **STATUS: DRAFT.** Staged under `outreach/` so nothing here is served on
> agent-coherence.dev or referenced from the live site. Moves into the
> agent-coherence main repo (alongside `examples/refactor_demo/`) once
> the demo fixtures and Python agent scripts land there.

This directory holds the assets that produce the 2–3 minute demo described
in the requirements doc (R1–R6) and the implementation plan
(Phase A — demo foundation). The demo proves write-side coherence by
showing two scripted sub-agents — a planner and an executor — collaborating
on a shared task spec, with and without `CCSStore` invalidation,
verified by real `tsc`.

## What's here

| File | Purpose |
|---|---|
| `record.sh` | Bash script that runs the demo flow under `asciinema rec`. Two variants: `with-coherence` and `without-coherence`. |
| `state-transitions.svg` | 12-second looping animated SVG of t=0..t=3, used as the visual explanation alongside the cast. Embeddable in `/code` hero, GitHub README, blog. |
| `README.md` | This file. |
| `*.cast` *(not committed)* | Output from `record.sh`. Per-take artifacts; review before uploading. |

## Why asciinema, not a screen-recorded video

The demo is entirely terminal: Python scripts (`planner.py`, `executor.py`),
a JSON task spec, real `tsc` output. There is no IDE, no browser, no GUI.
Asciinema gives us:

- One-command record, one-command playback
- `--idle-time-limit` smart-compresses any wait > 1.2s — natural sleeps
  in the script don't pad the cast
- Tiny output (5–30 KB JSON) vs 50+ MB MP4
- Embeddable as SVG, HTML widget, or GIF (asciinema-to-gif)
- Self-verifying — engineers trust raw terminal output far more than
  edited video, which is the R2 "real `tsc`, no fakes" requirement
- Re-recordable in seconds when the demo flow changes

For LinkedIn-feed distribution (R13, post-discovery), export the cast to
GIF via [`agg`](https://github.com/asciinema/agg) or screen-record the
cast itself playing in a clean terminal. Both are derivative work on
top of the canonical asciinema artifact — not a new recording.

## Prerequisites

```
brew install asciinema      # or: pipx install asciinema
node --version              # need Node 18+ for `npx tsc`
python3 --version           # need 3.10+
```

Plus a checkout of the agent-coherence main repo with `examples/refactor_demo/`
(planner + executor scripts) and `examples/refactor_demo_fixture/` (the
TypeScript fixture with the renamed-symbol scenario, ~4 source files,
strict tsconfig). Both are scoped in plan Unit 1.

## Recording

```bash
# Records both variants back to back; outputs with-coherence.cast and
# without-coherence.cast in this directory.
./record.sh both

# Or record one at a time:
./record.sh with-coherence
./record.sh without-coherence

# Override repo location:
AGENT_COHERENCE_REPO=/somewhere/else ./record.sh both
```

The script:
1. Verifies asciinema, python3, npx are on PATH
2. Stages the TS fixture into `/tmp/refactor_demo/` so the recorded cast
   shows clean paths (no `/Users/you/...` leakage)
3. Writes the narration script (`/tmp/refactor_demo/_run.sh`) inline,
   tailored to the chosen variant
4. Invokes `asciinema rec` with locked terminal geometry (120×32) so
   re-takes look consistent

Annotations appear as `# t=N — <narration>` lines printed by the
narration script — they show up as terminal output in the cast, which
is the in-context format engineers expect. No overlay tooling required.

## Reviewing a take

```bash
asciinema play with-coherence.cast
asciinema play -s 2 with-coherence.cast    # 2x speed for quick review
```

To trim or edit, the cast is just newline-delimited JSON. Open it,
edit the timing or the events array, save. Or use
[`asciinema-edit`](https://github.com/cassidoo/asciinema-edit).

## Publishing

Do NOT upload (`asciinema upload <cast>`) or embed in `/code` before
the 2026-05-16 discovery synthesis and the 2026-05-17 branch decision.
Per requirements doc R14 + plan Unit 8, no public artifact ships
before the gate.

After Phase 1 branch decision, if `coding-agent-dominant`:
1. `asciinema upload with-coherence.cast` → returns a cast URL
2. Embed the cast in `site/code/index.html` (the
   `<div class="demo-placeholder">` block) using the asciinema-player
   HTML/JS snippet from the upload page
3. Drop the `state-transitions.svg` in the hero of `/code` for the
   visual hook (the SVG is the explanation; the cast is the proof)
4. Remove the `noindex` meta tags + draft banner from `/code` to flip
   the page live
5. Add `/code/` to `sitemap.xml`

## state-transitions.svg

12-second looping animation. Five phases, each ~2.4 seconds visible:

| Phase | What's shown |
|---|---|
| t=0 | Planner writes v1 to the coordinator. Executor cache: empty. |
| t=1 | Executor reads v1 from coordinator. Executor cache: v1. |
| t=2 | Planner writes v2. CCSStore publishes invalidation. Executor cache flashes red → INVALID. |
| t=3 | Executor's next `get()` refetches v2. Executor cache: v2. |
| ✓   | Final stable state with a checkmark; `tsc: PASS`. |

CSS keyframe animations (no SMIL) — works in every modern browser
including Safari, Chromium, Firefox. Static elements (boxes, footer)
never animate; only the per-phase groups fade in/out via `@keyframes`.
The invalidation flash is a separate animation on a red border element
that pulses once around phase 2.

Drop it into HTML with a plain `<img src="state-transitions.svg" alt="...">`
or inline the `<svg>` block. The animations are CSS-driven and ride
with the markup either way.
