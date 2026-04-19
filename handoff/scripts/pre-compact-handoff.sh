#!/usr/bin/env bash
# PreCompact hook: generates HANDOFF.md before auto-compaction
# 1. Reads the conversation transcript while it's still intact
# 2. Sends it to a fresh Claude instance (claude -p) to generate a handoff
# 3. Saves it as HANDOFF.md in the project root

set -euo pipefail

INPUT=$(cat)
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // empty')

if [ -z "$SESSION_ID" ]; then
  exit 0
fi

# Find the transcript file
TRANSCRIPT=$(find ~/.claude/projects -maxdepth 2 -name "${SESSION_ID}.jsonl" -type f 2>/dev/null | head -1)

if [ -z "$TRANSCRIPT" ] || [ ! -f "$TRANSCRIPT" ]; then
  exit 0
fi

PROJECT_DIR="${PWD}"
OUTPUT_FILE="${PROJECT_DIR}/HANDOFF.md"

# Extract conversation: user messages (string content) + assistant messages (text blocks)
CONVERSATION=$(jq -r '
  select(.type == "user" or .type == "assistant") |
  if .type == "user" then
    "USER: " + (if (.message.content | type) == "string" then .message.content else (.message.content // "" | tostring) end)
  elif .type == "assistant" then
    "ASSISTANT: " + ([.message.content[]? | select(.type == "text") | .text] | join("\n"))
  else empty end
' "$TRANSCRIPT" 2>/dev/null | tail -300)

if [ -z "$CONVERSATION" ]; then
  exit 0
fi

BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "not a git repo")
LAST_COMMIT=$(git log --oneline -1 2>/dev/null || echo "no commits")
GIT_STATUS=$(git status --short 2>/dev/null || echo "no git")

# Generate handoff via a fresh Claude instance
claude -p --model sonnet "Generate a HANDOFF.md. Use this exact structure:

# Session Handoff
> Generated: $(date -u +%Y-%m-%dT%H:%M:%SZ)
> Branch: ${BRANCH}
> Last commit: ${LAST_COMMIT}

## What We Did
- (bulleted, specific files/functions/line numbers)

## What Didn't Work
(dead ends, failed approaches. \"Clean session.\" if none)

## Key Decisions
| Decision | Choice | Why |
|----------|--------|-----|

## Gotchas
(non-obvious discoveries. \"None.\" if none)

## Next Steps
1. (concrete, actionable)

## Key Files
| File | Role |
|------|------|

Rules: Be concrete. Include failures. Capture WHY. All sections required. Output ONLY the markdown, no commentary.

CONVERSATION:
${CONVERSATION}

GIT STATUS:
${GIT_STATUS}" > "$OUTPUT_FILE" 2>/dev/null || exit 0

exit 0
