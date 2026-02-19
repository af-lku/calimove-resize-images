# Video Resizer

A project to batch resize videos for mobile compatibility with configurable output resolution.

## Features

- Batch processes all video files in an input directory (including nested folders)
- Supports MP4, MOV, and AVI formats
- Configurable output resolution (360x360, 480x480, 720x720)
- Reduces frame rate to 30fps
- Preserves folder structure from input to output
- Test mode to process only the first N videos
- Logs failed conversions to `<input>/failed.txt`

## Python Script

Uses OpenCV (`resize_videos.py`).

### Setup

```bash
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
```

On Windows (PowerShell):

```powershell
python -m venv .venv
.venv\Scripts\Activate.ps1
pip install -r requirements.txt
```

### Usage

```bash
# Using default directories and resolution (./input, ./output, 720x720)
python resize_videos.py

# Custom resolution
python resize_videos.py -r 360   # 360x360
python resize_videos.py -r 480   # 480x480
python resize_videos.py -r 720   # 720x720 (default)

# Custom input/output directories
python resize_videos.py -i /path/to/videos -o /path/to/output

# Combine options
python resize_videos.py -i ./videos -o ./resized -r 480 -t 10
```

Or without activating the environment:

```bash
./.venv/bin/python resize_videos.py -i ./videos -o ./resized -r 480 -t 10
```

### Options

| Option               | Description                             | Default    |
| -------------------- | --------------------------------------- | ---------- |
| `-i`, `--input`      | Input directory containing videos       | `./input`  |
| `-o`, `--output`     | Output directory for resized videos     | `./output` |
| `-r`, `--resolution` | Output resolution (360, 480, 720)       | `720`      |
| `-t`, `--test`       | Process only first N videos (test runs) | disabled   |

## Bash Script

Uses FFmpeg (`resize_videos.sh`) and is usually much faster on macOS Apple Silicon.

### Setup

```bash
brew install ffmpeg
chmod +x resize_videos.sh
```

### Usage

```bash
# Default run
./resize_videos.sh

# Custom input/output/resolution with test limit
./resize_videos.sh --input ../assets --output ./output --resolution 360 --test 10

# Maximum compatibility for older Android devices
./resize_videos.sh --input ../assets --output ./output --resolution 360 --test 10 --compat old-android
```

### Options

| Option               | Description                                 | Default    |
| -------------------- | ------------------------------------------- | ---------- |
| `-i`, `--input`      | Input directory containing videos           | `./input`  |
| `-o`, `--output`     | Output directory for resized videos         | `./output` |
| `-r`, `--resolution` | Output resolution (360, 480, 720)           | `720`      |
| `-t`, `--test`       | Process only first N videos (test runs)     | disabled   |
| `-c`, `--compat`     | Compatibility mode: `auto` or `old-android` | `auto`     |

## Output

### Specifications

- Resolution: 360x360, 480x480, or 720x720 (configurable)
- Frame rate: 30fps
- Codec:
  - Python script: `mp4v`
  - Bash script: H.264 (`h264_videotoolbox` in `auto`, `libx264 baseline` in `old-android`)

### Filename Format

Output files are named with the resolution and frame rate:

```
input: video.mp4
output: video_720_30.mp4
```

When input has nested folders, output preserves the same folder structure:

```
input: events/2025/video.mp4
output: events/2025/video_720_30.mp4
```
