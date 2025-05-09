#!/bin/bash
# filepath: /Users/max/scripts/img2heic.sh

# img2heic - Convert images to HEIC format
# Usage: img2heic [options] [input_dir] [output_dir]

set -e

# Default settings
QUALITY=65
LOSSLESS=false
VERBOSE=true
DELETE_ORIGINALS=false
OVERWRITE=false
PARALLEL=true
DRY_RUN=false
TOOL="magick" 
INPUT_DIR="."
OUTPUT_DIR=""

# Default extensions
# DEFAULT_EXTENSIONS="png jpg jpeg gif bmp tiff tif webp PNG JPG JPEG GIF BMP TIFF TIF WEBP"
DEFAULT_EXTENSIONS="png gif bmp tiff tif webp PNG JPG JPEG GIF BMP TIFF TIF WEBP"
EXTENSIONS="$DEFAULT_EXTENSIONS"

# Show help message
show_help() {
  cat << EOF
Usage: $(basename "$0") [options] [input_dir] [output_dir]

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
  $(basename "$0") --ext png,jpg photos/
  $(basename "$0") --png photos/
EOF
}


# Check if a command exists
command_exists() {
  command -v "$1" >/dev/null 2>&1
}

# Process arguments
while [ $# -gt 0 ]; do
  case "$1" in
    -l|--lossless)
      LOSSLESS=true
      shift
      ;;
    -q|--quality)
      if [[ "$2" =~ ^[0-9]+$ ]] && [ "$2" -ge 1 ] && [ "$2" -le 100 ]; then
        QUALITY="$2"
        shift 2
      else
        echo "Error: Quality must be between 1 and 100" >&2
        exit 1
      fi
      ;;
    -d|--delete)
      DELETE_ORIGINALS=true
      shift
      ;;
    -o|--overwrite)
      OVERWRITE=true
      shift
      ;;
    -p|--no-parallel)
      PARALLEL=false
      shift
      ;;
    -n|--dry-run)
      DRY_RUN=true
      shift
      ;;
    -s|--silent)
      VERBOSE=false
      shift
      ;;
    -e|--ext)
        if [ -n "$2" ]; then
          EXTENSIONS=$(echo "$2" | tr ',' ' ')
          shift 2
        else
          echo "Error: --ext requires a comma-separated list" >&2
          exit 1
        fi
        ;;
    --png)
      EXTENSIONS="png PNG"
      shift
      ;;
    --jpg)
      EXTENSIONS="jpg JPG"
      shift
      ;;
    --jpeg)
      EXTENSIONS="jpeg JPEG"
      shift
      ;;
    --gif)
      EXTENSIONS="gif GIF"
      shift
      ;;
    --bmp)
      EXTENSIONS="bmp BMP"
      shift
      ;;
    --tiff)
      EXTENSIONS="tiff TIFF"
      shift
      ;;
    --tif)
      EXTENSIONS="tif TIF"
      shift
      ;;
    --webp)
      EXTENSIONS="webp WEBP"
      shift
      ;;      
    -t|--tool)
      case "$2" in
        magick|ffmpeg|auto)
          TOOL="$2"
          shift 2
          ;;
        *)
          echo "Error: Tool must be 'magick', 'ffmpeg', or 'auto'" >&2
          exit 1
          ;;
      esac
      ;;
    -h|--help)
      show_help
      exit 0
      ;;
    -*)
      echo "Error: Unknown option: $1" >&2
      show_help
      exit 1
      ;;
    *)
      if [ -z "$INPUT_DIR" ] || [ "$INPUT_DIR" = "." ]; then
        INPUT_DIR="$1"
      elif [ -z "$OUTPUT_DIR" ]; then
        OUTPUT_DIR="$1"
      else
        echo "Error: Too many arguments" >&2
        show_help
        exit 1
      fi
      shift
      ;;
  esac
done

# Set output directory to input directory if not specified
if [ -z "$OUTPUT_DIR" ]; then
  OUTPUT_DIR="$INPUT_DIR"
fi

# Adjust quality for lossless mode
if [ "$LOSSLESS" = true ]; then
  QUALITY=100
  [ "$VERBOSE" = true ] && echo "Lossless mode enabled. Using quality = 100."
fi

# Check dependencies and select tool
HAVE_MAGICK=false
HAVE_FFMPEG=false

if command_exists magick; then
  HAVE_MAGICK=true
fi

if command_exists ffmpeg; then
  HAVE_FFMPEG=true
fi

