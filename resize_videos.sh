#!/usr/bin/env bash

set -uo pipefail

DEFAULT_RESOLUTION=720
TARGET_FPS=30
DEFAULT_INPUT="./input"
DEFAULT_OUTPUT="./output"
DEFAULT_COMPAT="auto"
BITRATE_360="800k"
BITRATE_480="1400k"
BITRATE_720="2500k"

input_dir="$DEFAULT_INPUT"
output_dir="$DEFAULT_OUTPUT"
resolution="$DEFAULT_RESOLUTION"
test_count=""
compat_mode="$DEFAULT_COMPAT"

print_usage() {
  cat <<EOF
Usage: $(basename "$0") [options]

Resize videos recursively for mobile compatibility using FFmpeg.

Options:
  -i, --input DIR         Input directory containing videos (default: ./input)
  -o, --output DIR        Output directory for resized videos (default: ./output)
  -r, --resolution VALUE  Output resolution (360, 480, 720; default: 720)
  -t, --test COUNT        Process only first COUNT videos (for test runs)
  -c, --compat MODE       Compatibility mode: auto | old-android (default: auto)
  -h, --help              Show this help message
EOF
}

is_positive_integer() {
  [[ "$1" =~ ^[1-9][0-9]*$ ]]
}

format_duration() {
  local total_seconds=$1
  local hours=$((total_seconds / 3600))
  local minutes=$(((total_seconds % 3600) / 60))
  local seconds=$((total_seconds % 60))

  if [[ $hours -gt 0 ]]; then
    printf "%02d:%02d:%02d" "$hours" "$minutes" "$seconds"
  else
    printf "%02d:%02d" "$minutes" "$seconds"
  fi
}

print_progress() {
  local processed=$1
  local total=$2
  local elapsed=$3
  local eta=$4
  local bar_width=30
  local filled=$((processed * bar_width / total))
  local empty=$((bar_width - filled))
  local percent=$((processed * 100 / total))

  local filled_bar
  local empty_bar
  filled_bar="$(printf "%${filled}s" "" | tr ' ' '#')"
  empty_bar="$(printf "%${empty}s" "" | tr ' ' '-')"

  printf "\r[%s%s] %3d%% (%d/%d) elapsed %s eta %s" \
    "$filled_bar" "$empty_bar" "$percent" "$processed" "$total" \
    "$(format_duration "$elapsed")" "$(format_duration "$eta")"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -i|--input)
      input_dir="$2"
      shift 2
      ;;
    -o|--output)
      output_dir="$2"
      shift 2
      ;;
    -r|--resolution)
      resolution="$2"
      shift 2
      ;;
    -t|--test)
      test_count="$2"
      shift 2
      ;;
    -c|--compat)
      compat_mode="$2"
      shift 2
      ;;
    -h|--help)
      print_usage
      exit 0
      ;;
    *)
      echo "Error: Unknown argument: $1"
      print_usage
      exit 1
      ;;
  esac
done

if [[ "$resolution" != "360" && "$resolution" != "480" && "$resolution" != "720" ]]; then
  echo "Error: --resolution must be one of: 360, 480, 720"
  exit 1
fi

if [[ "$compat_mode" != "auto" && "$compat_mode" != "old-android" ]]; then
  echo "Error: --compat must be one of: auto, old-android"
  exit 1
fi

case "$resolution" in
  360) video_bitrate="$BITRATE_360" ;;
  480) video_bitrate="$BITRATE_480" ;;
  720) video_bitrate="$BITRATE_720" ;;
esac

if [[ -n "$test_count" ]] && ! is_positive_integer "$test_count"; then
  echo "Error: --test must be a positive integer"
  exit 1
fi

if [[ ! -d "$input_dir" ]]; then
  echo "Error: Input directory does not exist: $input_dir"
  exit 1
fi

if ! command -v ffmpeg >/dev/null 2>&1; then
  echo "Error: ffmpeg is not installed or not in PATH"
  exit 1
fi

mkdir -p "$output_dir"

input_dir_abs="$(cd "$input_dir" && pwd)"
output_dir_abs="$(mkdir -p "$output_dir" && cd "$output_dir" && pwd)"

video_files=()
while IFS= read -r video_path; do
  video_files+=("$video_path")
