# ==============================================================================
# CONFIGURATION ZSH PRO 2026 - TAHIRY (Architect Edition)
# ==============================================================================

# 1. INSTANT PROMPT (Speed ⚡)
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

# 2. SYSTEM ENV
export TERM="xterm-256color"
export COLORTERM="truecolor"
export LANG="en_US.UTF-8"
export PATH="$HOME/.local/bin:$PATH"

# 3. PREZTO & PLUGINS
[[ -s "${ZDOTDIR:-$HOME}/.zprezto/init.zsh" ]] && source "${ZDOTDIR:-$HOME}/.zprezto/init.zsh"

if [ -f ~/.zsh/zsh-autosuggestions/zsh-autosuggestions.zsh ]; then
    source ~/.zsh/zsh-autosuggestions/zsh-autosuggestions.zsh
    export ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE="fg=8"
    export ZSH_AUTOSUGGEST_STRATEGY=(history completion)
    bindkey '^ ' autosuggest-accept
fi

[[ -f ~/.zsh/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh ]] && source ~/.zsh/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh


# 5. LANGUAGE & RUNTIME
# NVM
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"

# PNPM
export PNPM_HOME="$HOME/.local/share/pnpm"
case ":$PATH:" in *":$PNPM_HOME:"*) ;; *) export PATH="$PNPM_HOME:$PATH" ;; esac

# BUN
export BUN_INSTALL="$HOME/.bun"
export PATH="$BUN_INSTALL/bin:$PATH"
[ -s "$HOME/.bun/_bun" ] && source "$HOME/.bun/_bun"

# FLUTTER/ANDROID
export FLUTTER_HOME="$HOME/development/flutter"
export ANDROID_HOME="$HOME/Android/Sdk"
export PATH="$PATH:$FLUTTER_HOME/bin:$ANDROID_HOME/platform-tools:$ANDROID_HOME/cmdline-tools/latest/bin"

# 6. PRODUCTIVITY TOOLS
if command -v ng >/dev/null; then source <(ng completion script); fi
if command -v zoxide >/dev/null; then eval "$(zoxide init zsh)"; fi

# 7. THEME
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh
[[ -f ~/powerlevel10k/powerlevel10k.zsh-theme ]] && source ~/powerlevel10k/powerlevel10k.zsh-theme

# 8. TTY
[[ -t 0 ]] && stty -ixon

. "$HOME/.local/share/../bin/env"

# 9. HISTORY
HISTSIZE=100000
SAVEHIST=100000
HISTFILE=~/.zsh_history
setopt INC_APPEND_HISTORY
setopt SHARE_HISTORY

# 10. ALIASES (loaded last — after all runtimes & tools are ready)
[[ -f ~/.zsh_aliases ]] && source ~/.zsh_aliases

# 11. LOCAL OVERRIDES (Private configs)
[[ -f ~/.zsh_local ]] && source ~/.zsh_local
