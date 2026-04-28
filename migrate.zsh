#!/usr/bin/env zsh
#
# migrate.zsh — Migrate from romkatv/powerlevel10k to quantumnic/powerlevel10k
#
# Usage:
#   zsh migrate.zsh [--dry-run|--check|--doctor]
#   # or: curl -fsSL https://raw.githubusercontent.com/quantumnic/powerlevel10k/master/migrate.zsh | zsh
#
# What it does:
#   1. Detects your current p10k installation method
#   2. Updates the git remote (or plugin reference) from romkatv → quantumnic
#   3. Preserves your ~/.p10k.zsh configuration (no changes)
#   4. Pulls latest changes when possible
#
# Your prompt configuration (~/.p10k.zsh) is NEVER modified.

set -euo pipefail

OLD_OWNER="romkatv"
NEW_OWNER="quantumnic"
MIGRATED=0
MODE=apply

typeset -a UPDATED_REMOTES UPDATED_CONFIGS BACKUPS FOUND_REMOTES FOUND_CONFIGS CURRENT_INSTALLS
typeset -a MANUAL_ACTIONS WARNINGS

usage() {
  print -r -- "Usage: zsh migrate.zsh [--dry-run|--check|--doctor|--help]"
  print -r -- ""
  print -r -- "Options:"
  print -r -- "  --dry-run  show planned changes without writing files or running git updates"
  print -r -- "  --check    inspect installation/config state without making changes"
  print -r -- "  --doctor   alias for --check"
  print -r -- "  --help     print this help"
}

while (( $# )); do
  case $1 in
    --dry-run|-n) MODE=dry-run;;
    --check) MODE=check;;
    --doctor) MODE=check;;
    --help|-h) usage; exit 0;;
    *)
      print -r -- "migrate.zsh: unknown option: $1" >&2
      usage >&2
      exit 2
    ;;
  esac
  shift
done

case $MODE in
  check) print -P "%F{cyan}%B── Powerlevel10k Migration Check ──%b%f";;
  dry-run) print -P "%F{cyan}%B── Powerlevel10k Migration Dry Run ──%b%f";;
  *) print -P "%F{cyan}%B── Powerlevel10k Migration ──%b%f";;
esac
print -P "Migrating from %F{red}romkatv%f/powerlevel10k → %F{green}quantumnic%f/powerlevel10k"
print ""

timestamp() {
  if [[ -n ${P10K_MIGRATE_TIMESTAMP:-} ]]; then
    print -r -- "$P10K_MIGRATE_TIMESTAMP"
  else
    date +%Y%m%d-%H%M%S 2>/dev/null || print -r -- "$$"
  fi
}

