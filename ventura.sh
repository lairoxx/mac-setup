#!/bin/bash
# Ultimate macOS Ventura ARM Setup & Optimization
# Fully Automated Interactive Script
#
# Usage: ./ventura.sh [--dry-run]
# Options:
#   --dry-run  Show what would be done without making changes

set -euo pipefail  # Exit on error, undefined vars, pipe failures

# Global variables
DRY_RUN=false

# Parse command line arguments
for arg in "$@"; do
    case $arg in
        --dry-run)
            DRY_RUN=true
            echo "🔍 DRY RUN MODE - No changes will be made"
            ;;
        -h|--help)
            echo "Usage: $0 [--dry-run]"
            echo "  --dry-run  Show what would be done without making changes"
            exit 0
            ;;
    esac
done

echo "🚀 Starting Ultimate macOS Setup & Optimization..."

# Helper functions
log_info() {
    echo "ℹ️  $1"
}

log_success() {
    echo "✅ $1"
}

log_error() {
    echo "❌ $1" >&2
}

log_warning() {
    echo "⚠️  $1"
}

# Execute command with dry run support
execute() {
    if [[ $DRY_RUN == true ]]; then
        echo "[DRY RUN] Would execute: $*"
    else
        log_info "Executing: $1"
        "$@"
    fi
}

# Check if command exists
command_exists() {
    command -v "$1" &>/dev/null
}

# Check if app is already installed
app_installed() {
    [[ -d "/Applications/$1.app" ]]
}

# Batch install brew packages
batch_brew_install() {
    local packages=("$@")
    if [[ ${#packages[@]} -eq 0 ]]; then
        return 0
    fi
    
    log_info "Installing ${#packages[@]} packages with brew..."
    if [[ $DRY_RUN == true ]]; then
        echo "[DRY RUN] Would install: ${packages[*]}"
    else
        brew install "${packages[@]}"
    fi
}

# Batch install brew cask packages
batch_brew_cask_install() {
    local packages=("$@")
    if [[ ${#packages[@]} -eq 0 ]]; then
        return 0
    fi
    
    log_info "Installing ${#packages[@]} cask packages with brew..."
    if [[ $DRY_RUN == true ]]; then
        echo "[DRY RUN] Would install casks: ${packages[*]}"
    else
        brew install --cask "${packages[@]}"
    fi
}

#--------------------------------#
# 1. Homebrew + Git
#--------------------------------#
if ! command_exists brew; then
    log_info "Installing Homebrew..."
    if [[ $DRY_RUN == false ]]; then
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
        echo "eval \"\$(/opt/homebrew/bin/brew shellenv)\"" >> ~/.zprofile
        eval "$(/opt/homebrew/bin/brew shellenv)"
    else
        echo "[DRY RUN] Would install Homebrew and configure shell environment"
    fi
else
    log_success "Homebrew already installed"
fi

# Install git if not present
if ! command_exists git; then
    execute brew install git
else
    log_success "Git already installed"
fi

#--------------------------------#
# 2. Dev Stack
#--------------------------------#
dev_packages=(node pnpm bun go rust fastfetch)
log_info "Installing development stack..."
batch_brew_install "${dev_packages[@]}"

#--------------------------------#
# 3. Interactive browser choice
#--------------------------------#
install_browser=""
echo "Choose browser to install (press Enter for None):"
select browser in "Orion" "Chrome" "Firefox" "None"; do
    case $browser in
        Orion) 
            if app_installed "Orion RC"; then
                log_warning "Orion already installed, skipping"
                install_browser=""
            else
                install_browser="orion"
            fi
            break ;;
        Chrome) 
            if app_installed "Google Chrome"; then
                log_warning "Chrome already installed, skipping"
                install_browser=""
            else
                install_browser="google-chrome"
            fi
            break ;;
        Firefox) 
            if app_installed "Firefox"; then
                log_warning "Firefox already installed, skipping"
                install_browser=""
            else
                install_browser="firefox"
            fi
            break ;;
        None|"") install_browser=""; break ;;
    esac
done

#--------------------------------#
# 4. Interactive music choice
#--------------------------------#
install_music=""
echo "Choose music app to install (press Enter for None):"
select music in "Tidal" "Spotify" "None"; do
    case $music in
        Tidal) 
            if app_installed "Tidal"; then
                log_warning "Tidal already installed, skipping"
                install_music=""
            else
                install_music="tidal"
            fi
            break ;;
        Spotify) 
            if app_installed "Spotify"; then
                log_warning "Spotify already installed, skipping"
                install_music=""
            else
                install_music="spotify"
            fi
            break ;;
        None|"") install_music=""; break ;;
    esac
