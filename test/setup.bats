#!/usr/bin/env bats

setup_file() {
    load 'test_helper/common-setup'
    clone_vale_repo_cache
}

teardown_file() {
    teardown_vale_repo_cache
}

setup() {
    load 'test_helper/common-setup'
    setup_temp_dir
}

teardown() {
    teardown_temp_dir
}

# --- Architecture & system checks ---

@test "check_architecture passes on x86_64" {
    source "$PROJECT_ROOT/setup.sh"
    run check_architecture
    assert_success
}

@test "check_system passes when apt-get exists" {
    source "$PROJECT_ROOT/setup.sh"
    if ! command -v apt-get &> /dev/null; then
        skip "apt-get not available"
    fi
    run check_system
    assert_success
}

@test "check_system fails without apt-get" {
    source "$PROJECT_ROOT/setup.sh"
    # Hide apt-get from PATH
    PATH="/usr/bin:/bin"
    if command -v apt-get &> /dev/null; then
        skip "cannot hide apt-get from PATH in this environment"
    fi
    run env PATH="$PATH" bash -c "source '$PROJECT_ROOT/setup.sh' && check_system"
    assert_failure
    assert_output --partial "apt-get not found"
}

# --- Directory creation ---

@test "create_directories creates odoo directory" {
    source "$PROJECT_ROOT/setup.sh"
    ODOO_DIR="$TEST_TEMP_DIR/Documents/odoo"
    run create_directories
    assert_success
    assert [ -d "$TEST_TEMP_DIR/Documents/odoo" ]
    assert_output --partial "Directory structure ready"
}

@test "create_directories is idempotent" {
    source "$PROJECT_ROOT/setup.sh"
    ODOO_DIR="$TEST_TEMP_DIR/Documents/odoo"
    mkdir -p "$ODOO_DIR"
    run create_directories
    assert_success
    assert [ -d "$ODOO_DIR" ]
}

# --- Repo cloning ---

@test "clone_or_update_repos pulls existing vale repo" {
    source "$PROJECT_ROOT/setup.sh"
    setup_fake_docs_repo
    setup_vale_repo
    run clone_or_update_repos
    assert_success
    assert_output --partial "Found odoo-vale-linter"
}

@test "clone_or_update_repos detects existing docs repo" {
    source "$PROJECT_ROOT/setup.sh"
    setup_fake_docs_repo
    setup_vale_repo
    run clone_or_update_repos
    assert_success
    assert_output --partial "Found documentation repo"
}

# --- Hook installation ---

@test "install_hook copies pre-commit hook" {
    source "$PROJECT_ROOT/setup.sh"
    setup_fake_docs_repo
    run install_hook
    assert_success
    assert [ -x "$DOCS_REPO/.git/hooks/pre-commit" ]
    assert_output --partial "Pre-commit hook installed"
}

@test "install_hook fails when docs repo missing" {
    source "$PROJECT_ROOT/setup.sh"
    DOCS_REPO="/nonexistent"
    run install_hook
    assert_failure
    assert_output --partial "Documentation repo not found"
}

@test "install_hook warns when tests/main.py is missing" {
    source "$PROJECT_ROOT/setup.sh"
    setup_fake_docs_repo
    run install_hook
    assert_success
    assert_output --partial "tests/main.py not found"
}

@test "install_hook does not warn when tests/main.py exists" {
    source "$PROJECT_ROOT/setup.sh"
    setup_fake_docs_repo
    mkdir -p "$DOCS_REPO/tests"
    touch "$DOCS_REPO/tests/main.py"
    run install_hook
    assert_success
    refute_output --partial "tests/main.py not found"
}

# --- uv installation ---

@test "install_uv reports already installed when present" {
    source "$PROJECT_ROOT/setup.sh"
    if ! command -v uv &> /dev/null; then
        skip "uv not in PATH"
    fi
    run install_uv
    assert_success
    assert_output --partial "uv already installed"
}

# --- Shell detection ---

@test "check_shell passes on bash" {
    source "$PROJECT_ROOT/setup.sh"
    export SHELL="/bin/bash"
    run check_shell
    assert_success
}

@test "check_shell warns on zsh but succeeds" {
    source "$PROJECT_ROOT/setup.sh"
    export SHELL="/bin/zsh"
    run check_shell
    assert_success
    assert_output --partial "Your login shell is not bash"
    assert_output --partial "Starship will be configured for bash anyway"
}

@test "check_shell warns on fish but succeeds" {
    source "$PROJECT_ROOT/setup.sh"
    export SHELL="/usr/bin/fish"
    run check_shell
    assert_success
    assert_output --partial "Your login shell is not bash"
}

# --- Starship installation ---

@test "install_starship reports already installed when present" {
    source "$PROJECT_ROOT/setup.sh"
    if ! command -v starship &> /dev/null; then
        skip "starship not in PATH"
    fi
    run install_starship
    assert_success
    assert_output --partial "starship already installed"
}

# --- Bashrc configuration ---

@test "configure_bashrc creates .bashrc if missing" {
    source "$PROJECT_ROOT/setup.sh"
    export HOME="$TEST_TEMP_DIR"
    run configure_bashrc
    assert_success
    assert [ -f "$TEST_TEMP_DIR/.bashrc" ]
    assert_output --partial "Creating new .bashrc file"
}

