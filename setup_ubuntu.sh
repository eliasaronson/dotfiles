# Add ppa:s
# sudo add-apt-repository ppa:neovim-ppa/stable
sudo add-apt-repository ppa:neovim-ppa/unstable

# Chrome
wget -q -O - https://dl-ssl.google.com/linux/linux_signing_key.pub | sudo apt-key add -
sudo sh -c 'echo "deb [arch=amd64] http://dl.google.com/linux/chrome/deb/ stable main" >> /etc/apt/sources.list.d/google.list'

# Wezterm
curl -fsSL https://apt.fury.io/wez/gpg.key | sudo gpg --yes --dearmor -o /usr/share/keyrings/wezterm-fury.gpg
echo 'deb [signed-by=/usr/share/keyrings/wezterm-fury.gpg] https://apt.fury.io/wez/ * *' | sudo tee /etc/apt/sources.list.d/wezterm.list

# Install packages
sudo apt update
sudo apt install vim neovim neovim git i3-wm zsh curl google-chrome-stable nitrogen fonts-powerline ripgrep alacritty python-is-python3 cmake python3-dev g++ dmenu ninja-build xsel nvidia-cudnn scrot ranger clang-format pip npm cargo shfmt fzf fd-find zoxide highlight libnotify-bin dunst xfce4-power-manager i3blocks brightnessctl pulseaudio-utils blueman wezterm flameshot xclip
ln -s $(which fdfind) ~/.local/bin/fd

sudo snap install dust
curl https://raw.githubusercontent.com/jesseduffield/lazydocker/master/scripts/install_update_linux.sh | bash

DIVE_VERSION=$(curl -sL "https://api.github.com/repos/wagoodman/dive/releases/latest" | grep '"tag_name":' | sed -E 's/.*"v([^"]+)".*/\1/')
curl -fOL "https://github.com/wagoodman/dive/releases/download/v${DIVE_VERSION}/dive_${DIVE_VERSION}_linux_amd64.deb"
sudo apt install ./dive_${DIVE_VERSION}_linux_amd64.deb

# Oh my zsh
sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
git clone https://github.com/zsh-users/zsh-autosuggestions ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions
git clone https://github.com/zsh-users/zsh-syntax-highlighting.git ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting
git clone https://github.com/Aloxaf/fzf-tab ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/fzf-tab
git clone https://github.com/zsh-users/zsh-completions.git ${ZSH_CUSTOM:-${ZSH:-~/.oh-my-zsh}/custom}/plugins/zsh-completions
git clone git@github.com:eliasaronson/clipfile.git ${ZSH_CUSTOM:-${ZSH:-~/.oh-my-zsh}/custom}/plugins/clipfile

# git
git config --global pull.rebase true
git config --global core.autocrlf input
git config --global user.email "elias@intuicell.com"
git config --global user.name "Elias H Aronsson"
# Add ssh key

# Chezmoi
sh -c "$(curl -fsLS get.chezmoi.io)" -- -b $HOME/.local/bin
chezmoi init git@github.com:eliasaronson/dotfiles.git

#chezmoi apply -v
chmod +x scripts/gitalias.sh
scripts/gitalias.sh

# Vim
pip install --user --upgrade --break-system-packages pynvim
sudo npm install -g neovim

cargo install stylua
sudo npm install --save-dev --save-exact -g @biomejs/biome
sudo npm install -g @fsouza/prettierd
pip install isort black --break-system-packages

curl -fLo ~/.vim/autoload/plug.vim --create-dirs https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim
vim +'PlugInstall --sync' +qa
cd ~/.vim/plugged/YouCompleteMe
python install.py --all
cd

# Keyboard
cd Documents && git clone git@github.com:eliasaronson/US-keyboard-with-Swedish-letters.git && cd US-keyboard-with-Swedish-letters
./install.sh
setxkbmap -layout se -variant US_swe
cd

# NoMachine
cd ~/Downloads
wget https://download.nomachine.com/download/8.13/Linux/nomachine_8.13.1_1_amd64.deb
sudo dpkg -i nomachine_8.13.1_1_amd64.deb
cd

# color lock
scripts/install_i3_color_lock.sh

# uv
curl -LsSf https://astral.sh/uv/install.sh | sh
uv tool install ruff@latest

pip install qtconsole --break-system-packages
