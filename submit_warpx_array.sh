#!/usr/bin/env bash
#
# submit_warpx_array.sh
# Submit a SLURM array of WarpX runs on S3DF, creating one run directory per parameter row.
#
# --- Quick config (edit these) -----------------------------------------------------------
CONDA_ENV="warpx-gpu-test"             # name of your conda env (see README)
ACCOUNT="atlas"                         # S3DF account
PARTITION="ampere"                      # GPU partition with A100s
NODES=1
NTASKS=4                                # MPI ranks (one per GPU)
GPUS=4                                  # GPUs requested
CPUS_PER_TASK=8                         # CPU threads per rank
MEM="100G"                              # total memory per node
TIME="04:00:00"                         # walltime

# Paths
# If you leave WARPX_EXE empty, the job script will try to auto-detect a warpx.3d* in ~/warpx/build/bin
WARPX_EXE="/fs/ddn/sdf/group/atlas/d/dntounis/WARPX/WARPX_vs_GP_July2025/warpx/build/bin/warpx.3d"                            # e.g., /path/to/warpx/build/bin/warpx.3d
INPUT_TEMPLATE="/fs/ddn/sdf/group/atlas/d/dntounis/WARPX/WARPX_vs_GP_July2025/warpx/input_C3_250.txt"   # base inputs file to copy & edit per run
PARAMS_FILE="/fs/ddn/sdf/group/atlas/d/dntounis/WARPX/WARPX_vs_GP_July2025/warpx/parameters_scans/parameter_scan_test.txt"   # whitespace/TSV file with one run per line (no header)
RUN_ROOT="$PWD"                          # where to create run directories
RUN_TITLE_PREFIX="C3"                    # prefix in directory names

# Column mapping: which keys in the inputs file to override for each column in PARAMS_FILE.
# Units can be appended literally (e.g. *nano). Leave empty to insert bare number.
# Default assumes columns: sigmax[nm] sigmay[nm] sigmaz[um] emitx[um] emity[nm] nmacropart[-]
COL_KEYS=("my_constants.sigmax"   "my_constants.sigmay"   "my_constants.sigmaz"   "my_constants.emitx"   "my_constants.emity"   "my_constants.nmacropart")
COL_UNITS=("*nano"                "*nano"                 "*micro"               "*micro"               "*nano"                "")
# ----------------------------------------------------------------------------------------

set -euo pipefail

# Count runnable lines (skip blanks & comments)
mapfile -t FILTERED < <(grep -v '^[[:space:]]*#' "$PARAMS_FILE" | sed '/^[[:space:]]*$/d')
NLINES="${#FILTERED[@]}"
if [[ "$NLINES" -eq 0 ]]; then
  echo "No parameter rows found in $PARAMS_FILE" >&2
  exit 1
fi

# Convert arrays to comma-separated strings for export
join_by_comma() { local IFS=,; echo "$*"; }
KEYS_CSV=$(join_by_comma "${COL_KEYS[@]}")
UNITS_CSV=$(join_by_comma "${COL_UNITS[@]}")

echo "Submitting WarpX array job for $NLINES runs..."

sbatch \
  --job-name="warpx_scan" \
  --account="${ACCOUNT}" \
  --partition="${PARTITION}" \
  --nodes="${NODES}" \
  --ntasks="${NTASKS}" \
  --gpus="${GPUS}" \
  --cpus-per-task="${CPUS_PER_TASK}" \
  --mem="${MEM}" \
  --time="${TIME}" \
  --array="1-${NLINES}" \
  --output="slurm-wx-%A_%a.out" \
  --export=ALL,CONDA_ENV="${CONDA_ENV}",PARAMS_FILE="${PARAMS_FILE}",COL_KEYS="${KEYS_CSV}",COL_UNITS="${UNITS_CSV}",INPUT_TEMPLATE="${INPUT_TEMPLATE}",WARPX_EXE="${WARPX_EXE}",RUN_TITLE_PREFIX="${RUN_TITLE_PREFIX}",RUN_ROOT="${RUN_ROOT}",NTASKS="${NTASKS}" \
  "$(dirname "$0")/warpx_job.sh"
