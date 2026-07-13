#!/usr/bin/env bash
# PreToolUse hook (matcher: Bash) — agent-rm project.
#
# Blocks permanent file deletion commands. To delete a file, use:
#     agent-rm <file>
# (one file at a time, no directories; goes to restorable system trash via
# 'gio trash').
#
# 'agent-rm' stays ALLOWED: in command position the segment starts with
# "agent", not a blocked command.
#
# Default: allow (exit 0). Blocking is done via JSON permissionDecision=deny.

DENY_MSG='Blocked (agent-rm): do not permanently delete files. Use '\''agent-rm <file>'\'' — one file at a time, no directories; goes to restorable trash (see '\''agent-rm --help'\'' to restore).'

input="$(cat)"
cmd="$(printf '%s' "$input" | jq -r '.tool_input.command // empty' 2>/dev/null)"
[ -z "$cmd" ] && exit 0

deny() {
  jq -n --arg r "$1" '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"deny",permissionDecisionReason:$r}}'
  exit 0
}

# Split into segments (chained ; | & && ||, subshells $( ), backticks).
segments="$(printf '%s' "$cmd" | sed -E 's/\$\(/\n/g; s/[;|&`]/\n/g; s/\|\|/\n/g; s/&&/\n/g')"

segment_is_destructive() {
  local seg="$1"
  local trimmed
  trimmed="$(printf '%s' "$seg" | sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//')"
  [ -z "$trimmed" ] && return 1

  # agent-rm is explicitly allowed.
  if printf '%s' "$trimmed" | grep -qE '^[[:space:]]*(sudo[[:space:]]+|time[[:space:]]+|[A-Za-z_][A-Za-z0-9_]*=[^[:space:]]*[[:space:]]+)*agent-rm([[:space:]]|$)'; then
    return 1
  fi

  # rm in command position (bare or absolute path).
  if printf '%s' "$trimmed" | grep -qE '^[[:space:]]*(sudo[[:space:]]+|time[[:space:]]+|[A-Za-z_][A-Za-z0-9_]*=[^[:space:]]*[[:space:]]+)*(/[^[:space:]]+/)?rm([[:space:]]|$)'; then
    return 0
  fi

  # command rm
  if printf '%s' "$trimmed" | grep -qE '^[[:space:]]*(sudo[[:space:]]+|time[[:space:]]+|[A-Za-z_][A-Za-z0-9_]*=[^[:space:]]*[[:space:]]+)*command[[:space:]]+rm([[:space:]]|$)'; then
    return 0
  fi

  # unlink
  if printf '%s' "$trimmed" | grep -qE '^[[:space:]]*(sudo[[:space:]]+|time[[:space:]]+|[A-Za-z_][A-Za-z0-9_]*=[^[:space:]]*[[:space:]]+)*unlink([[:space:]]|$)'; then
    return 0
  fi

  # find ... -delete
  if printf '%s' "$trimmed" | grep -qE '^[[:space:]]*(sudo[[:space:]]+|time[[:space:]]+|[A-Za-z_][A-Za-z0-9_]*=[^[:space:]]*[[:space:]]+)*find\b' \
    && printf '%s' "$trimmed" | grep -qE '\-delete\b'; then
    return 0
  fi

  # xargs ... rm
  if printf '%s' "$trimmed" | grep -qE '\bxargs\b' \
    && printf '%s' "$trimmed" | grep -qE '\brm\b'; then
    return 0
  fi

  return 1
}

while IFS= read -r seg; do
  if segment_is_destructive "$seg"; then
    deny "$DENY_MSG"
  fi
done <<EOF
$segments
EOF

exit 0
