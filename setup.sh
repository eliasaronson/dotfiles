#!/bin/sh

# Install packages
sudo pacman -S neovim zsh chezmoi ripgrep zathura nodejs xsel alacritty brightnessctl nitrogen xss-lock python-pip bluez bluez-utils clipmenu gdb

yay -S asusctl google-chrome python-pynvim i3lock-color julia-bin caffeine

# Switch shell
chsh -s $(which zsh)

# Oh-my-zsh
sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
git clone https://github.com/zsh-users/zsh-autosuggestions ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions
git clone https://github.com/zsh-users/zsh-syntax-highlighting.git ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting

# Vim
curl -fLo ~/.vim/autoload/plug.vim --create-dirs \
    https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim

# Generate ssh-key
sh-keygen -t ed25519 -C "elias.aronson@gmail.com"
ssh-add ~/.ssh/id_ed25519
cat .ssh/id_ed25519.pub

# chezmoi setup
chezmoi init git@github.com:eliasaronson/dotfiles.git
chezmoi apply --verbose

# Github
~/scripts/gitalias.sh

# Extra
sudo pacman -S openfortivpn pyright noto-fonts-emoji spotify-launcher

# Development
sudo pacman -S cuda ncurses5-compat-libs opencl-nvidia nvidia-utils libsndfile
