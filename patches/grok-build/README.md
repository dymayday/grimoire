# grok-build local patches

Source of truth for local grok-build patches. grok-build keeps
`local-patches` as a symlink here so `update-grok` still works.

## What this is

`spawn-subagent-reasoning-effort.patch` adds an optional
`reasoning_effort` override on `spawn_subagent` and shows
`model · reasoning effort` in pager surfaces:

- Tasks pane overlay (`Ctrl+G`): far right, left of elapsed time
- Tasks pane searchable label: same string, for search
- Fullscreen subagent title bar: after the description, when effort
  is present. Meta is kept first if the title is truncated.
- `/workflow runs` agent roster: same join when effort is available;
  model-only when effort is absent.

`apply-and-build.sh` applies the patch, runs the related tests, builds
`xai-grok-pager` in release, then restores the grok-build tree.

Refreshed against grok-build HEAD
`f0e3be1100ef5252488e3be8bb0e91cf68d8c305`
(`SOURCE_REV` `036a5d8348cd744767cd0b08518ab17bf608fa7f`).

Revalidated on 2026-09-24 against the latest `origin/main`, still at
this revision. The patch applies cleanly and exactly matches the diff
against upstream. All 39 targeted regression tests and the release build
passed; the source tree was restored to a clean state.

## Install

From a grok-build clone:

```bash
ln -sfn /absolute/path/to/grimoire/patches/grok-build \
  /absolute/path/to/grok-build/local-patches
```

Keep `/local-patches` in grok-build `.git/info/exclude` so the symlink
is not committed. A trailing slash does not match a symlink.

## Apply

From grok-build:

```bash
./local-patches/apply-and-build.sh
```

Or:

```zsh
update-grok
```

`update-grok` is:

```zsh
cd ~/Downloads/repo/grok-build && git fetch && git pull && ./local-patches/apply-and-build.sh ; cd -
```

To point at another clone:

```bash
GROK_BUILD_ROOT=/path/to/grok-build ./local-patches/apply-and-build.sh
```

Do not run the script from this grimoire path unless `GROK_BUILD_ROOT`
is set. The script must apply the patch in grok-build, not here.
