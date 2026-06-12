# ==============================================================================
# 🐳 DOCKER PRO ALIASES
# ==============================================================================
alias dup="docker compose up -d"
alias ddown="docker compose down"
alias dbuild="docker compose build"
alias dlogs="docker compose logs -f"
alias dps="docker ps"
alias dima="cd ~/Projects/Angular/dima-new"
alias dima-up="docker compose --env-file .env.docker up -d --build"
alias dima-down="docker compose --env-file .env.docker down"

# ══════════════════════════════════════════════════════════════════════════════
# 3. DOCKER 🐋 (migrated from zsh_aliases)
# ══════════════════════════════════════════════════════════════════════════════
if command -v docker >/dev/null 2>&1; then
alias d='docker'
alias dc='docker compose'
alias dcu='docker compose up -d'
alias dcd='docker compose down'
alias dcr='docker compose restart'
alias dcl='docker compose logs -f'
alias dcp='docker compose pull'
alias dcb='docker compose up -d --build'

alias dpsa='docker ps -a --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"'
alias di='docker images'
alias dprune='docker system prune -af --volumes && echo "🧹 Docker cleaned"'
alias dstats='docker stats --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}"'

# Enter a container
dsh() { docker exec -it $1 /bin/sh; }
dbash() { docker exec -it $1 /bin/bash; }
dlogs() { docker logs -f --tail=100 $1; }
fi
