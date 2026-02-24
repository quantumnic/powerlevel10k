#!/usr/bin/env zsh
#
# gitstatus-pure.plugin.zsh — Pure-zsh gitstatus implementation
#
# Provides the same API as gitstatus but uses pure zsh/git commands instead of gitstatusd.
# This is slower but works everywhere git is installed, without compiling gitstatusd.
#
# API compatibility:
#   gitstatus_start NAME [OPTIONS]
#   gitstatus_query [OPTIONS] NAME
#   gitstatus_stop NAME
#   gitstatus_check NAME
#
# All VCS_STATUS_* variables match gitstatusd output exactly.

# Note: Removed interactive check to allow testing in non-interactive shells

# Set required options
setopt no_aliases no_sh_glob brace_expand extended_glob

autoload -Uz add-zsh-hook        || return
zmodload zsh/datetime zsh/system || return

typeset -g _gitstatus_pure_plugin_dir"${1:-}"="${${(%):-%x}:A:h}"

# Global state tracking
typeset -gA _GITSTATUS_PURE_STATE          # name -> 0|1|2 (stopped|starting|started)
typeset -gA _GITSTATUS_PURE_DIRTY_MAX_INDEX_SIZE  # name -> size limit
typeset -gA _GITSTATUS_PURE_OPTIONS        # name -> options string
typeset -gA _GITSTATUS_PURE_ASYNC_JOBS     # name -> async job info

# Initialize async worker if available
if ! whence async_start_worker &>/dev/null; then
  # Load async if available, otherwise disable async support
  if [[ -f "${_gitstatus_pure_plugin_dir}/async.zsh" ]] || whence async &>/dev/null; then
    autoload -Uz async || true
  fi
fi

