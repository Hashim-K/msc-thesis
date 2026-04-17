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

Use `--no-nv` when testing on a machine without NVIDIA GPU support.
