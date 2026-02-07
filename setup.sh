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

install_apt_packages() {
    echo "${MAUVE}${BOLD}Installing system packages...${RST}"
    sudo apt-get update -qq
    sudo apt-get install -y --no-install-recommends \
        git \
        make \
        curl \
        ca-certificates \
        build-essential \
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
        git clone git@github.com:odoo/documentation.git "$DOCS_REPO"
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

verify_installation() {
    echo ""
    echo "${MAUVE}${BOLD}Verification${RST}"
    local ok=true

    for tool in git make uv vale; do
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
    for arg in "$@"; do
        case "$arg" in
            --skip-apt) skip_apt=true ;;
        esac
    done

    echo "${MAUVE}${BOLD}Odoo Writer Setup${RST}"
    echo ""

    check_architecture
    check_system

    if [ "$skip_apt" = false ]; then
        install_apt_packages
    else
        echo "${SUBTEXT}Skipping apt packages (--skip-apt)${RST}"
    fi

    install_uv
    install_vale
    create_directories
    clone_or_update_repos
    install_hook
    verify_installation
}

# Main guard: only run main() when executed directly (not sourced)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
