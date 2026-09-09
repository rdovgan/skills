---
name: refactor
description: >-
  Refactor and code-style-clean the code that is currently uncommitted, or (if the
  working tree is clean) the code in the last commit. Behavior-preserving only.
  Use when the user asks to "refactor my changes", "clean up what I just wrote",
  "fix code style on my diff", "tidy the last commit". Detects the mybookingpal
  project (mbp, core-module, dataaccesslayer, admin-portal, revpal, supplier-api)
  and keeps its conventions.
---

# Refactor the current change

Improve the code in the **change target** without changing what it does. Scope is the
delta only: new and modified production code. Do not refactor files or methods the
change did not touch.

## 1. Locate the repo and the change target

```bash
git rev-parse --show-toplevel          # must be inside a repo
git status --porcelain
```

- **Uncommitted changes exist** (staged, unstaged, or untracked source files) → the target
  is the working tree. Hunks: `git diff HEAD -- <file>`; new files: read them whole.
- **Working tree clean** → the target is the last commit. Hunks: `git show HEAD -- <file>`,
  or `git diff HEAD~1..HEAD -- <file>`.

Keep only production sources in the project language. Drop generated code (`target/`,
`generated-sources/`), resources, and pure DTO/config unless logic lives in them. Test
files are in scope only for style/readability fixes, not behavior changes.

## 2. Detect the project

Match the repo against the table in
`~/.claude/skills/generate-unit-tests/references/project-profiles.md` for the build tool,
test command, and how to run a single test. mbp is Java 8 (`master`, flat `test/` root,
Maven wrapper broken → use IDE MCP); the rest are Java 21 (`main`, `src/test/java`).
Unknown repo: read `pom.xml` / `build.gradle` and 2-3 nearby files for the local style.

## 3. Find refactor opportunities in the delta

For each changed production file, look only at the changed and surrounding code for:

- duplicated logic introduced by the change (extract a method / constant);
- dead code, unused locals, unreachable branches left behind;
- long methods and deep nesting the change added or worsened (guard clauses, early return);
- unclear names introduced by the change;
- magic numbers / strings that belong in a constant;
- a workaround or `TODO` the change left that can be done properly now;
- obvious inefficiency (work inside a loop, repeated lookups) added by the change.

Leave anything that needs edits outside the delta as a note in the report. Do not change
public signatures, APIs, or behavior unless the user asked.

## 4. Code style

- IDE MCP available: run `mcp__idea__get_file_problems` for each changed file and fix the
  warnings that belong to the changed code; run `mcp__idea__reformat_file` to apply the
  project's formatter. Use `mcp__idea__lint_files` for a batch view.
- No IDE MCP: match the surrounding file exactly (indentation, brace style, import order,
  field/method ordering, `final` usage, Javadoc presence). Do not reformat untouched lines.

## 5. Apply, then verify behavior is unchanged

- Minimal diffs. Match surrounding style. One concern per edit.
- Compile and run the affected unit tests per the project profile:
  ```bash
  mvn -o -q test -Dtest=<AffectedTest> -DfailIfNoTests=false   # Java 21 repos
  ```
  mbp: `mcp__idea__build_project` with `filesToRebuild`, then the IDE run config.
- Max ~3 iterations to green. If a test now fails because the refactor changed behavior,
  revert that step. If the build environment itself is broken, confirm the code **compiles**
  and say plainly in the report that tests were not executed.

## 6. Report

- Project detected; change target (uncommitted / last commit); files considered.
- Refactors applied, grouped by file, one line each.
- Style/format fixes applied.
- Verification: compiled? tests run? green? — or what blocked it.
- Deferred: refactors that need changes outside the delta, with a one-line reason.

## Guardrails

- Behavior-preserving only. No feature work, no API changes, no dependency changes.
- Never widen scope beyond the change target.
- Do not delete existing tests or rewrite unrelated ones.
- Do not commit or push. That is `/commit` and `/pr`.
