#!/bin/bash
set -e

# Check architecture early (assume amd64 for Thinkpad/Lenovo laptops)
ARCH=$(uname -m)
if [ "$ARCH" != "x86_64" ]; then
    echo "Error: Unsupported architecture detected: $ARCH"
    echo ""
    echo "This installer is designed for amd64/x86_64 systems (Thinkpad/Lenovo laptops)."
    echo ""
    echo "Action required:"
    echo "  Please open an issue at: https://github.com/felicious/docs-hooks/issues"
    echo "  Include:"
    echo "    - Your architecture: $ARCH"
    echo "    - Your laptop model"
    echo "    - Output of: uname -a"
    exit 1
fi

GUM_VERSION="${GUM_VERSION:-0.17.0}"
DOCS_REPO="${DOCS_REPO:-$HOME/Documents/odoo/documentation}"
VALE_REPO="${VALE_REPO:-$HOME/Documents/odoo/odoo-vale-linter}"

# CI mode: non-interactive fallbacks for gum
if [ -n "$CI" ]; then
    gum() {
        case "$1" in
            confirm) return 0 ;;
            spin) while [ "$1" != "--" ]; do shift; done; shift; "$@" > /dev/null ;;
            style) ;;
        esac
    }
fi

# Validate documentation repo exists
if [ ! -d "$DOCS_REPO/.git" ]; then
    echo "Error: Documentation repo not found"
    echo ""
    echo "Expected location: $DOCS_REPO"
    echo ""
    echo "Action required:"
    echo "  1. Clone the repo: git clone git@github.com:odoo/documentation.git"
    echo "  2. Move it to: $DOCS_REPO"
    echo "  3. Run this installer again"
    exit 1
fi

echo "✓ Architecture: $ARCH (amd64)"
echo "✓ Found documentation repo at: $DOCS_REPO"
echo ""

# Install gum for better UX (hardcoded amd64)
if [ -z "$CI" ] && ! command -v gum &> /dev/null; then
    echo "Installing Gum v${GUM_VERSION}..."
    TEMP_DIR=$(mktemp -d)
    curl -sL "https://github.com/charmbracelet/gum/releases/download/v${GUM_VERSION}/gum_${GUM_VERSION}_Linux_x86_64.tar.gz" | \
        tar xz -C "$TEMP_DIR" --strip-components=1
    mkdir -p "$HOME/.local/bin"
    mv "$TEMP_DIR/gum" "$HOME/.local/bin/"
    rm -rf "$TEMP_DIR"

    # Add to PATH if needed
    if [[ ":$PATH:" != *":$HOME/.local/bin:"* ]]; then
        # shellcheck disable=SC2016
        echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$HOME/.bashrc"
        export PATH="$HOME/.local/bin:$PATH"
    fi
    echo "✓ Gum installed"
    echo ""
fi

gum style --foreground 212 --bold "📝 Odoo Documentation Hooks Installer"
echo ""

# Install git hooks
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
gum spin --spinner dot --title "Installing pre-commit hook..." -- \
    cp "$SCRIPT_DIR/hooks/pre-commit" "$DOCS_REPO/.git/hooks/pre-commit"
chmod +x "$DOCS_REPO/.git/hooks/pre-commit"
gum style --foreground 212 "✓ Hook installed"

# Handle Vale linter repo
if [ -d "$VALE_REPO/.git" ]; then
    gum style --foreground 212 "✓ Found odoo-vale-linter"
    if gum confirm "Update vale-linter repo?"; then
        gum spin --spinner dot --title "Updating vale-linter..." -- \
            git -C "$VALE_REPO" pull
    fi
else
    gum spin --spinner dot --title "Cloning odoo-vale-linter..." -- \
        bash -c "mkdir -p '$(dirname "$VALE_REPO")' && \
                 git clone https://github.com/felicious/odoo-vale-linter.git '$VALE_REPO'"
    gum style --foreground 212 "✓ Cloned vale-linter"
fi

echo ""
gum style --border normal --padding "0 1" --border-foreground 212 \
    "Checking required tools..."
echo ""

# Check for required tools
MISSING=()
if ! command -v vale &> /dev/null; then
    MISSING+=("vale")
fi
if ! command -v uv &> /dev/null; then
    MISSING+=("uv")
fi

# Verify Sphinx linter is set up
if [ ! -f "$DOCS_REPO/tests/main.py" ]; then
    gum style --foreground 208 "⚠ Warning: tests/main.py not found in documentation repo"
    gum style --foreground 245 "  Sphinx linting will be skipped during commits"
    echo ""
fi

if [ ${#MISSING[@]} -gt 0 ]; then
    gum style --foreground 208 "Missing tools:"
    for tool in "${MISSING[@]}"; do
        gum style --foreground 212 "  • $tool"
    done
    echo ""

    if gum confirm "Install missing tools now?"; then
        for tool in "${MISSING[@]}"; do
            case "$tool" in
                vale)
                    gum spin --spinner dot --title "Installing vale..." -- \
                        sudo snap install vale
                    ;;
                uv)
                    gum spin --spinner dot --title "Installing uv..." -- \
                        bash -c 'curl -LsSf https://astral.sh/uv/install.sh | sh'
                    ;;
            esac
        done
        gum style --foreground 212 "✓ Tools installed"

        if [[ " ${MISSING[*]} " =~ " uv " ]]; then
            gum style --foreground 245 "  Note: Restart your terminal or run: source ~/.bashrc"
        fi
    fi
else
    gum style --foreground 212 "✓ All tools installed"
fi

# To sync third-party Vale styles (if added to .vale.ini):
#   vale --config="$VALE_REPO/.vale.ini" sync

echo ""

gum style \
    --border double \
    --padding "1 2" \
    --border-foreground 212 \
    --bold \
    "✓ Setup Complete!" \
    "" \
    "Your commits will now be checked automatically." \
    "" \
    "To update hooks:" \
    "  cd ~/Documents/odoo/docs-hooks && git pull && ./install.sh" \
    "" \
    "To skip checks: git commit --no-verify"
