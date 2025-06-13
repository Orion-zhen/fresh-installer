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
rm -rf $HOME/.config.bak

if [[ "$(uname)" == "Linux" ]]; then
  curl -fsSL https://raw.githubusercontent.com/Orion-zhen/fresh-installer/refs/heads/main/arch-pkgs.txt | xargs sudo pacman -Syu --noconfirm
elif [[ "$(uname)" == "Darwin" ]]; then
  /bin/bash -c "$(curl -fsSL https://github.com/Homebrew/install/raw/master/install.sh)"
  curl -fsSL https://raw.githubusercontent.com/Orion-zhen/fresh-installer/refs/heads/main/brew-pkg.txt >brew-pkg.txt
  brew bundle --file brew-pkg.txt
fi
