# Run Scripts

Commands for moving experiment artifacts between live cluster storage,
`mir-outputs`, and `mir-data`.

## Commands

| Script | Purpose |
|--------|---------|
| `publish-run.sh` | Archive one completed run from `MIR_RUNS_ROOT` into `mir-outputs` |
| `promote-model.sh` | Copy a selected checkpoint from `mir-outputs` into `mir-data/weights` |

## Publish Contract

Unified live runs should exist at:

```text
$MIR_RUNS_ROOT/<experiment_hash>/attempts/<attempt_id>/
```

Required files:

```text
../experiment.json
attempt.json
pipeline_state.json
<registered stage manifests and outputs>
```

The publisher also accepts the older `<experiment_hash>/<attempt_id>/` run
layout so outstanding legacy jobs remain publishable.

Publish with:

```bash
./scripts/runs/publish-run.sh <experiment_hash> <attempt_id>
```

The script creates one versioned bundle under
`mir-outputs/runs/<experiment_hash>/attempts/<attempt_id>/`, retains total and
per-stage LaTeX sources, requires matching PDFs compiled with `latexmk`,
generates long-form metric exports, and DVC-tracks the entire copied attempt
snapshot. Compact reports and an append-only per-attempt catalog entry are
Git-tracked. Publication stops before preparation if the report compiler is
unavailable.

Publication state moves through:

```text
completed -> reporting -> publishing -> published
```

`reporting_failed` and `publishing_failed` preserve
`scientific_status: completed` and can be retried. The live completed attempt
is always retained on HDD; publishing never deletes it.

## Model Promotion

Promote the checkpoints from either archive generation with:

```bash
./scripts/runs/promote-model.sh <experiment_hash> <attempt_id> <model-id>
```

For unified bundles, materialize `data.dvc` first if needed. Promotion copies
only `train/fold_*/checkpoints/official/` and prefixes each filename with its
fold ID, preserving the legacy promoted-weight naming convention. Recovery
checkpoints remain archived but are not promoted. Older archives continue to
use their top-level `checkpoints/` directory.
