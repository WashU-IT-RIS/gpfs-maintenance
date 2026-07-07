#!/usr/bin/env bash

# tree-changed-after
#
# Exit status:
#   0 = at least one matching file or directory was found
#   1 = no matching entries were found
#   2 = usage, date-parsing, filesystem, or other error

set -uo pipefail

usage() {
    printf 'Usage: %s DIRECTORY DATE\n' "${0##*/}" >&2
    printf 'Example: %s /srv/media "2026-07-01 12:00:00"\n' \
        "${0##*/}" >&2
    exit 2
}

[[ $# -eq 2 ]] || usage

directory=$1
cutoff=$2

if [[ ! -d $directory ]]; then
    printf 'Error: not a directory: %s\n' "$directory" >&2
    exit 2
fi

if ! directory=$(realpath -e -- "$directory"); then
    printf 'Error: cannot resolve directory: %s\n' "$1" >&2
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

if (( had_error )); then
    exit 2
elif (( found )); then
    exit 0
else
    printf 'No files or directories were modified or created after %s.\n' \
        "$cutoff"
    exit 1
fi
