# Build a Power-User Git Worktree & Branch Manager TUI with `ns`

## Objective

Build a production-quality terminal UI workflow for managing Git branches, Git worktrees, detached worktrees, pull requests, issues, commits, and tags.

The tool must be optimized for an experienced developer / architect who frequently works with multiple Git worktrees and parallel feature branches.

The UI must use the existing `ns` terminal UI/search/selection capabilities.

The final workflow should provide two commands:

```bash
gwt
gb
```

Where:

- `gwt` = Worktree Manager
- `gb` = Branch Manager

Do NOT replace the existing `ns` concept with another UI framework unless the current environment proves that `ns` cannot support a required feature.

---

# 1. First: inspect the existing environment

Before changing anything:

1. Inspect the current `ns` installation and determine exactly how it is used.
2. Inspect the existing `gwt` implementation.
3. Inspect the existing shell configuration / aliases / functions.
4. Inspect the Git environment.
5. Determine whether GitHub CLI (`gh`) is installed.
6. Determine whether GitLab CLI or another provider is configured.
7. Detect the current shell (`bash`, `zsh`, etc.).
8. Inspect the repository root and Git configuration.
9. Reuse existing functionality where possible instead of rewriting working code.

Do not blindly overwrite the current `gwt`.

Create a migration/refactoring plan first.

---

# 2. Core commands

Implement:

```bash
gwt
```

and:

```bash
gb
```

They must work from any directory inside a Git repository.

For example:

```bash
cd ~/projects/my-app/src/features/auth
gwt
```

must resolve the repository root using:

```bash
git rev-parse --show-toplevel
```

The tool must operate against the detected repository root, not the current subdirectory.

If the current directory is not inside a Git repository:

```text
Not a Git repository.
```

Exit cleanly.

---

# 3. `gwt` — Worktree Manager

The `gwt` interface must provide:

```text
Worktrees
Create
Create detached
Pull Requests
Issues
Commits
Tags
Remove
Refresh
Repository information
```

Suggested navigation:

```text
╭──────────────────── Worktree Manager ─────────────────────╮
│ Repository: my-project                                    │
│ Branch: main                                              │
│                                                          │
│  Worktrees                                                │
│                                                          │
│  ● main             ~/projects/my-project                │
│    feature/auth     ~/projects/my-project-auth           │
│    feature/payment  ~/projects/my-project-payment        │
│    PR #142          ~/projects/my-project-pr-142         │
│                                                          │
│  [Enter] Open                                             │
│  [n] New Worktree                                         │
│  [d] Detached                                             │
│  [p] Pull Request                                         │
│  [i] Issue                                                │
│  [c] Commit                                               │
│  [t] Tag                                                  │
│  [r] Remove                                               │
│  [R] Refresh                                              │
│  [q] Quit                                                 │
╰──────────────────────────────────────────────────────────╯
```

Do not copy this exact visual layout if `ns` has a better native interaction model.

The important requirement is the interaction model, not the exact ASCII layout.

---

# 4. Create worktree

Support creating a worktree from:

```text
Branch
Pull Request
Issue
Commit
Tag
```

Example:

```text
Create Worktree

Source:

  Branch
  Pull Request
  Issue
  Commit
  Tag
```

For a branch:

```bash
git worktree add ../project-feature-auth feature/auth
```

Validate:

- branch exists
- destination does not conflict
- branch is not already checked out in another worktree
- destination path is valid

---

# 5. Detached worktree

This is an important feature.

Support:

```bash
git worktree add --detach ../project-pr-test 8f31abc
```

The user must be able to select:

```text
Commit
Pull Request commit
Tag
```

and create a detached worktree.

Example:

```text
Create Detached Worktree

Source:
  8f31abc

Commit:
  fix: authentication redirect

Destination:
  ../project-pr-test

Type:
  Detached HEAD

[Cancel] [Create]
```

After creation, clearly display:

```text
Detached worktree created.

Commit: 8f31abc
Path: ../project-pr-test
```

Never pretend that a detached worktree belongs to a branch.

---

# 6. Pull Request integration

Automatically detect the repository provider from Git configuration.

For GitHub, prefer GitHub CLI if available:

```bash
gh
```

Detect repository information from:

```bash
git remote get-url origin
```

