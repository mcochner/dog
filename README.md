# Introduction

**dog.sh** is a Bash script that:
- Recursively lists files within a target directory (default: current directory).
- Skips “excluded” paths (set via an environment variable or defaults).
- Prints the contents of each file with clear delimiters.
- Optionally copies the concatenated output to your system clipboard (if a suitable command is available).
- Supports verbose debugging mode.

# Features

1. **Exclude Paths**
   - By default, skips `cmake-build-debug:cmake-build-release:.idea:.git`.
   - Override by setting the environment variable `DOG_EXCLUDE_PATHS` (colon-separated list).

2. **Include Patterns**
   - Use -i or --include to specify file patterns (shell-glob) to only process. For example, --include '*.sh:*.txt'
   - If no patterns are specified, the script processes **all** files (except those under excluded paths).

3. **Clipboard Support**
   - Attempts `pbcopy`, `xclip`, then `xsel` in that order.
   - Fails with an error if `-c` is used but no supported command is found.

4. **Verbose Logging**
   - Enable debug logs with -v.
   - Helpful for seeing how exclude paths, environment variables, and commands are set.


# Installation
To install:

Clone this repository or download dog.sh directly. Then place it somewhere on your PATH:
```bash
sudo cp dog.sh /usr/local/bin/dog.sh
```

Or install it locally:
```bash
cp dog.sh "${HOME}/.local/bin/dog.sh"
```

# Usage

```bash
dog.sh [OPTIONS] [DIRECTORY]

Where:
  -c,               Copy the combined output to the clipboard (requires pbcopy, xclip, or xsel).
  -v, --verbose     Enable verbose (debug) mode.
  -i, --include     Colon-separated file patterns to ONLY include (e.g. '*.sh:*.md').
  [DIRECTORY]       Directory to search (defaults to '.' if not specified).
```

## Examples

#### 1. Basic usage (no clipboard, using default exclude paths):
```bash
dog.sh
```

#### 2. Copy to clipboard:
```bash
dog.sh -c
```

Sample output:
```
-----------------------------------------
Processed files:
./dog.sh
./LICENSE
./README.md
-----------------------------------------
All content copied to clipboard.
Words (estimated_tokens) copied to clipboard:     1467
```

#### 3. Enable debug logging:
```bash
dog.sh -v -c
```
Sample output:
```
[DEBUG] DOG_EXCLUDE_PATHS = ''
[DEBUG] Effective EXCLUDE_PATHS = 'cmake-build-debug cmake-build-release .idea .git'
[DEBUG] Clipboard command = 'pbcopy'
[DEBUG] Copy to clipboard? = 'true'
[DEBUG] Verbose? = 'true'
[DEBUG] Target directory = '.'
[DEBUG] Use include patterns? = 'false'
[DEBUG] EXCLUDE_PATTERN = ' -name "cmake-build-debug" -o -name "cmake-build-release" -o -name ".idea" -o -name ".git"'
[DEBUG] Copying output to clipboard using 'pbcopy'
...
```

#### 4. Specify a directory:
```bash
dog.sh -c /path/to/code
```
This will process all files under /path/to/code (except those in excluded paths).

#### 5. Override excluded paths:
```bash
export DOG_EXCLUDE_PATHS=".idea:.git:tmp"
dog.sh -c -v
```
Now the script will skip tmp in addition to .idea and .git.

#### 6. Include patterns:
```bash
dog.sh -c -i '*.sh:*.md'
```
This includes only .sh and .md files (again skipping excluded paths).


# Authors:
- Martin | https://github.com/mcochner - Author
- Manuel | https://github.com/manuel-delverme - For the idea and for showing me the workflow that used similar script.
