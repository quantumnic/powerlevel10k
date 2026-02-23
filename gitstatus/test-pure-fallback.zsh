#!/usr/bin/env zsh
#
# test-pure-fallback.zsh — Test suite for pure-zsh gitstatus fallback
#
# This script thoroughly tests the pure-zsh gitstatus implementation against
# various repository states to ensure compatibility with gitstatusd behavior.
#
# Usage: zsh test-pure-fallback.zsh

# Note: Removed 'set -e' to allow tests to continue on assertion failures

# Color output
if [[ -t 1 ]]; then
  RED=$'\033[31m'
  GREEN=$'\033[32m'
  YELLOW=$'\033[33m'
  BLUE=$'\033[34m'
  RESET=$'\033[0m'
else
  RED= GREEN= YELLOW= BLUE= RESET=
fi

PASSED=0
FAILED=0
TOTAL=0

# Test result tracking
print_test_result() {
  local test_name="$1" expected="$2" actual="$3"
  (( TOTAL++ ))
  
  if [[ "$actual" == "$expected" ]]; then
    print "${GREEN}PASS${RESET} $test_name"
    (( PASSED++ ))
  else
    print "${RED}FAIL${RESET} $test_name"
    print "  Expected: $expected"
    print "  Actual:   $actual"
    (( FAILED++ ))
  fi
}

print_test_summary() {
  print
  print "Test Results: $PASSED passed, $FAILED failed, $TOTAL total"
  if (( FAILED > 0 )); then
    print "${RED}Some tests failed!${RESET}"
    return 1
  else
    print "${GREEN}All tests passed!${RESET}"
    return 0
  fi
}

# Get the directory of this script
test_dir="${${(%):-%x}:A:h}"

# Source the pure implementation
print "${BLUE}Loading gitstatus-pure.plugin.zsh...${RESET}"
source "$test_dir/gitstatus-pure.plugin.zsh" || {
  print "${RED}Failed to load gitstatus-pure.plugin.zsh${RESET}"
  exit 1
}

# Create temporary test directory
TEST_ROOT=$(mktemp -d -t gitstatus-test-XXXXXX)
cleanup() {
  cd /
  rm -rf "$TEST_ROOT" 2>/dev/null || true
}
trap cleanup EXIT

print "${BLUE}Test directory: $TEST_ROOT${RESET}"
cd "$TEST_ROOT"

# Configure git for tests
git config --global user.name "Test User"
git config --global user.email "test@example.com"
git config --global init.defaultBranch main

# Start gitstatus instance
print "${BLUE}Starting gitstatus instance...${RESET}"
gitstatus_start TEST_INSTANCE || {
  print "${RED}Failed to start gitstatus instance${RESET}"
  exit 1
}

# Test 1: Non-git directory
print "${YELLOW}Test 1: Non-git directory${RESET}"
mkdir non-repo && cd non-repo
gitstatus_query -d . TEST_INSTANCE
print_test_result "Non-repo result" "norepo-sync" "$VCS_STATUS_RESULT"
cd ..

# Test 2: Empty git repository
print "${YELLOW}Test 2: Empty git repository${RESET}"
mkdir empty-repo && cd empty-repo
git init
gitstatus_query -d . TEST_INSTANCE
print_test_result "Empty repo result" "ok-sync" "$VCS_STATUS_RESULT"
print_test_result "Empty repo workdir" "${PWD:A}" "${VCS_STATUS_WORKDIR:A}"  # Use :A to resolve symlinks
print_test_result "Empty repo commit" "" "$VCS_STATUS_COMMIT"
print_test_result "Empty repo branch" "main" "$VCS_STATUS_LOCAL_BRANCH"
print_test_result "Empty repo index size" "0" "$VCS_STATUS_INDEX_SIZE"
cd ..

