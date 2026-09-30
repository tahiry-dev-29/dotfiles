# Git Worktree &amp; Branch Manager — Final Production Version

You are working on an existing Ubuntu/Linux Git Worktree &amp; Branch Manager project.

The project already has a working Phase 1 implementation with:

- `gwt` — interactive Git Worktree Manager
- `gb` — interactive Git Branch Manager
- `fzf` as the TUI/fuzzy-selection engine
- safe Git command execution using arrays
- protected branch handling
- dirty-worktree detection
- safe branch deletion
- detached worktree creation
- preview panes
- automated tests
- shell integration
- GitHub CLI (`gh`) installed and authenticated

Do NOT rewrite the project from scratch.

Your goal is to transform the current Phase 1 implementation into the **complete, production-ready final version** of the Git Worktree &amp; Branch Manager.

---

# 1. FIRST: INSPECT THE EXISTING IMPLEMENTATION

Before modifying anything:

1. Inspect the complete existing implementation.
2. Understand the current architecture.
3. Inspect:
   - `scripts/gwt`
   - `scripts/gb`
   - `scripts/git-tools/`
   - existing worktree scripts
   - existing branch scripts
   - shell aliases
   - tests
   - Git configuration
   - GitHub CLI configuration
4. Run the existing test suite.
5. Identify which requested features already exist.
6. Do not duplicate existing functionality.
7. Reuse existing services/helpers where appropriate.
8. Preserve backward compatibility.

The current Phase 1 implementation is the foundation.

Do not destroy working functionality just to implement the final version.

---

# 2. CORE OBJECTIVE

The final application must behave like a real **Git Worktree + Branch + PR + Issue management TUI**, not simply like a wrapper around:

```
git worktree
git branch
```

The user should be able to manage the complete local development workflow from the terminal.

The two main commands remain:

```
gwt
gb
```

Running:

```
gwt
```

without arguments opens the Worktree Manager.

Running:

```
gb
```

without arguments opens the Branch Manager.

Existing CLI behavior with arguments must remain compatible.

---

# 3. UI ENGINE

Use the existing `fzf` implementation.

Do NOT replace `fzf` with another UI framework unless there is a concrete technical reason.

Use `fzf` capabilities extensively:

- fuzzy search
- multi-selection
- preview pane
- keyboard shortcuts
- headers
- reload
- ANSI formatting
- actions
- dynamic filtering

The UI should feel like a serious terminal productivity tool.

It should be fast and keyboard-first.

---

# 4. GWT — WORKTREE MANAGER

`gwt` must become the central Worktree Manager.

## Main view

Display:

```
Git Worktrees

● main        ~/project
● feature/a   ~/project-feature-a
● feature/b   ~/project-feature-b
● detached    ~/project-test
```

For each worktree show:

- current branch
- path
- short SHA
- clean/dirty state
- detached state
- upstream
- ahead/behind
- main/current worktree marker

Example:

```
● feature/auth
  ~/project-auth
  clean
  ↑2 ↓0
```

---

# 5. GWT ACTIONS

Implement:

```
Enter     Open/details
n         Create worktree
p         Create from Pull Request
i         Create from Issue
c         Create from Commit
t         Create from Tag
d         Create detached worktree
r         Remove worktree
R         Refresh
m         Multi-select
?         Help
q         Quit
```

Do not blindly use `Enter` to execute destructive operations.

---

# 6. CREATE WORKTREE

The user must be able to create a worktree from:

### Branch

```
Branch:
feature/auth

Base:
main

Path:
../project-auth
```

Preview:

```
git worktree add -b feature/auth ../project-auth main
```

Require confirmation before execution.

---

# 7. CREATE DETACHED WORKTREE

Support:

```
Commit SHA
Tag
Any Git ref
```

Example:

```
git worktree add --detach ../project-test 8f31abc
```

Show the exact command before execution.

The user must explicitly confirm.

---

# 8. CREATE WORKTREE FROM PR

Integrate GitHub CLI.

Detect GitHub automatically from the Git remote.

Use:

```
gh
```

Do not implement a custom GitHub API unless necessary.

The user should be able to:

```
gwt
→ p
→ search/filter PRs
→ select PR
→ inspect PR
→ create worktree
```

Display:

- PR number
- title
- author
- state
- source branch
- target branch
- CI/check status when available

Example:

```
#142  feat: authentication
      tahiry-dev
      feature/auth → main
      ✓ CI
```

After selecting a PR:

```
Create worktree for PR #142?

Branch: feature/auth
Base: main
Path: ../project-feature-auth
```

Preview the command.

Never merge the PR automatically.

The purpose is to **locally test/review the PR**.

---

# 9. CREATE WORKTREE FROM ISSUE

Support GitHub Issues.

Flow:

```
gwt
→ i
→ search issue
→ select issue
→ create branch/worktree
```

