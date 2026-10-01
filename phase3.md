# Task: Upgrade Git Worktree Manager — Safe Bootstrap + Bulk Workflows + Modern TUI

We already have a functional Git Worktree/Branch TUI based on fzf.

Do NOT rewrite the application from scratch.

First:

1. Inspect the existing implementation completely.

2. Identify current worktree lifecycle, branch lifecycle, TUI rendering, fzf bindings, Git executor, configuration, and tests.

3. Reuse existing abstractions where possible.

4. Do not duplicate Git logic or create another parallel implementation.

5. Keep the architecture modular and maintainable.

The implementation must prioritize:

1. Git safety

2. Data integrity

3. Explicit mutation boundaries

4. Backward compatibility

5. Clear terminal UX

6. Performance

7. Convenience

The existing application is already working, but the current workflow and UI need to be upgraded.

---

# 1. WORKTREE CREATION WORKFLOW

Implement a complete post-creation bootstrap workflow.

Desired workflow:

Create Worktree

    ↓

Create branch/worktree

    ↓

Copy allowed environment files

    ↓

Install dependencies with the detected package manager

    ↓

Verify bootstrap

    ↓

Show final result

The workflow must be transactional in spirit:

- Do not silently mutate unrelated files.

- Do not silently modify Git history.

- Do not rewrite lockfiles.

- Capture every command, exit code, stdout/stderr.

- If a post-create step fails, keep the worktree intact and clearly report what failed.

- Never delete a partially initialized worktree automatically unless explicitly configured.

- Never use `rm -rf` to remove a worktree.

- Use `git worktree remove` for worktree removal.

---

# 2. SOURCE OF ENVIRONMENT FILES

Important distinction:

The source is NOT "the main branch commit".

The source is the PRIMARY WORKTREE / MAIN WORKING DIRECTORY.

Example:

Primary worktree:

    /home/user/project

New worktree:

    /home/user/worktrees/feature-auth

Copy environment files from:

    /home/user/project

to:

    /home/user/worktrees/feature-auth

This must remain true even when the primary worktree is dirty.

Example current state:

    main

    modified: 23

    untracked: 15

This must NOT prevent creating another worktree.

However, the manager must NEVER copy arbitrary files from the primary worktree.

Use an explicit configurable allowlist.

Recommended default patterns:

    .env

    .env.local

    .env.development

    .env.development.local

Do NOT automatically copy:

    .env.production

    .env.production.local

unless explicitly configured.

Do NOT use a dangerous wildcard such as:

    cp -r .env\*

without validating the resulting file list.

Only copy regular files.

Do not follow symbolic links outside the source worktree.

Prevent path traversal.

Never overwrite an existing target file silently.

If a target environment file already exists:

    - report it

    - skip it by default

    - only overwrite after explicit confirmation

The UI should show exactly which environment files are going to be copied before mutation.

Example preview:

Environment bootstrap

Source:

  /home/user/project

Files:

  ✓ .env

  ✓ .env.local

  ✓ .env.development

Skipped:

  - .env.production (not allowed by default)

Action:

  Copy 3 files

---

# 3. DEPENDENCY INSTALLATION

Dependency installation must be deterministic.

Do NOT blindly execute:

    pnpm install

For pnpm projects use:

    pnpm install --frozen-lockfile

The frozen installation must not modify pnpm-lock.yaml.

If the project defines a package manager in package.json, inspect it.

Also detect lockfiles:

    pnpm-lock.yaml

    package-lock.json

    yarn.lock

    bun.lock

    bun.lockb

Recommended mapping:

    pnpm-lock.yaml

        → pnpm install --frozen-lockfile

    package-lock.json

        → npm ci

    yarn.lock

        → yarn install --immutable

    bun.lock / bun.lockb

        → bun install --frozen-lockfile

Do not guess if multiple package-manager lockfiles exist.

If conflicting lockfiles are detected:

    package.json

    + pnpm-lock.yaml

    + package-lock.json

show a clear warning and require an explicit choice or use the project's configured package manager.

Prefer the packageManager field from package.json when present.

