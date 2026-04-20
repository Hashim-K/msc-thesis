# msc-thesis
 
Orchestrator workspace for Hashim Karim's MSc thesis.
 
**MSc Computer and Embedded Systems Engineering — TU Delft**
 
## Clone (fresh machine)
 
```bash
git clone --recurse-submodules git@github.com:Hashim-K/msc-thesis.git
cd msc-thesis
./scripts/workspace/init.sh
```

The script will ask whether you are setting up the `legion`, `daic`, or
`delftblue` platform and then create or update the matching host-tools conda
environment for you.

On DAIC, the script will try to load the Miniconda module automatically. If that fails, run:

```bash
module use /opt/insy/modulefiles
module load miniconda
./scripts/workspace/init.sh
```

For `daic`, `init.sh` creates a minimal `MIR-hpc` bootstrap environment for
DVC and lightweight helper scripts. The full training/runtime stack is
provided by the shared Apptainer image.

DelftBlue is intentionally not configured yet. Add a tracked `.env.delftblue`
and verify the Apptainer workflow there before treating it as supported.

`init.sh` will:

- initialize submodules
- use the tracked `.env` plus the selected platform file such as `.env.legion` or `.env.daic`
- ask whether to set up `legion` (`MIR`), `daic` (`MIR-hpc`), or `delftblue` (`MIR-hpc`)
- create or update the matching conda environment from `repos/mir-environment`
- activate that environment inside the script
- install `repos/mir-core` in editable mode only for the `legion` env
- run `./scripts/workspace/dvc.sh`

After the script finishes, activate the environment in your shell:

```bash
conda activate MIR
# or
conda activate MIR-hpc
```

`update.sh` will:

- require Python 3.10+ in the active environment
- refresh `dvc[s3]` in the active Python environment for `legion` envs
- refresh the editable `repos/mir-core` install
- rerun `./scripts/workspace/dvc.sh`

In `MIR-hpc`, it skips both DVC pip installs and the editable `mir-core`
install, because the bootstrap env stays minimal and the full runtime lives in
Apptainer.

Use it when `.env`, MinIO credentials, or local workspace configuration changes.

`scripts/workspace/dvc.sh` will:

- prompt for MinIO access key and secret key, while allowing Enter to keep the current `.env` value
- configure local DVC remotes for `repos/mir-data` and `repos/mir-outputs`
- configure a shared DVC cache under `MIR_SHARED_ROOT/dvc-cache`
- optionally run `dvc pull` for `repos/mir-data` when valid MinIO credentials are configured

It does **not**:

- run `dvc push`
- create or modify remote bucket contents

`scripts/workspace/dvc.sh` only updates local DVC configuration in:

- `repos/mir-data/.dvc/config`
- `repos/mir-data/.dvc/config.local`
- `repos/mir-outputs/.dvc/config`
- `repos/mir-outputs/.dvc/config.local`

If you skip the optional pull in `scripts/workspace/dvc.sh`, pull data explicitly:

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
 
Script folders have their own short README files. The parent README keeps the
high-level map; folder READMEs keep the command-specific notes close to the
scripts.

| Script | Purpose |
|--------|---------|
| `scripts/workspace/init.sh` | First-time setup — submodules, `.env`, `mir-core`, local DVC config |
| `scripts/workspace/update.sh` | Refresh local workspace configuration after `.env` or credential changes |
| `scripts/workspace/dvc.sh` | Configure local DVC credentials/remotes and optionally pull `mir-data` |
| `scripts/workspace/smoke-test.sh` | Verify env activation, path model, and optional DVC pull |
| `scripts/workspace/sync.sh` | Pull latest on all submodules + update SHA pins |
| `scripts/apptainer/build.sh` | Build the shared Apptainer runtime image |
| `scripts/apptainer/exec.sh` | Execute a command inside the shared Apptainer image |
| `scripts/apptainer/push-image.sh` | DVC-track and push the built Apptainer image to `mir-containers` |
| `scripts/apptainer/pull-image.sh` | Pull the DVC-tracked Apptainer image and link it to `APPTAINER_IMAGE` |
| `scripts/apptainer/smoke-test.sh` | Verify the shared Apptainer runtime image |
| `scripts/runs/publish-run.sh` | Archive one completed live run into `mir-outputs` |
| `scripts/runs/promote-model.sh` | Promote checkpoint from outputs to data |
| `scripts/desktop/run.sh` | Launch desktop app when implemented |
| `scripts/webapp/run.sh` | Launch webapp when implemented |

## Rules
 
- No domain logic in this repo — thin launchers and config only
- Cross-repo references go through installed packages, env vars, or manifests
- No hard-coded absolute paths — use `MIR_DATA_ROOT`, `MIR_OUTPUTS_ROOT`, `MIR_CORE_PATH`, `MIR_SHARED_ROOT`, `MIR_RUNS_ROOT`

## Apptainer

The common cluster container assets live under `containers/apptainer/`.

Build the shared image:

```bash
./scripts/apptainer/build.sh
```

By default this builds the DVC-managed image at:

```text
containers/apptainer/images/mir-common.sif
```

If your host requires unprivileged builds, pass through Apptainer build flags:

```bash
APPTAINER_BUILD_OPTS="--fakeroot" ./scripts/apptainer/build.sh
```

Push the built image to the dedicated DVC remote:

```bash
./scripts/apptainer/push-image.sh
git add containers/apptainer/images/mir-common.sif.dvc containers/apptainer/images/.gitignore .gitignore .dvc/config
git commit -m "Update Apptainer image"
git push
```

On DAIC, pull and link the image into the configured runtime path:

```bash
./scripts/apptainer/pull-image.sh
```

The DAIC pull path is verified. The script pulls the DVC-tracked image from the
`mir-containers` remote into the shared DVC cache and links
`$APPTAINER_IMAGE` directly to the resolved cache object.

Run a command inside it:

```bash
./scripts/apptainer/exec.sh python -m mir_env.verify_installation
```

## Verified DAIC Status

As of 2026-04-20, the DAIC Apptainer runtime has been verified on a GPU node:

- host: `gpu10.hpc.tudelft.nl`
- GPU: NVIDIA A40
- Apptainer: `1.3.2-1.el7`
- container Python: `3.10.14`
- PyTorch: `2.5.1`, CUDA build `12.4`
- result: `cuda_available=True`, `cuda_device_count=1`

The next tracked work item is the first DAIC Apptainer smoke training
experiment in `mir-train-hpc`.

## Outputs

Cluster jobs should write live run artifacts to `MIR_RUNS_ROOT` and publish
completed attempts with:

```bash
./scripts/runs/publish-run.sh <experiment_hash> <attempt_id>
```

Archived runs land in `repos/mir-outputs/runs/<experiment_hash>/<attempt_id>/`.
Small metadata files stay in Git, while `checkpoints/` and `logs/` are tracked
with DVC and stored through the shared cache under `MIR_SHARED_ROOT`.

## Smoke Tests

Verify one bootstrap environment end-to-end with:

```bash
./scripts/workspace/smoke-test.sh legion --pull-test
./scripts/workspace/smoke-test.sh daic --pull-test
```

The script activates the target bootstrap environment, verifies DVC and a few
lightweight Python imports, prints the configured path model, and optionally
performs a small `dvc pull` smoke test from `mir-data`.

Verify the full shared runtime with:

```bash
./scripts/apptainer/smoke-test.sh
```

On a DAIC GPU allocation, verify CUDA visibility with:

```bash
sinteractive --gres=gpu:1 --mem=8G --time=01:00:00
./scripts/apptainer/smoke-test.sh --verbose
```