Example:

```
Issue #421
Fix authentication timeout
```

Suggested branch:

```
fix/421-authentication-timeout
```

Allow the user to modify the branch name before execution.

Show:

```
git worktree add -b fix/421-authentication-timeout ../project-421 main
```

Require confirmation.

---

# 10. CREATE WORKTREE FROM COMMIT

Support:

```
c
```

Search commits.

Display:

```
8f31abc  fix(auth): validate refresh token
91a23ef  feat(api): add user endpoint
```

Selecting one should allow:

```
Create normal branch worktree
OR
Create detached worktree
```

The distinction must be explicit.

---

# 11. CREATE WORKTREE FROM TAG

Support:

```
t
```

Show tags:

```
v1.0.0
v1.1.0
v1.2.0
```

Allow:

```
Create detached worktree
```

Preview:

```
git worktree add --detach ../project-v1.2.0 v1.2.0
```

---

# 12. WORKTREE REMOVAL

Removing a worktree must be safe.

Before removal:

```
Worktree:
~/project-feature-auth

Branch:
feature/auth

Status:
DIRTY

Uncommitted changes:
3 files

Remove anyway?
[y/N]
```

Never use:

```
rm -rf
```

Use:

```
git worktree remove
```

Only allow forced removal after explicit confirmation.

Never silently destroy user changes.

---

# 13. GB — BRANCH MANAGER

`gb` must become a real Branch Manager.

Provide filters:

```
ALL
MERGED
NOT MERGED
WITH CHANGES
REMOTE
HISTORICAL
```

Support:

```
/
```

for fuzzy search.

---

# 14. BRANCH INFORMATION

Each branch should display:

- branch name
- current marker
- merged/unmerged
- upstream
- ahead/behind
- associated worktree
- latest commit
- commit date
- commit author

Example:

```
● feature/auth
  unmerged
  ↑3 ↓1
  worktree: ~/project-auth
  fix(auth): refresh token validation
```

---

# 15. BRANCH DETAILS

Do NOT make `Enter` immediately switch branches.

Prefer:

```
Enter = Details
s     = Switch
w     = Create worktree
d     = Delete
p     = Pull Request
R     = Refresh
```

The branch detail screen should display:

```
Branch
Upstream
Worktree
Status
Ahead / Behind

Recent commits

Changed files

Diff statistics

Pull Request
```

Actions should be available from this screen.

---

# 16. BRANCH SWITCHING

Switching must be explicit:

```
s
```

Before switching:

- detect dirty current worktree
- detect conflicts
- ensure branch exists
- explain what will happen

Never silently discard changes.

Prefer:

```
git switch <branch>
```

over legacy:

```
git checkout <branch>
```

unless compatibility requires otherwise.

---

# 17. MULTI-SELECTION

This is mandatory.

Use `fzf` multi-select.

Example:

```
[ ] feature/auth
[x] feature/payment
[x] feature/dashboard
[ ] feature/docs
```

Bulk actions:

```
Delete branches
Create worktrees
Inspect branches
Refresh
```

Never execute destructive bulk operations without a final confirmation showing the exact selected items.

---

# 18. SAFE BRANCH DELETION

Default:

```
git branch -d <branch>
```

For unmerged branches:

```
Branch feature/experimental is NOT merged.

Force delete?

This may permanently remove the branch reference.

[y/N]
```

Only then allow:

```
git branch -D <branch>
```

Never automatically force delete.

Never delete:

```
main
master
develop
trunk
```

or configured protected branches.

---

# 19. PULL REQUEST MANAGEMENT

`gb` and `gwt` should understand associated PRs.

For a branch:

```
PR #142
feat: authentication
OPEN
```

Allow:

```
View PR
Open PR in browser
Create worktree
Refresh PR state
```

Do NOT merge PRs automatically.

PR creation may be supported through:

```
gh pr create
```

but must require user confirmation.

---

# 20. ISSUE MANAGEMENT

Support:

```
gh issue list
gh issue view
```

Allow:

```
Search issue
Inspect issue
Create branch
Create worktree
```

Do not automatically close issues.

---

# 21. REMOTE BRANCHES

Support:

```
REMOTE
```

branches.

Allow the user to:

- inspect remote branch
- create local branch
- create worktree from remote branch
- fetch/refresh

Example:

```
git fetch --prune
git switch --track origin/feature/auth
```

Never silently overwrite an existing local branch.

---

# 22. HISTORY

Add branch history view.

Show:

```
Branch
├── commit
├── commit
├── commit
└── commit
```

Use:

```
git log --graph --decorate --oneline
```

Allow:

```
View commit
Create worktree from commit
```

---

# 23. TAG MANAGEMENT

Support:

```
Tags
```

Allow:

- search tags
- inspect tag
- create detached worktree
- inspect commit