Do not automatically upgrade pnpm, npm, yarn, or bun.

Do not modify package.json.

Do not modify lockfiles.

If frozen installation fails because the manifest and lockfile are inconsistent:

    stop bootstrap

    preserve the worktree

    show the exact failure

    tell the user that the lockfile is not compatible with the selected revision

Do NOT automatically run a non-frozen install as fallback.

---

# 4. WORKTREE CREATION MODES

Support these explicit modes.

## Mode A — New branch + worktree

Example:

    git worktree add -b feature/auth ../feature-auth main

Then:

    copy allowed env files

    install dependencies

    verify

This is the default workflow.

---

## Mode B — Detached worktree

Example:

    git worktree add --detach ../commit-test &lt;ref&gt;

Then:

    copy allowed env files

    install dependencies

    verify

This is intended for:

    commits

    PR commits

    tags

    release points

    arbitrary refs

---

## Mode C — Multiple worktrees, one branch each

Allow multi-select.

Example:

    \[x\] feature/auth

    \[x\] feature/payments

    \[x\] feature/profile

Create:

    worktree-auth     → feature/auth

    worktree-payments → feature/payments

    worktree-profile  → feature/profile

Every worktree gets its own branch.

Each worktree must have an independently valid Git branch association.

---

## Mode D — Multiple detached worktrees from the same ref

Example:

    ref = abc123

Create:

    test-1 → detached abc123

    test-2 → detached abc123

    test-3 → detached abc123

This is valid because these worktrees do not attempt to check out the same branch.

The UI must explicitly distinguish:

    Branch worktree

    Detached worktree

---

## IMPORTANT GIT CONSTRAINT

Never allow the same branch to be checked out simultaneously in multiple normal worktrees.

For example, do NOT attempt:

    worktree-a → feature/auth

    worktree-b → feature/auth

as ordinary branch checkouts.

Git normally prevents this.

If the user wants multiple copies of identical code, offer:

    detached worktrees

or:

    one branch per worktree

Do not bypass Git's worktree safety mechanisms.

---

# 5. PR / ISSUE / TAG / COMMIT WORKTREE CREATION

The existing manager should support:

    PR

    Issue

    Tag

    Commit

    Branch

    Detached ref

The workflow must converge into the same worktree creation pipeline.

Do NOT create separate duplicated bootstrap logic for PRs, issues, tags, and commits.

Architecture:

    Selection

        ↓

    Worktree Creation Request

        ↓

    Git Worktree Service

        ↓

    Environment Bootstrap

        ↓

    Dependency Bootstrap

        ↓

    Verification

        ↓

    UI Result

PR:

    select PR

      ↓

    select/create branch mode

      ↓

    create worktree

      ↓

    bootstrap

Issue:

    select issue

      ↓

    generate branch name

      ↓

    allow user to edit

      ↓

    create worktree

      ↓

    bootstrap

Tag:

    select tag

      ↓

    detached worktree

      ↓

    bootstrap

Commit:

    select commit

      ↓

    detached worktree

      ↓

    bootstrap

---

# 6. HISTORICAL BRANCH MANAGEMENT

Add a dedicated historical branch workflow.

The user must be able to:

    search branches

    fuzzy filter

    multi-select

    inspect details

    bulk delete

Example:

    Historical Branches

    \[x\] feature/auth

    \[x\] fix/payment-timeout

    \[ \] feature/dashboard

    \[x\] chore/cleanup

Selected: 3

Actions:

    Enter  Details

    TAB    Select

    d      Delete selected

    r      Refresh

    ESC    Back

Deletion must be safe.

Default:

    git branch -d &lt;branch&gt;

Never use:

    git branch -D

without explicit user confirmation.

If a branch is unmerged:

    branch feature/auth is not fully merged

Then require explicit confirmation before force deletion.

Protected branches must never be deletable.

Default protected branches:

    main

    master

    develop

    trunk

Make this configurable.

Never delete:

    current branch

Never delete a branch currently associated with another worktree.

