---
name: prewalk
description: Use when the user invokes /prewalk, or asks for an expensive/frontier model (grok-4.6, grok-4.5, sol) to start a coding task and a cheaper model (luna, terra) to finish it — cost concerns on a self-contained task like a bug fix or focused feature.
argument-hint: "[task]"
disable-model-invocation: true
---

# Prewalk

## Overview

Frontier→cheap handoff keeps the **live trajectory, not a plan document**. In the Grok Build TUI, `/model` (alias `/m`) preserves the conversation and the `todo_write` list. A `spawn_subagent` execution child must load the same context again.

This is a TUI workflow. Headless `grok -p` cannot switch models mid-run. Do not enter `/plan` — plan mode blocks edits other than the plan file.

## When to use

- Self-contained coding tasks where exploration and convergence are hard but execution is mechanical.
- NOT for sprawling multi-domain work, deep knowledge transfer, or trivial tasks.

## Phase 1 — Walk (the expensive model)

If the session is already on `luna` or `terra`, stop and ask for `/model grok-4.6` (or `sol`) before exploring. Stay on the frontier model after that. Do not change it yourself.

1. **Explore.** Use `read_file`, `grep`, and `list_dir`. Read every file the change touches and trace the flow to a one-sentence root cause or concrete approach. No edits yet.
2. **Plan as todos.** Call `todo_write` with `merge: false` and **7–11 meaningful items**. Each item has an `id`, `content` that names the target and the validation command or criterion, and `status`. Include only code-changing or verification work—no reporting, bookkeeping, or cleanup ceremony. Todo #1 is the first edit; set it `in_progress`.
3. **Land the first edit.** Complete todo #1 now: edit with `search_replace` or `write`, validate with `run_terminal_command`, then mark it `completed` via `todo_write` (`merge: true`). This proves the plan and leaves a worked example in context.
4. **Stop.** End the turn with exactly this handoff and nothing after it:
   > Prewalk complete: N todos, first edit landed and verified. Switch with `/model luna` or `/model terra` — or `/effort low` if only 2–3 todos remain — and say **continue**; the full context carries over.

Do not continue past todo #1 on the expensive model. Do not create a handoff file or `spawn_subagent` to execute the rest. You cannot run `/model` yourself; the user must switch.

## Phase 2 — Execute (after the switch)

Continue the existing todo list; prior exploration remains in context.

- Work in order, one todo at a time: edit → validate → mark `completed`. Never complete several at once.
- Edit previously read files directly; re-read only when they changed on disk.
- Never change tests or validation assets to force a pass. If a test appears wrong, stop and tell the user.
- When reality disproves a todo, fix the actual problem and update the item with `todo_write` (`merge: true`).

Before claiming done, verify:

- **Consistency:** find every call site or duplicate needing the same pattern, signature, or check.
- **Scope:** the diff is the smallest correct change and touches nothing unrelated.
- **Verification:** run the full test module, not only the expected test.

Done means every todo is `completed` and final validation passed. Open todos mean not done.

## Review (optional)

For an independent pass, `spawn_subagent` a fresh reviewer with the diff **and repository access**. Pass `model` explicitly — after the cheap switch, children inherit `luna`/`terra` unless you override.

- Default `model`: `grok-4.6`. `subagent_type`: `explore` (read-only).
- Escalate to `sol` for shared contracts, API semantics, many-caller helpers, or similarly high-impact changes.
- Never use `luna` or `terra`, resume the original walk trajectory (`resume_from`), or review from diff text alone.

## Red flags — STOP

- `spawn_subagent` for execution: it reloads context already paid for.
- Writing a handoff `.md`: same duplication in a file.
- Entering plan mode or asking for `/plan`.
- Starting the walk on `luna` or `terra`.
- Requesting the switch before todo #1 validates.
- Completing a todo without its validation.
- Weakening a test or assertion to pass.
- Claiming completion with open todos.
- Review spawn with no `model` after the cheap switch.

## Rationalizations

| Excuse | Reality |
|---|---|
| “A fresh subagent prompt is cleaner.” | The context is the asset. Reloading it bills the reading twice. |
| “`/model` is user-controlled.” | Correct: stop and ask the user to switch (to frontier first, then to cheap). |
| “Keep frontier around to review.” | Per-todo validation is inline review; use a fresh reviewer only when needed. |
| “Hand off after planning.” | The first verified edit proves the plan. |
| “The rest is trivial; batch it.” | Work one at a time, validation first. |
| “The expected value is outdated.” | Fix code; if the test is wrong, tell the user. |
| “Review can inherit the current model.” | After `/model luna`/`terra`, inherit is the cheap tier. Pass `model`. |