# Core git status query function - populates all VCS_STATUS_* variables
_gitstatus_pure_query_sync() {
  emulate zsh
  setopt extended_glob no_nomatch no_aliases

  local dir="${1:-.}"
  local -i dirty_max_index_size="${2:--1}"
  local -i skip_dirty="${3:-0}"

  # Reset all VCS_STATUS variables to match gitstatusd behavior exactly
  # Use global assignment to ensure variables are visible outside function
  VCS_STATUS_RESULT=''
  VCS_STATUS_WORKDIR=''
  VCS_STATUS_COMMIT=''
  VCS_STATUS_COMMIT_ENCODING=''
  VCS_STATUS_COMMIT_SUMMARY=''
  VCS_STATUS_LOCAL_BRANCH=''
  VCS_STATUS_REMOTE_NAME=''
  VCS_STATUS_REMOTE_BRANCH=''
  VCS_STATUS_REMOTE_URL=''
  VCS_STATUS_ACTION=''
  VCS_STATUS_INDEX_SIZE=0
  VCS_STATUS_NUM_STAGED=0
  VCS_STATUS_NUM_STAGED_NEW=0
  VCS_STATUS_NUM_STAGED_DELETED=0
  VCS_STATUS_NUM_UNSTAGED=0
  VCS_STATUS_NUM_UNSTAGED_DELETED=0
  VCS_STATUS_NUM_CONFLICTED=0
  VCS_STATUS_NUM_UNTRACKED=0
  VCS_STATUS_NUM_SKIP_WORKTREE=0
  VCS_STATUS_NUM_ASSUME_UNCHANGED=0
  VCS_STATUS_HAS_STAGED=0
  VCS_STATUS_HAS_UNSTAGED=0
  VCS_STATUS_HAS_CONFLICTED=0
  VCS_STATUS_HAS_UNTRACKED=0
  VCS_STATUS_COMMITS_AHEAD=0
  VCS_STATUS_COMMITS_BEHIND=0
  VCS_STATUS_PUSH_COMMITS_AHEAD=0
  VCS_STATUS_PUSH_COMMITS_BEHIND=0
  VCS_STATUS_PUSH_REMOTE_NAME=''
  VCS_STATUS_PUSH_REMOTE_URL=''
  VCS_STATUS_STASHES=0
  VCS_STATUS_TAG=''

  # Check if this is a git repo
  local toplevel
  toplevel=$(command git -C "$dir" rev-parse --show-toplevel 2>/dev/null) || {
    VCS_STATUS_RESULT='norepo-sync'
    return 0
  }
  
  VCS_STATUS_WORKDIR="$toplevel"
  VCS_STATUS_RESULT='ok-sync'

  # Get git directory for action detection
  local git_dir
  git_dir=$(command git -C "$dir" rev-parse --absolute-git-dir 2>/dev/null)

  # HEAD commit
  VCS_STATUS_COMMIT=$(command git -C "$dir" rev-parse HEAD 2>/dev/null) || VCS_STATUS_COMMIT=''

  # Commit summary and encoding (only if HEAD exists)
  if [[ -n $VCS_STATUS_COMMIT ]]; then
    VCS_STATUS_COMMIT_SUMMARY=$(command git -C "$dir" log -1 --format=%s 2>/dev/null) || VCS_STATUS_COMMIT_SUMMARY=''
    local enc
    enc=$(command git -C "$dir" log -1 --format=%e 2>/dev/null)
    [[ $enc != (|UTF-8|utf-8) ]] && VCS_STATUS_COMMIT_ENCODING="$enc"
  fi

  # Branch information
  local head_ref
  head_ref=$(command git -C "$dir" symbolic-ref HEAD 2>/dev/null)
  if [[ -n $head_ref ]]; then
    VCS_STATUS_LOCAL_BRANCH="${head_ref#refs/heads/}"
    
    # Upstream tracking
    local upstream
    upstream=$(command git -C "$dir" for-each-ref --format='%(upstream:short)' "refs/heads/$VCS_STATUS_LOCAL_BRANCH" 2>/dev/null)
    if [[ -n $upstream ]]; then
      VCS_STATUS_REMOTE_NAME="${upstream%%/*}"
      VCS_STATUS_REMOTE_BRANCH="${upstream#*/}"
      VCS_STATUS_REMOTE_URL=$(command git -C "$dir" remote get-url "$VCS_STATUS_REMOTE_NAME" 2>/dev/null) || VCS_STATUS_REMOTE_URL=''

      # Ahead/behind commits
      local ahead_behind
      ahead_behind=$(command git -C "$dir" rev-list --left-right --count HEAD...@{upstream} 2>/dev/null)
      if [[ $ahead_behind == (#b)([0-9]##)[[:space:]]([0-9]##) ]]; then
        VCS_STATUS_COMMITS_AHEAD=$match[1]
        VCS_STATUS_COMMITS_BEHIND=$match[2]
      fi
    fi

    # Push remote (may be different from upstream)
    local push_remote_name
    push_remote_name=$(command git -C "$dir" config "branch.$VCS_STATUS_LOCAL_BRANCH.pushRemote" 2>/dev/null)
    if [[ -z $push_remote_name ]]; then
      push_remote_name=$(command git -C "$dir" config remote.pushDefault 2>/dev/null)
    fi
    if [[ -z $push_remote_name && -n $VCS_STATUS_REMOTE_NAME ]]; then
      push_remote_name="$VCS_STATUS_REMOTE_NAME"
    fi

    if [[ -n $push_remote_name ]]; then
      VCS_STATUS_PUSH_REMOTE_NAME="$push_remote_name"
      VCS_STATUS_PUSH_REMOTE_URL=$(command git -C "$dir" remote get-url "$push_remote_name" 2>/dev/null) || VCS_STATUS_PUSH_REMOTE_URL=''
      
      # Push ahead/behind
      local push_ref="refs/remotes/$push_remote_name/$VCS_STATUS_LOCAL_BRANCH"
      if command git -C "$dir" show-ref --verify --quiet "$push_ref" 2>/dev/null; then
        local push_ahead_behind
        push_ahead_behind=$(command git -C "$dir" rev-list --left-right --count "HEAD...$push_ref" 2>/dev/null)
        if [[ $push_ahead_behind == (#b)([0-9]##)[[:space:]]([0-9]##) ]]; then
          VCS_STATUS_PUSH_COMMITS_AHEAD=$match[1]
          VCS_STATUS_PUSH_COMMITS_BEHIND=$match[2]
        fi
      fi
    fi
  fi

  # Action detection (rebase, merge, cherry-pick, etc.)
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

  # Tag at HEAD
  VCS_STATUS_TAG=$(command git -C "$dir" describe --tags --exact-match HEAD 2>/dev/null) || VCS_STATUS_TAG=''

  # Stashes count
  local stash_count
  stash_count=$(command git -C "$dir" stash list 2>/dev/null | wc -l)
  VCS_STATUS_STASHES=$((stash_count + 0))  # Force numeric conversion

  # Index size (number of tracked files)
  local index_size
  index_size=$(command git -C "$dir" ls-files 2>/dev/null | wc -l)
  VCS_STATUS_INDEX_SIZE=$((index_size + 0))  # Force numeric conversion

  # Check dirty_max_index_size limit
  if (( dirty_max_index_size >= 0 && VCS_STATUS_INDEX_SIZE > dirty_max_index_size )); then
    skip_dirty=1
  fi

  if (( skip_dirty )); then
    # When skipping dirty checks, set counts to -1 as per gitstatusd behavior
    VCS_STATUS_HAS_STAGED=-1
    VCS_STATUS_HAS_UNSTAGED=-1
    VCS_STATUS_HAS_CONFLICTED=-1
    VCS_STATUS_HAS_UNTRACKED=-1
  else
    # Parse git status for staged/unstaged/conflicted/untracked files
    local status_output
    local ignore_submodules=${POWERLEVEL9K_VCS_IGNORE_SUBMODULES:-dirty}
    status_output=$(command git -C "$dir" status --porcelain=v1 -uall --ignore-submodules=$ignore_submodules 2>/dev/null)
    
    local line x y
    while IFS= read -r line; do
      [[ -n $line ]] || continue
      x="${line[1]}"
      y="${line[2]}"

      # Conflicted files (both sides modified, added by us/them, deleted by us/them)
      if [[ $x == 'U' || $y == 'U' || ($x == 'A' && $y == 'A') || ($x == 'D' && $y == 'D') ]]; then
        (( ++VCS_STATUS_NUM_CONFLICTED ))
        continue
      fi

      # Staged files (index changes)
      if [[ $x == [MADRC] ]]; then
        (( ++VCS_STATUS_NUM_STAGED ))
        [[ $x == 'A' ]] && (( ++VCS_STATUS_NUM_STAGED_NEW ))
        [[ $x == 'D' ]] && (( ++VCS_STATUS_NUM_STAGED_DELETED ))
      fi

      # Unstaged files (working tree changes)
      if [[ $y == [MD] ]]; then
        (( ++VCS_STATUS_NUM_UNSTAGED ))
        [[ $y == 'D' ]] && (( ++VCS_STATUS_NUM_UNSTAGED_DELETED ))
      fi

      # Untracked files
      if [[ $x == '?' ]]; then
        (( ++VCS_STATUS_NUM_UNTRACKED ))
      fi
    done <<< "$status_output"

    # Set HAS_* boolean flags
    (( VCS_STATUS_NUM_STAGED > 0 ))     && VCS_STATUS_HAS_STAGED=1
    (( VCS_STATUS_NUM_UNSTAGED > 0 ))   && VCS_STATUS_HAS_UNSTAGED=1
    (( VCS_STATUS_NUM_CONFLICTED > 0 )) && VCS_STATUS_HAS_CONFLICTED=1
    (( VCS_STATUS_NUM_UNTRACKED > 0 ))  && VCS_STATUS_HAS_UNTRACKED=1
  fi

  # Assume-unchanged and skip-worktree files
  local ls_output
  ls_output=$(command git -C "$dir" ls-files -v 2>/dev/null)
  
  local ls_line flag
  while IFS= read -r ls_line; do
    [[ -n $ls_line ]] || continue
    flag="${ls_line[1]}"
    case "$flag" in
      h) (( ++VCS_STATUS_NUM_ASSUME_UNCHANGED )) ;;
      S) (( ++VCS_STATUS_NUM_SKIP_WORKTREE )) ;;
    esac
  done <<< "$ls_output"

  return 0
}

# Async callback wrapper for background queries
_gitstatus_pure_async_callback() {
  emulate zsh
  local name="$1" callback="$2" dir="$3" dirty_max_index_size="$4" skip_dirty="$5"
  
  # Run the sync query
  _gitstatus_pure_query_sync "$dir" "$dirty_max_index_size" "$skip_dirty"
  
  # Update result to indicate async completion
  case $VCS_STATUS_RESULT in
    ok-sync)      VCS_STATUS_RESULT=ok-async ;;
    norepo-sync)  VCS_STATUS_RESULT=norepo-async ;;
  esac
  
  # Call the user callback if provided
  if [[ -n $callback ]] && (( $+functions[$callback] )); then
    $callback
  fi
}

# Start gitstatus for a named instance
# Usage: gitstatus_start [-t TIMEOUT] [-a] [-m DIRTY_MAX_INDEX_SIZE] [-s] [-u] [-c] [-d] [-e] [-U] [-W] [-D] NAME
function gitstatus_start"${1:-}"() {
  emulate -L zsh -o no_aliases -o extended_glob -o typeset_silent || return

  local opt OPTARG
  local -i OPTIND
  local -F timeout=5
  local -i async=0
  local -i dirty_max_index_size=-1
  local options=""

  while getopts ":t:s:u:c:d:m:eaUWD" opt; do
    case $opt in
      a)  async=1 ;;
      +a) async=0 ;;
      t)
        if [[ $OPTARG != (|+)<->(|.<->)(|[eE](|-|+)<->) ]] || (( ${timeout::=OPTARG} <= 0 )); then
          print -ru2 -- "gitstatus_start: invalid -t argument: $OPTARG"
          return 1
        fi
        options+=" -t $OPTARG"
      ;;
      s|u|c|d|m)
        if [[ $OPTARG != (|-|+)<-> ]]; then
          print -ru2 -- "gitstatus_start: invalid -$opt argument: $OPTARG"
          return 1
        fi
        options+=" -$opt $OPTARG"
        [[ $opt == m ]] && dirty_max_index_size=$OPTARG
      ;;
      e|U|W|D)    options+=" -$opt" ;;
      +(e|U|W|D)) options="${options// -$opt/}" ;;
      \?) print -ru2 -- "gitstatus_start: invalid option: $OPTARG"; return 1 ;;
      :)  print -ru2 -- "gitstatus_start: missing required argument: $OPTARG"; return 1 ;;
      *)  print -ru2 -- "gitstatus_start: invalid option: $opt"; return 1 ;;
    esac
  done

  if (( OPTIND != ARGC )); then
    print -ru2 -- "gitstatus_start: exactly one positional argument is required"
    return 1
  fi

  local name=$*[OPTIND]
  if [[ $name != [[:IDENT:]]## ]]; then
    print -ru2 -- "gitstatus_start: invalid positional argument: $name"
    return 1
  fi

  # Check if already started
  if (( ${_GITSTATUS_PURE_STATE[$name]:-0} )); then
    (( async )) && return 0
    (( _GITSTATUS_PURE_STATE[$name] == 2 )) && return 0
  fi

  # Initialize state
  _GITSTATUS_PURE_STATE[$name]=2  # Started
  _GITSTATUS_PURE_DIRTY_MAX_INDEX_SIZE[$name]=$dirty_max_index_size
  _GITSTATUS_PURE_OPTIONS[$name]="$options"

  # Initialize async worker if requested and available
  if (( async )) && (( $+functions[async_start_worker] )); then
    async_start_worker "gitstatus_pure_$name" -n
    async_register_callback "gitstatus_pure_$name" _gitstatus_pure_async_callback
  fi

  return 0
}

# Query git status for a named instance
# Usage: gitstatus_query [-d DIR] [-t TIMEOUT] [-c CALLBACK] [-p] NAME
function gitstatus_query"${1:-}"() {
  emulate -L zsh -o no_aliases -o extended_glob -o typeset_silent

  unset VCS_STATUS_RESULT

  local opt dir callback OPTARG
  local -i no_diff=0 OPTIND
  local -F timeout=-1
  
  while getopts ":d:c:t:p" opt; do
    case $opt in
      +p) no_diff=0 ;;
      p)  no_diff=1 ;;
      d)  dir=$OPTARG ;;
      c)  callback=$OPTARG ;;
      t)
        if [[ $OPTARG != (|+|-)<->(|.<->)(|[eE](|-|+)<->) ]]; then
          print -ru2 -- "gitstatus_query: invalid -t argument: $OPTARG"
          return 1
        fi
        timeout=$OPTARG
      ;;
      \?) print -ru2 -- "gitstatus_query: invalid option: $OPTARG"; return 1 ;;
      :)  print -ru2 -- "gitstatus_query: missing required argument: $OPTARG"; return 1 ;;
      *)  print -ru2 -- "gitstatus_query: invalid option: $opt"; return 1 ;;
    esac
  done

  if (( OPTIND != ARGC )); then
    print -ru2 -- "gitstatus_query: exactly one positional argument is required"
    return 1
  fi

  local name=$*[OPTIND]
  if [[ $name != [[:IDENT:]]## ]]; then
    print -ru2 -- "gitstatus_query: invalid positional argument: $name"
    return 1
  fi

  # Check if started
  (( _GITSTATUS_PURE_STATE[$name] == 2 )) || return 1

  # Set directory
  if [[ -z $dir ]]; then
    if [[ -z $GIT_DIR ]]; then
      dir="$PWD"
    else
      dir="$GIT_DIR"
    fi
  else
    if [[ $dir != /* ]]; then
      if [[ $PWD == /* && $PWD -ef . ]]; then
        dir="$PWD/$dir"
      else
        dir="${dir:a}"
      fi
    fi
  fi

  local dirty_max_index_size=${_GITSTATUS_PURE_DIRTY_MAX_INDEX_SIZE[$name]:-(-1)}
  
  # If callback is specified and async is available, try async query
  if [[ -n $callback ]] && (( $+functions[async_job] )); then
    # Start async job
    async_job "gitstatus_pure_$name" _gitstatus_pure_async_callback "$name" "$callback" "$dir" "$dirty_max_index_size" "$no_diff"
    
    # Set timeout result
    VCS_STATUS_RESULT=tout
    return 0
  fi

  # Synchronous query
  _gitstatus_pure_query_sync "$dir" "$dirty_max_index_size" "$no_diff"
  return 0
}

# Stop gitstatus for a named instance
function gitstatus_stop"${1:-}"() {
  emulate -L zsh -o no_aliases -o extended_glob -o typeset_silent

  if (( ARGC != 1 )); then
    print -ru2 -- "gitstatus_stop: exactly one positional argument is required"
    return 1
  fi

  local name=$1
  if [[ $name != [[:IDENT:]]## ]]; then
    print -ru2 -- "gitstatus_stop: invalid positional argument: $name"
    return 1
  fi

  # Clean up state
  unset "_GITSTATUS_PURE_STATE[$name]"
  unset "_GITSTATUS_PURE_DIRTY_MAX_INDEX_SIZE[$name]"
  unset "_GITSTATUS_PURE_OPTIONS[$name]"

  # Stop async worker if it exists
  if (( $+functions[async_stop_worker] )); then
    async_stop_worker "gitstatus_pure_$name" 2>/dev/null || true
  fi

  return 0
}

# Check if gitstatus is running for a named instance
function gitstatus_check"${1:-}"() {
  emulate -L zsh -o no_aliases -o extended_glob -o typeset_silent

  if (( ARGC != 1 )); then
    print -ru2 -- "gitstatus_check: exactly one positional argument is required"
    return 1
  fi

  local name=$1
  if [[ $name != [[:IDENT:]]## ]]; then
    print -ru2 -- "gitstatus_check: invalid positional argument: $name"
    return 1
  fi

  (( _GITSTATUS_PURE_STATE[$name] == 2 ))
}

# End of pure gitstatus implementation