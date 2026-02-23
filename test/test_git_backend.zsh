#!/usr/bin/env zsh
# Tests for the pure-git gitstatus backend

emulate -L zsh
setopt extended_glob

local passed=0 failed=0
local test_dir=$(mktemp -d)
trap "rm -rf $test_dir" EXIT

source "${0:A:h}/../gitstatus/gitstatus-git-backend.zsh"

_pass() { (( passed++ )); print "  \e[32mPASS\e[0m: $1"; }
_fail() { (( failed++ )); print "  \e[31mFAIL\e[0m: $1 (expected: $2, got: $3)"; }
_assert() {
  if [[ "$2" == "$3" ]]; then _pass "$1"
  else _fail "$1" "$2" "$3"; fi
}

print "\e[33mTesting pure-git backend\e[0m"

# Test 1: Non-repo directory
_gitstatus_git_query /tmp
_assert "Non-repo returns norepo-sync" "norepo-sync" "$VCS_STATUS_RESULT"

# Test 2: Init a repo and check basics
local repo="$test_dir/repo1"
mkdir -p "$repo"
git -C "$repo" init -q
git -C "$repo" config user.name 'Test'
git -C "$repo" config user.email 'test@test.com'

_gitstatus_git_query "$repo"
_assert "Empty repo is ok-sync" "ok-sync" "$VCS_STATUS_RESULT"
_assert "Empty repo workdir set" "${repo:A}" "$VCS_STATUS_WORKDIR"

# Test 3: After a commit
echo "hello" > "$repo/file.txt"
git -C "$repo" add file.txt
git -C "$repo" commit -q -m "Initial commit"

_gitstatus_git_query "$repo"
_assert "Has commit hash (40 chars)" "40" "${#VCS_STATUS_COMMIT}"
local _branch_ok=0
[[ $VCS_STATUS_LOCAL_BRANCH == (master|main) ]] && _branch_ok=1
_assert "Branch is master or main" "1" "$_branch_ok"
_assert "Commit summary" "Initial commit" "$VCS_STATUS_COMMIT_SUMMARY"
_assert "Index size is 1" "1" "$VCS_STATUS_INDEX_SIZE"
_assert "No staged changes" "0" "$VCS_STATUS_NUM_STAGED"
_assert "No unstaged changes" "0" "$VCS_STATUS_NUM_UNSTAGED"
_assert "No untracked files" "0" "$VCS_STATUS_NUM_UNTRACKED"

# Test 4: Unstaged changes
echo "world" >> "$repo/file.txt"
_gitstatus_git_query "$repo"
_assert "Has unstaged" "1" "$VCS_STATUS_HAS_UNSTAGED"
_assert "1 unstaged" "1" "$VCS_STATUS_NUM_UNSTAGED"

# Test 5: Staged changes
git -C "$repo" add file.txt
_gitstatus_git_query "$repo"
_assert "Has staged" "1" "$VCS_STATUS_HAS_STAGED"
_assert "1 staged" "1" "$VCS_STATUS_NUM_STAGED"

# Test 6: Untracked files
echo "new" > "$repo/new.txt"
_gitstatus_git_query "$repo"
_assert "Has untracked" "1" "$VCS_STATUS_HAS_UNTRACKED"
_assert "1 untracked" "1" "$VCS_STATUS_NUM_UNTRACKED"

# Test 7: Stash
git -C "$repo" commit -q -m "second"
echo "stash me" > "$repo/stash.txt"
git -C "$repo" add stash.txt
git -C "$repo" stash -q
_gitstatus_git_query "$repo"
_assert "1 stash" "1" "$VCS_STATUS_STASHES"

# Test 8: Tag
git -C "$repo" tag v1.0
_gitstatus_git_query "$repo"
_assert "Tag detected" "v1.0" "$VCS_STATUS_TAG"

# Test 9: Action detection (merge conflict)
local repo2="$test_dir/repo2"
git clone -q "$repo" "$repo2"
git -C "$repo2" config user.name 'Test'
git -C "$repo2" config user.email 'test@test.com'
git -C "$repo" checkout -q -b branch-a
echo "a" > "$repo/conflict.txt"
git -C "$repo" add conflict.txt
git -C "$repo" commit -q -m "branch a"
git -C "$repo" checkout -q -
git -C "$repo" checkout -q -b branch-b
echo "b" > "$repo/conflict.txt"
git -C "$repo" add conflict.txt
git -C "$repo" commit -q -m "branch b"
git -C "$repo" merge branch-a 2>/dev/null
_gitstatus_git_query "$repo"
_assert "Merge action detected" "merge" "$VCS_STATUS_ACTION"

# Test 10: Conflicted file count
_assert "Has conflicted" "1" "$VCS_STATUS_HAS_CONFLICTED"

# Cleanup
git -C "$repo" merge --abort 2>/dev/null

print ""
if (( failed == 0 )); then
  print "\e[32mAll $passed tests passed\e[0m"
else
  print "\e[31m$failed failed\e[0m, \e[32m$passed passed\e[0m"
fi
return $failed
