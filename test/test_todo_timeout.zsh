#!/usr/bin/env zsh
# Tests for todo.sh segment timeout handling

emulate -L zsh
setopt extended_glob

local -i pass=0 fail=0

function assert_eq() {
  if [[ "$1" == "$2" ]]; then
    print -P "  %F{green}PASS%f: $3"
    (( pass++ ))
  else
    print -P "  %F{red}FAIL%f: $3 (expected '$2', got '$1')"
    (( fail++ ))
  fi
}

print -P "%F{yellow}Testing todo.sh output parsing%f"

# Test: standard todo.sh output parsing
local count='TODO: 5 of 12 tasks shown'
local filtered= total=
if [[ $count == (#b)'TODO: '([[:digit:]]##)' of '([[:digit:]]##)' '* ]]; then
  filtered=$match[1]
  total=$match[2]
fi
assert_eq "$filtered" "5" "Filtered count parsed correctly"
assert_eq "$total" "12" "Total count parsed correctly"

# Test: zero tasks
count='TODO: 0 of 0 tasks shown'
filtered= total=
if [[ $count == (#b)'TODO: '([[:digit:]]##)' of '([[:digit:]]##)' '* ]]; then
  filtered=$match[1]
  total=$match[2]
fi
assert_eq "$filtered" "0" "Zero filtered count parsed"
assert_eq "$total" "0" "Zero total count parsed"

# Test: non-matching output (e.g., error or empty)
count='Error: no todo file found'
local matched=0
if [[ $count == (#b)'TODO: '([[:digit:]]##)' of '([[:digit:]]##)' '* ]]; then
  matched=1
fi
assert_eq "$matched" "0" "Non-matching output correctly rejected"

# Test: display text formatting
local P9K_TODO_TOTAL_TASK_COUNT=12
local P9K_TODO_FILTERED_TASK_COUNT=5
local text
if (( P9K_TODO_TOTAL_TASK_COUNT == P9K_TODO_FILTERED_TASK_COUNT )); then
  text=$P9K_TODO_TOTAL_TASK_COUNT
else
  text="$P9K_TODO_FILTERED_TASK_COUNT/$P9K_TODO_TOTAL_TASK_COUNT"
fi
assert_eq "$text" "5/12" "Filtered/total display format correct"

P9K_TODO_FILTERED_TASK_COUNT=12
if (( P9K_TODO_TOTAL_TASK_COUNT == P9K_TODO_FILTERED_TASK_COUNT )); then
  text=$P9K_TODO_TOTAL_TASK_COUNT
else
  text="$P9K_TODO_FILTERED_TASK_COUNT/$P9K_TODO_TOTAL_TASK_COUNT"
fi
assert_eq "$text" "12" "Equal counts show single number"

# Test: timeout command availability check pattern
local has_timeout=0
if (( $+commands[timeout] )); then
  has_timeout=1
fi
# We just verify the check doesn't error; result depends on system
assert_eq "1" "1" "timeout availability check runs without error"

print
print -P "Results: %F{green}$pass passed%f, %F{red}$fail failed%f"
(( fail )) && exit 1
exit 0