Support:

```text
List PRs
Search PRs
View PR
Create PR
Create worktree from PR
Test PR commit in detached mode
```

Example:

```text
Pull Requests

  #142  feat: authentication
  #139  fix: login redirect
  #137  refactor: user service
```

Selecting a PR should provide:

```text
PR #142

Title:
feat: authentication

Branch:
feature/auth

Base:
main

Author:
...

Status:
OPEN

Actions:

  Create worktree
  Create detached worktree
  Open
  Create local branch
```

For PR testing, support creating a detached worktree from the PR head commit.

Do not create unnecessary local branches.

---

# 7. Issue integration

Support listing issues when the repository provider supports them.

Example:

```text
Issues

  #231  Implement OAuth
  #228  Improve dashboard
  #219  Fix sidebar animation
```

Selecting an issue:

```text
Issue #231

Title:
Implement OAuth

Actions:

  Create branch + worktree
  Create worktree
```

Suggested branch name:

```text
feature/231-implement-oauth
```

But branch naming must be configurable.

Never silently create a branch without showing the intended branch/path first.

---

# 8. Tags

Support:

```bash
git tag
```

Display tags through the UI.

Allow:

```text
Tag
 ↓
Create detached worktree
```

Example:

```bash
git worktree add --detach ../project-v2.4.0 v2.4.0
```

---

# 9. Commits

Allow searching/selecting commits.

Useful information:

```text
SHA
short SHA
author
date
subject
refs
```

Example:

```text
8f31abc  fix: authentication redirect
a82d911  feat: dashboard redesign
2d91a22  refactor: user service
```

Allow:

```text
Commit
 ↓
Create detached worktree
```

---

# 10. `gb` — Branch Manager

`gb` must provide a powerful branch management interface.

Views/filters:

```text
All
Merged
Not merged
Current
Remote
With changes
Historical
```

Example:

```text
feature/auth       not merged    +7 commits    +5 files
feature/payment    not merged    +8 commits    +12 files
feature/navbar     merged
fix/login          not merged    +2 commits    +2 files
```

Support:

- search
- sorting
- filtering
- multi-selection
- branch details
- branch deletion
- worktree creation
- PR creation
- refresh

---

# 11. Branch status

For each branch, calculate useful information.

Possible metadata:

```text
Current
Merged
Not merged
Ahead
Behind
Ahead/behind
Changed files
Added lines
Deleted lines
Upstream
Remote
Associated PR
Associated worktree
Last commit
Last activity
```

For example:

```text
feature/auth

Status:
  NOT MERGED

Commits:
  +7

Files:
  +5

Diff:
  +382
  -91

Upstream:
  origin/feature/auth

Worktree:
  ../project-auth

PR:
  #142 OPEN
```

Do not run expensive Git commands for every branch unnecessarily.

Use caching and batch operations where practical.

---

# 12. Multi-selection

`gb` must support selecting multiple branches.

Example:

```text
☑ feature/auth
☑ feature/payment
☐ feature/navbar
☐ fix/login
```

Selected branches can be used for:

```text
Delete branches
Create worktrees
Create PRs
```

Before executing a bulk operation, show the complete affected set.

Never silently execute destructive bulk operations.

---

# 13. Branch deletion safety

Use:

```bash
git branch -d <branch>
```

by default.

Do NOT use:

```bash
git branch -D <branch>
```

automatically.

Before deletion, determine:

```text
Is current branch?
Is merged?
Is checked out by a worktree?
Has unmerged commits?
Has remote tracking?
Is protected?
```

Protected branches should include configurable defaults such as:

```text
main
master
develop
```

but protection must be configurable.

Example:

```text
Delete 2 branches?

  feature/auth       merged
  feature/payment    NOT MERGED ⚠

Commands:

  git branch -d feature/auth
  git branch -d feature/payment

[Cancel] [Delete]
```

If Git refuses the deletion, report the actual Git error.

Do not automatically force-delete.

---

# 14. Worktree deletion safety

Use:

```bash
git worktree remove <path>
```

Do NOT implement worktree deletion using:

```bash
rm -rf
```

Before removal:

```text
Check:
- worktree exists
- dirty files
- staged files
- untracked files
- current worktree
```

If dirty:

