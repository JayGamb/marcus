# CLAUDE.md — MRCS

This repo **is** the Marcus agent framework. Working here means editing the rules the other projects run on — a change lands everywhere the next time `scripts/install.sh` runs.

## Standing rules — a template, not the owner's file

The `CLAUDE.md` in `~/.claude/` is **the owner's own file**: personal, never shipped, never written by this repo. `scripts/install.sh` does not copy to it and `scripts/diff.sh` does not compare against it — the "in sync" verdict covers `agents/` and `skills/` only.

What the plugin ships is `skills/marcus/templates/standing-rules.md` (installed with the skill, to `~/.claude/skills/marcus/templates/`): the same cross-project rules with the identity reduced to placeholders. `/marcus init` §6 offers to fill them from `marcus.config.json` and **append** the block; the owner can also do it by hand. Edit the rules there, and keep the owner's live file the owner's business.

## Working here

- The live copies in `~/.claude/` are what actually runs. This repo is the versioned source.
- Edit live → `scripts/pull.sh` → review `git diff` → commit. Or edit here → `scripts/install.sh`.
- **Always run `scripts/diff.sh` before committing.** A commit that does not match the live setup is a lie about what runs.
- Never bulk-regex across the agent files. Six of them share a structure, and a sloppy pattern duplicated all six once already. Targeted edits, assert the line delta before writing.

## Hard rules

- Agents commit **locally only**, under the owner's git identity, no AI trailer. Never push, PR, merge, or apply prod. The owner owns the remote.
- Changing a guardrail (`hooks/`, the arming sentinel, the forbidden lists) is the owner's decision, never a convenience edit.
- **`marcus.config.json` is owner-only.** `block-dangerous-git.sh` reads `branches.production` from it, so editing it edits a guardrail. Agents never touch it.
- Document mentioning `git push` and friends: write it with the Write tool. A shell heredoc containing those strings trips the PreToolUse hook.

## Structure

`docs/WORKFLOW.md` is the report — the whole system. `docs/handoffs/` is session state. `skills/` and `agents/` are what `scripts/install.sh` copies into `~/.claude/` — including `skills/marcus/templates/standing-rules.md`, which rides along with the skill. `hooks/` is per-project, copied into each repo and **declared in that repo's `.claude/settings.json`**, or it never runs.
