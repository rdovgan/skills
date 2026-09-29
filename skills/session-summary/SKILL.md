---
name: session-summary
description: >-
  Save a dry technical session note + a rich mermaid summary to Obsidian (linked),
  tag them for search, rename the session, log the run. Re-running in the same
  session updates the notes in place. Use when the user asks to "save the session",
  "summarize this session", "/session-summary".
argument-hint: "[optional topic hint]"
---


Save this session to Obsidian as two linked notes, then set up rename/restore.
Re-running this command in the same session **updates the existing notes in place** — it never creates duplicates.

Vault: `/Users/r.dovgan/Desktop/Claude Vault`
- `Sessions/YYYY/MM/DD/<Slug>.md` — dry technical extract
- `Summary/<Project>/<ISO-Week>/<Slug>.md` — rich narrative + mermaid diagram, grouped by project then week (e.g. `Summary/mybookingpal/2026-W33/Cakb-Oracle-Migration.md`)
- `Logs/YYYY-MM-DD.md` — one file per day, one row per session (a re-run refreshes the row)
- `Keywords.md` — auto-regenerated vault-wide index: every topical tag and key phrase → the notes that carry it
Script: `~/.claude/scripts/save_session.sh` (bundled at `scripts/save_session.sh` in this skill; copy it there if missing, and override the vault with the `VAULT` env var)

## 1. Build the slug and find the session id

**Slug**: Title-Case-With-Hyphens, 3-6 words, from the topic. Prefer the user's hint if given ($ARGUMENTS). Example: `Cakb-Oracle-Migration`.

**Session id**: take the UUID segment from your scratchpad directory path (the directory right above `/scratchpad`). This is what makes re-runs update instead of duplicate — always pass it. If you genuinely can't determine it, omit `--session`; the script then falls back to updating a same-day note with the same slug.

## 2. Pick tags and key phrases

These feed the searchable keyword base (`Keywords.md` + Obsidian tag search).

- **Tags** (5-10): single kebab-case English words/compounds — technologies, systems, domains, ticket ids. Example: `oracle, jdbc, token-expiry, hyatt, ps-7615`. Reuse tags that already exist in `Keywords.md` when they fit (check its `##` headings) instead of inventing near-duplicates.
- **Key phrases** (3-6): short formulations a human would search for later, separated by `;`. Example: `refresh token not supported; client_credentials flow; app-level auth`.

## 3. Write both bodies

Both notes are Markdown rendered by Obsidian — **use its formatting fully**. Rules for both bodies:

- **Bullets over paragraphs, always.** Prose paragraphs are the default failure mode — dense, low-signal, nobody wants to read them. Break every paragraph you're about to write into a list instead: one idea per bullet, lead bullet in **bold** naming the beat, the rest of the bullet is the one-line payload. A paragraph is only acceptable as a single connecting sentence between two bulleted beats, never as the container for the beats themselves.
- **Ruthlessly short.** If a bullet needs two sentences, it's two bullets. Cut throat-clearing ("At this point, it was decided that…" → just say what was decided).
- Every file path, class, method, command, flag, branch, env var → `inline code`.
- Any command, code snippet, config, log excerpt → fenced code block with a language (```bash, ```java, ```sql …). Never leave code inline in a paragraph.
- **Bold** decisions and turning points, *italic* for asides/caveats/framing, `code` for anything literal. Use `==highlight==` sparingly, for the one fact that matters most in the whole note.
- Use Obsidian callouts: `> [!abstract]` TL;DR, `> [!warning]` gotchas/pitfalls, `> [!todo]` next steps, `> [!tip]` insights.
- Use tables for enumerable facts (files touched, endpoints compared, options weighed) — a table beats a bulleted list whenever rows share the same shape.
- No walls of text. If a section is running past ~6 lines of narrative, it's missing a sub-heading or a table.

**Dry body** (technical extract — like a changelog entry, no fluff):
```markdown
## What was done
- concrete bullets: decisions, findings — identifiers in `inline code`

### Commands run
​```bash
# the commands that mattered, with a one-line comment each
​```

## Files touched
| File | Change |
|---|---|
| `path/File.java` | what changed |

## Next steps
- [ ] open items, blockers (checkboxes)
```

**Rich body** (a document a human reads later to understand *what happened and why* — in under a minute, skimming):
```markdown
> [!abstract] TL;DR
> - 2-4 bullets, the headline points — **bold** the punchline word of each

## What happened

### <Phase 1 name — e.g. "The requirement had moved">
- **Lead fact**, the payload — *why it mattered*
- Next fact, `identifier` inline where relevant
- ...

### <Phase 2 name — e.g. "The better path was already there">
- Same shape. Use a table instead of bullets if comparing 2+ things with shared fields:

| | Option A | Option B |
|---|---|---|
| Field | value | value |

> [!warning] Gotchas
> - one bullet per surprise/pitfall (skip the whole callout if none)

## Flow
​```mermaid
flowchart TD
    A[Starting point] --> B[Key step]
    B --> C[Outcome]
​```

> [!todo] Next steps
> - [ ] the open items
```
2-4 phase sub-headings is typical; use fewer for a small session, more only if genuinely
distinct. Every phase is a bullet list or table, never a paragraph block.
Use `flowchart` for a process, `sequenceDiagram` for interactions between components,
`stateDiagram-v2` for state transitions. Skip the diagram only if there's genuinely no
process to show (pure reading/discussion session).

Don't cross-link manually — the script inserts the `[[wikilink]]` between the two notes automatically.

## 4. Save it

Project and git branch are auto-detected — don't pass project unless overriding. Combine both bodies into one stdin stream, separated by a line containing exactly `===RICH_SUMMARY===`:

```bash
bash ~/.claude/scripts/save_session.sh "<slug>" "<title>" \
  --session "<session-uuid>" \
  --tags "<tag1, tag2, ...>" \
  --keywords "<phrase one; phrase two; ...>" <<'EOF'
<dry body from step 3>
===RICH_SUMMARY===
<rich body from step 3, including the mermaid block>
EOF
```

The script prints `Mode: create` or `Mode: update`. On update it rewrites the same two files (adding an `updated:` timestamp, keeping the original `date:`), refreshes today's log row, and regenerates `Keywords.md`.

## 5. Rename (manual — Claude Code has no API for this)

Only on `Mode: create`: show the user the exact command from the script output and tell them to type it now: `/rename <slug>`. Don't skip this or imply it happened automatically. On `Mode: update` the rename was already done — don't ask again.

## 6. Restore

`claude -r "<slug>"` (only works if step 5 was run) or `claude -c` for most recent in this dir.

## Report

Mode (created/updated), both note paths, project + branch detected, slug, tags used, and — on create only — the `/rename <slug>` command to run. Don't restate the content back — they can open the files.
