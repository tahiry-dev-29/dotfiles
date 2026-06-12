#!/usr/bin/env bash

set -euo pipefail

# Check if git-crypt is installed
if ! command -v git-crypt &> /dev/null; then
  echo "❌ git-crypt is not installed. Please install it first."
  exit 1
fi

DOTFILES_DIR="$HOME/dotfiles"
cd "$DOTFILES_DIR"

if [ -d "$DOTFILES_DIR/.git/git-crypt" ]; then
  echo "✅ git-crypt is already initialized in this repository."
else
  echo "🔒 Initializing git-crypt..."
  git-crypt init
  echo "✅ git-crypt initialized."
fi

echo "📝 Creating/Updating .gitattributes..."
cat << 'EOF' > .gitattributes
**/.env filter=git-crypt diff=git-crypt
**/*.secret filter=git-crypt diff=git-crypt
secrets/** filter=git-crypt diff=git-crypt
EOF

echo "✅ .gitattributes configured for .env files and secrets/ directory."

KEY_PATH="$HOME/.ssh/dotfiles_git_crypt_key"
echo "🔑 Exporting symmetric key..."
if [ ! -f "$KEY_PATH" ]; then
  git-crypt export-key "$KEY_PATH"
  echo "✅ Key exported to $KEY_PATH."
  echo "⚠️  IMPORTANT: Backup this key securely (e.g., password manager or USB drive)."
  echo "   If you lose this key, you will NEVER be able to decrypt your secrets on a new machine."
else
  echo "✅ Key already exists at $KEY_PATH."
fi
