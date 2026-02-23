#!/usr/bin/env zsh
# Test: terraform/tofu segment support

setopt extended_glob

local pass=0 fail=0

run_test() {
  local desc=$1 expected=$2 actual=$3
  if [[ $actual == $expected ]]; then
    print "  \e[32mPASS\e[0m: $desc"
    (( pass++ ))
  else
    print "  \e[31mFAIL\e[0m: $desc (expected '$expected', got '$actual')"
    (( fail++ ))
  fi
}

print "\e[33mTesting terraform/tofu segment patterns\e[0m"

# Test init condition pattern (should match terraform OR tofu)
local cond='${commands[terraform]:-$commands[tofu]}'

# Test the pattern logic using simulated associative arrays
# (can't override $commands directly, so test the pattern with custom vars)
() {
  local -A cmds=([terraform]=/usr/bin/terraform)
  local r=${cmds[terraform]:-${cmds[tofu]}}
  run_test "terraform available resolves" "/usr/bin/terraform" "$r"
}
() {
  local -A cmds=([tofu]=/usr/bin/tofu)
  local r=${cmds[terraform]:-${cmds[tofu]}}
  run_test "tofu available resolves" "/usr/bin/tofu" "$r"
}
() {
  local -A cmds=([terraform]=/usr/bin/terraform [tofu]=/usr/bin/tofu)
  local r=${cmds[terraform]:-${cmds[tofu]}}
  run_test "terraform takes priority over tofu" "/usr/bin/terraform" "$r"
}
() {
  local -A cmds=()
  local r=${cmds[terraform]:-${cmds[tofu]}}
  run_test "neither available returns empty" "" "$r"
}

# Test version output parsing
local tf_output="Terraform v1.7.5
on darwin_arm64"
local v=${${tf_output#(Terraform|OpenTofu) v}%%$'\n'*}
run_test "Parse Terraform version" "1.7.5" "$v"

local tofu_output="OpenTofu v1.8.0
on linux_amd64"
v=${${tofu_output#(Terraform|OpenTofu) v}%%$'\n'*}
run_test "Parse OpenTofu version" "1.8.0" "$v"

# Test SHOW_ON_COMMAND patterns in config
local show_on='aws|awless|cdk|terraform|tofu|pulumi|terragrunt'
[[ "tofu" == ${~show_on} ]]
run_test "tofu matches SHOW_ON_COMMAND" "0" "$?"

[[ "terraform" == ${~show_on} ]]
run_test "terraform matches SHOW_ON_COMMAND" "0" "$?"

[[ "kubectl" == ${~show_on} ]]
run_test "kubectl does not match aws SHOW_ON_COMMAND" "1" "$?"

print ""
if (( fail )); then
  print "\e[31m$pass passed, $fail failed\e[0m"
  exit 1
else
  print "\e[32mAll $pass tests passed\e[0m"
fi
