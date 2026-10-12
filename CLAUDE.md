# Branches: RC before the principals

Two **principal** branches (do not push work straight to them):

- `main` — English (worktree `godot-studio-skills-en`)
- `release/spanish` — Spanish (worktree `godot-studio-skills`)

Fixed order:

1. Implement on a pair of **RC** branches, not on the principals.
2. Name them `rc/vX.Y.Z` (from `main`) and `rc/vX.Y.Z-spanish` (from `release/spanish`). X.Y.Z = next kit version (latest tag `v0.6.0` → next `v0.7.0`). A second candidate: `rc/vX.Y.Z-rc.2` / `rc/vX.Y.Z-rc.2-spanish`.
3. Commit + push **only** to those RCs.
4. Merge / push to `main` and `release/spanish` **only** after the user accepts the RC.

Keep the ES/EN mirror on the same cut. Do not land on the principals “to get ahead”.

## Kit

Skills in `skills/`, commands in `commands/`, subagents in `agents/`: the same files install into Claude Code (`./install.sh --claude`) and Cursor (`./install.sh`). Do not write instructions that only hold in one harness without naming the other’s equivalent. A read-only subagent carries `readonly: true` (Cursor) **and** `disallowedTools` (Claude Code).

This rule also lives in `.cursor/rules/release-candidate.mdc`; change both.
