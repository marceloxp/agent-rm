#!/usr/bin/env bash
# beforeShellExecution hook — agent-rm project (Cursor).
#
# Blocks permanent file deletion shell commands. To delete a file, use:
#     agent-rm <file>
#
# Default: allow. Blocking returns JSON with permission=deny.

DENY_USER='Blocked (agent-rm): permanent deletion is not allowed. Use agent-rm <file> instead.'
DENY_AGENT='Do not permanently delete files. Use agent-rm <file> — one file at a time, no directories; goes to restorable trash (gio trash --restore undoes it).'

input="$(cat)"
cmd="$(printf '%s' "$input" | jq -r '.command // empty' 2>/dev/null)"
[ -z "$cmd" ] && echo '{"permission":"allow"}' && exit 0

deny() {
  jq -n \
    --arg u "$DENY_USER" \
    --arg a "$DENY_AGENT" \
    '{permission:"deny",user_message:$u,agent_message:$a}'
  exit 0
}

segments="$(printf '%s' "$cmd" | sed -E 's/\$\(/\n/g; s/[;|&`]/\n/g; s/\|\|/\n/g; s/&&/\n/g')"

segment_is_destructive() {
  local seg="$1"
  local trimmed
  trimmed="$(printf '%s' "$seg" | sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//')"
  [ -z "$trimmed" ] && return 1

  if printf '%s' "$trimmed" | grep -qE '^[[:space:]]*(sudo[[:space:]]+|time[[:space:]]+|[A-Za-z_][A-Za-z0-9_]*=[^[:space:]]*[[:space:]]+)*agent-rm([[:space:]]|$)'; then
    return 1
  fi

  if printf '%s' "$trimmed" | grep -qE '^[[:space:]]*(sudo[[:space:]]+|time[[:space:]]+|[A-Za-z_][A-Za-z0-9_]*=[^[:space:]]*[[:space:]]+)*(/[^[:space:]]+/)?rm([[:space:]]|$)'; then
    return 0
  fi

  if printf '%s' "$trimmed" | grep -qE '^[[:space:]]*(sudo[[:space:]]+|time[[:space:]]+|[A-Za-z_][A-Za-z0-9_]*=[^[:space:]]*[[:space:]]+)*command[[:space:]]+rm([[:space:]]|$)'; then
    return 0
  fi

  if printf '%s' "$trimmed" | grep -qE '^[[:space:]]*(sudo[[:space:]]+|time[[:space:]]+|[A-Za-z_][A-Za-z0-9_]*=[^[:space:]]*[[:space:]]+)*unlink([[:space:]]|$)'; then
    return 0
  fi

  if printf '%s' "$trimmed" | grep -qE '^[[:space:]]*(sudo[[:space:]]+|time[[:space:]]+|[A-Za-z_][A-Za-z0-9_]*=[^[:space:]]*[[:space:]]+)*find\b' \
    && printf '%s' "$trimmed" | grep -qE '\-delete\b'; then
    return 0
  fi

  if printf '%s' "$trimmed" | grep -qE '\bxargs\b' \
    && printf '%s' "$trimmed" | grep -qE '\brm\b'; then
    return 0
  fi

  return 1
}

while IFS= read -r seg; do
  if segment_is_destructive "$seg"; then
    deny
  fi
done <<EOF
$segments
EOF

echo '{"permission":"allow"}'
exit 0
