---
name: junit
description: >-
  Write JUnit tests for the code that is currently uncommitted, or (if the working
  tree is clean) the code in the last commit. Use when the user asks to "write
  junit for my changes", "cover what I just wrote with tests", "add tests for the
  last commit". Same project conventions as generate-unit-tests, but scoped to the
  uncommitted / last-commit delta instead of the whole branch.
---

# JUnit tests for the current change

This is `generate-unit-tests` with a narrower change set. Follow that skill's workflow and
project conventions in full:

- Project profiles, test roots, frameworks, mock libraries, and single-test commands:
  `~/.claude/skills/generate-unit-tests/references/project-profiles.md` and the table in
  `~/.claude/skills/generate-unit-tests/SKILL.md`.
- Steps 3-8 there (read spec if given, build the coverage checklist, study local test
  conventions, write the tests, compile/run/iterate to green, report) apply unchanged.

## The only difference: the change set

Replace "diff against the branch merge-base" with the uncommitted / last-commit rule:

```bash
git rev-parse --show-toplevel
git status --porcelain
```

- **Uncommitted changes exist** (staged, unstaged, or untracked source) → test that.
  ```bash
  git diff HEAD -- <file>        # modified production hunks
  # untracked new files: read whole
  ```
- **Working tree clean** → test the last commit.
  ```bash
  git show HEAD --stat
  git diff HEAD~1..HEAD -- <file>
  ```

Keep only production sources in the project language. Drop test files, resources, generated
code, and pure DTO/config. If the delta has no testable production change, say so instead of
inventing tests.

## Guardrails (from generate-unit-tests)

- Production code is read-only unless the user asks for a fix.
- Add methods to an existing `*Test` class when one exists; match its runner and style.
- An assertion failure that reveals a real defect → stop, report it, do not weaken the test.
- Never report tests as passing if they were not executed (mbp Maven / IDE runner can fail
  to start — then report "compiles, not executed").
- Do not commit or push.
