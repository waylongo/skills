---
name: handoff
description: Generates a HANDOFF.md shift-change report capturing session context, decisions, gotchas, and next steps. Use when a session is ending, the user says "handoff", "hand off", "shift change", "wrap up", or "save context". Use with "resume" to read back an existing HANDOFF.md at the start of a new session.
---

# /handoff

Two modes: **save** (default) and **resume**.

If input contains "resume", "pick up", or "continue", run Resume. Otherwise run Save.

## First Run

Check if the auto-compact hook is configured or was declined:

```bash
jq -e '.hooks.PreCompact[] | select(.hooks[].command | test("pre-compact-handoff"))' ~/.claude/settings.json 2>/dev/null && echo "HOOK_EXISTS" || { [ -f ~/.claude/.handoff-hook-declined ] && echo "DECLINED" || echo "NO_HOOK"; }
```

If `HOOK_EXISTS` or `DECLINED`: skip to Save/Resume.

If `NO_HOOK`: ask the user:

> Enable auto-handoff? When context runs out, a HANDOFF.md is generated automatically before compaction. Uses a `claude -p` call (Sonnet, costs tokens). Disable later via `/hooks`.

- A) Yes, enable (recommended)
- B) No, I'll run /handoff manually

If A: read `~/.claude/settings.json`, merge into the `hooks` object (preserve existing hooks):

```json
{
  "PreCompact": [
    {
      "matcher": "auto",
      "hooks": [
        {
          "type": "command",
          "command": "~/.claude/skills/handoff/scripts/pre-compact-handoff.sh",
          "timeout": 120
        }
      ]
    }
  ]
}
```

If B: run `touch ~/.claude/.handoff-hook-declined`

Then proceed with Save or Resume.

## Resume

1. Read `HANDOFF.md` from the project root. If missing: `No HANDOFF.md found.` and stop.
2. Summarize: what was done, gotchas, next steps.
3. Ask: `Ready to continue?`

## Save

1. Run:
```bash
echo "=== BRANCH ===" && git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "not a git repo"
echo "=== LAST COMMIT ===" && git log --oneline -1 2>/dev/null || echo "no commits"
echo "=== STATUS ===" && git status --short 2>/dev/null || echo "no git"
```

2. Review the **full conversation** and write `HANDOFF.md` to the project root:

```markdown
# Session Handoff

> Generated: {ISO-8601 timestamp}
> Branch: {branch}
> Last commit: {hash} {message}

## What We Did
- {specific: name files, functions, line numbers}

## What Didn't Work
{Dead ends, failed approaches. "Clean session." if none.}

## Key Decisions
| Decision | Choice | Why |
|----------|--------|-----|

## Gotchas
{Non-obvious discoveries. "None." if none.}

## Next Steps
1. {concrete, actionable}

## Key Files
| File | Role |
|------|------|
```

3. Confirm: `HANDOFF SAVED → HANDOFF.md`

## Rules

- **Concrete.** `src/auth.ts:47` not "the auth file".
- **Include failures.** Dead ends prevent the next session repeating them.
- **Capture WHY.** Decisions without reasoning get re-litigated.
- **All sections required.** Use fallback text if empty.
- **Overwrite** any previous HANDOFF.md.