done

#--------------------------------#
# 5. Select additional apps
#--------------------------------#
# Note: Removed Ice, Orion, NordVPN from this list as they have special installation methods
apps_list=("Zed" "SABnzbd" "VLC" "Raycast" "Shottr" "Rectangle" "HiddenBar" "KeepingYouAwake" "AppCleaner" "Stats" "IINA" "Itsycal")
echo "Select additional apps to install (comma-separated numbers, press Enter to skip):"
for i in "${!apps_list[@]}"; do
    if app_installed "${apps_list[$i]}"; then
        echo "$i) ${apps_list[$i]} (already installed)"
    else
        echo "$i) ${apps_list[$i]}"
    fi
done
read -r -p "Selection: " selection
IFS=',' read -ra selected_indices <<< "$selection"

#--------------------------------#
# 6. Homebrew search & install
#--------------------------------#
read -r -p "Do you want to search and install any Homebrew app? (y/n): " search_choice
if [[ $search_choice == "y" ]]; then
    read -r -p "Enter search term: " search_term
    if [[ -n $search_term ]]; then
        log_info "Searching Homebrew for '$search_term'..."
        if [[ $DRY_RUN == false ]]; then
            brew search "$search_term"
        else
            echo "[DRY RUN] Would search for: $search_term"
        fi
        read -r -p "Enter app name to install (or leave empty to skip): " brew_app
        if [[ -n $brew_app ]]; then
            if [[ $DRY_RUN == false ]]; then
                brew install --cask "$brew_app" || brew install "$brew_app"
            else
                echo "[DRY RUN] Would install: $brew_app"
            fi
        fi
    fi
fi

#--------------------------------#
# 7. Install apps
#--------------------------------#
# Collect all apps to install in arrays for batch processing
cask_apps=()

# Add browser if selected
if [[ -n $install_browser ]]; then
    cask_apps+=("$install_browser")
fi

# Add music app if selected
if [[ -n $install_music ]]; then
    cask_apps+=("$install_music")
fi

