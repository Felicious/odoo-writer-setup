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
    BIT_DEPTH=$(identify -format '%[bit-depth]' "$img" 2>/dev/null)

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
    if [ "$BIT_DEPTH" -gt 8 ]; then
        NEEDS_OPTIMIZE=1
        if [ -n "$CHANGES" ]; then
            CHANGES="$CHANGES, "
        fi
        CHANGES="${CHANGES}optimize ${BIT_DEPTH}-bit→8-bit"
        STATUS=""  # Clear status if we need changes
    fi

    # Show all files with their status
    if [ -n "$CHANGES" ]; then
        echo -e "  ${YELLOW}→${RESET} $img: $CHANGES"
        PLANNED_CHANGES+=("$img")
    elif [ -n "$STATUS" ]; then
        echo -e "  ${GREEN}✓${RESET} $img: $STATUS"
    elif [ "$WIDTH" -eq "$TARGET_WIDTH" ] && [ "$BIT_DEPTH" -le 8 ]; then
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

    # Check color depth (bit depth)
    BIT_DEPTH=$(identify -format '%[bit-depth]' "$img" 2>/dev/null)

    # Check if optimization needed
    if [ "$BIT_DEPTH" -gt 8 ]; then
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
    fi

    # Optimize if not 8-bit
    if [ "$BIT_DEPTH" -gt 8 ]; then
        echo -e "  ${GREEN}✓${RESET} Optimizing $img (${BIT_DEPTH}-bit → 8-bit)"
        pngquant --force --ext .png --quality 85-100 --skip-if-larger "$img" 2>/dev/null || true
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
