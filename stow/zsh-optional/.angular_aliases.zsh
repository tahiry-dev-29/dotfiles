# ==============================================================================
# 🅰️ ANGULAR & NX ALIASES
# ==============================================================================
if command -v nx >/dev/null 2>&1 || command -v ng >/dev/null 2>&1 || command -v bunx >/dev/null 2>&1; then
alias nx="bunx nx"
alias ngs="bunx nx serve"
alias ngb="bunx nx build"
alias ngt="bunx nx test"
alias ngl="bunx nx lint"
alias ngc="bunx nx g @nx/angular:component"
alias ngs-all="bunx nx run-many --target=serve --all --parallel"
alias ngg="bunx nx g"

# ══════════════════════════════════════════════════════════════════════════════
# 6. NX MONOREPO 🐬
# ══════════════════════════════════════════════════════════════════════════════

# Run
alias nxsa='br start:all'
alias nxpgl='br prisma:generate:local'
alias nxpmd='br prisma:migrate:deploy'
alias nxpstu='br prisma:studio'
alias nxba='br build:all'

# Generators
alias nxgc='bunx nx g @nx/angular:component'
alias nxgs='bunx nx g @nx/angular:service'
alias nxgp='bunx nx g @nx/angular:pipe'
alias nxgd='bunx nx g @nx/angular:directive'
alias nxgm='bunx nx g @nx/angular:module'
alias nxgr='bunx nx g @nx/angular:resolver'

# NX Functions
nx-new-api() { bunx nx g @nx/nest:application --name=${1:-api} --directory=apps/${1:-api} --unitTestRunner=none --linter=eslint; }
nx-new-lib() { bunx nx g @nx/nest:lib libs/$1; }
nx-gen-feat() {
  bunx nx g @nx/js:library $1 \
    --directory=libs/backend/features/$1 \
    --bundler=none --minimal --unitTestRunner=none \
    --importPath=@dimanew/backend/$1 --linter=none
}
nx-affected() { bunx nx affected --target=${1:-build} --base=origin/main; }
nx-dep() { bunx nx show project $1 --web; }  # see project dependencies


# ══════════════════════════════════════════════════════════════════════════════
# 7. ANGULAR 🦁  (Angular CLI — ng)
# ══════════════════════════════════════════════════════════════════════════════
# Dev
alias ngs-prod='ng serve --configuration=production'
alias ngb-prod='ng build --configuration=production'
alias ngtw='ng test --watch'
alias nge2e='ng e2e'

# Generators (ng generate)
alias nggc='ng g component'
alias nggs='ng g service'
alias nggp='ng g pipe'
alias nggd='ng g directive'
alias nggm='ng g module'
alias nggr='ng g resolver'
alias nggg='ng g guard'
alias nggi='ng g interceptor'
alias nggen='ng g enum'
alias nggcl='ng g class'
alias nggif='ng g interface'

# Generators avec options Angular moderne (standalone + scss + OnPush)
nggnew() {
  local name=$1
  local path=${2:-.}
  ng g component $path/$name --standalone --style=scss --change-detection=OnPush
  echo "✅ Component ✅ Component '$name' generated in generated in $path"
}

# Angular update
alias ng-update='ng update @angular/core @angular/cli'
alias ng-update-all='ng update'
alias ng-version='ng version'
alias ng-doc='ng doc'                 # open Angular doc
fi
