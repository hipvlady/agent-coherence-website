# Refactor-Demo Recording Assets

> **STATUS: DRAFT.** Staged under `outreach/` — not served on agent-coherence.dev,
> not linked from anywhere on the live site.

This directory holds the assets that wrap the agent-coherence
**refactor-demo** (shipped in v0.7.1 under `examples/refactor_demo/`)
into recorded artifacts suitable for the `/code` page, README, and
LinkedIn/HN distribution. The demo itself — Python sub-agents, TS
fixture, real `tsc`, three variants — lives in the agent-coherence
main repo. The assets here are about *recording* it, not implementing it.

## What's here

| File | Purpose |
|---|---|
| `record.sh` | Bash wrapper around `asciinema rec` + `python -m examples.refactor_demo.main`. Records any of three variants or all three. |
| `state-transitions.svg` | 12-second looping animated SVG showing t=0..t=3 state transitions for the happy path. Embed as visual hook in `/code` hero. |
| `README.md` | This file. |
| `*.cast` *(not committed)* | Output from `record.sh`. Per-take artifacts; review before uploading. |

## The three variants (from `examples/refactor_demo/README.md`)

| Variant | Mechanism | What the cast will show |
|---|---|---|
| `with` | Default `CCSStore`, lazy strategy. Executor reads v1 (cache SHARED), planner writes v2 (executor cache → INVALID), executor re-reads at commit → fetches v2. | `cache_hit=False` on commit-time get · `committed spec v2` · `tsc: OK` |
| `no-invalidation` | `disable_invalidation(store)` patches the bus' `publish_invalidation` to no-op. Executor cache stays SHARED at v1; commit-time re-read returns cached v1. | `cache_hit=True` on commit-time get · `committed spec v1` · `tsc: FAIL TS2305` on `src/utils/session.ts` |
| `context-cache` | Executor never re-reads from the store; commits from the v1 spec it captured at read time. Mirrors LLM context-window behavior. | One executor `get` in the event stream · `committed spec v1` · `tsc: FAIL TS2305` |

**`no-invalidation`** is the protocol-level proof — a single-line bus
suppression turns the same code path into a failing variant.

**`context-cache`** is the audience-facing failure — same `tsc` outcome
but the mechanism (executor never re-reads) is the one LLM agents
actually exhibit in production.

The happy path (`with`) is the conclusion. Recording all three lets
you choose the framing per distribution surface — and prove that the
protocol, not the orchestration, is what differentiates.

## Why asciinema, not screen-recorded video

The shipped demo is entirely terminal output: Python prints the
narration, JSON task spec is loaded/saved, `npx tsc --noEmit` runs
inline, the result prints. No IDE, no browser, no GUI.

Asciinema:
- One-command record / playback
- `--idle-time-limit 1.2` smart-compresses any wait > 1.2s — the
  demo's natural pauses don't pad the cast
- Tiny output (5–30 KB JSON) vs 50+ MB MP4
- Embeddable as SVG, HTML widget, or GIF (via `agg`)
- Self-verifying — engineers trust raw terminal output far more than
  edited video, which is R2's "real `tsc`, no fakes" bar
- Re-recordable in seconds when the demo flow changes

For LinkedIn-feed distribution (R13, post-discovery), convert the cast
to GIF or screen-record the cast itself playing in a clean terminal.
Both are derivative work on top of the canonical asciinema artifact.

## Prerequisites

```
brew install asciinema      # or: pipx install asciinema
node --version              # need Node 18+ for npx tsc
python3 --version           # need 3.11+

# In an active Python env where agent-coherence is editable-installed:
cd ~/projects/agent-coherence
pip install -e ".[langgraph,benchmark]"
```

The `record.sh` script verifies all of these before recording.

## Recording

```bash
# Records all three back to back; outputs <variant>.cast in this directory.
./record.sh all

# Or one at a time:
./record.sh with
./record.sh no-invalidation
./record.sh context-cache

# Override agent-coherence repo location:
AGENT_COHERENCE_REPO=/somewhere/else ./record.sh all

# Override cast output directory:
CAST_DIR=/tmp ./record.sh with
```

On first run, `record.sh` runs `npm install` in
`examples/refactor_demo/fixture_repo_ts/` and verifies the fixture
builds clean on its as-checked-in source. Subsequent runs skip this.

The demo binary handles its own:
- Temp-directory fixture staging (source `fixture_repo_ts/` is never mutated)
- Planner/executor coordination through `CCSStore`
- Real `tsc --noEmit` invocation against the temp copy
- Result printing

The cast captures the demo's own structured output, which is already
designed to read well in terminal — no overlay annotations needed.

## Reviewing a take

```bash
asciinema play with.cast
asciinema play -s 2 with.cast     # 2x speed for quick scan
```

To trim or edit, the cast is newline-delimited JSON. Open it,
edit the timing or events array, save. Or use
[`asciinema-edit`](https://github.com/cassidoo/asciinema-edit).

## Publishing checklist

Do NOT upload (`asciinema upload <cast>`) or embed in `/code` before
the 2026-05-16 discovery synthesis and the 2026-05-17 branch decision.
Per requirements doc R14 + plan Unit 8.

After Phase 1 branch decision, if `coding-agent-dominant`:

1. `asciinema upload with.cast` (and `context-cache.cast`) → returns
   public cast URLs + embed snippets
2. In `site/code/index.html`, replace the `<div class="demo-placeholder">`
   with the asciinema-player HTML/JS embed
3. Drop `state-transitions.svg` into the hero of `/code` for the
   visual hook — the SVG explains; the cast proves
4. Remove the three `noindex`/`nofollow` meta tags + the draft banner
   from `/code`
5. Add a `<url>` entry to `site/sitemap.xml`
6. (Optional) Link from header nav on `/index.html`
7. (Optional, for LinkedIn) Convert one cast to GIF via
   [`agg`](https://github.com/asciinema/agg)

## state-transitions.svg

12-second looping animation. Five phases, each ~2.4s visible:

| Phase | What's shown |
|---|---|
| t=0 | Planner writes v1 to coordinator. Executor cache: empty. |
| t=1 | Executor reads v1 from coordinator. Executor cache: v1. |
| t=2 | Planner writes v2. CCSStore publishes invalidation. Executor cache flashes red → INVALID. |
| t=3 | Executor's next `get()` refetches v2. Executor cache: v2. |
| ✓   | Final state, checkmark, `tsc: PASS`. |

CSS keyframe animations (no SMIL) — works in Safari, Chromium, Firefox.
Drop it in as `<img src="state-transitions.svg" alt="...">` or inline
the `<svg>` block. The animations ride with the markup either way.

Shows the `with` variant only. The `no-invalidation` and `context-cache`
failure paths are documented in the cast, not the SVG, because two
animated paths in one frame would dilute the explanatory clarity the
SVG is meant to deliver.
