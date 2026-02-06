# Video Resizer

A Python script to batch resize videos for mobile compatibility with configurable output resolution.

## Features

- Batch processes all video files in an input directory
- Supports MP4, MOV, and AVI formats
- Configurable output resolution (360x360, 480x480, 720x720)
- Downscales resolution using high-quality INTER_AREA interpolation
- Reduces frame rate by skipping frames (60fps → 30fps)
- Progress bars for tracking processing status
- Logs failed conversions to `input/failed.txt`

## Installation

```bash
pip install -r requirements.txt
```

## Usage

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
python resize_videos.py -i ./videos -o ./resized -r 480
```

### Options

| Option | Description | Default |
|--------|-------------|---------|
| `-i`, `--input` | Input directory containing videos | `./input` |
| `-o`, `--output` | Output directory for resized videos | `./output` |
| `-r`, `--resolution` | Output resolution (360, 480, 720) | `720` |

## Output

### Specifications

- Resolution: 360x360, 480x480, or 720x720 (configurable)
- Frame rate: 30fps
- Codec: mp4v

### Filename Format

Output files are named with the resolution and frame rate:
```
input: video.mp4
output: video_720_30.mp4
```
