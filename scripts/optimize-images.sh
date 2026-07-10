#!/bin/bash
#
# Optimize PNG images for Odoo documentation.
# Resizes to specified width and optimizes to 8-bit color depth.
#
# Usage:
#   optimize-images                         # Optimize all modified PNG files (768px)
#   optimize-images file1.png file2.png     # Optimize specific files (768px)
#   optimize-images --width 933 file.png    # Resize to 933px instead
#   optimize-images --width 933             # Resize all modified to 933px
#   optimize-images -y                      # Skip confirmation prompt
#

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BOLD='\033[1m'
SUBTEXT='\033[38;2;166;173;200m'
RESET='\033[0m'

# Backup directory for originals
BACKUP_DIR="$HOME/.cache/odoo-docs-image-originals"

# Max PNG size in bytes; must match MAX_IMAGE_SIZES['.png'] in
# odoo/documentation's tests/checkers/resource_files.py (the `make review` check).
MAX_PNG_SIZE=505000

# pngquant quality/color fallback tiers, tried in order until the image
# becomes a palette PNG at or under MAX_PNG_SIZE. A single --quality 85-100
# pass is not enough: pngquant aborts without writing output when it can't
# hit the minimum quality (common on busy screenshots), which used to leave
# the image completely uncompressed.
QUALITY_TIERS=(85-100 65-100 0-100)
COLOR_TIERS=(128 64 32 16)

# Return success (0) if the PNG is already an indexed/palette image, i.e.
# what `identify`'s `%[bit-depth]` cannot tell us: it reports bits per
# *channel*, so a 24-bit TrueColor screenshot reports 8 just like an
# already-quantized palette PNG. Checking the ImageMagick "type" instead
# mirrors the docs repo's own check, which looks at the Pillow image mode.
png_is_palette() {
    local type
    type=$(identify -format '%[type]' "$1" 2>/dev/null)
    [[ "$type" == *Palette* ]]
}

# Return success (0) if the PNG still needs work: not a palette image yet,
# or already palette but still over the docs repo's size limit.
png_needs_optimize() {
    local img="$1" size
    size=$(stat -c%s "$img" 2>/dev/null || echo 0)
    if ! png_is_palette "$img"; then
        return 0
    fi
    [ "$size" -gt "$MAX_PNG_SIZE" ]
}

# Quantize $1 down to a palette PNG under MAX_PNG_SIZE, escalating from
# best quality/most colors to more aggressive settings only as needed.
# Returns 0 on success, 1 if it's palette but still oversized, 2 if it
# could not be converted to palette at all.
quantize_png() {
    local img="$1" tier

    for tier in "${QUALITY_TIERS[@]}"; do
        pngquant --force --ext .png --skip-if-larger --quality "$tier" "$img" 2>/dev/null || true
        png_needs_optimize "$img" || return 0
    done

    for tier in "${COLOR_TIERS[@]}"; do
        pngquant --force --ext .png --skip-if-larger "$tier" "$img" 2>/dev/null || true
        png_needs_optimize "$img" || return 0
    done

    if png_is_palette "$img"; then
        return 1
    fi
    return 2
}

# Parse arguments first (before checking tools)
TARGET_WIDTH=768
WIDTH_EXPLICIT=0  # Track if --width was explicitly provided
AUTO_CONFIRM=0
POSITIONAL_ARGS=()

while [[ $# -gt 0 ]]; do
    case $1 in
        --width)
            TARGET_WIDTH="$2"
            WIDTH_EXPLICIT=1
            if [ "$TARGET_WIDTH" != "768" ] && [ "$TARGET_WIDTH" != "933" ]; then
                echo -e "${RED}Error: --width must be either 768 or 933${RESET}"
                exit 1
            fi
            shift 2
            ;;
        -y|--yes)
            AUTO_CONFIRM=1
            shift
            ;;
        *)
            POSITIONAL_ARGS+=("$1")
            shift
            ;;
    esac
done

# Check for required tools
if ! command -v identify &> /dev/null; then
    echo -e "${RED}Error: ImageMagick not found. Install with: sudo apt install imagemagick${RESET}"
    exit 1
fi

if ! command -v mogrify &> /dev/null; then
    echo -e "${RED}Error: ImageMagick not found. Install with: sudo apt install imagemagick${RESET}"
    exit 1
fi

if ! command -v pngquant &> /dev/null; then
    echo -e "${RED}Error: pngquant not found. Install with: sudo apt install pngquant${RESET}"
    exit 1
fi

