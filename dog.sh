#!/usr/bin/env bash

# -------------------------------------------------------
# Script: dog.sh
#
# Description:
#   Recursively lists all files in the given directory
#   (default: current directory), ignoring blacklisted
#   directories, and prints the file name and contents.
#   Optionally copies the combined output to the clipboard.
#   Optionally *only* includes files if they match a whitelist
#   provided via the command line argument (-w / --whitelist).
#
# Usage:
#   ./dog.sh [-c] [-v] [-V] [-w <pattern1:pattern2:...>] [directory]
#       -c                     Copy output to clipboard
#       -v, --verbose          Enable verbose debug logging
#       -V, --version          Print script version and exit
#       -w, --whitelist <str>  Colon-separated file patterns to ONLY include
#       [directory]            Directory to search (defaults to '.')
#
# Example:
#   ./dog.sh -c -v -w 'CMakeLists.txt:*.sh' .
#
# Notes:
#   - You can supply multiple patterns, separated by colons.
#   - Patterns are shell-glob style (e.g. "*.sh" or "CMakeLists.txt").
#   - If no whitelist is specified, the script will process ALL files (except blacklisted dirs)
#   - DOG_BLACKLIST_DIRS env var can be set to customize the default blacklist
# -------------------------------------------------------

# -----------------------------------------
# Add a version identifier here
# -----------------------------------------
VERSION="0.0.1"

# Default blacklisted directories as a colon-separated list
DEFAULT_BLACKLIST_DIRS="cmake-build-debug:cmake-build-debug:.idea:.git"

# If DOG_BLACKLIST_DIRS is set, parse it as a colon-separated list.
# Otherwise, fall back to the default.
if [[ -n "$DOG_BLACKLIST_DIRS" ]]; then
  IFS=':' read -ra CUSTOM_DIRS <<< "$DOG_BLACKLIST_DIRS"
  BLACKLIST_DIRS=("${CUSTOM_DIRS[@]}")
else
  IFS=':' read -ra DEFAULT_DIRS <<< "$DEFAULT_BLACKLIST_DIRS"
  BLACKLIST_DIRS=("${DEFAULT_DIRS[@]}")
fi

# -- We'll store whitelist patterns here if provided
WHITELISTED=false
WHITELIST_PATTERNS=()

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

echo_processed_files(){
    # print the processed files to stdout as well
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
    -w|--whitelist)
      # Next argument should be a string of colon-separated patterns
      if [[ -n "$2" && ! "$2" =~ ^- ]]; then
        IFS=':' read -ra WHITELIST_PATTERNS <<< "$2"
        WHITELISTED=true
        shift 2
      else
        echo "Error: Missing value after $1"
        exit 1
      fi
      ;;
    -h|--help)
      echo "Usage: $0 [-c] [-v] [-V] [-w <patterns>] [directory]"
      echo "  -c                     Copy output to clipboard"
      echo "  -v, --verbose          Enable verbose debug logging"
      echo "  -V, --version          Print script version and exit"
      echo "  -w, --whitelist <str>  Colon-separated file patterns (e.g. '*.sh:CMakeLists.txt')"
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
log_debug "DOG_BLACKLIST_DIRS = '$DOG_BLACKLIST_DIRS'"
log_debug "Effective BLACKLIST_DIRS = '${BLACKLIST_DIRS[*]}'"
log_debug "Clipboard command = '$CLIP_CMD'"
log_debug "Copy to clipboard? = '$copy_to_clipboard'"
log_debug "Verbose? = '$verbose'"
log_debug "Target directory = '$dir'"
log_debug "Whitelist enabled? = '$WHITELISTED'"
if $WHITELISTED; then
  log_debug "Whitelist patterns: '${WHITELIST_PATTERNS[*]}'"
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
# Build the find command to prune blacklisted directories.
# -------------------------------------------------------
EXCLUDE_PATTERN=""
for d in "${BLACKLIST_DIRS[@]}"; do
  EXCLUDE_PATTERN="$EXCLUDE_PATTERN -name \"$d\" -o"
done
# Remove the trailing '-o'
EXCLUDE_PATTERN="${EXCLUDE_PATTERN% -o}"

log_debug "EXCLUDE_PATTERN = '$EXCLUDE_PATTERN'"

# Use the pattern in a find command that prunes matching directories.
# We must double-escape parentheses so that they survive the eval and the shell.
while IFS= read -r file; do
  # If whitelisting is on, check if this file matches at least one pattern
  if $WHITELISTED; then
    matched=false
    for pattern in "${WHITELIST_PATTERNS[@]}"; do
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
    # print the processed files to stdout as well
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
  # print the processed files to stdout as well
  echo_processed_files
fi
