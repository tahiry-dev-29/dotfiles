# 💻 Tahiry's Dotfiles

A centralized repository to instantly backup and restore my development environment on any machine. This setup is optimized for modern web and backend development (TypeScript, Angular, Nx Monorepos, NestJS) using Neovim, Fish shell, and terminal-based UI tools.

## 📦 Features & Configurations Included

### 1. 📝 Neovim (NvChad)
A highly customized Neovim configuration based on **NvChad (v2.5)** with specific enhancements:
- **LSP Configuration for Nx Monorepos**: TypeScript Language Server (`ts_ls`) is configured to perfectly understand Nx monorepos, correctly resolving paths from `nx.json` or `tsconfig.base.json` down to framework-specific files (`angular.json`, `next.config.js`, etc.).
- **Trunk Linter Integration**: Integrated floating terminal (`<C-t>`) to run `trunk check --show-existing` natively inside Neovim.
- **Diagnostics UI**: Custom "Problems" workspace (`<C-j>`) via Trouble.nvim, and clear sidebar margin icons.
- **Interconnected Ecosystem**: Directly launch terminal UI tools from within Neovim via floating terminals:
  - `<C-g>`: Opens **Lazygit** to manage git seamlessly.
  - `<C-d>`: Opens **Lazydocker** to monitor containers.
  - `<C-t>`: Opens **Trunk Check** to view linter diagnostics globally.
- **Safe Buffer Management**: Patched `<C-w>` mapping to safely close buffers without throwing `E5108`/`E517` errors on unlisted buffers or terminals.
- **Easy Menus**: Dashboard accessible via `<leader>m` and a contextual right-click menu (`<RightMouse>`).

#### LSP / Autocomplétion (typescript, tailwindcss, dart, js…)

Les serveurs LSP suivants sont actifs en insertion via `nvim-cmp` : `html`, `cssls`, `tailwindcss`, `prismals`, `angularls` (uniquement si `angular.json`), `dartls` (via Flutter), `ts_ls` et `eslint` (LSP).

**Pour installer les serveurs manquants** (une seule fois) :

```bash
# Option A — via Mason (dans Neovim, une fois lancé)
:MasonInstall html-lsp css-lsp tailwindcss-language-server prisma-language-server angular-language-server typescript-language-server eslint-lsp

# Option B — via npm global (binaires directement sur le PATH)
npm i -g typescript@5 typescript-language-server @tailwindcss/language-server vscode-langservers-extracted @prisma/language-server @angular/language-server
```

