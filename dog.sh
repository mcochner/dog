#!/usr/bin/env bash

# -------------------------------------------------------
# Script: dog.sh
#
# Description:
#   Recursively lists all text files in the given directory
#   (default: current directory), ignoring excluded paths,
#   and prints the file name and contents.
#   Optionally copies the combined output to the clipboard.
#   Optionally only includes files if they match patterns
#   provided via the command line argument (-i / --include).
#
# Usage:
#   ./dog.sh [-c] [-v] [-V] [-i <pattern1:pattern2:...>] [directory]
#       -c                     Copy output to clipboard
#       -v, --verbose          Enable verbose debug logging
#       -V, --version          Print script version and exit
#       -i, --include <str>    Colon-separated file patterns to ONLY include
#       [directory]            Directory to search (defaults to '.')
#
# Environment Variables:
#   - DOG_EXCLUDE_PATHS: colon-separated list of directories to exclude
#   - DOG_MAX_FILE_SIZE: integer (bytes). If set, skip files larger than this.
#                        If not set, defaults to 1 MB (1048576 bytes).
#
# Example:
#   ./dog.sh -c -v -i 'CMakeLists.txt:*.sh' .
#
# Notes:
#   - If no include patterns are specified, the script processes ALL files
#     (except excluded paths).
#   - Patterns are shell-glob style (e.g. "*.sh" or "CMakeLists.txt").
#   - By default, the script uses a simple heuristic to skip binary files.
#   - If DOG_MAX_FILE_SIZE is set, files larger than that size are skipped.
# -------------------------------------------------------

VERSION="0.0.3"

# Default excluded paths as a colon-separated list
DEFAULT_DOG_EXCLUDE_PATHS="cmake-build-debug:cmake-build-release:.idea:.git"
# Default maximum file size (1 MB) if not set
DEFAULT_DOG_MAX_FILE_SIZE=1048576


# If DOG_EXCLUDE_PATHS is set, parse it as a colon-separated list.
# Otherwise, fall back to the default.
if [[ -n "$DOG_EXCLUDE_PATHS" ]]; then
  IFS=':' read -ra CUSTOM_PATHS <<< "$DOG_EXCLUDE_PATHS"
  EXCLUDE_PATHS=("${CUSTOM_PATHS[@]}")
else
  IFS=':' read -ra DEFAULT_PATHS <<< "$DEFAULT_DOG_EXCLUDE_PATHS"
  EXCLUDE_PATHS=("${DEFAULT_PATHS[@]}")
fi


if [[ -z "$DOG_MAX_FILE_SIZE" ]]; then
  DOG_MAX_FILE_SIZE="$DEFAULT_DOG_MAX_FILE_SIZE"
fi

# We'll store file patterns here if provided
USE_INCLUDE_PATTERNS=false
INCLUDE_PATTERNS=()

# Detect the best available clipboard command
# Priority order: pbcopy -> xclip -> xsel
if command -v pbcopy &> /dev/null; then
  CLIP_CMD="pbcopy"
elif command -v xclip &> /dev/null; then
  CLIP_CMD="xclip -selection clipboard"
elif command -v xsel &> /dev/null; then
  CLIP_CMD="xsel --clipboard --input"
else
  CLIP_CMD=""
fi

# By default, don't copy to clipboard unless -c is used
copy_to_clipboard=false

# By default, verbose logging is off
verbose=false

# Keep track of processed files
processed_files=()

# A helper function for debug logging
log_debug() {
  if $verbose; then
    echo "[DEBUG] $*"
  fi
}

echo_processed_files() {
  echo "-----------------------------------------"
  echo "Processed files:"
  for f in "${processed_files[@]}"; do
    echo "$f"
  done
  echo "-----------------------------------------"
}

# ------------------------------------------------------------------
# Parse command-line arguments:
# ------------------------------------------------------------------
dir="."  # Default directory
while [[ $# -gt 0 ]]; do
  case "$1" in
    -c)
      copy_to_clipboard=true
      shift
      ;;
    -v|--verbose)
      verbose=true
      shift
      ;;
    -V|--version)
      echo "dog.sh version: $VERSION"
      exit 0
      ;;
    -i|--include)
      if [[ -n "$2" && ! "$2" =~ ^- ]]; then
        IFS=':' read -ra INCLUDE_PATTERNS <<< "$2"
        USE_INCLUDE_PATTERNS=true
        shift 2
      else
        echo "Error: Missing value after $1"
        exit 1
      fi
      ;;
    -h|--help)
      echo "Usage: $0 [-c] [-v] [-V] [-i <patterns>] [directory]"
      echo "  -c                     Copy output to clipboard"
      echo "  -v, --verbose          Enable verbose debug logging"
      echo "  -V, --version          Print script version and exit"
      echo "  -i, --include <str>    Colon-separated file patterns (e.g. '*.sh:CMakeLists.txt')"
      echo "  [directory]            Directory to search (defaults to '.')"
      echo
      echo "Environment variables:"
      echo "  DOG_EXCLUDE_PATHS      Colon-separated directories to exclude."
      echo "  DOG_MAX_FILE_SIZE      If set, skip files larger than this (in bytes)."
      echo "                         Defaults to 1 MB (1048576)."
      echo
      exit 0
      ;;
    -*)
      echo "Error: Invalid option: $1"
      exit 1
      ;;
    *)
      dir="$1"
      shift
      ;;
  esac
