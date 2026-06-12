# ==============================================================================
# GIT 🐙 & GITHUB CLI (gh) 🐈‍⬛ ALIASES
# ==============================================================================

if command -v git >/dev/null 2>&1; then
alias gs='git status'
alias ga='git add .'
alias gaa='git add -A'
alias gai='git add -i'                # interactive add
alias gc='git commit'
alias gcm='git commit -m'
alias gcam='git add . && git commit -m'
alias gca='git commit --amend --no-edit'
alias gcae='git commit --amend'
alias gp='git push'
alias gpf='git push --force-with-lease' # SAFE force push
alias gpo='git push -u origin HEAD'  # push new branch
alias gl='git pull'
alias glr='git pull --rebase'
alias gf='git fetch --all --prune'

alias glog="git log --oneline --graph --decorate --color"
alias gloga="git log --oneline --graph --decorate --all --color"
alias glogp='git log --pretty=format:"%C(yellow)%h%Creset %C(blue)%an%Creset %C(green)%ar%Creset %s"'

alias gb='git branch'
alias gba='git branch -a'
alias gbd='git branch -d'
alias gbD='git branch -D'
alias gsw='git switch'
alias gswc='git switch -c'           # create + switch
alias gco='git checkout'
alias gcob='git checkout -b'

alias gst='git stash'
alias gstp='git stash pop'
alias gstl='git stash list'
alias gstd='git stash drop'
alias gsta='git stash apply'

alias grb='git rebase'
alias grbi='git rebase -i'           # interactive rebase
alias grbc='git rebase --continue'
alias grba='git rebase --abort'

alias gd='git diff'
alias gds='git diff --staged'
alias gdw='git diff --word-diff'

alias grs='git restore'
alias grss='git restore --staged'    # unstage a file
alias grsh='git reset --hard HEAD'   # DANGER: discard all
alias grss1='git reset --soft HEAD~1' # undo last commit (keep changes)

alias gtag='git tag'
alias gtagp='git push origin --tags'

# Find who wrote what
gwho() { git log --follow -p -- $1; }
galias() { git config --get-regexp alias; }

# Sync fork with upstream
upstream-sync() {
  local main_branch=$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/origin/@@')
  main_branch=${main_branch:-main}
  echo "🔄 Sync with upstream/$main_branch..."
  git checkout $main_branch && git fetch upstream && git merge upstream/$main_branch --ff-only && git push origin $main_branch
  echo "✅ Fork synchronized!"
}

# Quick create PR
gpr() {
  git add . && git commit -m "${1:-wip}" && git push -u origin HEAD
  echo "🔗 Open GitHub to create your PR!"
  gh pr create --fill 2>/dev/null || echo "💡 Install gh CLI to auto-create the PR"
}

# Clean merged branches
gbclean() {
  git fetch --all --prune
  git branch --merged | grep -v '\*\|main\|master\|develop' | xargs -r git branch -d
  echo "🧹 Merged branches deleted"
}
fi

# ------------------------------------------------------------------------------
# GITHUB CLI (gh) 🐈‍⬛
# ------------------------------------------------------------------------------
if command -v gh >/dev/null 2>&1; then
alias ghpc='gh pr create --fill'
alias ghpl='gh pr list'
alias ghps='gh pr status'
alias ghpm='gh pr merge --merge --delete-branch'
alias ghpm-squash='gh pr merge --squash --delete-branch'
alias ghpm-rebase='gh pr merge --rebase --delete-branch'
alias ghv='gh repo view --web'
alias ghw='gh run watch'
alias ghr='gh run list'
fi
