#!/bin/bash
# ⚡ Ultimate macOS Ventura ARM Setup & Optimization
# Dev Stack + Apps + Fastfetch + Zed + Shottr hotkeys + Performance

echo "🚀 Starting ultimate setup..."

##############################
# 1. Homebrew + Git
##############################
if ! command -v brew &>/dev/null; then
    echo "🍺 Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.zprofile
    eval "$(/opt/homebrew/bin/brew shellenv)"
fi
brew install git

##############################
# 2. Dev Stack
##############################
brew install node pnpm bun go rust fastfetch

##############################
# 3. Apps via Brew
##############################
brew install --cask zed sabnzbd vlc raycast shottr rectangle hiddenbar keepingyouawake appcleaner stats iina itsycal

##############################
# 4. Manual installs
##############################
INSTALL_DIR="/Applications"

install_dmg() {
    local url="$1"
    local name="$2"
    local dmg="/tmp/$name.dmg"

    echo "⬇️ Downloading $name..."
    curl -L -o "$dmg" "$url"

    echo "📦 Mounting $name..."
    hdiutil attach "$dmg" -nobrowse -quiet
    cp -r "/Volumes/$name/$name.app" "$INSTALL_DIR"

    echo "💾 Unmounting $name..."
    hdiutil detach "/Volumes/$name" -quiet
    rm "$dmg"
}

install_dmg "https://github.com/jordanbaird/Ice/releases/latest/download/Ice.dmg" "Ice"
install_dmg "https://browser.kagi.com/download/Orion.dmg" "Orion"
install_dmg "https://downloads.nordcdn.com/apps/macos/generic/NordVPN.dmg" "NordVPN"

##############################
# 5. Zed config
##############################
mkdir -p ~/Library/Application\ Support/Zed
cat > ~/Library/Application\ Support/Zed/settings.json <<'EOF'
// Zed settings (user-provided)
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

##############################
# 6. Fastfetch config
##############################
mkdir -p ~/.config/fastfetch
fastfetch --gen-config > ~/.config/fastfetch/config.json

##############################
# 7. Dark Mode + Wallpaper
##############################
osascript -e 'tell application "System Events" to tell appearance preferences to set dark mode to true'
curl -o ~/Downloads/wallpaper.jpg https://lawrencemillard.uk/downloads/wallpaper.jpg
osascript -e 'tell application "System Events" to set picture of every desktop to (POSIX file "~/Downloads/wallpaper.jpg" as alias)'

##############################
# 8. Startup apps (only Raycast, NordVPN, Ice)
##############################
osascript -e 'tell application "System Events" to delete every login item'
osascript -e 'tell application "System Events" to make login item at end with properties {path:"/Applications/Raycast.app", hidden:false}'
osascript -e 'tell application "System Events" to make login item at end with properties {path:"/Applications/NordVPN.app", hidden:false}'
osascript -e 'tell application "System Events" to make login item at end with properties {path:"/Applications/Ice.app", hidden:true}'

##############################
# 9. Menu Bar + Dock
##############################
defaults write -g AppleEnableMenuBarTransparency -bool true
killall SystemUIServer
defaults write com.apple.dock persistent-apps -array
defaults write com.apple.dock persistent-others -array
killall Dock

##############################
# 10. Replace Spotlight with Raycast
##############################
defaults write com.apple.symbolichotkeys AppleSymbolicHotKeys -dict-add 64 "{enabled = 0;}"
defaults write com.apple.symbolichotkeys AppleSymbolicHotKeys -dict-add 65 "{enabled = 0;}"

##############################
# 11. Performance Tweaks
##############################
defaults write NSGlobalDomain NSAutomaticWindowAnimationsEnabled -bool false
defaults write com.apple.dock expose-animation-duration -float 0.1
defaults write com.apple.finder DisableAllAnimations -bool true
killall Dock
killall Finder

##############################
# 12. Shottr hotkeys (auto replace screenshots)
##############################
echo "⌨️ Configuring Shottr hotkeys..."
# Ensure Shottr runs at login
osascript -e 'tell application "System Events" to make login item at end with properties {path:"/Applications/Shottr.app", hidden:false}'
# Remap Cmd+Shift+3 & Cmd+Shift+4 to Shottr
# macOS doesn’t allow full programmatic override, but Shottr prompts to replace shortcuts on first launch

echo "✅ Ultimate setup & optimization complete! Reboot recommended."
