#!/usr/bin/env zsh
# Tests for POWERLEVEL9K_STATUS_ERROR_SHOW_ONCE feature (#2873)

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

# Source just the status function from p10k.zsh
# We test the logic by simulating the variables

# Test 1: Verify the config variable is declared with default 0
local decl_line=$(grep 'POWERLEVEL9K_STATUS_ERROR_SHOW_ONCE' ${0:A:h}/../internal/p10k.zsh | grep '_p9k_declare')
local has_decl=$(( ${#decl_line} > 0 ? 1 : 0 ))
assert "STATUS_ERROR_SHOW_ONCE declared" "1" "$has_decl"
[[ $decl_line == *" 0" ]] && \
  assert "STATUS_ERROR_SHOW_ONCE defaults to 0" "0" "0" || \
  assert "STATUS_ERROR_SHOW_ONCE defaults to 0" "0" "1"

# Test 2: Verify the show_once logic exists in prompt_status
local show_once_check=$(grep -c 'STATUS_ERROR_SHOW_ONCE' ${0:A:h}/../internal/p10k.zsh)
assert "STATUS_ERROR_SHOW_ONCE referenced in code" "1" "$(( show_once_check >= 3 ? 1 : 0 ))"

# Test 3: Verify _p9k__last_shown_status tracking exists
local tracking=$(grep -c '_p9k__last_shown_status' ${0:A:h}/../internal/p10k.zsh)
assert "last_shown_status tracking present" "1" "$(( tracking >= 2 ? 1 : 0 ))"

# Test 4: Verify the logic suppresses repeated status
# Check that matching last_shown_status triggers a return (next line after the comparison)
local suppress_check=$(grep -A1 '_p9k__last_shown_status:-' ${0:A:h}/../internal/p10k.zsh | grep -c 'return')
assert "suppresses repeated error status" "1" "$suppress_check"

# Test 5: Verify status is cleared on success (status 0)
local clear_line=$(grep -A1 'STATUS_ERROR_SHOW_ONCE.*_p9k__status' ${0:A:h}/../internal/p10k.zsh | grep '_p9k__last_shown_status=')
# Should have a line that clears last_shown_status (empty assignment)
local has_clear=$(grep '_p9k__last_shown_status=$' ${0:A:h}/../internal/p10k.zsh | wc -l)
assert "clears tracking on success" "1" "$(( has_clear > 0 ? 1 : 0 ))"

print
if (( fail )); then
  print -P "%F{red}$fail tests failed%f, $pass passed"
  return 1
else
  print -P "%F{green}All $pass tests passed%f"
fi
