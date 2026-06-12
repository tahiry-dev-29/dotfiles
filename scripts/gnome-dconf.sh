#!/usr/bin/env bash

# ==============================================================================
# GNOME Dconf Backup & Restore
# ==============================================================================

BACKUP_DIR="$HOME/dotfiles/configs/gnome"
mkdir -p "$BACKUP_DIR"

echo "╔══════════════════════════════════════════════════╗"
echo "║             GNOME DCONF MANAGER                  ║"
echo "╚══════════════════════════════════════════════════╝"

options=(
  "Backup Keybindings (/org/gnome/desktop/wm/keybindings/)"
  "Backup Custom Keybindings (/org/gnome/settings-daemon/plugins/media-keys/)"
  "Backup Extensions (/org/gnome/shell/extensions/)"
  "Backup Full GNOME Settings (/org/gnome/)"
  "Restore Keybindings"
  "Restore Custom Keybindings"
  "Restore Extensions"
  "Restore Full GNOME Settings"
  "Quit"
)

PS3="Select an option (1-9): "
select opt in "${options[@]}"; do
  case $REPLY in
    1)
      dconf dump /org/gnome/desktop/wm/keybindings/ > "$BACKUP_DIR/keybindings.ini"
      echo "✅ Keybindings backed up to $BACKUP_DIR/keybindings.ini"
      break
      ;;
    2)
      dconf dump /org/gnome/settings-daemon/plugins/media-keys/ > "$BACKUP_DIR/custom_keybindings.ini"
      echo "✅ Custom Keybindings backed up to $BACKUP_DIR/custom_keybindings.ini"
      break
      ;;
    3)
      dconf dump /org/gnome/shell/extensions/ > "$BACKUP_DIR/extensions.ini"
      echo "✅ Extensions backed up to $BACKUP_DIR/extensions.ini"
      break
      ;;
    4)
      dconf dump /org/gnome/ > "$BACKUP_DIR/full_gnome.ini"
      echo "✅ Full GNOME settings backed up to $BACKUP_DIR/full_gnome.ini"
      break
      ;;
    5)
      if [ -f "$BACKUP_DIR/keybindings.ini" ]; then
        dconf load /org/gnome/desktop/wm/keybindings/ < "$BACKUP_DIR/keybindings.ini"
        echo "✅ Keybindings restored."
      else
        echo "❌ No backup found for keybindings."
      fi
      break
      ;;
    6)
      if [ -f "$BACKUP_DIR/custom_keybindings.ini" ]; then
        dconf load /org/gnome/settings-daemon/plugins/media-keys/ < "$BACKUP_DIR/custom_keybindings.ini"
        echo "✅ Custom Keybindings restored."
      else
        echo "❌ No backup found for custom keybindings."
      fi
      break
      ;;
    7)
      if [ -f "$BACKUP_DIR/extensions.ini" ]; then
        dconf load /org/gnome/shell/extensions/ < "$BACKUP_DIR/extensions.ini"
        echo "✅ Extensions restored."
      else
        echo "❌ No backup found for extensions."
      fi
      break
      ;;
    8)
      if [ -f "$BACKUP_DIR/full_gnome.ini" ]; then
        dconf load /org/gnome/ < "$BACKUP_DIR/full_gnome.ini"
        echo "✅ Full GNOME settings restored."
      else
        echo "❌ No backup found for full GNOME."
      fi
      break
      ;;
    9)
      echo "Exiting."
      break
      ;;
    *)
      echo "Invalid option."
      ;;
  esac
done
