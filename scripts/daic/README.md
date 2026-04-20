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
