#!/usr/bin/env zsh
# Tests for disk_usage segment parsing and threshold logic

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

print -P "%F{yellow}Testing disk_usage segment parsing%f"

# Simulate df -P output parsing
# Typical df -P output:
# Filesystem     1024-blocks      Used Available Capacity Mounted on
# /dev/disk1s1    488245288 234567890 123456789      66% /

# Test: parse percentage from df -P output
local df_output="Filesystem     1024-blocks      Used Available Capacity Mounted on
/dev/disk1s1    488245288 234567890 123456789      66% /"
local pct=${${=${(f)df_output}[2]}[5]%%%}
assert_eq "$pct" "66" "Parse 66% from df -P output"

# Test: parse 100% (full disk)
df_output="Filesystem     1024-blocks      Used Available Capacity Mounted on
/dev/sda1       100000000 100000000         0     100% /"
pct=${${=${(f)df_output}[2]}[5]%%%}
assert_eq "$pct" "100" "Parse 100% (full disk)"

# Test: parse 0% (empty disk)
df_output="Filesystem     1024-blocks      Used Available Capacity Mounted on
tmpfs            16384000         0  16384000       0% /tmp"
pct=${${=${(f)df_output}[2]}[5]%%%}
assert_eq "$pct" "0" "Parse 0% (empty)"

# Test: parse 1% 
df_output="Filesystem     1024-blocks      Used Available Capacity Mounted on
/dev/sdb1       500000000   5000000 495000000       1% /data"
pct=${${=${(f)df_output}[2]}[5]%%%}
assert_eq "$pct" "1" "Parse 1%"

# Test: validate range (0-100)
local valid=0
[[ "66" == <0-100> ]] && valid=1
assert_eq "$valid" "1" "66 is valid percentage"

valid=0
[[ "101" == <0-100> ]] && valid=1
assert_eq "$valid" "0" "101 is invalid percentage"

valid=0
[[ "-1" == <0-100> ]] && valid=1
assert_eq "$valid" "0" "-1 is invalid percentage"

# Test: threshold logic
local -i _POWERLEVEL9K_DISK_USAGE_WARNING_LEVEL=50
local -i _POWERLEVEL9K_DISK_USAGE_CRITICAL_LEVEL=90
local -i _POWERLEVEL9K_DISK_USAGE_ONLY_WARNING=0
local _p9k__disk_usage_normal= _p9k__disk_usage_warning= _p9k__disk_usage_critical=

# Simulate threshold check for 95% (critical)
local -i _p9k__disk_usage_pct=95
_p9k__disk_usage_normal=
_p9k__disk_usage_warning=
_p9k__disk_usage_critical=
if (( _p9k__disk_usage_pct >= _POWERLEVEL9K_DISK_USAGE_CRITICAL_LEVEL )); then
  _p9k__disk_usage_critical=1
elif (( _p9k__disk_usage_pct >= _POWERLEVEL9K_DISK_USAGE_WARNING_LEVEL )); then
  _p9k__disk_usage_warning=1
elif (( ! _POWERLEVEL9K_DISK_USAGE_ONLY_WARNING )); then
  _p9k__disk_usage_normal=1
fi
assert_eq "$_p9k__disk_usage_critical" "1" "95% triggers critical"
assert_eq "$_p9k__disk_usage_warning" "" "95% does not trigger warning"
assert_eq "$_p9k__disk_usage_normal" "" "95% does not trigger normal"

# Simulate threshold check for 70% (warning)
_p9k__disk_usage_pct=70
_p9k__disk_usage_normal=
_p9k__disk_usage_warning=
_p9k__disk_usage_critical=
if (( _p9k__disk_usage_pct >= _POWERLEVEL9K_DISK_USAGE_CRITICAL_LEVEL )); then
  _p9k__disk_usage_critical=1
elif (( _p9k__disk_usage_pct >= _POWERLEVEL9K_DISK_USAGE_WARNING_LEVEL )); then
  _p9k__disk_usage_warning=1
elif (( ! _POWERLEVEL9K_DISK_USAGE_ONLY_WARNING )); then
  _p9k__disk_usage_normal=1
fi
assert_eq "$_p9k__disk_usage_critical" "" "70% does not trigger critical"
assert_eq "$_p9k__disk_usage_warning" "1" "70% triggers warning"
assert_eq "$_p9k__disk_usage_normal" "" "70% does not trigger normal"

# Simulate threshold check for 30% (normal)
_p9k__disk_usage_pct=30
_p9k__disk_usage_normal=
_p9k__disk_usage_warning=
_p9k__disk_usage_critical=
if (( _p9k__disk_usage_pct >= _POWERLEVEL9K_DISK_USAGE_CRITICAL_LEVEL )); then
  _p9k__disk_usage_critical=1
elif (( _p9k__disk_usage_pct >= _POWERLEVEL9K_DISK_USAGE_WARNING_LEVEL )); then
  _p9k__disk_usage_warning=1
elif (( ! _POWERLEVEL9K_DISK_USAGE_ONLY_WARNING )); then
  _p9k__disk_usage_normal=1
fi
assert_eq "$_p9k__disk_usage_critical" "" "30% does not trigger critical"
assert_eq "$_p9k__disk_usage_warning" "" "30% does not trigger warning"
assert_eq "$_p9k__disk_usage_normal" "1" "30% triggers normal"

# Test: ONLY_WARNING mode (30% should not show)
_POWERLEVEL9K_DISK_USAGE_ONLY_WARNING=1
_p9k__disk_usage_pct=30
_p9k__disk_usage_normal=
_p9k__disk_usage_warning=
_p9k__disk_usage_critical=
if (( _p9k__disk_usage_pct >= _POWERLEVEL9K_DISK_USAGE_CRITICAL_LEVEL )); then
  _p9k__disk_usage_critical=1
elif (( _p9k__disk_usage_pct >= _POWERLEVEL9K_DISK_USAGE_WARNING_LEVEL )); then
  _p9k__disk_usage_warning=1
elif (( ! _POWERLEVEL9K_DISK_USAGE_ONLY_WARNING )); then
  _p9k__disk_usage_normal=1
fi
assert_eq "$_p9k__disk_usage_normal" "" "30% with ONLY_WARNING=1 does not show"

print
print -P "Results: %F{green}$pass passed%f, %F{red}$fail failed%f"
(( fail )) && exit 1
exit 0
