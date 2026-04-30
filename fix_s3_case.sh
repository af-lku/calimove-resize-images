#!/usr/bin/env bash
# Rename S3 video files where the 4-char code segment contains uppercase letters.
# The 4-char code (e.g. n20X -> n20x) is lowercased in the destination key.
# By default this is a dry-run — pass --apply to actually rename files.

set -uo pipefail

print_usage() {
  cat <<EOF
Usage: $(basename "$0") --bucket BUCKET [--profile PROFILE] [--prefix PREFIX] [--apply]

Scans an S3 bucket for video files whose 4-char code segment (e.g. n20X)
contains uppercase letters, and renames them to the all-lowercase version.

Options:
  --bucket BUCKET    S3 bucket name (required)
  --profile PROFILE  AWS CLI profile to use (default: default profile)
  --prefix PREFIX    S3 key prefix to scan (default: "")
  --apply            Actually perform the copy+delete (default: dry-run)
  -h, --help         Show this help
EOF
}

bucket=""
profile=""
prefix=""
apply=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --bucket) bucket="$2"; shift 2 ;;
    --profile) profile="$2"; shift 2 ;;
    --prefix) prefix="$2"; shift 2 ;;
    --apply) apply=true; shift ;;
    -h|--help) print_usage; exit 0 ;;
    *) echo "Error: Unknown argument: $1"; print_usage; exit 1 ;;
  esac
done

if [[ -z "$bucket" ]]; then
  echo "Error: --bucket is required"
  print_usage
  exit 1
fi

if ! command -v aws >/dev/null 2>&1; then
  echo "Error: aws CLI is not installed or not in PATH"
  exit 1
fi

aws_opts=()
[[ -n "$profile" ]] && aws_opts+=(--profile "$profile")

if [[ "$apply" == false ]]; then
  echo "DRY RUN — pass --apply to execute renames"
fi
echo "Scanning s3://${bucket}/${prefix} ..."
[[ -n "$profile" ]] && echo "AWS profile: ${profile}"
echo ""

rename_count=0
skip_count=0
error_count=0

while IFS= read -r key; do
  [[ -z "$key" ]] && continue

  filename="$(basename "$key")"
  dir="$(dirname "$key")"
  [[ "$dir" == "." ]] && dir=""

  # Match: <anything>_<4char>_<resolution>_<fps>.mp4
  # 4-char code: starts with N/P/X (any case), followed by 3 chars from [NPXnpx0-9]
  if [[ "$filename" =~ _([NPXnpx][NPXnpx0-9]{3})_[0-9]+_[0-9]+\.mp4$ ]]; then
    code="${BASH_REMATCH[1]}"
    lowered="$(printf '%s' "$code" | tr 'A-Z' 'a-z')"

    if [[ "$code" == "$lowered" ]]; then
      skip_count=$((skip_count + 1))
      continue
    fi

    new_filename="${filename/_${code}_/_${lowered}_}"
    if [[ -n "$dir" ]]; then
      new_key="${dir}/${new_filename}"
    else
      new_key="$new_filename"
    fi

    echo "RENAME: s3://${bucket}/${key}"
    echo "     -> s3://${bucket}/${new_key}"

    rename_count=$((rename_count + 1))

    if [[ "$apply" == true ]]; then
      if aws "${aws_opts[@]}" s3 cp "s3://${bucket}/${key}" "s3://${bucket}/${new_key}" --no-progress; then
        aws "${aws_opts[@]}" s3 rm "s3://${bucket}/${key}"
      else
        echo "  ERROR: copy failed for ${key}" >&2
        error_count=$((error_count + 1))
      fi
    fi
  else
    skip_count=$((skip_count + 1))
  fi
done < <(
  aws "${aws_opts[@]}" s3api list-objects-v2 \
    --bucket "$bucket" \
    --prefix "$prefix" \
    --query 'Contents[].Key' \
    --output text \
  | tr '\t' '\n' \
  | grep -i '\.mp4$'
)

echo ""
if [[ "$apply" == true ]]; then
  echo "Done. Renamed: ${rename_count}  Skipped (already correct): ${skip_count}  Errors: ${error_count}"
  [[ $error_count -gt 0 ]] && exit 1
else
  echo "Dry run complete. Would rename: ${rename_count}  Already correct: ${skip_count}"
  echo "Run with --apply to execute."
fi
