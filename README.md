# img2heic


# Usage


```zsh
Usage: img2heic [options] [input_dir] [output_dir]

Convert images to HEIC format using FFmpeg or ImageMagick.

Options:
  -l, --lossless       Use lossless compression (sets quality to 100)
  -q, --quality NUM    Set compression quality (1-100, default: 65)
  -d, --delete         Delete original files after successful conversion
  -o, --overwrite      Overwrite existing HEIC files
  -p, --no-parallel    Disable parallel processing
  -n, --dry-run        Don't actually convert files, just show what would be done
  -s, --silent         Suppress output except errors
  -t, --tool TOOL      Specify conversion tool: 'magick', 'ffmpeg', or 'auto' (default: ffmpeg)
  -e, --ext LIST       Comma-separated list of extensions to convert (e.g. png,jpg)
      --png            Only convert PNG files
      --jpg            Only convert JPG files
      --jpeg           Only convert JPEG files
      --gif            Only convert GIF files
      --bmp            Only convert BMP files
      --tiff           Only convert TIFF files
      --tif            Only convert TIF files
      --webp           Only convert WEBP files
  -h, --help           Show this help message

Examples:
  img2heic --ext png,jpg photos/
  img2heic --png photos/

  ```
