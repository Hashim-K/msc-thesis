# Scripts

Operational scripts for the `msc-thesis` workspace.

These scripts are thin orchestration wrappers. Project logic should stay inside
the submodules under `repos/`.

## Layout

| Folder | Purpose |
|--------|---------|
| `workspace/` | Clone/bootstrap/update/sync/DVC setup helpers |
| `apptainer/` | Build, pull, push, execute, and smoke-test the shared container |
| `runs/` | Publish completed runs and promote curated checkpoints |
| `desktop/` | Desktop app launcher |
| `webapp/` | Webapp launcher |
| `lib/` | Shared shell helpers used by scripts |

## Common Entry Points

```bash
./scripts/workspace/init.sh
./scripts/workspace/sync.sh
./scripts/workspace/dvc.sh
./scripts/apptainer/smoke-test.sh --no-nv
```

Run scripts from the `msc-thesis` root unless a script says otherwise.
