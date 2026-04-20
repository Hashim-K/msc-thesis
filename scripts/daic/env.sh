#!/usr/bin/env bash
set -euo pipefail

module use /opt/insy/modulefiles
module load miniconda
export MIR_ENV_PROFILE=daic
conda activate MIR-hpc
