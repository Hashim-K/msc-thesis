# Apptainer Scripts

Build, publish, pull, execute, and verify the shared `mir-common.sif` runtime.

The image is DVC-tracked from the `msc-thesis` repo and pushed to the
`mir-containers` MinIO bucket.

## Commands

| Script | Purpose |
|--------|---------|
| `build.sh` | Build the image from `containers/apptainer/mir-common.def.in` |
| `push-image.sh` | DVC-add and push the built image to `mir-containers` |
| `pull-image.sh` | Pull the DVC-tracked image and link it to `APPTAINER_IMAGE` |
| `exec.sh` | Run a command inside the image |
| `smoke-test.sh` | Verify Apptainer, image presence, imports, Python, Torch, and CUDA visibility |

## Local Build

```bash
./scripts/apptainer/build.sh
./scripts/apptainer/smoke-test.sh --no-nv
```

## Cluster Use

```bash
./scripts/apptainer/pull-image.sh
./scripts/apptainer/smoke-test.sh
```

Use `pull-image.sh` instead of running `dvc pull` manually for the image. The
script configures the parent workspace DVC cache under
`$MIR_SHARED_ROOT/dvc-cache` with symlink checkout before pulling, validates the
expected image size from the `.dvc` file, and links `$APPTAINER_IMAGE` directly
to the resolved cache object. This avoids putting the multi-GB `.sif` file in
home quota.

Use `--no-nv` when testing on a machine without NVIDIA GPU support.

## Verified DAIC Baseline

The shared image has been pulled and smoke-tested on DAIC:

```bash
./scripts/apptainer/pull-image.sh
./scripts/apptainer/smoke-test.sh --no-nv
```

GPU visibility was verified from an interactive DAIC GPU allocation:

```bash
sinteractive --gres=gpu:1 --mem=8G --time=01:00:00
./scripts/apptainer/smoke-test.sh --verbose
```

Verified result: NVIDIA A40 visible inside the container with
`cuda_available=True`.
