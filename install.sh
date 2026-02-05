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

# Check architecture early (assume amd64 for Thinkpad/Lenovo laptops)
ARCH=$(uname -m)
if [ "$ARCH" != "x86_64" ]; then
    echo "${RED}❌ Unsupported architecture: $ARCH${RST}"
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

DOCS_REPO="${DOCS_REPO:-$HOME/Documents/odoo/documentation}"
VALE_REPO="${VALE_REPO:-$HOME/Documents/odoo/odoo-vale-linter}"

# Validate documentation repo exists
if [ ! -d "$DOCS_REPO/.git" ]; then
    echo "${RED}❌ Documentation repo not found at $DOCS_REPO${RST}"
    echo ""
    echo "If you already have it cloned elsewhere:"
    echo "  mv /path/to/documentation $DOCS_REPO"
    echo ""
    echo "If you haven't cloned it yet:"
    echo "  git clone git@github.com:odoo/documentation.git $DOCS_REPO"
    exit 1
fi

echo "${MAUVE}${BOLD}📝 Odoo Documentation Hooks Installer${RST}"
echo ""
echo "${GREEN}✅ Found documentation repo${RST}"
echo ""

# Install git hooks
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cp "$SCRIPT_DIR/hooks/pre-commit" "$DOCS_REPO/.git/hooks/pre-commit"
chmod +x "$DOCS_REPO/.git/hooks/pre-commit"
echo "${GREEN}✅ Hook installed${RST}"

# Handle Vale linter repo
if [ -d "$VALE_REPO/.git" ]; then
    echo "${GREEN}✅ Found odoo-vale-linter${RST}"
    git -C "$VALE_REPO" pull --quiet
else
    echo "📦 Cloning odoo-vale-linter..."
    mkdir -p "$(dirname "$VALE_REPO")"
    git clone --quiet https://github.com/felicious/odoo-vale-linter.git "$VALE_REPO"
    echo "${GREEN}✅ Cloned vale-linter${RST}"
fi

# Verify Sphinx linter is set up
if [ ! -f "$DOCS_REPO/tests/main.py" ]; then
    echo "${PEACH}⚠️  tests/main.py not found in documentation repo${RST}"
    echo "${SUBTEXT}   Sphinx linting will be skipped during commits${RST}"
    echo ""
fi

# Check for required tools (uv first — vale install depends on it)
MISSING=()
if ! command -v uv &> /dev/null; then
    MISSING+=("uv")
fi
if ! command -v vale &> /dev/null; then
    MISSING+=("vale")
fi

if [ ${#MISSING[@]} -gt 0 ]; then
    echo "🔧 Installing missing tools: ${MAUVE}${MISSING[*]}${RST}"
    for tool in "${MISSING[@]}"; do
        case "$tool" in
            vale)
                # Install vale via uv (PyPi) since we need python + uv anyways
                # and the alternatives are more complex (download binary + setup PATH)
                # or via snap which require sudo

                # Requires the docutils for rst2html binary
                uv tool install --with-executables-from docutils vale
                ;;
            uv)
                curl -LsSf https://astral.sh/uv/install.sh | sh
                ;;
        esac
    done
    echo "${GREEN}✅ Tools installed${RST}"

    if [[ " ${MISSING[*]} " =~ " uv " ]]; then
        echo "${SUBTEXT}   Restart your terminal or run: source ~/.bashrc${RST}"
    fi
else
    echo "${GREEN}✅ All tools installed${RST}"
fi

# To sync third-party Vale styles (if added to .vale.ini):
#   vale --config="$VALE_REPO/.vale.ini" sync

echo ""
echo "${GREEN}${BOLD}✅ Setup complete!${RST} Your commits will now be checked automatically."
echo ""
echo "${SUBTEXT}To update hooks:${RST}"
echo "  cd ~/Documents/odoo/docs-hooks && git pull && ./install.sh"
echo ""
echo "${SUBTEXT}To skip checks:${RST} git commit --no-verify"
