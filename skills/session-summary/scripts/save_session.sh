#!/usr/bin/env bash
# Usage: save_session.sh <slug> <title> [project] [--session <uuid>] [--tags "a,b,c"] [--keywords "phrase; phrase2"] <<'EOF'
# <dry technical content>
# ===RICH_SUMMARY===
# <rich narrative + mermaid content>
# EOF
#
# project is optional — auto-detected from git remote / cwd if omitted.
# --session enables idempotent re-runs: an existing pair of notes with the same
# session-id in frontmatter is updated in place instead of new files being created.
# Without --session, a same-day note with the same slug is updated instead.
# Writes two linked notes (Sessions/ dry, Summary/ rich), appends/refreshes today's
# log row, and regenerates the vault-wide Keywords.md tag/phrase index.
set -euo pipefail

VAULT="${VAULT:-/Users/r.dovgan/Desktop/Claude Vault}"

SESSION_ID="${CLAUDE_SESSION_ID:-}"
TAGS=""
KEYWORDS=""
BRANCH_OVERRIDE=""
POSITIONAL=()
while [ $# -gt 0 ]; do
  case "$1" in
    --session)  SESSION_ID="${2:?--session needs a value}"; shift 2 ;;
    --tags)     TAGS="${2:?--tags needs a value}"; shift 2 ;;
    --keywords) KEYWORDS="${2:?--keywords needs a value}"; shift 2 ;;
    --branch)   BRANCH_OVERRIDE="${2:?--branch needs a value}"; shift 2 ;;
    *)          POSITIONAL+=("$1"); shift ;;
  esac
done
SLUG="${POSITIONAL[0]:?slug required}"
TITLE="${POSITIONAL[1]:?title required}"
PROJECT="${POSITIONAL[2]:-}"

if [ -z "$PROJECT" ]; then
  PROJECT="$(git remote get-url origin 2>/dev/null | sed 's/.*\///;s/\.git$//' || true)"
  if [ -z "$PROJECT" ]; then
    PROJECT="$(basename "$PWD")"
  fi
fi

BRANCH="$BRANCH_OVERRIDE"
[ -z "$BRANCH" ] && BRANCH="$(git branch --show-current 2>/dev/null || true)"
[ -z "$BRANCH" ] && BRANCH="n/a"

YEAR="$(date +%Y)"; MONTH="$(date +%m)"; DAY="$(date +%d)"
WEEK="$(date +%G-W%V)"
TIMESTAMP="$(date '+%H:%M:%S')"
TODAY="${YEAR}-${MONTH}-${DAY}"
PROJECT_SAFE="$(echo "$PROJECT" | tr ' /' '--')"

RAW="$(cat)"
DRY_BODY="$(printf '%s\n' "$RAW" | awk '/^===RICH_SUMMARY===$/{exit} {print}')"
RICH_BODY="$(printf '%s\n' "$RAW" | awk 'found{print} /^===RICH_SUMMARY===$/{found=1}')"

if [ -z "$RICH_BODY" ]; then
  echo "ERROR: no ===RICH_SUMMARY=== delimiter found in input — both sections are required." >&2
  exit 1
fi

SESSIONS_DIR="$VAULT/Sessions/${YEAR}/${MONTH}/${DAY}"
SUMMARY_DIR="$VAULT/Summary/${PROJECT_SAFE}/${WEEK}"
LOGS_DIR="$VAULT/Logs"

# --- locate existing notes for this session (update mode) --------------------
MODE="create"
SESSION_NOTE=""
SUMMARY_NOTE=""

if [ -n "$SESSION_ID" ] && [ -d "$VAULT/Sessions" ]; then
  SESSION_NOTE="$(grep -rl --include='*.md' "^session-id: ${SESSION_ID}$" "$VAULT/Sessions" 2>/dev/null | head -1 || true)"
fi
if [ -n "$SESSION_ID" ] && [ -d "$VAULT/Summary" ]; then
  SUMMARY_NOTE="$(grep -rl --include='*.md' "^session-id: ${SESSION_ID}$" "$VAULT/Summary" 2>/dev/null | head -1 || true)"
fi

if [ -n "$SESSION_NOTE" ]; then
  MODE="update"
  FINAL_SLUG="$(basename "$SESSION_NOTE" .md)"
