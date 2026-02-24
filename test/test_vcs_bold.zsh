#!/usr/bin/env zsh
# Tests for VCS bold styling (romkatv/powerlevel10k#2859)
#
# Verifies that POWERLEVEL9K_VCS_*_BOLD properly applies %B (bold on)
# instead of the default %b (bold off) in _p9k_vcs_style output.

emulate -L zsh
setopt no_unset pipe_fail

typeset -gi passed=0 failed=0 total=0

assert_eq() {
  local desc=$1 expected=$2 actual=$3
  (( ++total ))
  if [[ $expected == $actual ]]; then
    (( ++passed ))
    print -P "%F{green}  PASS%f $desc"
  else
    (( ++failed ))
    print -P "%F{red}  FAIL%f $desc"
    print "    expected: ${(q)expected}"
    print "    actual:   ${(q)actual}"
  fi
}

assert_not_contains() {
  local desc=$1 pattern=$2 actual=$3
  (( ++total ))
  if [[ $actual != *$pattern* ]]; then
    (( ++passed ))
    print -P "%F{green}  PASS%f $desc"
  else
    (( ++failed ))
    print -P "%F{red}  FAIL%f $desc"
    print "    expected NOT to contain: ${(q)pattern}"
    print "    actual: ${(q)actual}"
  fi
}

# Helper: compute style like _p9k_vcs_style does
_test_vcs_style() {
  local bold_val=$1
  local style
  if (( bold_val )); then
    style=%B
  else
    style=%b
  fi
  print -rn -- "$style"
}

print "=== VCS Bold Styling Tests ==="

# Test 1: Default style starts with %b (bold off)
local result
result=$(_test_vcs_style 0)
assert_eq "Default style is %b (bold off)" "%b" "$result"

# Test 2: Bold enabled uses %B
result=$(_test_vcs_style 1)
assert_eq "Bold style is %B (bold on)" "%B" "$result"

# Test 3: Verify no %B%b cancellation (the old bug)
result=$(_test_vcs_style 1)
assert_not_contains "No %B%b cancellation in bold mode" "%B%b" "$result"
assert_eq "Bold mode produces only %B" "%B" "$result"

# Test 4: POWERLEVEL9K_VCS_BOLD defaults propagate to per-state vars
_POWERLEVEL9K_VCS_BOLD=1
for state in CLEAN MODIFIED UNTRACKED CONFLICTED LOADING; do
  local var=_POWERLEVEL9K_VCS_${state}_BOLD
  typeset -g $var=$_POWERLEVEL9K_VCS_BOLD
  result=$(_test_vcs_style ${(P)var})
  assert_eq "VCS_${state}_BOLD inherits global BOLD=1" "%B" "$result"
done

# Test 5: Per-state override
_POWERLEVEL9K_VCS_BOLD=1
_POWERLEVEL9K_VCS_CLEAN_BOLD=0
result=$(_test_vcs_style $_POWERLEVEL9K_VCS_CLEAN_BOLD)
assert_eq "Per-state CLEAN_BOLD=0 overrides global BOLD=1" "%b" "$result"

# Summary
print "\n=== Results: $passed/$total passed, $failed failed ==="
(( failed == 0 )) && exit 0 || exit 1
