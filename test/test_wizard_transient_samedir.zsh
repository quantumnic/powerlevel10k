#!/usr/bin/env zsh
# Tests for wizard transient prompt same-dir option (#2880)

emulate -L zsh
setopt extended_glob

local -i pass=0 fail=0

function assert() {
  local desc=$1 expected=$2 actual=$3
  if [[ $actual == $expected ]]; then
    print -P "%F{green}✓%f $desc"
    (( pass++ ))
  else
    print -P "%F{red}✗%f $desc (expected '$expected', got '$actual')"
    (( fail++ ))
  fi
}

local wizard=${0:A:h}/../internal/wizard.zsh

# Test 1: Wizard offers 'd' option for same-dir
local has_d_option=$(grep -c 'unless this is the first command after changing directory' $wizard)
assert "wizard offers same-dir option" "1" "$(( has_d_option > 0 ? 1 : 0 ))"

# Test 2: Wizard uses 'ydnr' ask pattern
local has_ydnr=$(grep -c 'ask ydnr' $wizard)
assert "wizard asks ydnr choices" "1" "$(( has_ydnr > 0 ? 1 : 0 ))"

# Test 3: 'd' choice sets transient_prompt=2
local d_choice=$(grep "d)" $wizard | grep 'transient_prompt=2')
assert "d choice sets transient_prompt=2" "1" "$(( ${#d_choice} > 0 ? 1 : 0 ))"

# Test 4: 'd' choice records same-dir in options
local d_samedir=$(grep "d)" $wizard | grep 'same-dir')
assert "d choice records same-dir option" "1" "$(( ${#d_samedir} > 0 ? 1 : 0 ))"

# Test 5: generate_config handles same-dir value
local tp_val=$(grep -c 'tp_val' $wizard)
assert "generate_config extracts transient_prompt value" "1" "$(( tp_val >= 3 ? 1 : 0 ))"

# Test 6: 'y' choice records always
local y_always=$(grep "y)" $wizard | grep 'transient_prompt=always')
assert "y choice records always option" "1" "$(( ${#y_always} > 0 ? 1 : 0 ))"

print
if (( fail )); then
  print -P "%F{red}$fail tests failed%f, $pass passed"
  return 1
else
  print -P "%F{green}All $pass tests passed%f"
fi
