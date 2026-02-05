# documentation-hooks

Git hooks and tooling for the Odoo documentation repo.

Installs a **pre-commit hook** that automatically runs [Vale](https://vale.sh/) and the Sphinx linter against staged `.rst` files before each commit.

## Install / Update

Run this single command (safe to re-run):

```bash
(git clone git@github.com:felicious/odoo-documentation-hooks.git ~/Documents/odoo/docs-hooks 2>/dev/null || git -C ~/Documents/odoo/docs-hooks pull) && ~/Documents/odoo/docs-hooks/install.sh
```

### What gets installed

- **Pre-commit hook** copied into your documentation repo's `.git/hooks/`
- **[odoo-vale-linter](https://github.com/felicious/odoo-vale-linter)** cloned if missing (the hook references its `.vale.ini` directly)
- **uv** and **vale** are installed if missing

## Usage

Once installed, the hook runs automatically on `git commit` inside the documentation repo. It only checks **staged** `.rst` files.

To skip checks for a specific commit:

```bash
git commit --no-verify
```

## Troubleshooting

### Unsupported Architecture

This installer is designed for standard Thinkpad/Lenovo laptops (amd64/x86_64 architecture).

If you see an "Unsupported architecture" error:
1. Open an issue at: https://github.com/felicious/docs-hooks/issues
2. Include:
   - Your architecture (shown in the error)
   - Your laptop model
   - Output of: `uname -a`

We'll add support for your architecture if there's demand.