if [ "$TOOL" = "auto" ]; then
  if [ "$HAVE_FFMPEG" = true ]; then
    TOOL="ffmpeg"
  elif [ "$HAVE_MAGICK" = true ]; then
    TOOL="magick"
  else
    echo "Error: Neither FFmpeg nor ImageMagick found. Please install one of them." >&2
    exit 1
  fi
else
  # User specified a tool, make sure it's available
  if [ "$TOOL" = "magick" ] && [ "$HAVE_MAGICK" = false ]; then
    echo "Error: ImageMagick (magick command) not found. Please install it." >&2
    exit 1
  fi
  
  if [ "$TOOL" = "ffmpeg" ] && [ "$HAVE_FFMPEG" = false ]; then
    echo "Error: FFmpeg not found. Please install it." >&2
    exit 1
  fi
fi

[ "$VERBOSE" = true ] && echo "Using $TOOL for conversion."

# Check if GNU Parallel is available for parallel processing
if [ "$PARALLEL" = true ] && ! command_exists parallel; then
  [ "$VERBOSE" = true ] && echo "Warning: GNU Parallel not found. Falling back to sequential processing."
  PARALLEL=false
fi

# Check if directories exist
if [ ! -d "$INPUT_DIR" ]; then
  echo "Error: Input directory '$INPUT_DIR' does not exist" >&2
  exit 1
fi

# Create output folder if it doesn't exist
if [ "$DRY_RUN" = false ]; then
  mkdir -p "$OUTPUT_DIR"
fi

# Process a single image
convert_image() {
  local img="$1"
  local output="$2"
  
  if [ -f "$output" ] && [ "$OVERWRITE" = false ]; then
    [ "$VERBOSE" = true ] && echo "Skipping $img (output file already exists)"
    return 0
  fi
  
  [ "$VERBOSE" = true ] && echo "Converting $img → $output"
  
  if [ "$DRY_RUN" = false ]; then

    # using ImageMagick -> "magick" for conversion
    if [ "$TOOL" = "magick" ]; then
      if ! magick "$img" -quality "$QUALITY" "$output"; then
        echo "Error: Failed to convert $img using ImageMagick" >&2
        return 1
      fi

    # using "ffmpeg" for conversion
    elif [ "$TOOL" = "ffmpeg" ]; then
      # FFmpeg uses different quality scale (lower is better)
      local ffmpeg_quality=$((51 - QUALITY / 2))
      # Ensure quality is in valid range (0-51)
      if [ "$ffmpeg_quality" -gt 51 ]; then ffmpeg_quality=51; fi
      if [ "$ffmpeg_quality" -lt 0 ]; then ffmpeg_quality=0; fi

      local ffmpeg_opts="-loglevel error -y"
      [ "$VERBOSE" = true ] || ffmpeg_opts="${ffmpeg_opts} -v quiet"

      if ! ffmpeg $ffmpeg_opts -i "$img" -vf "scale=iw:ih" -c:v libx265 -crf "$ffmpeg_quality" -f heic "$output"; then
        echo "Error: Failed to convert $img using FFmpeg" >&2
        return 1
      fi
    fi
    if [ "$DELETE_ORIGINALS" = true ]; then
      rm "$img"
    fi
  fi
  
  return 0
}


# Enable nullglob to handle no matches gracefully
shopt -s nullglob

# Collect all images to convert
images=()
for ext in $EXTENSIONS; do
  for img in "$INPUT_DIR"/*.$ext; do
    [ -e "$img" ] || continue
    filename=$(basename -- "$img")
    name="${filename%.*}"
    output="$OUTPUT_DIR/$name.heic"
    images+=("$img:$output")
  done
done

# Check if any files were found
if [ ${#images[@]} -eq 0 ]; then
  echo "No supported image files found in $INPUT_DIR"
  exit 0
fi

[ "$VERBOSE" = true ] && echo "Found ${#images[@]} images to convert"

# Process images
if [ "$PARALLEL" = true ]; then
  # Process using GNU Parallel
  [ "$VERBOSE" = true ] && echo "Using parallel processing"
  
  export -f convert_image
  export VERBOSE DRY_RUN DELETE_ORIGINALS QUALITY OVERWRITE TOOL
  
  printf '%s\n' "${images[@]}" | \
    parallel --eta --colsep ':' "convert_image {1} {2}"
else
  # Process sequentially
  total=${#images[@]}
  count=0
  
  for item in "${images[@]}"; do
    img="${item%%:*}"
    output="${item#*:}"
    count=$((count+1))
    
    [ "$VERBOSE" = true ] && echo "[$count/$total] Processing"
    convert_image "$img" "$output"
  done
fi

[ "$VERBOSE" = true ] && echo "All conversions done."
exit 0
