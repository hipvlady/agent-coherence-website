#!/usr/bin/env bash
# Records the /rag flagship lost-update demo (examples/coherent_volume in the
# agent-coherence library repo) into a terminal GIF for site/rag/.
#
# Sibling of record.sh — same asciinema → v2 cast → agg → GIF pipeline and the
# same site theme. The difference: it records the library demo directly (no
# fixture.sh), filters stderr (fixed.py spawns a local coordinator subprocess
# whose connect/retry logs would otherwise land in the capture), and writes the
# GIF under site/rag/gifs/.
#
# Output:
#   site/rag/gifs/lost-update.cast — v2-format asciicast (trimmed, exit stripped)
#   site/rag/gifs/lost-update.gif  — rendered via agg, theme matches site palette
#
# Reproduce:
#   AGENT_COHERENCE_REPO=/path/to/agent-coherence ./record-coherent-volume.sh
# (PYTHON overrides the interpreter; defaults to python3 with agent-coherence importable.)

set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SITE_REPO="$(cd "$HERE/../.." && pwd)"
OUT_DIR="$SITE_REPO/site/rag/gifs"
CAST="$OUT_DIR/lost-update.cast"
CAST_V3="$OUT_DIR/lost-update.cast.v3"
GIF="$OUT_DIR/lost-update.gif"

AGENT_COHERENCE_REPO="${AGENT_COHERENCE_REPO:-$SITE_REPO/../agent-coherence}"
PYTHON="${PYTHON:-python3}"

# ─── Prerequisite checks ─────────────────────────────────────────────────────
require() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "ERROR: '$1' not on PATH." >&2
    exit 1
  fi
}
require asciinema
require agg

if [[ ! -f "$AGENT_COHERENCE_REPO/examples/coherent_volume/main.py" ]]; then
  echo "ERROR: examples/coherent_volume not found under AGENT_COHERENCE_REPO=$AGENT_COHERENCE_REPO" >&2
  exit 1
fi
if ! (cd "$AGENT_COHERENCE_REPO" && "$PYTHON" -c "import ccs" >/dev/null 2>&1); then
  echo "ERROR: '$PYTHON' cannot import ccs from $AGENT_COHERENCE_REPO (the demo self-injects src/, so a checkout works; otherwise pip install agent-coherence)." >&2
  exit 1
fi

mkdir -p "$OUT_DIR"

# ─── Record (paced) ──────────────────────────────────────────────────────────
# The demo prints near-instantly, which reads like a static dump. Pace it
# line-by-line through a small runner so the broken→fixed sequence unfolds, with
# longer holds on each LOST UPDATE verdict (the payload). Filter the demo's
# stderr — the fixed run spawns a coordinator subprocess. NOTE: --idle-time-limit
# must exceed the longest pacing pause (1.8s) or asciinema would clamp it.
RUNNER="$OUT_DIR/.run-coherent-volume.sh"
cat > "$RUNNER" <<RUNEOF
#!/usr/bin/env bash
cd '$AGENT_COHERENCE_REPO'
PYTHONWARNINGS=ignore '$PYTHON' -m examples.coherent_volume.main 2>/dev/null | while IFS= read -r line; do
  printf '%s\n' "\$line"
  case "\$line" in
    *'LOST UPDATE: True'*)  sleep 1.8 ;;   # let the data-loss land
    *'LOST UPDATE: False'*) sleep 1.6 ;;   # let the prevention land
    *BROKEN*|*FIXED*)        sleep 0.7 ;;   # beat before each scene
    Takeaway*)              sleep 0.6 ;;
    '')                     sleep 0.25 ;;
    *)                      sleep 0.22 ;;   # per-line typing cadence
  esac
done
RUNEOF

echo "─── recording coherent_volume (paced) into $CAST_V3 ─────────────────"
TERM=xterm-256color asciinema rec \
  --idle-time-limit 2.5 \
  --cols 100 \
  --rows 28 \
  --overwrite \
  --command "bash '$RUNNER'" \
  "$CAST_V3"
rm -f "$RUNNER"

# ─── Convert v3 → v2 ─────────────────────────────────────────────────────────
echo "─── converting to asciicast v2 ───────────────────────────────────────"
asciinema convert --overwrite --output-format=asciicast-v2 "$CAST_V3" "$CAST"
rm -f "$CAST_V3"

# ─── Trim + shrink + strip exit ──────────────────────────────────────────────
echo "─── trimming idle, stripping exit events, shrinking rows ─────────────"
python3 - "$CAST" <<'PYEOF'
import json, sys
path = sys.argv[1]
with open(path) as f:
    header = json.loads(f.readline())
    events = [json.loads(l) for l in f if l.strip()]
while events and events[-1][1] != "o":
    events.pop()
shift = 0
if events:
    shift = events[0][0] - 0.1
    if shift > 0:
        events = [[round(e[0] - shift, 4), *e[1:]] for e in events]
# coherent_volume prints ~20 visible lines.
header["height"] = 22
with open(path, "w") as f:
    f.write(json.dumps(header) + "\n")
    for e in events:
        f.write(json.dumps(e) + "\n")
total = events[-1][0] if events else 0
print(f"  trimmed {shift:.3f}s leading idle, {len(events)} events, total {total:.2f}s + 3s last-frame pause")
PYEOF

# ─── Render to GIF ───────────────────────────────────────────────────────────
echo "─── rendering GIF ────────────────────────────────────────────────────"
# Theme + sizing match record.sh so the GIF blends with the site.
agg \
  --speed 1.0 \
  --last-frame-duration 3 \
  --theme "0a0a0a,e8e8ea,0a0a0a,fb7185,5eead4,c084fc,5eead4,c084fc,5eead4,e8e8ea" \
  --font-size 20 \
  --fps-cap 24 \
  "$CAST" "$GIF"

echo "─── done ──────────────────────────────────────────────────────────────"
ls -lh "$CAST" "$GIF"
