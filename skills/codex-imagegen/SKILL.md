---
name: codex-imagegen
description: Use when generating or editing images from OpenCode with Codex CLI, ChatGPT OAuth, Codex subscription auth, no OPENAI_API_KEY, gpt-image-2, $imagegen, or requests that mention OpenAI image-2/gpt-image image generation.
---

# Codex Imagegen

## Overview

Use Codex CLI's `$imagegen` flow for image generation through ChatGPT/Codex OAuth. No `OPENAI_API_KEY` is needed; auth comes from `codex login`, and the image model is `gpt-image-2`.

## When to Use

- User wants to generate or edit an image from OpenCode.
- User has Codex CLI OAuth/subscription auth.
- User has no OpenAI API key.
- User mentions `image-2`, `gpt-image-2`, `$imagegen`, ChatGPT Plus/Pro/Team/Enterprise, or Codex subscription image generation.

Do not use this for direct OpenAI Platform Images API calls; those require `OPENAI_API_KEY` and API billing.

## Workflow

1. Use Codex CLI, not the OpenAI Images API.
2. If the user asks to generate or edit an image and provides an image prompt, run `codex exec` immediately.
3. Ask a clarifying question only when the image prompt or required reference image path is missing.
4. Prefer `codex exec` when OpenCode shells out to Codex because it is non-interactive.
5. Preserve `$imagegen` literally with single quotes.
6. Ask Codex to save to an explicit local file path when the user needs an artifact.
7. If Codex reports an auth problem, tell the user to run `codex login`.
8. If Codex does not recognize `$imagegen`, update Codex CLI or verify the user's plan supports Codex image generation.
9. If OpenCode needs a reusable command, create an instruction command that invokes this skill instead of embedding fragile shell quoting.

## Default Action

If the user's request includes a prompt, execute this pattern directly:

```bash
codex exec '$imagegen create <user image prompt>. Save it as ./generated-images/<short-name>.png'
```

If the user only says "use codex-imagegen" without an image prompt, ask for the prompt.

## Commands

Generate a new image:

```bash
codex exec '$imagegen create a 1024x1024 PNG of a moonlit Arbitrum Orbit gateway dashboard. Save it as ./generated-images/arbitrum-gateway.png'
```

Edit from a reference image:

```bash
codex exec -i reference.png '$imagegen edit this into a polished product hero image. Save it as ./generated-images/hero.png'
```

Reusable OpenCode command body:

```markdown
---
description: Generate an image through Codex CLI OAuth
---

Use the codex-imagegen skill to generate an image for: $ARGUMENTS
```

## Common Mistakes

| Mistake | Correction |
|---|---|
| Saying an API key is required | Codex CLI `$imagegen` works through OAuth subscription auth. |
| Calling the model `image-2` | Use `gpt-image-2`. |
| Passing `--model image-2` | Do not pass an image model flag; `$imagegen` uses the built-in Codex image path. |
| Using `api.openai.com/v1/images` | That is the API-key path, not Codex CLI OAuth. |
| Running `codex "$imagegen ..."` | Shell expands `$imagegen`; use single quotes. |
| Assuming OpenCode exposes `$imagegen` natively | Shell out to Codex CLI or create an instruction command. |
