#!/usr/bin/env bash

set -e

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="$HOME/.config"
BACKUP_DIR="$HOME/.dotfiles_backup_$(date +%Y%m%d_%H%M%S)"

echo "🚀 Starting dotfiles installation..."

# Function to create a symbolic link with backup
link_file() {
    local src=$1
    local dest=$2

    if [ -L "$dest" ]; then
        if [ "$(readlink "$dest")" = "$src" ]; then
            echo "✅ Already linked: $dest"
            return
        fi
    fi

    if [ -e "$dest" ] || [ -d "$dest" ]; then
        echo "📦 Backing up $dest to $BACKUP_DIR"
        mkdir -p "$BACKUP_DIR"
        mv "$dest" "$BACKUP_DIR/"
    fi

    echo "🔗 Creating link: $dest -> $src"
    mkdir -p "$(dirname "$dest")"
    ln -sf "$src" "$dest"
}

# 1. Directories in ~/.config
echo "📂 Configuring ~/.config..."
mkdir -p "$CONFIG_DIR"

CONFIG_APPS=("nvim" "trunk" "fish" "lazygit" "lazydocker" "ghostty" "zed")

for app in "${CONFIG_APPS[@]}"; do
    if [ -d "$DOTFILES_DIR/configs/$app" ]; then
        link_file "$DOTFILES_DIR/configs/$app" "$CONFIG_DIR/$app"
    fi
done

# 2. Files in the root of ~/
echo "📄 Configuring system files..."
if [ -f "$DOTFILES_DIR/configs/bashrc" ]; then
    link_file "$DOTFILES_DIR/configs/bashrc" "$HOME/.bashrc"
fi

if [ -f "$DOTFILES_DIR/configs/zshrc" ]; then
    link_file "$DOTFILES_DIR/configs/zshrc" "$HOME/.zshrc"
fi

if [ -f "$DOTFILES_DIR/configs/zsh_aliases" ]; then
    link_file "$DOTFILES_DIR/configs/zsh_aliases" "$HOME/.zsh_aliases"
fi

if [ -f "$DOTFILES_DIR/configs/p10k.zsh" ]; then
    link_file "$DOTFILES_DIR/configs/p10k.zsh" "$HOME/.p10k.zsh"
fi

if [ -f "$DOTFILES_DIR/configs/gitconfig" ]; then
    link_file "$DOTFILES_DIR/configs/gitconfig" "$HOME/.gitconfig"
fi

echo "🎉 Installation complete! If directories already existed, they have been backed up in $BACKUP_DIR."
