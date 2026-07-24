#!/usr/bin/env bash

#SBATCH --job-name=source_cutover_manifest
#SBATCH --output=%x-%A_%a.out
#SBATCH --error=%x-%A_%a.err
#SBATCH --ntasks-per-node=1
#SBATCH --cpus-per-task=2
#SBATCH --time=1-12:00:00
#SBATCH --partition=general-cpu
#SBATCH --array=0-5             # Set to 0-(N-1) where N is line count of INPUT_FILE

set -uo pipefail

# Enable globbing options for hidden files (dotfiles) and empty directory matches
shopt -s dotglob nullglob

# ==============================================================================
# CONFIGURATION
# ==============================================================================
CUTOFF_DATE="2026-07-01 12:00:00"
INPUT_FILE="directories.txt"

SOURCE_BASE="/source_cluster/allocations"
DEST_BASE="/dest_cluster/allocations"
MANIFEST_OUTPUT_DIR="./manifests"

# ==============================================================================
# VALIDATION & SLURM SETUP
# ==============================================================================

if [[ -z "${CUTOFF_DATE:-}" || ! -f "$INPUT_FILE" ]]; then
    printf 'ERROR: Cutoff date is not set or input file "%s" is missing.\n' "${INPUT_FILE:-}" >&2
    exit 2
fi

if [[ -z "${SLURM_ARRAY_TASK_ID:-}" ]]; then
    printf 'ERROR: This script must be submitted via sbatch as a job array.\n' >&2
    exit 2
fi

rel_directory=$(sed -n "$((SLURM_ARRAY_TASK_ID + 1))p" "$INPUT_FILE")

if [[ -z "$rel_directory" ]]; then
    printf 'ERROR: No entry found in %s for line %d.\n' "$INPUT_FILE" "$((SLURM_ARRAY_TASK_ID + 1))" >&2
    exit 2
fi

source_dir="${SOURCE_BASE}/${rel_directory}"
dest_dir="${DEST_BASE}/${rel_directory}"

mkdir -p "$MANIFEST_OUTPUT_DIR" || exit 2
output_manifest="${MANIFEST_OUTPUT_DIR}/manifest_${SLURM_ARRAY_TASK_ID}.txt"

echo "========================================================"
echo "Job ID: $SLURM_JOB_ID | Array Task ID: $SLURM_ARRAY_TASK_ID"
echo "Cutoff Date:      $CUTOFF_DATE"
echo "Source Path:      $source_dir"
echo "Destination Path: $dest_dir"
echo "Output Manifest:  $output_manifest"
echo "========================================================"

if [[ ! -d "$source_dir" ]]; then
    printf 'Error: Source directory does not exist: %s\n' "$source_dir" >&2
    exit 2
fi

cutoff_epoch=$(date --date="$CUTOFF_DATE" '+%s') || exit 2

# Secure temp files for processing
temp_manifest=$(mktemp) || exit 2
sorted_manifest=$(mktemp) || exit 2
trap 'rm -f "$temp_manifest" "$sorted_manifest"' EXIT

# ==============================================================================
# IDENTIFY POST-CUTOVER SOURCE CHANGES
# ==============================================================================
echo "Scanning for changes in source allocation since cutover..."

# Rule A: Catch direct in-place modifications (mtime/ctime > cutoff)
while IFS= read -r -d '' src_item; do
    rel_path="${src_item#"$source_dir"/}"
    
    if [[ -n "$rel_path" ]]; then
        if [[ -d $src_item ]]; then type="directory";
        elif [[ -f $src_item ]]; then type="file";
        elif [[ -L $src_item ]]; then type="symlink";
        else type="other"; fi
        
        # Use tab delimiters (\t) to prevent path and string corruption
        printf '%s\t%s\t%s\n' "$type" "modified_post_cutover" "$rel_path" >> "$temp_manifest"
    fi
done < <(find "$source_dir" -mindepth 1 \( -newerct "$CUTOFF_DATE" -o -newermt "$CUTOFF_DATE" \) -print0)

# Rule B: Catch copied/moved items with old timestamps 
# (parent directory modified since cutoff AND missing on destination)
while IFS= read -r -d '' parent_dir; do
    for src_item in "$parent_dir"/*; do
        # Skip dot-directories (. and ..)
        [[ "${src_item##*/}" == "." || "${src_item##*/}" == ".." ]] && continue
        [[ ! -e "$src_item" && ! -L "$src_item" ]] && continue

        rel_path="${src_item#"$source_dir"/}"
        target_dest="${dest_dir}/${rel_path}"

        # If the item doesn't exist on destination, it was added/copied/moved post-cutover
        if [[ ! -e "$target_dest" && ! -L "$target_dest" ]]; then
            if [[ -d $src_item ]]; then type="directory";
            elif [[ -f $src_item ]]; then type="file";
            elif [[ -L $src_item ]]; then type="symlink";
            else type="other"; fi
            
            printf '%s\t%s\t%s\n' "$type" "copied_or_moved_post_cutover" "$rel_path" >> "$temp_manifest"
        fi
    done
done < <(find "$source_dir" -type d \( -newerct "$CUTOFF_DATE" -o -newermt "$CUTOFF_DATE" \) -print0)

# ==============================================================================
# OUTPUT & SAVE MANIFEST
# ==============================================================================

if [[ ! -s "$temp_manifest" ]]; then
    echo "--------------------------------------------------------"
    echo "STATUS: No post-cutover changes detected in $source_dir."
    > "$output_manifest"
    exit 0
fi

# Sort and deduplicate based strictly on the relative path (3rd tab-delimited column)
sort -t $'\t' -u -k3,3 "$temp_manifest" > "$sorted_manifest"

# Display pretty-printed table to job log stdout
echo "--------------------------------------------------------"
printf '%-12s %-30s %s\n' "TYPE" "REASON" "RELATIVE PATH"
echo "--------------------------------------------------------"
awk -F '\t' '{printf "%-12s %-30s %s\n", $1, $2, $3}' "$sorted_manifest"

# Extract only the 3rd column (relative paths) into the final output manifest file
cut -f3 "$sorted_manifest" > "$output_manifest"

change_count=$(wc -l < "$output_manifest")

echo "--------------------------------------------------------"
echo "STATUS: Found $change_count changed items."
echo "Manifest written to: $output_manifest"
exit 1