done

# Log debug messages about our environment/variables
log_debug "DOG_EXCLUDE_PATHS = '$DOG_EXCLUDE_PATHS'"
log_debug "Effective EXCLUDE_PATHS = '${EXCLUDE_PATHS[*]}'"
log_debug "DOG_MAX_FILE_SIZE = '$DOG_MAX_FILE_SIZE'"
log_debug "Clipboard command = '$CLIP_CMD'"
log_debug "Copy to clipboard? = '$copy_to_clipboard'"
log_debug "Verbose? = '$verbose'"
log_debug "Target directory = '$dir'"
log_debug "Use include patterns? = '$USE_INCLUDE_PATTERNS'"
if $USE_INCLUDE_PATTERNS; then
  log_debug "Include patterns: '${INCLUDE_PATTERNS[*]}'"
fi

# We'll build our output in a variable so we can optionally copy it
output=""

# Function that handles a single file
process_file() {
  local file="$1"

  # Check file size; skip if larger than DOG_MAX_FILE_SIZE
  local filesize
  if [[ "$OSTYPE" == "darwin"* ]]; then
    filesize=$(stat -f%z "$file" 2>/dev/null || echo 0)
  else
    filesize=$(stat -c%s "$file" 2>/dev/null || echo 0)
  fi

  if (( filesize > DOG_MAX_FILE_SIZE )); then
    log_debug "Skipping large file (size: $filesize bytes): $file"
    return
  fi

  # Check if readable
  if [[ ! -r "$file" ]]; then
    log_debug "Skipping unreadable file: $file"
    return
  fi

  # Basic check for binary files (heuristic)
  local mimetype
  mimetype=$(file --mime-type -b "$file" 2>/dev/null || true)
  if [[ $mimetype != text/* ]]; then
    log_debug "Skipping binary (or non-text) file: $file (mime-type: $mimetype)"
    return
  fi

  # If we got here, we consider the file safe to print
  processed_files+=("$file")

  output+="
-----------------------------------------
  START OF FILE: $file
-----------------------------------------
$(cat "$file")
-----------------------------------------
  END OF FILE: $file
-----------------------------------------
"
}

# -------------------------------------------------------
# Build the find command to prune excluded paths.
# -------------------------------------------------------
EXCLUDE_PATTERN=""
for path in "${EXCLUDE_PATHS[@]}"; do
  EXCLUDE_PATTERN="$EXCLUDE_PATTERN -name \"$path\" -o"
done
# Remove the trailing '-o'
EXCLUDE_PATTERN="${EXCLUDE_PATTERN% -o}"

log_debug "EXCLUDE_PATTERN = '$EXCLUDE_PATTERN'"

# Use the pattern in a find command that prunes matching directories.
# Switch to -print0 and read -r -d '' for robust handling of special chars/spaces.
while IFS= read -r -d '' file; do
  # If include patterns are on, check if this file matches at least one pattern
  if $USE_INCLUDE_PATTERNS; then
    matched=false
    for pattern in "${INCLUDE_PATTERNS[@]}"; do
      # Full-path shell-glob matching
      if [[ "$file" == $pattern ]]; then
        matched=true
        break
      fi
      # Alternatively, to match basenames only:
      # if [[ "$(basename "$file")" == $pattern ]]; then
      #   matched=true
      #   break
      # fi
    done
    if ! $matched; then
      continue  # Skip this file if it doesn't match any pattern
    fi
  fi

  process_file "$file"
done < <(eval "find \"$dir\" \\( $EXCLUDE_PATTERN \\) -prune -o -type f -print0")

# -------------------------------------------------------
# Handle clipboard copying (if requested).
# Also show an approximate word count for reference.
# -------------------------------------------------------
if $copy_to_clipboard; then
  if [[ -n "$CLIP_CMD" ]]; then
    log_debug "Copying output to clipboard using '$CLIP_CMD'"
    echo "$output" | eval "$CLIP_CMD"
    # Print the processed files to stdout
    echo_processed_files
    echo "All content copied to clipboard."

    # Approximate token count by simple word count
    estimated_words=$(echo -n "$output" | wc -w)
    echo "Approx. word count copied to clipboard: $estimated_words"
  else
    echo "Error: No suitable clipboard command found. Aborting."
    exit 1
  fi
else
  # If not copying to clipboard, just print everything to stdout.
  echo "$output"
  echo_processed_files
fi