Do not delete tags automatically.

---

# 24. COMMAND PREVIEW

Every mutation must have a preview.

Example:

```
Action

Create worktree

Command:
git worktree add -b feature/auth ../project-auth main

Proceed? [y/N]
```

For deletion:

```
Command:
git branch -d feature/auth

Proceed? [y/N]
```

The preview must reflect the actual command that will execute.

---

# 25. SAFETY MODEL

Safety has the highest priority.

Never use:

```
eval
```

Never construct unsafe shell strings.

Use Bash arrays:

```
cmd=(git worktree add ...)
"${cmd[@]}"
```

All external arguments must remain separate arguments.

Avoid:

```
sh -c "$user_input"
```

Never execute arbitrary user input.

---

# 26. DANGEROUS OPERATIONS

The application must NOT automatically execute:

```
git reset --hard
git clean -fd
git branch -D
rm -rf
git worktree remove --force
```

unless the user explicitly requests the dangerous operation and confirms it.

---

# 27. DIRTY STATE

Before destructive operations inspect:

```
git status --porcelain
```

Handle:

- modified files
- staged files
- untracked files
- conflicts

Display exactly why an operation is blocked.

---

# 28. PROTECTED BRANCHES

Support configurable protected branches.

Default:

```
main
master
develop
trunk
```

Configuration should allow:

```
protected_branches=main,master,develop,trunk
```

Never delete a protected branch through the TUI.

---

# 29. GITHUB DETECTION

Automatically detect GitHub from:

```
git remote -v
git remote get-url origin
```

Support:

```
github.com
```

Use:

```
gh
```

if available and authenticated.

If GitHub CLI is unavailable:

- local Git features must continue working
- show a clear message for GitHub-only features
- never make the whole application unusable

Design provider support so GitLab can be added later.

---

# 30. CONFIGURATION

Create a clean configuration mechanism.

Potential configuration:

```
protected branches
default base branch
worktree directory
branch naming templates
GitHub provider
confirmation behavior
```

Example:

```
~/.config/git-tools/config
```

Do not hard-code everything into the TUI.

---

# 31. WORKTREE PATH GENERATION

Support predictable worktree paths.

Example:

```
~/worktrees/project-feature-auth
~/worktrees/project-feature-payment
~/worktrees/project-142
```

The user must be able to override the generated path.

Never overwrite an existing directory without explicit confirmation.

---

# 32. PERFORMANCE

The TUI should remain responsive in repositories with:

- hundreds of branches
- hundreds of commits
- many worktrees

Avoid unnecessarily executing expensive Git/GitHub commands for every keystroke.

Use:

- caching
- refresh commands
- lazy loading
- targeted Git queries

Do not call the GitHub API continuously while typing.

---

# 33. ERROR HANDLING

Every command must:

1. execute safely
2. capture exit code
3. capture stderr
4. display meaningful error
5. return to the TUI without crashing

Example:

```
ERROR

Cannot create worktree.

fatal: 'feature/auth' is already checked out

Press Enter to continue.
```

Never hide Git errors.

---

# 34. ARCHITECTURE

Keep the current modular architecture.

Maintain a strict separation:

```
UI
 ↓
Use Cases
 ↓
Services
 ↓
Git / GitHub adapters
 ↓
Executor
```

Suggested structure:

```
scripts/
├── gwt
├── gb
└── git-tools/
    ├── bin/
    │   ├── gwt
    │   └── gb
    │
    ├── lib/
    │   ├── core.sh
    │   ├── executor.sh
    │   ├── repo.sh
    │   ├── worktree_service.sh
    │   ├── branch_service.sh
    │   ├── commit_service.sh
    │   ├── tag_service.sh
    │   ├── remote_service.sh
    │   ├── github_service.sh
    │   ├── issue_service.sh
    │   ├── pr_service.sh
    │   ├── config.sh
    │   ├── ui_fzf.sh
    │   ├── tui_worktree.sh
    │   └── tui_branch.sh
    │
    └── tests/
        ├── test_phase1.sh
        ├── test_worktree.sh
        ├── test_branch.sh
        ├── test_safety.sh
        ├── test_remote.sh
        └── test_integration.sh
```

Keep files small and focused.

Prefer one responsibility per file.

Do not create giant Bash files containing unrelated logic.

Target approximately 200 lines or less per file where practical.

If a file grows significantly beyond that, split the responsibility.

---

# 35. TESTING

Create comprehensive tests using temporary Git repositories.

Test:

### Repository

- root detection
- nested directory
- invalid directory
- bare repository handling

### Worktree

- create
- detached
- remove
- dirty protection
- force removal
- duplicate path
- duplicate branch
- existing worktree

### Branch

- create
- switch
- merged detection
- unmerged detection
- safe deletion
- force deletion
- protected branches
- remote branches

### Commit

