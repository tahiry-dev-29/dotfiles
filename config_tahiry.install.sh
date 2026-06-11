#!/usr/bin/env bash

set -e

DOTFILES_REPO="https://github.com/tahiry-dev-29/dotfiles.git"
DOTFILES_DIR="$HOME/dotfiles"
CONFIG_DIR="$HOME/.config"
CURRENT_DATE="$(date +%Y%m%d_%H%M%S)"

echo "==============================================="
echo "🚀 Tahiry's Dotfiles Bootstrap Installer"
echo "==============================================="

# 1. Auto-Clone
if [ -d "$DOTFILES_DIR" ]; then
    echo "✅ Dotfiles repository already exists at $DOTFILES_DIR. Pulling latest..."
    cd "$DOTFILES_DIR"
    git pull origin master
else
    echo "📦 Cloning dotfiles repository to $DOTFILES_DIR..."
    git clone "$DOTFILES_REPO" "$DOTFILES_DIR"
    cd "$DOTFILES_DIR"
fi

# Function to safely create symlinks
link_file() {
    local src=$1
    local dest=$2

    if [ -L "$dest" ] && [ "$(readlink "$dest")" = "$src" ]; then
        echo "✅ Already linked: $dest"
        return
    fi

    if [ -e "$dest" ] || [ -d "$dest" ]; then
        local backup_name="${dest}.${CURRENT_DATE}.bak"
        echo "📦 Backing up $dest to $backup_name"
        mv "$dest" "$backup_name"
    fi

    echo "🔗 Symlinking: $dest -> $src"
    mkdir -p "$(dirname "$dest")"
    ln -sf "$src" "$dest"
}

# 2. Interactive Menu
echo ""
echo "Please select the configurations you want to install:"
echo "-----------------------------------------------"

declare -A wants
apps=("nvim" "trunk" "lazygit" "lazydocker" "zsh" "fish" "ghostty" "zed" "gitconfig")

for app in "${apps[@]}"; do
    read -p "  [?] Install $app ? [Y/n] " response
    if [[ "$response" =~ ^([nN][oO]|[nN])$ ]]; then
        wants[$app]=false
        echo "      ⏭️  Skipping $app."
    else
        wants[$app]=true
    fi
done

echo "-----------------------------------------------"
echo "🚀 Applying configurations..."

mkdir -p "$CONFIG_DIR"

# Standard Apps
for app in "nvim" "trunk" "lazygit" "lazydocker" "fish" "ghostty" "zed"; do
    if [ "${wants[$app]}" = true ] && [ -d "$DOTFILES_DIR/configs/$app" ]; then
        link_file "$DOTFILES_DIR/configs/$app" "$CONFIG_DIR/$app"
    fi
done

# Gitconfig
if [ "${wants[gitconfig]}" = true ] && [ -f "$DOTFILES_DIR/configs/gitconfig" ]; then
    link_file "$DOTFILES_DIR/configs/gitconfig" "$HOME/.gitconfig"
fi

# ZSH Specific Logic
if [ "${wants[zsh]}" = true ]; then
    echo ""
    echo "🐚 Setting up Zsh core configurations..."
    [ -f "$DOTFILES_DIR/configs/zshrc" ] && link_file "$DOTFILES_DIR/configs/zshrc" "$HOME/.zshrc"
    [ -f "$DOTFILES_DIR/configs/zsh_aliases" ] && link_file "$DOTFILES_DIR/configs/zsh_aliases" "$HOME/.zsh_aliases"
    [ -f "$DOTFILES_DIR/configs/p10k.zsh" ] && link_file "$DOTFILES_DIR/configs/p10k.zsh" "$HOME/.p10k.zsh"

    echo ""
    echo "🧩 ZSH Optional Modules"
    read -p "  [?] Do you want to enable the Angular & Nx Aliases? [y/N] " ans_angular
    if [[ "$ans_angular" =~ ^([yY][eE][sS]|[yY])$ ]]; then
        link_file "$DOTFILES_DIR/configs/optional/angular_aliases.zsh" "$HOME/.angular_aliases.zsh"
    fi

    read -p "  [?] Do you want to enable the Docker Aliases? [y/N] " ans_docker
    if [[ "$ans_docker" =~ ^([yY][eE][sS]|[yY])$ ]]; then
        link_file "$DOTFILES_DIR/configs/optional/docker_aliases.zsh" "$HOME/.docker_aliases.zsh"
    fi
fi

echo "==============================================="
echo "🎉 Installation complete!"
echo "If any configurations were replaced, they were safely backed up with the .bak extension."
