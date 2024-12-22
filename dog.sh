#!/usr/bin/env bash

# -------------------------------------------------------
# Script: dog.sh
#
# Description:
#   Recursively lists all files in the given directory
#   (default: current directory), ignoring blacklisted
#   directories, and prints the file name and contents.
#   Optionally copies the combined output to the clipboard.
#
# Usage:
#   ./dog.sh [-c] [-v] [directory]
#       -c           Copy output to clipboard
#       -v           Enable verbose debug logging
#       [directory]  Directory to search (defaults to '.')
#
# Example:
#   ./dog.sh -c -v .
# -------------------------------------------------------

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

# Parse command-line options
while getopts "chv" opt; do
  case "$opt" in
    c)
      copy_to_clipboard=true
      ;;
    v)
      verbose=true
      ;;
    h)
      echo "Usage: $0 [-c] [-v] [directory]"
      echo "  -c           Copy output to the clipboard"
      echo "  -v           Enable verbose debug logging"
      echo "  [directory]  Directory to search (defaults to '.')"
      exit 0
      ;;
    \?)
      echo "Error: Invalid option: -$OPTARG"
      exit 1
      ;;
  esac
done
shift $((OPTIND - 1))

# Use either the provided directory or '.' if none is given
dir="${1:-.}"

# Log debug messages about our environment/variables
log_debug "DOG_BLACKLIST_DIRS = '$DOG_BLACKLIST_DIRS'"
log_debug "Effective BLACKLIST_DIRS = '${BLACKLIST_DIRS[*]}'"
log_debug "Clipboard command = '$CLIP_CMD'"
log_debug "Copy to clipboard? = '$copy_to_clipboard'"
log_debug "Verbose? = '$verbose'"
log_debug "Target directory = '$dir'"

# We'll build our output in a variable so we can optionally copy it
output=""

# Function that handles a single file
process_file() {
  local file="$1"
  # Add clear delimiters around each file’s content
  output+="\n"
  output+="-----------------------------------------\n"
  output+="  START OF FILE: $file\n"
  output+="-----------------------------------------\n"
  output+="$(cat "$file")\n"
  output+="-----------------------------------------\n"
  output+="  END OF FILE: $file\n"
  output+="-----------------------------------------\n\n"
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

# Use the pattern in a find command that prunes matching directories
# The final -type f -print captures all files outside blacklisted directories
while IFS= read -r file; do
  process_file "$file"
done < <(eval "find \"$dir\" \\( $EXCLUDE_PATTERN \\) -prune -o -type f -print")

# -------------------------------------------------------
# Handle clipboard copying (if requested).
# Also show an approximate token count for reference.
# -------------------------------------------------------
if $copy_to_clipboard; then
  if [[ -n "$CLIP_CMD" ]]; then
    log_debug "Copying output to clipboard using '$CLIP_CMD'"
    echo -e "$output" | eval "$CLIP_CMD"
    echo "All content copied to clipboard."

    # ---------------------------------------------------
    # Approximate token count by simple word count
    # (just to gauge size relative to ChatGPT’s context).
    # ---------------------------------------------------
    estimated_tokens=$(echo -n "$output" | wc -w)
    echo "Words (estimated_tokens) copied to clipboard: $estimated_tokens"
  else
    echo "Error: No suitable clipboard command found. Aborting."
    exit 1
  fi
else
  # If not copying to clipboard, just print everything to stdout.
  echo -e "$output"
fi