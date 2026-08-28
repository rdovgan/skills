# skills

Claude Code skills I use across projects. Each skill is a directory under `skills/` with a `SKILL.md` file.

## Skills

### deslop

Cuts AI tells and verbosity from code, docs, and chat responses. It scans for a fixed list of patterns (puffery, em dashes, inline-header lists, "great question", metaphor soup, and more), rewrites them in plain language, then does a self-audit pass. The skill is marked "must always apply", so it runs on every session once installed.

See [skills/deslop/SKILL.md](skills/deslop/SKILL.md) for the full pattern list.

### consolidate

Run before ending a session. It sweeps the conversation for schemas, decisions, scope changes, and findings, then files each one in its canonical home: `plans/<topic>.md`, local `memory/kb/`, or a new ADR. Also checks that the deslop skill is loaded so what gets written stays clean.

See [skills/consolidate/SKILL.md](skills/consolidate/SKILL.md).

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
