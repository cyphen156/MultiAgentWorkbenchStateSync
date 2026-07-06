# examples/workbench-state

This is the **directory layout WorkbenchStateSync transports** between the workbench
worktree and your state repository via `Launchers\Start.ps1` (pull) and
`Launchers\Finish.ps1` (push). It shows *what gets synchronized*.

Unlike a synthetic skeleton, this example holds a **real, refined cross-review session**
(`Reviews/2026-07-03_MathUnitTypeDesign` — Math / unit / coordinate data-type design) so
you can see both the shape of the state and real review content.

```text
workbench-state/
  UserSettings/preferences.example.md              # personal settings (*.md)
  Projects/MultiAgentCrossReview/RULES.md          # per-project rules
  Reviews/2026-07-03_MathUnitTypeDesign/           # a real review instance
    README.md
    Claud/REVIEW.md + artifacts/*.h
    Codex/REVIEW.md
    DECISION.md
```

Full include/exclude rules are in [`../../STATE_MANIFEST.schema.md`](../../STATE_MANIFEST.schema.md).
Excluded from transport: `UserSettings/README.md`, `Reviews/README.md`, `Reviews/_TEMPLATE/`,
`Reviews/run-review.ps1`, `Projects/<name>/baseline/`, `Projects/<name>/edit/`, and any raw
session JSONL, databases, keys, or machine-local config. Real state lives in your private
state repository (the `MultiAgentWorkbenchStateVault`), not in this public template.
