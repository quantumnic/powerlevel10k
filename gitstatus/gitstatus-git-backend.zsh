#!/usr/bin/env zsh
#
# gitstatus-git-backend.zsh — Pure git fallback integration for gitstatus
#
# This file provides integration hooks for using the pure-zsh gitstatus fallback
# instead of the compiled gitstatusd daemon. It's designed to be sourced by
# gitstatus.plugin.zsh when fallback mode is needed.
#
# Usage:
#   export GITSTATUS_BACKEND=git  # Enable pure-git backend
#   source gitstatus.plugin.zsh   # Will use this fallback automatically
#
# Or manually:
#   source gitstatus-git-backend.zsh
#   _gitstatus_git_query /path/to/repo
#   typeset -m 'VCS_STATUS_*'

# Load the pure implementation if not already loaded
if ! (( $+functions[_gitstatus_pure_query_sync] )); then
  local backend_dir="${${(%):-%x}:A:h}"
  if [[ -f "$backend_dir/gitstatus-pure.plugin.zsh" ]]; then
    source "$backend_dir/gitstatus-pure.plugin.zsh"
  else
    print -ru2 "gitstatus-git-backend: cannot find gitstatus-pure.plugin.zsh"
    return 1
  fi
fi

# Compatibility wrapper for the old API
_gitstatus_git_query() {
  emulate -L zsh
  local dir="${1:-.}"
  local -i dirty_max_index_size="${2:--1}"
  local -i skip_dirty="${3:-0}"
  
  _gitstatus_pure_query_sync "$dir" "$dirty_max_index_size" "$skip_dirty"
}

# Detection function - check if we should use pure backend
_gitstatus_should_use_pure_backend() {
  # Use pure backend if:
  # 1. Explicitly requested via GITSTATUS_BACKEND=git
  # 2. gitstatusd binary is not available
  # 3. gitstatusd compilation failed
  
  if [[ $GITSTATUS_BACKEND == git ]]; then
    return 0
  fi
  
  if [[ $GITSTATUS_BACKEND == daemon ]]; then
    return 1
  fi
  
  # Auto-detect: check if gitstatusd is available
  local plugin_dir="${_gitstatus_plugin_dir:-${${(%):-%x}:A:h}}"
  local daemon_path
  
  # Common gitstatusd locations
  for daemon_path in \
    "$plugin_dir/bin/gitstatusd" \
    "$plugin_dir/usrbin/gitstatusd" \
    "$plugin_dir/gitstatusd"; do
    if [[ -x "$daemon_path" ]]; then
      return 1  # Daemon available, don't use pure
    fi
  done
  
  # No daemon found, use pure backend
  return 0
}

# Override functions for integration with main plugin
if _gitstatus_should_use_pure_backend; then
  # Override the daemon-based functions with pure implementations
  
  # Main entry points - these match the original API exactly
  functions[gitstatus_start]='gitstatus_start() { gitstatus_start "$@" }'
  functions[gitstatus_query]='gitstatus_query() { gitstatus_query "$@" }'  
  functions[gitstatus_stop]='gitstatus_stop() { gitstatus_stop "$@" }'
  functions[gitstatus_check]='gitstatus_check() { gitstatus_check "$@" }'
  
  # Mark that we're using pure backend
  typeset -g GITSTATUS_BACKEND=git
  
  # Provide status info
  print -ru2 "gitstatus: using pure-zsh fallback (no gitstatusd daemon)"
fi