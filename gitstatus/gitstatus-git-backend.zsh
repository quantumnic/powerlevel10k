#!/usr/bin/env zsh
#
# gitstatus-git-backend.zsh — Pure git fallback for gitstatus
#
# Provides VCS_STATUS_* variables using plain `git` commands instead of gitstatusd.
# This is slower but works everywhere git is installed, without compiling gitstatusd.
#
# Usage:
#   source gitstatus-git-backend.zsh
#   _gitstatus_git_query /path/to/repo
#   typeset -m 'VCS_STATUS_*'
#
# Set GITSTATUS_BACKEND=git to activate this in gitstatus_query.

# Query git status for a directory using plain git commands.
# Sets all VCS_STATUS_* variables matching the gitstatusd API.
_gitstatus_git_query() {
  emulate -L zsh
  setopt extended_glob no_nomatch

  local dir="${1:-.}"

  # Reset all VCS_STATUS variables
  typeset -g  VCS_STATUS_RESULT=''
  typeset -g  VCS_STATUS_WORKDIR=''
  typeset -g  VCS_STATUS_COMMIT=''
  typeset -g  VCS_STATUS_COMMIT_ENCODING=''
  typeset -g  VCS_STATUS_COMMIT_SUMMARY=''
  typeset -g  VCS_STATUS_LOCAL_BRANCH=''
  typeset -g  VCS_STATUS_REMOTE_NAME=''
  typeset -g  VCS_STATUS_REMOTE_BRANCH=''
  typeset -g  VCS_STATUS_REMOTE_URL=''
  typeset -g  VCS_STATUS_ACTION=''
  typeset -gi VCS_STATUS_INDEX_SIZE=0
  typeset -gi VCS_STATUS_NUM_STAGED=0
  typeset -gi VCS_STATUS_NUM_STAGED_NEW=0
  typeset -gi VCS_STATUS_NUM_STAGED_DELETED=0
  typeset -gi VCS_STATUS_NUM_UNSTAGED=0
  typeset -gi VCS_STATUS_NUM_UNSTAGED_DELETED=0
  typeset -gi VCS_STATUS_NUM_CONFLICTED=0
  typeset -gi VCS_STATUS_NUM_UNTRACKED=0
  typeset -gi VCS_STATUS_NUM_SKIP_WORKTREE=0
  typeset -gi VCS_STATUS_NUM_ASSUME_UNCHANGED=0
  typeset -gi VCS_STATUS_HAS_STAGED=0
  typeset -gi VCS_STATUS_HAS_UNSTAGED=0
  typeset -gi VCS_STATUS_HAS_CONFLICTED=0
  typeset -gi VCS_STATUS_HAS_UNTRACKED=0
  typeset -gi VCS_STATUS_COMMITS_AHEAD=0
  typeset -gi VCS_STATUS_COMMITS_BEHIND=0
  typeset -gi VCS_STATUS_PUSH_COMMITS_AHEAD=0
  typeset -gi VCS_STATUS_PUSH_COMMITS_BEHIND=0
  typeset -g  VCS_STATUS_PUSH_REMOTE_NAME=''
  typeset -g  VCS_STATUS_PUSH_REMOTE_URL=''
  typeset -gi VCS_STATUS_STASHES=0
  typeset -g  VCS_STATUS_TAG=''

  # Check if this is a git repo
  local toplevel
  toplevel=$(git -C "$dir" rev-parse --show-toplevel 2>/dev/null) || {
    VCS_STATUS_RESULT='norepo-sync'
    return 0
  }
  VCS_STATUS_WORKDIR="$toplevel"
  VCS_STATUS_RESULT='ok-sync'

  # HEAD commit
  VCS_STATUS_COMMIT=$(git -C "$dir" rev-parse HEAD 2>/dev/null)

  # Commit summary and encoding
  if [[ -n $VCS_STATUS_COMMIT ]]; then
    VCS_STATUS_COMMIT_SUMMARY=$(git -C "$dir" log -1 --format=%s 2>/dev/null)
    local enc
    enc=$(git -C "$dir" log -1 --format=%e 2>/dev/null)
    [[ $enc != (|UTF-8|utf-8) ]] && VCS_STATUS_COMMIT_ENCODING="$enc"
  fi

  # Branch
  local head_ref
  head_ref=$(git -C "$dir" symbolic-ref HEAD 2>/dev/null)
  if [[ -n $head_ref ]]; then
    VCS_STATUS_LOCAL_BRANCH="${head_ref#refs/heads/}"
  fi

  # Upstream tracking
  if [[ -n $VCS_STATUS_LOCAL_BRANCH ]]; then
    local upstream
    upstream=$(git -C "$dir" rev-parse --abbrev-ref '@{upstream}' 2>/dev/null)
    if [[ -n $upstream ]]; then
      VCS_STATUS_REMOTE_NAME="${upstream%%/*}"
      VCS_STATUS_REMOTE_BRANCH="${upstream#*/}"
      VCS_STATUS_REMOTE_URL=$(git -C "$dir" remote get-url "$VCS_STATUS_REMOTE_NAME" 2>/dev/null)

      # Ahead/behind
      local ab
      ab=$(git -C "$dir" rev-list --left-right --count HEAD...@{upstream} 2>/dev/null)
      if [[ $ab == (#b)([0-9]##)[[:space:]]([0-9]##) ]]; then
        VCS_STATUS_COMMITS_AHEAD=$match[1]
        VCS_STATUS_COMMITS_BEHIND=$match[2]
      fi
    fi

    # Push remote
    local push_remote
    push_remote=$(git -C "$dir" rev-parse --abbrev-ref '@{push}' 2>/dev/null)
    if [[ -n $push_remote ]]; then
      VCS_STATUS_PUSH_REMOTE_NAME="${push_remote%%/*}"
      VCS_STATUS_PUSH_REMOTE_URL=$(git -C "$dir" remote get-url "$VCS_STATUS_PUSH_REMOTE_NAME" 2>/dev/null)

      local push_ab
      push_ab=$(git -C "$dir" rev-list --left-right --count HEAD...@{push} 2>/dev/null)
      if [[ $push_ab == (#b)([0-9]##)[[:space:]]([0-9]##) ]]; then
        VCS_STATUS_PUSH_COMMITS_AHEAD=$match[1]
        VCS_STATUS_PUSH_COMMITS_BEHIND=$match[2]
      fi
    fi
  fi

  # Action (rebase, merge, cherry-pick, etc.)
  local git_dir
  git_dir=$(git -C "$dir" rev-parse --absolute-git-dir 2>/dev/null)
  if [[ -n $git_dir ]]; then
    if [[ -d "$git_dir/rebase-merge" ]]; then
      VCS_STATUS_ACTION='rebase'
    elif [[ -d "$git_dir/rebase-apply" ]]; then
      if [[ -f "$git_dir/rebase-apply/rebasing" ]]; then
        VCS_STATUS_ACTION='rebase'
      elif [[ -f "$git_dir/rebase-apply/applying" ]]; then
        VCS_STATUS_ACTION='am'
      else
        VCS_STATUS_ACTION='rebase/am'
      fi
    elif [[ -f "$git_dir/MERGE_HEAD" ]]; then
      VCS_STATUS_ACTION='merge'
    elif [[ -f "$git_dir/CHERRY_PICK_HEAD" ]]; then
      VCS_STATUS_ACTION='cherry-pick'
    elif [[ -f "$git_dir/REVERT_HEAD" ]]; then
      VCS_STATUS_ACTION='revert'
    elif [[ -f "$git_dir/BISECT_LOG" ]]; then
      VCS_STATUS_ACTION='bisect'
    fi
  fi

  # Tag
  VCS_STATUS_TAG=$(git -C "$dir" describe --tags --exact-match HEAD 2>/dev/null)

  # Stashes
  local stash_count
  stash_count=$(git -C "$dir" stash list 2>/dev/null | wc -l)
  VCS_STATUS_STASHES=${stash_count##[[:space:]]#}

  # Index size (number of tracked files)
  VCS_STATUS_INDEX_SIZE=$(git -C "$dir" ls-files 2>/dev/null | wc -l)
  VCS_STATUS_INDEX_SIZE=${VCS_STATUS_INDEX_SIZE##[[:space:]]#}

  # Status: staged, unstaged, untracked, conflicted
  # Use --porcelain=v1 for stable output
  local line
  git -C "$dir" status --porcelain=v1 -uall 2>/dev/null | while IFS= read -r line; do
    local x="${line[1]}" y="${line[2]}"

    # Conflicted
    if [[ $x == 'U' || $y == 'U' || ($x == 'A' && $y == 'A') || ($x == 'D' && $y == 'D') ]]; then
      (( VCS_STATUS_NUM_CONFLICTED++ ))
      continue
    fi

    # Staged
    if [[ $x == [MADRC] ]]; then
      (( VCS_STATUS_NUM_STAGED++ ))
      [[ $x == 'A' ]] && (( VCS_STATUS_NUM_STAGED_NEW++ ))
      [[ $x == 'D' ]] && (( VCS_STATUS_NUM_STAGED_DELETED++ ))
    fi

    # Unstaged
    if [[ $y == [MD] ]]; then
      (( VCS_STATUS_NUM_UNSTAGED++ ))
      [[ $y == 'D' ]] && (( VCS_STATUS_NUM_UNSTAGED_DELETED++ ))
    fi

    # Untracked
    if [[ $x == '?' ]]; then
      (( VCS_STATUS_NUM_UNTRACKED++ ))
    fi
  done

  # Set HAS_* boolean flags
  (( VCS_STATUS_NUM_STAGED ))     && VCS_STATUS_HAS_STAGED=1
  (( VCS_STATUS_NUM_UNSTAGED ))   && VCS_STATUS_HAS_UNSTAGED=1
  (( VCS_STATUS_NUM_CONFLICTED )) && VCS_STATUS_HAS_CONFLICTED=1
  (( VCS_STATUS_NUM_UNTRACKED ))  && VCS_STATUS_HAS_UNTRACKED=1

  # Assume-unchanged and skip-worktree
  local au_line
  git -C "$dir" ls-files -v 2>/dev/null | while IFS= read -r au_line; do
    case "${au_line[1]}" in
      h) (( VCS_STATUS_NUM_ASSUME_UNCHANGED++ )) ;;
      S) (( VCS_STATUS_NUM_SKIP_WORKTREE++ )) ;;
    esac
  done

  return 0
}
