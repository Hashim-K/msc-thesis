# msc-thesis
 
Orchestrator workspace for Hashim Karim's MSc thesis.
 
**MSc Computer and Embedded Systems Engineering — TU Delft**
 
## Clone (fresh machine)
 
```bash
git clone --recurse-submodules git@github.com:Hashim-K/msc-thesis.git
cd msc-thesis
./scripts/init-workspace.sh
```

The script will ask whether you are setting up a `desktop`, `daic`, or
`delftblue` environment and then create or update the matching conda
environment for you. When available, it prefers `mamba` or Conda's
`libmamba` solver to avoid the classic solver being killed on HPC login nodes.

On DAIC, the script will try to load the Miniconda module automatically. If that fails, run:

```bash
module use /opt/insy/modulefiles
module load miniconda
./scripts/init-workspace.sh
```

On DelftBlue, install Miniconda or Miniforge in `$HOME` first. The script will
try to find one of these standard installs automatically:

- `$HOME/miniconda3`
- `$HOME/miniforge3`
- `$HOME/mambaforge`

For `daic` and `delftblue`, `init-workspace.sh` now creates a minimal
`MIR-hpc` bootstrap environment for DVC and lightweight helper scripts. The
full training/runtime stack is provided by the shared Apptainer image.

`init-workspace.sh` will:

- initialize submodules
- create `.env` from `.env.example` if needed
- auto-detect workspace repo paths and prompt for overrides when `.env` is first created or still uses placeholders
- ask whether to set up `desktop` (`MIR`), `daic` (`MIR-hpc`), or `delftblue` (`MIR-hpc`)
- create or update the matching conda environment from `repos/mir-environment`
- activate that environment inside the script
- install `repos/mir-core` in editable mode only for the desktop env
- run `./scripts/setup-dvc.sh`

After the script finishes, activate the environment in your shell:

```bash
conda activate MIR
# or
conda activate MIR-hpc
```

`update-workspace.sh` will:

- require Python 3.10+ in the active environment
- refresh `dvc[s3]` in the active Python environment
- refresh the editable `repos/mir-core` install
- rerun `./scripts/setup-dvc.sh`

Use it when `.env`, MinIO credentials, or local workspace configuration changes.

`scripts/setup-dvc.sh` will:

- prompt for MinIO access key and secret key, while allowing Enter to keep the current `.env` value
- configure local DVC remotes for `repos/mir-data` and `repos/mir-outputs`
- configure a shared DVC cache under `MIR_SHARED_ROOT/dvc-cache`
- optionally run `dvc pull` for `repos/mir-data` when valid MinIO credentials are configured

It does **not**:

- run `dvc push`
- create or modify remote bucket contents

`scripts/setup-dvc.sh` only updates local DVC configuration in:

- `repos/mir-data/.dvc/config`
- `repos/mir-data/.dvc/config.local`
- `repos/mir-outputs/.dvc/config`
- `repos/mir-outputs/.dvc/config.local`

If you skip the optional pull in `scripts/setup-dvc.sh`, pull data explicitly:

```bash
cd repos/mir-data
dvc pull
```
 
## Submodules
 
