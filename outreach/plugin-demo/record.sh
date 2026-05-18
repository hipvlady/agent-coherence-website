#!/usr/bin/env bash
# Wraps fixture.sh in asciinema → v2 cast → GIF, same pipeline as
# outreach/demo/record.sh.
#
# Output:
#   stale-read.cast    — v2-format asciicast, header.height shrunk to 16,
#                        leading idle trimmed, trailing exit events stripped
#   stale-read.gif     — rendered via agg, theme matches site palette

set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FIXTURE="$HERE/fixture.sh"
CAST="$HERE/stale-read.cast"
CAST_V3="$HERE/stale-read.cast.v3"
GIF="$HERE/stale-read.gif"

# ─── Prerequisite checks ─────────────────────────────────────────────────────
require() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "ERROR: '$1' not on PATH." >&2
    exit 1
  fi
}
require asciinema
require agg
require python3

# ─── Record ──────────────────────────────────────────────────────────────────
echo "─── recording fixture into $CAST_V3 ──────────────────────────────────"
TERM=xterm-256color asciinema rec \
  --idle-time-limit 1.2 \
  --cols 120 \
  --rows 32 \
  --overwrite \
  --command "TERM=xterm-256color bash $FIXTURE" \
  "$CAST_V3"

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
# Strip trailing exit events (players clear the screen on "x").
while events and events[-1][1] != "o":
    events.pop()
# Trim leading idle so the cast doesn't sit blank for 1+ seconds on loop.
shift = 0
if events:
    shift = events[0][0] - 0.1
    if shift > 0:
        events = [[round(e[0] - shift, 4), *e[1:]] for e in events]
# Shrink terminal height — the fixture outputs ~22 visible lines max, no
# need for the default 32-row asciinema buffer.
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
# Theme: bg, fg, then 8 ANSI colors (black, red, green, yellow, blue, magenta,
# cyan, white). Matches the site palette so the GIF blends with /test page.
agg \
  --speed 1.0 \
  --last-frame-duration 3 \
  --theme "0a0a0a,e8e8ea,0a0a0a,fb7185,5eead4,c084fc,5eead4,c084fc,5eead4,e8e8ea" \
  --font-size 14 \
  "$CAST" "$GIF"

echo "─── done ──────────────────────────────────────────────────────────────"
echo "Cast: $CAST"
echo "GIF:  $GIF"
ls -lh "$CAST" "$GIF"
