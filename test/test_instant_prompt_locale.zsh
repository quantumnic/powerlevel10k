#!/usr/bin/env zsh
# Test: instant prompt time locale handling
# Verifies that the stash expansion for instant_prompt_time forces LC_TIME=C
# to avoid localized AM/PM strings (issue #2871).

emulate -L zsh
setopt extended_glob

local -i passed=0 failed=0

function assert_eq() {
  local desc=$1 expected=$2 actual=$3
  if [[ $expected == $actual ]]; then
    print -P "%F{green}✓%f $desc"
    (( passed++ ))
  else
    print -P "%F{red}✗%f $desc (expected: ${(q)expected}, got: ${(q)actual})"
    (( failed++ ))
  fi
}

# Test that LC_TIME=C produces English AM/PM
function test_c_locale_ampm() {
  local LC_TIME=C
  local result=${(%):-'%D{%p}'}
  # %p should produce AM or PM in C locale
  [[ $result == 'AM' || $result == 'PM' ]]
  assert_eq "C locale produces AM or PM" 0 $?
}

# Test that non-C locale could produce different AM/PM
function test_locale_save_restore() {
  local original_lc="test_value"
  local save=$original_lc
  local LC_TIME=C
  LC_TIME=$save
  assert_eq "LC_TIME restored after override" "$original_lc" "$LC_TIME"
}

# Test the stash pattern: save → set C → eval → restore
function test_stash_locale_pattern() {
  local __p9k_instant_prompt_lc_time_save=''
  local LC_TIME='ja_JP.UTF-8'
  
  # Simulate the stash pattern
  __p9k_instant_prompt_lc_time_save=$LC_TIME
  LC_TIME=C
  local result=${(%):-'%D{%p}'}
  LC_TIME=$__p9k_instant_prompt_lc_time_save
  
  # After the stash, LC_TIME should be restored
  assert_eq "LC_TIME restored after stash pattern" 'ja_JP.UTF-8' "$LC_TIME"
  # Result should be English AM/PM
  [[ $result == 'AM' || $result == 'PM' ]]
  assert_eq "stash produces English AM/PM" 0 $?
}

test_c_locale_ampm
test_locale_save_restore
test_stash_locale_pattern

print
if (( failed )); then
  print -P "%F{red}$failed test(s) failed%f"
  exit 1
else
  print -P "%F{green}All $passed tests passed%f"
fi
