# Common Apptainer Runtime

This directory contains the shared Apptainer build assets for cluster jobs.

Files:

- `mir-common.def.in`
  Template definition file used by `scripts/apptainer/build.sh`

Outputs:

- `images/mir-common.sif`
  Default built image. The file is ignored by Git and tracked through DVC.

The image is intended to be:

- headless
- GPU-capable with `apptainer exec --nv`
- usable on both DAIC and DelftBlue

The image includes:

- the `MIR-apptainer` conda environment from `repos/mir-environment/environment-apptainer.yml`
- an editable install of `repos/mir-core` baked into the image at build time

Runtime data and output paths are still provided by bind mounts and env vars:

- `MIR_DATA_ROOT`
- `MIR_OUTPUTS_ROOT`
- `MIR_CORE_PATH`

Build locally:

```bash
./scripts/apptainer/build.sh
```

Push the image to the dedicated DVC remote backed by the `mir-containers`
MinIO bucket:

```bash
./scripts/apptainer/push-image.sh
```

Pull it on a cluster checkout and link it to `APPTAINER_IMAGE`:

```bash
./scripts/apptainer/pull-image.sh
```
