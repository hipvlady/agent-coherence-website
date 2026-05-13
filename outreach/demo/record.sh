#!/usr/bin/env bash
# Asciinema recording script for the agent-coherence planner-executor demo.
#
# STATUS: DRAFT — staged in the website repo's outreach/ folder.
# Moves to the agent-coherence main repo (alongside examples/refactor_demo/)
# when the demo fixtures land there.
#
# Usage:
#   ./record.sh with-coherence    # produces with-coherence.cast (executor pulls v2)
#   ./record.sh without-coherence # produces without-coherence.cast (tsc fails)
#   ./record.sh both              # records both variants back to back
#
# Prerequisites:
#   brew install asciinema     # or: pipx install asciinema
#   Node 18+ (provides npx tsc)
#   Python 3.10+ (the agent-coherence library + the refactor_demo example)
#
# What this script DOES:
#   - Verifies prerequisites
#   - Rebuilds /tmp/refactor_demo/ from the agent-coherence fixture
#   - Writes a narration script (_run.sh) inline so the recorded cast
#     contains visible commentary as terminal output
#   - Invokes asciinema rec with --idle-time-limit 1.2 to smart-compress
#     waits, --cols 120 --rows 32 to lock terminal geometry across takes
#
# What this script does NOT do:
#   - Edit the cast post-recording (asciinema casts are JSON; if you need
#     to trim, edit the JSON or use asciinema-edit)
#   - Upload to asciinema.org (do that manually after review:
#     asciinema upload with-coherence.cast)

set -euo pipefail

# ─── Config ──────────────────────────────────────────────────────────────────

# Point at your local checkout of the agent-coherence main repo.
# Override with: AGENT_COHERENCE_REPO=/path/to/repo ./record.sh ...
: "${AGENT_COHERENCE_REPO:=$HOME/projects/agent-coherence}"

DEMO_DIR="$AGENT_COHERENCE_REPO/examples/refactor_demo"
FIXTURE_DIR="$AGENT_COHERENCE_REPO/examples/refactor_demo_fixture"
STAGE_DIR=/tmp/refactor_demo
OUTPUT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ─── Prerequisite checks ─────────────────────────────────────────────────────

require() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "ERROR: '$1' not on PATH. $2" >&2
    exit 1
  fi
}

require asciinema "Install with: brew install asciinema  (or: pipx install asciinema)"
require python3 "Install Python 3.10 or newer."
require npx "Install Node 18 or newer (provides npx)."

if [[ ! -d "$AGENT_COHERENCE_REPO" ]]; then
  echo "ERROR: agent-coherence main repo not found at $AGENT_COHERENCE_REPO" >&2
  echo "Set AGENT_COHERENCE_REPO to the correct path or check out the repo." >&2
  exit 1
fi

if [[ ! -d "$DEMO_DIR" ]]; then
  echo "ERROR: demo example not found at $DEMO_DIR" >&2
  echo "This script expects the agent-coherence main repo to contain" >&2
  echo "examples/refactor_demo/{planner.py,executor.py} per plan Unit 1." >&2
  exit 1
fi

if [[ ! -d "$FIXTURE_DIR" ]]; then
  echo "ERROR: TypeScript fixture not found at $FIXTURE_DIR" >&2
  exit 1
fi

# ─── Inline narration script (gets recorded) ─────────────────────────────────
#
# Writing this to /tmp instead of sourcing the committed _run.sh means the
# script body that appears in the cast matches what's actually executed —
# no double-source confusion when someone replays the cast and reads it.

build_run_script() {
  local variant="$1"
  cat > "$STAGE_DIR/_run.sh" <<EOF
#!/usr/bin/env bash
set -e

clear
echo "──────────────────────────────────────────────────────────────────"
echo "  agent-coherence demo — planner / executor refactor"
echo "  variant: $variant"
echo "  shared artifact: task-spec.json  (held in CCSStore)"
echo "──────────────────────────────────────────────────────────────────"
echo
sleep 2

echo "# t=0 — planner writes v1 of the task spec"
python3 "$DEMO_DIR/planner.py" --version v1
sleep 2

echo
echo "# t=1 — executor reads v1, caches locally, begins"
python3 "$DEMO_DIR/executor.py" --read
sleep 2

echo
echo "# t=2 — planner discovers a 4th caller, writes v2"
python3 "$DEMO_DIR/planner.py" --version v2
EOF

  if [[ "$variant" == "without-coherence" ]]; then
    cat >> "$STAGE_DIR/_run.sh" <<EOF
sleep 2

echo
echo "# (no invalidation — executor's cache still says v1)"
sleep 2

echo
echo "# t=3 — executor commits using its stale v1"
python3 "$DEMO_DIR/executor.py" --commit --no-coherence
sleep 2

echo
echo "# verifying with real tsc..."
cd "$STAGE_DIR" && npx --yes typescript@5 tsc --noEmit 2>&1 || true
sleep 2

echo
echo "──────────────────────────────────────────────────────────────────"
echo "  Result: tsc reported errors. The executor renamed 3 callers but"
echo "  the 4th (added in v2) still references the old symbol."
echo "  Without coherence, the stale read silently lands a broken build."
echo "──────────────────────────────────────────────────────────────────"
EOF
  else
    cat >> "$STAGE_DIR/_run.sh" <<EOF
sleep 2

echo
echo "# (CCSStore publishes invalidation to peers before write() returns)"
sleep 2

echo
echo "# t=3 — executor's next read of the task spec"
python3 "$DEMO_DIR/executor.py" --commit
sleep 2

echo
echo "# verifying with real tsc..."
cd "$STAGE_DIR" && npx --yes typescript@5 tsc --noEmit
sleep 2

echo
echo "──────────────────────────────────────────────────────────────────"
echo "  Result: tsc passes. The executor's next get() saw INVALID,"
echo "  refetched v2, and renamed all 4 callers — including the one"
echo "  the planner added mid-flight. Prevention, not repair."
echo "──────────────────────────────────────────────────────────────────"
EOF
  fi
  chmod +x "$STAGE_DIR/_run.sh"
}

# ─── Recording ───────────────────────────────────────────────────────────────

record_variant() {
  local variant="$1"
  local cast="$OUTPUT_DIR/$variant.cast"

  echo "─── preparing $variant ─────────────────────────────────────────"
  rm -rf "$STAGE_DIR"
  cp -r "$FIXTURE_DIR" "$STAGE_DIR"
  build_run_script "$variant"

  echo "─── recording → $cast ─────────────────────────────────────────"
  # --idle-time-limit 1.2 → asciinema smart-compresses any wait > 1.2s to 1.2s
  # --cols 120 --rows 32  → lock terminal geometry so playback looks consistent
  # --overwrite           → re-recording is the normal path; don't error
  asciinema rec \
    --idle-time-limit 1.2 \
    --cols 120 \
    --rows 32 \
    --overwrite \
    --command "bash $STAGE_DIR/_run.sh" \
    "$cast"

  echo "─── done: $cast ───────────────────────────────────────────────"
  echo "Preview:  asciinema play $cast"
  echo "Upload:   asciinema upload $cast"
  echo
}

# ─── Entry ───────────────────────────────────────────────────────────────────

case "${1:-}" in
  with-coherence)    record_variant with-coherence ;;
  without-coherence) record_variant without-coherence ;;
  both)
    record_variant without-coherence
    record_variant with-coherence
    ;;
  *)
    echo "Usage: $0 {with-coherence|without-coherence|both}" >&2
    exit 1
    ;;
esac
