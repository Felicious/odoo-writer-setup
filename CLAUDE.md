# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Odoo Writer Setup is a one-command environment setup tool for Odoo documentation writers. It automates installation of required tools (Vale linter, uv package manager), clones documentation repositories, and configures git pre-commit hooks for documentation quality checks.

## Commands

### Running Setup
```bash
./setup.sh                    # Full setup (requires sudo for apt)
./setup.sh --skip-apt         # Skip apt package installation
./setup.sh --skip-github-ssh  # Skip GitHub SSH verification
```

### Running Tests
```bash
# Run all tests
./test/bats/bin/bats test/

# Run specific test file
./test/bats/bin/bats test/setup.bats
./test/bats/bin/bats test/pre-commit.bats

# Run a single test by name
./test/bats/bin/bats test/setup.bats --filter "test name pattern"
```

### Linting
```bash
shellcheck setup.sh hooks/pre-commit    # Lint shell scripts
bash -n setup.sh                         # Syntax check
```

## Architecture

### Core Components

- **setup.sh**: Main orchestration script that installs dependencies, clones repos, and configures hooks. Uses modular functions that can be skipped via flags.

- **hooks/pre-commit**: Git hook installed in the documentation repo. Runs Vale linter and Sphinx RST validation on staged `.rst` files before commits.

### Test Framework

Uses BATS (Bash Automated Testing System) with git submodules:
- `test/bats/` - BATS core
- `test/test_helper/bats-support/` - Support utilities
- `test/test_helper/bats-assert/` - Assertion library
- `test/test_helper/common-setup.bash` - Shared test helpers for temp dirs and mock repos

### Environment Variables

| Variable | Default | Purpose |
|----------|---------|---------|
| `DOCS_REPO` | `~/Documents/odoo/documentation` | Documentation repo path |
| `VALE_REPO` | `~/Documents/odoo/odoo-vale-linter` | Vale config repo path |
| `ODOO_DIR` | `~/Documents/odoo` | Workspace parent directory |
| `SKIP_GITHUB_SSH_CHECK` | unset | Set to `1` to skip SSH check in CI |
| `SPHINX_MAX_LINE_LENGTH` | `100` | Max line length for Sphinx linter |

## Code Conventions

- Shell scripts follow ShellCheck recommendations
- Color output uses Catppuccin Mocha theme (truecolor ANSI codes)
- All setup operations are idempotent (safe to re-run)
- Tests use BATS `@test` blocks with `assert_*` helpers from bats-assert