```text
⚠ Worktree contains changes.

Path:
../project-auth

Modified:
5 files

Untracked:
2 files

[Cancel] [Remove anyway]
```

Never silently delete dirty worktrees.

---

# 15. Never use unsafe shell execution

This is a critical requirement.

Do NOT build commands like:

```bash
eval "$USER_INPUT"
```

Do NOT interpolate arbitrary user input into shell commands.

Instead:

```text
UI selection
    ↓
validated value
    ↓
structured command arguments
    ↓
Git process execution
```

Prefer safe argument passing using arrays / direct process execution according to the implementation language.

Never allow branch names, paths, PR titles, issue titles, commit messages, or search input to become arbitrary shell code.

---

# 16. Preview before mutation

All important mutations should support a preview.

Before:

```text
Create
Remove
Delete
Create branch
Create PR
Fetch
```

show the operation.

Example:

```text
Action

Create detached worktree

Command:

git worktree add --detach \
  ../project-pr-142 \
  8f31abc

[Cancel] [Execute]
```

This is especially important for destructive operations.

---

# 17. Git commands must be isolated

The UI must NOT directly contain Git implementation logic.

Use an architecture similar to:

```text
UI
 ↓
Use Case
 ↓
Git Service
 ↓
Command Executor
 ↓
Git CLI
```

For remote providers:

```text
UI
 ↓
Use Case
 ↓
Provider abstraction
 ├── GitHub
 ├── GitLab
 └── ...
```

Example interfaces/concepts:

```text
GitRepository
GitBranchService
GitWorktreeService
GitCommitService
GitTagService
PullRequestProvider
IssueProvider
CommandExecutor
RepositoryContext
```

Do not create one giant script/class containing everything.

Use one clear responsibility per module/file.

---

# 18. Provider detection

Detect provider from:

```bash
git remote get-url origin
```

Examples:

```text
github.com
gitlab.com
bitbucket.org
```

The local Git functionality must work independently of the remote provider.

The tool must still be useful without network access.

---

# 19. Refresh model

The UI must support explicit refresh.

Example:

```text
[R] Refresh
```

Refresh should update:

```text
branches
worktrees
commits
tags
PRs
issues
```

Do not continuously hammer Git or remote APIs.

Remote data should use sensible caching/debouncing.

---

# 20. Error handling

Never hide Git errors.

Bad:

```text
Operation failed.
```

Good:

```text
Failed to remove worktree.

Git returned:

fatal: '/path/project-auth' contains modified or untracked files

[Back]
```

Exit codes must be preserved where appropriate.

The UI should recover cleanly after failed operations.

---

# 21. Power-user keyboard workflow

Optimize for keyboard usage.

The interface should support concepts such as:

```text
↑ ↓       Navigate
Enter     Open
Space     Select
/         Search
f         Filter
r         Refresh
n         New
d         Detached
w         Worktree
p         Pull Request
i         Issue
c         Commit
t         Tag
x         Delete
q         Quit
Esc       Back
```

Do not require mouse interaction.

If `ns` provides native fuzzy search/multi-select, use it.

---

# 22. Search

Search must be fast.

For branches:

```text
/auth
```

should match:

```text
feature/auth
feature/oauth
fix/authentication
```

For commits:

```text
authentication
```

should search useful commit metadata.

For PRs/issues:

```text
oauth
```

should search titles and relevant metadata.

Use native `ns` fuzzy-search capabilities where appropriate.

---

# 23. Configuration

Do not hardcode everything.

Provide a configuration mechanism for:

```text
protected branches
default base branch
worktree directory pattern
branch naming convention
provider
default actions
confirmation behavior
```

Example conceptual configuration:

```text
default_base_branch = main

protected_branches =
  main
  master
  develop

worktree_pattern = ../{repo}-{branch}

issue_branch_pattern = feature/{issue}-{slug}
```

Use existing Git configuration where appropriate.

Do not create unnecessary global configuration if repository-local Git configuration can solve the problem.

---

# 24. Worktree path handling

Be careful with:

```text
spaces
special characters
relative paths
absolute paths
existing directories
symlinks
```

Normalize paths safely.

Never blindly delete a directory because it "looks like" a worktree.

Use Git's worktree metadata to determine ownership.

