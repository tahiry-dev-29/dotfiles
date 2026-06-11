#!/usr/bin/env bash

set -e

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="$HOME/.config"
BACKUP_DIR="$HOME/.dotfiles_backup_$(date +%Y%m%d_%H%M%S)"

echo "==============================================="
echo "🚀 Starting Dotfiles Interactive Installation"
echo "==============================================="
echo ""

prompt_install() {
    local name=$1
    local src=$2
    local dest=$3

    echo "-----------------------------------------------"
    echo "📦 Configuration: $name"
    echo "⚠️  WARNING: This will replace your current configuration at $dest."
    echo "   (A backup will automatically be created at $BACKUP_DIR if it exists)"
    
    read -p "Do you want to install the $name configuration? [y/N] " response
    if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
        link_file "$src" "$dest"
    else
        echo "⏭️  Skipping $name."
    fi
}

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

    echo "🔗 Creating symlink: $dest -> $src"
    mkdir -p "$(dirname "$dest")"
    ln -sf "$src" "$dest"
}

mkdir -p "$CONFIG_DIR"

CONFIG_APPS=("nvim" "trunk" "fish" "lazygit" "lazydocker" "ghostty" "zed")

for app in "${CONFIG_APPS[@]}"; do
    if [ -d "$DOTFILES_DIR/configs/$app" ]; then
        prompt_install "$app" "$DOTFILES_DIR/configs/$app" "$CONFIG_DIR/$app"
    fi
done

echo "-----------------------------------------------"
echo "📄 System Files"

if [ -f "$DOTFILES_DIR/configs/bashrc" ]; then
    prompt_install ".bashrc" "$DOTFILES_DIR/configs/bashrc" "$HOME/.bashrc"
fi

if [ -f "$DOTFILES_DIR/configs/zshrc" ]; then
    prompt_install ".zshrc" "$DOTFILES_DIR/configs/zshrc" "$HOME/.zshrc"
fi

if [ -f "$DOTFILES_DIR/configs/zsh_aliases" ]; then
    prompt_install ".zsh_aliases" "$DOTFILES_DIR/configs/zsh_aliases" "$HOME/.zsh_aliases"
fi

if [ -f "$DOTFILES_DIR/configs/p10k.zsh" ]; then
    prompt_install "Powerlevel10k (.p10k.zsh)" "$DOTFILES_DIR/configs/p10k.zsh" "$HOME/.p10k.zsh"
fi

if [ -f "$DOTFILES_DIR/configs/gitconfig" ]; then
    prompt_install ".gitconfig" "$DOTFILES_DIR/configs/gitconfig" "$HOME/.gitconfig"
fi

echo "==============================================="
echo "🎉 Installation complete!"
echo "If any existing directories were replaced, you can find their backups in:"
echo "$BACKUP_DIR"
