#!/usr/bin/env zsh
# Tests for wifi segment networksetup timeout protection.
# Verifies that timeout wrappers are present in the wifi async function.

emulate -L zsh
setopt no_unset

PASS=0
FAIL=0

pass() { (( PASS += 1 )); print "  PASS: $1"; }
fail() { (( FAIL += 1 )); print "  FAIL: $1"; }

P10K="${0:h}/../internal/p10k.zsh"

# Test 1: networksetup -listallhardwareports has timeout wrapper
if grep -q 'command timeout 5 networksetup -listallhardwareports' "$P10K"; then
  pass "networksetup -listallhardwareports has 5s timeout"
else
  fail "networksetup -listallhardwareports missing timeout"
fi

# Test 2: networksetup -getairportnetwork has timeout wrapper
if grep -q 'command timeout 5 networksetup -getairportnetwork' "$P10K"; then
  pass "networksetup -getairportnetwork has 5s timeout"
else
  fail "networksetup -getairportnetwork missing timeout"
fi

# Test 3: networksetup -listpreferredwirelessnetworks has timeout wrapper
if grep -q 'command timeout 5 networksetup -listpreferredwirelessnetworks' "$P10K"; then
  pass "networksetup -listpreferredwirelessnetworks has 5s timeout"
else
  fail "networksetup -listpreferredwirelessnetworks missing timeout"
fi

# Test 4: ipconfig getsummary has timeout wrapper
if grep -q 'command timeout 5 ipconfig getsummary' "$P10K"; then
  pass "ipconfig getsummary has 5s timeout"
else
  fail "ipconfig getsummary missing timeout"
fi

# Test 5: all timeout-wrapped calls have fallback (no timeout command available)
local -i fallback_count
fallback_count=$(grep -c 'command networksetup.*2>/dev/null' "$P10K")
# Should have both timeout and non-timeout variants (3 networksetup calls × 2 = 6, plus ipconfig)
if (( fallback_count >= 3 )); then
  pass "networksetup calls have non-timeout fallbacks ($fallback_count found)"
else
  fail "expected at least 3 networksetup fallback calls, got $fallback_count"
fi

print "\nResults: $PASS passed, $FAIL failed"
(( FAIL == 0 ))
