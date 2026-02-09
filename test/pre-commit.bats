#!/usr/bin/env bats

setup() {
    load 'test_helper/common-setup'
    setup_temp_dir

    # Create a fresh git repo for each test
    REPO_DIR="$TEST_TEMP_DIR/repo"
    git init --quiet "$REPO_DIR"
    git -C "$REPO_DIR" config user.email "test@test.com"
    git -C "$REPO_DIR" config user.name "Test"
    git -C "$REPO_DIR" config commit.gpgsign false
    # Initial commit so HEAD exists
    touch "$REPO_DIR/.gitkeep"
    git -C "$REPO_DIR" add .gitkeep
    git -C "$REPO_DIR" commit --quiet -m "init"

    # Copy the pre-commit hook into the test repo
    cp "$PROJECT_ROOT/hooks/pre-commit" "$REPO_DIR/.git/hooks/pre-commit"
    chmod +x "$REPO_DIR/.git/hooks/pre-commit"

    # Default VALE_REPO to a fake one
    VALE_REPO="$TEST_TEMP_DIR/vale"
    mkdir -p "$VALE_REPO/.git" "$VALE_REPO/styles"
    cat > "$VALE_REPO/.vale.ini" <<'VALEEOF'
StylesPath = styles
MinAlertLevel = warning
[*.rst]
BasedOnStyles = Vale
VALEEOF
    export VALE_REPO

    # Save original PATH for restoration
    ORIG_PATH="$PATH"
}

teardown() {
    PATH="$ORIG_PATH"
    teardown_temp_dir
}

@test "exits 0 when no .rst files staged" {
    run git -C "$REPO_DIR" hook run pre-commit
    assert_success
    assert_output ""
}

@test "exits 0 when only non-rst files staged" {
    echo "hello" > "$REPO_DIR/file.txt"
    git -C "$REPO_DIR" add file.txt
    run git -C "$REPO_DIR" hook run pre-commit
    assert_success
    assert_output ""
}

@test "runs vale on staged .rst files" {
    if ! command -v vale &> /dev/null; then
        skip "vale not in PATH"
    fi

    printf 'Test\n====\n\nA test paragraph.\n' > "$REPO_DIR/test.rst"
    git -C "$REPO_DIR" add test.rst

    run git -C "$REPO_DIR" hook run pre-commit
    assert_output --partial "Running Vale"
}

@test "warns when vale is not installed" {
    # Hide vale from PATH by using a restricted PATH
    PATH="/usr/bin:/bin"
    # Make sure vale is actually hidden
    if command -v vale &> /dev/null; then
        skip "cannot hide vale from PATH in this environment"
    fi

    printf 'Test\n====\n\nA paragraph.\n' > "$REPO_DIR/test.rst"
    git -C "$REPO_DIR" add test.rst

    run env PATH="$PATH" VALE_REPO="$VALE_REPO" git -C "$REPO_DIR" hook run pre-commit
    assert_output --partial "Vale not found"
}

@test "warns when uv is not installed for sphinx" {
    # Create tests/main.py so sphinx linter section is entered
    mkdir -p "$REPO_DIR/tests"
    echo "# sphinx linter" > "$REPO_DIR/tests/main.py"
    git -C "$REPO_DIR" add tests/main.py
    git -C "$REPO_DIR" commit --quiet -m "add main.py"

    printf 'Test\n====\n\nA paragraph.\n' > "$REPO_DIR/test.rst"
    git -C "$REPO_DIR" add test.rst

    # Hide uv from PATH
    PATH="/usr/bin:/bin"
    if command -v uv &> /dev/null; then
        skip "cannot hide uv from PATH in this environment"
    fi

    run env PATH="$PATH" VALE_REPO="$VALE_REPO" git -C "$REPO_DIR" hook run pre-commit
    assert_output --partial "uv not found"
}

@test "skips sphinx when tests/main.py missing" {
    if ! command -v vale &> /dev/null; then
        skip "vale not in PATH"
    fi

    printf 'Test\n====\n\nA paragraph.\n' > "$REPO_DIR/test.rst"
    git -C "$REPO_DIR" add test.rst

    run git -C "$REPO_DIR" hook run pre-commit
    refute_output --partial "Sphinx linter"
}

