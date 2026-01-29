# Fresh Installer

A modern, automated post-installation setup script for Arch Linux.

## Features

- **Modular Configuration**: Packages and repositories are defined in easy-to-read TOML files.
- **Interactive Selection**: Choose which component groups to install via a menu.
- **Automated setup**:
  - Configures `pacman.conf` with third-party repositories (archlinuxcn, etc.).
  - Installs AUR helper (`yay`) automatically.
  - Sets up dotfiles from [your config repo](https://github.com/Orion-zhen/dot-config).
- **Safe**: Supports `--dry-run` mode to preview changes.

## Prerequisites

- **Arch Linux** installation.
- Working internet connection.
- `base-devel`, `git`, and `python` (script handles installation if missing).

## Usage

### One-Step Installation

```bash
curl -fsSL https://raw.githubusercontent.com/Orion-zhen/fresh-installer/main/install.sh | bash
```

### Manual Usage

1. Clone the repository:
   ```bash
   git clone https://github.com/Orion-zhen/fresh-installer.git
   cd fresh-installer
   ```

2. Run the installer:
   ```bash
   ./install.sh
   ```

### Options

- `--dry-run`: Simulate actions without making changes.
- `--skip-dotfiles`: Skip the dotfiles setup step.

## Configuration

Modify files in `config/` to customize your installation:

- **[repos.toml](config/repos.toml)**: Add or remove third-party Pacman repositories.
- **[packages.toml](config/packages.toml)**: Manage packages and groups.