@test "configure_bashrc adds starship init to .bashrc" {
    source "$PROJECT_ROOT/setup.sh"
    export HOME="$TEST_TEMP_DIR"
    touch "$TEST_TEMP_DIR/.bashrc"
    run configure_bashrc
    assert_success
    assert_output --partial "starship configured in .bashrc"
    assert_output --partial "source ~/.bashrc"
    grep -qF "starship init bash" "$TEST_TEMP_DIR/.bashrc"
}

@test "configure_bashrc is idempotent" {
    source "$PROJECT_ROOT/setup.sh"
    export HOME="$TEST_TEMP_DIR"
    touch "$TEST_TEMP_DIR/.bashrc"

    # Run once
    configure_bashrc > /dev/null

    # Run again
    run configure_bashrc
    assert_success
    assert_output --partial "starship already configured"

    # Verify only one occurrence
    count=$(grep -c "starship init bash" "$TEST_TEMP_DIR/.bashrc" || echo 0)
    [ "$count" -eq 1 ]
}

@test "configure_bashrc detects manual starship configuration" {
    source "$PROJECT_ROOT/setup.sh"
    export HOME="$TEST_TEMP_DIR"

    # Manually add starship without our marker comment
    cat > "$TEST_TEMP_DIR/.bashrc" << 'EOF'
# User's manual config
eval "$(starship init bash)"
EOF

    run configure_bashrc
    assert_success
    assert_output --partial "starship already configured"
}

@test "configure_bashrc includes marker comment" {
    source "$PROJECT_ROOT/setup.sh"
    export HOME="$TEST_TEMP_DIR"
    touch "$TEST_TEMP_DIR/.bashrc"

    configure_bashrc > /dev/null

    grep -qF "# Starship prompt (added by odoo-writer-setup)" "$TEST_TEMP_DIR/.bashrc"
}

# --- Verification ---

@test "verify_installation checks for starship" {
    source "$PROJECT_ROOT/setup.sh"
    setup_fake_docs_repo

    # Create mock starship binary
    mkdir -p "$TEST_TEMP_DIR/bin"
    echo '#!/bin/bash' > "$TEST_TEMP_DIR/bin/starship"
    chmod +x "$TEST_TEMP_DIR/bin/starship"
    export PATH="$TEST_TEMP_DIR/bin:$PATH"

    run verify_installation
    assert_success
    assert_output --partial "starship found"
}

@test "verify_installation confirms bashrc configuration" {
    source "$PROJECT_ROOT/setup.sh"
    export HOME="$TEST_TEMP_DIR"
    setup_fake_docs_repo

    # Configure starship in bashrc
    cat > "$TEST_TEMP_DIR/.bashrc" << 'EOF'
eval "$(starship init bash)"
EOF

    run verify_installation
    assert_success
    assert_output --partial "starship configured in .bashrc"
}

@test "verify_installation reports tools and repos" {
    source "$PROJECT_ROOT/setup.sh"
    setup_fake_docs_repo
    # Install hook so verification finds it
    cp "$PROJECT_ROOT/hooks/pre-commit" "$DOCS_REPO/.git/hooks/pre-commit"
    chmod +x "$DOCS_REPO/.git/hooks/pre-commit"
    # Set up vale repo
    setup_vale_repo

    run verify_installation
    assert_success
    assert_output --partial "Verification"
    assert_output --partial "git found"
    assert_output --partial "documentation repo present"
    assert_output --partial "odoo-vale-linter present"
    assert_output --partial "pre-commit hook installed"
}

@test "verify_installation warns about missing components" {
    source "$PROJECT_ROOT/setup.sh"
    DOCS_REPO="$TEST_TEMP_DIR/nonexistent"
    VALE_REPO="$TEST_TEMP_DIR/nonexistent-vale"
    run verify_installation
    assert_success
    assert_output --partial "documentation repo missing"
    assert_output --partial "odoo-vale-linter missing"
    assert_output --partial "Setup finished with warnings"
}

# --- Integration: full setup.sh with --skip-apt ---

@test "full setup with --skip-apt installs hook and verifies" {
    setup_fake_docs_repo
    setup_vale_repo

    run env DOCS_REPO="$DOCS_REPO" VALE_REPO="$VALE_REPO" SKIP_GITHUB_SSH_CHECK=1 \
        bash "$PROJECT_ROOT/setup.sh" --skip-apt
    assert_success
    assert_output --partial "Odoo Writer Setup"
    assert_output --partial "Skipping apt packages"
    assert_output --partial "Skipping GitHub SSH check"
    assert [ -x "$DOCS_REPO/.git/hooks/pre-commit" ]
}

@test "full setup is idempotent (safe to re-run)" {
    setup_fake_docs_repo
    setup_vale_repo

    # Run once
    run env DOCS_REPO="$DOCS_REPO" VALE_REPO="$VALE_REPO" SKIP_GITHUB_SSH_CHECK=1 \
        bash "$PROJECT_ROOT/setup.sh" --skip-apt
    assert_success

    # Run again
    run env DOCS_REPO="$DOCS_REPO" VALE_REPO="$VALE_REPO" SKIP_GITHUB_SSH_CHECK=1 \
        bash "$PROJECT_ROOT/setup.sh" --skip-apt
    assert_success
    assert_output --partial "Found documentation repo"
    assert_output --partial "Found odoo-vale-linter"
}