- lookup
- detached worktree
- branch from commit

### Tags

- list
- lookup
- detached worktree

### GitHub

Mock or isolate GitHub calls where appropriate.

Test:

- PR listing
- PR lookup
- issue listing
- issue lookup
- authentication failure
- `gh` unavailable

### Safety

Explicitly test that dangerous commands cannot execute without confirmation.

---

# 36. REGRESSION

Before declaring the final version complete:

Run the existing Phase 1 tests.

All previous tests must continue passing.

Then run the new test suite.

Target:

```
0 failures
0 regressions
```

If a feature cannot be tested automatically, document why and provide a manual verification procedure.

---

# 37. BACKWARD COMPATIBILITY

Preserve:

```
gwt <existing-command>
gb <existing-command>
```

Existing aliases/scripts must continue working unless they directly conflict with the new manager.

Do not break unrelated shell tooling.

---

# 38. UX DETAILS

The TUI should always show:

```
Repository
Current branch
Current worktree
Current action
Available keyboard shortcuts
```

Example:

```
Git Worktree Manager
Repository: ~/projects/my-app
Branch: main

────────────────────────────────────────

● main
● feature/auth
● feature/payment
● detached @ 8f31abc

────────────────────────────────────────

Enter Details   n New   p PR   i Issue
c Commit         t Tag   d Remove
/ Search         R Refresh
? Help           q Quit
```

Use clear status indicators:

```
clean
dirty
merged
unmerged
ahead
behind
detached
protected
```

Avoid excessive colors or visual noise.

---

# 39. HELP SCREEN

Implement:

```
?
```

Show all available shortcuts for the current screen.

The help screen should adapt to:

```
gwt
gb
branch details
PR selection
issue selection
commit selection
```

---

# 40. FINAL ACCEPTANCE CRITERIA

The implementation is complete only if the user can perform this entire workflow without manually typing low-level Git commands:

```
gwt
  ↓
list worktrees
  ↓
p
  ↓
search PR
  ↓
select PR #142
  ↓
inspect PR
  ↓
create worktree
  ↓
preview command
  ↓
confirm
  ↓
worktree created
  ↓
run application/tests manually
  ↓
return to gwt
  ↓
remove worktree safely
```

And:

```
gb
  ↓
search branch
  ↓
open branch details
  ↓
inspect commits
  ↓
inspect changed files
  ↓
inspect associated PR
  ↓
create worktree
```

And:

```
gb
  ↓
multi-select branches
  ↓
bulk operation
  ↓
show exact selected branches
  ↓
confirmation
  ↓
safe execution
```

And:

```
gwt
  ↓
c
  ↓
select commit
  ↓
create detached worktree
  ↓
preview
  ↓
confirm
```

---

# 41. IMPORTANT DESIGN PRINCIPLE

This tool is NOT intended to hide Git.

It is intended to make advanced Git workflows safer and faster.

The user should always understand:

```
WHAT
WHERE
WHY
COMMAND
RESULT
```

before destructive operations.

The TUI is an interface over Git, not a replacement for Git's semantics.

Always prefer correct Git behavior over UI convenience.

---

# 42. IMPLEMENTATION STRATEGY

Do not implement everything blindly in one giant change.

Work incrementally:

## Step 1

Inspect current implementation.

## Step 2

Fix/refactor Phase 1 if necessary.

## Step 3

Implement:

- branch filters
- search
- multi-selection
- branch details
- commits
- tags
- remote branches

## Step 4

Implement GitHub:

- PRs
- Issues
- PR → worktree
- Issue → branch/worktree
- PR details

## Step 5

Implement configuration.

## Step 6

Implement caching/performance improvements.

## Step 7

Implement comprehensive tests.

## Step 8

Run regression tests.

## Step 9

Perform manual end-to-end testing in a real GitHub repository.

## Step 10

Only after all of that, declare the project production-ready.

---

# 43. FINAL REPORT

At the end provide a concise report containing:

```
Implementation status
Features completed
Features intentionally not implemented
Files created/modified
Tests executed
Tests passed/failed
GitHub integration status
Known limitations
Manual verification steps
Example commands
```

Also explicitly state whether the complete workflow is functional:

```
gwt → PR → inspect → create worktree → test → remove

gb → branch → details → worktree → PR

gb → multi-select → bulk action

gwt → commit/tag → detached worktree
```

Do not claim a feature is complete unless it was actually implemented and tested.

---

# FINAL PRIORITY

Use this priority order throughout the implementation:

1. **Safety**
2. **Correct Git semantics**
3. **Data integrity**
4. **Existing functionality / backward compatibility**
5. **UX**
6. **Performance**
7. **GitHub integration**
8. **Convenience**

Do not sacrifice Git safety for a faster or prettier TUI.

Build this as a serious developer productivity tool that can be used daily on real repositories.