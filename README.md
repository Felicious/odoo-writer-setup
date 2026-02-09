# Odoo Writer Setup

One-command environment setup for Odoo documentation writers. Installs all tools, clones repos, and configures git hooks.

## Prerequisites

**Configure GitHub SSH authentication first.** The setup script clones repositories via SSH and will fail if your SSH key isn't configured.

1. **Generate an SSH key** (if you don't have one):
   ```bash
   ssh-keygen -t ed25519 -C "your_email@example.com"
   ```

2. **Add your SSH key to GitHub**:
   - Copy your public key: `cat ~/.ssh/id_ed25519.pub`
   - Go to GitHub → Settings → SSH and GPG keys → New SSH key
   - Paste your public key

3. **Verify it works**:
   ```bash
   ssh -T git@github.com
   ```
   You should see: `Hi username! You've successfully authenticated...`

See the full guide: https://docs.github.com/en/authentication/connecting-to-github-with-ssh

## Quick Start

Run this single command to set up your environment:

```bash
(git clone git@github.com:felicious/odoo-writer-setup.git ~/Documents/odoo/odoo-writer-setup 2>/dev/null || git -C ~/Documents/odoo/odoo-writer-setup pull) && ~/Documents/odoo/odoo-writer-setup/setup.sh
```

This installs Vale linter, the `optimize-images` tool, clones documentation repos, and sets up git hooks to validate your work before commits.

> [!TIP]
> After setup completes, run `source ~/.bashrc` or open a new terminal to activate changes.

## What It Does

The setup script:

1. **System packages** — installs git, make, curl, ImageMagick, pngquant, and other build tools via apt
2. **uv** — installs the [uv](https://github.com/astral-sh/uv) Python package manager (if missing)
3. **vale** — installs the [Vale](https://vale.sh/) prose linter via uv
4. **optimize-images** — installs the image optimization tool to `~/.local/bin` (added to PATH)
5. **Directories** — creates `~/Documents/odoo/` workspace
6. **Repos** — clones (or updates) the documentation and [odoo-vale-linter](https://github.com/felicious/odoo-vale-linter) repos
7. **Pre-commit hook** — installs a git hook that validates `.rst` files and PNG images before each commit

## Pre-commit Hook

Once installed, the hook runs automatically on `git commit` inside the documentation repo. It validates both `.rst` files and PNG images.

What the hook validates:
- **Vale** — style and best-practices linting for `.rst` files
- **Sphinx linter** — RST syntax validation (if `tests/main.py` exists in the docs repo)
- **PNG images** — validates width (≤768px or exactly 933px) and color depth (≤8-bit)

If image validation fails, the hook will show clear instructions to run `optimize-images`.

> [!TIP]
> To skip checks for a specific commit, use:
> ```bash
> git commit --no-verify
> ```

## Image Optimization

The `optimize-images` command helps you prepare PNG images for documentation. It resizes images and optimizes file size while maintaining quality.

> [!IMPORTANT]
> Without file arguments, `optimize-images` only processes **modified** PNG files (staged, unstaged, or untracked). It won't touch existing committed images unless they've been changed.

### Usage

```bash
# Optimize all modified PNG images (default 768px)
optimize-images

# Resize specific images to 933px (for wider screenshots)
optimize-images --width 933 screenshot.png

# Skip confirmation prompt (for scripts)
optimize-images -y
```

### Image Requirements

> [!NOTE]
> Documentation images must meet these requirements (enforced by pre-commit hook):
> - **Width**: ≤768px OR exactly 933px
> - **Color depth**: ≤8-bit (256 colors)
>
> **Why these sizes?**
> - **768px** — standard width for most documentation images (fits well in docs)
> - **933px** — exception for screenshots that need extra width (e.g., wide UI elements)

### Workflow Examples

**Basic workflow (all images 768px):**
```bash
# Add/edit PNG images
optimize-images          # Shows what will change, asks confirmation
git add .
git commit -m "Add images"
```

**Mixed widths (some images need 933px):**
```bash
# First, resize specific images to 933px
optimize-images --width 933 wide-screenshot.png

# Then optimize everything else
optimize-images          # Preserves 933px, resizes others to 768px

git add .
git commit -m "Add screenshots"
```

**Force everything to specific width:**
```bash
# Force all images to 768px (including any 933px)
optimize-images --width 768

# Or force all to 933px
optimize-images --width 933
```

> [!TIP]
> Originals are backed up to `~/.cache/odoo-docs-image-originals/` before any modifications. You can restore from backups if needed.

## Re-running / Updating

The setup is fully idempotent — safe to re-run at any time. It will update repos and tools to their latest versions.

```bash
cd ~/Documents/odoo/odoo-writer-setup && git pull && ./setup.sh
```

## Troubleshooting

### System Requirements

This setup requires:
- Ubuntu/Debian (amd64/x86_64)
- Bash shell (zsh/fish not currently supported)
- sudo access (or use `--skip-apt` flag)

> [!NOTE]
> The setup script configures `~/.bashrc` and requires bash. If you use zsh or fish, you'll need to manually configure your shell after setup.

### Unsupported Architecture

This setup is designed for standard Thinkpad/Lenovo laptops (amd64/x86_64).

If you see an "Unsupported architecture" error:
1. Open an issue at: https://github.com/felicious/odoo-writer-setup/issues
2. Include:
   - Your architecture (shown in the error)
   - Your laptop model
   - Output of: `uname -a`

### SSH Clone Fails

> [!WARNING]
> The documentation repo is cloned via SSH (`git@github.com:odoo/documentation.git`). If this fails, make sure your SSH key is added to GitHub.
>
> See: https://docs.github.com/en/authentication/connecting-to-github-with-ssh

## Advanced Configuration

### Run Manually (With Options)

If you want skip the apt package installations or don't have sudo, run `setup.sh` directly with `--skip-apt`:

```bash
cd ~/Documents/odoo/odoo-writer-setup
git pull
./setup.sh --skip-apt
```

### Environment Variables

Override default paths via environment variables:

| Variable | Default | Description |
|----------|---------|-------------|
| `DOCS_REPO` | `~/Documents/odoo/documentation` | Path to the documentation repo |
| `VALE_REPO` | `~/Documents/odoo/odoo-vale-linter` | Path to the vale linter config repo |
| `ODOO_DIR` | `~/Documents/odoo` | Parent directory for the workspace |

### Shell Configuration

Setup automatically adds to your `~/.bashrc`:
- `~/.local/bin` to PATH (for `optimize-images` and other tools)
- Starship prompt initialization

### Advanced Image Optimization

#### Command Reference

| Command | Effect |
|---------|--------|
| `optimize-images` | Optimize all **modified** PNGs (default 768px, preserves 933px) |
| `optimize-images file.png` | Optimize specific file to 768px |
| `optimize-images --width 933` | Resize all **modified** PNGs to 933px |
| `optimize-images --width 933 file.png` | Resize specific file to 933px |
| `optimize-images --width 768 file.png` | Force 933px image back to 768px |
| `optimize-images -y` | Skip confirmation prompt |

**Modified** = staged, unstaged, or untracked PNG files (not the entire repository)

#### What It Does

1. **Discovers** modified PNG files (staged, unstaged, or untracked) — or uses specific files you provide
2. **Analyzes** images and shows planned changes
3. **Asks confirmation** (unless `-y` flag is used)
4. **Backs up** originals to `~/.cache/odoo-docs-image-originals/`
5. **Resizes** to target width (default 768px)
6. **Optimizes** to 8-bit color depth using pngquant
7. **Shows instructions** for recovering originals or using 933px

> [!NOTE]
> When run without file arguments, only processes images you've added or modified, not the entire repository.

#### Behavior Details

> [!NOTE]
> **How width targeting works:**
> - **No `--width` flag**: Resizes to 768px, but preserves any 933px images (writer-friendly default)
> - **With `--width 768`**: Forces everything to 768px, including 933px images (explicit override)
> - **With `--width 933`**: Forces everything to 933px (for wide screenshots)