Before deletion, show a preview:

    Delete 3 branches?

    feature/auth

    feature/profile

    chore/cleanup

    2 merged

    1 unmerged

    \[Cancel\]

    \[Delete merged only\]

    \[Force delete all\]

Do not make destructive behavior implicit.

---

# 7. UI REDESIGN

The current UI is functional but too classic and information is being hidden/truncated.

Current issues visible in the existing UI:

- command hints are compressed into one line

- text is truncated

- paths are truncated

- status information is dense

- the header consumes space without providing enough hierarchy

- the preview panel is visually overloaded

- keyboard actions are difficult to scan

- important information disappears when the terminal width changes

Redesign the terminal UI to behave like a modern developer TUI.

Do NOT add unnecessary visual decoration.

The goal is clarity, hierarchy, density, and adaptive layout.

---

# 8. RESPONSIVE TERMINAL LAYOUT

The interface must adapt to terminal width.

Never intentionally hide important information.

Detect terminal dimensions.

Define at least these layout modes:

## Wide

Example:

    ┌─────────────────────────────────────────────────────────────┬──────────────────────────────┐

    │ Worktrees                                                   │ Details                      │

    │                                                             │                              │

    │ main       clean      \~/project                             │ Recent commits               │

    │ feature/a  dirty      \~/project-a                           │ Status                       │

    │ feature/b  clean      \~/project-b                           │ Diff                         │

    └─────────────────────────────────────────────────────────────┴──────────────────────────────┘

Use a two-pane layout.

---

## Medium

Reduce secondary columns.

Keep:

    branch

    status

    type

    path

Move detailed information into preview.

---

## Narrow

Automatically switch to a single-pane layout.

Do NOT let columns silently disappear.

Example:

    WORKTREES

    ● main

      clean

      \~/project

    ○ feature/auth

      dirty

      \~/project-auth

Selected worktree:

    Branch: feature/auth

    Type: branch

    Status: dirty

    Path: \~/project-auth

Use a secondary detail screen/panel instead of destroying information.

---

# 9. HEADER DESIGN

Replace the current dense one-line header.

Current style:

    Repo: ... | Current: ... | Worktrees: ...

    Enter=Open | n=New | p=PR | i=Issue | ...

This becomes unreadable on smaller terminals.

Create clear semantic zones:

    ┌──────────────────────────────────────────────────────────────┐

    │ GWT  ·  Worktree Manager                                    │

    │ gestion-benevole  ·  main  ·  1 worktree                   │

    ├──────────────────────────────────────────────────────────────┤

    │ Search: \_                                                    │

    └──────────────────────────────────────────────────────────────┘

Then put actions into a dedicated footer.

---

# 10. KEYBOARD HELP

Do not place every shortcut inside the header.

Use contextual footer help.

Example:

    ↑↓ Navigate   TAB Select   Enter Details   n New   p PR

    i Issue       c Commit     t Tag            m Multi

    r Refresh     d Delete     q Quit

On narrow terminals:

    ↑↓ Move   TAB Select   Enter Details   ? Help   q Quit

Provide a dedicated help screen/dialog with:

    ?

The help screen should list all commands grouped by context.

Example:

    NAVIGATION

      ↑ ↓       Navigate

      TAB       Select

      Enter     Open details

      Esc       Back

    CREATION

      n         New worktree

      p         Pull request

      i         Issue

      c         Commit

      t         Tag

      d         Detached

    MANAGEMENT

      m         Multi-select

      r         Refresh

      x         Remove

Do not overload the main screen.

---

# 11. TEXT MUST NEVER BE SILENTLY LOST

Current UI truncates information.

Improve truncation behavior.

For paths:

    \~/project/worktrees/feature-authentication

If width is insufficient, intelligently truncate:

    \~/project/.../feature-authentication

Prefer preserving the filename/branch suffix.

For long commit messages:

    preserve the beginning and meaningful subject

For branch names:

    preserve both prefix and meaningful suffix where possible

Do not blindly render:

    feature/authentication-ti...

if the important differentiating part is hidden.

Use a details view when full text cannot fit.

---

# 12. WORKTREE STATUS DISPLAY

Make the status more readable.

