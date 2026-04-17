# Run Scripts

Commands for moving experiment artifacts between live cluster storage,
`mir-outputs`, and `mir-data`.

## Commands

| Script | Purpose |
|--------|---------|
| `publish-run.sh` | Archive one completed run from `MIR_RUNS_ROOT` into `mir-outputs` |
| `promote-model.sh` | Copy a selected checkpoint from `mir-outputs` into `mir-data/weights` |

## Publish Contract

Live runs should exist at:

```text
$MIR_RUNS_ROOT/<experiment_hash>/<attempt_id>/
```

Required files:

```text
run.json
metrics.json
config.yaml
checkpoints/
logs/
```

Publish with:

```bash
./scripts/runs/publish-run.sh <experiment_hash> <attempt_id>
```

The script DVC-tracks `checkpoints/` and `logs/`, Git-tracks compact metadata,
pushes both DVC and Git, and removes the live run only after publish succeeds.
