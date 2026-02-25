#!/usr/bin/env zsh
# Test: ##* stash pattern does not cause "bad substitution" with special chars
# Regression test for issue #18: LC_TIME values containing dots, hyphens,
# or other non-identifier characters must not trigger "bad substitution".

emulate -L zsh
setopt extended_glob

local -i pass=0 fail=0

function assert_ok() {
  local desc=$1
  shift
  local err
  err=$( eval "$@" 2>&1 >/dev/null )
  if [[ -z $err ]]; then
    print -P "  %F{green}PASS%f: $desc"
    (( pass++ ))
  else
    print -P "  %F{red}FAIL%f: $desc (stderr: $err)"
    (( fail++ ))
  fi
}

print -P "%F{yellow}Testing stash pattern with problematic LC_TIME values%f"

# The fixed pattern uses ##* to silently discard the assigned value.
# The old pattern used +} which interprets the value as a parameter name.

# Test various LC_TIME values that contain non-identifier characters
local -a problem_values=(
  'en_US.UTF-8'
  'de_DE.UTF-8'
  'ja_JP.EUC-JP'
  'zh_CN.GB18030'
  'POSIX'
  'C'
  ''
  'en_GB.ISO-8859-1'
)

for val in $problem_values; do
  # Test the FIXED pattern (##*): should never error
  assert_ok "##* pattern with LC_TIME='$val'" \
    'local __save; local LC_TIME="'$val'"; : ${${__save::=$LC_TIME}##*}${${LC_TIME::=C}##*}${${LC_TIME::=$__save}##*}'
done

print
# Test that the old broken pattern (+}) DOES fail on dotted values
# This confirms the regression test is meaningful
local old_err
old_err=$( eval 'local __save; local LC_TIME="en_US.UTF-8"; : ${${__save::=$LC_TIME}+}' 2>&1 >/dev/null )
if [[ -n $old_err ]]; then
  print -P "  %F{green}PASS%f: old +} pattern correctly fails on dotted values (confirms fix is needed)"
  (( pass++ ))
else
  # On some zsh versions +} might not error; that's OK, just note it
  print -P "  %F{yellow}INFO%f: old +} pattern did not error on this zsh version (${ZSH_VERSION})"
fi

print
print -P "Results: %F{green}$pass passed%f, %F{red}$fail failed%f"
(( fail )) && exit 1
exit 0