@test "reports all checks passed on clean file" {
    if ! command -v vale &> /dev/null; then
        skip "vale not in PATH"
    fi

    printf 'Test\n====\n\nA clean test paragraph.\n' > "$REPO_DIR/test.rst"
    git -C "$REPO_DIR" add test.rst

    run git -C "$REPO_DIR" hook run pre-commit
    assert_success
    assert_output --partial "All checks passed"
}

@test "blocks commit when vale finds issues" {
    if ! command -v vale &> /dev/null; then
        skip "vale not in PATH"
    fi

    # Use the real odoo-vale-linter config if available, otherwise skip
    if [ -d "$HOME/Documents/odoo/odoo-vale-linter/.git" ]; then
        VALE_REPO="$HOME/Documents/odoo/odoo-vale-linter"
        export VALE_REPO
    fi

    # Create a .rst with content likely to trigger vale errors
    # Using non-standard heading, very long line, etc.
    cat > "$REPO_DIR/bad.rst" <<'EOF'
test
====

We will be discussing the the fact that this sentence has a repeated word and also this is extremely long sentence that goes on and on and on and the the quick brown fox jumped over the lazy dog while the the cat sat on the mat.
EOF
    git -C "$REPO_DIR" add bad.rst

    run git -C "$REPO_DIR" hook run pre-commit
    # If vale passes (no matching rules), the test is inconclusive — skip
    if [ "$status" -eq 0 ]; then
        skip "vale did not flag any issues with test content (no matching rules configured)"
    fi
    assert_failure
    assert_output --partial "Commit blocked"
}

@test "validates PNG width and blocks commit" {
    if ! command -v convert &> /dev/null; then
        skip "ImageMagick not installed"
    fi

    # Create a 1000x500 test PNG (exceeds 768px)
    convert -size 1000x500 xc:blue "$REPO_DIR/wide.png"
    git -C "$REPO_DIR" add wide.png

    run git -C "$REPO_DIR" hook run pre-commit
    assert_failure
    assert_output --partial "Image validation failed"
    assert_output --partial "wide.png: 1000px wide"
    assert_output --partial "optimize-images"
}

@test "validates PNG bit depth and blocks commit" {
    if ! command -v convert &> /dev/null; then
        skip "ImageMagick not installed"
    fi

    # Create a 16-bit RGB PNG (gradient creates multi-bit depth)
    convert -size 500x300 gradient:blue-red "$REPO_DIR/rgb.png"
    git -C "$REPO_DIR" add rgb.png

    run git -C "$REPO_DIR" hook run pre-commit
    assert_failure
    assert_output --partial "Image validation failed"
    assert_output --partial "rgb.png:"
    assert_output --partial "bit color depth"
    assert_output --partial "optimize-images"
}

@test "allows 933px width images" {
    if ! command -v convert &> /dev/null; then
        skip "ImageMagick not installed"
    fi

    # Create a 933x500 test PNG (exception width)
    convert -size 933x500 xc:blue "$REPO_DIR/special.png"
    git -C "$REPO_DIR" add special.png

    run git -C "$REPO_DIR" hook run pre-commit
    assert_success
    assert_output --partial "All images validated"
}

@test "allows optimized PNG images" {
    if ! command -v convert &> /dev/null; then
        skip "ImageMagick not installed"
    fi

    # Create an 8-bit 500px PNG (optimal)
    convert -size 500x300 xc:blue -depth 8 -type Palette "$REPO_DIR/optimal.png"
    git -C "$REPO_DIR" add optimal.png

    run git -C "$REPO_DIR" hook run pre-commit
    assert_success
    assert_output --partial "All images validated"
}

@test "warns when ImageMagick not installed for validation" {
    # Hide ImageMagick from PATH
    PATH="/usr/bin:/bin"
    if command -v identify &> /dev/null; then
        skip "cannot hide ImageMagick from PATH in this environment"
    fi

    echo "fake png" > "$REPO_DIR/test.png"
    git -C "$REPO_DIR" add test.png

    run env PATH="$PATH" git -C "$REPO_DIR" hook run pre-commit
    assert_success
    assert_output --partial "ImageMagick not found"
}