Notes importantes :
- `typescript` doit rester en **v5.x** : la v7 native ne fournit plus `tsserver.js`, ce qui fait échouer `ts_ls` (`"Could not find a valid TypeScript installation"`).
- Le dossier `~/.local/share/nvim/mason/bin` est ajouté au `PATH` (option `PATH = "prepend"`), sinon les serveurs installés par Mason ne sont jamais trouvés.
- Si vous installez par `npm -g`, `NODE_PATH` pointe vers les modules globaux pour que `ts_ls` fonctionne même dans un projet sans `typescript` local.
- `<C-]>` et `Ctrl+Clic` ouvrent la définition via le LSP (plus d'erreurs `E433: No tags file` / `E426: Tag not found`).
- `<C-t>` (Trunk scan) et `<leader>ta` (Trunk check all) détectent dynamiquement la racine du projet (dossier contenant `.trunk` / `trunk.yaml`, sinon racine git) et y exécutent `trunk` — même si nvim est ouvert dans un sous-dossier.
- `<leader>rr` / `<leader>rt` / `<leader>re` / `<leader>rl` détectent dynamiquement le `package.json` : d'abord en remontant les ancêtres, puis par une recherche `rg` vers le bas — ce qui trouve les packages situés dans un sous-dossier précis (monorepo `apps/*`, `packages/*`…).
- Les toasts/notifications (`nvim-notify`) disparaissent après **1,5 s**.

### 2. 🐚 Zsh Shell
My highly productive Zsh configuration including:
- Custom `.zshrc`.
- Massive custom aliases file (`.zsh_aliases`).
- Stunning Powerlevel10k prompt configuration (`.p10k.zsh`).

### 3. 🛠️ Terminal Tools
- **Lazygit**: Configuration for the terminal UI for git commands. Quickly accessible from Neovim via `<C-g>`.
- **Lazydocker**: Configuration for the terminal UI for Docker management. Quickly accessible from Neovim via `<C-d>`.
- **Trunk**: Centralized linter configuration (`~/.config/trunk`).
- **Herdr**: Terminal workspace manager for AI coding agents 🦬 (`~/.config/herdr`). Organizes workspaces/tabs/panes and manages agent sessions directly from the terminal. Versioned config (`config.toml`) + custom `command-palette.sh` launcher in `stow/herdr`, with aliases `hdr`, `hdrs`, `hdrws`, `hdrtb`, `hdrpn`, `hdrap`, `hdrun`, `hdr-env`. Keybinds (prefix `ctrl+a`): `<prefix>+shift+a` command palette · `<prefix>+shift+b` sidebar · `<prefix>+shift+m` mobile relay.

### 4. 🚀 Terminals & Editors


## 🧰 Prerequisites / Installation Links

Before symlinking your configurations, install the actual tools on your fresh PC. Here are the official fast-install commands:

<details>
<summary><b>Show Installation Commands</b></summary>

- **[Neovim (v0.10+)](https://neovim.io/)**:
  ```bash
  curl -LO https://github.com/neovim/neovim/releases/latest/download/nvim-linux64.tar.gz && sudo rm -rf /opt/nvim && sudo tar -C /opt -xzf nvim-linux64.tar.gz && export PATH="$PATH:/opt/nvim-linux64/bin"
  ```
- **[Trunk Linter](https://trunk.io/)**:
  ```bash
  curl -fsSl https://trunk.io/releases/trunk | bash
  ```
- **[Zsh & Oh My Zsh](https://ohmyz.sh/)**:
  ```bash
  sudo apt install zsh -y && sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
  ```
- **[Lazygit](https://github.com/jesseduffield/lazygit)**:
  ```bash
  LAZYGIT_VERSION=$(curl -s "https://api.github.com/repos/jesseduffield/lazygit/releases/latest" | grep -Po '"tag_name": "v\K[^"]*') && curl -Lo lazygit.tar.gz "https://github.com/jesseduffield/lazygit/releases/latest/download/lazygit_${LAZYGIT_VERSION}_Linux_x86_64.tar.gz" && tar xf lazygit.tar.gz lazygit && sudo install lazygit /usr/local/bin
  ```
- **[Lazydocker](https://github.com/jesseduffield/lazydocker)**:
  ```bash
  curl https://raw.githubusercontent.com/jesseduffield/lazydocker/master/scripts/install_update_linux.sh | bash
  ```
- **[Ghostty](https://github.com/ghostty-org/ghostty)**:

- **[Herdr (terminal workspace manager)](https://herdr.dev/)** — gère workspaces/tabs/panes pour les agents AI dans le terminal :
  ```bash
  curl -fsSL https://herdr.dev/install.sh | sh
  ```
  > Config gérée par dotfiles via `stow/herdr/.config/herdr/config.toml`. Plugins (`command-palette`, `herdr-sidebar`, `herdr-mobile-relay.events`) installés automatiquement par Herdr — seuls la config et `bin/command-palette.sh` sont versionnés.
</details>

## 🚀 Automated Configuration Installation (Zero-Touch)

You can install these dotfiles on a fresh machine with a single command. The included scripts intelligently symlink all configurations and safely backup any existing ones.

### 🐧 Linux / macOS

Just run this single bootstrap command. It will auto-clone the repository and open the interactive installation menu:

```bash
curl -fsSL https://raw.githubusercontent.com/tahiry-dev-29/dotfiles/master/config_tahiry.install.sh | bash
```
> 🔗 **[Download Linux/macOS Install Script](https://raw.githubusercontent.com/tahiry-dev-29/dotfiles/master/config_tahiry.install.sh)**

### 🪟 Windows (PowerShell)

Open PowerShell as Administrator (or ensure Developer Mode is enabled for Symlinks) and run:

```powershell
git clone https://github.com/tahiry-dev-29/dotfiles.git $env:USERPROFILE\dotfiles
cd $env:USERPROFILE\dotfiles
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
.\install.ps1
```
> 🔗 **[Download Windows Install Script](https://raw.githubusercontent.com/tahiry-dev-29/dotfiles/master/install.ps1)**

### What the scripts do:
1. Auto-clones the repository to `~/dotfiles` (if running the bootstrap script).
2. Presents an interactive menu (`[Y/n]`) for every tool.
3. If Zsh is selected, it prompts individually for optional modules (Angular / Docker).
4. Safely moves any existing config (e.g., `~/.config/nvim`) to a `.bak` file right next to it with a timestamp.
5. Creates a symlink from the dotfiles repository directly to your system's configuration folder.
