#!/usr/bin/env zsh
# Tests for p10k doctor and gitstatus diagnostics.

emulate -L zsh

local root="${0:A:h}/.."
local -i pass=0 fail=0

function assert_contains() {
  local desc=$1 haystack=$2 needle=$3
  if [[ $haystack == *$needle* ]]; then
    print -P "  %F{green}PASS%f: $desc"
    (( pass++ ))
  else
    print -P "  %F{red}FAIL%f: $desc"
    print "    Expected to contain: $needle"
    print "    Got: ${haystack[1,300]}"
    (( fail++ ))
  fi
}

local home
home=$(mktemp -d "${TMPDIR:-/tmp}/p10k-doctor-test.XXXXXXXXXX") || exit 1
trap 'rm -rf -- "$home"' EXIT

local out
out=$(HOME="$home" ZDOTDIR="$home" POWERLEVEL9K_DISABLE_INSTANT_PROMPT=true zsh -f -c "
  source ${(q)root}/powerlevel10k.zsh-theme
  p10k help doctor
  p10k help gitstatus
  p10k doctor
  p10k doctor gitstatus
  p10k gitstatus doctor
" 2>&1)

local gitstatus_alias_out
gitstatus_alias_out=$(HOME="$home" ZDOTDIR="$home" POWERLEVEL9K_DISABLE_INSTANT_PROMPT=true zsh -f -c "
  source ${(q)root}/powerlevel10k.zsh-theme
  p10k gitstatus doctor
" 2>&1)

assert_contains "doctor help is available" "$out" "Print environment diagnostics"
assert_contains "gitstatus diagnostics help is available" "$out" "Print diagnostics for gitstatus"
assert_contains "doctor prints heading" "$out" "Powerlevel10k Doctor"
assert_contains "doctor checks zsh" "$out" "zsh"
assert_contains "doctor checks installation" "$out" "installation"
assert_contains "doctor prints gitstatus section" "$out" "gitstatus"
assert_contains "gitstatus doctor checks plugin" "$out" "gitstatus.plugin.zsh"
assert_contains "gitstatus command alias checks plugin" "$gitstatus_alias_out" "gitstatus.plugin.zsh"

print
if (( fail )); then
  print -P "%F{red}$fail test(s) failed%f, $pass passed"
  exit 1
else
  print -P "%F{green}All $pass tests passed%f"
fi
