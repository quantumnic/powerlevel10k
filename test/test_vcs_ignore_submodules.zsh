#!/usr/bin/env zsh
# Tests for configurable POWERLEVEL9K_VCS_IGNORE_SUBMODULES (#2876)
#
# Verifies that the pure-git backend passes --ignore-submodules flag
# from the POWERLEVEL9K_VCS_IGNORE_SUBMODULES config variable.

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

assert_contains() {
  local desc=$1 pattern=$2 actual=$3
  (( ++total ))
  if [[ $actual == *$pattern* ]]; then
    (( ++passed ))
    print -P "%F{green}  PASS%f $desc"
  else
    (( ++failed ))
    print -P "%F{red}  FAIL%f $desc"
    print "    expected to contain: ${(q)pattern}"
    print "    actual: ${(q)actual}"
  fi
}

# Source the pure backend to check the code
local backend_file="${0:A:h}/../gitstatus/gitstatus-pure.plugin.zsh"
if [[ ! -f $backend_file ]]; then
  print -P "%F{red}SKIP%f: gitstatus-pure.plugin.zsh not found"
  exit 0
fi

local backend_code
backend_code=$(<$backend_file)

# Test 1: Backend references POWERLEVEL9K_VCS_IGNORE_SUBMODULES
assert_contains \
  "pure backend references POWERLEVEL9K_VCS_IGNORE_SUBMODULES" \
  "POWERLEVEL9K_VCS_IGNORE_SUBMODULES" \
  "$backend_code"

# Test 2: Backend uses --ignore-submodules flag
assert_contains \
  "pure backend passes --ignore-submodules to git status" \
  "--ignore-submodules=" \
  "$backend_code"

# Test 3: Default value is 'dirty' (matching gitstatusd behavior)
assert_contains \
  "default ignore-submodules value is dirty" \
  ':-dirty' \
  "$backend_code"

# Test 4: Variable is used in the git status command
assert_contains \
  "ignore_submodules variable used in git status call" \
  '--ignore-submodules=$ignore_submodules' \
  "$backend_code"

print ""
if (( failed )); then
  print -P "%F{red}$failed of $total tests failed%f"
  exit 1
else
  print -P "%F{green}All $total tests passed%f"
fi
