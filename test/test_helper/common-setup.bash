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
    git -C "$DOCS_REPO" config commit.gpgsign false
}

# Clone the real odoo-vale-linter repo once per test file.
# Call from setup_file. Cleaned up by teardown_vale_repo_cache.
clone_vale_repo_cache() {
    VALE_REPO_CACHE="$(mktemp -d)"
    export VALE_REPO_CACHE
    git clone --quiet --depth 1 https://github.com/felicious/odoo-vale-linter.git \
        "$VALE_REPO_CACHE/odoo-vale-linter"
}

teardown_vale_repo_cache() {
    if [ -n "$VALE_REPO_CACHE" ] && [ -d "$VALE_REPO_CACHE" ]; then
        rm -rf "$VALE_REPO_CACHE"
    fi
}

# Copy the cached vale repo clone into the per-test temp directory.
# Sets VALE_REPO to the created path.
setup_vale_repo() {
    VALE_REPO="${TEST_TEMP_DIR}/odoo-vale-linter"
    export VALE_REPO
    cp -a "$VALE_REPO_CACHE/odoo-vale-linter" "$VALE_REPO"
}