# Test 3: Repository with initial commit
print "${YELLOW}Test 3: Repository with initial commit${RESET}"
mkdir initial-commit && cd initial-commit
git init
echo "Initial content" > README.md
git add README.md
git commit -m "Initial commit"
gitstatus_query -d . TEST_INSTANCE
print_test_result "Initial commit result" "ok-sync" "$VCS_STATUS_RESULT"
print_test_result "Initial commit has commit" "true" "$([[ -n $VCS_STATUS_COMMIT ]] && echo true || echo false)"
print_test_result "Initial commit summary" "Initial commit" "$VCS_STATUS_COMMIT_SUMMARY"
print_test_result "Initial commit index size" "1" "$VCS_STATUS_INDEX_SIZE"
print_test_result "Initial commit staged count" "0" "$VCS_STATUS_NUM_STAGED"
print_test_result "Initial commit unstaged count" "0" "$VCS_STATUS_NUM_UNSTAGED"
print_test_result "Initial commit untracked count" "0" "$VCS_STATUS_NUM_UNTRACKED"
cd ..

# Test 4: Repository with staged files
print "${YELLOW}Test 4: Repository with staged files${RESET}"
mkdir staged-files && cd staged-files
git init
echo "File 1" > file1.txt
git add file1.txt
git commit -m "First commit"
echo "File 2" > file2.txt
echo "File 3" > file3.txt
git add file2.txt file3.txt
gitstatus_query -d . TEST_INSTANCE
print_test_result "Staged files result" "ok-sync" "$VCS_STATUS_RESULT"
print_test_result "Staged files count" "2" "$VCS_STATUS_NUM_STAGED"
print_test_result "Staged files new count" "2" "$VCS_STATUS_NUM_STAGED_NEW"
print_test_result "Has staged flag" "1" "$VCS_STATUS_HAS_STAGED"
cd ..

# Test 5: Repository with unstaged files
print "${YELLOW}Test 5: Repository with unstaged files${RESET}"
mkdir unstaged-files && cd unstaged-files
git init
echo "Original" > file1.txt
git add file1.txt
git commit -m "Initial"
echo "Modified" > file1.txt
echo "New file" > file2.txt
gitstatus_query -d . TEST_INSTANCE
print_test_result "Unstaged files result" "ok-sync" "$VCS_STATUS_RESULT"
print_test_result "Unstaged files count" "1" "$VCS_STATUS_NUM_UNSTAGED"
print_test_result "Untracked files count" "1" "$VCS_STATUS_NUM_UNTRACKED"
print_test_result "Has unstaged flag" "1" "$VCS_STATUS_HAS_UNSTAGED"
print_test_result "Has untracked flag" "1" "$VCS_STATUS_HAS_UNTRACKED"
cd ..

# Test 6: Repository with remote tracking
print "${YELLOW}Test 6: Repository with remote tracking${RESET}"
mkdir remote-repo && cd remote-repo
git init --bare
cd ..
git clone remote-repo tracked-repo
cd tracked-repo
echo "Content" > file.txt
git add file.txt
git commit -m "Add file"
git push origin main
echo "More content" > file2.txt
git add file2.txt
git commit -m "Second commit"
gitstatus_query -d . TEST_INSTANCE
print_test_result "Remote tracking result" "ok-sync" "$VCS_STATUS_RESULT"
print_test_result "Remote name" "origin" "$VCS_STATUS_REMOTE_NAME"
print_test_result "Remote branch" "main" "$VCS_STATUS_REMOTE_BRANCH"
print_test_result "Commits ahead" "1" "$VCS_STATUS_COMMITS_AHEAD"
print_test_result "Commits behind" "0" "$VCS_STATUS_COMMITS_BEHIND"
cd ..

