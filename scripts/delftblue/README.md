# DelftBlue Scripts

Small helpers for interactive DelftBlue login-node sessions.

## Load Host Tools

```bash
source ./scripts/delftblue/env.sh
```

This loads a user-installed Conda or Miniforge from `$HOME`, activates
`MIR-hpc`, sets `MIR_ENV_PROFILE=delftblue`, and loads `.env.delftblue`.

If `MIR-hpc` does not exist yet, run:

```bash
./scripts/workspace/init.sh
```

and choose `delftblue`.

## Setup Flow

From a fresh DelftBlue checkout:

```bash
git pull
git submodule update --init --recursive
./scripts/workspace/init.sh
./scripts/apptainer/pull-image.sh
./scripts/apptainer/smoke-test.sh --no-nv
```

To refresh an existing DelftBlue checkout:

```bash
./scripts/delftblue/pull-all.sh
```

GPU verification should run from an allocated GPU node:

```bash
srun --partition=gpu --time=00:30:00 --ntasks=1 --cpus-per-task=4 --gpus-per-task=1 --mem=16G --account=<account> --pty bash
./scripts/apptainer/smoke-test.sh --verbose
```

The Apptainer cache and temporary directory are expected under `/scratch` to
avoid filling the DelftBlue home quota.
