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

# 2. Install Dependencies
echo ""
echo "📦 System Dependencies"
read -p "  [?] Do you want to auto-install required system tools (tree, ripgrep, fd, zoxide, bun, pnpm, gh)? [Y/n] " ans_deps
if [[ "$ans_deps" =~ ^([yY][eE][sS]|[yY]|"")$ ]]; then
    echo "  🔄 Detecting OS and installing packages..."
    if command -v apt-get &> /dev/null; then
        sudo apt-get update
        sudo apt-get install -y tree ripgrep zoxide fd-find psmisc curl wget unzip
        
        # GitHub CLI for APT
        if ! command -v gh &> /dev/null; then
            echo "  🐙 Installing GitHub CLI..."
            curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg
            sudo chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg
            echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null
            sudo apt-get update
            sudo apt-get install -y gh
        fi
    elif command -v brew &> /dev/null; then
        brew install tree ripgrep zoxide fd psmisc curl wget unzip gh
    elif command -v pacman &> /dev/null; then
        sudo pacman -Sy --noconfirm tree ripgrep zoxide fd psmisc curl wget unzip github-cli
    else
        echo "  ⚠️ Unsupported package manager. Please install tree, ripgrep, fd, and zoxide manually."
    fi

    # Install Bun
    if ! command -v bun &> /dev/null; then
        echo "  🍞 Installing Bun..."
        curl -fsSL https://bun.sh/install | bash
    fi

    # Install pnpm
    if ! command -v pnpm &> /dev/null; then
        echo "  📦 Installing pnpm..."
        curl -fsSL https://get.pnpm.io/install.sh | sh -
    fi
    echo "  ✅ Dependencies installed!"
fi

# 3. Visuals & Fonts
echo ""
echo "🎨 Visuals & Fonts"
read -p "  [?] Do you want to auto-install MesloLGS NF (Nerd Font for Icons)? [Y/n] " ans_font
if [[ "$ans_font" =~ ^([yY][eE][sS]|[yY]|"")$ ]]; then
    echo "  📥 Downloading MesloLGS NF..."
    if [[ "$OSTYPE" == "darwin"* ]]; then
        FONT_DIR="$HOME/Library/Fonts"
    else
        FONT_DIR="$HOME/.local/share/fonts"
    fi
    mkdir -p "$FONT_DIR"
    wget -qO "$FONT_DIR/MesloLGS NF Regular.ttf" "https://github.com/romkatv/powerlevel10k-media/raw/master/MesloLGS%20NF%20Regular.ttf"
    wget -qO "$FONT_DIR/MesloLGS NF Bold.ttf" "https://github.com/romkatv/powerlevel10k-media/raw/master/MesloLGS%20NF%20Bold.ttf"
    wget -qO "$FONT_DIR/MesloLGS NF Italic.ttf" "https://github.com/romkatv/powerlevel10k-media/raw/master/MesloLGS%20NF%20Italic.ttf"
    wget -qO "$FONT_DIR/MesloLGS NF Bold Italic.ttf" "https://github.com/romkatv/powerlevel10k-media/raw/master/MesloLGS%20NF%20Bold%20Italic.ttf"
    if command -v fc-cache &> /dev/null; then
        fc-cache -f "$FONT_DIR"
    fi
    echo "  ✅ Fonts installed successfully!"
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

# 4. Interactive Menu
echo ""
echo "Please select the configurations you want to install:"
echo "-----------------------------------------------"

declare -A wants
apps=("nvim" "trunk" "lazygit" "lazydocker" "zsh" "fish" "ghostty")

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
for app in "nvim" "trunk" "lazygit" "lazydocker" "fish" "ghostty"; do
    if [ "${wants[$app]}" = true ] && [ -d "$DOTFILES_DIR/configs/$app" ]; then
        link_file "$DOTFILES_DIR/configs/$app" "$CONFIG_DIR/$app"
    fi
done


# ZSH Specific Logic
if [ "${wants[zsh]}" = true ]; then
    echo ""
    echo "🐚 Setting up Zsh core configurations..."
    
    # Clone ZSH Plugins
    echo ""
    echo "⚡ Setting up Zsh Plugins (Prezto, Autosuggestions, Syntax Highlighting)..."
    read -p "  [?] Do you want to auto-clone required Zsh plugins? [Y/n] " ans_zsh_plugins
    if [[ "$ans_zsh_plugins" =~ ^([yY][eE][sS]|[yY]|"")$ ]]; then
        update_or_clone() {
            local dir=$1
            local repo=$2
            if [ -d "$dir" ]; then
                echo "  🔄 Updating $(basename "$dir")..."
                git -C "$dir" pull origin master >/dev/null 2>&1 || git -C "$dir" pull origin main >/dev/null 2>&1 || true
            else
                echo "  📥 Cloning $(basename "$dir")..."
                git clone --recursive "$repo" "$dir" >/dev/null 2>&1
            fi
        }

        update_or_clone "$HOME/.zprezto" "https://github.com/sorin-ionescu/prezto.git"
        mkdir -p "$HOME/.zsh"
        update_or_clone "$HOME/.zsh/zsh-autosuggestions" "https://github.com/zsh-users/zsh-autosuggestions"
        update_or_clone "$HOME/.zsh/zsh-syntax-highlighting" "https://github.com/zsh-users/zsh-syntax-highlighting.git"
        
        if [ -d "$HOME/.zsh/powerlevel10k" ]; then
            echo "  🔄 Updating powerlevel10k..."
            git -C "$HOME/.zsh/powerlevel10k" pull origin master >/dev/null 2>&1 || true
        else
            echo "  📥 Cloning powerlevel10k..."
            git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "$HOME/.zsh/powerlevel10k" >/dev/null 2>&1
        fi
        
        echo "  ✅ Zsh plugins installed/updated successfully!"
    fi

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

    read -p "  [?] Do you want to enable the Flutter Aliases? [y/N] " ans_flutter
    if [[ "$ans_flutter" =~ ^([yY][eE][sS]|[yY])$ ]]; then
        link_file "$DOTFILES_DIR/configs/optional/flutter_aliases.zsh" "$HOME/.flutter_aliases.zsh"
    fi

    read -p "  [?] Do you want to enable the NestJS & Prisma Aliases? [y/N] " ans_nestjs
    if [[ "$ans_nestjs" =~ ^([yY][eE][sS]|[yY])$ ]]; then
        link_file "$DOTFILES_DIR/configs/optional/nestjs_prisma_aliases.zsh" "$HOME/.nestjs_prisma_aliases.zsh"
    fi

    read -p "  [?] Do you want to enable the Git & GitHub CLI Aliases? [y/N] " ans_git
    if [[ "$ans_git" =~ ^([yY][eE][sS]|[yY])$ ]]; then
        link_file "$DOTFILES_DIR/configs/optional/git_aliases.zsh" "$HOME/.git_aliases.zsh"
    fi
fi

echo "==============================================="
echo "🎉 Installation complete!"
echo "If any configurations were replaced, they were safely backed up with the .bak extension."
