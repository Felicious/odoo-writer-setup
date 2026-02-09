#!/bin/bash
set -e
trap 'exit 130' INT

# Catppuccin Mocha colors (truecolor)
GREEN=$'\033[38;2;166;227;161m'
PEACH=$'\033[38;2;250;179;135m'
RED=$'\033[38;2;243;139;168m'
MAUVE=$'\033[38;2;203;166;247m'
SUBTEXT=$'\033[38;2;166;173;200m'
BOLD=$'\033[1m'
RST=$'\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOCS_REPO="${DOCS_REPO:-$HOME/Documents/odoo/documentation}"
VALE_REPO="${VALE_REPO:-$HOME/Documents/odoo/odoo-vale-linter}"
ODOO_DIR="${ODOO_DIR:-$HOME/Documents/odoo}"

# --- Step functions ---

check_architecture() {
    local arch
    arch=$(uname -m)
    if [ "$arch" != "x86_64" ]; then
        echo "${RED}Unsupported architecture: $arch${RST}"
        echo ""
        echo "This setup is designed for amd64/x86_64 systems (Thinkpad/Lenovo laptops)."
        echo ""
        echo "Action required:"
        echo "  Please open an issue at: https://github.com/felicious/odoo-writer-setup/issues"
        echo "  Include:"
        echo "    - Your architecture: $arch"
        echo "    - Your laptop model"
        echo "    - Output of: uname -a"
        return 1
    fi
}

check_system() {
    if ! command -v apt-get &> /dev/null; then
        echo "${RED}apt-get not found. This setup requires a Debian/Ubuntu system.${RST}"
        return 1
    fi
}

check_shell() {
    if [ -z "$SHELL" ] || [[ ! "$SHELL" =~ bash$ ]]; then
        echo "${PEACH}Note: Your login shell is not bash${RST}"
        echo "${SUBTEXT}   Starship will be configured for bash anyway${RST}"
        echo "${SUBTEXT}   If you use zsh/fish, configure manually: https://starship.rs/guide/#step-2-set-up-your-shell-to-use-starship${RST}"
    fi
}

check_github_ssh() {
    if ! command -v ssh &> /dev/null; then
        echo "${RED}ssh not found. Please install OpenSSH client and try again.${RST}"
        return 1
    fi

    echo "${MAUVE}${BOLD}Checking GitHub SSH authentication...${RST}"
    local output
    output=$(ssh -o BatchMode=yes -o StrictHostKeyChecking=accept-new -T git@github.com 2>&1 || true)

    if echo "$output" | grep -qi "successfully authenticated"; then
        echo "${GREEN}GitHub SSH authentication OK${RST}"
        return 0
    fi

    echo "${RED}GitHub SSH authentication failed.${RST}"
    echo "${SUBTEXT}   Run: ssh -T git@github.com${RST}"
    echo "${SUBTEXT}   Then add your SSH public key to GitHub and re-run setup.${RST}"
    return 1
}

install_apt_packages() {
    echo "${MAUVE}${BOLD}Installing system packages...${RST}"
    sudo apt-get update -qq
    sudo apt-get install -y --no-install-recommends \
        git \
        make \
        curl \
        ca-certificates \
        build-essential \
        pngquant \
        imagemagick \
        python3 \
        python3-dev \
        libpng-dev \
        libjpeg-dev \
        zlib1g-dev \
        libfreetype-dev \
        libffi-dev \
        libxml2-dev \
        libxslt1-dev
    echo "${GREEN}System packages installed${RST}"
}

install_uv() {
    if command -v uv &> /dev/null; then
        echo "${GREEN}uv already installed${RST}"
        return 0
    fi
    echo "Installing uv..."
    curl -LsSf https://astral.sh/uv/install.sh | sh
    export PATH="$HOME/.local/bin:$PATH"
    echo "${GREEN}uv installed${RST}"
}

install_vale() {
    echo "Installing vale via uv..."
    uv tool install --with-executables-from docutils vale
    echo "${GREEN}vale installed${RST}"
}

