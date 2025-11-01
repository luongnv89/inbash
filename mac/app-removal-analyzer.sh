#!/bin/bash

#==============================================================================
# App Removal Analyzer for macOS
#==============================================================================
# Description: Interactive dry-run tool to analyze installed applications
#              and generate a step-by-step removal plan without performing
#              any actual deletions.
#
# Usage: ./app-removal-analyzer.sh [--help]
#
# Author: Auto-generated
# Version: 1.0.0
#==============================================================================

set -euo pipefail

# Color codes for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly CYAN='\033[0;36m'
readonly BOLD='\033[1m'
readonly RESET='\033[0m'

# Output directory
readonly OUTPUT_DIR="$HOME/Desktop/app-removal-plans"

# Global arrays to store found items
declare -a GUI_APPS=()
declare -a GUI_APP_BUNDLE_IDS=()
declare -a BREW_CASKS=()
declare -a BREW_FORMULAE=()
declare -a MAS_APPS=()
declare -a MAS_APP_IDS=()
declare -a NPM_PACKAGES=()
declare -a YARN_PACKAGES=()
declare -a PNPM_PACKAGES=()
declare -a PIP_PACKAGES=()
declare -a PIPX_PACKAGES=()

#==============================================================================
# Helper Functions
#==============================================================================

print_header() {
    echo -e "${BOLD}${CYAN}╔════════════════════════════════════════════════════════════════╗${RESET}"
    echo -e "${BOLD}${CYAN}║       macOS App Removal Analyzer - DRY RUN TOOL ONLY          ║${RESET}"
    echo -e "${BOLD}${CYAN}╚════════════════════════════════════════════════════════════════╝${RESET}"
    echo ""
}

print_disclaimer() {
    echo -e "${BOLD}${YELLOW}⚠️  DISCLAIMER:${RESET}"
    echo -e "${YELLOW}This script performs NO deletions - it only analyzes and generates a plan.${RESET}"
    echo -e "${YELLOW}You will manually execute the removal steps in a separate terminal.${RESET}"
    echo ""
}

show_help() {
    print_header
    echo "Usage: $0 [--help]"
    echo ""
    echo "This script helps you safely remove applications from macOS by:"
    echo "  1. Searching for the app across all installation methods"
    echo "  2. Finding related files, caches, and user data"
    echo "  3. Generating a detailed, step-by-step removal plan"
    echo ""
    echo "Options:"
    echo "  --help, -h    Show this help message"
    echo ""
    echo "The script searches:"
    echo "  • GUI Applications (.app bundles)"
    echo "  • Homebrew packages (casks and formulae)"
    echo "  • Mac App Store apps"
    echo "  • npm, yarn, pnpm, pip, pipx packages"
    echo "  • User Library files and caches"
    echo "  • LaunchAgents and helper processes"
    echo ""
    echo "Output is saved to: $OUTPUT_DIR"
    exit 0
}

log_info() {
    echo -e "${BLUE}ℹ${RESET}  $1"
}

log_success() {
    echo -e "${GREEN}✓${RESET}  $1"
}

log_warning() {
    echo -e "${YELLOW}⚠${RESET}  $1"
}

log_error() {
    echo -e "${RED}✗${RESET}  $1"
}

#==============================================================================
# Search Functions
#==============================================================================