human_path() {
  local p=$1
  if [[ -n ${HOME:-} && $p == $HOME(|/*) ]]; then
    p="~${p#$HOME}"
  fi
  print -r -- "$p"
}

mode_prefix() {
  case $MODE in
    check) print -r -- "Found";;
    dry-run) print -r -- "Would update";;
    *) print -r -- "Updating";;
  esac
}

# --- Helper: update git remote in a directory ---
update_remote() {
  local label=$1 dir=$2
  if [[ -d "$dir/.git" ]]; then
    local url
    url=$(git -C "$dir" remote get-url origin 2>/dev/null || true)
    if [[ "$url" == *"$OLD_OWNER/powerlevel10k"* ]]; then
      local new_url=${url/$OLD_OWNER/$NEW_OWNER}
      FOUND_REMOTES+=("$label:$(human_path "$dir")")
      print -P "  %F{yellow}→%f $(mode_prefix) remote in %F{blue}$(human_path "$dir")%f ($label)"
      print -P "    old: $url"
      print -P "    new: $new_url"
      [[ $MODE != apply ]] && return 0
      if ! git -C "$dir" remote set-url origin "$new_url"; then
        WARNINGS+=("failed to update remote in $(human_path "$dir")")
        return 1
      fi
      if ! git -C "$dir" fetch origin --depth=1 2>/dev/null &&
         ! git -C "$dir" fetch origin 2>/dev/null; then
        WARNINGS+=("remote updated but fetch failed in $(human_path "$dir")")
      elif ! git -C "$dir" pull --ff-only 2>/dev/null; then
        WARNINGS+=("remote updated but fast-forward pull failed in $(human_path "$dir")")
      fi
      UPDATED_REMOTES+=("$label:$(human_path "$dir")")
      MIGRATED=1
      return 0
    elif [[ "$url" == *"$NEW_OWNER/powerlevel10k"* ]]; then
      CURRENT_INSTALLS+=("$label:$(human_path "$dir")")
    fi
  fi
  return 1
}

# --- Helper: update references in config files ---
update_config_file() {
  local file=$1
  if [[ -f "$file" ]] && grep -q "$OLD_OWNER/powerlevel10k" "$file" 2>/dev/null; then
    FOUND_CONFIGS+=("$(human_path "$file")")
    print -P "  %F{yellow}→%f $(mode_prefix) references in %F{blue}$(human_path "$file")%f"
    [[ $MODE != apply ]] && return 0
    local backup="${file}.p10k-migrate-$(timestamp)-backup"
    cp -p "$file" "$backup" 2>/dev/null || cp "$file" "$backup"
    if [[ "$OSTYPE" == darwin* ]]; then
      sed -i '' "s|$OLD_OWNER/powerlevel10k|$NEW_OWNER/powerlevel10k|g" "$file"
    else
      sed -i "s|$OLD_OWNER/powerlevel10k|$NEW_OWNER/powerlevel10k|g" "$file"
    fi
    UPDATED_CONFIGS+=("$(human_path "$file")")
    BACKUPS+=("$(human_path "$backup")")
    MIGRATED=1
    print -P "    backup: %F{blue}$(human_path "$backup")%f"
    print -P "    restore: %F{yellow}cp $(human_path "$backup") $(human_path "$file")%f"
  fi
}

detect_homebrew() {
  (( $+commands[brew] )) || return 0
  local taps
  taps=$(brew tap 2>/dev/null || true)
  if [[ $taps == *"$OLD_OWNER/powerlevel10k"* ]]; then
    MANUAL_ACTIONS+=("Homebrew tap $OLD_OWNER/powerlevel10k is installed; run: brew untap $OLD_OWNER/powerlevel10k")
  fi
}

# --- 1. Check common installation directories ---
print -P "%F{cyan}Checking installation directories...%f"

if (( ! ${+ZINIT} )); then
  typeset -A ZINIT
elif [[ ${(t)ZINIT} != *association* ]]; then
  unset ZINIT
  typeset -A ZINIT
fi

local_zdotdir=${ZDOTDIR:-$HOME}
local_xdg_config=${XDG_CONFIG_HOME:-$HOME/.config}
local_xdg_data=${XDG_DATA_HOME:-$HOME/.local/share}

install_dirs=(
  "manual" "$HOME/powerlevel10k"
  "manual-xdg" "$local_xdg_data/powerlevel10k"
  "oh-my-zsh" "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k"
  "oh-my-zsh" "$HOME/.oh-my-zsh/custom/themes/powerlevel10k"
  "zinit" "$HOME/.zinit/plugins/romkatv---powerlevel10k"
  "zinit" "$local_xdg_data/zinit/plugins/romkatv---powerlevel10k"
  "zinit" "${ZINIT[PLUGINS_DIR]:-/dev/null}/romkatv---powerlevel10k"
  "zplugin" "$HOME/.zplugin/plugins/romkatv---powerlevel10k"
  "zim" "${ZIM_HOME:-$HOME/.zim}/modules/powerlevel10k"
  "zplug" "$HOME/.zplug/repos/romkatv/powerlevel10k"
  "antigen" "$HOME/.antigen/bundles/romkatv/powerlevel10k"
  "antidote" "$HOME/.antidote/repos/romkatv/powerlevel10k"
  "antidote" "$local_xdg_data/antidote/repos/romkatv/powerlevel10k"
)

for label d in "${install_dirs[@]}"; do
  update_remote "$label" "$d" 2>/dev/null || true
done
detect_homebrew

# --- 2. Update plugin manager config files ---
print -P "%F{cyan}Checking config files...%f"

config_files=(
  "$local_zdotdir/.zshrc"
  "$local_zdotdir/.zshenv"
  "$local_zdotdir/.zprofile"
  "$HOME/.zshrc"
  "$HOME/.zimrc"
  "$HOME/.zplugrc"
  "$HOME/.antigenrc"
  "$HOME/.zinitrc"
  "$HOME/.zpluginrc"
  "$HOME/.zsh_plugins.txt"
  "$HOME/.zsh_plugins.zsh"
  "$local_xdg_config/sheldon/plugins.toml"
  "$local_xdg_config/sheldon/plugins.lock"
)

typeset -a seen_config_files
for f in "${config_files[@]}"; do
  (( ${seen_config_files[(Ie)$f]} )) || seen_config_files+=("$f")
done
for f in "${seen_config_files[@]}"; do
  update_config_file "$f"
done

# --- 3. Summary ---
print ""
print -P "%F{cyan}Summary:%f"
print -P "  Remote installs needing migration: %B${#FOUND_REMOTES}%b"
print -P "  Config files needing migration:   %B${#FOUND_CONFIGS}%b"
if (( ${#CURRENT_INSTALLS} )); then
  print -P "  Already on quantumnic:            %B${#CURRENT_INSTALLS}%b"
fi
if (( ${#UPDATED_REMOTES} )); then
  print -P "  Remotes updated:                  %B${#UPDATED_REMOTES}%b"
fi
if (( ${#UPDATED_CONFIGS} )); then
  print -P "  Config files updated:             %B${#UPDATED_CONFIGS}%b"
fi
if (( ${#BACKUPS} )); then
  print -P "  Backups created:"
  local b
  for b in "${BACKUPS[@]}"; do
    print -P "    %F{blue}$b%f"
  done
fi
if (( ${#MANUAL_ACTIONS} )); then
  print -P "  Manual actions:"
  local action
  for action in "${MANUAL_ACTIONS[@]}"; do
    print -P "    %F{yellow}$action%f"
  done
fi
if (( ${#WARNINGS} )); then
  print -P "  Warnings:"
  local warning
  for warning in "${WARNINGS[@]}"; do
    print -P "    %F{yellow}$warning%f"
  done
fi
print ""

if [[ $MODE == check ]]; then
  if (( ${#FOUND_REMOTES} || ${#FOUND_CONFIGS} || ${#MANUAL_ACTIONS} )); then
    print -P "%F{yellow}Migration is available. Run without --check to apply, or with --dry-run to preview.%f"
  else
    print -P "%F{green}No romkatv/powerlevel10k references found.%f"
  fi
elif [[ $MODE == dry-run ]]; then
  if (( ${#FOUND_REMOTES} || ${#FOUND_CONFIGS} || ${#MANUAL_ACTIONS} )); then
    print -P "%F{yellow}Dry run complete. No files, remotes, or caches were changed.%f"
  else
    print -P "%F{green}No romkatv/powerlevel10k references found.%f"
  fi
elif (( MIGRATED )); then
  print -P "%F{green}%B✓ Migration complete!%b%f"
  print -P "  Your %F{blue}~/.p10k.zsh%f configuration was preserved (no changes needed)."
  print -P "  Run %F{yellow}exec zsh%f to reload your shell."
elif (( ${#MANUAL_ACTIONS} )); then
  print -P "%F{yellow}Manual migration steps remain.%f"
  print -P "  Complete the manual actions above, then run %F{yellow}exec zsh%f to reload your shell."
else
  print -P "%F{yellow}No romkatv/powerlevel10k installation found.%f"
  print -P "  If you installed via Homebrew or a system package, update manually:"
  print -P "  %F{blue}brew untap romkatv/powerlevel10k 2>/dev/null%f"
  print -P "  Then install from: %F{green}https://github.com/quantumnic/powerlevel10k#installation%f"
fi