install_starship() {
    if command -v starship &> /dev/null; then
        echo "${GREEN}starship already installed${RST}"
        return 0
    fi
    echo "Installing starship..."
    curl -sS https://starship.rs/install.sh | sh -s -- --yes
    export PATH="$HOME/.local/bin:$PATH"
    echo "${GREEN}starship installed${RST}"
}

configure_bashrc() {
    local NEEDS_UPDATE=0

    if [ ! -f "$HOME/.bashrc" ]; then
        echo "${PEACH}Creating new .bashrc file${RST}"
        touch "$HOME/.bashrc"
        NEEDS_UPDATE=1
    fi

    # Check if PATH already includes ~/.local/bin
    # shellcheck disable=SC2016  # We want the literal string '$HOME/.local/bin'
    if ! grep -qF '$HOME/.local/bin' "$HOME/.bashrc"; then
        NEEDS_UPDATE=1
    fi

    # Check if starship is already configured
    if ! grep -qF "starship init bash" "$HOME/.bashrc"; then
        NEEDS_UPDATE=1
    fi

    if [ "$NEEDS_UPDATE" -eq 0 ]; then
        echo "${GREEN}shell already configured in .bashrc${RST}"
        return 0
    fi

    # Add PATH if not present
    # shellcheck disable=SC2016  # We want the literal string '$HOME/.local/bin'
    if ! grep -qF '$HOME/.local/bin' "$HOME/.bashrc"; then
        cat >> "$HOME/.bashrc" << 'EOF'

# Add user binaries to PATH (added by odoo-writer-setup)
export PATH="$HOME/.local/bin:$PATH"
EOF
        echo "${GREEN}Added ~/.local/bin to PATH in .bashrc${RST}"
    fi

    # Add starship if not present
    if ! grep -qF "starship init bash" "$HOME/.bashrc"; then
        cat >> "$HOME/.bashrc" << 'EOF'

# Starship prompt (added by odoo-writer-setup)
eval "$(starship init bash)"
EOF
        echo "${GREEN}starship configured in .bashrc${RST}"
    fi

    echo "${SUBTEXT}   Run: source ~/.bashrc${RST}"
}

create_directories() {
    mkdir -p "$ODOO_DIR"
    echo "${GREEN}Directory structure ready ($ODOO_DIR)${RST}"
}

clone_or_update_repos() {
    # Documentation repo
    if [ -d "$DOCS_REPO/.git" ]; then
        echo "${GREEN}Found documentation repo${RST}"
        git -C "$DOCS_REPO" pull --quiet 2>/dev/null || true
    else
        echo "Cloning documentation repo..."
        mkdir -p "$(dirname "$DOCS_REPO")"
        if ! git clone git@github.com:odoo/documentation.git "$DOCS_REPO"; then
            echo "${RED}Failed to clone documentation repo via SSH.${RST}"
            echo "${SUBTEXT}   Configure your GitHub SSH key and re-run setup.${RST}"
            echo "${SUBTEXT}   See README: SSH setup instructions.${RST}"
            return 1
        fi
        echo "${GREEN}Cloned documentation repo to $DOCS_REPO${RST}"
    fi

    # Vale linter repo
    if [ -d "$VALE_REPO/.git" ]; then
        echo "${GREEN}Found odoo-vale-linter${RST}"
        git -C "$VALE_REPO" pull --quiet 2>/dev/null || true
    else
        echo "Cloning odoo-vale-linter..."
        mkdir -p "$(dirname "$VALE_REPO")"
        git clone --quiet https://github.com/felicious/odoo-vale-linter.git "$VALE_REPO"
        echo "${GREEN}Cloned odoo-vale-linter to $VALE_REPO${RST}"
    fi
}

install_hook() {
    if [ ! -d "$DOCS_REPO/.git" ]; then
        echo "${RED}Documentation repo not found at $DOCS_REPO, skipping hook install${RST}"
        return 1
    fi

    cp "$SCRIPT_DIR/hooks/pre-commit" "$DOCS_REPO/.git/hooks/pre-commit"
    chmod +x "$DOCS_REPO/.git/hooks/pre-commit"
    echo "${GREEN}Pre-commit hook installed${RST}"

    if [ ! -f "$DOCS_REPO/tests/main.py" ]; then
        echo "${PEACH}  tests/main.py not found in documentation repo${RST}"
        echo "${SUBTEXT}   Sphinx linting will be skipped during commits${RST}"
    fi
}

