# DAIC Scripts

Small helpers for interactive DAIC login-node sessions.

## Load Host Tools

```bash
source ./scripts/daic/env.sh
```

This loads the DAIC Miniconda module, activates `MIR-hpc`, and sets:

```bash
MIR_ENV_PROFILE=daic
```

Workspace scripts load `.env` first and then `.env.daic` when the profile is
`daic`.

The base `.env` stores only `MIR_ENV_PROFILE`, `AWS_ACCESS_KEY_ID`, and `AWS_SECRET_ACCESS_KEY`. `.env.daic` stores DAIC paths and `MINIO_ENDPOINT`.

If `MIR-hpc` does not exist yet, run:

```bash
./scripts/workspace/init.sh
```

and choose `daic`.

## Verified Flow

From a fresh DAIC checkout:

```bash
git pull
git submodule update --init --recursive
./scripts/workspace/init.sh
./scripts/apptainer/pull-image.sh
./scripts/apptainer/smoke-test.sh --no-nv
```

For an interactive shell, source the host-tools environment:

```bash
source ./scripts/daic/env.sh
```

Executing `./scripts/daic/env.sh` directly can perform checks, but it cannot
persist the activated conda environment in your current shell.

GPU verification should run from an allocated GPU node:

```bash
sinteractive --gres=gpu:1 --mem=8G --time=01:00:00
./scripts/apptainer/smoke-test.sh --verbose
```

The current verified DAIC baseline is an NVIDIA A40 node with CUDA visible
inside the shared Apptainer image.
