# 💻 Tahiry's Dotfiles

Un dépôt centralisé pour sauvegarder et restaurer instantanément mon environnement de développement sur n'importe quel ordinateur, de manière professionnelle et sans manipulation manuelle.

## 📦 Ce qui est inclus
- **Neovim** (Config complète NvChad avec LSP TS pour Nx, Trunk, etc.)
- **Trunk** (Linter configuration)
- **Fish Shell** (Configuration shell)
- **Lazygit & Lazydocker** (Configs UI)
- **Zed / Ghostty** (Si utilisés)
- **.bashrc / .gitconfig**

## 🚀 Installation automatisée (1 Commande)

Clone ce dépôt où tu le souhaites (ex: `~/dotfiles`) puis lance le script d'installation.
Le script liera automatiquement (`symlink`) toutes les configurations à leur bonne place et créera un dossier de sauvegarde si des configurations existent déjà sur la nouvelle machine.

```bash
git clone https://github.com/TON-UTILISATEUR/dotfiles.git ~/dotfiles
cd ~/dotfiles
chmod +x install.sh
./install.sh
```

C'est tout ! 🎉 Neovim, Fish et le reste sont configurés exactement comme tu les as laissés.
