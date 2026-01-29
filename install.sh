#!/bin/bash
set -eo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Log file support
LOG_FILE="${LOG_FILE:-/tmp/fresh-installer-$(date +%Y%m%d-%H%M%S).log}"
exec > >(tee -a "$LOG_FILE") 2>&1

log() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

show_help() {
    cat << EOF
Usage: $(basename "$0") [OPTIONS]

Fresh Installer - Arch Linux package installer

Options:
    --dry-run        Show what would be done without making changes
    --skip-dotfiles  Skip dotfiles setup
    --help           Show this help message

Environment Variables:
    REPO_BASE_URL    Base URL for remote configuration (default: GitHub)
    LOG_FILE         Path to log file (default: /tmp/fresh-installer-*.log)

Examples:
    ./install.sh                    # Interactive installation
    ./install.sh --dry-run          # Preview changes
    ./install.sh --skip-dotfiles    # Skip dotfiles configuration
    curl -fsSL <url> | bash         # Remote installation

For more information, visit: https://github.com/Orion-zhen/fresh-installer
EOF
}

# Configuration paths
REPO_BASE_URL="${REPO_BASE_URL:-https://raw.githubusercontent.com/Orion-zhen/fresh-installer/main}"
CONFIG_DIR="$(dirname "$(readlink -f "$0")")/config"

# Detect interactive mode
if [ -t 0 ]; then
    INTERACTIVE=true
else
    INTERACTIVE=false
    warn "Running in non-interactive mode (stdin is not a terminal)"
fi

# Check if running locally or piped
if [ ! -d "$CONFIG_DIR" ]; then
    log "Local configuration not found. Fetching from remote..."
    CONFIG_TEMP_DIR=$(mktemp -d)
    mkdir -p "$CONFIG_TEMP_DIR/config"
    
    log "Downloading configuration files..."
    if ! curl -fsSL "$REPO_BASE_URL/config/repos.toml" -o "$CONFIG_TEMP_DIR/config/repos.toml"; then
        error "Failed to download repos.toml from $REPO_BASE_URL"
        exit 1
    fi
    if ! curl -fsSL "$REPO_BASE_URL/config/packages.toml" -o "$CONFIG_TEMP_DIR/config/packages.toml"; then
        error "Failed to download packages.toml from $REPO_BASE_URL"
        exit 1
    fi
    
    CONFIG_DIR="$CONFIG_TEMP_DIR/config"
    trap 'rm -rf "$CONFIG_TEMP_DIR"' EXIT
fi

REPOS_CONFIG="$CONFIG_DIR/repos.toml"
PACKAGES_CONFIG="$CONFIG_DIR/packages.toml"

# State
DRY_RUN=false
SKIP_DOTFILES=false
declare -g -a SELECTED_SECTIONS=()

