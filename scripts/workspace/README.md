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
| `sync-profile.sh` | Safely fast-forward a deployment profile without resetting initialized submodules to stale pins |

## Fresh Setup

```bash
./scripts/workspace/init.sh
```

Tracked platform env files exist for `legion`, `daic`, and `delftblue`.
DelftBlue still needs live SSH/account validation before training jobs should
be submitted there.

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

Deployment mirrors use `sync-profile.sh`. With `--pull-root`, it lets Git
fast-forward the superproject while preserving non-overlapping tracked host
overrides such as `.env.prometheus`. Existing submodules are switched to their
configured branch and fast-forwarded directly from origin; they are never reset
to an older superproject pin first. Tracked changes in a child repository still
cause that child to be skipped, while untracked runtime output is preserved.

The DAIC and DelftBlue `pull-all.sh` entry points deliberately do not pull the
superproject. They sync every submodule listed by the deployment shell to the
latest commit on its configured branch (`main` by default). Updating the shell
itself, including adding a newly registered submodule, remains an explicit
operator action.
