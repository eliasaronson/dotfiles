#!/bin/bash
# Idempotent Ubuntu setup script. Safe to re-run after a crash or on subsequent machines.
set -euo pipefail

# ==============================================================================
# Logging helpers
# ==============================================================================
log_section() { echo -e "\n====== $1 ======"; }
log_info()    { echo "[INFO]  $1"; }
log_skip()    { echo "[SKIP]  $1 (already done)"; }
log_warn()    { echo "[WARN]  $1"; }

# ==============================================================================
# Path constants & environment
# ==============================================================================
LOCAL_BIN="$HOME/.local/bin"
mkdir -p "$LOCAL_BIN"

TMPDIR_SETUP="$(mktemp -d)"
trap 'rm -rf "$TMPDIR_SETUP"' EXIT

UBUNTU_VERSION="$(lsb_release -rs)"       # e.g. "24.04"
ARCH="$(dpkg --print-architecture)"        # e.g. "amd64"

# ==============================================================================
# Section 1: APT Repositories
# ==============================================================================
log_section "APT Repositories"

# Neovim unstable PPA
if ! grep -rq "neovim-ppa/unstable" /etc/apt/sources.list.d/ 2>/dev/null; then
    log_info "Adding Neovim unstable PPA"
    sudo add-apt-repository -y ppa:neovim-ppa/unstable
else
    log_skip "Neovim PPA"
fi

# Google Chrome (modern signed-by keyring, replaces deprecated apt-key)
CHROME_KEYRING="/usr/share/keyrings/google-chrome.gpg"
CHROME_LIST="/etc/apt/sources.list.d/google-chrome.list"
if [ ! -f "$CHROME_KEYRING" ]; then
    log_info "Adding Google Chrome keyring"
    curl -fsSL https://dl.google.com/linux/linux_signing_key.pub \
        | sudo gpg --dearmor -o "$CHROME_KEYRING"
else
    log_skip "Chrome keyring"
fi
if [ ! -f "$CHROME_LIST" ]; then
    log_info "Adding Google Chrome repo"
    echo "deb [arch=${ARCH} signed-by=${CHROME_KEYRING}] http://dl.google.com/linux/chrome/deb/ stable main" \
        | sudo tee "$CHROME_LIST" > /dev/null
else
    log_skip "Chrome repo"
fi

# Wezterm
WEZTERM_KEYRING="/usr/share/keyrings/wezterm-fury.gpg"
WEZTERM_LIST="/etc/apt/sources.list.d/wezterm.list"
if [ ! -f "$WEZTERM_KEYRING" ]; then
    log_info "Adding Wezterm keyring"
    curl -fsSL https://apt.fury.io/wez/gpg.key \
        | sudo gpg --yes --dearmor -o "$WEZTERM_KEYRING"
else
    log_skip "Wezterm keyring"
fi
if [ ! -f "$WEZTERM_LIST" ]; then
    log_info "Adding Wezterm repo"
    echo "deb [signed-by=${WEZTERM_KEYRING}] https://apt.fury.io/wez/ * *" \
        | sudo tee "$WEZTERM_LIST" > /dev/null
else
    log_skip "Wezterm repo"
fi

# GitHub CLI
GH_KEYRING="/usr/share/keyrings/githubcli-archive-keyring.gpg"
GH_LIST="/etc/apt/sources.list.d/github-cli.list"
if [ ! -f "$GH_KEYRING" ]; then
    log_info "Adding GitHub CLI keyring"
    curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
        | sudo tee "$GH_KEYRING" > /dev/null
else
    log_skip "GitHub CLI keyring"
fi
if [ ! -f "$GH_LIST" ]; then
    log_info "Adding GitHub CLI repo"
    echo "deb [arch=${ARCH} signed-by=${GH_KEYRING}] https://cli.github.com/packages stable main" \
        | sudo tee "$GH_LIST" > /dev/null
else
    log_skip "GitHub CLI repo"
fi

# ==============================================================================
# Section 2: APT Package Installation
# ==============================================================================
log_section "APT Packages"
sudo apt update

APT_PACKAGES=(
    vim neovim git i3-wm zsh curl google-chrome-stable nitrogen
    fonts-powerline ripgrep alacritty python-is-python3 cmake python3-dev
    g++ dmenu ninja-build xsel scrot ranger clang-format pip npm cargo
    shfmt fzf fd-find zoxide highlight libnotify-bin dunst
    xfce4-power-manager i3blocks brightnessctl pulseaudio-utils blueman
    wezterm flameshot xclip gh
)