| Path | Repo | Description |
|------|------|-------------|
| `repos/mir-core` | [mir-core](https://github.com/Hashim-K/mir-core) | Shared Python package |
| `repos/mir-train-hpc` | [mir-train-hpc](https://github.com/Hashim-K/mir-train-hpc) | DAIC training workflows |
| `repos/mir-desktop-app` | [mir-desktop-app](https://github.com/Hashim-K/mir-desktop-app) | Desktop inference UI |
| `repos/mir-webapp` | [mir-webapp](https://github.com/Hashim-K/mir-webapp) | DAIC job scheduler webapp |
| `repos/mir-embedded-ai` | [mir-embedded-ai](https://github.com/Hashim-K/mir-embedded-ai) | Embedded inference + actuation |
| `repos/mir-embedded-hmi` | [mir-embedded-hmi](https://github.com/Hashim-K/mir-embedded-hmi) | Wireless node firmware + HMI |
| `repos/mir-environment` | [mir-environment](https://github.com/Hashim-K/mir-environment) | Conda environment definitions |
| `repos/mir-data` | [mir-data](https://github.com/Hashim-K/mir-data) | Datasets + promoted weights (DVC) |
| `repos/mir-outputs` | [mir-outputs](https://github.com/Hashim-K/mir-outputs) | Run artifacts + checkpoints (DVC) |
| `repos/thesis-docs` | [thesis-docs](https://github.com/Hashim-K/thesis-docs) | Notes, ADRs, architecture |
| `repos/thesis-latex` | [thesis-latex](https://github.com/Hashim-K/thesis-latex) | Thesis manuscript (LaTeX) |
 
## Scripts
 
| Script | Purpose |
|--------|---------|
| `scripts/init-workspace.sh` | First-time setup — submodules, `.env`, `mir-core`, local DVC config |
| `scripts/update-workspace.sh` | Refresh local workspace configuration after `.env` or credential changes |
| `scripts/setup-dvc.sh` | Configure local DVC credentials/remotes and optionally pull `mir-data` |
| `scripts/build-apptainer.sh` | Build the shared Apptainer runtime image |
| `scripts/apptainer-exec.sh` | Execute a command inside the shared Apptainer image |
| `scripts/publish-run.sh` | Archive one completed live run into `mir-outputs` |
| `scripts/smoke-test-env.sh` | Verify env activation, path model, and optional DVC pull |
| `scripts/smoke-test-apptainer.sh` | Verify the shared Apptainer runtime image |
| `scripts/update-repos.sh` | Pull latest on all submodules + update SHA pins |
| `scripts/run-desktop.sh` | Launch desktop app |
| `scripts/run-web.sh` | Launch webapp |
| `scripts/promote-model.sh` | Promote checkpoint from outputs to data |
 
## Rules
 
- No domain logic in this repo — thin launchers and config only
- Cross-repo references go through installed packages, env vars, or manifests
- No hard-coded absolute paths — use `MIR_DATA_ROOT`, `MIR_OUTPUTS_ROOT`, `MIR_CORE_PATH`, `MIR_SHARED_ROOT`, `MIR_RUNS_ROOT`

## Apptainer

The common cluster container assets live under [containers/apptainer](/home/hashim/msc-thesis/containers/apptainer).

Build the shared image:

```bash
./scripts/build-apptainer.sh
```

If your host requires unprivileged builds, pass through Apptainer build flags:

```bash
APPTAINER_BUILD_OPTS="--fakeroot" ./scripts/build-apptainer.sh
```

Run a command inside it:

```bash
./scripts/apptainer-exec.sh python -m mir_env.verify_installation
```

## Outputs

Cluster jobs should write live run artifacts to `MIR_RUNS_ROOT` and publish
completed attempts with:

```bash
./scripts/publish-run.sh <experiment_hash> <attempt_id>
```

Archived runs land in `repos/mir-outputs/runs/<experiment_hash>/<attempt_id>/`.
Small metadata files stay in Git, while `checkpoints/` and `logs/` are tracked
with DVC and stored through the shared cache under `MIR_SHARED_ROOT`.

## Smoke Tests

Verify one bootstrap environment end-to-end with:

```bash
./scripts/smoke-test-env.sh daic --pull-test
./scripts/smoke-test-env.sh daic-experimental --pull-test
./scripts/smoke-test-env.sh delftblue --pull-test
```

The script activates the target bootstrap environment, verifies DVC and a few
lightweight Python imports, prints the configured path model, and optionally
performs a small `dvc pull` smoke test from `mir-data`.

Verify the full shared runtime with:

```bash
./scripts/smoke-test-apptainer.sh
```
