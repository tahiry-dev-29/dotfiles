# ==============================================================================
# NESTJS 🐦 & PRISMA 🗄️ ALIASES
# ==============================================================================

if command -v pnpm >/dev/null 2>&1; then
# NESTJS 🐦
alias ns='pnpm start'
alias nsd='pnpm start:dev'
alias nsb='pnpm start:debug'
alias nsp='pnpm start:prod'

alias nsgm='pnpm nest g module'
alias nsgs='pnpm nest g service'
alias nsgc='pnpm nest g controller'
alias nsgg='pnpm nest g guard'
alias nsgp='pnpm nest g pipe'
alias nsgd='pnpm nest g decorator'
alias nsgmi='pnpm nest g middleware'
alias nsgint='pnpm nest g interceptor'


# PRISMA 🗄️
alias pgenx='pnpm exec dotenv -e .env -- prisma generate'
alias pmig='pnpm exec dotenv -e .env -- prisma migrate dev'
alias pmig-prod='pnpm exec dotenv -e .env -- prisma migrate deploy'
alias pstu='pnpm prisma studio'
alias pgen='pnpm prisma generate'
alias pdbpsh='pnpm prisma db push'
alias pdbpull='pnpm prisma db pull'

alias pseed='pnpm exec dotenv -e .env -- prisma db seed'
alias pcheck='pnpm prisma migrate status'

# Create a migration without applying it
pmig-create() { pnpm exec dotenv -e .env -- prisma migrate dev --name ${1:-migration} --create-only; }
fi