# Get list of files to process
if [ "${#POSITIONAL_ARGS[@]}" -eq 0 ]; then
    # No args: process all modified PNG files (staged + unstaged)
    if ! git rev-parse --is-inside-work-tree &> /dev/null; then
        echo -e "${RED}Error: Not in a git repository${RESET}"
        exit 1
    fi
    # Get both staged and unstaged PNG files
    mapfile -t STAGED < <(git diff --cached --name-only --diff-filter=ACM -- '*.png')
    mapfile -t UNSTAGED < <(git diff --name-only --diff-filter=M -- '*.png')
    # Also include untracked PNG files
    mapfile -t UNTRACKED < <(git ls-files --others --exclude-standard -- '*.png')

    # Combine and deduplicate
    declare -A SEEN
    FILES=()
    for file in "${STAGED[@]}" "${UNSTAGED[@]}" "${UNTRACKED[@]}"; do
        if [ -n "$file" ] && [ -z "${SEEN[$file]}" ]; then
            FILES+=("$file")
            SEEN[$file]=1
        fi
    done

    if [ "${#FILES[@]}" -eq 0 ]; then
        echo -e "${YELLOW}No modified PNG files found${RESET}"
        exit 0
    fi
else
    # Args provided: process those specific files
    FILES=("${POSITIONAL_ARGS[@]}")
fi

# First pass: analyze files and show what will be changed
echo -e "${BOLD}Analyzing ${#FILES[@]} PNG image(s)...${RESET}"
echo ""

PLANNED_CHANGES=()
for img in "${FILES[@]}"; do
    if [ ! -f "$img" ]; then
        continue
    fi

    WIDTH=$(identify -format '%w' "$img" 2>/dev/null)

    if [ -z "$WIDTH" ]; then
        continue
    fi

    CHANGES=""
    STATUS=""
    # Check if resize is needed
    # Special case: preserve 933px only when using implicit default 768px
    NEEDS_RESIZE=0
    if [ "$WIDTH" -ne "$TARGET_WIDTH" ]; then
        if [ "$WIDTH_EXPLICIT" -eq 0 ] && [ "$TARGET_WIDTH" -eq 768 ] && [ "$WIDTH" -eq 933 ]; then
            # 933px is allowed when using implicit default 768px
            NEEDS_RESIZE=0
            STATUS="already optimized (933px override)"
        else
            NEEDS_RESIZE=1
            CHANGES="resize ${WIDTH}px→${TARGET_WIDTH}px"
        fi
    fi

    NEEDS_OPTIMIZE=0
    if png_needs_optimize "$img"; then
        NEEDS_OPTIMIZE=1
        if [ -n "$CHANGES" ]; then
            CHANGES="$CHANGES, "
        fi
        if png_is_palette "$img"; then
            SIZE_KB=$(( $(stat -c%s "$img") / 1024 ))
            CHANGES="${CHANGES}compress (${SIZE_KB}KB > $(( MAX_PNG_SIZE / 1024 ))KB limit)"
        else
            CHANGES="${CHANGES}quantize to palette (TrueColor→8-bit)"
        fi
        STATUS=""  # Clear status if we need changes
    fi

    # Show all files with their status
    if [ -n "$CHANGES" ]; then
        echo -e "  ${YELLOW}→${RESET} $img: $CHANGES"
        PLANNED_CHANGES+=("$img")
    elif [ -n "$STATUS" ]; then
        echo -e "  ${GREEN}✓${RESET} $img: $STATUS"
    elif [ "$WIDTH" -eq "$TARGET_WIDTH" ]; then
        echo -e "  ${GREEN}✓${RESET} $img: already optimized"
    fi
done

if [ "${#PLANNED_CHANGES[@]}" -eq 0 ]; then
    echo -e "${GREEN}${BOLD}✓ All images already optimized${RESET}"
    exit 0
fi

echo ""

# Ask for confirmation unless --yes flag is set
if [ "$AUTO_CONFIRM" -eq 0 ]; then
    echo -e "${BOLD}Modify ${#PLANNED_CHANGES[@]} image(s)? [y/N]${RESET} "
    read -r RESPONSE
    if [[ ! "$RESPONSE" =~ ^[Yy]$ ]]; then
        echo -e "${YELLOW}Cancelled${RESET}"
        exit 0
    fi
    echo ""
fi

echo -e "${BOLD}Optimizing ${#PLANNED_CHANGES[@]} PNG image(s) to ${TARGET_WIDTH}px...${RESET}"
echo ""

IMAGES_MODIFIED=0
IMAGES_BACKED_UP=()

