#!/usr/bin/env bash
# Render the four scenes from the stale-read demo as a single PNG montage.
# Alternative display option per the source script's fallback at the bottom:
#   "Alternative if recording video tooling is unavailable — Take the 4
#    scenes as still screenshots and string them as a 4-panel PNG
#    montage. The warning text in scene 3 is the load-bearing visual."
#
# Approach: render 4 minimal asciinema casts (one per scene), each
# captured as a single-frame GIF via agg, then composite into a 2x2 PNG
# grid via Pillow with scene labels.

set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRATCH="$HERE/.montage-scratch"
mkdir -p "$SCRATCH"

VENV_PYTHON="/Users/vladparakhin/projects/agent-coherence/.venv/bin/python"

# ─── Scene fixtures — each emits the final visible state for its scene ──────

scene_fixture() {
  local n="$1"
  case "$n" in
    1)
      cat <<'EOF'
TERM=xterm-256color
printf '\033[1;36m❯\033[0m cat docs/plans/feature-x.md\n'
cat <<'PLAN'
# Feature X plan (v4 — UPDATED 2026-05)
Steps:
  1. Add database migration
  2. Add API endpoint
  3. Add tests
  4. Wire feature flag
  5. Ship behind flag (rollout cohort: 10% → 100% over 1 week)
PLAN
EOF
      ;;
    2)
      cat <<'EOF'
TERM=xterm-256color
printf '\033[1;36m❯\033[0m claude --include-hook-events --output-format stream-json \\\n'
printf '         --print --verbose --model haiku \\\n'
printf '         "Read docs/plans/feature-x.md and summarize the deployment plan."\n'
printf '\033[2m{"type":"system","subtype":"init","session_id":"7ab2c4d8-…","model":"claude-haiku-4-7"}\033[0m\n'
printf '\033[2m{"type":"hook_event","hook":"SessionStart","status":"coordinator_ready","port":50311}\033[0m\n'
printf '\033[2m{"type":"message","role":"assistant","content":[{"type":"tool_use","name":"Read","input":{"file_path":"docs/plans/feature-x.md"}}]}\033[0m\n'
EOF
      ;;
    3)
      cat <<'EOF'
TERM=xterm-256color
printf '\033[1;33m{"type":"hook_event","hook":"PreToolUse:Read","decision":"allow",\033[0m\n'
printf '\033[1;33m "additionalContext":\033[0m\n'
printf '\033[1;33m  "⚠ Stale read [warning emitted 2026-05-17T12:34:56+00:00]:\033[0m\n'
printf '\033[1;33m   docs/plans/feature-x.md was updated by session a3f1c2b0\033[0m\n'
printf '\033[1;33m   at 2026-05-17T12:30:12+00:00. Current version is v3; this\033[0m\n'
printf '\033[1;33m   is the first time your session has observed this artifact\033[0m\n'
printf '\033[1;33m   (another session in this workspace registered it before\033[0m\n'
printf '\033[1;33m   you). Your worktree'\''s content matches the last-recorded\033[0m\n'
printf '\033[1;33m   hash; the divergence is purely about version-tracking\033[0m\n'
printf '\033[1;33m   metadata. Consider re-reading docs/plans/feature-x.md\033[0m\n'
printf '\033[1;33m   before acting on stale assumptions."}\033[0m\n'
EOF
      ;;
    4)
      cat <<'EOF'
TERM=xterm-256color
printf '\033[2m{"type":"message","role":"assistant","content":"\033[0m\n'
printf '\033[2m  Noted: the coordinator flagged this file as updated by another\033[0m\n'
printf '\033[2m  session, so I'\''m treating my view as potentially stale. ..."}\033[0m\n'
printf '\n'
printf '\033[1;36m❯\033[0m agent-coherence-status\n'
cat <<'STATUS'

Tracked artifacts (1):
  docs/plans/feature-x.md         v3   last writer: a3f1c2b0   2m ago
                                       this session viewed:    none prior

Coordinator: pid 47281, listening 127.0.0.1:50311, uptime 4m12s
STATUS
EOF
      ;;
  esac
}

