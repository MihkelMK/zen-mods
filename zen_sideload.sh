#!/bin/bash

##########################################################
#          -* Zen Mods Sideloader - MihkelMK *-          #
#                   ------------------                   #
#         Some code is generated with Claude 3.7         #
##########################################################
#################    INFO FOR MODDERS    #################
# - Mods need to be in sibling subdirectories            #
# - Mods need to have theme.json with the following:     #
#   - id (uuidv4)                                        #
#   - title                                              #
#   - description                                        #
#   - version (MAYOR.MINOR.PATCH)                        #
##########################################################
##################    INFO FOR USERS    ##################
# - jq is REQUIRED for this script to work               #
# - You need to manually enable mods after install       #
# - How to find your profile directory:                  #
#   1. Go to about:profiles in your browser              #
#   2. Find "This is the profile you use... be deleted." #
#   3. Use the Root Directory of that Profile            #
#      - I suggest making a backup of that directory     #
##########################################################

# Colors
BOLD='\033[1m'
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[0;37m'
GREY='\033[0;90m'
NC='\033[0m' # No Color

# Check if jq is installed
if ! command -v jq &>/dev/null; then
    echo -e "${BOLD}${RED}error:${NC} jq is required for this script. Please install jq and try again."
    exit 1
fi

# Check if a path argument is provided
if [ "$#" -ne 1 ]; then
    echo -e "${BOLD}${YELLOW}Usage:${NC} $0 <path_to_profile_dir>"
    exit 1
fi

PROFILE_PATH="$1"

# Check if the provided path exists
if [ ! -d "$PROFILE_PATH" ]; then
    echo -e "${BOLD}${RED}error:${NC} Directory $PROFILE_PATH does not exist"
    exit 1
fi

# Find all theme.json files
THEME_FILES=$(find ~+ -mindepth 2 -maxdepth 2 -name "theme.json" | sort)

if [ -z "$THEME_FILES" ]; then
    echo -e "${BOLD}${RED}error:${NC} No theme.json files found in subdirectories"
    exit 1
fi

# Store theme data in arrays
declare -a MOD_DIRS
declare -a THEME_NAMES
declare -a THEME_DESCRIPTIONS
declare -a THEME_VERSIONS
declare -a INSTALLED
declare -a FAILED
declare -a UNCHANGED

echo ""
echo -e "${BOLD}${GREEN}:: ${WHITE}Zen Mods Sideloader${NC}"
echo -e "${BOLD}${CYAN}==============================================${NC}"
echo ""

# Counter for indexing themes
COUNT=1

# Parse theme.json files and list available themes
for THEME_FILE in $THEME_FILES; do
    # Get the directory containing the theme.json file
    MOD_DIR=$(dirname "$THEME_FILE")

    # Extract theme data using jq
    THEME_NAME=$(jq -r '.name' "$THEME_FILE")
    THEME_DESC=$(jq -r '.description' "$THEME_FILE")
    THEME_VERSION=$(jq -r '.version' "$THEME_FILE")
    THEME_ID=$(jq -r '.id' "$THEME_FILE")

    # Store values in arrays
    MOD_DIRS[COUNT]="$MOD_DIR"
    THEME_NAMES[COUNT]="$THEME_NAME"
    THEME_DESCRIPTIONS[COUNT]="$THEME_DESC"
    THEME_VERSIONS[COUNT]="$THEME_VERSION"

    # Check if symlink already exists
    DEST_DIR="$PROFILE_PATH/chrome/zen-themes/$THEME_ID"
    INSTALLED_STATUS=""
    if [ -L "$DEST_DIR" ]; then
        INSTALLED_STATUS="(Installed)"
    fi

    # Display theme information with index in yay style
    echo -e "${BOLD}${PURPLE}$COUNT${NC} ${BOLD}${WHITE}${THEME_NAMES[$COUNT]}${NC} ${BLUE}${THEME_VERSION}${NC} ${GREEN}${INSTALLED_STATUS}${NC}"

    # Indented soft-wrap of description
    FOLD_OPTIONS="-s"
    if [ $COLUMNS ]; then
        FOLD_OPTIONS="-sw $((COLUMNS - 4))"
    fi

    echo -e "${THEME_DESCRIPTIONS[$COUNT]}${NC}" | fold "$FOLD_OPTIONS" | sed -e "s/^/    /"

    ((COUNT++))
done

# Total number of themes
TOTAL=$((COUNT - 1))

echo -e "${GREEN}==>${NC} Mods to install (eg: 1 3 5 or 1-5)"
echo -ne "${GREEN}==>${NC} "
read -r SELECTIONINPUT

# Check if input contains a hyphen (range format)
if [[ "$SELECTIONINPUT" =~ ^[0-9]+-[0-9]+$ ]]; then
    # Extract the start and end of the range
    seq_start=$(echo "$SELECTIONINPUT" | cut -d'-' -f1)
    seq_end=$(echo "$SELECTIONINPUT" | cut -d'-' -f2)

    # Generate the sequence
    SELECTIONS=$(seq "$seq_start" "$seq_end")
else
    # Input is already space-separated, just echo it
    SELECTIONS="$SELECTIONINPUT"
fi

# Count the number of themes to install
NUM_TO_INSTALL=$(echo "$SELECTIONS" | wc -w)
echo -e "\n${BOLD}${GREEN}::${NC} Preparing to install ${GREEN}$NUM_TO_INSTALL${NC} mods"

# Validate and process user selections
INSTALLED_COUNT=0
FAILED_COUNT=0
UNCHANGED_COUNT=0

for SEL in $SELECTIONS; do
    echo ""

    # Check if selection is a number and within valid range
    if ! [[ "$SEL" =~ ^[0-9]+$ ]] || [ "$SEL" -lt 1 ] || [ "$SEL" -gt "$TOTAL" ]; then
        echo -e "${BOLD}${YELLOW}warning:${NC} Invalid selection: $SEL (must be between 1 and $TOTAL)"
        continue
    fi

    MOD_DIR="${MOD_DIRS[$SEL]}"
    THEME_NAME="${THEME_NAMES[$SEL]}"
    THEME_VERSION="${THEME_VERSIONS[$SEL]}"

    # Get the theme ID from the theme.json file
    THEME_ID=$(jq -r '.id' "$MOD_DIR/theme.json")

    echo -e "${BOLD}${BLUE}::${NC} Installing ${BOLD}${THEME_NAME}${GREY}-${THEME_VERSION}${NC}"

    # Check if the theme directory contains CSS files
    CSS_FILES=$(find "$MOD_DIR" -name "*.css" | wc -l)

    if [ "$CSS_FILES" -eq 0 ]; then
        echo -e "   ${BOLD}${YELLOW}warning:${NC} No CSS files found in $MOD_DIR"
        FAILED[FAILED_COUNT]=${THEME_NAME}
        ((FAILED_COUNT++))
        continue
    fi

    # Make sure the parent directory exists
    mkdir -p "$PROFILE_PATH/chrome/zen-themes"

    # The destination for the symbolic link
    DEST_DIR="$PROFILE_PATH/chrome/zen-themes/$THEME_ID"

    # Check if the destination directory already exists
    if [ -L "$DEST_DIR" ] || [ -d "$DEST_DIR" ]; then
        echo -ne "   ${YELLOW}Theme link already exists.${NC} ${BOLD}Overwrite? [y/N]${NC} "
        read -r OVERWRITE

        if [[ "$OVERWRITE" =~ ^[nN]$ ]]; then
            echo -e "   ${BOLD}${BLUE}info:${NC} Skipped ${WHITE}${THEME_NAME}${NC}"
            UNCHANGED[UNCHANGED_COUNT]="${THEME_NAME}"
            ((UNCHANGED_COUNT++))

            # Check if the theme is already in zen-themes.json
            if [ -f "$PROFILE_PATH/zen-themes.json" ]; then
                if jq -e ".\"$THEME_ID\"" "$PROFILE_PATH/zen-themes.json" >/dev/null 2>&1; then
                    continue
                fi
            fi

            # If we're here, we need to add to json but not create symlink
            echo -e "   ${BOLD}${BLUE}info:${NC} Adding theme to zen-themes.json without creating a new symlink"
        else
            # User wants to overwrite, remove existing link or directory first
            rm -rf "$DEST_DIR"
        fi
    fi

    # Create the symbolic link if it doesn't exist or user wants to overwrite
    if [[ ! -L "$DEST_DIR" && ! -d "$DEST_DIR" ]] || [[ ! "$OVERWRITE" =~ ^[Yy]$ ]]; then
        if ! ln -s "$MOD_DIR" "$DEST_DIR"; then
            echo -e "   ${BOLD}${RED}error:${NC} Failed to create symbolic link for ${WHITE}${THEME_NAME}${NC}"
            FAILED[FAILED_COUNT]=${THEME_NAME}
            ((FAILED_COUNT++))
            continue
        fi
    fi

    # Append the theme.json content to zen-themes.json
    ZEN_THEMES_JSON="$PROFILE_PATH/zen-themes.json"

    # Create the zen-themes.json file if it doesn't exist
    if [ ! -f "$ZEN_THEMES_JSON" ]; then
        echo "{}" >"$ZEN_THEMES_JSON"
    fi

    # Check if zen-themes.json is a valid JSON file
    if ! jq empty "$ZEN_THEMES_JSON" 2>/dev/null; then
        echo -e "   ${BOLD}${YELLOW}warning:${NC} $ZEN_THEMES_JSON is not a valid JSON file. Creating a new one."
        echo "{}" >"$ZEN_THEMES_JSON"
    fi

    # Update zen-themes.json with the new theme
    THEME_JSON=$(cat "$MOD_DIR/theme.json")
    TMP_FILE=$(mktemp)

    # Check if theme isn't loaded into the browser
    if ! jq -e ".[\"$THEME_ID\"]" "$ZEN_THEMES_JSON" &>/dev/null; then
        # Theme doesn't exist - add it with enabled:false

        # First modify the theme JSON to set enabled to false
        # Add preferences:true if preferences.json exists
        if [ -f "$MOD_DIR/preferences.json" ]; then
            THEME_JSON_DISABLED=$(echo "$THEME_JSON" | jq '. + {"enabled": false, "preferences": true}')
        else
            THEME_JSON_DISABLED=$(echo "$THEME_JSON" | jq '. + {"enabled": false}')
        fi

        if jq --argjson theme "$THEME_JSON_DISABLED" ". + {\"$THEME_ID\": \$theme}" "$ZEN_THEMES_JSON" >"$TMP_FILE" && mv "$TMP_FILE" "$ZEN_THEMES_JSON"; then
            echo -e "   ${BOLD}${GREEN}success:${NC} Installed ${WHITE}${THEME_NAME}${NC} (disabled by default)"
            INSTALLED[INSTALLED_COUNT]=${THEME_NAME}
            ((INSTALLED_COUNT++))
        else
            echo -e "   ${BOLD}${YELLOW}warning:${NC} Failed to update zen-themes.json for ${WHITE}${THEME_NAME}${NC}"
            FAILED[FAILED_COUNT]=${THEME_NAME}
            ((FAILED_COUNT++))
        fi
    fi
done

echo ""
echo -e "${BOLD}${GREEN}:: ${WHITE}Installation complete${NC}"
if [ $INSTALLED_COUNT -gt 0 ]; then
    echo -e "\n${BOLD}${GREEN}$INSTALLED_COUNT${NC} themes installed successfully:"
    for ((i = 0; i < INSTALLED_COUNT; i++)); do
        echo -e "   - ${GREEN}${INSTALLED[$i]}${NC}"
    done
fi
if [ $FAILED_COUNT -gt 0 ]; then
    echo -e "\n${BOLD}${YELLOW}$FAILED_COUNT${NC} themes failed to install:"
    for ((i = 0; i < FAILED_COUNT; i++)); do
        echo -e "   - ${YELLOW}${FAILED[$i]}${NC}"
    done
fi
if [ $UNCHANGED_COUNT -gt 0 ]; then
    echo -e "\n${BOLD}${BLUE}$UNCHANGED_COUNT${NC} themes left unchanged:"
    for ((i = 0; i < UNCHANGED_COUNT; i++)); do
        echo -e "   - ${BLUE}${UNCHANGED[$i]}${NC}"
    done
fi
