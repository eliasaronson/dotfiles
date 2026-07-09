#!/bin/bash
# Install oh-my-zsh + the custom plugins that ~/.zshrc depends on.
# Cross-distro (Ubuntu + NixOS) — runs via `chezmoi apply`. Idempotent.
# Uses --keep-zshrc so it never touches ~/.zshrc (chezmoi owns that).
set -euo pipefail

OMZ="$HOME/.oh-my-zsh"
CUSTOM="${ZSH_CUSTOM:-$OMZ/custom}"

# --- oh-my-zsh ---
if [ ! -d "$OMZ" ]; then
    echo "[ohmyzsh] installing oh-my-zsh"
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" \
        "" --unattended --keep-zshrc
else
    echo "[ohmyzsh] already present"
fi

# --- public plugins ---
declare -A PLUGINS=(
    [zsh-autosuggestions]="https://github.com/zsh-users/zsh-autosuggestions"
    [zsh-syntax-highlighting]="https://github.com/zsh-users/zsh-syntax-highlighting.git"
    [fzf-tab]="https://github.com/Aloxaf/fzf-tab"
    [zsh-completions]="https://github.com/zsh-users/zsh-completions.git"
)
for name in "${!PLUGINS[@]}"; do
    dir="$CUSTOM/plugins/$name"
    if [ ! -d "$dir" ]; then
        echo "[ohmyzsh] cloning $name"
        git clone --depth=1 "${PLUGINS[$name]}" "$dir"
    fi
done

# --- private plugin (needs SSH auth; best-effort so a missing key doesn't abort) ---
clip="$CUSTOM/plugins/clipfile"
if [ ! -d "$clip" ]; then
    if git clone --depth=1 git@github.com:eliasaronson/clipfile.git "$clip" 2>/dev/null; then
        echo "[ohmyzsh] cloned clipfile"
    else
        echo "[ohmyzsh] WARN: couldn't clone clipfile (SSH auth?). Later run:"
        echo "         git clone git@github.com:eliasaronson/clipfile.git $clip"
    fi
fi

echo "[ohmyzsh] done"