Instead of:

    main  4445135 dirty (mod:23, untracked:15) ↑0 ↓0

Prefer:

    ● main

      4445135

      dirty

      23 modified · 15 untracked

      ↑0 ↓0

      \~/project

Or in wide mode:

    ● main   dirty   23 modified · 15 untracked   ↑0 ↓0   \~/project

The status should be visually scannable.

Also distinguish:

    clean

    dirty

    detached

    locked

    prunable

    unavailable

Do not rely only on color.

Use symbols/text so the TUI remains understandable without color.

---

# 13. PREVIEW PANEL

The preview panel should have sections.

Example:

    WORKTREE

    feature/auth

    REPOSITORY

    branch: feature/auth

    commit: 4445135

    type: branch

    STATUS

    3 modified

    1 untracked

    RECENT COMMITS

    4445135 Fix authentication

    198fac9 Improve login flow

    ...

    PATH

    \~/project-feature-auth

Avoid dumping raw terminal output into the panel.

Format information semantically.

---

# 14. ACTION CONFIRMATION UX

For potentially destructive or expensive operations:

    delete

    force delete

    install dependencies

    overwrite env files

    remove dirty worktree

show explicit confirmation.

For safe non-destructive operations:

    inspect

    navigate

    search

    preview

do not add unnecessary confirmation steps.

---

# 15. BOOTSTRAP PROGRESS UI

When creating a worktree, show a progress state.

Example:

    Create Worktree

    ✓ Git worktree created

    ✓ Environment files copied

    ◐ Installing dependencies

      pnpm install --frozen-lockfile

    Worktree:

      \~/project-feature-auth

Do not freeze the whole UI without feedback.

Capture command status.

After completion:

    ✓ Worktree ready

    Branch:

      feature/auth

    Path:

      \~/project-feature-auth

    Environment:

      3 files copied

    Dependencies:

      pnpm install --frozen-lockfile

If installation fails:

    ✗ Dependency installation failed

    Command:

      pnpm install --frozen-lockfile

    Reason:

      lockfile is out of sync with package.json

    Worktree was preserved.

---

# 16. SECURITY REQUIREMENTS

This task modifies filesystem and Git state.

Treat all user-controlled values as untrusted.

Never use:

    eval

Never construct arbitrary shell commands by interpolating uncontrolled strings.

Prefer structured argument arrays / safe command execution.

Validate:

    repository paths

    branch names

    refs

    worktree paths

    PR numbers

    issue numbers

    tag names

    commit SHAs

Do not execute arbitrary content from branch names or commit messages.

Never copy arbitrary files based on unsanitized glob expansion.

Never follow environment-file symlinks outside the source worktree.

Do not expose secret environment values in the TUI.

Show filenames only, never their contents.

Never automatically force-delete Git data.

---

# 17. CONFIGURATION

Add or extend configuration for:

    default\_base\_branch

    worktree\_directory

    protected\_branches

    env\_copy\_enabled

    env\_copy\_patterns

    package\_manager

    auto\_install\_dependencies

    install\_command

    confirmation\_mode

    ui\_preview\_enabled

    ui\_layout\_mode

Example:

    env\_copy\_enabled=true

    env\_copy\_patterns=(

      ".env"

      ".env.local"

      ".env.development"

      ".env.development.local"

    )

    auto\_install\_dependencies=true

    package\_manager=auto

    default\_base\_branch=main

Do not hard-code personal paths.

---

# 18. PERFORMANCE

Do not execute expensive commands on every keystroke.

Cache where appropriate:

    git branch

    git worktree

    git status

    GitHub PR/Issue data

Refresh explicitly or on meaningful state changes.

Do not call GitHub APIs repeatedly while the user is simply typing a search query.

For PR/Issue lists:

    fetch once

    cache result

    filter locally

until an explicit refresh.

---

# 19. ARCHITECTURE

Respect the existing architecture.

Prefer:

    UI

      ↓

    Use Case

      ↓

    Service

      ↓

    Git / GitHub Adapter

      ↓

    Executor

Separate responsibilities.

