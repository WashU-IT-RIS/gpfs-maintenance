#!/usr/bin/env bash

#SBATCH --job-name=tree_changed_check
#SBATCH --output=%x-%A_%a.out
#SBATCH --error=%x-%A_%a.err
#SBATCH --ntasks-per-node=1
#SBATCH --cpus-per-task=1       # 1 CPU is sufficient for filesystem traversal
#SBATCH --time=1-12:00:00       # Adjust based on the size of your allocations
#SBATCH --partition=general-cpu
#SBATCH --array=0-5             # Set this to 0-(N-1) where N is number of directories in your text file

set -uo pipefail

# ==============================================================================
# CONFIGURATION
# ==============================================================================
CUTOFF_DATE="2026-07-01 12:00:00"
INPUT_FILE="directories.txt"

# ==============================================================================
# VALIDATION & SLURM SETUP
# ==============================================================================

# Exit immediately if the input file is missing or cutoff date is empty
if [[ -z "${CUTOFF_DATE:-}" || ! -f "$INPUT_FILE" ]]; then
    printf 'ERROR: Cutoff date is not set or input file "%s" is missing.\n' "${INPUT_FILE:-}" >&2
    exit 2
fi

# Exit if not executing inside a Slurm array environment
if [[ -z "${SLURM_ARRAY_TASK_ID:-}" ]]; then
    printf 'ERROR: This script must be submitted via sbatch as a job array.\n' >&2
    exit 2
fi

# Pull the specific directory path for this array task index
directory=$(sed -n "$((SLURM_ARRAY_TASK_ID + 1))p" "$INPUT_FILE")
cutoff=$CUTOFF_DATE

# Exit if the text file doesn't have a line corresponding to this array index
if [[ -z "$directory" ]]; then
    printf 'ERROR: No entry found in %s for line %d.\n' "$INPUT_FILE" "$((SLURM_ARRAY_TASK_ID + 1))" >&2
    exit 2
fi

echo "========================================================"
echo "Job ID: $SLURM_JOB_ID | Array Task ID: $SLURM_ARRAY_TASK_ID"
echo "Targeting Directory: $directory"
echo "Cutoff Date:         $cutoff"
echo "========================================================"

# ==============================================================================
# CORE MODIFICATION LOGIC (Your Original Algorithm)
# ==============================================================================

if [[ ! -d $directory ]]; then
    printf 'Error: not a directory: %s\n' "$directory" >&2
    exit 2
fi

if ! directory=$(realpath -e -- "$directory"); then
    printf 'Error: cannot resolve directory: %s\n' "$directory" >&2
    exit 2
fi

if ! cutoff_epoch=$(date --date="$cutoff" '+%s'); then
    printf 'Error: invalid date: %s\n' "$cutoff" >&2
    exit 2
fi

reference=$(mktemp) || exit 2
trap 'rm -f "$reference"' EXIT

if ! touch --date="$cutoff" -- "$reference"; then
    printf 'Error: could not create cutoff timestamp.\n' >&2
    exit 2
fi

found=0
had_error=0

while IFS= read -r -d '' path; do
    modified=0
    created=0

    # Compare modification time with the cutoff reference file.
    if [[ $path -nt $reference ]]; then
        modified=1
    fi

    # %W is the filesystem birth/creation time as epoch seconds.
    # GNU stat returns 0 when birth time is unavailable.
    if birth_epoch=$(stat --format='%W' -- "$path"); then
        if [[ $birth_epoch =~ ^[0-9]+$ ]] &&
           (( birth_epoch != 0 && birth_epoch > cutoff_epoch )); then
            created=1
        fi
    else
        printf 'Warning: could not stat: %s\n' "$path" >&2
        had_error=1
        continue
    fi

    if (( modified || created )); then
        found=1

        if (( modified && created )); then
            reason='modified and created'
        elif (( modified )); then
            reason='modified'
        else
            reason='created'
        fi

        if [[ -d $path ]]; then
            type='directory'
        elif [[ -f $path ]]; then
            type='file'
        elif [[ -L $path ]]; then
            type='symlink'
        else
            type='other'
        fi

        printf '%-12s %-20s %s\n' "$type" "$reason" "$path"
    fi
done < <(find "$directory" -print0)

echo "--------------------------------------------------------"
if (( had_error )); then
    echo "STATUS: Finished with errors in $directory."
    exit 2
elif (( found )); then
    echo "STATUS: Target changes detected in $directory."
    exit 1
else
    echo "STATUS: No target changes detected in $directory."
    exit 0
fi