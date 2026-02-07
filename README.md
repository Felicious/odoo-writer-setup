# Odoo Writer Setup

One-command environment setup for Odoo documentation writers. Installs all tools, clones repos, and configures git hooks.

## Quick Start

Run this single command (safe to re-run at any time):

```bash
(git clone git@github.com:felicious/odoo-writer-setup.git ~/Documents/odoo/odoo-writer-setup 2>/dev/null || git -C ~/Documents/odoo/odoo-writer-setup pull) && ~/Documents/odoo/odoo-writer-setup/setup.sh
```

SSH is required because writers will push to the documentation repo.

## Run Manually (With Options)

If you want skip the apt package installations or don't have sudo, run `setup.sh` directly with `--skip-apt`:

```bash
cd ~/Documents/odoo/odoo-writer-setup
git pull
./setup.sh --skip-apt
```

## What It Does

1. **System packages** — installs git, make, curl, build tools, and image libraries via apt
2. **uv** — installs the [uv](https://github.com/astral-sh/uv) Python package manager (if missing)
3. **vale** — installs the [Vale](https://vale.sh/) prose linter via uv
4. **Directories** — creates `~/Documents/odoo/` workspace
5. **Repos** — clones (or updates) the documentation and [odoo-vale-linter](https://github.com/felicious/odoo-vale-linter) repos
6. **Pre-commit hook** — installs a git hook that automatically runs Vale and the Sphinx linter against staged `.rst` files before each commit

## Configuration

Override default paths via environment variables:

| Variable | Default | Description |
|----------|---------|-------------|
| `DOCS_REPO` | `~/Documents/odoo/documentation` | Path to the documentation repo |
| `VALE_REPO` | `~/Documents/odoo/odoo-vale-linter` | Path to the vale linter config repo |
| `ODOO_DIR` | `~/Documents/odoo` | Parent directory for the workspace |

## Pre-commit Hook

Once installed, the hook runs automatically on `git commit` inside the documentation repo. It only checks **staged** `.rst` files.

What the hook runs:
- **Vale** — style and best-practices linting
- **Sphinx linter** — RST syntax validation (if `tests/main.py` exists in the docs repo)

To skip checks for a specific commit:

```bash
git commit --no-verify
```

## Re-running / Updating

The setup is fully idempotent — safe to re-run at any time. It will update repos and tools to their latest versions.

```bash
cd ~/Documents/odoo/odoo-writer-setup && git pull && ./setup.sh
```

## Requirements

- Ubuntu/Debian (amd64/x86_64)
- sudo access (for apt packages, or use `--skip-apt`)

## Preflight (Recommended)

If you plan to push documentation changes, make sure GitHub SSH auth is working:

```bash
ssh -T git@github.com
```

If that fails, configure your SSH key before running `setup.sh`. The setup script performs this check up front and will stop if SSH isn’t working.

## Troubleshooting

### Unsupported Architecture

This setup is designed for standard Thinkpad/Lenovo laptops (amd64/x86_64).

If you see an "Unsupported architecture" error:
1. Open an issue at: https://github.com/felicious/odoo-writer-setup/issues
2. Include:
   - Your architecture (shown in the error)
   - Your laptop model
   - Output of: `uname -a`

### SSH Clone Fails

The documentation repo is cloned via SSH (`git@github.com:odoo/documentation.git`). If this fails, make sure your SSH key is added to GitHub. See: https://docs.github.com/en/authentication/connecting-to-github-with-ssh
