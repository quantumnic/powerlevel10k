#!/usr/bin/env zsh
# Tests for instant_prompt_date LC_TIME=C fix

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

function assert_match() {
  if [[ "$1" == $~2 ]]; then
    print -P "  %F{green}PASS%f: $3"
    (( pass++ ))
  else
    print -P "  %F{red}FAIL%f: $3 ('$1' does not match pattern '$2')"
    (( fail++ ))
  fi
}

print -P "%F{yellow}Testing instant_prompt_date locale handling%f"

# Test: C locale produces English day/month names
local saved=$LC_TIME
LC_TIME=C
local date_c=${(%):-'%D{%A, %B %d}'}
LC_TIME=$saved

# Should contain English day name (Mon-Sun)
assert_match "$date_c" "*day*" "C locale produces English day name"

# Test: LC_TIME is restored after override
LC_TIME=en_US.UTF-8
local save_val=$LC_TIME
local tmp_save=$LC_TIME
LC_TIME=C
local formatted=${(%):-'%D{%A}'}
LC_TIME=$tmp_save
assert_eq "$LC_TIME" "$save_val" "LC_TIME restored after override"

# Test: stash-style save/restore pattern works
local __p9k_instant_prompt_lc_time_save_date=
LC_TIME=en_US.UTF-8
local before=$LC_TIME
# Simulate the stash pattern:
__p9k_instant_prompt_lc_time_save_date=$LC_TIME
LC_TIME=C
local during=$LC_TIME
LC_TIME=$__p9k_instant_prompt_lc_time_save_date
assert_eq "$during" "C" "LC_TIME set to C during stash"
assert_eq "$LC_TIME" "$before" "LC_TIME restored after stash"

# Test: date format with %p (AM/PM) uses C locale
LC_TIME=C
local time_c=${(%):-'%D{%p}'}
LC_TIME=$saved
assert_match "$time_c" "(AM|PM)" "C locale produces AM or PM in date format"

print
print -P "Results: %F{green}$pass passed%f, %F{red}$fail failed%f"
(( fail )) && exit 1
exit 0
