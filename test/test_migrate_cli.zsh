#!/usr/bin/env zsh
# Tests for migrate.zsh dry-run, check mode and timestamped backups.

emulate -L zsh
set -u

local script="${0:A:h}/../migrate.zsh"
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

function assert_file_exists() {
  local desc=$1 file=$2
  if [[ -f $file ]]; then
    print -P "  %F{green}PASS%f: $desc"
    (( pass++ ))
  else
    print -P "  %F{red}FAIL%f: $desc"
    print "    Missing file: $file"
    (( fail++ ))
  fi
}

function read_file() {
  local content
  IFS= read -r content <$1
  print -r -- "$content"
}

local tmp
tmp=$(mktemp -d "${TMPDIR:-/tmp}/p10k-migrate-test.XXXXXXXXXX") || exit 1
trap 'rm -rf -- "$tmp"' EXIT

mkdir -p "$tmp/check-home" "$tmp/dry-home/.config/sheldon" "$tmp/apply-home"

local out
out=$(HOME="$tmp/check-home" ZDOTDIR="$tmp/check-home" zsh -f "$script" --check 2>&1)
assert_contains "check mode prints check header" "$out" "Migration Check"
assert_contains "check mode handles missing Zinit under nounset" "$out" "No romkatv/powerlevel10k references found"
out=$(HOME="$tmp/check-home" ZDOTDIR="$tmp/check-home" ZINIT=scalar zsh -f "$script" --check 2>&1)
assert_contains "check mode handles scalar Zinit under nounset" "$out" "No romkatv/powerlevel10k references found"

print -r -- 'source romkatv/powerlevel10k' >"$tmp/dry-home/.zshrc"
print -r -- 'github = "romkatv/powerlevel10k"' >"$tmp/dry-home/.config/sheldon/plugins.toml"
out=$(HOME="$tmp/dry-home" ZDOTDIR="$tmp/dry-home" XDG_CONFIG_HOME="$tmp/dry-home/.config" zsh -f "$script" --dry-run 2>&1)
assert_contains "dry-run reports zshrc update" "$out" "Would update references in"
assert_contains "dry-run covers Sheldon config" "$out" "plugins.toml"
assert_contains "dry-run reports no writes" "$out" "No files, remotes, or caches were changed"
assert_equals "dry-run leaves zshrc unchanged" "$(read_file "$tmp/dry-home/.zshrc")" 'source romkatv/powerlevel10k'

print -r -- 'zinit light romkatv/powerlevel10k' >"$tmp/apply-home/.zshrc"
out=$(P10K_MIGRATE_TIMESTAMP=20260428-123456 HOME="$tmp/apply-home" ZDOTDIR="$tmp/apply-home" zsh -f "$script" 2>&1)
assert_contains "apply reports config update count" "$out" "Config files updated:"
assert_contains "apply prints restore command" "$out" "restore:"
assert_equals "apply rewrites config reference" "$(read_file "$tmp/apply-home/.zshrc")" 'zinit light quantumnic/powerlevel10k'
assert_file_exists "apply creates timestamped backup" "$tmp/apply-home/.zshrc.p10k-migrate-20260428-123456-backup"
assert_equals "backup preserves original config" "$(read_file "$tmp/apply-home/.zshrc.p10k-migrate-20260428-123456-backup")" 'zinit light romkatv/powerlevel10k'

print
if (( fail )); then
  print -P "%F{red}$fail test(s) failed%f, $pass passed"
  exit 1
else
  print -P "%F{green}All $pass tests passed%f"
fi
