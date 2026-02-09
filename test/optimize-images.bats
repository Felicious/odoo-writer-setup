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
    touch "$REPO_DIR/.gitkeep"
    git -C "$REPO_DIR" add .gitkeep
    git -C "$REPO_DIR" commit --quiet -m "init"

    # Clean cache directory for tests
    CACHE_DIR="$HOME/.cache/odoo-docs-image-originals"
    rm -rf "$CACHE_DIR"

    # Save original directory
    ORIG_DIR="$PWD"
}

teardown() {
    cd "$ORIG_DIR"
    teardown_temp_dir
}

@test "optimize-images.sh resizes wide PNG and creates backup" {
    if ! command -v convert &> /dev/null; then
        skip "ImageMagick not installed"
    fi
    if ! command -v pngquant &> /dev/null; then
        skip "pngquant not installed"
    fi

    cd "$REPO_DIR"
    convert -size 1000x500 xc:blue wide.png

    run "$PROJECT_ROOT/scripts/optimize-images.sh" -y
    assert_success
    assert_output --partial "Resizing wide.png"
    assert_output --partial "Backup saved"

    # Verify new width is 768px
    WIDTH=$(identify -format '%w' wide.png)
    [ "$WIDTH" -eq 768 ]

    # Verify backup exists with original width
    BACKUP="$HOME/.cache/odoo-docs-image-originals/wide.png"
    [ -f "$BACKUP" ]
    BACKUP_WIDTH=$(identify -format '%w' "$BACKUP")
    [ "$BACKUP_WIDTH" -eq 1000 ]
}

@test "optimize-images.sh processes unstaged PNG files" {
    if ! command -v convert &> /dev/null; then
        skip "ImageMagick not installed"
    fi
    if ! command -v pngquant &> /dev/null; then
        skip "pngquant not installed"
    fi

    cd "$REPO_DIR"
    # Create and commit a wide image first
    convert -size 1000x500 xc:blue wide.png
    git add wide.png
    git commit --quiet -m "add wide"

    # Modify it (unstaged)
    convert -size 1200x600 xc:red wide.png

    run "$PROJECT_ROOT/scripts/optimize-images.sh" -y
    assert_success
    assert_output --partial "Resizing wide.png (1200px → 768px)"

    # Verify it was optimized
    WIDTH=$(identify -format '%w' wide.png)
    [ "$WIDTH" -eq 768 ]
}

@test "optimize-images.sh preserves 933px by default" {
    if ! command -v convert &> /dev/null; then
        skip "ImageMagick not installed"
    fi
    if ! command -v pngquant &> /dev/null; then
        skip "pngquant not installed"
    fi

    cd "$REPO_DIR"
    convert -size 933x500 xc:blue special.png

    run "$PROJECT_ROOT/scripts/optimize-images.sh" -y
    assert_success
    assert_output --partial "All images already optimized"

    # Verify width is still 933px
    WIDTH=$(identify -format '%w' special.png)
    [ "$WIDTH" -eq 933 ]
}

@test "optimize-images.sh --width 933 preserves 933px images" {
    if ! command -v convert &> /dev/null; then
        skip "ImageMagick not installed"
    fi
    if ! command -v pngquant &> /dev/null; then
        skip "pngquant not installed"
    fi

    cd "$REPO_DIR"
    convert -size 933x500 xc:blue special.png

    run "$PROJECT_ROOT/scripts/optimize-images.sh" -y --width 933
    assert_success
    assert_output --partial "already optimized"

    # Verify width is still 933px
    WIDTH=$(identify -format '%w' special.png)
    [ "$WIDTH" -eq 933 ]
}

@test "optimize-images.sh optimizes 16-bit to 8-bit" {
    if ! command -v convert &> /dev/null; then
        skip "ImageMagick not installed"
    fi
    if ! command -v pngquant &> /dev/null; then
        skip "pngquant not installed"
    fi

    cd "$REPO_DIR"
    convert -size 500x300 gradient:blue-red rgb.png

    run "$PROJECT_ROOT/scripts/optimize-images.sh" -y
    assert_success
    assert_output --partial "Optimizing rgb.png"

    # Verify it's now 8-bit
    BIT_DEPTH=$(identify -format '%[bit-depth]' rgb.png)
    [ "$BIT_DEPTH" -eq 8 ]
}

@test "optimize-images.sh accepts specific file arguments" {
    if ! command -v convert &> /dev/null; then
        skip "ImageMagick not installed"
    fi
    if ! command -v pngquant &> /dev/null; then
        skip "pngquant not installed"
    fi

    cd "$REPO_DIR"
    convert -size 1000x500 xc:blue file1.png
    convert -size 1000x500 xc:red file2.png

    run "$PROJECT_ROOT/scripts/optimize-images.sh" -y file1.png
    assert_success
    assert_output --partial "file1.png"
    refute_output --partial "file2.png"

    # Only file1 should be resized
    WIDTH1=$(identify -format '%w' file1.png)
    WIDTH2=$(identify -format '%w' file2.png)
    [ "$WIDTH1" -eq 768 ]
    [ "$WIDTH2" -eq 1000 ]
}

