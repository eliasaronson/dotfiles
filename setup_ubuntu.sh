# Add ppa:s
# sudo add-apt-repository ppa:neovim-ppa/stable
sudo add-apt-repository ppa:neovim-ppa/unstable

# Chrome
wget -q -O - https://dl-ssl.google.com/linux/linux_signing_key.pub | sudo apt-key add -
sudo sh -c 'echo "deb [arch=amd64] http://dl.google.com/linux/chrome/deb/ stable main" >> /etc/apt/sources.list.d/google.list'

# Install packages
sudo apt update
sudo apt install vim neovim neovim git i3-wm zsh curl google-chrome-stable nitrogen fonts-powerline ripgrep alacritty python-is-python3 cmake python3-dev g++ dmenu ninja-build xsel nvidia-cudnn scrot ranger clang-format #python-neovim golang-go

# Oh my zsh
sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"

# git
git config --global pull.rebase true
git config --global core.autocrlf input
git config --global user.email "elias@intuicell.com"
git config --global user.name "Elias H Aronsson"
# Add ssh key

# Chezmoi
wget https://github.com/twpayne/chezmoi/releases/download/v2.42.3/chezmoi_2.42.3_linux_amd64.deb
sudo dpkg -i chezmoi_2.42.3_linux_amd64.deb
chezmoi init git@github.com:eliasaronson/dotfiles.git

#chezmoi apply -v
scripts/gitalias.sh

# Vim
pip install neovim --break-system-packages
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
wget https://download.nomachine.com/download/8.10/Linux/nomachine_8.10.1_1_amd64.deb
sudo dpkg -i nomachine_8.10.1_1_amd64.deb
cd