MISSING=()
for pkg in "${APT_PACKAGES[@]}"; do
    if ! dpkg -s "$pkg" &>/dev/null; then
        MISSING+=("$pkg")
    fi
done

if [ ${#MISSING[@]} -gt 0 ]; then
    log_info "Installing ${#MISSING[@]} packages: ${MISSING[*]}"
    sudo apt install -y "${MISSING[@]}"
else
    log_skip "All APT packages"
fi

# fd-find symlink
if [ ! -e "$LOCAL_BIN/fd" ]; then
    log_info "Creating fd symlink"
    ln -s "$(which fdfind)" "$LOCAL_BIN/fd"
else
    log_skip "fd symlink"
fi

# Default shell
if [ "$SHELL" != "$(which zsh)" ]; then
    log_info "Setting default shell to zsh"
    chsh -s "$(which zsh)"
else
    log_skip "Default shell already zsh"
fi

# ==============================================================================
# Section 3: GitHub CLI Authentication
# ==============================================================================
log_section "GitHub CLI Authentication"
if ! gh auth status &>/dev/null; then
    log_info "Running gh auth login (interactive)"
    gh auth login
    gh auth setup-git
else
    log_skip "gh already authenticated"
fi

# ==============================================================================
# Section 4: Git Configuration
# ==============================================================================
log_section "Git Configuration"
git config --global pull.rebase true
git config --global core.autocrlf input
git config --global user.email "elias@intuicell.com"
git config --global user.name "Elias H Aronsson"

# ==============================================================================
# Section 5: Chezmoi
# ==============================================================================
log_section "Chezmoi"
if ! command -v chezmoi &>/dev/null; then
    log_info "Installing chezmoi"
    sh -c "$(curl -fsLS get.chezmoi.io)" -- -b "$LOCAL_BIN"
else
    log_skip "chezmoi binary"
fi

if [ ! -d "$HOME/.local/share/chezmoi/.git" ]; then
    log_info "Initializing chezmoi"
    chezmoi init git@github.com:eliasaronson/dotfiles.git
else
    log_skip "chezmoi already initialized"
fi

CHEZMOI_SOURCE="$(chezmoi source-path)"

# ==============================================================================
# Section 6: Git Aliases
# ==============================================================================
log_section "Git Aliases"
GITALIAS_SCRIPT="${CHEZMOI_SOURCE}/scripts/executable_gitalias.sh"
if [ -f "$GITALIAS_SCRIPT" ]; then
    log_info "Running gitalias.sh"
    bash "$GITALIAS_SCRIPT"
else
    log_warn "gitalias.sh not found at $GITALIAS_SCRIPT"
fi

# ==============================================================================
# Section 7: Oh My Zsh + Plugins
# ==============================================================================
log_section "Oh My Zsh"
OMZ_DIR="$HOME/.oh-my-zsh"
OMZ_CUSTOM="${ZSH_CUSTOM:-$OMZ_DIR/custom}"

if [ ! -d "$OMZ_DIR" ]; then
    log_info "Installing Oh My Zsh"
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
else
    log_skip "Oh My Zsh"
fi

declare -A OMZ_PLUGINS=(
    [zsh-autosuggestions]="https://github.com/zsh-users/zsh-autosuggestions"
    [zsh-syntax-highlighting]="https://github.com/zsh-users/zsh-syntax-highlighting.git"
    [fzf-tab]="https://github.com/Aloxaf/fzf-tab"
    [zsh-completions]="https://github.com/zsh-users/zsh-completions.git"
)

for plugin in "${!OMZ_PLUGINS[@]}"; do
    PLUGIN_DIR="${OMZ_CUSTOM}/plugins/${plugin}"
    if [ ! -d "$PLUGIN_DIR" ]; then
        log_info "Cloning OMZ plugin: $plugin"
        git clone "${OMZ_PLUGINS[$plugin]}" "$PLUGIN_DIR"
    else
        log_skip "OMZ plugin: $plugin"
    fi
done

# clipfile (private repo, uses SSH — requires gh auth from Section 3)
CLIPFILE_DIR="${OMZ_CUSTOM}/plugins/clipfile"
if [ ! -d "$CLIPFILE_DIR" ]; then
    log_info "Cloning OMZ plugin: clipfile (SSH)"
    git clone git@github.com:eliasaronson/clipfile.git "$CLIPFILE_DIR"
else
    log_skip "OMZ plugin: clipfile"
fi

# ==============================================================================
# Section 8: Snap & Binary Tools
# ==============================================================================
log_section "Snap & Binary Tools"

# dust
if ! snap list dust &>/dev/null 2>&1; then
    log_info "Installing dust via snap"
    sudo snap install dust
else
    log_skip "dust (snap)"
fi

# lazydocker
if ! command -v lazydocker &>/dev/null; then
    log_info "Installing lazydocker"
    curl -fsSL https://raw.githubusercontent.com/jesseduffield/lazydocker/master/scripts/install_update_linux.sh | bash
else
    log_skip "lazydocker"
fi

# dive (download to temp dir, not CWD)
if ! command -v dive &>/dev/null; then
    log_info "Installing dive"
    DIVE_VERSION=$(curl -sL "https://api.github.com/repos/wagoodman/dive/releases/latest" \
        | grep '"tag_name":' | sed -E 's/.*"v([^"]+)".*/\1/')
    curl -fL -o "${TMPDIR_SETUP}/dive.deb" \
        "https://github.com/wagoodman/dive/releases/download/v${DIVE_VERSION}/dive_${DIVE_VERSION}_linux_amd64.deb"
    sudo apt install -y "${TMPDIR_SETUP}/dive.deb"
else
    log_skip "dive"
fi

# ==============================================================================
# Section 9: Vim / Neovim Setup
# ==============================================================================
log_section "Vim / Neovim Setup"

# pynvim
if ! python3 -c "import pynvim" &>/dev/null; then
    log_info "Installing pynvim"
    pip install --user --upgrade --break-system-packages pynvim
else
    log_skip "pynvim"
fi

# neovim npm package
if ! npm list -g neovim &>/dev/null; then
    log_info "Installing neovim npm package"
    sudo npm install -g neovim
else
    log_skip "neovim npm"
fi

# stylua
if ! command -v stylua &>/dev/null; then
    log_info "Installing stylua"
    cargo install stylua
else
    log_skip "stylua"
fi

# biome
if ! command -v biome &>/dev/null; then
    log_info "Installing biome"
    sudo npm install --save-dev --save-exact -g @biomejs/biome
else
    log_skip "biome"
fi

# prettierd
if ! command -v prettierd &>/dev/null; then
    log_info "Installing prettierd"
    sudo npm install -g @fsouza/prettierd
else
    log_skip "prettierd"
fi

# isort and black
if ! command -v isort &>/dev/null || ! command -v black &>/dev/null; then
    log_info "Installing isort and black"
    pip install isort black --break-system-packages
else
    log_skip "isort/black"
fi

# vim-plug
PLUG_VIM="$HOME/.vim/autoload/plug.vim"
if [ ! -f "$PLUG_VIM" ]; then
    log_info "Installing vim-plug"
    curl -fLo "$PLUG_VIM" --create-dirs \
        https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim
else
    log_skip "vim-plug"
fi

log_info "Running PlugInstall (installs missing plugins only)"
vim +'PlugInstall --sync' +qa

# ==============================================================================
# Section 10: Keyboard Layout
# ==============================================================================
log_section "Custom Keyboard Layout"
KB_DIR="$HOME/Documents/US-keyboard-with-Swedish-letters"
if [ ! -d "$KB_DIR" ]; then
    log_info "Cloning keyboard layout repo"
    mkdir -p "$HOME/Documents"
    git clone git@github.com:eliasaronson/US-keyboard-with-Swedish-letters.git "$KB_DIR"
    log_info "Running keyboard install script"
    bash "$KB_DIR/install.sh"
else
    log_skip "Keyboard layout repo"
fi

setxkbmap -layout se -variant US_swe || true

# ==============================================================================
# Section 11: NoMachine
# ==============================================================================
log_section "NoMachine"
if ! dpkg -s nomachine &>/dev/null; then
    log_info "Installing NoMachine"
    wget -O "${TMPDIR_SETUP}/nomachine.deb" \
        "https://download.nomachine.com/download/8.13/Linux/nomachine_8.13.1_1_amd64.deb"
    sudo dpkg -i "${TMPDIR_SETUP}/nomachine.deb"
else
    log_skip "NoMachine"
fi

# ==============================================================================
# Section 12: i3lock-color
# ==============================================================================
log_section "i3lock-color"
I3LOCK_SCRIPT="${CHEZMOI_SOURCE}/scripts/executable_install_i3_color_lock.sh"
if ! command -v i3lock &>/dev/null; then
    if [ -f "$I3LOCK_SCRIPT" ]; then
        log_info "Running i3lock-color install script"
        bash "$I3LOCK_SCRIPT"
    else
        log_warn "i3lock-color install script not found at $I3LOCK_SCRIPT"
    fi
else
    log_skip "i3lock-color"
fi

# ==============================================================================
# Section 13: Julia (via juliaup)
# ==============================================================================
log_section "Julia"
if ! command -v julia &>/dev/null; then
    log_info "Installing Julia via juliaup"
    curl -fsSL https://install.julialang.org | sh
else
    log_skip "Julia"
fi

# ==============================================================================
# Section 14: uv + ruff
# ==============================================================================
log_section "uv + ruff"
if ! command -v uv &>/dev/null; then
    log_info "Installing uv"
    curl -LsSf https://astral.sh/uv/install.sh | sh
else
    log_skip "uv"
fi

export PATH="$HOME/.local/bin:$HOME/.cargo/bin:$PATH"

if ! command -v ruff &>/dev/null; then
    log_info "Installing ruff via uv"
    uv tool install ruff@latest
else
    log_skip "ruff"
fi

# ==============================================================================
# Section 15: qtconsole
# ==============================================================================
log_section "qtconsole"
if ! python3 -c "import qtconsole" &>/dev/null; then
    log_info "Installing qtconsole"
    pip install qtconsole --break-system-packages
else
    log_skip "qtconsole"
fi

# ==============================================================================
# Section 16: Set Wezterm as Default Terminal
# ==============================================================================
log_section "Default Terminal (Wezterm)"
WEZTERM_PATH="$(which wezterm 2>/dev/null || true)"
if [ -n "$WEZTERM_PATH" ]; then
    CURRENT_TERM="$(readlink -f /etc/alternatives/x-terminal-emulator 2>/dev/null || true)"
    if [ "$CURRENT_TERM" != "$WEZTERM_PATH" ]; then
        log_info "Registering wezterm as x-terminal-emulator alternative"
        sudo update-alternatives --install /usr/bin/x-terminal-emulator \
            x-terminal-emulator "$WEZTERM_PATH" 50
        log_info "Setting wezterm as default terminal"
        sudo update-alternatives --set x-terminal-emulator "$WEZTERM_PATH"
    else
        log_skip "Wezterm already default terminal"
    fi
else
    log_warn "wezterm not found on PATH; cannot set as default terminal"
fi

# ==============================================================================
# Section 17: NVIDIA GPU + CUDA (conditional)
# ==============================================================================
log_section "NVIDIA GPU + CUDA"
if lspci | grep -qi nvidia; then
    log_info "NVIDIA GPU detected"

    # CUDA keyring
    if ! dpkg -s cuda-keyring &>/dev/null; then
        log_info "Installing CUDA keyring"
        UBUNTU_VER_NODOT="${UBUNTU_VERSION//./}"
        CUDA_KEYRING_DEB="cuda-keyring_1.1-1_all.deb"
        curl -fL -o "${TMPDIR_SETUP}/${CUDA_KEYRING_DEB}" \
            "https://developer.download.nvidia.com/compute/cuda/repos/ubuntu${UBUNTU_VER_NODOT}/x86_64/${CUDA_KEYRING_DEB}"
        sudo dpkg -i "${TMPDIR_SETUP}/${CUDA_KEYRING_DEB}"
        sudo apt update
    else
        log_skip "CUDA keyring"
    fi

    # CUDA toolkit
    if ! dpkg -s cuda-toolkit &>/dev/null; then
        log_info "Installing CUDA toolkit"
        sudo apt install -y cuda-toolkit
    else
        log_skip "CUDA toolkit"
    fi

    # NVIDIA drivers
    if ! dpkg -s cuda-drivers &>/dev/null; then
        log_info "Installing NVIDIA drivers (cuda-drivers)"
        sudo apt install -y cuda-drivers
    else
        log_skip "NVIDIA drivers"
    fi

    # nvidia-cudnn (was in the unconditional apt list before)
    if ! dpkg -s nvidia-cudnn &>/dev/null; then
        log_info "Installing nvidia-cudnn"
        sudo apt install -y nvidia-cudnn
    else
        log_skip "nvidia-cudnn"
    fi
else
    log_info "No NVIDIA GPU detected, skipping CUDA installation"
fi

# ==============================================================================
# Done
# ==============================================================================
log_section "Setup Complete"
log_info "You may need to:"
log_info "  - Log out and back in for shell changes to take effect"
log_info "  - Reboot if NVIDIA drivers were installed"
log_info "  - Run 'chezmoi apply -v' to apply dotfiles"
