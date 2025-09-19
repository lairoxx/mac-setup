#!/bin/bash
# Ultimate Automated macOS Ventura ARM Setup

set -euo pipefail
echo "🚀 Starting fully automated macOS setup..."

#-----------------------#
# 1. Install Homebrew
#-----------------------#
if ! command -v brew &>/dev/null; then
    echo "🍺 Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL "https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh")"
    echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.zprofile
    eval "$(/opt/homebrew/bin/brew shellenv)"
fi

#-----------------------#
# 2. Install Dev Tools
#-----------------------#
brew install git node pnpm bun go rust fastfetch

#-----------------------#
# 3. Install Cask Apps
#-----------------------#
apps=("zed" "sabnzbd" "vlc" "raycast" "shottr" "rectangle" "hiddenbar" "keepingyouawake" "appcleaner" "stats" "iina" "itsycal" "ice" "nordvpn" "spotify" "orion" "alacritty")
for app in "${apps[@]}"; do
    brew install --cask "$app" || echo "⚠️ Failed to install $app, skipping..."
done

#-----------------------#
# 4. Alacritty config
#-----------------------#
mkdir -p ~/.config/alacritty
curl -fsSL "https://raw.githubusercontent.com/catppuccin/alacritty/refs/heads/main/catppuccin-mocha.toml" -o ~/.config/alacritty/alacritty.yml

# Install font
FONT_DIR=~/Library/Fonts
mkdir -p "$FONT_DIR"
curl -fsSL "https://lairox.sirv.com/MonaspaceRadonNF-Bold.otf" -o "$FONT_DIR/MonaspaceRadonNF-Bold.otf"

#-----------------------#
# 5. Zed config
#-----------------------#
mkdir -p ~/Library/Application\ Support/Zed
cat > ~/Library/Application\ Support/Zed/settings.json <<'EOF'
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

#-----------------------#
# 6. Fastfetch config
#-----------------------#
mkdir -p ~/.config/fastfetch
fastfetch --gen-config > ~/.config/fastfetch/config.json

#-----------------------#
# 7. Dock + Dark Mode + Wallpaper
#-----------------------#
defaults write com.apple.dock persistent-apps -array
defaults write com.apple.dock persistent-others -array
killall Dock
osascript -e 'tell application "System Events" to tell appearance preferences to set dark mode to true'
curl -fsSL -o ~/Downloads/wallpaper.jpg "https://lawrencemillard.uk/downloads/wallpaper.jpg"
osascript -e 'tell application "System Events" to set picture of every desktop to (POSIX file "~/Downloads/wallpaper.jpg" as alias)'

#-----------------------#
# 8. Menubar transparency
#-----------------------#
defaults write -g AppleEnableMenuBarTransparency -bool true
killall SystemUIServer

#-----------------------#
# 9. Startup apps
#-----------------------#
for app in "Raycast" "NordVPN" "Ice" "Shottr"; do
    hidden=false
    [[ $app == "Ice" ]] && hidden=true
    osascript -e "tell application \"System Events\" to make login item at end with properties {path:\"/Applications/$app.app\", hidden:$hidden}"
done

#-----------------------#
# 10. Replace Spotlight with Raycast
#-----------------------#
defaults write com.apple.symbolichotkeys AppleSymbolicHotKeys -dict-add 64 "{enabled = 0;}"
defaults write com.apple.symbolichotkeys AppleSymbolicHotKeys -dict-add 65 "{enabled = 0;}"

#-----------------------#
# 11. Performance Tweaks
#-----------------------#
defaults write NSGlobalDomain NSAutomaticWindowAnimationsEnabled -bool false
defaults write com.apple.dock expose-animation-duration -float 0.1
defaults write com.apple.finder DisableAllAnimations -bool true
killall Dock
killall Finder

echo "✅ Fully automated setup complete! Reboot recommended."
