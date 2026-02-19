import argparse
import os
import cv2
from tqdm import tqdm

# Constants
DEFAULT_RESOLUTION = 720
SUPPORTED_RESOLUTIONS = [360, 480, 720]
TARGET_FPS = 30
SOURCE_FPS = 60

# Default paths
DEFAULT_INPUT = "./input"
DEFAULT_OUTPUT = "./output"

def get_video_files(input_dir: str) -> list:
    """
    Scans input directory recursively for video files.
    Returns list of video file paths.
    """
    allowed_extensions = {'.mp4', '.mov', '.avi'}
    video_files = []
    for root, _, files in os.walk(input_dir):
        for file in files:
            if os.path.splitext(file)[1].lower() in allowed_extensions:
                video_files.append(os.path.join(root, file))
    return sorted(set(video_files))


def resize_video(input_path: str, output_path: str, resolution: int) -> bool:
    """
    Resizes a video to the specified resolution @ 30fps.
    Skips every other frame to achieve 30fps from 60fps source.
    Returns True on success, False on failure.
    """
    cap = cv2.VideoCapture(input_path)
    
    if not cap.isOpened():
        print(f"Error: Cannot open video file: {input_path}")
        return False
    
    # Get source video properties
    source_fps = cap.get(cv2.CAP_PROP_FPS)
    frame_count = int(cap.get(cv2.CAP_PROP_FRAME_COUNT))
    
    # Calculate frame skip factor (e.g., skip every other frame for 60->30fps)
    frame_skip = max(1, round(source_fps / TARGET_FPS))
    
    # Setup video writer
    fourcc = cv2.VideoWriter_fourcc(*'mp4v')
    out = cv2.VideoWriter(output_path, fourcc, TARGET_FPS, (resolution, resolution))
    
    if not out.isOpened():
        print(f"Error: Cannot create output file: {output_path}")
        cap.release()
        return False
    
    frame_idx = 0
    frames_written = 0
    
    # Progress bar for frames
    with tqdm(total=frame_count // frame_skip, desc=os.path.basename(input_path), 
              unit="frames", leave=False) as pbar:
        while True:
            ret, frame = cap.read()
            if not ret:
                break
            
            # Skip frames to achieve target fps
            if frame_idx % frame_skip == 0:
                # Resize frame using INTER_AREA (best for downscaling)
                resized_frame = cv2.resize(frame, (resolution, resolution), 
                                          interpolation=cv2.INTER_AREA)
                out.write(resized_frame)
                frames_written += 1
                pbar.update(1)
            
            frame_idx += 1
    
    cap.release()
    out.release()
    
    return True


def main():
    parser = argparse.ArgumentParser(
        description="Resize videos from 2012x2012 @ 60fps to 720x720 @ 30fps for mobile compatibility"
    )
    parser.add_argument(
        "-i", "--input",
        default=DEFAULT_INPUT,
        help=f"Input directory containing videos (default: {DEFAULT_INPUT})"
    )
    parser.add_argument(
        "-o", "--output",
        default=DEFAULT_OUTPUT,
        help=f"Output directory for resized videos (default: {DEFAULT_OUTPUT})"
    )
    parser.add_argument(
        "-r", "--resolution",
        type=int,
        default=DEFAULT_RESOLUTION,
        choices=SUPPORTED_RESOLUTIONS,
        help=f"Output resolution (square): {SUPPORTED_RESOLUTIONS} (default: {DEFAULT_RESOLUTION})"
    )
    parser.add_argument(
        "-t", "--test",
        type=int,
        default=None,
        help="Process only the first N videos (for test runs)"
    )
    
    args = parser.parse_args()
    
    # Validate input directory
    if not os.path.isdir(args.input):
        print(f"Error: Input directory does not exist: {args.input}")
        return 1
    
    # Create output directory if needed
    os.makedirs(args.output, exist_ok=True)
    
    # Find video files
    video_files = get_video_files(args.input)

    if args.test is not None:
        if args.test <= 0:
            print("Error: --test must be a positive integer")
            return 1
        video_files = video_files[:args.test]
    
    if not video_files:
        print(f"No video files found in {args.input}")
        return 0
    
    print(f"Found {len(video_files)} video(s) to process")
    print(f"Output resolution: {args.resolution}x{args.resolution} @ {TARGET_FPS}fps")

    
    # Process videos with progress bar
    success_count = 0
    failed_files = []
    
    for video_path in tqdm(video_files, desc="Processing videos", unit="video"):
        relative_video_path = os.path.relpath(video_path, args.input)
        relative_dir = os.path.dirname(relative_video_path)

        filename = os.path.basename(video_path)
        name_without_ext = os.path.splitext(filename)[0]
        output_filename = f"{name_without_ext}_{args.resolution}_{TARGET_FPS}.mp4"
        output_dir = os.path.join(args.output, relative_dir)
        os.makedirs(output_dir, exist_ok=True)
        output_path = os.path.join(output_dir, output_filename)
        
        try:
            if resize_video(video_path, output_path, args.resolution):
                success_count += 1
            else:
                failed_files.append(relative_video_path)
        except Exception as e:
            print(f"\nError processing {filename}: {e}")
            failed_files.append(relative_video_path)
    
    # Summary
    print(f"\nCompleted: {success_count}/{len(video_files)} videos processed successfully")
    
    if failed_files:
        print(f"Failed: {', '.join(failed_files)}")
        # Write failures to failed.txt
        failed_log_path = os.path.join(args.input, 'failed.txt')
        with open(failed_log_path, 'a') as f:
            for filename in failed_files:
                f.write(f"{filename} (resize failed)\n")
    
    return 0 if not failed_files else 1


if __name__ == "__main__":
    exit(main())
