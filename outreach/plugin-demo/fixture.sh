#!/usr/bin/env bash
# Staged demo fixture — visualizes what an authentic agent-coherence-plugin
# stale-read encounter produces in claude's stream-JSON output.
#
# Honesty bar: the warning text is byte-for-byte the output of
# ccs.adapters.claude_code.hook_payloads.stale_read_warning() — the actual
# plugin code path. The orchestration around it (claude CLI invocation,
# stream-JSON event shapes, agent response) is staged for readability and
# to avoid burning a real Haiku API call per recording.
#
# Source script:
#   /Users/vladparakhin/projects/agent-coherence-plugin/docs/demos/
#     2026-05-17-stale-read-demo-script.md
#
# Plugin v0.1 plan:
#   /Users/vladparakhin/projects/agent-coherence/docs/plans/
#     2026-05-13-001-feat-claude-code-coherence-plugin-v0.1-plan.md

set -e

# ─── Scene 1: workspace + file content ──────────────────────────────────────
clear
printf '\033[1;36m❯\033[0m cat docs/plans/feature-x.md\n'
sleep 1.0
cat <<'EOF'
# Feature X plan (v4 — UPDATED 2026-05)
Steps:
  1. Add database migration
  2. Add API endpoint
  3. Add tests
  4. Wire feature flag
  5. Ship behind flag (rollout cohort: 10% → 100% over 1 week)
EOF
sleep 3.5

# ─── Scene 2: invoke claude with the plugin's hook events streaming ─────────
echo
printf '\033[1;36m❯\033[0m claude --include-hook-events --output-format stream-json \\\n'
printf '         --print --verbose --model haiku \\\n'
printf '         "Read docs/plans/feature-x.md and summarize the deployment plan."\n'
sleep 2.2

# Stream-JSON: init
printf '\033[2m{"type":"system","subtype":"init","session_id":"7ab2c4d8-9e3f-4a02-bb57-1c8e9a4c2110","model":"claude-haiku-4-7"}\033[0m\n'
sleep 1.2

# Stream-JSON: SessionStart hook fired by the plugin (ensures coordinator alive)
printf '\033[2m{"type":"hook_event","hook":"SessionStart","status":"coordinator_ready","port":50311}\033[0m\n'
sleep 1.2

# Stream-JSON: assistant chooses Read tool
printf '\033[2m{"type":"message","role":"assistant","content":[{"type":"tool_use","name":"Read","input":{"file_path":"docs/plans/feature-x.md"}}]}\033[0m\n'
sleep 2.5    # ANTICIPATION pause — the read is about to be intercepted

# Stream-JSON: PreToolUse:Read hook fires — THIS is the load-bearing visual.
# additionalContext is the exact string returned by
# ccs.adapters.claude_code.hook_payloads.stale_read_warning() for a summary
# where prior_version_seen_by_session is None and hash_differs is False.
printf '\033[1;33m{"type":"hook_event","hook":"PreToolUse:Read","decision":"allow",\033[0m\n'
sleep 0.6
printf '\033[1;33m "additionalContext":\033[0m\n'
sleep 0.7
printf '\033[1;33m  "⚠ Stale read [warning emitted 2026-05-17T12:34:56+00:00]: \033[0m\n'
sleep 0.7
printf '\033[1;33m   docs/plans/feature-x.md was updated by session a3f1c2b0 at \033[0m\n'
sleep 0.7
printf '\033[1;33m   2026-05-17T12:30:12+00:00. Current version is v3; this is \033[0m\n'
sleep 0.7
printf '\033[1;33m   the first time your session has observed this artifact \033[0m\n'
sleep 0.7
printf '\033[1;33m   (another session in this workspace registered it before \033[0m\n'
sleep 0.7
printf '\033[1;33m   you). Your worktree'\''s content matches the last-recorded \033[0m\n'
sleep 0.7
printf '\033[1;33m   hash; the divergence is purely about version-tracking \033[0m\n'
sleep 0.7
printf '\033[1;33m   metadata. Consider re-reading docs/plans/feature-x.md \033[0m\n'
sleep 0.7
printf '\033[1;33m   before acting on stale assumptions."}\033[0m\n'
sleep 5.5    # ABSORPTION pause — reader takes the full warning in

# Stream-JSON: tool result + assistant acknowledgement
printf '\033[2m{"type":"tool_result","content":"# Feature X plan (v4 — UPDATED 2026-05) ..."}\033[0m\n'
sleep 1.5
printf '\033[2m{"type":"message","role":"assistant","content":"\033[0m\n'
sleep 0.6
printf '\033[2m  Noted: the coordinator flagged this file as updated by another \033[0m\n'
sleep 0.6
printf '\033[2m  session, so I'\''m treating my view as potentially stale. Based \033[0m\n'
sleep 0.6
printf '\033[2m  on the v3 content I have, the deployment plan is: migrate the \033[0m\n'
sleep 0.6
printf '\033[2m  database, add the API endpoint, write tests, wire a feature \033[0m\n'
sleep 0.6
printf '\033[2m  flag, then ship behind the flag with a 10% → 100% rollout over \033[0m\n'
sleep 0.6
printf '\033[2m  one week. I'\''d recommend re-reading the file before executing \033[0m\n'
sleep 0.6
printf '\033[2m  any of these steps in case the other session changed them."}\033[0m\n'
sleep 3.0

# ─── Scene 4: final status check ────────────────────────────────────────────
echo
printf '\033[1;36m❯\033[0m agent-coherence-status\n'
sleep 1.0
cat <<'EOF'

Tracked artifacts (1):
  docs/plans/feature-x.md         v3   last writer: a3f1c2b0   2m ago
                                       this session viewed:    none prior

Coordinator: pid 47281, listening 127.0.0.1:50311, uptime 4m12s
EOF
sleep 3.5

# ─── Footer ─────────────────────────────────────────────────────────────────
echo
printf '\033[2m# The plugin caught the stale read \033[0;36mbefore\033[2m the assistant acted.\033[0m\n'
printf '\033[2m# No platform fix needed, no model retraining.\033[0m\n'
sleep 3.0
