#!/usr/bin/env python3
import argparse
import re
import shutil
import sys
from pathlib import Path


def process_directory(source_dir: Path, dry_run: bool = False):
    if not source_dir.is_dir():
        print(f"Error: Source directory '{source_dir}' does not exist.")
        sys.exit(1)

    # Regex patterns
    target_dir_pattern = re.compile(
        r"^Targeting Directory:\s*(.+)$", re.MULTILINE
    )  # why multiline?
    recovered_folder_pattern = re.compile(r"^(.*?)/recovered_from_([^/]+)(?:/.*)?$")

    out_files = list(source_dir.glob("*.out"))
    if not out_files:
        print(f"No '.out' files found in {source_dir}")
        return

    print(f"Found {len(out_files)} '.out' file(s) to process.\n")

    for out_file in out_files:
        try:
            content = out_file.read_text(encoding="utf-8", errors="ignore")
            match = target_dir_pattern.search(content)

            if not match:
                print(f"[SKIP] {out_file.name}: 'Targeting Directory' line not found.")
                continue

            target_path = match.group(1).strip()
            path_match = recovered_folder_pattern.match(target_path)

            if not path_match:
                print(
                    f"[SKIP] {out_file.name}: Could not match 'recovered_from_<type>' pattern in path: {target_path}"
                )
                continue

            # Extract base directory and suffix (e.g., 'Active', 'snapshot')
            dest_dir_path, folder_type = path_match.groups()  # aren't their 3 groups?
            dest_dir = Path(dest_dir_path)
            dest_file_name = f"modified_files_{folder_type}.txt"
            dest_file_path = dest_dir / dest_file_name

            print(f"[PROCESSING] {out_file.name}")
            print(f"  ├─ Target Directory: {dest_dir}")
            print(f"  └─ Destination File: {dest_file_name}")

            if dry_run:
                print("  └─ [DRY RUN] File copy skipped.")
            else:
                dest_dir.mkdir(parents=True, exist_ok=True)
                shutil.copy2(out_file, dest_file_path)
                print(f"  └─ [SUCCESS] Copied to {dest_file_path}")

        except Exception as e:
            print(f"[ERROR] Failed to process {out_file.name}: {e}")

        print("-" * 60)


def main():
    parser = argparse.ArgumentParser(
        description="Process .out files, extract destination directory, copy and rename them."
    )
    parser.add_argument(
        "directory",
        type=Path,
        help="Directory containing the .out files to process",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Simulate execution without creating directories or copying files",
    )

    args = parser.parse_args()
    process_directory(args.directory, dry_run=args.dry_run)


if __name__ == "__main__":
    main()