install_optimize_images_script() {
    local BIN_DIR="$HOME/.local/bin"
    local SCRIPT_SOURCE="$SCRIPT_DIR/scripts/optimize-images.sh"
    local SCRIPT_TARGET="$BIN_DIR/optimize-images"

    mkdir -p "$BIN_DIR"

    if [ -L "$SCRIPT_TARGET" ]; then
        echo "${GREEN}optimize-images already in PATH${RST}"
    elif [ -f "$SCRIPT_TARGET" ]; then
        echo "${YELLOW}Warning: $SCRIPT_TARGET exists but is not a symlink${RST}"
    else
        ln -s "$SCRIPT_SOURCE" "$SCRIPT_TARGET"
        echo "${GREEN}Installed optimize-images to PATH${RST}"
    fi
}

verify_installation() {
    echo ""
    echo "${MAUVE}${BOLD}Verification${RST}"
    local ok=true

    for tool in git make uv vale pngquant identify optimize-images starship; do
        if command -v "$tool" &> /dev/null; then
            echo "${GREEN}  $tool found${RST}"
        else
            echo "${PEACH}  $tool not found${RST}"
            ok=false
        fi
    done

    if [ -d "$DOCS_REPO/.git" ]; then
        echo "${GREEN}  documentation repo present${RST}"
    else
        echo "${PEACH}  documentation repo missing${RST}"
        echo "${SUBTEXT}   SSH may not be configured for GitHub${RST}"
        ok=false
    fi

    if [ -d "$VALE_REPO/.git" ]; then
        echo "${GREEN}  odoo-vale-linter present${RST}"
    else
        echo "${PEACH}  odoo-vale-linter missing${RST}"
        ok=false
    fi

    if [ -x "$DOCS_REPO/.git/hooks/pre-commit" ]; then
        echo "${GREEN}  pre-commit hook installed${RST}"
    else
        echo "${PEACH}  pre-commit hook missing${RST}"
        ok=false
    fi

    if [ -f "$HOME/.bashrc" ] && grep -qF "starship init bash" "$HOME/.bashrc"; then
        echo "${GREEN}  starship configured in .bashrc${RST}"
    else
        echo "${PEACH}  starship not configured in .bashrc${RST}"
        ok=false
    fi

    if [ "$ok" = true ]; then
        echo ""
        echo "${GREEN}${BOLD}Setup complete!${RST} Your commits will now be checked automatically."
    else
        echo ""
        echo "${PEACH}${BOLD}Setup finished with warnings.${RST} Check above for details."
    fi

    echo ""
    echo "${SUBTEXT}To update:${RST}"
    echo "  cd $SCRIPT_DIR && git pull && ./setup.sh"
    echo ""
    echo "${SUBTEXT}To skip pre-commit checks:${RST} git commit --no-verify"
}

main() {
    local skip_apt=false
    local skip_ssh=false
    for arg in "$@"; do
        case "$arg" in
            --skip-apt) skip_apt=true ;;
            --skip-ssh|--skip-github-ssh) skip_ssh=true ;;
        esac
    done

    echo "${MAUVE}${BOLD}Odoo Writer Setup${RST}"
    echo ""

    check_architecture
    check_system
    check_shell

    if [ "$skip_apt" = false ]; then
        install_apt_packages
    else
        echo "${SUBTEXT}Skipping apt packages (--skip-apt)${RST}"
    fi

    install_uv
    install_vale
    install_starship
    configure_bashrc
    create_directories
    if [ "${SKIP_GITHUB_SSH_CHECK:-0}" = "1" ] || [ "$skip_ssh" = true ]; then
        echo "${SUBTEXT}Skipping GitHub SSH check${RST}"
    else
        check_github_ssh
    fi
    clone_or_update_repos
    install_hook
    install_optimize_images_script
    verify_installation
}

# Main guard: only run main() when executed directly (not sourced)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
