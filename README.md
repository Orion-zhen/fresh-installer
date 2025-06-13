# fresh-installer

Installer for fresh systems. Supports Arch Linux and macOS.

## Prerequisites

Please first make sure that you have *stable* network connections.

> Possible solution: clash-verge-rev<sup>archlinuxcn</sup>

For Arch Linux users, please add repositories below into `/etc/pacman.conf`:

```text
[archlinuxcn]
SigLevel = Optional TrustAll
Server = https://mirrors.cernet.edu.cn/archlinuxcn/$arch

[arch4edu]
SigLevel = Optional TrustAll
Server = https://mirrors.cernet.edu.cn/arch4edu/$arch

[our]
# This is my own repository :)
SigLevel = Optional TrustAll
Server = https://orion-zhen.github.io/our/$arch
```

## Usage

Run the command below:

```bash
curl -fsSL https://raw.githubusercontent.com/Orion-zhen/fresh-installer/refs/heads/main/install.sh | bash
```

Then you can navigate to [my .config repository](https://github.com/Orion-zhen/dot-config) for next step configuration.
