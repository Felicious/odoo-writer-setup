#!/usr/bin/env bats

setup() {
    load 'test_helper/common-setup'
    setup_temp_dir
}

teardown() {
    teardown_temp_dir
}

@test "fails when docs repo is missing" {
    run env DOCS_REPO=/nonexistent VALE_REPO=/tmp bash "$PROJECT_ROOT/install.sh"
    assert_failure
    assert_output --partial "Documentation repo not found"
}

@test "fails when docs repo has no .git" {
    mkdir -p "$TEST_TEMP_DIR/no-git-repo"
    run env DOCS_REPO="$TEST_TEMP_DIR/no-git-repo" VALE_REPO=/tmp bash "$PROJECT_ROOT/install.sh"
    assert_failure
    assert_output --partial "Documentation repo not found"
}

@test "installs pre-commit hook" {
    setup_fake_docs_repo
    setup_fake_vale_repo

    run env DOCS_REPO="$DOCS_REPO" VALE_REPO="$VALE_REPO" bash "$PROJECT_ROOT/install.sh"
    assert_success
    assert [ -x "$DOCS_REPO/.git/hooks/pre-commit" ]
}

@test "warns when tests/main.py is missing" {
    setup_fake_docs_repo
    setup_fake_vale_repo

    run env DOCS_REPO="$DOCS_REPO" VALE_REPO="$VALE_REPO" bash "$PROJECT_ROOT/install.sh"
    assert_success
    assert_output --partial "tests/main.py not found"
}

@test "does not warn when tests/main.py exists" {
    setup_fake_docs_repo
    mkdir -p "$DOCS_REPO/tests"
    touch "$DOCS_REPO/tests/main.py"
    setup_fake_vale_repo

    run env DOCS_REPO="$DOCS_REPO" VALE_REPO="$VALE_REPO" bash "$PROJECT_ROOT/install.sh"
    assert_success
    refute_output --partial "tests/main.py not found"
}

@test "pulls existing vale repo" {
    setup_fake_docs_repo
    setup_fake_vale_repo

    run env DOCS_REPO="$DOCS_REPO" VALE_REPO="$VALE_REPO" bash "$PROJECT_ROOT/install.sh"
    assert_success
    assert_output --partial "Found odoo-vale-linter"
}

@test "reports all tools installed when present" {
    setup_fake_docs_repo
    setup_fake_vale_repo

    if ! command -v uv &> /dev/null || ! command -v vale &> /dev/null; then
        skip "uv and/or vale not in PATH"
    fi

    run env DOCS_REPO="$DOCS_REPO" VALE_REPO="$VALE_REPO" bash "$PROJECT_ROOT/install.sh"
    assert_success
    assert_output --partial "All tools installed"
}
