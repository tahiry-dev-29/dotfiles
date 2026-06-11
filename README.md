# 💻 Tahiry's Dotfiles

A centralized repository to instantly backup and restore my development environment on any machine. This setup is optimized for modern web and backend development (TypeScript, Angular, Nx Monorepos, NestJS) using Neovim, Fish shell, and terminal-based UI tools.

## 📦 Features & Configurations Included

### 1. 📝 Neovim (NvChad)
A highly customized Neovim configuration based on **NvChad (v2.5)** with specific enhancements:
- **LSP Configuration for Nx Monorepos**: TypeScript Language Server (`ts_ls`) is configured to perfectly understand Nx monorepos, correctly resolving paths from `nx.json` or `tsconfig.base.json` down to framework specific files (`angular.json`, `next.config.js`, etc.).
- **Trunk Linter Integration**: Integrated floating terminal (`<C-t>`) to run `trunk check --show-existing` natively inside Neovim.
- **Diagnostics UI**: Custom "Problems" workspace (`<C-j>`) via Trouble.nvim, and clear sidebar margin icons.
- **Safe Buffer Management**: Patched `<C-w>` mapping to safely close buffers without throwing `E5108`/`E517` errors on unlisted buffers or terminals.
- **Easy Menus**: Dashboard accessible via `<leader>m` and a contextual right-click menu (`<RightMouse>`).

### 2. 🐚 Fish Shell
My default shell configuration (`~/.config/fish`), including aliases, paths, and environment variables (e.g., `uv` environment integration).

### 3. 🛠️ Terminal Tools
- **Lazygit**: Configuration for the terminal UI for git commands. Quickly accessible from Neovim via `<C-g>`.
- **Lazydocker**: Configuration for the terminal UI for Docker management. Quickly accessible from Neovim via `<C-d>`.
- **Trunk**: Centralized linter configuration (`~/.config/trunk`).

### 4. 🚀 Terminals & Editors
- **Ghostty**: Blazing fast terminal emulator config and themes (`catppuccin-mocha`).
- **Zed**: Configuration settings for the Zed editor.

### 5. ⚙️ System Files
- Custom `.bashrc` fallback.
- Global `.gitconfig`.

## 🚀 Automated Installation (Zero-Touch)

You can install these dotfiles on a fresh Linux/macOS machine with a single command. The included `install.sh` script does not rely on third-party tools like GNU Stow. It intelligently symlinks all configurations and safely backups any existing ones.

```bash
git clone https://github.com/$(gh api user -q ".login")/dotfiles.git ~/dotfiles
cd ~/dotfiles
chmod +x install.sh
./install.sh
```

### What `install.sh` does:
1. Iterates over all configurations in the `configs/` directory.
2. If an existing config (e.g., `~/.config/nvim`) is already present and is *not* a symlink, it safely moves it to `~/.dotfiles_backup_YYYYMMDD_HHMMSS`.
3. Creates a symlink from the `~/dotfiles/configs/` directory to the respective path in your `$HOME` folder.
