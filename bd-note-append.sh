#!/usr/bin/env bash
# bd-note-append.sh — append to a beads (bd) issue's notes without overwriting them.
#
# Usage:
#   bd-note-append.sh <issue-id> "text to append"
#   echo "text" | bd-note-append.sh <issue-id> -
#   bd-note-append.sh <issue-id> - < note.txt
#
# Why this exists: `bd update <id> --notes "..."` REPLACES the whole notes field.
# A literal-value overwrite silently wipes whatever was there before. This wrapper
# reads the current notes, concatenates, writes the merged result, then re-reads and
# fails loudly if the notes got shorter (the only signal that an overwrite happened).
#
# Guards against three argument-shape mistakes that look like success:
#   * 2nd arg is a file path        -> would append the path string itself as the note
#   * 2nd arg looks like an option  -> `--file x` would be appended as literal text
#   * more than 2 args              -> extra args would be silently dropped
#
# Environment:
#   BD_BIN      path/name of the bd executable            (default: bd)
#   BD_WORKDIR  directory to run bd in                    (default: current dir)
#
# Exit codes: 0 ok | 2 bad usage | 3 `bd show` failed | 4 `bd update` failed
#             5 notes got shorter after the write (overwrite detected)
set -euo pipefail

USAGE="usage: bd-note-append.sh <issue-id> <text|->"
if [ "$#" -lt 2 ]; then
  echo "$USAGE" >&2
  exit 2
fi

ISSUE="$1"
TEXT="$2"
if [ "$TEXT" = "-" ]; then TEXT="$(cat)"; fi
[ -n "$TEXT" ] || { echo "text to append is empty; nothing done" >&2; exit 2; }

if [ "$#" -gt 2 ]; then
  echo "takes exactly two arguments; arguments after the 2nd would be dropped (got $#). To feed a file: $0 $ISSUE - < file" >&2
  exit 2
fi

# Path-shaped single-line argument: refuse. Deliberately does not touch the
# filesystem (a sandbox may hide the file, making an existence check unreliable):
# single line + no whitespace + looks like a path (leading / ./ ../ ~/ , or a
# slash plus a 2-4 letter extension). Real notes are almost always multi-line prose.
case "$TEXT" in
  *$'\n'*) _looks_like_path=0 ;;
  *[[:space:]]*) _looks_like_path=0 ;;
  /*|./*|../*|~/*) _looks_like_path=1 ;;
  */*.[A-Za-z][A-Za-z]|*/*.[A-Za-z][A-Za-z][A-Za-z]|*/*.[A-Za-z][A-Za-z][A-Za-z][A-Za-z])
      _looks_like_path=1 ;;
  *) _looks_like_path=0 ;;
esac
if [ "$_looks_like_path" -eq 1 ]; then
  echo "2nd argument looks like a file path, not text (${TEXT}). To feed a file: $0 $ISSUE - < file" >&2
  exit 2
fi

# Single-line text that starts with -- is an option typo, not a note.
case "$TEXT" in
  *$'\n'*) : ;;
  --*) echo "2nd argument looks like an option, not text (${TEXT}). To feed a file: $0 $ISSUE - < file" >&2
       exit 2 ;;
esac

BD_BIN="${BD_BIN:-bd}"
if [[ "$BD_BIN" == */* ]]; then
  case "$BD_BIN" in
    /*) ;;
    *) BD_BIN="$PWD/$BD_BIN" ;;
  esac
elif command -v "$BD_BIN" >/dev/null 2>&1; then
  BD_BIN="$(command -v "$BD_BIN")"
fi
[ -n "${BD_WORKDIR:-}" ] && cd "$BD_WORKDIR"

ISSUE="$ISSUE" TEXT="$TEXT" BD_BIN="$BD_BIN" python3 - <<'PY'
import json, os, subprocess, sys

issue, text, bd = os.environ['ISSUE'], os.environ['TEXT'], os.environ['BD_BIN']

def run_bd(args):
    try:
        return subprocess.run([bd] + args, capture_output=True, text=True)
    except FileNotFoundError:
        print(f"bd executable not found: {bd}", file=sys.stderr)
        sys.exit(3)

def show():
    r = run_bd(['show', issue, '--json'])
    if r.returncode != 0:
        print(f"bd show failed: {r.stderr.strip()[:200]}", file=sys.stderr)
        sys.exit(3)
    try:
        d = json.loads(r.stdout)
    except ValueError:
        print("bd show did not return JSON", file=sys.stderr)
        sys.exit(3)
    if isinstance(d, list):
        if not d:
            print(f"bd show returned empty list for issue: {issue}", file=sys.stderr)
            sys.exit(3)
        d = d[0]
    return d

old = show().get('notes') or ''
merged = (old.rstrip('\n') + '\n' + text) if old else text

r = run_bd(['update', issue, '--notes', merged])
if r.returncode != 0:
    print(f"bd update failed: {r.stderr.strip()[:200]}", file=sys.stderr)
    sys.exit(4)

new = show().get('notes') or ''
if len(new) < len(old):
    # Shorter after a write means an overwrite happened. Say so loudly:
    # silence is the only way this bug ever hurts anyone.
    print(f"WARNING: notes got shorter after write ({len(old)} -> {len(new)}); verify by hand", file=sys.stderr)
    sys.exit(5)
if len(new) == len(old) or not new.rstrip('\n').endswith(text.rstrip('\n')):
    print(f"WARNING: notes did not increase or appended text not found after write ({len(old)} -> {len(new)}); verify by hand", file=sys.stderr)
    sys.exit(5)
print(f"{issue}: notes {len(old)} -> {len(new)} chars (appended {len(text)})")
PY
