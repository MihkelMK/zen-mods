#!/bin/bash

##########################################################
#          -* Zen Mods Sideloader - MihkelMK *-          #
#                   ------------------                   #
#         Some code is generated with Claude 3.7         #
##########################################################
#################    INFO FOR MODDERS    #################
# - Mods need to be in sibling subdirectories            #
# - Mods need to have chrome.css, theme.json             #
# - chrome.css (and preferences.json if used)            #
#   need to be publicly hosted (ex. on GitHub)           #
# - Add "enabled: false" to theme.json to sync GUI       #
#   on first load (otherwise it looks enabled but isn't) #
##########################################################
##################    INFO FOR USERS    ##################
# - Installing jq is HIGHLY recommended (grep is hacky)  #
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

    # Extract theme data using jq (if available) or grep + cut as fallback
    if command -v jq &>/dev/null; then
        THEME_NAME=$(jq -r '.name' "$THEME_FILE")
        THEME_DESC=$(jq -r '.description' "$THEME_FILE")
        THEME_VERSION=$(jq -r '.version' "$THEME_FILE")
        THEME_ID=$(jq -r '.id' "$THEME_FILE")
    else
        THEME_NAME=$(grep -o '"name": *"[^"]*"' "$THEME_FILE" | cut -d'"' -f4)
        THEME_DESC=$(grep -o '"description": *"[^"]*"' "$THEME_FILE" | cut -d'"' -f4)
        THEME_VERSION=$(grep -o '"version": *"[^"]*"' "$THEME_FILE" | cut -d'"' -f4)
        THEME_ID=$(grep -o '"id": *"[^"]*"' "$THEME_FILE" | cut -d'"' -f4)
    fi

    # Check if theme is already installed by looking for ID in zen-themes.json
    INSTALLED_VERSION=""
    ZEN_THEMES_JSON="$PROFILE_PATH/zen-themes.json"
    if [ -f "$ZEN_THEMES_JSON" ]; then
        if command -v jq &>/dev/null; then
            if jq -e ".\"$THEME_ID\"" "$ZEN_THEMES_JSON" >/dev/null 2>&1; then
                INSTALLED_VERSION=$(jq -r ".\"$THEME_ID\".version" "$ZEN_THEMES_JSON")
            fi
        else
            if grep -q "\"$THEME_ID\"" "$ZEN_THEMES_JSON"; then
                INSTALLED_VERSION=$(grep -o "\"$THEME_ID\"[^}]*\"version\": *\"[^\"]*\"" "$ZEN_THEMES_JSON" | grep -o "\"version\": *\"[^\"]*\"" | cut -d'"' -f4)
            fi
        fi
    fi

    # Store values in arrays
    MOD_DIRS[COUNT]="$MOD_DIR"
    THEME_NAMES[COUNT]="$THEME_NAME"
    THEME_DESCRIPTIONS[COUNT]="$THEME_DESC"
    THEME_VERSIONS[COUNT]="$THEME_VERSION"

    CURRENT_VERSION="$THEME_VERSION"
    VERSION_COLOR="$BLUE"
    INSTALLED_STATUS=""
    UPDATE_STATUS=""

    if [ "$INSTALLED_VERSION" ]; then
        INSTALLED_STATUS="(Installed)"

        if [ "$INSTALLED_VERSION" != "$THEME_VERSION" ]; then
            CURRENT_VERSION="$INSTALLED_VERSION"
            VERSION_COLOR="$RED"
            UPDATE_STATUS="v${THEME_VERSION} available"
        fi
    fi

    # Display theme information with index in yay style
    echo -e "${BOLD}${PURPLE}$COUNT${NC} ${BOLD}${WHITE}${THEME_NAMES[$COUNT]}${NC} ${VERSION_COLOR}${CURRENT_VERSION}${NC} ${GREEN}${INSTALLED_STATUS}${NC} ${YELLOW}${UPDATE_STATUS}${NC}"

    # Indented soft-wrap of description
    echo -e "${THEME_DESCRIPTIONS[$COUNT]}${NC}" | fold -s -w $((COLUMNS - 4)) | sed -e "s/^/    /"

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
    if command -v jq &>/dev/null; then
        THEME_ID=$(jq -r '.id' "$MOD_DIR/theme.json")
    else
        THEME_ID=$(grep -o '"id": *"[^"]*"' "$MOD_DIR/theme.json" | cut -d'"' -f4)
    fi

    echo -e "${BOLD}${BLUE}::${NC} Installing ${BOLD}${THEME_NAME}${GREY}-${THEME_VERSION}${NC}"

    # Check if the theme directory contains CSS files
    CSS_FILES=$(find "$MOD_DIR" -name "*.css" | wc -l)

    if [ "$CSS_FILES" -eq 0 ]; then
        echo -e "   ${BOLD}${YELLOW}warning:${NC} No CSS files found in $MOD_DIR"
        FAILED[FAILED_COUNT]=${THEME_NAME}
        ((FAILED_COUNT++))
        continue
    fi

    # Create the destination directory for this specific theme
    DEST_DIR="$PROFILE_PATH/chrome/zen-themes/$THEME_ID"

    # Check if the destination directory already exists
    if [ -d "$DEST_DIR" ]; then
        echo -ne "   ${YELLOW}Theme files already exist.${NC} ${BOLD}Overwrite? [Y/n]${NC} "
        read -r OVERWRITE

        if [[ "$OVERWRITE" =~ ^[nN]$ ]]; then
            echo -e "   ${BOLD}${BLUE}info:${NC} Skipped ${WHITE}${THEME_NAME}${NC}"
            UNCHANGED[UNCHANGED_COUNT]="${THEME_NAME}"
            ((UNCHANGED_COUNT++))

            # Check if the theme is already in zen-themes.json
            if [ -f "$PROFILE_PATH/zen-themes.json" ]; then
                if command -v jq &>/dev/null; then
                    if jq -e ".\"$THEME_ID\"" "$PROFILE_PATH/zen-themes.json" >/dev/null 2>&1; then
                        echo -e "   ${BOLD}${BLUE}info:${NC} Theme is already in zen-themes.json"
                        continue
                    fi
                else
                    if grep -q "\"$THEME_ID\"" "$PROFILE_PATH/zen-themes.json"; then
                        echo -e "   ${BOLD}${BLUE}info:${NC} Theme is already in zen-themes.json"
                        continue
                    fi
                fi
            fi

            # If we're here, we need to add to json but not copy files
            echo -e "   ${BOLD}${BLUE}info:${NC} Adding theme to zen-themes.json without overwriting files"
        else
            # User wants to overwrite, remove existing directory first
            rm -rf "$DEST_DIR"
            mkdir -p "$DEST_DIR"
        fi
    else
        mkdir -p "$DEST_DIR"
    fi

    # Copy theme files to the destination
    if [[ ! -d "$DEST_DIR" || ! "$OVERWRITE" =~ ^[Nn]$ ]]; then
        if ! cp -r "$MOD_DIR"/* "$DEST_DIR/" 2>/dev/null; then
            echo -e "   ${BOLD}${RED}error:${NC} Failed to copy theme files for ${WHITE}${THEME_NAME}${NC}"
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
    if command -v jq &>/dev/null; then
        if ! jq empty "$ZEN_THEMES_JSON" 2>/dev/null; then
            echo -e "   ${BOLD}${YELLOW}warning:${NC} $ZEN_THEMES_JSON is not a valid JSON file. Creating a new one."
            echo "{}" >"$ZEN_THEMES_JSON"
        fi
    fi

    # Update zen-themes.json with the new theme
    if command -v jq &>/dev/null; then
        # Use jq to merge the theme.json content into zen-themes.json
        THEME_JSON=$(cat "$MOD_DIR/theme.json")
        TMP_FILE=$(mktemp)

        # Check if theme already exists
        if jq -e ".[\"$THEME_ID\"]" "$ZEN_THEMES_JSON" &>/dev/null; then
            # Theme exists - check if we should overwrite
            if ! [[ "$OVERWRITE" =~ ^[nN]$ ]]; then
                # Overwrite the existing theme
                if jq --argjson theme "$THEME_JSON" ".\"$THEME_ID\" = \$theme" "$ZEN_THEMES_JSON" >"$TMP_FILE" && mv "$TMP_FILE" "$ZEN_THEMES_JSON"; then
                    echo -e "   ${BOLD}${GREEN}success:${NC} Updated ${WHITE}${THEME_NAME}${NC}"
                    INSTALLED[INSTALLED_COUNT]=${THEME_NAME}
                    ((INSTALLED_COUNT++))
                else
                    echo -e "   ${BOLD}${YELLOW}warning:${NC} Failed to update zen-themes.json for ${WHITE}${THEME_NAME}${NC}"
                    FAILED[FAILED_COUNT]=${THEME_NAME}
                    ((FAILED_COUNT++))
                fi
            fi
        else
            # Theme doesn't exist - add it
            if jq --argjson theme "$THEME_JSON" ". + {\"$THEME_ID\": \$theme}" "$ZEN_THEMES_JSON" >"$TMP_FILE" && mv "$TMP_FILE" "$ZEN_THEMES_JSON"; then
                echo -e "   ${BOLD}${GREEN}success:${NC} Installed ${WHITE}${THEME_NAME}${NC}"
                INSTALLED[INSTALLED_COUNT]=${THEME_NAME}
                ((INSTALLED_COUNT++))
            else
                echo -e "   ${BOLD}${YELLOW}warning:${NC} Failed to update zen-themes.json for ${WHITE}${THEME_NAME}${NC}"
                FAILED[FAILED_COUNT]=${THEME_NAME}
                ((FAILED_COUNT++))
            fi
        fi
    else
        echo -e "${BOLD}${YELLOW}warning:${NC} jq not found, manual validation recommended"

        # Create a temporary file for processing
        TMP_FILE=$(mktemp)

        # Check if the theme already exists in the file
        if grep -q "\"$THEME_ID\":" "$ZEN_THEMES_JSON"; then
            # Theme exists - check if we should overwrite
            if ! [[ "$OVERWRITE" =~ ^[nN]$ ]]; then
                # Extract content before the theme definition
                START_POS=$(grep -b -o "\"$THEME_ID\":" "$ZEN_THEMES_JSON" | cut -d: -f1)

                # Get everything before the theme
                head -c "$START_POS" "$ZEN_THEMES_JSON" >"$TMP_FILE"

                # Find the position after this theme's closing brace (accounting for nested braces)
                REMAINING=$(tail -c "+$((START_POS + 1))" "$ZEN_THEMES_JSON")
                BRACE_COUNT=0
                SCAN_POS=0
                IN_QUOTES=false
                ESCAPE_NEXT=false

                for ((i = 0; i < ${#REMAINING}; i++)); do
                    char="${REMAINING:$i:1}"

                    if [ "$ESCAPE_NEXT" = true ]; then
                        ESCAPE_NEXT=false
                        continue
                    fi

                    if [ "$char" = "\\" ]; then
                        ESCAPE_NEXT=true
                        continue
                    fi

                    if [ "$char" = "\"" ]; then
                        IN_QUOTES=$([ "$IN_QUOTES" = true ] && echo false || echo true)
                        continue
                    fi

                    if [ "$IN_QUOTES" = false ]; then
                        if [ "$char" = "{" ]; then
                            ((BRACE_COUNT++))
                        elif [ "$char" = "}" ]; then
                            ((BRACE_COUNT--))
                            if [ $BRACE_COUNT -eq -1 ]; then
                                SCAN_POS=$((i + 1))
                                break
                            fi
                        fi
                    fi
                done

                # Write the new theme definition
                echo -n "\"$THEME_ID\":" >>"$TMP_FILE"
                cat "$MOD_DIR/theme.json" >>"$TMP_FILE"

                # Append the remainder of the file
                if [ $SCAN_POS -lt ${#REMAINING} ]; then
                    echo -n "${REMAINING:$SCAN_POS}" >>"$TMP_FILE"
                fi

                # Replace the original file
                mv "$TMP_FILE" "$ZEN_THEMES_JSON"

                echo -e "   ${BOLD}${GREEN}success:${NC} Updated ${WHITE}${THEME_NAME}${NC}"
                INSTALLED[INSTALLED_COUNT]=${THEME_NAME}
                ((INSTALLED_COUNT++))
            else
                rm "$TMP_FILE" # Clean up temp file
            fi
        else
            # Theme doesn't exist - add it using the original approach
            # Check if file ends with } and remove the last }
            LAST_CHAR=$(tail -c 2 "$ZEN_THEMES_JSON")
            if [ "$LAST_CHAR" == "}" ]; then
                # Remove the last character (})
                sed -i '$ s/.$//' "$ZEN_THEMES_JSON"
                # Check if the file has more than just {
                if [ "$(cat "$ZEN_THEMES_JSON")" != "{" ]; then
                    # Add a comma
                    echo -n "," >>"$ZEN_THEMES_JSON"
                fi
            fi

            # Append the new theme
            {
                echo -n "\"$THEME_ID\":"
                cat "$MOD_DIR/theme.json"
                echo "}"
            } >>"$ZEN_THEMES_JSON"

            echo -e "   ${BOLD}${GREEN}success:${NC} Installed ${WHITE}${THEME_NAME}${NC}"
            INSTALLED[INSTALLED_COUNT]=${THEME_NAME}
            ((INSTALLED_COUNT++))
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