Examples:

    worktree\_create\_service

    worktree\_bootstrap\_service

    env\_copy\_service

    dependency\_install\_service

    branch\_delete\_service

    package\_manager\_detector

    terminal\_layout

    tui\_footer

    tui\_help

    tui\_preview

Do not create a giant TUI file.

Do not put Git commands directly into rendering code.

Do not put filesystem mutation inside fzf formatting functions.

One responsibility per module.

Keep files reasonably small.

---

# 20. TESTING

Add tests before declaring the implementation complete.

At minimum test:

WORKTREE

    create branch worktree

    create detached worktree

    create multiple branch worktrees

    create multiple detached worktrees

    reject duplicate branch checkout

ENVIRONMENT

    copy allowed env files

    skip unapproved env files

    skip missing env files

    refuse unsafe symlink

    do not overwrite existing env file silently

    handle dirty primary worktree

DEPENDENCIES

    pnpm → frozen install

    npm → npm ci

    yarn → immutable install

    bun → frozen install

    conflicting lockfiles

    missing lockfile

    frozen install failure

    packageManager field

BRANCHES

    multi-select

    safe delete

    unmerged branch confirmation

    protected branch

    current branch

    branch used by another worktree

UI

    wide terminal

    medium terminal

    narrow terminal

    long branch name

    long path

    long commit message

    footer overflow

    preview overflow

Failure tests are mandatory.

Test both:

    successful workflow

and:

    partial failure

A failed dependency installation must not cause silent worktree deletion.

---

# 21. ACCEPTANCE CRITERIA

The implementation is complete only when all of the following are true:

[ ] New branch + worktree creation works.

[ ] New worktree can copy configured .env files from the primary worktree.

[ ] Dirty primary worktree does not block env bootstrap.

[ ] Environment copying is allowlisted and safe.

[ ] Existing env files are never silently overwritten.

[ ] pnpm uses `pnpm install --frozen-lockfile`.

[ ] Lockfiles are never modified automatically.

[ ] No non-frozen fallback occurs automatically.

[ ] Package manager detection works.

[ ] PR → worktree works.

[ ] Issue → worktree works.

[ ] Commit → detached worktree works.

[ ] Tag → detached worktree works.

[ ] Multiple branch worktrees work.

[ ] Multiple detached worktrees from the same ref work.

[ ] Same branch cannot be checked out in two worktrees.

[ ] Historical branches support fuzzy search.

[ ] Historical branches support multi-select.

[ ] Bulk deletion is safe.

[ ] Protected branches cannot be deleted.

[ ] Current/active worktrees cannot be accidentally deleted.

[ ] UI adapts to terminal width.

[ ] Important text is never silently hidden.

[ ] Header is less dense.

[ ] Keyboard help is contextual.

[ ] Preview information is structured.

[ ] Long paths and branch names remain understandable.

[ ] Progress is visible during bootstrap.

[ ] Failures are explicit and actionable.

[ ] No eval or arbitrary shell execution.

[ ] Existing functionality remains compatible.

[ ] Automated tests pass.

---

# 22. IMPLEMENTATION PROCESS

Do not start by editing everything.

First produce:

1. Current architecture summary

2. Existing files/modules involved

3. Existing worktree creation flow

4. Existing branch deletion flow

5. Existing TUI layout flow

6. Reusable components/services

7. Gaps against this specification

8. Proposed implementation phases

Then implement in small phases:

Phase 1:

    bootstrap services

    package manager detection

    frozen installation

    env copy safety

Phase 2:

    worktree creation modes

    bulk worktree creation

Phase 3:

    historical branches

    fuzzy multi-select

    safe bulk deletion

Phase 4:

    PR / Issue / Commit / Tag integration

Phase 5:

    TUI redesign

    responsive layout

    contextual footer

    help screen

    structured preview

Phase 6:

    tests

    error handling

    performance

    final hardening

After each phase:

    run tests

    inspect the actual result

    fix regressions

    report what is verified

Do not claim completion based only on compilation.

The final report must distinguish:

    implemented

    tested

    manually verified

    known limitations