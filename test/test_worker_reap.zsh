#!/usr/bin/env zsh
# Ensure async worker process-substitution children are reaped after their pipe closes.

emulate -L zsh

local root=${0:A:h}/..
source $root/internal/worker.zsh

local worker_main=$(functions _p9k_worker_main)
local gitstatus_daemon=$(<$root/gitstatus/gitstatus.plugin.zsh)
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
assert_contains \
  "worker exits when the parent process dies" \
  "$worker_main" \
  'local -i _p9k_worker_orig_ppid=$sysparams[ppid]'
assert_contains \
  "gitstatus daemon monitors for orphaning" \
  "$gitstatus_daemon" \
  'local orig_ppid=$sysparams[ppid]'
assert_contains \
  "gitstatus daemon kills its process group on orphaning" \
  "$gitstatus_daemon" \
  'kill -- -$pgid 2>/dev/null'

print
if (( fail )); then
  print -P "%F{red}$fail test(s) failed%f, $pass passed"
  exit 1
fi

print -P "%F{green}All $pass tests passed%f"
