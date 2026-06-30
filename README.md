# MultiAgentPrivateRulesSync

Public MIT example layout for a private markdown rule vault used with MultiAgentCrossReview RuleSync.

This repository is an example/template only. Real personal preferences and project-private rules should live in a user-owned private repository with this shape.

## Layout

```text
MultiAgentPrivateRulesSync/
├─ README.md
├─ LICENSE
├─ .gitignore
├─ UserSettings/
│  ├─ preferences.md
│  ├─ session.md
│  └─ machines/
│     └─ EXAMPLE-HOST.md
└─ Projects/
   └─ ExampleProject/
      └─ RULES.md
```

## Use With RuleSync

In the public MultiAgentCrossReview workbench:

```powershell
Copy-Item .\Packages\RuleSync\rulesync.config.example.psd1 .\Packages\RuleSync\rulesync.config.psd1
```

Set the private vault path in the ignored local config:

```powershell
@{
    VaultRoot = 'D:\Private\MyRulesVault'
    WorktreeRoot = ''
}
```

Pull private rules into the workbench:

```powershell
.\Packages\RuleSync\rulesync.ps1 -Direction Pull
```

Push workbench rule changes back to the private vault:

```powershell
.\Packages\RuleSync\rulesync.ps1 -Direction Push
```

## SSOT

The private rules vault is the SSOT for private markdown rules. The public workbench only carries the sync engine, templates, and examples.

## Not Synced

Do not store these in a rules vault:

```text
Projects/<name>/baseline/**
Projects/<name>/edit/**
secrets/tokens/databases/session JSONL
```