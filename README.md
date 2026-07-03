# MultiAgentWorkbenchStateSync

Button-like PowerShell sync helper for user-managed MultiAgentCrossReview state.

This repository is a public MIT tool repository. It does not store your real review records, local settings, project paths, raw sessions, tokens, or machine-specific configuration.

## What It Syncs

WorkbenchStateSync copies the mutable state that should stay out of the public MultiAgentCrossReview framework repository.

Included:

```text
UserSettings/**/*.md
Projects/<name>/RULES.md
Reviews/<review-id>/**
```

Excluded:

```text
UserSettings/README.md
Reviews/README.md
Reviews/_TEMPLATE/**
Reviews/run-review.ps1
Projects/<name>/baseline/**
Projects/<name>/edit/**
*.jsonl, *.db, *.sqlite, *.key, *.pem, *.env, *.user, *.log
```

Raw Codex or Claude conversation JSONL is not WorkbenchStateSync data. Use a separate session transport tool for that.

## Repository Roles

| Repository | Role |
|---|---|
| `MultiAgentCrossReview` | Public framework: process docs, templates, review runner, examples, and package copy. |
| `MultiAgentWorkbenchStateSync` | Public sync tool: portable Start/Finish wrappers and copy rules. |
| Your state repository | User-chosen storage for real `UserSettings/`, `Projects/<name>/RULES.md`, and `Reviews/<review-id>/` records. Usually private. |

## Setup

Clone or create your state repository first:

```powershell
git clone https://github.com/<you>/<your-state-repo>.git D:\State\MultiAgentWorkbenchState
```

Copy the example config:

```powershell
Copy-Item .\workbenchstatesync.config.example.psd1 .\workbenchstatesync.config.psd1
```

Edit `workbenchstatesync.config.psd1`:

```powershell
@{
    VaultRoot = 'D:\State\MultiAgentWorkbenchState'
    WorktreeRoot = 'C:\ClaudCode Project'
}
```

`VaultRoot` is the local clone/path of your state repository. `WorktreeRoot` is the local MultiAgentCrossReview workbench. If `WorktreeRoot` is empty, the current directory is used.

## Daily Use

Pull state into the workbench:

```powershell
.\Start.ps1
```

Push state back to the state repository, commit it, and push the state repository:

```powershell
.\Finish.ps1
```

Useful variants:

```powershell
.\Start.ps1 -DryRun
.\Finish.ps1 -DryRun
.\Start.ps1 -Force
.\Finish.ps1 -NoOverwrite
.\Finish.ps1 -SkipGitPush
.\Finish.ps1 -CommitMessage 'workbench state: update desktop'
```

Lower-level copy mode:

```powershell
.\workbenchstatesync.ps1 -Direction Pull
.\workbenchstatesync.ps1 -Direction Push
```

## Example State Layout

See `examples/workbench-state/` for a tiny sanitized state repository shape:

```text
examples/workbench-state/
  UserSettings/preferences.example.md
  Projects/ExampleProject/RULES.md
  Reviews/2026-07-04_ExampleReview/
    README.md
    Claud/REVIEW.md
    Codex/REVIEW.md
    DECISION.md
```

That example shows the kind of data WorkbenchStateSync moves. Real copies of those files belong in your state repository, not in the public framework repository.

## Conflict Behavior

WorkbenchStateSync does not silently overwrite divergent destination files.

When source and destination both have a file at the same relative path with different content:

1. The destination file is copied to a timestamped `.bak-*` backup.
2. The copy is skipped unless `-Force` is supplied.
3. With `-Force`, the source file overwrites the destination after backup.

Push mode scans for common token-shaped secrets. Matching values are not printed.

## License

MIT.
