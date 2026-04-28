#!/usr/bin/env zsh
# Tests for the ai_workspace prompt segment.

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
    (( fail++ ))
  fi
}

function assert_equals() {
  local desc=$1 actual=$2 expected=$3
  if [[ $actual == $expected ]]; then
    print -P "  %F{green}PASS%f: $desc"
    (( pass++ ))
  else
    print -P "  %F{red}FAIL%f: $desc"
    print "    Expected: $expected"
    print "    Got:      $actual"
    (( fail++ ))
  fi
}

local p10k_source icons_source
p10k_source=$(<"$root/internal/p10k.zsh") || exit 1
icons_source=$(<"$root/internal/icons.zsh") || exit 1

assert_contains "ai_workspace prompt function exists" "$p10k_source" "prompt_ai_workspace"
assert_contains "Codex environment is detected" "$p10k_source" "CODEX_SANDBOX"
assert_contains "Claude environment is detected" "$p10k_source" "CLAUDECODE"
assert_contains "Gemini environment is detected" "$p10k_source" "GEMINI_CLI"
assert_contains "template parameter is declared" "$p10k_source" "POWERLEVEL9K_AI_WORKSPACE_TEMPLATE"
assert_contains "AI icon is available" "$icons_source" "AI_WORKSPACE_ICON"

local home out
home=$(mktemp -d "${TMPDIR:-/tmp}/p10k-ai-segment-test.XXXXXXXXXX") || exit 1
trap 'rm -rf -- "$home"' EXIT

out=$(HOME="$home" ZDOTDIR="$home" POWERLEVEL9K_DISABLE_INSTANT_PROMPT=true CODEX_SANDBOX=seatbelt zsh -f -c "
  source ${(q)root}/powerlevel10k.zsh-theme
  _p9k_ai_workspace_detect
  print -r -- \$P9K_AI_WORKSPACE
" 2>/dev/null)
assert_equals "Codex detection sets workspace label" "$out" "codex"

out=$(HOME="$home" ZDOTDIR="$home" POWERLEVEL9K_DISABLE_INSTANT_PROMPT=true POWERLEVEL9K_AI_WORKSPACE_CONTEXT=manual zsh -f -c "
  source ${(q)root}/powerlevel10k.zsh-theme
  _p9k_init_vars
  _p9k_init_params
  _p9k_ai_workspace_detect
  print -r -- \$P9K_AI_WORKSPACE
" 2>/dev/null)
out=${out##*$'\n'}
assert_equals "explicit workspace context wins" "$out" "manual"

print
if (( fail )); then
  print -P "%F{red}$fail test(s) failed%f, $pass passed"
  exit 1
else
  print -P "%F{green}All $pass tests passed%f"
fi