for img in "${PLANNED_CHANGES[@]}"; do
    if [ ! -f "$img" ]; then
        echo -e "${YELLOW}⚠ Skipping $img (not found)${RESET}"
        continue
    fi

    NEEDS_BACKUP=0
    MODIFIED_THIS_IMAGE=0

    # Check current width
    WIDTH=$(identify -format '%w' "$img" 2>/dev/null)
    if [ -z "$WIDTH" ]; then
        echo -e "${YELLOW}⚠ Skipping $img (cannot read image properties)${RESET}"
        continue
    fi

    # Check if resize needed (preserve 933px only with implicit default 768px)
    WILL_RESIZE=0
    if [ "$WIDTH" -ne "$TARGET_WIDTH" ]; then
        if [ "$WIDTH_EXPLICIT" -eq 0 ] && [ "$TARGET_WIDTH" -eq 768 ] && [ "$WIDTH" -eq 933 ]; then
            # Skip resizing 933px only when using implicit default 768px
            WILL_RESIZE=0
        else
            WILL_RESIZE=1
            NEEDS_BACKUP=1
        fi
    fi

    # Check if optimization needed (not palette, or palette but oversized)
    WILL_OPTIMIZE=0
    if png_needs_optimize "$img"; then
        WILL_OPTIMIZE=1
        NEEDS_BACKUP=1
    fi

    # Create backup if modifications needed
    if [ "$NEEDS_BACKUP" -eq 1 ]; then
        BACKUP="$BACKUP_DIR/$img"
        if [ ! -f "$BACKUP" ]; then
            mkdir -p "$(dirname "$BACKUP")"
            cp "$img" "$BACKUP"
            echo -e "  ${GREEN}✓${RESET} Backup saved: $BACKUP"
            IMAGES_BACKED_UP+=("$img")
        else
            echo -e "  ${YELLOW}⚠${RESET} Using existing backup: $BACKUP"
        fi
    fi

    # Resize if needed
    if [ "$WILL_RESIZE" -eq 1 ]; then
        echo -e "  ${GREEN}✓${RESET} Resizing $img (${WIDTH}px → ${TARGET_WIDTH}px)"
        mogrify -resize "${TARGET_WIDTH}x" "$img"
        MODIFIED_THIS_IMAGE=1
        # Resizing can shrink the file enough on its own; re-check before quantizing.
        if png_needs_optimize "$img"; then
            WILL_OPTIMIZE=1
        else
            WILL_OPTIMIZE=0
        fi
    fi

    # Quantize to palette if not already, or still oversized
    if [ "$WILL_OPTIMIZE" -eq 1 ]; then
        echo -e "  ${GREEN}✓${RESET} Optimizing $img (compressing to palette PNG)"
        if quantize_png "$img"; then
            QUANTIZE_STATUS=0
        else
            QUANTIZE_STATUS=$?
        fi
        FINAL_KB=$(( $(stat -c%s "$img") / 1024 ))
        if [ "$QUANTIZE_STATUS" -eq 2 ]; then
            echo -e "  ${RED}✗${RESET} $img could not be converted to a palette PNG (pngquant failed)"
        elif [ "$QUANTIZE_STATUS" -eq 1 ]; then
            echo -e "  ${YELLOW}⚠${RESET} $img is still ${FINAL_KB}KB after best-effort compression" \
                "(limit: $(( MAX_PNG_SIZE / 1024 ))KB) — consider cropping or splitting the image"
        fi
        MODIFIED_THIS_IMAGE=1
    fi

    if [ "$MODIFIED_THIS_IMAGE" -eq 0 ]; then
        echo -e "  ${GREEN}✓${RESET} $img already optimized"
    else
        IMAGES_MODIFIED=1
    fi
done

echo ""

# Notify about next steps
if [ "$IMAGES_MODIFIED" -eq 1 ]; then
    echo -e "${GREEN}${BOLD}✓ Optimization complete${RESET}"
    echo -e "${SUBTEXT}Remember to stage modified files: ${BOLD}git add <files>${RESET}"

    # Show alternative width option for backed-up images
    if [ "${#IMAGES_BACKED_UP[@]}" -gt 0 ] && [ "$TARGET_WIDTH" -eq 768 ]; then
        echo ""
        echo -e "${YELLOW}To resize to 933px instead (for images that need extra width):${RESET}"
        echo -e "  ${BOLD}optimize-images --width 933 ${IMAGES_BACKED_UP[*]}${RESET}"
        echo ""
        echo -e "${YELLOW}Originals backed up in: $BACKUP_DIR${RESET}"
    fi
else
    echo -e "${GREEN}${BOLD}✓ All images already optimized${RESET}"
fi
