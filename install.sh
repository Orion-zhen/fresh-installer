#!/bin/bash

if [[ "$(uname)" == "Linux" ]]; then
  if [[ "$1" == "--add-repo" ]]; then
    sudo cp /etc/pacman.conf /etc/pacman.conf.bak
    sudo curl -fsSL https://raw.githubusercontent.com/Orion-zhen/fresh-installer/refs/heads/main/pacman.conf >> /etc/pacman.conf
  fi
  curl -fsSL https://raw.githubusercontent.com/Orion-zhen/fresh-installer/refs/heads/main/arch-pkgs.txt | xargs sudo pacman -S --noconfirm
  sudo groupadd docker
  sudo usermod -aG docker $USER
  sudo systemctl enable --now docker.service docker.socket
  sudo systemctl enable --now cronie.service
  sudo systemctl enable --now sshd.service
  sudo systemctl enable --now tailscaled.service
  sudo systemctl enable --now cups.service cups.socket cups-browsed.service
elif [[ "$(uname)" == "Darwin" ]]; then
  # TODO: install homebrew and brew install
fi
