#!/usr/bin/env zsh
#
# migrate.zsh — Migrate from romkatv/powerlevel10k to quantumnic/powerlevel10k
#
# Usage:
#   zsh migrate.zsh
#   # or: curl -fsSL https://raw.githubusercontent.com/quantumnic/powerlevel10k/master/migrate.zsh | zsh
#
# What it does:
#   1. Detects your current p10k installation method
#   2. Updates the git remote (or plugin reference) from romkatv → quantumnic
#   3. Preserves your ~/.p10k.zsh configuration (no changes)
#   4. Pulls latest changes
#
# Your prompt configuration (~/.p10k.zsh) is NEVER modified.

set -euo pipefail

print -P "%F{cyan}%B── Powerlevel10k Migration ──%b%f"
print -P "Migrating from %F{red}romkatv%f/powerlevel10k → %F{green}quantumnic%f/powerlevel10k"
print ""

OLD_OWNER="romkatv"
NEW_OWNER="quantumnic"
MIGRATED=0

# --- Helper: update git remote in a directory ---
update_remote() {
  local dir=$1
  if [[ -d "$dir/.git" ]]; then
    local url
    url=$(git -C "$dir" remote get-url origin 2>/dev/null || true)
    if [[ "$url" == *"$OLD_OWNER/powerlevel10k"* ]]; then
      local new_url=${url/$OLD_OWNER/$NEW_OWNER}
      print -P "  %F{yellow}→%f Updating remote in %F{blue}$dir%f"
      print -P "    old: $url"
      print -P "    new: $new_url"
      git -C "$dir" remote set-url origin "$new_url"
      git -C "$dir" fetch origin --depth=1 2>/dev/null || git -C "$dir" fetch origin 2>/dev/null
      git -C "$dir" pull --ff-only 2>/dev/null || git -C "$dir" reset --hard origin/master 2>/dev/null || true
      MIGRATED=1
      return 0
    fi
  fi
  return 1
}

# --- Helper: update references in config files ---
update_config_file() {
  local file=$1
  if [[ -f "$file" ]] && grep -q "$OLD_OWNER/powerlevel10k" "$file" 2>/dev/null; then
    print -P "  %F{yellow}→%f Updating references in %F{blue}$file%f"
    # Create backup
    cp "$file" "${file}.p10k-migrate-backup"
    if [[ "$OSTYPE" == darwin* ]]; then
      sed -i '' "s|$OLD_OWNER/powerlevel10k|$NEW_OWNER/powerlevel10k|g" "$file"
    else
      sed -i "s|$OLD_OWNER/powerlevel10k|$NEW_OWNER/powerlevel10k|g" "$file"
    fi
    MIGRATED=1
    print -P "    (backup: ${file}.p10k-migrate-backup)"
  fi
}

# --- 1. Check common installation directories ---
print -P "%F{cyan}Checking installation directories...%f"

# Manual install
update_remote ~/powerlevel10k 2>/dev/null || true

# Oh My Zsh
for d in "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k" \
         "$HOME/.oh-my-zsh/custom/themes/powerlevel10k"; do
  update_remote "$d" 2>/dev/null || true
done

# Zinit / Zplugin
for d in ~/.zinit/plugins/romkatv---powerlevel10k \
         ~/.local/share/zinit/plugins/romkatv---powerlevel10k \
         "${ZINIT[PLUGINS_DIR]:-/dev/null}/romkatv---powerlevel10k" \
         ~/.zplugin/plugins/romkatv---powerlevel10k; do
  update_remote "$d" 2>/dev/null || true
done

# Zim
if [[ -d "${ZIM_HOME:-$HOME/.zim}/modules/powerlevel10k" ]]; then
  update_remote "${ZIM_HOME:-$HOME/.zim}/modules/powerlevel10k" 2>/dev/null || true
fi

# --- 2. Update plugin manager config files ---
print -P "%F{cyan}Checking config files...%f"

update_config_file ~/.zshrc
update_config_file ~/.zimrc
update_config_file ~/.zsh_plugins.txt    # Antidote
update_config_file ~/.zsh_plugins.zsh    # Antidote (compiled)

# --- 3. Summary ---
print ""
if (( MIGRATED )); then
  print -P "%F{green}%B✓ Migration complete!%b%f"
  print -P "  Your %F{blue}~/.p10k.zsh%f configuration was preserved (no changes needed)."
  print -P "  Run %F{yellow}exec zsh%f to reload your shell."
else
  print -P "%F{yellow}No romkatv/powerlevel10k installation found.%f"
  print -P "  If you installed via Homebrew or a system package, update manually:"
  print -P "  %F{blue}brew untap romkatv/powerlevel10k 2>/dev/null%f"
  print -P "  Then install from: %F{green}https://github.com/quantumnic/powerlevel10k#installation%f"
fi
