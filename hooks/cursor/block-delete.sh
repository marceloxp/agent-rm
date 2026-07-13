#!/usr/bin/env bash
# preToolUse hook (matcher: Delete) — agent-rm project (Cursor).
#
# Cursor's native Delete tool permanently removes files (no system trash).
# This hook blocks it and redirects the agent to agent-rm via Shell.

DENY_USER='Blocked (agent-rm): the Delete tool permanently removes files. Use agent-rm <file> via Shell instead.'
DENY_AGENT='Do not use the Delete tool to remove files. Run agent-rm <file> via Shell — one file at a time, no directories; goes to restorable trash (see agent-rm --help to restore).'

input="$(cat)"
tool_name="$(printf '%s' "$input" | jq -r '.tool_name // empty' 2>/dev/null)"

if [ "$tool_name" = "Delete" ]; then
  jq -n \
    --arg u "$DENY_USER" \
    --arg a "$DENY_AGENT" \
    '{permission:"deny",user_message:$u,agent_message:$a}'
  exit 0
fi

echo '{"permission":"allow"}'
exit 0
