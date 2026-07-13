#!/usr/bin/env bash
#
# check-gio-trash.sh — verify that the trash backend agent-rm relies on actually
# works in THIS environment.
#
# 'command -v gio' passing is NOT enough: 'gio trash' needs a working backend
# (a D-Bus session bus, ~/.local/share/Trash, and a same-filesystem trash for
# mounted volumes). On SSH/headless sessions, WSL, containers, or across
# filesystems it can fail at runtime — exactly when you're relying on it.
#
# This script proves the full round-trip (trash -> gone -> restore -> back) on a
# throwaway file, then cleans up. It never touches a real file of yours.
#
# Usage:
#   scripts/check-gio-trash.sh [dir]
#
#   dir   Directory to create the throwaway file in. Defaults to the current
#         directory, so the test runs on the same filesystem where you actually
#         delete files. Pass a path to test a specific mount/volume.
#
# Exit codes:
#   0  round-trip OK — the trash backend works here
#   1  gio missing
#   2  trash failed (backend not working in this environment)
#   3  restore failed, or restored content did not match
#   4  setup error (target dir not writable, mktemp failed, etc.)

set -uo pipefail

dir="${1:-.}"

red()   { printf '\033[31m%s\033[0m\n' "$*"; }
green() { printf '\033[32m%s\033[0m\n' "$*"; }

fail() {
  local code="$1"; shift
  red "FAIL: $*"
  exit "$code"
}

# --- Preconditions --------------------------------------------------------
command -v gio >/dev/null 2>&1 \
  || fail 1 "'gio' not found. Install the 'libglib2.0-bin' package."

[ -d "$dir" ] || fail 4 "'$dir' is not a directory."
[ -w "$dir" ] || fail 4 "'$dir' is not writable."

# --- Setup: throwaway file with known content -----------------------------
# Use an absolute path so the trash records an unambiguous origin, and derive
# the trash:/// URI used to restore it (gio restores by trash URI, not by the
# original path).
f="$(mktemp "$dir/agent-rm-gio-check.XXXXXX")" \
  || fail 4 "could not create a temp file in '$dir'."
f="$(cd "$(dirname "$f")" && printf '%s/%s' "$PWD" "$(basename "$f")")"
trash_uri="trash:///$(basename "$f")"

token="agent-rm-check-$$-${RANDOM:-0}"
printf '%s\n' "$token" > "$f" \
  || { rm -f "$f"; fail 4 "could not write to the temp file."; }

echo "Testing trash round-trip on: $f"

# --- 1) Trash it ----------------------------------------------------------
if ! gio trash -- "$f" 2>/tmp/agent-rm-gio-check.err; then
  err="$(cat /tmp/agent-rm-gio-check.err 2>/dev/null)"
  rm -f "$f" /tmp/agent-rm-gio-check.err 2>/dev/null
  fail 2 "'gio trash' failed. Backend not working here. ${err:+Details: $err}"
fi
rm -f /tmp/agent-rm-gio-check.err 2>/dev/null

[ ! -e "$f" ] || fail 2 "'gio trash' returned OK but the file is still there."
green "  trashed: file removed from '$dir'"

# --- 2) Restore it --------------------------------------------------------
# gio restores by trash URI (trash:///<name-in-trash>), not by original path.
if ! gio trash --restore "$trash_uri" >/dev/null 2>&1; then
  fail 3 "'gio trash --restore $trash_uri' failed."
fi
[ -e "$f" ] || fail 3 "restore reported OK but the file is not back."

restored="$(cat "$f" 2>/dev/null || true)"
[ "$restored" = "$token" ] \
  || fail 3 "restored file content does not match the original."
green "  restored: file back with matching content"

# --- 3) Clean up the throwaway (via the trash, to stay consistent) --------
gio trash -- "$f" >/dev/null 2>&1 || rm -f "$f"

echo
green "OK: the gio trash backend works in this environment."