# Test 7: Repository with merge conflict
print "${YELLOW}Test 7: Repository with merge conflict${RESET}"
mkdir conflict-repo && cd conflict-repo
git init
echo "Original line" > conflict.txt
git add conflict.txt
git commit -m "Initial"
git checkout -b feature
echo "Feature change" > conflict.txt
git add conflict.txt
git commit -m "Feature commit"
git checkout main
echo "Main change" > conflict.txt
git add conflict.txt
git commit -m "Main commit"
# Create merge conflict
git merge feature --no-commit --no-ff 2>/dev/null || true
gitstatus_query -d . TEST_INSTANCE
print_test_result "Conflict result" "ok-sync" "$VCS_STATUS_RESULT"
print_test_result "Conflict action" "merge" "$VCS_STATUS_ACTION"
print_test_result "Conflicted count" "1" "$VCS_STATUS_NUM_CONFLICTED"
print_test_result "Has conflicted flag" "1" "$VCS_STATUS_HAS_CONFLICTED"
cd ..

# Test 8: Repository with stashes
print "${YELLOW}Test 8: Repository with stashes${RESET}"
mkdir stash-repo && cd stash-repo
git init
echo "File content" > file.txt
git add file.txt
git commit -m "Initial"
echo "Modified content" > file.txt
git stash push -m "Stash 1"
echo "Another change" > file.txt
git stash push -m "Stash 2"
gitstatus_query -d . TEST_INSTANCE
print_test_result "Stash result" "ok-sync" "$VCS_STATUS_RESULT"
print_test_result "Stash count" "2" "$VCS_STATUS_STASHES"
cd ..

# Test 9: Repository with tags
print "${YELLOW}Test 9: Repository with tags${RESET}"
mkdir tag-repo && cd tag-repo
git init
echo "Tagged content" > file.txt
git add file.txt
git commit -m "Tagged commit"
git tag v1.0.0
gitstatus_query -d . TEST_INSTANCE
print_test_result "Tag result" "ok-sync" "$VCS_STATUS_RESULT"
print_test_result "Tag value" "v1.0.0" "$VCS_STATUS_TAG"
# Add another commit so we're not on the tag
echo "More content" > file2.txt
git add file2.txt
git commit -m "Post-tag commit"
gitstatus_query -d . TEST_INSTANCE
print_test_result "Non-tagged commit tag" "" "$VCS_STATUS_TAG"
cd ..

# Test 10: Detached HEAD
print "${YELLOW}Test 10: Detached HEAD${RESET}"
mkdir detached-repo && cd detached-repo
git init
echo "Content 1" > file.txt
git add file.txt
git commit -m "Commit 1"
echo "Content 2" > file.txt
git add file.txt
git commit -m "Commit 2"
# Detach HEAD to first commit
first_commit=$(git rev-list --reverse HEAD | head -1)
git checkout "$first_commit" 2>/dev/null
gitstatus_query -d . TEST_INSTANCE
print_test_result "Detached HEAD result" "ok-sync" "$VCS_STATUS_RESULT"
print_test_result "Detached HEAD branch" "" "$VCS_STATUS_LOCAL_BRANCH"
print_test_result "Detached HEAD commit" "$first_commit" "$VCS_STATUS_COMMIT"
cd ..

# Test 11: Skip-worktree and assume-unchanged
print "${YELLOW}Test 11: Skip-worktree and assume-unchanged files${RESET}"
mkdir skip-assume-repo && cd skip-assume-repo
git init
echo "Content 1" > skip.txt
echo "Content 2" > assume.txt
git add skip.txt assume.txt
git commit -m "Initial files"
git update-index --skip-worktree skip.txt
git update-index --assume-unchanged assume.txt
gitstatus_query -d . TEST_INSTANCE
print_test_result "Skip-worktree result" "ok-sync" "$VCS_STATUS_RESULT"
print_test_result "Skip-worktree count" "1" "$VCS_STATUS_NUM_SKIP_WORKTREE"
print_test_result "Assume-unchanged count" "1" "$VCS_STATUS_NUM_ASSUME_UNCHANGED"
cd ..