search_gui_apps() {
    local search_term="$1"
    log_info "Searching for GUI applications..."
    
    local found_apps=()
    
    # Search in /Applications and ~/Applications
    while IFS= read -r app_path; do
        # Skip empty results
        [[ -z "$app_path" ]] && continue
        
        # Get bundle identifier
        local bundle_id=""
        if [[ -f "$app_path/Contents/Info.plist" ]]; then
            bundle_id=$(/usr/libexec/PlistBuddy -c "Print CFBundleIdentifier" "$app_path/Contents/Info.plist" 2>/dev/null || echo "")
            
            # Skip Apple system apps
            if [[ "$bundle_id" =~ ^com\.apple\. ]]; then
                continue
            fi
        fi
        
        GUI_APPS+=("$app_path")
        GUI_APP_BUNDLE_IDS+=("$bundle_id")
        found_apps+=("$(basename "$app_path")")
    done < <(find /Applications ~/Applications -maxdepth 3 -name "*.app" -type d 2>/dev/null | grep -i "$search_term" || true)
    
    if [[ ${#found_apps[@]} -gt 0 ]]; then
        log_success "Found ${#found_apps[@]} GUI app(s): ${found_apps[*]}"
    fi
}

search_homebrew() {
    local search_term="$1"
    
    if ! command -v brew &>/dev/null; then
        return
    fi
    
    log_info "Searching Homebrew packages..."
    
    # Search casks
    while IFS= read -r cask; do
        [[ -z "$cask" ]] && continue
        BREW_CASKS+=("$cask")
    done < <(brew list --cask 2>/dev/null | grep -i "$search_term" || true)
    
    # Search formulae
    while IFS= read -r formula; do
        [[ -z "$formula" ]] && continue
        BREW_FORMULAE+=("$formula")
    done < <(brew list --formula 2>/dev/null | grep -i "$search_term" || true)
    
    if [[ ${#BREW_CASKS[@]} -gt 0 ]]; then
        log_success "Found ${#BREW_CASKS[@]} Homebrew cask(s): ${BREW_CASKS[*]}"
    fi
    if [[ ${#BREW_FORMULAE[@]} -gt 0 ]]; then
        log_success "Found ${#BREW_FORMULAE[@]} Homebrew formula(e): ${BREW_FORMULAE[*]}"
    fi
}

search_mas() {
    local search_term="$1"
    
    if ! command -v mas &>/dev/null; then
        return
    fi
    
    log_info "Searching Mac App Store apps..."
    
    while IFS= read -r line; do
        [[ -z "$line" ]] && continue
        local app_id=$(echo "$line" | awk '{print $1}')
        local app_name=$(echo "$line" | cut -d' ' -f2-)
        MAS_APPS+=("$app_name")
        MAS_APP_IDS+=("$app_id")
    done < <(mas list 2>/dev/null | grep -i "$search_term" || true)
    
    if [[ ${#MAS_APPS[@]} -gt 0 ]]; then
        log_success "Found ${#MAS_APPS[@]} Mac App Store app(s): ${MAS_APPS[*]}"
    fi
}

search_npm() {
    local search_term="$1"
    
    if ! command -v npm &>/dev/null; then
        return
    fi
    
    log_info "Searching npm global packages..."
    
    while IFS= read -r pkg; do
        [[ -z "$pkg" ]] && continue
        NPM_PACKAGES+=("$pkg")
    done < <(npm list -g --depth=0 2>/dev/null | grep -i "$search_term" | awk '{print $2}' | cut -d'@' -f1 || true)
    
    if [[ ${#NPM_PACKAGES[@]} -gt 0 ]]; then
        log_success "Found ${#NPM_PACKAGES[@]} npm package(s): ${NPM_PACKAGES[*]}"
    fi
}

search_yarn() {
    local search_term="$1"
    
    if ! command -v yarn &>/dev/null; then
        return
    fi
    
    log_info "Searching yarn global packages..."
    
    while IFS= read -r pkg; do
        [[ -z "$pkg" ]] && continue
        YARN_PACKAGES+=("$pkg")
    done < <(yarn global list 2>/dev/null | grep -i "$search_term" | awk '{print $2}' | cut -d'@' -f1 || true)
    
    if [[ ${#YARN_PACKAGES[@]} -gt 0 ]]; then
        log_success "Found ${#YARN_PACKAGES[@]} yarn package(s): ${YARN_PACKAGES[*]}"
    fi
}

search_pnpm() {
    local search_term="$1"
    
    if ! command -v pnpm &>/dev/null; then
        return
    fi
    
    log_info "Searching pnpm global packages..."
    
    while IFS= read -r pkg; do
        [[ -z "$pkg" ]] && continue
        PNPM_PACKAGES+=("$pkg")
    done < <(pnpm list -g --depth=0 2>/dev/null | grep -i "$search_term" | awk '{print $2}' | cut -d'@' -f1 || true)
    
    if [[ ${#PNPM_PACKAGES[@]} -gt 0 ]]; then
        log_success "Found ${#PNPM_PACKAGES[@]} pnpm package(s): ${PNPM_PACKAGES[*]}"
    fi
}

search_pip() {
    local search_term="$1"
    
    if ! command -v pip &>/dev/null && ! command -v pip3 &>/dev/null; then
        return
    fi
    
    log_info "Searching pip packages..."
    
    local pip_cmd="pip"
    if ! command -v pip &>/dev/null; then
        pip_cmd="pip3"
    fi
    
    while IFS= read -r pkg; do
        [[ -z "$pkg" ]] && continue
        PIP_PACKAGES+=("$pkg")
    done < <($pip_cmd list 2>/dev/null | grep -i "$search_term" | awk '{print $1}' || true)
    
    if [[ ${#PIP_PACKAGES[@]} -gt 0 ]]; then
        log_success "Found ${#PIP_PACKAGES[@]} pip package(s): ${PIP_PACKAGES[*]}"
    fi
}

search_pipx() {
    local search_term="$1"
    
    if ! command -v pipx &>/dev/null; then
        return
    fi
    
    log_info "Searching pipx packages..."
    
    while IFS= read -r pkg; do
        [[ -z "$pkg" ]] && continue
        PIPX_PACKAGES+=("$pkg")
    done < <(pipx list 2>/dev/null | grep "package" | grep -i "$search_term" | awk '{print $2}' || true)
    
    if [[ ${#PIPX_PACKAGES[@]} -gt 0 ]]; then
        log_success "Found ${#PIPX_PACKAGES[@]} pipx package(s): ${PIPX_PACKAGES[*]}"
    fi
}

#==============================================================================
# Analysis Functions
#==============================================================================

find_user_library_files() {
    local bundle_id="$1"
    local app_name="$2"
    local result_array_name="$3"
    
    # Directories to search
    local search_dirs=(
        "$HOME/Library/Application Support"
        "$HOME/Library/Caches"
        "$HOME/Library/Containers"
        "$HOME/Library/Group Containers"
        "$HOME/Library/Preferences"
        "$HOME/Library/Preferences/ByHost"
        "$HOME/Library/Logs"
        "$HOME/Library/Saved Application State"
        "$HOME/Library/WebKit"
        "$HOME/Library/LaunchAgents"
    )
    
    for dir in "${search_dirs[@]}"; do
        if [[ ! -d "$dir" ]]; then
            continue
        fi
        
        # Search by bundle ID
        if [[ -n "$bundle_id" ]]; then
            while IFS= read -r found; do
                [[ -z "$found" ]] && continue
                eval "${result_array_name}+=(\"\$found\")"
            done < <(find "$dir" -maxdepth 2 -iname "*${bundle_id}*" 2>/dev/null || true)
        fi
        
        # Search by app name (without .app extension)
        local clean_name="${app_name%.app}"
        while IFS= read -r found; do
            [[ -z "$found" ]] && continue
            # Avoid duplicates
            eval "local existing=(\"\${${result_array_name}[@]:-}\")"
            if [[ ! " ${existing[*]} " =~ " ${found} " ]]; then
                eval "${result_array_name}+=(\"\$found\")"
            fi
        done < <(find "$dir" -maxdepth 2 -iname "*${clean_name}*" 2>/dev/null || true)
    done
}

find_launch_agents() {
    local bundle_id="$1"
    local app_name="$2"
    local result_array_name="$3"
    
    local launch_dir="$HOME/Library/LaunchAgents"
    
    if [[ ! -d "$launch_dir" ]]; then
        return
    fi
    
    if [[ -n "$bundle_id" ]]; then
        while IFS= read -r found; do
            [[ -z "$found" ]] && continue
            eval "${result_array_name}+=(\"\$found\")"
        done < <(find "$launch_dir" -name "*.plist" -maxdepth 1 2>/dev/null | xargs grep -l "$bundle_id" 2>/dev/null || true)
    fi
    
    local clean_name="${app_name%.app}"
    while IFS= read -r found; do
        [[ -z "$found" ]] && continue
        eval "local existing=(\"\${${result_array_name}[@]:-}\")"
        if [[ ! " ${existing[*]} " =~ " ${found} " ]]; then
            eval "${result_array_name}+=(\"\$found\")"
        fi
    done < <(find "$launch_dir" -name "*${clean_name}*.plist" -maxdepth 1 2>/dev/null || true)
}

find_running_processes() {
    local app_name="$1"
    local result_array_name="$2"
    
    local clean_name="${app_name%.app}"
    
    while IFS= read -r proc; do
        [[ -z "$proc" ]] && continue
        eval "${result_array_name}+=(\"\$proc\")"
    done < <(ps aux | grep -i "$clean_name" | grep -v "grep" | awk '{print $11}' || true)
}

detect_uninstaller() {
    local app_path="$1"
    local app_name=$(basename "$app_path")
    local clean_name="${app_name%.app}"
    
    # Check inside app bundle
    if [[ -d "$app_path/Contents/Resources" ]]; then
        local uninstaller=$(find "$app_path/Contents/Resources" -iname "*uninstall*" -type f -o -iname "*uninstall*.app" -type d 2>/dev/null | head -n1)
        if [[ -n "$uninstaller" ]]; then
            echo "$uninstaller"
            return
        fi
    fi
    
    # Check for sibling uninstaller
    local parent_dir=$(dirname "$app_path")
    if [[ -d "$parent_dir/${clean_name} Uninstaller.app" ]]; then
        echo "$parent_dir/${clean_name} Uninstaller.app"
        return
    fi
    
    if [[ -f "$parent_dir/Uninstall ${clean_name}.app" ]]; then
        echo "$parent_dir/Uninstall ${clean_name}.app"
        return
    fi
}

#==============================================================================
# Plan Generation
#==============================================================================

generate_removal_plan() {
    local app_name="$1"
    local app_path="$2"
    local bundle_id="$3"
    local output_file="$4"
    
    local clean_name="${app_name%.app}"
    
    # Find related files
    local -a library_files=()
    local -a launch_agents=()
    local -a processes=()
    
    find_user_library_files "$bundle_id" "$app_name" library_files
    find_launch_agents "$bundle_id" "$app_name" launch_agents
    find_running_processes "$app_name" processes
    
    local uninstaller=$(detect_uninstaller "$app_path")
    
    # Generate plan
    {
        echo "# App Removal Plan: $app_name"
        echo ""
        echo "**Generated:** $(date '+%Y-%m-%d %H:%M:%S')"
        echo "**Search Query:** $clean_name"
        echo "**User:** $USER"
        echo ""
        echo "---"
        echo ""
        echo "## ⚠️ IMPORTANT WARNINGS"
        echo ""
        echo "1. **THIS IS A DRY-RUN REPORT** - No files have been deleted"
        echo "2. **BACKUP YOUR DATA** before proceeding with removal"
        echo "3. **REVIEW EACH STEP** carefully before executing"
        echo "4. **Execute commands in a separate terminal** window"
        echo "5. Commands with \`rm -rf\` are DESTRUCTIVE and cannot be undone"
        echo ""
        echo "---"
        echo ""
        echo "## 📋 Removal Steps"
        echo ""
        
        local step=1
        
        # Step: Quit application
        echo "### Step $step: Quit the Application"
        echo ""
        echo "**Purpose:** Ensure the app is not running before removal"
        echo ""
        echo '```bash'
        echo "osascript -e 'quit app \"$clean_name\"'"
        echo '```'
        echo ""
        echo "**Alternative:** Use Activity Monitor to force quit if needed"
        echo ""
        ((step++))
        
        # Step: Stop processes
        if [[ ${#processes[@]} -gt 0 ]]; then
            echo "### Step $step: Stop Helper Processes"
            echo ""
            echo "**Purpose:** Terminate background processes related to the app"
            echo ""
            echo "**Found processes:**"
            for proc in "${processes[@]}"; do
                echo "- \`$proc\`"
            done
            echo ""
            echo '```bash'
            echo "# ⚠️ WARNING: This will kill running processes"
            echo "killall -9 \"$clean_name\""
            echo '```'
            echo ""
            ((step++))
        fi
        
        # Step: Unload LaunchAgents
        if [[ ${#launch_agents[@]} -gt 0 ]]; then
            echo "### Step $step: Unload LaunchAgents"
            echo ""
            echo "**Purpose:** Stop automatic launch services"
            echo ""
            for agent in "${launch_agents[@]}"; do
                local agent_name=$(basename "$agent")
                echo '```bash'
                echo "# Unload LaunchAgent: $agent_name"
                echo "launchctl unload \"$agent\""
                echo '```'
                echo ""
            done
            ((step++))
        fi
        
        # Step: Run native uninstaller (PRIORITIZED)
        if [[ -n "$uninstaller" ]]; then
            echo "### Step $step: Run Native Uninstaller (RECOMMENDED)"
            echo ""
            echo "**Purpose:** Use the app's official uninstaller for clean removal"
            echo ""
            echo "**⭐ This is the PREFERRED method for removing this app**"
            echo ""
            echo "**Uninstaller location:** \`$uninstaller\`"
            echo ""
            if [[ "$uninstaller" == *.app ]]; then
                echo '```bash'
                echo "# Open the uninstaller application"
                echo "open \"$uninstaller\""
                echo '```'
            else
                echo '```bash'
                echo "# Run the uninstaller script"
                echo "\"$uninstaller\""
                echo '```'
            fi
            echo ""
            echo "**Note:** Follow the uninstaller's prompts. After completion, verify that files are removed."
            echo ""
            ((step++))
        fi
        
        # Step: Package manager removal
        local has_pkg_manager=0
        
        # Check for Homebrew cask
        for cask in "${BREW_CASKS[@]:-}"; do
            if [[ "$cask" =~ $clean_name ]]; then
                if [[ $has_pkg_manager -eq 0 ]]; then
                    echo "### Step $step: Uninstall via Package Manager"
                    echo ""
                    has_pkg_manager=1
                fi
                echo "**Homebrew Cask:**"
                echo ""
                echo '```bash'
                echo "# Uninstall Homebrew cask: $cask"
                echo "brew uninstall --cask \"$cask\""
                echo '```'
                echo ""
            fi
        done
        
        # Check for Homebrew formula
        for formula in "${BREW_FORMULAE[@]:-}"; do
            if [[ "$formula" =~ $clean_name ]]; then
                if [[ $has_pkg_manager -eq 0 ]]; then
                    echo "### Step $step: Uninstall via Package Manager"
                    echo ""
                    has_pkg_manager=1
                fi
                echo "**Homebrew Formula:**"
                echo ""
                echo '```bash'
                echo "# Uninstall Homebrew formula: $formula"
                echo "brew uninstall \"$formula\""
                echo '```'
                echo ""
            fi
        done
        
        # Check for Mac App Store
        for i in "${!MAS_APPS[@]}"; do
            if [[ "${MAS_APPS[$i]}" =~ $clean_name ]]; then
                if [[ $has_pkg_manager -eq 0 ]]; then
                    echo "### Step $step: Uninstall via Package Manager"
                    echo ""
                    has_pkg_manager=1
                fi
                echo "**Mac App Store:**"
                echo ""
                echo '```bash'
                echo "# Uninstall Mac App Store app: ${MAS_APPS[$i]}"
                echo "mas uninstall ${MAS_APP_IDS[$i]}"
                echo '```'
                echo ""
            fi
        done
        
        # npm
        for pkg in "${NPM_PACKAGES[@]:-}"; do
            if [[ "$pkg" =~ $clean_name ]]; then
                if [[ $has_pkg_manager -eq 0 ]]; then
                    echo "### Step $step: Uninstall via Package Manager"
                    echo ""
                    has_pkg_manager=1
                fi
                echo "**npm:**"
                echo ""
                echo '```bash'
                echo "# Uninstall npm global package: $pkg"
                echo "npm uninstall -g \"$pkg\""
                echo '```'
                echo ""
            fi
        done
        
        # yarn
        for pkg in "${YARN_PACKAGES[@]:-}"; do
            if [[ "$pkg" =~ $clean_name ]]; then
                if [[ $has_pkg_manager -eq 0 ]]; then
                    echo "### Step $step: Uninstall via Package Manager"
                    echo ""
                    has_pkg_manager=1
                fi
                echo "**yarn:**"
                echo ""
                echo '```bash'
                echo "# Uninstall yarn global package: $pkg"
                echo "yarn global remove \"$pkg\""
                echo '```'
                echo ""
            fi
        done
        
        # pnpm
        for pkg in "${PNPM_PACKAGES[@]:-}"; do
            if [[ "$pkg" =~ $clean_name ]]; then
                if [[ $has_pkg_manager -eq 0 ]]; then
                    echo "### Step $step: Uninstall via Package Manager"
                    echo ""
                    has_pkg_manager=1
                fi
                echo "**pnpm:**"
                echo ""
                echo '```bash'
                echo "# Uninstall pnpm global package: $pkg"
                echo "pnpm uninstall -g \"$pkg\""
                echo '```'
                echo ""
            fi
        done
        
        # pip
        for pkg in "${PIP_PACKAGES[@]:-}"; do
            if [[ "$pkg" =~ $clean_name ]]; then
                if [[ $has_pkg_manager -eq 0 ]]; then
                    echo "### Step $step: Uninstall via Package Manager"
                    echo ""
                    has_pkg_manager=1
                fi
                echo "**pip:**"
                echo ""
                echo '```bash'
                echo "# Uninstall pip package: $pkg"
                echo "pip uninstall \"$pkg\""
                echo '```'
                echo ""
            fi
        done
        
        # pipx
        for pkg in "${PIPX_PACKAGES[@]:-}"; do
            if [[ "$pkg" =~ $clean_name ]]; then
                if [[ $has_pkg_manager -eq 0 ]]; then
                    echo "### Step $step: Uninstall via Package Manager"
                    echo ""
                    has_pkg_manager=1
                fi
                echo "**pipx:**"
                echo ""
                echo '```bash'
                echo "# Uninstall pipx package: $pkg"
                echo "pipx uninstall \"$pkg\""
                echo '```'
                echo ""
            fi
        done
        
        if [[ $has_pkg_manager -eq 1 ]]; then
            ((step++))
        fi
        
        # Step: Remove app bundle
        if [[ -n "$app_path" ]]; then
            echo "### Step $step: Remove Application Bundle"
            echo ""
            echo "**Purpose:** Delete the main application"
            echo ""
            echo "**Location:** \`$app_path\`"
            echo ""
            echo '```bash'
            echo "# ⚠️ WARNING: This permanently deletes the application"
            echo "rm -rf \"$app_path\""
            echo '```'
            echo ""
            echo "**Safer alternative (move to Trash):**"
            echo ""
            echo '```bash'
            echo "# Reveal in Finder, then drag to Trash manually"
            echo "open -R \"$app_path\""
            echo '```'
            echo ""
            ((step++))
        fi
        
        # Step: Remove user library files
        if [[ ${#library_files[@]} -gt 0 ]]; then
            echo "### Step $step: Remove User Data and Caches"
            echo ""
            echo "**Purpose:** Clean up app-related user data, preferences, and caches"
            echo ""
            echo "**Found ${#library_files[@]} file(s)/folder(s):**"
            echo ""
            for file in "${library_files[@]}"; do
                echo "- \`$file\`"
            done
            echo ""
            echo '```bash'
            echo "# ⚠️ WARNING: These commands permanently delete user data"
            echo "# Review each path carefully before executing"
            echo ""
            for file in "${library_files[@]}"; do
                echo "rm -rf \"$file\""
            done
            echo '```'
            echo ""
            echo "**Safer alternative (review in Finder first):**"
            echo ""
            echo '```bash'
            echo "# Open each location in Finder for manual review"
            for file in "${library_files[@]}"; do
                echo "open -R \"$file\""
            done
            echo '```'
            echo ""
            ((step++))
        fi
        
        # Step: Remove LaunchAgents
        if [[ ${#launch_agents[@]} -gt 0 ]]; then
            echo "### Step $step: Remove LaunchAgent Files"
            echo ""
            echo "**Purpose:** Delete LaunchAgent configuration files"
            echo ""
            for agent in "${launch_agents[@]}"; do
                echo '```bash'
                echo "# Remove LaunchAgent: $(basename "$agent")"
                echo "rm \"$agent\""
                echo '```'
                echo ""
            done
            ((step++))
        fi
        
        # Final verification step
        echo "### Step $step: Verify Removal"
        echo ""
        echo "**Purpose:** Confirm all components have been removed"
        echo ""
        echo '```bash'
        echo "# Check if app bundle still exists"
        echo "ls \"$app_path\" 2>/dev/null && echo \"App still exists\" || echo \"App removed\""
        echo ""
        echo "# Search for remaining files in Library"
        echo "find ~/Library -iname \"*${clean_name}*\" 2>/dev/null"
        echo ""
        echo "# Check for running processes"
        echo "ps aux | grep -i \"$clean_name\" | grep -v grep"
        echo '```'
        echo ""
        
        echo "---"
        echo ""
        echo "## 📝 Summary"
        echo ""
        echo "- **App:** $app_name"
        if [[ -n "$bundle_id" ]]; then
            echo "- **Bundle ID:** $bundle_id"
        fi
        if [[ -n "$uninstaller" ]]; then
            echo "- **Native Uninstaller:** ✅ Found (RECOMMENDED)"
        else
            echo "- **Native Uninstaller:** ❌ Not found"
        fi
        echo "- **Library Files:** ${#library_files[@]} item(s)"
        echo "- **LaunchAgents:** ${#launch_agents[@]} item(s)"
        echo "- **Running Processes:** ${#processes[@]} process(es)"
        echo ""
        echo "**Remember:**"
        echo "1. Always backup important data before removal"
        echo "2. Use native uninstallers when available"
        echo "3. Review each command before executing"
        echo "4. Consider using Finder to manually review files before deletion"
        echo ""
        echo "---"
        echo ""
        echo "*Report generated by App Removal Analyzer v1.0.0*"
        
    } > "$output_file"
}

#==============================================================================
# Disambiguation
#==============================================================================

disambiguate_matches() {
    local total_matches=0
    local -a all_matches=()
    local -a match_types=()
    local -a match_details=()
    
    # Collect all matches
    for i in "${!GUI_APPS[@]}"; do
        all_matches+=("$(basename "${GUI_APPS[$i]}")")
        match_types+=("GUI")
        match_details+=("${GUI_APPS[$i]}")
        ((total_matches++))
    done
    
    for cask in "${BREW_CASKS[@]:-}"; do
        [[ -z "$cask" ]] && continue
        all_matches+=("$cask")
        match_types+=("Homebrew Cask")
        match_details+=("$cask")
        ((total_matches++))
    done
    
    for formula in "${BREW_FORMULAE[@]:-}"; do
        [[ -z "$formula" ]] && continue
        all_matches+=("$formula")
        match_types+=("Homebrew Formula")
        match_details+=("$formula")
        ((total_matches++))
    done
    
    for i in "${!MAS_APPS[@]}"; do
        all_matches+=("${MAS_APPS[$i]}")
        match_types+=("Mac App Store")
        match_details+=("${MAS_APP_IDS[$i]}")
        ((total_matches++))
    done
    
    for pkg in "${NPM_PACKAGES[@]:-}"; do
        [[ -z "$pkg" ]] && continue
        all_matches+=("$pkg")
        match_types+=("npm")
        match_details+=("$pkg")
        ((total_matches++))
    done
    
    for pkg in "${YARN_PACKAGES[@]:-}"; do
        [[ -z "$pkg" ]] && continue
        all_matches+=("$pkg")
        match_types+=("yarn")
        match_details+=("$pkg")
        ((total_matches++))
    done
    
    for pkg in "${PNPM_PACKAGES[@]:-}"; do
        [[ -z "$pkg" ]] && continue
        all_matches+=("$pkg")
        match_types+=("pnpm")
        match_details+=("$pkg")
        ((total_matches++))
    done
    
    for pkg in "${PIP_PACKAGES[@]:-}"; do
        [[ -z "$pkg" ]] && continue
        all_matches+=("$pkg")
        match_types+=("pip")
        match_details+=("$pkg")
        ((total_matches++))
    done
    
    for pkg in "${PIPX_PACKAGES[@]:-}"; do
        [[ -z "$pkg" ]] && continue
        all_matches+=("$pkg")
        match_types+=("pipx")
        match_details+=("$pkg")
        ((total_matches++))
    done
    
    if [[ $total_matches -eq 0 ]]; then
        return 1
    fi
    
    if [[ $total_matches -eq 1 ]]; then
        echo "0"
        return 0
    fi
    
    # Multiple matches - ask user to choose
    echo ""
    echo -e "${BOLD}${YELLOW}Multiple matches found. Please select which app(s) to analyze:${RESET}"
    echo ""
    
    for i in "${!all_matches[@]}"; do
        echo -e "${CYAN}$((i+1)).${RESET} ${all_matches[$i]} ${BOLD}(${match_types[$i]})${RESET}"
    done
    
    echo ""
    echo -e "${CYAN}A.${RESET} Analyze all"
    echo -e "${CYAN}0.${RESET} Cancel"
    echo ""
    
    local selection
    read -p "Enter your choice (number, 'A' for all, or '0' to cancel): " selection
    
    if [[ "$selection" == "0" ]]; then
        return 1
    elif [[ "$selection" =~ ^[Aa]$ ]]; then
        # Return all indices
        for i in "${!all_matches[@]}"; do
            echo "$i"
        done
        return 0
    elif [[ "$selection" =~ ^[0-9]+$ ]] && [[ $selection -ge 1 ]] && [[ $selection -le $total_matches ]]; then
        echo "$((selection-1))"
        return 0
    else
        log_error "Invalid selection"
        return 1
    fi
}

#==============================================================================
# Main Execution
#==============================================================================

main() {
    # Check for help flag
    if [[ "${1:-}" == "--help" ]] || [[ "${1:-}" == "-h" ]]; then
        show_help
    fi
    
    print_header
    print_disclaimer
    
    # Create output directory
    mkdir -p "$OUTPUT_DIR"
    
    # Get app name from user
    echo -e "${BOLD}Enter the name of the app you want to analyze:${RESET}"
    read -p "> " app_name_input
    
    # Trim whitespace
    app_name_input=$(echo "$app_name_input" | xargs)
    
    if [[ -z "$app_name_input" ]]; then
        log_error "App name cannot be empty"
        exit 1
    fi
    
    echo ""
    log_info "Searching for: $app_name_input"
    echo ""
    
    # Perform searches
    search_gui_apps "$app_name_input"
    search_homebrew "$app_name_input"
    search_mas "$app_name_input"
    search_npm "$app_name_input"
    search_yarn "$app_name_input"
    search_pnpm "$app_name_input"
    search_pip "$app_name_input"
    search_pipx "$app_name_input"
    
    echo ""
    
    # Disambiguate if multiple matches
    local selected_indices=()
    while IFS= read -r idx; do
        selected_indices+=("$idx")
    done < <(disambiguate_matches)
    
    if [[ ${#selected_indices[@]} -eq 0 ]]; then
        log_error "No apps found or selection cancelled"
        exit 1
    fi
    
    # Generate removal plans for selected apps
    for idx in "${selected_indices[@]}"; do
        # Determine which app this index corresponds to
        local current_idx=0
        local found=0
        
        # Check GUI apps
        for i in "${!GUI_APPS[@]}"; do
            if [[ $current_idx -eq $idx ]]; then
                local app_path="${GUI_APPS[$i]}"
                local app_name=$(basename "$app_path")
                local bundle_id="${GUI_APP_BUNDLE_IDS[$i]}"
                local timestamp=$(date '+%Y%m%d-%H%M%S')
                local output_file="$OUTPUT_DIR/${app_name%.app}-$timestamp.md"
                
                echo ""
                log_info "Generating removal plan for: $app_name"
                
                generate_removal_plan "$app_name" "$app_path" "$bundle_id" "$output_file"
                
                log_success "Report saved to: $output_file"
                echo ""
                
                # Display the report
                cat "$output_file"
                
                found=1
                break
            fi
            ((current_idx++))
        done
        
        if [[ $found -eq 1 ]]; then
            continue
        fi
        
        # If not a GUI app, create a simplified report
        # (This handles package manager-only installations)
        log_warning "Selected item is not a GUI application - limited analysis available"
    done
    
    echo ""
    echo -e "${BOLD}${GREEN}✓ Analysis complete!${RESET}"
    echo ""
    echo -e "Reports saved to: ${CYAN}$OUTPUT_DIR${RESET}"
    echo ""
}

# Run main function
main "$@"
