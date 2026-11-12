#!/usr/bin/env bash
# Secret-scan hook for Claude Code. Wire it to two events:
#
# UserPromptSubmit: block prompts that contain likely secrets by printing
#   {"continue": false, "stopReason": ...}. The prompt never reaches the model
#   and isn't echoed back, but Claude Code still records it in the local
#   session transcript and prompt history, so we also mark the session.
#
# SessionEnd: if this session was marked, delete its transcript and its
#   prompt-history lines so nobody can --resume it or up-arrow to the secret.
#
# This is a demo-grade pattern list, not a replacement for a real scanner.
# For production, call gitleaks or trufflehog here instead.

set -euo pipefail

input="$(cat)"

field() {
  if command -v jq >/dev/null 2>&1; then
    jq -r --arg k "$1" '.[$k] // empty' <<<"$input"
  else
    python3 -c 'import json,sys; print(json.load(sys.stdin).get(sys.argv[1]) or "")' "$1" <<<"$input"
  fi
}

transcript="$(field transcript_path)"
marker="${transcript%.jsonl}.secret-blocked"

if [ "$(field hook_event_name)" = "SessionEnd" ]; then
  # Guard the rm: only act on a real transcript path for a marked session.
  if [[ "$transcript" == *.jsonl ]] && [ -e "$marker" ]; then
    rm -rf -- "$transcript" "${transcript%.jsonl}" "$marker"
    session="$(field session_id)"
    history="${CLAUDE_CONFIG_DIR:-$HOME/.claude}/history.jsonl"
    if [ -n "$session" ] && [ -f "$history" ]; then
      # ponytail: read-then-replace can drop lines another open session appends
      # mid-rewrite; use a lock if many sessions run at once.
      rc=0; grep -vF "\"sessionId\":\"$session\"" "$history" >"$history.tmp" || rc=$?
      # grep exits 1 when every line was this session's; >1 is an error, so
      # keep the original rather than replacing it with a partial file.
      if [ "$rc" -le 1 ]; then mv -- "$history.tmp" "$history"; else rm -f -- "$history.tmp"; fi
    fi
  fi
  exit 0
fi

prompt="$(field prompt)"

# Firebase web config apiKey values are public by design (security comes from
# rules + App Check), so don't block a pasted firebaseConfig. Other AIza keys
# (Gemini, Maps server keys) are still caught below.
prompt="$(sed -E 's/apiKey["'\'']?[[:space:]]*:[[:space:]]*["'\'']AIza[0-9A-Za-z_-]{35}//g' <<<"$prompt")"

patterns=(
  'sk_(live|test)_[0-9A-Za-z_]{10,}'          # Stripe-style secret keys
  'AKIA[0-9A-Z]{16}'                          # AWS access key ID
  'AIza[0-9A-Za-z_-]{35}'                     # Google API key
  'gh[pousr]_[0-9A-Za-z]{36,}'                # GitHub tokens
  'github_pat_[0-9A-Za-z_]{40,}'              # GitHub fine-grained PAT
  'xox[abprs]-[0-9A-Za-z-]{10,}'              # Slack tokens
  'sk-ant-[0-9A-Za-z_-]{20,}'                 # Anthropic API key
  'sk-(proj-)?[0-9A-Za-z_-]{32,}'             # OpenAI-style API key
  '-----BEGIN [A-Z ]*PRIVATE KEY-----'        # PEM private keys
  '"private_key_id"[[:space:]]*:'             # GCP service account JSON
)

for p in "${patterns[@]}"; do
  # Here-string, not a pipe: with pipefail, grep -q exiting early SIGPIPEs the
  # writer and the match is lost on long prompts.
  rc=0; grep -Eq -- "$p" <<<"$prompt" || rc=$?
  # 0 = match, 1 = no match, >1 = grep error: fail closed and block.
  if [ "$rc" -ne 1 ]; then
    # Marking must never stop the block, so ignore failures here.
    [ -n "$transcript" ] && touch -- "$marker" 2>/dev/null || true
    # Block with {"continue": false} rather than exit 2: exit 2 makes Claude
    # Code echo the original prompt (secret included) back to the screen.
    echo '{"continue": false, "stopReason": "Blocked: this prompt looks like it contains a secret. Rotate that key now, store the new one in your secret manager, and reference it by name instead. This session will be deleted from local history when you exit, so exit now (/exit) and start a fresh session."}'
    exit 0
  fi
done

exit 0
