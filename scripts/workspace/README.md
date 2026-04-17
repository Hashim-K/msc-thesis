# Workspace Scripts

Setup and maintenance commands for the checked-out `msc-thesis` workspace.

## Commands

| Script | Purpose |
|--------|---------|
| `init.sh` | First-time setup: submodules, `.env`, conda bootstrap env, DVC config |
| `update.sh` | Refresh local workspace configuration after `.env` or credential changes |
| `dvc.sh` | Configure local DVC remotes, credentials, and shared cache |
| `smoke-test.sh` | Verify bootstrap env, path model, DVC, and optional data pull |
| `sync.sh` | Fast-forward submodules and commit updated submodule SHA pins |

## Fresh Setup

```bash
./scripts/workspace/init.sh
```

## Refresh After Config Changes

```bash
./scripts/workspace/update.sh
```

## Pull Latest Submodule Refs

```bash
./scripts/workspace/sync.sh
```

`sync.sh` skips detached submodules because it cannot safely choose a branch for
them. If a submodule is detached, enter that repo, check out its branch, and run
the sync again.
