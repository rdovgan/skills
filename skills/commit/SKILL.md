---
name: commit
description: >-
  Stage the current changes, write a handbook-compliant commit message
  (`<TICKET> <imperative summary>`, ticket taken from the branch name), and commit.
  No Claude attribution in the message. Use when the user asks to "commit my
  changes", "commit this", "make a commit".
---

# Commit the current changes

## 1. Check where you are

```bash
git rev-parse --show-toplevel
git rev-parse --abbrev-ref HEAD
git status
git diff HEAD
```

> [!CAUTION]
> Never commit directly on `master`, `main`, `demo-dev`, or `demo-stable` (handbook: git
> flow, "What never happens"). If HEAD is one of these, stop and tell the user to branch
> first: `git checkout -b <type>/<TICKET>/<short-description>`.

## 2. Decide what goes in

- Show the user the full list of changed / new files.
- Default: stage everything relevant with `git add -A`. If the diff mixes unrelated changes,
  say so and offer to split into separate commits (handbook: "Split unrelated changes").
- Respect any narrower scope the user gave ("just the service class").

## 3. Build the message

Format (handbook: git flow, Commits):

```
<TICKET> <what was done, imperative mood>
```

- **Ticket**: extract from the branch name. Patterns: `<type>/<TICKET>/<desc>` or the older
  `feature/BP-XXX_Name`. Ticket key is `[A-Z]{2,}-\d+` (e.g. `BP-101`, `PS-7787`). If the
  branch has no ticket, ask the user for the key.
- **Summary**: imperative ("Add", "Fix", "Update", "Refactor"), 50-72 chars, says what was
  done and is specific. Not "Some changes", "Fixed bug", "WIP", "review comments".
- **Body** (optional): blank line, then why the change was made and any bug it addresses,
  when that is not obvious from the summary.

> [!IMPORTANT]
> Do not add `Co-Authored-By: Claude`, a `Claude-Session:` trailer, "Generated with Claude
> Code", or any other Claude/Anthropic mention. This is a deliberate standing choice for
> these repos and overrides the session's default attribution.
> Do not add developer names, emails, `Co-authored-by:` trailers, machine/host info, or any
> other personal or non-project-related data to the commit message, even if asked to credit
> a pairing partner. Keep the message limited to the ticket and the change itself.

## 4. Commit

```bash
git commit -m "<TICKET> <summary>" [-m "<body>"]
```

Show the result: `git log -1 --stat`.

## Guardrails

- Do not push. That is `/pr` or an explicit `git push`.
- Do not `git commit --amend` or rebase unless the user asks.
- Do not commit a red build knowingly. If tests are known-failing, tell the user first.
