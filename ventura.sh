#!/bin/bash
set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

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

# Cleanup function
cleanup() {
    print_status "Cleaning up temporary files..."
    rm -f /tmp/homebrew_install.sh /tmp/font.otf /tmp/theme.toml /tmp/wallpaper.jpg
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

# =============================================================================
# PHASE 1: HOMEBREW INSTALLATION (PARALLEL PREP)
# =============================================================================

print_status "Phase 1: Installing Homebrew..."

# Download Homebrew installer in background
curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh -o /tmp/homebrew_install.sh &
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

# =============================================================================
# PHASE 2: PARALLEL DOWNLOADS & BREW UPDATES
# =============================================================================

print_status "Phase 2: Preparing parallel downloads and brew update..."

# Start background downloads
{
    # Download font
    curl -fsSL "https://lairox.sirv.com/MonaspaceRadonNF-Bold.otf" -o /tmp/font.otf &
    FONT_PID=$!
    
    # Download Alacritty theme
    curl -fsSL "https://raw.githubusercontent.com/catppuccin/alacritty/refs/heads/main/catppuccin-mocha.toml" -o /tmp/theme.toml &
    THEME_PID=$!
    
    # Download wallpaper
    curl -fsSL "https://lawrencemillard.uk/downloads/wallpaper.jpg" -o /tmp/wallpaper.jpg &
    WALLPAPER_PID=$!
    
    # Export PIDs for later use
    echo "$FONT_PID,$THEME_PID,$WALLPAPER_PID" > /tmp/download_pids
} &

# Update Homebrew in parallel
brew update --quiet &
BREW_UPDATE_PID=$!

print_success "Background downloads and brew update started"

# =============================================================================
# PHASE 3: SYSTEM OPTIMIZATIONS (WHILE DOWNLOADS RUN)
# =============================================================================

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

# Disable Spotlight shortcuts (for Raycast)
defaults write com.apple.symbolichotkeys AppleSymbolicHotKeys -dict-add 64 "{enabled = 0;}"
defaults write com.apple.symbolichotkeys AppleSymbolicHotKeys -dict-add 65 "{enabled = 0;}"

# Optimize Finder
defaults write com.apple.finder AppleShowAllFiles -bool true
defaults write com.apple.finder ShowStatusBar -bool true
defaults write com.apple.finder ShowPathbar -bool true
defaults write com.apple.finder _FXShowPosixPathInTitle -bool true

print_success "System optimizations applied"

# =============================================================================
# PHASE 4: INSTALL DEVELOPMENT TOOLS
# =============================================================================

print_status "Phase 4: Installing development tools..."

# Wait for brew update to complete
wait $BREW_UPDATE_PID
print_success "Homebrew updated"

# Install dev tools (parallel where possible)
DEV_TOOLS=(
    "git"
    "node" 
    "pnpm"
    "bun"
    "go"
    "rust"
    "fastfetch"
)

print_status "Installing development tools in parallel batches..."

# Install in parallel batches of 3 to avoid overwhelming
for ((i=0; i<${#DEV_TOOLS[@]}; i+=3)); do
    batch=("${DEV_TOOLS[@]:i:3}")
    for tool in "${batch[@]}"; do
        if [[ -n "$tool" ]]; then
            brew install "$tool" &
        fi
    done
    wait
    print_success "Installed batch: ${batch[*]}"
done

print_success "All development tools installed"

# =============================================================================
# PHASE 5: INSTALL APPLICATIONS
# =============================================================================

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
    "ice"
    "nordvpn"
    "spotify"
    "orion"
    "alacritty"
)

# Install apps in parallel batches
print_status "Installing applications in parallel batches..."

for ((i=0; i<${#CASK_APPS[@]}; i+=4)); do
    batch=("${CASK_APPS[@]:i:4}")
    for app in "${batch[@]}"; do
        if [[ -n "$app" ]]; then
            brew install --cask "$app" --no-quarantine &
        fi
    done
    wait
    print_success "Installed batch: ${batch[*]}"
done

print_success "All applications installed"

# =============================================================================
# PHASE 6: CONFIGURATION FILES
# =============================================================================

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
mkdir -p "~/Library/Application Support/Zed"

# Install font
if [[ -f /tmp/font.otf ]]; then
    cp /tmp/font.otf ~/Library/Fonts/MonaspaceRadonNF-Bold.otf
    print_success "Font installed"
else
    print_warning "Font download failed, skipping..."
fi

# Set wallpaper
if [[ -f /tmp/wallpaper.jpg ]]; then
    cp /tmp/wallpaper.jpg ~/Downloads/wallpaper.jpg
    osascript -e "tell application \"Finder\" to set desktop picture to POSIX file \"$HOME/Downloads/wallpaper.jpg\"" 2>/dev/null || true
    print_success "Wallpaper set"
else
    print_warning "Wallpaper download failed, skipping..."
fi

# Alacritty configuration
cat > ~/.config/alacritty/alacritty.yml << 'EOF'
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
    family: "MonaspaceRadonNF"
    style: Bold
  size: 14.0

# Shell
shell:
  program: /bin/zsh
  args:
    - --login
    - -c
    - "fastfetch && exec zsh"

# Scrolling
scrolling:
  history: 10000
  multiplier: 3

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
EOF

# Copy theme if downloaded
if [[ -f /tmp/theme.toml ]]; then
    cp /tmp/theme.toml ~/.config/alacritty/catppuccin-mocha.toml
    print_success "Alacritty theme configured"
else
    print_warning "Alacritty theme download failed, using default..."
fi

# Zed configuration
cat > ~/Library/Application\ Support/Zed/settings.json << 'EOF'
{
  "agent": {
    "enabled": true,
    "default_model": {
      "provider": "anthropic",
      "model": "claude-sonnet-4-thinking"
    },
    "tools": {
      "thinking": { "enabled": true },
      "terminal": { "enabled": true },
      "project_notifications": { "enabled": true },
      "web_search": { "enabled": true }
    }
  },
  "theme": {
    "mode": "system",
    "light": "One Light",
    "dark": "One Dark"
  },
  "ui_font_size": 16,
  "buffer_font_size": 15,
  "buffer_font_family": "MonaspaceRadonNF",
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
  "autosave": "on_focus_change",
  "relative_line_numbers": false,
  "cursor_blink": true,
  "hover_popover_enabled": true,
  "confirm_quit": false,
  "restore_on_startup": "last_workspace"
}
EOF

print_success "Zed configuration created"

# Fastfetch configuration (auto-generate)
fastfetch --gen-config &>/dev/null || true
print_success "Fastfetch configuration generated"

# =============================================================================
# PHASE 7: STARTUP APPLICATIONS & FINAL SETUP
# =============================================================================

print_status "Phase 7: Configuring startup applications..."

# Configure startup applications
STARTUP_APPS=(
    "Raycast:visible"
    "Rectangle:hidden"
    "HiddenBar:hidden"  
    "KeepingYouAwake:hidden"
    "Stats:hidden"
    "Itsycal:hidden"
    "Ice:hidden"
)

for app_config in "${STARTUP_APPS[@]}"; do
    IFS=':' read -r app_name visibility <<< "$app_config"
    hidden_flag=$([ "$visibility" = "hidden" ] && echo "true" || echo "false")
    
    if [[ -d "/Applications/${app_name}.app" ]]; then
        osascript -e "tell application \"System Events\" to make login item at end with properties {path:\"/Applications/${app_name}.app\", hidden:${hidden_flag}}" 2>/dev/null || true
        print_success "Added $app_name to startup ($visibility)"
    fi
done

# =============================================================================
# PHASE 8: RESTART SERVICES & CLEANUP
# =============================================================================

print_status "Phase 8: Applying final changes..."

# Restart affected services
killall Dock 2>/dev/null || true
killall Finder 2>/dev/null || true
killall SystemUIServer 2>/dev/null || true

# Update shell environment
{
    echo 'export PATH="/opt/homebrew/bin:$PATH"'
    echo 'eval "$(/opt/homebrew/bin/brew shellenv)"'
    echo 'alias ls="ls -la"'
    echo 'alias ll="ls -la"'
    echo 'alias grep="grep --color=always"'
} >> ~/.zshrc

print_success "Shell environment updated"

# =============================================================================
# COMPLETION SUMMARY
# =============================================================================

SETUP_TIME=$(($(date +%s) - START_TIME))
START_TIME=$(date +%s)

print_success "🚀 Setup completed successfully!"
echo
echo "📊 INSTALLATION SUMMARY:"
echo "========================"
echo "• Homebrew: Installed with ${#DEV_TOOLS[@]} dev tools"
echo "• Applications: ${#CASK_APPS[@]} apps installed via Cask"
echo "• Configurations: Alacritty, Zed, Fastfetch"
echo "• System: Optimized for speed and performance"
echo "• Startup: ${#STARTUP_APPS[@]} apps configured"
echo "• Font: MonaspaceRadonNF installed"
echo "• Theme: Catppuccin Mocha (Alacritty)"
echo "• Wallpaper: Custom wallpaper applied"
echo
echo "📝 Next Steps:"
echo "• Restart your terminal to see Fastfetch"
echo "• Open Raycast and configure shortcuts"
echo "• Launch Zed to complete first-time setup"
echo "• Check startup apps in System Preferences > Login Items"
echo
echo "📄 Setup log saved to: $LOG_FILE"
echo
print_success "Ready to rock! 🎸"

# Optional: Show system info
echo
print_status "System Information:"
fastfetch 2>/dev/null || echo "Run 'fastfetch' in a new terminal to see system info"
