#!/usr/bin/env bash

# -------------------------------------------------------
# Script: dog.sh
#
# Description:
#   Recursively lists all files in the given directory
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
# Example:
#   ./dog.sh -c -v -i 'CMakeLists.txt:*.sh' .
#
# Notes:
#   - You can supply multiple patterns, separated by colons.
#   - Patterns are shell-glob style (e.g. "*.sh" or "CMakeLists.txt").
#   - If no include patterns are specified, the script will process ALL files (except excluded paths).
#   - DOG_EXCLUDE_PATHS env var can be set to customize which paths to skip.
# -------------------------------------------------------

# -----------------------------------------
# Add a version identifier here
# -----------------------------------------
VERSION="0.0.2"

# Default excluded paths as a colon-separated list
DEFAULT_DOG_EXCLUDE_PATHS="cmake-build-debug:cmake-build-release:.idea:.git"

# If DOG_EXCLUDE_PATHS is set, parse it as a colon-separated list.
# Otherwise, fall back to the default.
if [[ -n "$DOG_EXCLUDE_PATHS" ]]; then
  IFS=':' read -ra CUSTOM_PATHS <<< "$DOG_EXCLUDE_PATHS"
  EXCLUDE_PATHS=("${CUSTOM_PATHS[@]}")
else
  IFS=':' read -ra DEFAULT_PATHS <<< "$DEFAULT_DOG_EXCLUDE_PATHS"
  EXCLUDE_PATHS=("${DEFAULT_PATHS[@]}")
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

# A helper function to log debug messages if verbose is enabled
log_debug() {
  if $verbose; then
    echo "[DEBUG] $*"
  fi
}

echo_processed_files() {
    # Print the processed files to stdout
    echo "-----------------------------------------"
    echo "Processed files:"
    for f in "${processed_files[@]}"; do
      echo "$f"
    done
    echo "-----------------------------------------"
}

# Keep track of processed files
processed_files=()

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
      # Next argument should be a string of colon-separated patterns
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
      exit 0
      ;;
    -*)
      echo "Error: Invalid option: $1"
      exit 1
      ;;
    *)
      # Anything that's not recognized above is presumed to be the directory
      dir="$1"
      shift
      ;;
  esac
done

# Log debug messages about our environment/variables
log_debug "DOG_EXCLUDE_PATHS = '$DOG_EXCLUDE_PATHS'"
log_debug "Effective EXCLUDE_PATHS = '${EXCLUDE_PATHS[*]}'"
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
  processed_files+=("$file")  # Record the file name
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
# We must double-escape parentheses so they survive both eval and the shell.
while IFS= read -r file; do
  # If include patterns are on, check if this file matches at least one pattern
  if $USE_INCLUDE_PATTERNS; then
    matched=false
    for pattern in "${INCLUDE_PATTERNS[@]}"; do
      # For a shell-glob match across the *full path*:
      if [[ "$file" == $pattern ]]; then
        matched=true
        break
      fi
      # Alternatively, if you only want to match basenames:
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
done < <(eval "find \"$dir\" \\( $EXCLUDE_PATTERN \\) -prune -o -type f -print")

# -------------------------------------------------------
# Handle clipboard copying (if requested).
# Also show an approximate token count for reference.
# -------------------------------------------------------
if $copy_to_clipboard; then
  if [[ -n "$CLIP_CMD" ]]; then
    log_debug "Copying output to clipboard using '$CLIP_CMD'"
    echo "$output" | eval "$CLIP_CMD"
    # Print the processed files to stdout
    echo_processed_files
    echo "All content copied to clipboard."

    # Approximate token count by simple word count
    estimated_tokens=$(echo -n "$output" | wc -w)
    echo "Words (estimated_tokens) copied to clipboard: $estimated_tokens"
  else
    echo "Error: No suitable clipboard command found. Aborting."
    exit 1
  fi
else
  # If not copying to clipboard, just print everything to stdout.
  echo "$output"
  echo_processed_files
fi