# Python script to parse TOML
# Arguments: file_path, query_mode, [args...]
parse_toml() {
    python3 -c "
import sys
import tomllib

def get_repos(data):
    for repo in data.get('repo', []):
        print(f\"{repo['name']}|{repo['siglevel']}|{repo['server']}\")

def get_sections(data, prefix=''):
    for section, content in data.items():
        full_key = f'{prefix}.{section}' if prefix else section
        if isinstance(content, dict):
            if 'description' in content:
                print(f\"{full_key}|{content['description']}\")
            else:
                # Recurse into nested sections
                get_sections(content, full_key)

def get_packages(data, section):
    keys = section.split('.')
    val = data
    for k in keys:
        val = val.get(k, {})
    for pkg in val.get('packages', []):
        print(pkg)

try:
    with open(sys.argv[1], 'rb') as f:
        data = tomllib.load(f)
    mode = sys.argv[2]
    if mode == 'repos':
        get_repos(data)
    elif mode == 'sections':
        get_sections(data)
    elif mode == 'packages':
        get_packages(data, sys.argv[3])
except Exception as e:
    sys.stderr.write(str(e))
    sys.exit(1)
" "$@"
}

check_dependencies() {
    log "Checking core dependencies..."
    if ! command -v python3 &>/dev/null; then
        warn "Python3 not found. Installing..."
        if [ "$DRY_RUN" = false ]; then
            sudo pacman -Sy --noconfirm python
        fi
    fi
    if ! command -v git &>/dev/null; then
        warn "Git not found. Installing..."
        if [ "$DRY_RUN" = false ]; then
            sudo pacman -S --noconfirm git
        fi
    fi
}

configure_pacman() {
    log "Configuring pacman repositories..."
    if [ ! -f "$REPOS_CONFIG" ]; then
        error "Repos config not found at $REPOS_CONFIG"
        exit 1
    fi

    # Backup pacman.conf
    if [ "$DRY_RUN" = false ]; then
        if [ ! -f /etc/pacman.conf.bak ]; then
            sudo cp /etc/pacman.conf /etc/pacman.conf.bak
            success "Backed up pacman.conf to pacman.conf.bak"
        fi
    fi

    # Parse and append repos (using process substitution to avoid subshell issues with set -e)
    while IFS='|' read -r name siglevel server; do
        if grep -q "\[$name\]" /etc/pacman.conf; then
            log "Repo [$name] already exists in pacman.conf, skipping..."
        else
            log "Adding repo [$name]..."
            if [ "$DRY_RUN" = false ]; then
                echo -e "\n[$name]\nSigLevel = $siglevel\nServer = $server" | sudo tee -a /etc/pacman.conf >/dev/null
            fi
        fi
    done < <(parse_toml "$REPOS_CONFIG" "repos")

    if [ "$DRY_RUN" = false ]; then
        sudo pacman -Sy
        # Handles archlinuxcn-keyring if archlinuxcn is present
        if grep -q "\[archlinuxcn\]" /etc/pacman.conf; then
            if ! pacman -Qs archlinuxcn-keyring >/dev/null; then
                log "Installing archlinuxcn-keyring..."
                sudo pacman -S --noconfirm archlinuxcn-keyring
            fi
        fi
    fi
}

install_yay() {
    if command -v yay &>/dev/null; then
        log "yay is already installed."
        return
    fi
    
    log "Installing yay..."
    if [ "$DRY_RUN" = true ]; then
        return
    fi

    # Ensure base-devel
    sudo pacman -S --needed --noconfirm base-devel

    YAY_TEMP_DIR=$(mktemp -d)
    git clone https://aur.archlinux.org/yay.git "$YAY_TEMP_DIR/yay"
    pushd "$YAY_TEMP_DIR/yay" > /dev/null
    makepkg -si --noconfirm
    popd > /dev/null
    rm -rf "$YAY_TEMP_DIR"
}

select_components() {
    echo -e "${CYAN}=== Select Components to Install ===${NC}"
    echo "Using configuration from: $PACKAGES_CONFIG"
    
    # Get all sections
    mapfile -t SECTIONS < <(parse_toml "$PACKAGES_CONFIG" "sections")
    
    SELECTED_SECTIONS=()
    
    # If no interactive tool like whiptail, use simple select loop
    # But simple select is hard for multiple choice.
    # Let's verify each section.
    
    echo "Available categories:"
    for i in "${!SECTIONS[@]}"; do
        IFS='|' read -r code desc <<< "${SECTIONS[$i]}"
        printf "%2d) %-20s %s\n" $((i+1)) "[$code]" "$desc"
    done
    
    echo
    echo "Enter numbers separated by space (e.g., '1 2 4'), 'all' for everything,"
    echo "or use '^N' to exclude (e.g., '^1 ^2' = all except 1 and 2)."
    echo "Press Enter directly to select all."
    
    if [ "$INTERACTIVE" = true ]; then
        read -p "Selection [all] > " SELECTION
        # Default to 'all' if empty input
        SELECTION="${SELECTION:-all}"
    else
        # Non-interactive mode: install all by default
        warn "Non-interactive mode: selecting all packages"
        SELECTION="all"
    fi
    
    # Check if using inverse selection (starts with ^)
    if [[ "$SELECTION" =~ ^\^ ]]; then
        # Inverse selection mode: start with all, then exclude
        declare -A EXCLUDED
        for token in $SELECTION; do
            if [[ "$token" =~ ^\^([0-9]+)$ ]]; then
                EXCLUDED["${BASH_REMATCH[1]}"]=1
            fi
        done
        
        for i in "${!SECTIONS[@]}"; do
            num=$((i+1))
            if [[ -z "${EXCLUDED[$num]}" ]]; then
                IFS='|' read -r code _ <<< "${SECTIONS[$i]}"
                SELECTED_SECTIONS+=("$code")
            fi
        done
        
        log "Inverse selection: excluding ${!EXCLUDED[*]}"
    elif [[ "$SELECTION" == "all" ]]; then
        for item in "${SECTIONS[@]}"; do
            IFS='|' read -r code _ <<< "$item"
            SELECTED_SECTIONS+=("$code")
        done
    else
        for num in $SELECTION; do
            if [[ "$num" =~ ^[0-9]+$ ]] && [ "$num" -le "${#SECTIONS[@]}" ] && [ "$num" -gt 0 ]; then
                IDX=$((num-1))
                IFS='|' read -r code _ <<< "${SECTIONS[$IDX]}"
                SELECTED_SECTIONS+=("$code")
            fi
        done
    fi
}

install_packages() {
    local PKG_LIST=()
    
    log "Gathering package list..."
    for section in "${SELECTED_SECTIONS[@]}"; do
        log "Processing section: [$section]"
        while read -r pkg; do
            PKG_LIST+=("$pkg")
        done < <(parse_toml "$PACKAGES_CONFIG" "packages" "$section")
    done
    
    if [ ${#PKG_LIST[@]} -eq 0 ]; then
        warn "No packages selected."
        return
    fi
    
    # Remove duplicates safely using mapfile
    mapfile -t PKG_LIST < <(printf "%s\n" "${PKG_LIST[@]}" | sort -u)
    
    echo -e "${CYAN}The following ${#PKG_LIST[@]} packages will be installed:${NC}"
    echo "${PKG_LIST[*]}"
    
    if [ "$DRY_RUN" = true ]; then
        log "Dry run complete. No changes were made."
        return
    fi
    
    if [ "$INTERACTIVE" = true ]; then
        read -p "Proceed? [y/N] " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log "Installation aborted by user."
            exit 0
        fi
    else
        log "Non-interactive mode: proceeding with installation..."
    fi

    log "Installing packages using yay..."
    if ! yay -S --needed --noconfirm "${PKG_LIST[@]}"; then
        error "Some packages failed to install. Check the log at $LOG_FILE"
        warn "You can retry failed packages manually."
    fi
}

setup_dotfiles() {
    if [ "$SKIP_DOTFILES" = true ]; then
        log "Skipping dotfiles setup."
        return
    fi
    
    log "Setting up dotfiles..."
    if [ "$DRY_RUN" = true ]; then
         return
    fi
    
    if [ -d "$HOME/.config" ] && [ ! -d "$HOME/.config.bak" ]; then
        cp -r "$HOME/.config" "$HOME/.config.bak"
    fi
    
    rm -rf "$HOME/.config"
    mkdir -p "$HOME/.config"
    
    # Clone directly into .config or use specific logic
    # Original script logic:
    cd "$HOME/.config"
    git init -b main
    git remote add origin https://github.com/Orion-zhen/dot-config.git
    git fetch
    git reset --hard origin/main
    git branch --set-upstream-to origin/main
    
    # Restore backups if needed? The original script copied back everything non-clashing.
    # But usually one wants the repo to be the source of truth.
    # Merging back old configs:
    if [ -d "$HOME/.config.bak" ]; then
        cp -rn "$HOME/.config.bak/"* "$HOME/.config/"
        rm -rf "$HOME/.config.bak"
    fi
    
    success "Dotfiles configured."
}

# Parse Args
while [[ "$#" -gt 0 ]]; do
    case $1 in
        --dry-run) DRY_RUN=true ;;
        --skip-dotfiles) SKIP_DOTFILES=true ;;
        --help|-h) show_help; exit 0 ;;
        *) error "Unknown parameter passed: $1"; show_help; exit 1 ;;
    esac
    shift
done

# Main Execution
echo -e "${CYAN}=== Fresh Installer ===${NC}"
log "Log file: $LOG_FILE"
log "Interactive mode: $INTERACTIVE"
[ "$DRY_RUN" = true ] && warn "Running in dry-run mode"

check_dependencies
configure_pacman
install_yay
select_components
install_packages
setup_dotfiles

success "Installation Complete!"
log "Full log saved to: $LOG_FILE"