done < <(
  find "$input_dir_abs" -type f \( -iname "*.mp4" -o -iname "*.mov" -o -iname "*.avi" \) | sort
)

if [[ -n "$test_count" && ${#video_files[@]} -gt "$test_count" ]]; then
  video_files=("${video_files[@]:0:$test_count}")
fi

total_videos=${#video_files[@]}
if [[ $total_videos -eq 0 ]]; then
  echo "No video files found in $input_dir"
  exit 0
fi

echo "Found $total_videos video(s) to process"
echo "Output resolution: ${resolution}x${resolution} @ ${TARGET_FPS}fps"
echo "Video bitrate: ${video_bitrate}"
echo "Compatibility mode: ${compat_mode}"

success_count=0
failed_files=()
warning_files=()
start_time=$(date +%s)
warning_log_path="$input_dir_abs/warnings.txt"
: > "$warning_log_path"

index=0
print_progress 0 "$total_videos" 0 0
for video_path in "${video_files[@]}"; do
  index=$((index + 1))

  relative_video_path="${video_path#$input_dir_abs/}"
  relative_dir="$(dirname "$relative_video_path")"

  filename="$(basename "$video_path")"
  name_without_ext="${filename%.*}"
  output_filename="${name_without_ext}_${resolution}_${TARGET_FPS}.mp4"

  if [[ "$relative_dir" == "." ]]; then
    output_subdir="$output_dir_abs"
  else
    output_subdir="$output_dir_abs/$relative_dir"
  fi

  mkdir -p "$output_subdir"
  output_path="$output_subdir/$output_filename"

  if [[ "$compat_mode" == "old-android" ]]; then
    ffmpeg_cmd=(
      ffmpeg -hide_banner -loglevel error -y
      -i "$video_path"
      -vf "fps=${TARGET_FPS},scale=${resolution}:${resolution}:flags=lanczos"
      -an
      -c:v libx264 -preset veryfast
      -profile:v baseline -level:v 3.0
      -pix_fmt yuv420p
      -movflags +faststart
      -b:v "$video_bitrate"
      "$output_path"
    )
  else
    ffmpeg_cmd=(
      ffmpeg -hide_banner -loglevel error -y
      -i "$video_path"
      -vf "fps=${TARGET_FPS},scale=${resolution}:${resolution}:flags=lanczos"
      -an
      -c:v h264_videotoolbox -b:v "$video_bitrate"
      "$output_path"
    )
  fi

  ffmpeg_log_file="$(mktemp)"
  if "${ffmpeg_cmd[@]}" 2>"$ffmpeg_log_file"; then
    success_count=$((success_count + 1))

    if grep -Eiq "invalid nal unit|error splitting the input into nal units|error submitting packet to decoder|missing picture in access unit|corrupt|error while decoding" "$ffmpeg_log_file"; then
      warning_files+=("$relative_video_path")
      {
        echo "FILE: $relative_video_path"
        sed 's/^/  /' "$ffmpeg_log_file"
        echo ""
      } >> "$warning_log_path"
    fi
  else
    failed_files+=("$relative_video_path")
    echo "Error processing: $relative_video_path"
  fi
  rm -f "$ffmpeg_log_file"

  now_time=$(date +%s)
  elapsed_seconds=$((now_time - start_time))
  avg_seconds=$((elapsed_seconds / index))
  remaining=$((total_videos - index))
  eta_seconds=$((avg_seconds * remaining))
  print_progress "$index" "$total_videos" "$elapsed_seconds" "$eta_seconds"
done

echo ""
echo "Completed: ${success_count}/${total_videos} videos processed successfully"

if [[ ${#warning_files[@]} -gt 0 ]]; then
  echo "Warnings: ${#warning_files[@]} file(s) had decode warnings"
  echo "Warning details: $warning_log_path"
else
  rm -f "$warning_log_path"
fi

if [[ ${#failed_files[@]} -gt 0 ]]; then
  echo "Failed: ${failed_files[*]}"
  failed_log_path="$input_dir_abs/failed.txt"
  for failed_file in "${failed_files[@]}"; do
    echo "$failed_file (resize failed)" >> "$failed_log_path"
  done
  exit 1
fi

exit 0