@test "optimize-images.sh shows 933px resize commands" {
    if ! command -v convert &> /dev/null; then
        skip "ImageMagick not installed"
    fi
    if ! command -v pngquant &> /dev/null; then
        skip "pngquant not installed"
    fi

    cd "$REPO_DIR"
    convert -size 1000x500 xc:blue wide.png

    run "$PROJECT_ROOT/scripts/optimize-images.sh" -y
    assert_success
    assert_output --partial "To resize to 933px instead"
    assert_output --partial "optimize-images --width 933"
}

@test "optimize-images.sh --width 933 resizes to 933px" {
    if ! command -v convert &> /dev/null; then
        skip "ImageMagick not installed"
    fi
    if ! command -v pngquant &> /dev/null; then
        skip "pngquant not installed"
    fi

    cd "$REPO_DIR"
    convert -size 1000x500 xc:blue wide.png

    run "$PROJECT_ROOT/scripts/optimize-images.sh" -y --width 933
    assert_success
    assert_output --partial "Optimizing 1 PNG image(s) to 933px"
    assert_output --partial "Resizing wide.png (1000px → 933px)"

    # Verify new width is 933px
    WIDTH=$(identify -format '%w' wide.png)
    [ "$WIDTH" -eq 933 ]
}

@test "optimize-images.sh --width 933 for specific file" {
    if ! command -v convert &> /dev/null; then
        skip "ImageMagick not installed"
    fi
    if ! command -v pngquant &> /dev/null; then
        skip "pngquant not installed"
    fi

    cd "$REPO_DIR"
    convert -size 1000x500 xc:blue file1.png
    convert -size 1000x500 xc:red file2.png

    run "$PROJECT_ROOT/scripts/optimize-images.sh" -y --width 933 file1.png
    assert_success
    assert_output --partial "file1.png"
    refute_output --partial "file2.png"

    # Only file1 should be resized to 933px
    WIDTH1=$(identify -format '%w' file1.png)
    WIDTH2=$(identify -format '%w' file2.png)
    [ "$WIDTH1" -eq 933 ]
    [ "$WIDTH2" -eq 1000 ]
}

@test "optimize-images.sh --width rejects invalid values" {
    cd "$REPO_DIR"
    run "$PROJECT_ROOT/scripts/optimize-images.sh" -y --width 500
    assert_failure
    assert_output --partial "must be either 768 or 933"
}

@test "optimize-images.sh workflow: 933px then default preserves 933px" {
    if ! command -v convert &> /dev/null; then
        skip "ImageMagick not installed"
    fi
    if ! command -v pngquant &> /dev/null; then
        skip "pngquant not installed"
    fi

    cd "$REPO_DIR"
    # Create 3 oversized images
    convert -size 1200x600 xc:blue image1.png
    convert -size 1000x500 xc:red image2.png
    convert -size 1500x750 xc:green special.png

    # Step 1: Resize one to 933px
    run "$PROJECT_ROOT/scripts/optimize-images.sh" -y --width 933 special.png
    assert_success
    WIDTH=$(identify -format '%w' special.png)
    [ "$WIDTH" -eq 933 ]

    # Step 2: Run default optimization (should preserve 933px, resize others to 768px)
    run "$PROJECT_ROOT/scripts/optimize-images.sh" -y
    assert_success

    # Verify: special.png still 933px
    WIDTH_SPECIAL=$(identify -format '%w' special.png)
    [ "$WIDTH_SPECIAL" -eq 933 ]

    # Verify: others are 768px
    WIDTH1=$(identify -format '%w' image1.png)
    WIDTH2=$(identify -format '%w' image2.png)
    [ "$WIDTH1" -eq 768 ]
    [ "$WIDTH2" -eq 768 ]
}

@test "optimize-images.sh explicit --width 768 forces 933px to 768px" {
    if ! command -v convert &> /dev/null; then
        skip "ImageMagick not installed"
    fi
    if ! command -v pngquant &> /dev/null; then
        skip "pngquant not installed"
    fi

    cd "$REPO_DIR"
    # Create an image and resize to 933px
    convert -size 1500x750 xc:green special.png
    "$PROJECT_ROOT/scripts/optimize-images.sh" -y --width 933 special.png
    WIDTH=$(identify -format '%w' special.png)
    [ "$WIDTH" -eq 933 ]

    # Now explicitly force it to 768px
    run "$PROJECT_ROOT/scripts/optimize-images.sh" -y --width 768 special.png
    assert_success
    assert_output --partial "Resizing special.png (933px → 768px)"

    # Verify it's now 768px
    WIDTH=$(identify -format '%w' special.png)
    [ "$WIDTH" -eq 768 ]
}