---

# 25. Environment files and dependencies

Do NOT assume that:

```text
git worktree add
```

copies:

```text
.env
node_modules
untracked files
local configuration
```

It does not magically reproduce the entire development environment.

The manager should clearly distinguish:

```text
Git worktree creation
```

from:

```text
Application environment setup
```

Do not automatically copy secrets.

If an optional environment bootstrap is implemented later, make it explicit and configurable.

---

# 26. No destructive behavior by default

Default philosophy:

```text
READ  → automatic
CREATE → confirmation
MODIFY → confirmation
DELETE → strong confirmation
FORCE DELETE → explicit opt-in
```

Never:

```text
rm -rf
git reset --hard
git clean -fd
git branch -D
```

without explicit user action and a clear warning.

These commands must not be introduced merely for convenience.

---

# 27. Performance

This tool will be used frequently.

Avoid:

```text
N branches
×
N separate expensive Git commands
```

where a single Git operation can provide the required information.

Prefer:

```text
batch Git queries
caching
lazy loading
async remote requests
```

Remote PR/Issue data should be lazy-loaded where appropriate.

The UI must remain responsive.

---

# 28. Existing `gwt` migration

There is already an existing `gwt` workflow.

Do not destroy it immediately.

First:

1. inspect it
2. understand it
3. identify reusable code
4. design the new interface
5. migrate functionality
6. verify behavior
7. replace the old entry point only after validation

Keep rollback easy.

---

# 29. Testing

Add tests for critical operations.

At minimum test:

```text
Repository detection
Branch detection
Merged status
Worktree detection
Detached worktree creation
Branch deletion protection
Dirty worktree detection
Path validation
Provider detection
Command construction
```

For destructive operations, use temporary Git repositories in tests.

Do NOT run destructive tests against the user's real repository.

---

# 30. Implementation strategy

Do not implement everything in one huge change.

Work in phases.

## Phase 1

Build:

```text
gwt
 ├── list worktrees
 ├── create worktree
 ├── detached worktree
 └── remove worktree

gb
 ├── list branches
 ├── search
 ├── merged/not-merged
 ├── branch details
 └── safe delete
```

## Phase 2

Add:

```text
commits
tags
multi-select
bulk operations
```

## Phase 3

Add:

```text
GitHub PRs
GitHub Issues
PR → worktree
Issue → branch/worktree
```

## Phase 4

Add:

```text
provider abstraction
GitLab
advanced configuration
caching
performance improvements
```

Do not move to the next phase until the previous phase works.

---

# 31. Definition of done

The implementation is complete only when:

- `gwt` launches the new TUI.
- `gb` launches the branch manager.
- Both work from any directory inside a Git repository.
- Existing worktrees are detected correctly.
- Branch status is accurate.
- Detached worktrees can be created from commit SHA.
- Worktrees can be safely removed.
- Branches can be multi-selected.
- Branch deletion is protected.
- Dirty worktrees are detected.
- PRs can be detected when a supported provider is configured.
- Issues can be detected when supported.
- PR/Issue/Commit/Tag → worktree workflows work.
- No arbitrary shell evaluation is used.
- No destructive command runs without explicit confirmation.
- The existing `gwt` functionality is preserved or intentionally migrated.
- The codebase is modular and maintainable.
- No giant monolithic script/class is introduced.
- Errors are visible and actionable.
- Tests cover the dangerous Git operations.

---

# Final instruction to Codex

Act as a senior software engineer and terminal-tool architect.

Do not rush directly into implementation.

First inspect the existing `ns` and `gwt` setup and repository environment.

Then:

1. Explain the current architecture.
2. Identify what can be reused.
3. Propose the target architecture.
4. Identify risks and compatibility concerns.
5. Implement Phase 1.
6. Test it using isolated temporary Git repositories.
7. Show exactly what changed.
8. Do not modify unrelated shell configuration or projects.
9. Do not delete the existing implementation until the replacement is verified.
10. Keep the implementation clean, modular, testable, and suitable for long-term daily use by a senior developer.

The priority order is:

```text
Safety
>
Correct Git behavior
>
UX / keyboard workflow
>
Performance
>
Remote integrations
>
Convenience
```

Never sacrifice Git safety for UI convenience.