elif [ -f "$SESSIONS_DIR/${SLUG}.md" ]; then
  # same slug, same day: only update if it's not a different session's note
  EXISTING_SID="$(awk -F': ' '/^session-id: /{print $2; exit}' "$SESSIONS_DIR/${SLUG}.md")"
  if [ -z "$EXISTING_SID" ] || [ -z "$SESSION_ID" ] || [ "$EXISTING_SID" = "$SESSION_ID" ]; then
    MODE="update"
    FINAL_SLUG="$SLUG"
    SESSION_NOTE="$SESSIONS_DIR/${SLUG}.md"
    [ -f "$SUMMARY_DIR/${SLUG}.md" ] && SUMMARY_NOTE="$SUMMARY_DIR/${SLUG}.md"
  else
    FINAL_SLUG="${SLUG}-$(date +%H%M)"
  fi
else
  FINAL_SLUG="$SLUG"
fi

mkdir -p "$SESSIONS_DIR" "$SUMMARY_DIR" "$LOGS_DIR"

[ -z "$SESSION_NOTE" ] && SESSION_NOTE="$SESSIONS_DIR/${FINAL_SLUG}.md"
[ -z "$SUMMARY_NOTE" ] && SUMMARY_NOTE="$SUMMARY_DIR/${FINAL_SLUG}.md"
LOG_FILE="$LOGS_DIR/${TODAY}.md"

# preserve the original creation date when updating
CREATED="$TODAY"
UPDATED_LINE=""
if [ "$MODE" = "update" ] && [ -f "$SESSION_NOTE" ]; then
  ORIG_DATE="$(awk -F': ' '/^date: /{print $2; exit}' "$SESSION_NOTE")"
  [ -n "$ORIG_DATE" ] && CREATED="$ORIG_DATE"
  UPDATED_LINE="updated: ${TODAY} ${TIMESTAMP}"
fi

# links are derived from actual note paths (they may live under an older date/week)
SESSION_LINK="${SESSION_NOTE#"$VAULT"/}"; SESSION_LINK="${SESSION_LINK%.md}"
SUMMARY_LINK="${SUMMARY_NOTE#"$VAULT"/}"; SUMMARY_LINK="${SUMMARY_LINK%.md}"

# --- frontmatter helpers -----------------------------------------------------
# TAGS: comma-separated -> inline yaml list, kebab-case, deduped
yaml_tags() {  # $1 = base tag (claude-session | claude-summary)
  local base="$1"
  local out="$base"
  if [ -n "$TAGS" ]; then
    local t
    while IFS= read -r t; do
      t="$(echo "$t" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | tr 'A-Z ' 'a-z-')"
      [ -z "$t" ] || [ "$t" = "$base" ] && continue
      case ", $out," in *", $t,"*) continue ;; esac
      out="$out, $t"
    done < <(printf '%s\n' "$TAGS" | tr ',' '\n')
  fi
  echo "tags: [$out]"
}

# KEYWORDS: semicolon-separated phrases -> multi-line yaml list
yaml_keywords() {
  [ -z "$KEYWORDS" ] && return 0
  echo "keywords:"
  local k
  while IFS= read -r k; do
    k="$(echo "$k" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
    [ -z "$k" ] && continue
    echo "  - ${k}"
  done < <(printf '%s\n' "$KEYWORDS" | tr ';' '\n')
}

write_note() {  # $1 = path, $2 = base tag, $3 = backlink label, $4 = backlink target, $5 = body
  {
    echo "---"
    echo "title: \"${TITLE}\""
    echo "date: ${CREATED}"
    [ -n "$UPDATED_LINE" ] && echo "$UPDATED_LINE"
    echo "project: ${PROJECT}"
    echo "branch: ${BRANCH}"
    echo "slug: ${FINAL_SLUG}"
    [ -n "$SESSION_ID" ] && echo "session-id: ${SESSION_ID}"
    yaml_tags "$2"
    yaml_keywords
    echo "---"
    echo ""
    echo "> $3: [[$4]]"
    echo ""
    echo "$5"
  } > "$1"
}

