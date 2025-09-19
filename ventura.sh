#!/bin/bash
# Ultimate macOS Ventura ARM Setup & Optimization
# Fully Automated Interactive Script

echo "🚀 Starting Ultimate macOS Setup & Optimization..."

#--------------------------------#
# 1. Homebrew + Git
#--------------------------------#
if ! command -v brew &>/dev/null; then
    echo "🍺 Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.zprofile
    eval "$(/opt/homebrew/bin/brew shellenv)"
fi
brew install git

#--------------------------------#
# 2. Dev Stack
#--------------------------------#
brew install node pnpm bun go rust fastfetch

#--------------------------------#
# 3. Interactive browser choice
#--------------------------------#
echo "Choose browser to install (press Enter for None):"
select browser in "Orion" "Chrome" "Firefox" "None"; do
    case $browser in
        Orion) install_browser="orion"; break ;;
        Chrome) install_browser="google-chrome"; break ;;
        Firefox) install_browser="firefox"; break ;;
        None|"") install_browser=""; break ;;
    esac
done

#--------------------------------#
# 4. Interactive music choice
#--------------------------------#
echo "Choose music app to install (press Enter for None):"
select music in "Tidal" "Spotify" "None"; do
    case $music in
        Tidal) install_music="tidal"; break ;;
        Spotify) install_music="spotify"; break ;;
        None|"") install_music=""; break ;;
    esac
done

#--------------------------------#
# 5. Select additional apps
#--------------------------------#
apps_list=("Zed" "SABnzbd" "VLC" "Raycast" "Shottr" "Rectangle" "HiddenBar" "KeepingYouAwake" "AppCleaner" "Stats" "IINA" "Itsycal" "Ice" "NordVPN")
echo "Select additional apps to install (comma-separated numbers, press Enter to skip):"
for i in "${!apps_list[@]}"; do
    echo "$i) ${apps_list[$i]}"
done
read -p "Selection: " selection
IFS=',' read -ra selected_indices <<< "$selection"

#--------------------------------#
# 6. Homebrew search & install
#--------------------------------#
read -p "Do you want to search and install any Homebrew app? (y/n): " search_choice
if [[ $search_choice == "y" ]]; then
    read -p "Enter search term: " search_term
    echo "Searching Homebrew for '$search_term'..."
    brew search "$search_term"
    read -p "Enter app name to install (or leave empty to skip): " brew_app
    if [[ ! -z $brew_app ]]; then
        brew install --cask "$brew_app" || brew install "$brew_app"
    fi
fi

#--------------------------------#
# 7. Install apps
#--------------------------------#
echo "📦 Installing selected apps..."
if [[ ! -z $install_browser ]]; then brew install --cask "$install_browser"; fi
if [[ ! -z $install_music ]]; then brew install --cask "$install_music"; fi
for index in "${selected_indices[@]}"; do
    brew install --cask "${apps_list[$index]}"
done

#--------------------------------#
# 8. Manual DMG installs
#--------------------------------#
INSTALL_DIR="/Applications"
install_dmg() {
    local url="$1"
    local name="$2"
    local dmg="/tmp/$name.dmg"
    curl -L -o "$dmg" "$url"
    hdiutil attach "$dmg" -nobrowse -quiet
    cp -r "/Volumes/$name/$name.app" "$INSTALL_DIR"
    hdiutil detach "/Volumes/$name" -quiet
    rm "$dmg"
}

# Ice, Orion, NordVPN
install_dmg "https://github.com/jordanbaird/Ice/releases/latest/download/Ice.dmg" "Ice"
install_dmg "https://browser.kagi.com/download/Orion.dmg" "Orion"
install_dmg "https://downloads.nordcdn.com/apps/macos/generic/NordVPN.dmg" "NordVPN"

#--------------------------------#
# 9. Alacritty + Config + Font
#--------------------------------#
brew install --cask alacritty
mkdir -p ~/.config/alacritty
curl -fsSL https://raw.githubusercontent.com/catppuccin/alacritty/refs/heads/main/catppuccin-mocha.toml -o ~/.config/alacritty/alacritty.yml

# Font
FONT_DIR=~/Library/Fonts
mkdir -p "$FONT_DIR"
curl -fsSL https://lairox.sirv.com/MonaspaceRadonNF-Bold.otf -o "$FONT_DIR/MonaspaceRadonNF-Bold.otf"

#--------------------------------#
# 10. Zed config
#--------------------------------#
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

#--------------------------------#
# 11. Fastfetch config
#--------------------------------#
mkdir -p ~/.config/fastfetch
fastfetch --gen-config > ~/.config/fastfetch/config.json

#--------------------------------#
# 12. Dock, Dark Mode, Menubar, HiddenBar
#--------------------------------#
defaults write com.apple.dock persistent-apps -array
defaults write com.apple.dock persistent-others -array
killall Dock
osascript -e 'tell application "System Events" to tell appearance preferences to set dark mode to true'
curl -o ~/Downloads/wallpaper.jpg https://lawrencemillard.uk/downloads/wallpaper.jpg
osascript -e 'tell application "System Events" to set picture of every desktop to (POSIX file "~/Downloads/wallpaper.jpg" as alias)'
defaults write -g AppleEnableMenuBarTransparency -bool true
killall SystemUIServer

#--------------------------------#
# 13. Startup apps: Raycast, NordVPN, Ice, Shottr
#--------------------------------#
osascript -e 'tell application "System Events" to delete every login item'
for app in "Raycast" "NordVPN" "Ice" "Shottr"; do
    hidden=false
    [[ $app == "Ice" ]] && hidden=true
    osascript -e "tell application \"System Events\" to make login item at end with properties {path:\"/Applications/$app.app\", hidden:$hidden}"
done

#--------------------------------#
# 14. Replace Spotlight with Raycast
#--------------------------------#
defaults write com.apple.symbolichotkeys AppleSymbolicHotKeys -dict-add 64 "{enabled = 0;}"
defaults write com.apple.symbolichotkeys AppleSymbolicHotKeys -dict-add 65 "{enabled = 0;}"

#--------------------------------#
# 15. Performance Tweaks
#--------------------------------#
defaults write NSGlobalDomain NSAutomaticWindowAnimationsEnabled -bool false
defaults write com.apple.dock expose-animation-duration -float 0.1
defaults write com.apple.finder DisableAllAnimations -bool true
killall Dock
killall Finder

echo "✅ Ultimate setup & optimization complete! Reboot recommended."
