# grok-build local patches

Source of truth for local grok-build patches. grok-build keeps
`local-patches` as a symlink here so `update-grok` still works.

## What this is

`spawn-subagent-reasoning-effort.patch` adds an optional
`reasoning_effort` override on `spawn_subagent` and shows
`model · reasoning effort` in the pager subagent UI.

`apply-and-build.sh` applies the patch, runs the related tests, builds
`xai-grok-pager` in release, then restores the grok-build tree.

Refreshed against grok-build `SOURCE_REV`
`70ec060ec3d28e77b9c4593be43c2ab0128bcd21`.

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
