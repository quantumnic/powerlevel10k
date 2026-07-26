#!/usr/bin/env zsh
# Ensure async worker process-substitution children are reaped after their pipe closes.

emulate -L zsh

local root=${0:A:h}/..
source $root/internal/worker.zsh

local worker_main=$(functions _p9k_worker_main)
local -i pass=0 fail=0

function assert_contains() {
  local description=$1 text=$2 needle=$3
  if [[ $text == *$needle* ]]; then
    print -P "  %F{green}PASS%f: $description"
    (( pass++ ))
  else
    print -P "  %F{red}FAIL%f: $description"
    print "    Expected to contain: $needle"
    (( fail++ ))
  fi
}

assert_contains \
  "worker records the process-substitution child pid" \
  "$worker_main" \
  'local async_pid=$sysparams[procsubstpid]'
assert_contains \
  "worker reaps the completed process-substitution child" \
  "$worker_main" \
  'wait $async_pid'
print
if (( fail )); then
  print -P "%F{red}$fail test(s) failed%f, $pass passed"
  exit 1
fi

print -P "%F{green}All $pass tests passed%f"