# ─── Render each scene as a single-frame asciicast → still GIF ──────────────
for n in 1 2 3 4; do
  fixture_script="$SCRATCH/scene-$n.sh"
  scene_fixture "$n" > "$fixture_script"
  chmod +x "$fixture_script"

  cast_v3="$SCRATCH/scene-$n.cast.v3"
  cast="$SCRATCH/scene-$n.cast"
  gif="$SCRATCH/scene-$n.gif"

  echo "─── recording scene $n ─────────────────────────────────────"
  TERM=xterm-256color asciinema rec \
    --idle-time-limit 0.05 \
    --cols 110 \
    --rows 14 \
    --overwrite \
    --command "TERM=xterm-256color bash $fixture_script" \
    "$cast_v3"

  asciinema convert --overwrite --output-format=asciicast-v2 "$cast_v3" "$cast"
  rm -f "$cast_v3"

  # Single-frame render: render the LAST frame as a tiny "still" GIF.
  # --last-frame-duration absorbs all the playback time so agg renders
  # only one frame (~1 KB) — but we still get the full visual state.
  agg \
    --speed 100 \
    --last-frame-duration 0.04 \
    --theme "0a0a0a,e8e8ea,0a0a0a,fb7185,5eead4,c084fc,5eead4,c084fc,5eead4,e8e8ea" \
    --font-size 18 \
    --fps-cap 30 \
    "$cast" "$gif"
done

# ─── Composite via Pillow: 4 individual PNGs + 1 2x2 montage ──────────────
echo "─── compositing scenes ─────────────────────────────────────"
"$VENV_PYTHON" - "$SCRATCH" "$HERE" <<'PYEOF'
import sys
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

scratch = Path(sys.argv[1])
out_dir = Path(sys.argv[2])

# Open the 4 scene GIFs as PIL images (first frame).
scenes = [Image.open(scratch / f"scene-{n}.gif").convert("RGB") for n in (1, 2, 3, 4)]

# Normalize widths/heights to the largest so the grid is uniform.
max_w = max(s.width for s in scenes)
max_h = max(s.height for s in scenes)

# Pad each scene to (max_w, max_h) with the same dark background.
BG = (10, 10, 10)  # #0a0a0a — matches the site's --bg
def pad(img):
    canvas = Image.new("RGB", (max_w, max_h), BG)
    canvas.paste(img, ((max_w - img.width) // 2, 0))
    return canvas

padded = [pad(s) for s in scenes]

# Save individual scene PNGs (no per-panel caption — the /test page
# emits scene labels in HTML alongside each image so screen readers see
# the label as text and search engines index it).
for n, img in enumerate(padded, start=1):
    fname = out_dir / f"stale-read-scene-{n}.png"
    img.save(fname, "PNG", optimize=True)
    print(f"  wrote {fname.name} ({fname.stat().st_size // 1024} KB) — {img.width}x{img.height}")

# Label strip per panel for the combined montage view.
LABEL_H = 38
LABELS = [
    "1 — the plan two sessions are sharing",
    "2 — claude is asked to read it",
    "3 — the plugin intercepts: stale-read warning injected",
    "4 — assistant acknowledges, status shows v3 by another session",
]
LABEL_COLOR = (94, 234, 212)
LABEL_BG = (19, 20, 24)

font = None
for candidate in (
    "/System/Library/Fonts/SFNSMono.ttf",
    "/System/Library/Fonts/Menlo.ttc",
    "/System/Library/Fonts/Supplemental/Courier New Bold.ttf",
    "/Library/Fonts/Arial.ttf",
):
    try:
        font = ImageFont.truetype(candidate, 18)
        break
    except (OSError, IOError):
        continue
if font is None:
    font = ImageFont.load_default()

def labeled(scene_img, text):
    panel = Image.new("RGB", (max_w, LABEL_H + max_h), LABEL_BG)
    d = ImageDraw.Draw(panel)
    d.text((20, (LABEL_H - 18) // 2), text, fill=LABEL_COLOR, font=font)
    panel.paste(scene_img, (0, LABEL_H))
    return panel

labeled_scenes = [labeled(padded[i], LABELS[i]) for i in range(4)]

gap = 14
panel_w = max_w
panel_h = LABEL_H + max_h
total_w = panel_w * 2 + gap * 3
total_h = panel_h * 2 + gap * 3

montage = Image.new("RGB", (total_w, total_h), BG)
positions = [
    (gap, gap),
    (gap * 2 + panel_w, gap),
    (gap, gap * 2 + panel_h),
    (gap * 2 + panel_w, gap * 2 + panel_h),
]
for img, pos in zip(labeled_scenes, positions):
    montage.paste(img, pos)

montage_path = out_dir / "stale-read-montage.png"
montage.save(montage_path, "PNG", optimize=True)
print(f"  wrote {montage_path.name} ({montage_path.stat().st_size // 1024} KB) — {total_w}x{total_h}")
PYEOF

rm -rf "$SCRATCH"
echo "─── done ───────────────────────────────────────────────────"
