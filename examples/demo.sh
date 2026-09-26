#!/usr/bin/env bash
# Run the tool against the fake bd, no real beads needed:  bash examples/demo.sh
set -e
here="$(cd "$(dirname "$0")" && pwd)"
export BD_BIN="$here/bd-stub" BD_STUB_DIR="$(mktemp -d)"
bash "$here/../bd-note-append.sh" demo-1 "first note"
bash "$here/../bd-note-append.sh" demo-1 "second note, first one is kept"
echo "--- notes now:"; cat "$BD_STUB_DIR/demo-1.txt"; echo