# Test 12: Dirty max index size limit
print "${YELLOW}Test 12: Dirty max index size limit${RESET}"
gitstatus_stop TEST_INSTANCE
gitstatus_start -m 2 TEST_LIMITED  # Max 2 files before skipping dirty checks
mkdir large-repo && cd large-repo
git init
for i in {1..5}; do
  echo "File $i" > "file$i.txt"
  git add "file$i.txt"
done
git commit -m "Many files"
echo "Modified" > file1.txt
echo "Untracked" > untracked.txt
gitstatus_query -d . TEST_LIMITED
print_test_result "Large repo result" "ok-sync" "$VCS_STATUS_RESULT"
print_test_result "Large repo index size" "5" "$VCS_STATUS_INDEX_SIZE"
print_test_result "Large repo dirty limit" "-1" "$VCS_STATUS_HAS_UNSTAGED"  # Should be -1 due to limit
print_test_result "Large repo untracked limit" "-1" "$VCS_STATUS_HAS_UNTRACKED"  # Should be -1 due to limit
cd ..

# Test 13: Async functionality (if available)
print "${YELLOW}Test 13: Async functionality${RESET}"
callback_called=""
test_callback() {
  callback_called="yes"
}

cd initial-commit  # Use existing repo
if (( $+functions[async_job] )); then
  gitstatus_query -c test_callback -d . TEST_INSTANCE
  print_test_result "Async result" "tout" "$VCS_STATUS_RESULT"
  # Wait a moment for callback
  sleep 0.1
  print_test_result "Async callback called" "yes" "$callback_called"
else
  print "${YELLOW}Async not available, skipping async tests${RESET}"
fi
cd ..

# Test 14: Rebase action detection
print "${YELLOW}Test 14: Rebase action detection${RESET}"
mkdir rebase-repo && cd rebase-repo
git init
echo "Base content" > file.txt
git add file.txt
git commit -m "Base commit"
git checkout -b feature
echo "Feature content" > file.txt
git add file.txt
git commit -m "Feature commit"
git checkout main
echo "Main content" > file.txt  # Change same file to create conflict
git add file.txt
git commit -m "Main commit"
# Try to force a conflict by making the changes more incompatible
echo "Completely different content" > file.txt
git add file.txt
git commit --amend --no-edit
# Start rebase (should conflict)
if git rebase feature >/dev/null 2>&1; then
  print "${YELLOW}INFO${RESET} Rebase succeeded without conflict, skipping rebase action test"
  (( TOTAL += 2 ))
else
  gitstatus_query -d . TEST_INSTANCE
  print_test_result "Rebase result" "ok-sync" "$VCS_STATUS_RESULT"
  print_test_result "Rebase action" "rebase" "$VCS_STATUS_ACTION"
fi
cd ..

# Test 15: Cherry-pick action detection  
print "${YELLOW}Test 15: Cherry-pick action detection${RESET}"
mkdir cherry-repo && cd cherry-repo
git init
echo "Base" > file.txt
git add file.txt
git commit -m "Base"
git checkout -b feature
echo "Feature change" > file.txt  # Modify same file to create conflict
git add file.txt
git commit -m "Feature commit"
git checkout main
# Create a more substantial conflict
echo "Completely different main content" > file.txt
git add file.txt
git commit -m "Main change"
# Cherry-pick that should conflict
if git cherry-pick feature >/dev/null 2>&1; then
  print "${YELLOW}INFO${RESET} Cherry-pick succeeded without conflict, skipping cherry-pick action test"
  (( TOTAL += 2 ))
else
  gitstatus_query -d . TEST_INSTANCE
  print_test_result "Cherry-pick result" "ok-sync" "$VCS_STATUS_RESULT"
  print_test_result "Cherry-pick action" "cherry-pick" "$VCS_STATUS_ACTION"
fi
cd ..

# Clean up
gitstatus_stop TEST_INSTANCE 2>/dev/null || true
gitstatus_stop TEST_LIMITED 2>/dev/null || true

# Print final results
print_test_summary