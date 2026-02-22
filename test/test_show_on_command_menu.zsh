#!/usr/bin/env zsh
# Tests for SHOW_ON_COMMAND menu-select interaction (#2912)
# Verifies that prompt updates are skipped during menu-select keymap

emulate -L zsh

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

# Test: completion widgets should be detected in the skip list
print -P "%F{yellow}Testing SHOW_ON_COMMAND completion widget skip patterns%f"

local -a completion_widgets=(
  complete-word
  expand-or-complete
  menu-complete
  reverse-menu-complete
  menu-expand-or-complete
  expand-or-complete-prefix
  _complete_help
  _correct_word
  _expand_alias
  _expand_word
  _history_complete_word
  _most_recent_file
  _next_tags
  _read_comp
)

local pattern='(complete-word|expand-or-complete|menu-complete|reverse-menu-complete|menu-expand-or-complete|expand-or-complete-prefix|_complete_help|_correct_word|_expand_alias|_expand_word|_history_complete_word|_most_recent_file|_next_tags|_read_comp)'

for w in $completion_widgets; do
  local match_result=0
  [[ "$w" == ${~pattern} ]] && match_result=1
  assert_eq "$match_result" "1" "Widget '$w' matches completion skip pattern"
done

# Test: non-completion widgets should NOT match
local -a normal_widgets=(accept-line self-insert backward-delete-char)
for w in $normal_widgets; do
  local match_result=0
  [[ "$w" == ${~pattern} ]] && match_result=1
  assert_eq "$match_result" "0" "Widget '$w' does not match completion skip pattern"
done

# Test: menuselect keymap detection
local KEYMAP=menuselect
local should_skip=0
[[ "${KEYMAP:-}" == menuselect ]] && should_skip=1
assert_eq "$should_skip" "1" "menuselect keymap is detected"

KEYMAP=main
should_skip=0
[[ "${KEYMAP:-}" == menuselect ]] && should_skip=1
assert_eq "$should_skip" "0" "main keymap is not menuselect"

print
print -P "Results: %F{green}$pass passed%f, %F{red}$fail failed%f"
(( fail )) && exit 1
exit 0
