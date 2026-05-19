#!/usr/bin/env bash
# Smoke-test the DAIC training environment before submitting jobs.
# Usage: bash scripts/daic/test-env.sh

set -uo pipefail

ROOT="/home/nfs/hashimkarim/msc-thesis"
REPOS="$ROOT/repos"
PASS=0; FAIL=0

ok()   { echo "  [OK]  $*"; (( PASS++ )) || true; }
fail() { echo "  [FAIL] $*"; (( FAIL++ )) || true; }

section() { echo; echo "── $* ──"; }

# ── Repos ────────────────────────────────────────────────────────────────────
section "Repos"

for repo in mir-core mir-train-hpc; do
  branch=$(git -C "$REPOS/$repo" rev-parse --abbrev-ref HEAD 2>/dev/null)
  if [[ "$branch" == "HEAD" ]]; then
    fail "$repo: detached HEAD (run pull-all.sh)"
  elif [[ "$branch" == "main" ]]; then
    commit=$(git -C "$REPOS/$repo" rev-parse --short HEAD)
    ok "$repo @ $branch ($commit)"
  else
    fail "$repo: on branch '$branch', expected main"
  fi
done

# ── Python imports ────────────────────────────────────────────────────────────
section "Python imports"

export PYTHONPATH="$REPOS/mir-core:$REPOS/mir-train-hpc${PYTHONPATH:+:$PYTHONPATH}"

python_check() {
  local label="$1"; shift
  if python -c "$@" 2>/dev/null; then
    ok "$label"
  else
    fail "$label"
    python -c "$@" 2>&1 | sed 's/^/    /'
  fi
}

python_check "import mir_core"      "import mir_core"
python_check "import beatlab"       "import beatlab"
python_check "beatlab.matrix"       "from beatlab import matrix"
python_check "beatlab.print_hash"   "from beatlab import print_hash"
python_check "beatlab.train_beat"   "from beatlab import train_beat"

# ── print_hash smoke test ─────────────────────────────────────────────────────
section "print_hash"

hash_out=$(python -m beatlab.print_hash \
  --matrix \
  --target-preset salsaset_ft \
  --model-preset bock_tcn \
  --condition-preset target_only \
  --learning-rate-preset lr_5e_4 2>/dev/null)

if [[ "$hash_out" =~ ^btk-[0-9a-f]+$ ]]; then
  ok "hash = $hash_out"
else
  fail "unexpected output: '$hash_out'"
fi

# ── Data ──────────────────────────────────────────────────────────────────────
section "Datasets"

DATA_ROOT="$REPOS/mir-data/datasets/processed"
for ds in salsaset_ft salsa_dataset brid candombe; do
  if [[ -d "$DATA_ROOT/$ds" ]]; then
    ok "$ds"
  else
    fail "$ds not found at $DATA_ROOT/$ds"
  fi
done

# ── Apptainer image ───────────────────────────────────────────────────────────
section "Apptainer"

IMG=$(ls "$ROOT/scripts/apptainer/"*.sif 2>/dev/null | head -1 || true)
if [[ -n "$IMG" ]]; then
  ok "image: $(basename "$IMG")"
else
  fail "no .sif image found under $ROOT/scripts/apptainer/"
fi

if command -v apptainer >/dev/null 2>&1; then
  ok "apptainer in PATH"
elif command -v singularity >/dev/null 2>&1; then
  ok "singularity in PATH (apptainer compat)"
else
  fail "apptainer/singularity not in PATH"
fi

# ── SLURM ─────────────────────────────────────────────────────────────────────
section "SLURM"

if command -v sbatch >/dev/null 2>&1; then
  ok "sbatch available"
else
  fail "sbatch not in PATH"
fi

if command -v squeue >/dev/null 2>&1; then
  ok "squeue available"
else
  fail "squeue not in PATH"
fi

# ── Summary ───────────────────────────────────────────────────────────────────
echo
echo "────────────────────────────────"
echo "  $PASS passed  /  $FAIL failed"
echo "────────────────────────────────"

(( FAIL == 0 ))
