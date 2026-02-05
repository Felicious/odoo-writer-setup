#!/bin/bash
# Common setup for all BATS test files

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
export PROJECT_ROOT

load "${PROJECT_ROOT}/test/test_helper/bats-support/load"
load "${PROJECT_ROOT}/test/test_helper/bats-assert/load"

# Create a fresh temp directory for the test. Cleaned up in teardown.
setup_temp_dir() {
    TEST_TEMP_DIR="$(mktemp -d)"
    export TEST_TEMP_DIR
}

teardown_temp_dir() {
    if [ -n "$TEST_TEMP_DIR" ] && [ -d "$TEST_TEMP_DIR" ]; then
        rm -rf "$TEST_TEMP_DIR"
    fi
}

# Create a minimal git-initialized directory to act as the docs repo.
# Sets DOCS_REPO to the created path.
setup_fake_docs_repo() {
    DOCS_REPO="${TEST_TEMP_DIR}/documentation"
    export DOCS_REPO
    mkdir -p "$DOCS_REPO"
    git init --quiet "$DOCS_REPO"
    # Configure git user for commits in tests
    git -C "$DOCS_REPO" config user.email "test@test.com"
    git -C "$DOCS_REPO" config user.name "Test"
}

# Create a git-cloned directory with .vale.ini to act as the vale repo.
# Uses a local bare repo as the remote so `git pull` works.
# Sets VALE_REPO to the created path.
setup_fake_vale_repo() {
    VALE_REPO="${TEST_TEMP_DIR}/odoo-vale-linter"
    export VALE_REPO
    git init --quiet --bare "$TEST_TEMP_DIR/vale-bare.git"
    git clone --quiet "$TEST_TEMP_DIR/vale-bare.git" "$VALE_REPO"
    mkdir -p "$VALE_REPO/styles"
    cat > "$VALE_REPO/.vale.ini" <<'EOF'
StylesPath = styles
MinAlertLevel = warning
[*.rst]
BasedOnStyles = Vale
EOF
    git -C "$VALE_REPO" add -A
    git -C "$VALE_REPO" -c user.email=t@t.com -c user.name=T commit --quiet -m "init"
    git -C "$VALE_REPO" push --quiet
}
