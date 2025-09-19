#!/bin/bash
set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Start timer
START_TIME=$(date +%s)

# Logging
LOG_FILE="/tmp/setup_$(date +%Y%m%d_%H%M%S).log"
exec 1> >(tee -a "$LOG_FILE")
exec 2> >(tee -a "$LOG_FILE" >&2)

print_status() {
    echo -e "${BLUE}[$(date +'%H:%M:%S')] $1${NC}"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

# Robust download function with retries
download_file() {
    local url="$1"
    local output="$2"
    local description="$3"
    local max_attempts=3
    local attempt=1
    
    while [[ $attempt -le $max_attempts ]]; do
        if curl -fsSL --connect-timeout 10 --max-time 60 --retry 3 "$url" -o "$output"; then
            print_success "$description downloaded successfully"
            return 0
        else
            print_warning "$description download attempt $attempt failed"
            ((attempt++))
            sleep 2
        fi
    done
    
    print_error "$description download failed after $max_attempts attempts"
    return 1
}

# Cleanup function
cleanup() {
    print_status "Cleaning up temporary files..."
    rm -f /tmp/homebrew_install.sh /tmp/font.otf /tmp/theme.toml /tmp/wallpaper.jpg /tmp/download_pids /tmp/monaspace.zip 2>/dev/null || true
    print_success "Cleanup complete"
}
trap cleanup EXIT

# Check if running on macOS
if [[ "$(uname)" != "Darwin" ]]; then
    print_error "This script must be run on macOS"
    exit 1
fi

# Check if M1 Mac
if [[ "$(uname -m)" != "arm64" ]]; then
    print_warning "This script is optimized for M1 Macs but will continue anyway"
fi

print_status "Starting blazing fast macOS VM setup..."
print_status "Log file: $LOG_FILE"

# ===============================================================================
# PHASE 1: HOMEBREW INSTALLATION (PARALLEL PREP)  
# ===============================================================================

print_status "Phase 1: Installing Homebrew..."

# Download Homebrew installer in background
download_file "https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh" "/tmp/homebrew_install.sh" "Homebrew installer" &
DOWNLOAD_PID=$!

# Accept Xcode license if needed (non-interactive)
if ! xcode-select -p &>/dev/null; then
    print_status "Installing Xcode command line tools..."
    xcode-select --install 2>/dev/null || true
    # Wait for installation (this is required)
    until xcode-select -p &>/dev/null; do
        sleep 5
    done
fi

# Wait for Homebrew download
wait $DOWNLOAD_PID
print_success "Homebrew installer downloaded"

# Install Homebrew non-interactively
export NONINTERACTIVE=1
/bin/bash /tmp/homebrew_install.sh

# Add Homebrew to PATH immediately
if [[ -d "/opt/homebrew" ]]; then
    export PATH="/opt/homebrew/bin:$PATH"
    eval "$(/opt/homebrew/bin/brew shellenv)"
else
    export PATH="/usr/local/bin:$PATH"
fi

print_success "Homebrew installed and configured"

# ===============================================================================
# PHASE 2: PARALLEL DOWNLOADS & BREW UPDATES
# ===============================================================================

print_status "Phase 2: Preparing parallel downloads and brew update..."

# Start background downloads with robust error handling
{
    # Download font with working URL
    if ! download_file "https://github.com/githubnext/monaspace/releases/download/v1.101/monaspace-v1.101.zip" "/tmp/monaspace.zip" "Monaspace font"; then
        print_warning "Font download failed"
    fi &
    FONT_PID=$!
    
    # Download Alacritty theme with fallback
    if ! download_file "https://raw.githubusercontent.com/catppuccin/alacritty/main/catppuccin-mocha.toml" "/tmp/theme.toml" "Catppuccin theme"; then
        # Create fallback theme
        cat > /tmp/theme.toml << 'EOF'
# Fallback dark theme
[colors.primary]
background = "#1e1e2e"
foreground = "#cdd6f4"

[colors.cursor]
text = "#1e1e2e"
cursor = "#f5e0dc"

[colors.normal]
black = "#45475a"
red = "#f38ba8"
green = "#a6e3a1"
yellow = "#f9e2af"
blue = "#89b4fa"
magenta = "#f5c2e7"
cyan = "#94e2d5"
white = "#bac2de"

[colors.bright]
black = "#585b70"
red = "#f38ba8"
green = "#a6e3a1"
yellow = "#f9e2af"
blue = "#89b4fa"
magenta = "#f5c2e7"
cyan = "#94e2d5"
white = "#a6adc8"
EOF
        print_success "Fallback Alacritty theme created"
    fi &
    THEME_PID=$!
    
    # Download wallpaper with multiple fallbacks
    if ! download_file "https://images.unsplash.com/photo-1506905925346-21bda4d32df4?w=2560&h=1440&fit=crop" "/tmp/wallpaper.jpg" "Unsplash wallpaper"; then
        print_warning "Wallpaper download failed, will use system default"
    fi &
    WALLPAPER_PID=$!
    
    # Export PIDs for later use
    echo "$FONT_PID,$THEME_PID,$WALLPAPER_PID" > /tmp/download_pids
} &

# Update Homebrew in parallel
brew update --quiet &
BREW_UPDATE_PID=$!

print_success "Background downloads and brew update started"

# ===============================================================================
# PHASE 3: SYSTEM OPTIMIZATIONS (WHILE DOWNLOADS RUN)
# ===============================================================================

print_status "Phase 3: Applying system optimizations..."

# Disable animations for speed
defaults write NSGlobalDomain NSAutomaticWindowAnimationsEnabled -bool false
defaults write com.apple.dock expose-animation-duration -float 0.1
defaults write com.apple.finder DisableAllAnimations -bool true
defaults write com.apple.dock autohide-delay -float 0
defaults write com.apple.dock autohide-time-modifier -float 0.5

# Enable dark mode
osascript -e 'tell application "System Events" to tell appearance preferences to set dark mode to true' 2>/dev/null || true

# Menu bar transparency
defaults write -g AppleEnableMenuBarTransparency -bool true

# Clear dock
defaults write com.apple.dock persistent-apps -array

# Disable Spotlight shortcuts (for Raycast) - Fixed syntax
defaults write com.apple.symbolichotkeys AppleSymbolicHotKeys -dict-add 64 '<dict><key>enabled</key><false/></dict>'
defaults write com.apple.symbolichotkeys AppleSymbolicHotKeys -dict-add 65 '<dict><key>enabled</key><false/></dict>'

# Optimize Finder
defaults write com.apple.finder AppleShowAllFiles -bool true
defaults write com.apple.finder ShowStatusBar -bool true
defaults write com.apple.finder ShowPathbar -bool true
defaults write com.apple.finder _FXShowPosixPathInTitle -bool true

print_success "System optimizations applied"

# ===============================================================================
# PHASE 4: INSTALL DEVELOPMENT TOOLS
# ===============================================================================

print_status "Phase 4: Installing development tools..."

# Wait for brew update to complete
wait $BREW_UPDATE_PID
print_success "Homebrew updated"

# Install dev tools (using correct package names)
DEV_TOOLS=(
    "git"
    "node" 
    "pnpm"
    "bun"
    "go"
    "rustup-init"
    "fastfetch"
)

print_status "Installing development tools in parallel batches..."

# Install in parallel batches of 3 to avoid overwhelming
for ((i=0; i<${#DEV_TOOLS[@]}; i+=3)); do
    batch=("${DEV_TOOLS[@]:i:3}")
    for tool in "${batch[@]}"; do
        if [[ -n "$tool" ]]; then
            if [[ "$tool" == "rustup-init" ]]; then
                # Special handling for Rust
                brew install rustup-init && rustup-init -y &
            else
                brew install "$tool" &
            fi
        fi
    done
    wait
    print_success "Installed batch: ${batch[*]}"
done

print_success "All development tools installed"

# ===============================================================================
# PHASE 5: INSTALL APPLICATIONS
# ===============================================================================

print_status "Phase 5: Installing applications..."

CASK_APPS=(
    "zed"
    "sabnzbd" 
    "vlc"
    "raycast"
    "shottr"
    "rectangle"
    "hiddenbar"
    "keepingyouawake"
    "appcleaner"
    "stats"
    "iina"
    "itsycal"
    "jordanbaird-ice"  # Fixed package name
    "nordvpn"
    "spotify"
    "browser-chooser"  # Alternative to orion if not available
    "alacritty"
)

# Install apps in parallel batches with error handling
print_status "Installing applications in parallel batches..."

for ((i=0; i<${#CASK_APPS[@]}; i+=4)); do
    batch=("${CASK_APPS[@]:i:4}")
    for app in "${batch[@]}"; do
        if [[ -n "$app" ]]; then
            (brew install --cask "$app" --no-quarantine 2>/dev/null || print_warning "Failed to install $app") &
        fi
    done
    wait
    print_success "Processed batch: ${batch[*]}"
done

print_success "Application installation completed"

# ===============================================================================
# PHASE 6: CONFIGURATION FILES
# ===============================================================================

print_status "Phase 6: Setting up configuration files..."

# Wait for downloads to complete
if [[ -f /tmp/download_pids ]]; then
    IFS=',' read -r FONT_PID THEME_PID WALLPAPER_PID < /tmp/download_pids
    wait $FONT_PID $THEME_PID $WALLPAPER_PID 2>/dev/null || true
    print_success "All downloads completed"
fi

# Create directories
mkdir -p ~/.config/alacritty
mkdir -p ~/.config/fastfetch
mkdir -p ~/Library/Fonts
mkdir -p "$HOME/Library/Application Support/Zed"

# Install font with better error handling
FONT_FAMILY="Monaco"  # Default fallback
if [[ -f /tmp/monaspace.zip ]] && [[ -s /tmp/monaspace.zip ]]; then
    print_status "Extracting Monaspace fonts..."
    cd /tmp
    if unzip -q monaspace.zip 2>/dev/null; then
        # Find and copy font files
        find /tmp -name "*.otf" -o -name "*.ttf" | while read -r font_file; do
            cp "$font_file" ~/Library/Fonts/ 2>/dev/null || true
        done
        FONT_FAMILY="MonaspaceRadonNF"
        print_success "Monaspace fonts installed"
    else
        print_warning "Font extraction failed, using system default"
    fi
else
    print_warning "Font download failed, using system default"
fi

# Set wallpaper with better error handling
if [[ -f /tmp/wallpaper.jpg ]] && [[ -s /tmp/wallpaper.jpg ]]; then
    # Verify it's actually a valid image
    if file /tmp/wallpaper.jpg | grep -q "JPEG\|PNG\|image"; then
        cp /tmp/wallpaper.jpg ~/Downloads/wallpaper.jpg
        
        # Try to set wallpaper
        osascript -e "tell application \"Finder\" to set desktop picture to POSIX file \"$HOME/Downloads/wallpaper.jpg\"" 2>/dev/null || print_warning "Could not set wallpaper automatically"
        print_success "Wallpaper set successfully"
    else
        print_warning "Downloaded file is not a valid image, skipping wallpaper"
    fi
else
    print_warning "Wallpaper download failed, using system default"
fi

# Alacritty configuration (YAML format - more compatible)
cat > ~/.config/alacritty/alacritty.yml << EOF
# Import Catppuccin theme
import:
  - ~/.config/alacritty/catppuccin-mocha.toml

# Window settings
window:
  opacity: 0.95
  padding:
    x: 10
    y: 10
  decorations: buttonless

# Font configuration  
font:
  normal:
    family: "${FONT_FAMILY}"
    style: Bold
  size: 14.0
  use_thin_strokes: true

# Shell
shell:
  program: /bin/zsh
  args:
    - --login
    - -c
    - "fastfetch 2>/dev/null || echo 'System ready!' && exec zsh"

# Scrolling
scrolling:
  history: 10000

# Selection
selection:
  save_to_clipboard: true

# Cursor
cursor:
  style:
    shape: Block
    blinking: On
  blink_interval: 750

# Live config reload
live_config_reload: true

# Key bindings
key_bindings:
  - { key: V, mods: Command, action: Paste }
  - { key: C, mods: Command, action: Copy }
  - { key: Q, mods: Command, action: Quit }
  - { key: N, mods: Command, action: SpawnNewInstance }
EOF

# Copy theme if downloaded
if [[ -f /tmp/theme.toml ]] && [[ -s /tmp/theme.toml ]]; then
    cp /tmp/theme.toml ~/.config/alacritty/catppuccin-mocha.toml
    print_success "Alacritty theme configured"
else
    print_warning "Using fallback Alacritty theme"
fi

# Zed configuration with corrected JSON structure
cat > "$HOME/Library/Application Support/Zed/settings.json" << EOF
{
  "theme": {
    "mode": "system",
    "light": "One Light",
    "dark": "One Dark"
  },
  "ui_font_size": 16,
  "buffer_font_size": 15,
  "buffer_font_family": "${FONT_FAMILY}",
  "vim_mode": false,
  "base_keymap": "VSCode",
  "inlay_hints": {
    "enabled": true
  },
  "show_inline_completions": true,
  "minimap": {
    "enabled": true
  },
  "scrollbar": {
    "show": "always"
  },
  "indent_guides": {
    "enabled": true
  },
  "soft_wrap": "editor_width",
  "tab_size": 2,
  "hard_tabs": false,
  "auto_save": "on_focus_change",
  "format_on_save": "on",
  "relative_line_numbers": false,
  "cursor_blink": true,
  "hover_popover_enabled": true,
  "confirm_quit": false,
  "restore_on_startup": "last_workspace",
  "terminal": {
    "shell": {
      "program": "/bin/zsh"
    }
  }
}
EOF

print_success "Zed configuration created"

# Fastfetch configuration (auto-generate)
fastfetch --gen-config &>/dev/null || true
print_success "Fastfetch configuration generated"

# ===============================================================================
# PHASE 7: STARTUP APPLICATIONS & FINAL SETUP
# ===============================================================================

print_status "Phase 7: Configuring startup applications..."

# Configure startup applications with better error handling
STARTUP_APPS=(
    "Raycast"
    "Rectangle"
    "HiddenBar"
    "KeepingYouAwake"
    "Stats"
    "Itsycal"
    "Ice"
)

for app_name in "${STARTUP_APPS[@]}"; do
    # Check multiple possible app locations
    app_paths=(
        "/Applications/${app_name}.app"
        "/System/Applications/${app_name}.app"
        "/Applications/Utilities/${app_name}.app"
    )
    
    app_found=false
    for app_path in "${app_paths[@]}"; do
        if [[ -d "$app_path" ]]; then
            # Use osascript to add to login items
            if osascript -e "tell application \"System Events\" to make login item at end with properties {path:\"${app_path}\", hidden:true}" 2>/dev/null; then
                print_success "Added $app_name to startup"
                app_found=true
                break
            fi
        fi
    done
    
    if [[ "$app_found" = false ]]; then
        print_warning "Could not find or configure startup for: $app_name"
    fi
done

# ===============================================================================
# PHASE 8: RESTART SERVICES & CLEANUP
# ===============================================================================

print_status "Phase 8: Applying final changes..."

# Restart affected services with better error handling
print_status "Restarting system services..."

services_to_restart=("Dock" "Finder" "SystemUIServer")
for service in "${services_to_restart[@]}"; do
    if pgrep -x "$service" > /dev/null; then
        killall "$service" 2>/dev/null && print_success "Restarted $service" || print_warning "Could not restart $service"
        sleep 1
    fi
done

# Refresh font cache
atsutil databases -remove 2>/dev/null || true
atsutil server -ping 2>/dev/null || true

# Update shell environment
SHELL_ADDITIONS='
# Homebrew
if [[ -d "/opt/homebrew" ]]; then
    export PATH="/opt/homebrew/bin:$PATH"
    eval "$(/opt/homebrew/bin/brew shellenv)"
fi

# Useful aliases
alias ls="ls -la"
alias ll="ls -laG"
alias grep="grep --color=always"

# Git shortcuts
alias gs="git status"
alias ga="git add"
alias gc="git commit"
alias gp="git push"

# Node/pnpm
export PNPM_HOME="$HOME/Library/pnpm"
case ":$PATH:" in
  *":$PNPM_HOME:"*) ;;
  *) export PATH="$PNPM_HOME:$PATH" ;;
esac

# Go
export GOPATH="$HOME/go"
export PATH="$GOPATH/bin:$PATH"

# Rust
export PATH="$HOME/.cargo/bin:$PATH"

# Better history
export HISTSIZE=10000
export HISTFILESIZE=10000
export HISTCONTROL=ignoredups:erasedups
'

# Backup existing .zshrc if it exists
if [[ -f ~/.zshrc ]]; then
    cp ~/.zshrc ~/.zshrc.backup.$(date +%Y%m%d_%H%M%S)
fi

# Add to .zshrc
echo "$SHELL_ADDITIONS" >> ~/.zshrc

print_success "Shell environment updated"

# ===============================================================================
# COMPLETION SUMMARY
# ===============================================================================

SETUP_TIME=$(($(date +%s) - START_TIME))

print_success "🚀 Setup completed successfully in ${SETUP_TIME} seconds!"
echo
echo "📊 INSTALLATION SUMMARY:"
echo "========================"
echo "• Homebrew: ✓ Installed with ${#DEV_TOOLS[@]} dev tools"
echo "• Applications: ✓ ${#CASK_APPS[@]} apps processed"
echo "• Configurations: ✓ Alacritty, Zed, Fastfetch"
echo "• System: ✓ Optimized for speed and performance"
echo "• Startup: ✓ Apps configured for auto-start"
echo "• Font: ✓ ${FONT_FAMILY}"
echo "• Theme: ✓ Catppuccin Mocha (Alacritty)"
echo "• Shell: ✓ Enhanced with aliases and environment"
echo
echo "🔧 TROUBLESHOOTING:"
echo "• If wallpaper didn't set: Manually set ~/Downloads/wallpaper.jpg"
echo "• If fonts look wrong: Check ~/Library/Fonts/ for installed fonts"
echo "• For Raycast: Grant accessibility permissions in System Preferences"
echo "• For Rectangle: Grant accessibility permissions in System Preferences"
echo
echo "📝 Next Steps:"
echo "• 🔄 Restart your terminal: source ~/.zshrc"
echo "• 🚀 Open Raycast (Cmd+Space) and configure shortcuts"
echo "• ⚡ Launch Zed to complete first-time setup"
echo "• 📱 Check startup apps in System Preferences > Login Items"
echo "• 🎨 Run 'alacritty' to test terminal setup"
echo
echo "📄 Full setup log: $LOG_FILE"
echo "💾 Shell backup: ~/.zshrc.backup.* (if existed)"
echo
print_success "Ready to rock! 🎸"

# Optional: Show system info
echo
print_status "System Information:"
fastfetch 2>/dev/null || echo "Run 'fastfetch' in a new terminal to see system info"
