#!/usr/bin/env bash
# Asciinema recording script for the agent-coherence refactor-demo (v0.7.1+).
#
# STATUS: DRAFT — staged in the website repo's outreach/ folder.
# Moves into the agent-coherence main repo when the demo recording flow
# is ready to ship publicly (post 2026-05-17 branch decision).
#
# Usage:
#   ./record.sh with               # records the with-coherence happy path
#   ./record.sh no-invalidation    # records the protocol-level failure proof
#   ./record.sh context-cache      # records the audience-facing failure mode
#   ./record.sh all                # records all three back to back
#
# The demo binary (examples.refactor_demo.main) does its own fixture
# staging, narration printing, and tsc invocation. This script is a thin
# asciinema wrapper around it — no /tmp setup, no inline narration scripts.
#
# Variant taxonomy (from examples/refactor_demo/README.md):
#   with             → CCSStore lazy strategy; executor refetches v2; tsc OK
#   no-invalidation  → bus.publish_invalidation patched to no-op;
#                      executor reads stale v1 on commit; tsc FAIL
#                      (protocol-level proof — single-line bus suppression)
#   context-cache    → executor never re-reads from the store; commits from
#                      the v1 spec it captured at read time; tsc FAIL
#                      (mirrors LLM context-window behavior; audience demo)

set -euo pipefail

# ─── Config ──────────────────────────────────────────────────────────────────

# Point at your local checkout of the agent-coherence main repo.
# Override with: AGENT_COHERENCE_REPO=/path/to/repo ./record.sh ...
: "${AGENT_COHERENCE_REPO:=$HOME/projects/agent-coherence}"

# Output directory for cast files; defaults to the directory this script
# lives in. Override with: CAST_DIR=/somewhere ./record.sh ...
: "${CAST_DIR:=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)}"

FIXTURE_DIR="$AGENT_COHERENCE_REPO/examples/refactor_demo/fixture_repo_ts"

# ─── Prerequisite checks ─────────────────────────────────────────────────────

require() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "ERROR: '$1' not on PATH. $2" >&2
    exit 1
  fi
}

require asciinema "Install with: brew install asciinema  (or: pipx install asciinema)"
require python3 "Install Python 3.11 or newer."
require npx "Install Node 18+ (provides npx)."
require npm "Install Node 18+ (provides npm)."

if [[ ! -d "$AGENT_COHERENCE_REPO" ]]; then
  echo "ERROR: agent-coherence main repo not found at $AGENT_COHERENCE_REPO" >&2
  echo "Set AGENT_COHERENCE_REPO to the correct path." >&2
  exit 1
fi

if [[ ! -d "$AGENT_COHERENCE_REPO/examples/refactor_demo" ]]; then
  echo "ERROR: examples/refactor_demo not found under $AGENT_COHERENCE_REPO" >&2
  echo "Requires agent-coherence v0.7.1 or newer." >&2
  exit 1
fi

if ! python3 -c "import ccs" >/dev/null 2>&1; then
  echo "ERROR: 'ccs' (agent-coherence) not importable in the current Python env." >&2
  echo "Activate the venv where agent-coherence is installed in editable mode," >&2
  echo "or run: pip install -e \"$AGENT_COHERENCE_REPO\"[langgraph,benchmark]" >&2
  exit 1
fi

# ─── One-time fixture setup ──────────────────────────────────────────────────

if [[ ! -d "$FIXTURE_DIR/node_modules" ]]; then
  echo "─── installing TypeScript fixture dependencies (one-time) ─────────"
  ( cd "$FIXTURE_DIR" && npm install --silent )
  echo "─── verifying fixture builds clean on as-checked-in source ────────"
  ( cd "$FIXTURE_DIR" && npx tsc --noEmit )
fi

# ─── Recording ───────────────────────────────────────────────────────────────

record_variant() {
  local variant="$1"
  local cast="$CAST_DIR/$variant.cast"
  local cast_v3="$cast.v3"

  echo "─── recording variant=$variant → $cast ────────────────────────────"

  # asciinema rec writes v3 cast format by default; we downgrade to v2 below
  # because asciinema-player 3.x (used for the /code embed) reads v2 natively.
  # --idle-time-limit 1.2 → smart-compresses any wait > 1.2s
  # --cols 120 --rows 32  → lock terminal geometry so re-takes look consistent
  # --overwrite           → re-recording is the normal path
  asciinema rec \
    --idle-time-limit 1.2 \
    --cols 120 \
    --rows 32 \
    --overwrite \
    --command "cd '$AGENT_COHERENCE_REPO' && python -W ignore -m examples.refactor_demo.main --variant=$variant 2>/dev/null" \
    "$cast_v3"

  echo "─── converting to asciicast v2 (for asciinema-player) ─────────────"
  asciinema convert --overwrite --output-format=asciicast-v2 "$cast_v3" "$cast"
  rm -f "$cast_v3"

  echo "─── trimming leading idle (Python/langgraph startup) ──────────────"
  # The demo's first output event lands ~1s in due to Python startup overhead.
  # Looped playback would re-introduce that gap every cycle, so we shift every
  # event timestamp by -(first_t - 0.1) so the cast starts almost immediately.
  python3 - "$cast" <<'PYEOF'
import json, sys
path = sys.argv[1]
with open(path) as f:
    header = json.loads(f.readline())
    events = [json.loads(l) for l in f if l.strip()]
# Strip trailing exit ("x") events — players clear the terminal on exit,
# which would blank the final frame and hide the punchline (tsc result).
while events and events[-1][1] != "o":
    events.pop()
# Shift all output events so the first one lands at t=0.1, killing the
# Python/langgraph startup blank period that would otherwise dominate
# visible playback time on loop.
shift = 0
if events:
    shift = events[0][0] - 0.1
    if shift > 0:
        events = [[round(e[0] - shift, 4), *e[1:]] for e in events]
# Shrink terminal height from the asciinema default (24 rows) to 14 — the
# demo outputs ~12 lines and the extra 10 blank rows just make the rendered
# GIF unnecessarily tall.
header["height"] = 14
with open(path, 'w') as f:
    f.write(json.dumps(header) + "\n")
    for e in events:
        f.write(json.dumps(e) + '\n')
print(f"  trimmed {shift:.3f}s leading idle, stripped exit events, shrunk to 14 rows" if shift > 0 else "  cleaned trailing exit events, shrunk to 14 rows")
PYEOF

  echo "─── done: $cast ───────────────────────────────────────────────────"
  echo "Preview:  asciinema play '$cast'"
  echo "Upload:   asciinema upload '$cast'"
  echo
}

# ─── Entry ───────────────────────────────────────────────────────────────────

case "${1:-}" in
  with)             record_variant with ;;
  no-invalidation)  record_variant no-invalidation ;;
  context-cache)    record_variant context-cache ;;
  all)
    record_variant context-cache    # audience-facing failure first
    record_variant no-invalidation  # protocol-level proof second
    record_variant with             # happy path last (most memorable)
    ;;
  *)
    echo "Usage: $0 {with|no-invalidation|context-cache|all}" >&2
    echo "  with             — with coherence, executor refetches v2, tsc OK" >&2
    echo "  no-invalidation  — bus.publish_invalidation no-op'd, tsc FAIL (protocol proof)" >&2
    echo "  context-cache    — executor never re-reads, tsc FAIL (audience demo)" >&2
    echo "  all              — records all three back to back" >&2
    exit 1
    ;;
esac