# Add selected additional apps (filter out already installed ones)
for index in "${selected_indices[@]}"; do
    if [[ $index =~ ^[0-9]+$ ]] && [[ $index -lt ${#apps_list[@]} ]]; then
        app_name="${apps_list[$index]}"
        if ! app_installed "$app_name"; then
            cask_apps+=("$app_name")
        else
            log_warning "$app_name already installed, skipping"
        fi
    fi
done

# Install all cask apps in batch
if [[ ${#cask_apps[@]} -gt 0 ]]; then
    log_info "Installing ${#cask_apps[@]} applications..."
    batch_brew_cask_install "${cask_apps[@]}"
else
    log_info "No new applications to install"
fi

#--------------------------------#
# 8. Manual DMG installs
#--------------------------------#
install_dmg() {
    local url="$1"
    local name="$2"
    local app_name="${3:-$name}"
    local dmg="/tmp/$name.dmg"
    
    if app_installed "$app_name"; then
        log_warning "$app_name already installed, skipping DMG installation"
        return 0
    fi
    
    if [[ $DRY_RUN == true ]]; then
        echo "[DRY RUN] Would install $app_name from $url"
        return 0
    fi
    
    log_info "Installing $app_name from DMG..."
    
    # Download with error handling
    if ! curl -L -o "$dmg" "$url"; then
        log_error "Failed to download $name from $url"
        return 1
    fi
    
    # Mount DMG
    if ! hdiutil attach "$dmg" -nobrowse -quiet; then
        log_error "Failed to mount $dmg"
        rm -f "$dmg"
        return 1
    fi
    
    # Copy application
    if ! cp -r "/Volumes/$name/$app_name.app" "/Applications/"; then
        log_error "Failed to copy $app_name to Applications"
        hdiutil detach "/Volumes/$name" -quiet 2>/dev/null || true
        rm -f "$dmg"
        return 1
    fi
    
    # Cleanup
    hdiutil detach "/Volumes/$name" -quiet 2>/dev/null || true
    rm -f "$dmg"
    
    log_success "Successfully installed $app_name"
}

# Install special apps via DMG (these aren't available via brew cask or have issues)
log_info "Installing apps via DMG..."
install_dmg "https://github.com/jordanbaird/Ice/releases/latest/download/Ice.dmg" "Ice"
install_dmg "https://browser.kagi.com/download/Orion.dmg" "Orion" "Orion RC"
install_dmg "https://downloads.nordcdn.com/apps/macos/generic/NordVPN.dmg" "NordVPN"

#--------------------------------#
# 9. Alacritty + Config + Font
#--------------------------------#
setup_alacritty() {
    if ! app_installed "Alacritty"; then
        execute brew install --cask alacritty
    else
        log_success "Alacritty already installed"
    fi
    
    local config_dir="$HOME/.config/alacritty"
    local config_file="$config_dir/alacritty.yml"
    
    if [[ $DRY_RUN == true ]]; then
        echo "[DRY RUN] Would setup Alacritty configuration and font"
        return 0
    fi
    
    # Create config directory
    mkdir -p "$config_dir"
    
    # Backup existing config if it exists
    if [[ -f "$config_file" ]]; then
        log_warning "Backing up existing Alacritty config to ${config_file}.backup"
        cp "$config_file" "${config_file}.backup"
    fi
    
    # Download new config
    log_info "Installing Alacritty configuration..."
    if curl -fsSL https://raw.githubusercontent.com/catppuccin/alacritty/refs/heads/main/catppuccin-mocha.toml -o "$config_file"; then
        log_success "Alacritty configuration installed"
    else
        log_error "Failed to download Alacritty configuration"
    fi
}

setup_font() {
    local font_dir="$HOME/Library/Fonts"
    local font_file="$font_dir/MonaspaceRadonNF-Bold.otf"
    
    if [[ $DRY_RUN == true ]]; then
        echo "[DRY RUN] Would install MonaspaceRadonNF-Bold font"
        return 0
    fi
    
    if [[ -f "$font_file" ]]; then
        log_success "MonaspaceRadonNF-Bold font already installed"
        return 0
    fi
    
    mkdir -p "$font_dir"
    log_info "Installing MonaspaceRadonNF-Bold font..."
    
    if curl -fsSL https://lairox.sirv.com/MonaspaceRadonNF-Bold.otf -o "$font_file"; then
        log_success "Font installed successfully"
    else
        log_error "Failed to download font"
    fi
}

setup_alacritty
setup_font

#--------------------------------#
# 10. Zed config
#--------------------------------#
setup_zed_config() {
    local zed_config_dir="$HOME/Library/Application Support/Zed"
    local zed_settings="$zed_config_dir/settings.json"
    
    if [[ $DRY_RUN == true ]]; then
        echo "[DRY RUN] Would setup Zed configuration"
        return 0
    fi
    
    # Create config directory
    mkdir -p "$zed_config_dir"
    
    # Backup existing settings if they exist
    if [[ -f "$zed_settings" ]]; then
        log_warning "Backing up existing Zed settings to ${zed_settings}.backup"
        cp "$zed_settings" "${zed_settings}.backup"
    fi
    
    log_info "Installing Zed configuration..."
    cat > "$zed_settings" <<'EOF'
{
  "agent": {
    "default_profile": "agent",
    "profiles": {
      "agent": {
        "name": "Agent",
        "tools": {
          "thinking": true,
          "terminal": true,
          "project_notifications": true,
          "read_file": true,
          "open": true,
          "now": true,
          "move_path": true,
          "list_directory": true,
          "grep": true,
          "find_path": true,
          "edit_file": true,
          "fetch": true,
          "diagnostics": true,
          "delete_path": true,
          "create_directory": true,
          "copy_path": true
        },
        "enable_all_context_servers": false,
        "context_servers": {}
      }
    },
    "default_model": {
      "provider": "zed.dev",
      "model": "claude-sonnet-4-thinking"
    },
    "use_modifier_to_send": true,
    "play_sound_when_agent_done": true,
    "always_allow_tool_actions": true
  },
  "inlay_hints": { "enabled": true, "show_value_hints": true, "show_type_hints": true },
  "buffer_font_features": { "calt": 1 },
  "ui_font_family": ".SystemUIFont",
  "minimap": { "show": "auto" },
  "base_keymap": "VSCode",
  "icon_theme": { "mode": "system", "light": "Zed (Default)", "dark": "Zed (Default)" },
  "ui_font_size": 16,
  "buffer_font_size": 15,
  "theme": { "mode": "system", "light": "Gruvbox Light", "dark": "Gruvbox Dark" }
}
EOF
    log_success "Zed configuration installed"
}

setup_zed_config

#--------------------------------#
# 11. Fastfetch config
#--------------------------------#
setup_fastfetch() {
    local fastfetch_config_dir="$HOME/.config/fastfetch"
    local fastfetch_config="$fastfetch_config_dir/config.json"
    
    if [[ $DRY_RUN == true ]]; then
        echo "[DRY RUN] Would setup fastfetch configuration"
        return 0
    fi
    
    if [[ -f "$fastfetch_config" ]]; then
        log_success "Fastfetch config already exists"
        return 0
    fi
    
    log_info "Generating fastfetch configuration..."
    mkdir -p "$fastfetch_config_dir"
    
    if command_exists fastfetch; then
        fastfetch --gen-config > "$fastfetch_config"
        log_success "Fastfetch configuration generated"
    else
        log_warning "Fastfetch not available, skipping config generation"
    fi
}

setup_fastfetch

#--------------------------------#
# 12. Dock, Dark Mode, Menubar, HiddenBar
#--------------------------------#
setup_macos_preferences() {
    if [[ $DRY_RUN == true ]]; then
        echo "[DRY RUN] Would configure macOS preferences (dock, dark mode, wallpaper)"
        return 0
    fi
    
    log_info "Configuring macOS preferences..."
    
    # Clear dock
    defaults write com.apple.dock persistent-apps -array
    defaults write com.apple.dock persistent-others -array
    
    # Enable dark mode
    osascript -e 'tell application "System Events" to tell appearance preferences to set dark mode to true' 2>/dev/null || log_warning "Could not set dark mode"
    
    # Download and set wallpaper
    local wallpaper_path="$HOME/Downloads/wallpaper.jpg"
    if curl -o "$wallpaper_path" https://lawrencemillard.uk/downloads/wallpaper.jpg 2>/dev/null; then
        osascript -e "tell application \"System Events\" to set picture of every desktop to (POSIX file \"$wallpaper_path\" as alias)" 2>/dev/null || log_warning "Could not set wallpaper"
        log_success "Wallpaper downloaded and set"
    else
        log_warning "Could not download wallpaper"
    fi
    
    # Enable menu bar transparency
    defaults write -g AppleEnableMenuBarTransparency -bool true 2>/dev/null || log_warning "Could not set menu bar transparency"
    
    # Restart UI services
    killall Dock 2>/dev/null || true
    killall SystemUIServer 2>/dev/null || true
    
    log_success "macOS preferences configured"
}

setup_macos_preferences

#--------------------------------#
# 13. Startup apps: Raycast, NordVPN, Ice, Shottr
#--------------------------------#
setup_login_items() {
    if [[ $DRY_RUN == true ]]; then
        echo "[DRY RUN] Would configure login items for startup apps"
        return 0
    fi
    
    log_info "Configuring startup applications..."
    
    # Clear existing login items
    osascript -e 'tell application "System Events" to delete every login item' 2>/dev/null || log_warning "Could not clear existing login items"
    
    # Add startup apps
    local startup_apps=("Raycast" "NordVPN" "Ice" "Shottr")
    for app in "${startup_apps[@]}"; do
        if app_installed "$app"; then
            local hidden=false
            [[ $app == "Ice" ]] && hidden=true
            
            if osascript -e "tell application \"System Events\" to make login item at end with properties {path:\"/Applications/$app.app\", hidden:$hidden}" 2>/dev/null; then
                log_success "Added $app to login items"
            else
                log_warning "Could not add $app to login items"
            fi
        else
            log_warning "$app not installed, skipping login item"
        fi
    done
}

setup_login_items

#--------------------------------#
# 14. Replace Spotlight with Raycast
#--------------------------------#
setup_raycast_spotlight() {
    if [[ $DRY_RUN == true ]]; then
        echo "[DRY RUN] Would disable Spotlight shortcuts for Raycast"
        return 0
    fi
    
    if app_installed "Raycast"; then
        log_info "Disabling Spotlight shortcuts for Raycast..."
        defaults write com.apple.symbolichotkeys AppleSymbolicHotKeys -dict-add 64 "{enabled = 0;}" 2>/dev/null || log_warning "Could not disable Spotlight shortcut 1"
        defaults write com.apple.symbolichotkeys AppleSymbolicHotKeys -dict-add 65 "{enabled = 0;}" 2>/dev/null || log_warning "Could not disable Spotlight shortcut 2"
        log_success "Spotlight shortcuts disabled for Raycast"
    else
        log_warning "Raycast not installed, skipping Spotlight shortcut configuration"
    fi
}

setup_raycast_spotlight

#--------------------------------#
# 15. Performance Tweaks
#--------------------------------#
apply_performance_tweaks() {
    if [[ $DRY_RUN == true ]]; then
        echo "[DRY RUN] Would apply performance tweaks (disable animations, optimize UI)"
        return 0
    fi
    
    log_info "Applying performance tweaks..."
    
    # Disable window animations
    defaults write NSGlobalDomain NSAutomaticWindowAnimationsEnabled -bool false 2>/dev/null || log_warning "Could not disable window animations"
    
    # Speed up dock animation
    defaults write com.apple.dock expose-animation-duration -float 0.1 2>/dev/null || log_warning "Could not set dock animation duration"
    
    # Disable finder animations
    defaults write com.apple.finder DisableAllAnimations -bool true 2>/dev/null || log_warning "Could not disable finder animations"
    
    # Restart affected services
    killall Dock 2>/dev/null || true
    killall Finder 2>/dev/null || true
    
    log_success "Performance tweaks applied"
}

apply_performance_tweaks

log_success "Ultimate setup & optimization complete! Reboot recommended."

# Show summary
if [[ $DRY_RUN == false ]]; then
    echo ""
    log_info "Setup Summary:"
    echo "  🍺 Homebrew and Git configured"
    echo "  🛠  Development stack installed"
    echo "  📱 Applications installed and configured"
    echo "  ⚙️  macOS preferences optimized"
    echo "  🚀 Startup items configured"
    echo "  ⚡ Performance tweaks applied"
    echo ""
    echo "Next steps:"
    echo "  1. Reboot your system to apply all changes"
    echo "  2. Open Raycast and configure your preferences"
    echo "  3. Sign into your applications"
    echo "  4. Enjoy your optimized macOS setup!"
fi
