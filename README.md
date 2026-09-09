# skills

Claude Code skills I use across projects. Each skill is a directory under `skills/` with a `SKILL.md` file.

## Skills

### deslop

Cuts AI tells and verbosity from code, docs, and chat responses. It scans for a fixed list of patterns (puffery, em dashes, inline-header lists, "great question", metaphor soup, and more), rewrites them in plain language, then does a self-audit pass. The skill is marked "must always apply", so it runs on every session once installed.

See [skills/deslop/SKILL.md](skills/deslop/SKILL.md) for the full pattern list.

### consolidate

Run before ending a session. It sweeps the conversation for schemas, decisions, scope changes, and findings, then files each one in its canonical home: `plans/<topic>.md`, local `memory/kb/`, or a new ADR. Also checks that the deslop skill is loaded so what gets written stays clean.

See [skills/consolidate/SKILL.md](skills/consolidate/SKILL.md).

### prd

Writes PRDs in Operator's house style: milestone-based structure with a "Definition of done" acceptance line and post-milestone "Update" log per milestone, a "Pre-PRD action items" gate, linked ADRs, a runtime-vs-operator responsibilities split, and lean PRDs that split into siblings before they sprawl. Ships `scripts/new-prd.js` and `scripts/bootstrap-prd.js` plus templates and reference conventions. Vendored from [Yuripetusko/skills](https://github.com/Yuripetusko/skills/tree/main/skills/prd).

See [skills/prd/SKILL.md](skills/prd/SKILL.md).

### migration-safety-brakes

Hard guardrails for Liquibase migrations under `db/changelog/`. It refuses unsafe changeset work rather than helping perform it: no reading `src/main/resources/**` config or secrets, no operating outside the repo, no shelling out to apply migrations against a live DB, no editing changesets that already ran in production, no unguarded column/table drops or in-place type changes, no fake rollback blocks. Additive changesets (new tables, nullable columns, indexes) are still allowed.

See [skills/migration-safety-brakes/SKILL.md](skills/migration-safety-brakes/SKILL.md).

### refactor

Behavior-preserving refactor plus a code-style pass on the current change target: uncommitted changes, or the last commit if the working tree is clean. Scope is the delta only. Detects the mybookingpal project (mbp, core-module, dataaccesslayer, admin-portal, revpal, supplier-api), uses IntelliJ MCP for inspections and formatting, then compiles and runs the affected tests to confirm nothing changed.

See [skills/refactor/SKILL.md](skills/refactor/SKILL.md).

### junit

Writes JUnit tests for the same uncommitted / last-commit delta. Reuses the `generate-unit-tests` project profiles (test roots, frameworks, mock libraries, single-test commands) and swaps only the change-set rule.

See [skills/junit/SKILL.md](skills/junit/SKILL.md).

### commit

Stages the current changes and commits with a handbook message: `<TICKET> <imperative summary>`, ticket taken from the branch name, optional why-body. No Claude attribution. Refuses to commit on `master`, `main`, `demo-dev`, or `demo-stable`. Does not push.

See [skills/commit/SKILL.md](skills/commit/SKILL.md).

### pr

End-to-end pre-PR pass for a working branch: run `refactor`, run `junit`, get the module build green (`mvn -o test`), save a session summary, commit with a clean message, push, then print a filled PR description and the Bitbucket create-PR link. Does not open the PR. Stops before push on a protected branch or an unexplained red build.

See [skills/pr/SKILL.md](skills/pr/SKILL.md).

## Install

Point Claude Code at this directory as a skills source, or copy a skill folder into `~/.claude/skills/`:

```
git clone git@github.com:rdovgan/skills.git
cp -r skills/deslop ~/.claude/skills/
```

Claude Code loads any `~/.claude/skills/<name>/SKILL.md` on startup.

## Adding a skill

1. Create `skills/<name>/SKILL.md`.
2. Add YAML frontmatter with `name` and `description`. The description is what Claude uses to decide when the skill applies, so make it specific.
3. Write the instructions as steps or a checklist.
4. Add an entry to this README.
