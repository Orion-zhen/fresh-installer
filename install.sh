#!/bin/bash

# setup .config repo
rm -rf $HOME/.config.bak
cp -r $HOME/.config $HOME/.config.bak
cd $HOME/.config
git init --initial-branch=main
git remote add origin https://github.com/Orion-zhen/dot-config.git
git fetch
git reset --hard origin/main
git branch --set-upstream-to origin/main
cd $HOME
cp -rn $HOME/.config.bak/* $HOME/.config/

if [[ "$(uname)" == "Linux" ]]; then
  if [[ "$1" == "--add-repo" ]]; then
    sudo cp /etc/pacman.conf /etc/pacman.conf.bak
    sudo curl -fsSL https://raw.githubusercontent.com/Orion-zhen/fresh-installer/refs/heads/main/pacman.conf >> /etc/pacman.conf
  fi
  curl -fsSL https://raw.githubusercontent.com/Orion-zhen/fresh-installer/refs/heads/main/arch-pkgs.txt | xargs sudo pacman -Syu --noconfirm
  sudo groupadd docker
  sudo usermod -aG docker $USER
  sudo systemctl enable --now docker.service docker.socket
  sudo systemctl enable --now cronie.service
  sudo systemctl enable --now sshd.service
  sudo systemctl enable --now tailscaled.service
  sudo systemctl enable --now cups.service cups.socket cups-browsed.service
elif [[ "$(uname)" == "Darwin" ]]; then
  /bin/bash -c "$(curl -fsSL https://github.com/Homebrew/install/raw/master/install.sh)"
  curl -fsSL https://raw.githubusercontent.com/Orion-zhen/fresh-installer/refs/heads/main/brew-pkg.txt > brew-pkg.txt
  brew bundle --file brew-pkg.txt
fi
