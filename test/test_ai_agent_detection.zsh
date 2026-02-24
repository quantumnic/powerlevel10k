#!/usr/bin/env zsh
# Tests for AI coding agent detection in instant prompt (#2865)
# Verifies that instant prompt is auto-disabled for Cursor, Copilot, Windsurf, etc.

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

function assert_not_contains() {
  local desc=$1 haystack=$2 needle=$3
  if [[ $haystack != *$needle* ]]; then
    print -P "  %F{green}PASS%f: $desc"
    (( pass++ ))
  else
    print -P "  %F{red}FAIL%f: $desc"
    print "    Expected NOT to contain: $needle"
    (( fail++ ))
  fi
}

# Read the instant prompt generation code
local p10k_source
p10k_source=$(<internal/p10k.zsh) 2>/dev/null || {
  print -P "  %F{red}FAIL%f: could not read internal/p10k.zsh"
  exit 1
}

# Test 1: VSCODE_INJECTION guard exists in instant prompt generation
assert_contains \
  "instant prompt checks VSCODE_INJECTION env var" \
  "$p10k_source" \
  'VSCODE_INJECTION'

# Test 2: The guard returns early (disabling instant prompt)
assert_contains \
  "VSCODE_INJECTION check causes early return" \
  "$p10k_source" \
  '[[ -z "$VSCODE_INJECTION" ]] || return 0'

# Test 3: Comment references issue #2865
assert_contains \
  "code references issue #2865" \
  "$p10k_source" \
  '#2865'

# Test 4: Comment mentions AI coding agents
assert_contains \
  "code mentions AI coding agents" \
  "$p10k_source" \
  'AI coding agent'

# Test 5: Verify the check is BEFORE the main instant prompt logic
# (i.e., it appears in the early return section, not after prompt rendering)
local before_disabled after_disabled
before_disabled=${p10k_source%%'typeset -gi __p9k_instant_prompt_disabled=1'*}
assert_contains \
  "VSCODE_INJECTION check is before instant prompt activation" \
  "$before_disabled" \
  'VSCODE_INJECTION'

# Test 6: Verify that standard conditions still exist
assert_contains \
  "instant prompt still checks ZSH_SUBSHELL" \
  "$p10k_source" \
  'ZSH_SUBSHELL'

assert_contains \
  "instant prompt still checks POWERLEVEL9K_DISABLE_INSTANT_PROMPT" \
  "$p10k_source" \
  'POWERLEVEL9K_DISABLE_INSTANT_PROMPT'

print
if (( fail )); then
  print -P "%F{red}$fail test(s) failed%f, $pass passed"
  exit 1
else
  print -P "%F{green}All $pass tests passed%f"
fi