write_note "$SESSION_NOTE" "claude-session" "Full summary" "$SUMMARY_LINK" "$DRY_BODY"
write_note "$SUMMARY_NOTE" "claude-summary" "Technical log" "$SESSION_LINK" "$RICH_BODY"

# --- daily log: refresh the row on update, append on create ------------------
if [ ! -f "$LOG_FILE" ]; then
  {
    echo "# Log ${TODAY}"
    echo ""
    echo "| Time | Project | Branch | Slug | Session | Summary |"
    echo "|---|---|---|---|---|---|"
  } > "$LOG_FILE"
fi
if [ "$MODE" = "update" ]; then
  TMP_LOG="$(mktemp)"
  grep -vF "[[${SESSION_LINK}]]" "$LOG_FILE" > "$TMP_LOG" || true
  mv "$TMP_LOG" "$LOG_FILE"
fi
echo "| ${TIMESTAMP} | ${PROJECT} | ${BRANCH} | ${FINAL_SLUG} | [[${SESSION_LINK}]] | [[${SUMMARY_LINK}]] |" >> "$LOG_FILE"

# --- regenerate the vault-wide keyword index ---------------------------------
INDEX_FILE="$VAULT/Keywords.md"
TMP_PAIRS="$(mktemp)"

find "$VAULT/Sessions" "$VAULT/Summary" -name '*.md' -type f 2>/dev/null | while IFS= read -r f; do
  rel="${f#"$VAULT"/}"; rel="${rel%.md}"
  awk -v link="$rel" '
    NR==1 { if ($0 != "---") exit; inFM=1; next }
    inFM && /^---$/ { exit }
    inFM && /^tags:/ {
      line=$0
      sub(/^tags:[[:space:]]*\[/, "", line); sub(/\][[:space:]]*$/, "", line)
      n=split(line, arr, ",")
      for (i=1; i<=n; i++) {
        t=arr[i]; gsub(/^[[:space:]]+|[[:space:]]+$/, "", t)
        if (t != "" && t != "claude-session" && t != "claude-summary")
          printf "T\t%s\t%s\n", t, link
      }
      next
    }
    inFM && /^keywords:/ { inKW=1; next }
    inFM && inKW {
      if ($0 ~ /^[[:space:]]+-[[:space:]]/) {
        k=$0; sub(/^[[:space:]]+-[[:space:]]*/, "", k)
        gsub(/^[[:space:]]+|[[:space:]]+$/, "", k)
        if (k != "") printf "K\t%s\t%s\n", k, link
      } else { inKW=0 }
    }
  ' "$f"
done | sort -f -u > "$TMP_PAIRS"

{
  echo "---"
  echo "tags: [claude-index]"
  echo "updated: ${TODAY} ${TIMESTAMP}"
  echo "---"
  echo ""
  echo "# Keyword Index"
  echo ""
  echo "> Auto-generated by \`save_session.sh\` on every run — do not edit by hand."
  awk -F'\t' '
    $1 == "T" {
      if ($2 != prevT) { printf "\n## #%s\n", $2; prevT=$2 }
      printf "- [[%s]]\n", $3
    }
  ' "$TMP_PAIRS"
  if grep -q '^K	' "$TMP_PAIRS"; then
    echo ""
    echo "---"
    echo ""
    echo "# Key Phrases"
    awk -F'\t' '
      $1 == "K" {
        if ($2 != prevK) { printf "\n## %s\n", $2; prevK=$2 }
        printf "- [[%s]]\n", $3
      }
    ' "$TMP_PAIRS"
  fi
} > "$INDEX_FILE"
rm -f "$TMP_PAIRS"

# --- report ------------------------------------------------------------------
echo "Mode: ${MODE}"
echo "Session note: ${SESSION_NOTE}"
echo "Summary note: ${SUMMARY_NOTE}"
echo "Project: ${PROJECT} | Branch: ${BRANCH}"
echo "Logged: ${LOG_FILE}"
echo "Index: ${INDEX_FILE}"
echo ""
if [ "$MODE" = "update" ]; then
  echo "Existing notes were updated in place — no rename needed if already done."
else
  echo "Run this to rename the session (manual, Claude Code has no API for it):"
fi
echo "/rename ${FINAL_SLUG}"
