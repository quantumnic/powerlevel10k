#!/usr/bin/env zsh
# Tests for wizard cp -p fallback chain (#2896)
# Verifies that the wizard gracefully handles cp -p failures on sticky-bit dirs.

emulate -L zsh

local -i pass=0 fail=0

function assert_contains() {
  local desc=$1 haystack=$2 needle=$3
  if [[ $haystack == *$needle* ]]; then
    print -P "  %F{green}PASS%f: $desc"
    (( pass++ ))
  else
    print -P "  %F{red}FAIL%f: $desc"
    print "    Expected to contain: $needle"
    print "    Got: ${haystack[1,200]}"
    (( fail++ ))
  fi
}

# Read wizard source
local wizard_source
wizard_source=$(<internal/wizard.zsh) 2>/dev/null || {
  print -P "  %F{red}FAIL%f: could not read internal/wizard.zsh"
  exit 1
}

# Test 1: zshrc backup has cp -p → cp → cat fallback chain
assert_contains \
  "zshrc backup uses cp -p with fallback to cp" \
  "$wizard_source" \
  'cp -p $__p9k_zshrc $zshrc_backup 2>/dev/null ||'

# Test 2: zshrc backup falls back to plain cp
assert_contains \
  "zshrc backup falls back to plain cp" \
  "$wizard_source" \
  'cp $__p9k_zshrc $zshrc_backup 2>/dev/null ||'

# Test 3: zshrc backup falls back to cat
assert_contains \
  "zshrc backup falls back to cat" \
  "$wizard_source" \
  'cat $__p9k_zshrc >$zshrc_backup'

# Test 4: change_zshrc has similar fallback chain
assert_contains \
  "change_zshrc uses cp -p with fallback chain" \
  "$wizard_source" \
  'cp -p $__p9k_zshrc $tmp 2>/dev/null || cp $__p9k_zshrc $tmp 2>/dev/null || cat $__p9k_zshrc >$tmp'

# Test 5: config backup uses plain cp (no -p needed since it's in tmpdir)
assert_contains \
  "config backup uses plain cp" \
  "$wizard_source" \
  'cp $__p9k_cfg_path $config_backup'

# Test 6: TMPDIR is preferred when available
assert_contains \
  "wizard prefers TMPDIR over /tmp" \
  "$wizard_source" \
  'local tmpdir=$TMPDIR'

# Test 7: Falls back to /tmp when TMPDIR not available
assert_contains \
  "wizard falls back to /tmp" \
  "$wizard_source" \
  'local tmpdir=/tmp'

print
if (( fail )); then
  print -P "%F{red}$fail test(s) failed%f, $pass passed"
  exit 1
else
  print -P "%F{green}All $pass tests passed%f"
fi
