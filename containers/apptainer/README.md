# Common Apptainer Runtime

This directory contains the shared Apptainer build assets for cluster jobs.

Files:

- `mir-common.def.in`
  Template definition file used by `scripts/build-apptainer.sh`

Outputs:

- `mir-common.sif`
  Default built image (ignored by Git)

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
