---
name: pr
description: >-
  End-to-end pre-PR pass for a mybookingpal working branch: refactor the change,
  add JUnit tests, get the module build green, save a session summary, commit with
  a clean message, push, and print a filled PR description plus the Bitbucket
  create-PR link. Use when the user asks to "prep my PR", "do the PR flow",
  "get this ready to merge", "run /pr".
---

# Pre-PR pass

Runs the whole "ready for review" checklist from the handbook (Definition of Done). Does
**not** open the Bitbucket PR. It pushes the branch and hands the user a filled description
and the create-PR URL.

## 0. Pre-flight

```bash
git rev-parse --show-toplevel
git rev-parse --abbrev-ref HEAD
git status
git remote get-url origin
```

- HEAD must be a working branch, not `master` / `main` / `demo-dev` / `demo-stable`. Stop if it is.
- Branch name should be `<type>/<TICKET>/<short-description>` (or the older `feature/BP-XXX_Name`).
  Note it if it is off, but continue.
- Capture the ticket key (`[A-Z]{2,}-\d+`) and the repo name from the origin URL.
- Tell the user the plan and that step 6 pushes the branch. Proceed unless they object.

## 1. Refactor the change

Follow the `refactor` skill on the current change target (uncommitted, else last commit):
behavior-preserving refactors + code-style/format fixes on the delta only.

## 2. Add JUnit tests

Follow the `junit` skill on the same change target: cover new and modified production code,
matching the project's test conventions.

## 3. Build green

Run the module's unit tests, not just the new ones (handbook: Local testing, the PS-7891
incident).

```bash
mvn -o test            # Java 21 repos, whole module — expect Failures: 0, Errors: 0
```

mbp: Maven wrapper is broken → use `mcp__idea__build_project` + the IDE run configs.

- Red because of a real regression → fix it.
- Red because the change intentionally changed asserted behavior → update or remove those
  tests in this pass.
- Build environment itself broken → report which checks ran and which did not. Do not claim
  green.

> [!IMPORTANT]
> Do not continue to push if the module build is red and unexplained.

## 4. Session summary

Run the `/session-summary` command workflow (saves the two linked Obsidian notes, tags,
log row, rename). Use the ticket / change as the topic hint.

## 5. Commit

Follow the `commit` skill: `<TICKET> <imperative summary>`, optional body, **no Claude
attribution**. If there are already commits on the branch and only small fixup changes
remain, still make a normal new commit (handbook: push fixes as new commits, no squash).

## 6. Push

```bash
git push -u origin <branch>
```

## 7. PR description and link

- Fill in the template at `~/Downloads/docs/templates/pr-description.md` from what this pass
  did: what changed, why (ticket), `mvn -o test` result, tests added, obsolete tests
  touched, reviewer notes. **No Claude / "Generated with Claude Code" line.**
- Print the title: `<TICKET> <short summary>`.
- Print the Bitbucket create-PR URL for a **test PR to `demo-dev`**:
  ```
  https://bitbucket.org/mybookingpal/<repo>/pull-requests/new?source=<branch>&dest=demo-dev
  ```
  Remind the user: reviewers = team + any area owner they touched; the release PR to
  `master` / `main` comes later from the same branch after QA on demo-dev.

## 8. Report

One block: branch, ticket, refactor summary, tests added, build result, session-summary
note paths, commit hash, push result, PR title + description + create-PR URL.

## Guardrails

- Stop before push on: protected branch, unexplained red build, or the user objecting.
- No Claude mention in commits or the PR description.
- Does not open the PR, add reviewers, or merge. Those stay manual in Bitbucket.
