#!/usr/bin/env bash
# Zero-dependency test runner (bash + python3 stdlib). Exit 0 = all pass.
set -u
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TOOL="$ROOT/bd-note-append.sh"
export BD_BIN="$ROOT/examples/bd-stub"
PASS=0; FAIL=0

fresh() { export BD_STUB_DIR; BD_STUB_DIR="$(mktemp -d)"; }
notes() { cat "$BD_STUB_DIR/$1.txt" 2>/dev/null || true; }
ok()   { PASS=$((PASS+1)); echo "ok   - $1"; }
bad()  { FAIL=$((FAIL+1)); echo "FAIL - $1 ($2)"; }
# expect <name> <expected-rc> <cmd...>
expect() { local name="$1" want="$2"; shift 2; "$@" >/dev/null 2>&1; local rc=$?; [ "$rc" -eq "$want" ] && ok "$name" || bad "$name" "rc=$rc want=$want"; }

# ---- positive cases ----
fresh
expect "P1 append to empty notes" 0 bash "$TOOL" t1 "first"
[ "$(notes t1)" = "first" ] && ok "P1b content is 'first'" || bad "P1b content" "$(notes t1)"

bash "$TOOL" t1 "second" >/dev/null 2>&1
[ "$(notes t1)" = "$(printf 'first\nsecond')" ] && ok "P2 second append keeps first" || bad "P2 keeps old text" "$(notes t1)"

printf 'line A\nline B\n' | bash "$TOOL" t2 - >/dev/null 2>&1
[ "$(notes t2)" = "$(printf 'line A\nline B\n')" ] && ok "P3 stdin multi-line via '-'" || bad "P3 stdin" "$(notes t2)"

bash "$TOOL" t3 "日本語と中文 ok" >/dev/null 2>&1; bash "$TOOL" t3 "second ✓" >/dev/null 2>&1
[ "$(notes t3)" = "$(printf '日本語と中文 ok\nsecond ✓')" ] && ok "P4 unicode survives" || bad "P4 unicode" "$(notes t3)"

# a multi-line note that mentions a path in prose must NOT be rejected
bash "$TOOL" t4 "see /var/log/app.log for details" >/dev/null 2>&1
[ "$(notes t4)" = "see /var/log/app.log for details" ] && ok "P5 prose containing a path is accepted" || bad "P5 prose with path" "$(notes t4)"

# P6 relative BD_BIN survives with BD_WORKDIR
WORKDIR="$(mktemp -d)"
(
  cd "$ROOT"
  BD_BIN="examples/bd-stub" BD_WORKDIR="$WORKDIR" bash "$TOOL" t6 "works from sub dir" >/dev/null 2>&1
)
[ "$(notes t6)" = "works from sub dir" ] && ok "P6 relative BD_BIN works with BD_WORKDIR" || bad "P6 relative BD_BIN" "$(notes t6)"

# ---- negative cases ----
fresh
expect "N0 no args rejected (rc 2)" 2 bash "$TOOL"
bash "$TOOL" n1 "keep me" >/dev/null 2>&1
expect "N1 path-shaped arg rejected (rc 2)" 2 bash "$TOOL" n1 /tmp/note.txt
[ "$(notes n1)" = "keep me" ] && ok "N1b notes untouched after path reject" || bad "N1b untouched" "$(notes n1)"

expect "N2 option-shaped arg rejected (rc 2)" 2 bash "$TOOL" n1 --file
expect "N3 extra argument rejected (rc 2)" 2 bash "$TOOL" n1 "text" "/tmp/x.txt"
expect "N4 empty stdin rejected (rc 2)" 2 bash -c "printf '' | bash '$TOOL' n1 -"
[ "$(notes n1)" = "keep me" ] && ok "N4b notes untouched after rejects" || bad "N4b untouched" "$(notes n1)"

BD_STUB_LOSSY=1 expect "N5 shrink detected (rc 5)" 5 bash "$TOOL" n1 "this write gets truncated by a buggy backend"
BD_STUB_SHOW_FAIL=1 expect "N6 bd show failure surfaces (rc 3)" 3 bash "$TOOL" n1 "x"
BD_STUB_UPDATE_FAIL=1 expect "N7 bd update failure surfaces (rc 4)" 4 bash "$TOOL" n1 "x"
BD_STUB_SHOW_EMPTY=1 expect "N8 bd show empty list surfaces (rc 3)" 3 bash "$TOOL" n1 "x"
BD_BIN="/nonexistent/path/to/bd" expect "N9 bd missing surfaces (rc 3)" 3 bash "$TOOL" n1 "x"

echo "---- $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
