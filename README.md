# Introduction

**dog.sh** is a Bash script that:
- Recursively lists files within a target directory (default: current directory).
- Ignores blacklisted directories (set via environment variable or defaults).
- Prints the contents of each file with clear delimiters.
- Optionally copies the concatenated output to your system clipboard (if a suitable command is available).
- Supports verbose debugging mode.

# Features

1. **Blacklist Directories**
    - By default, ignores `cmake-build-debug:cmake-build-release:.idea:.git`.
    - Override by setting `DOG_BLACKLIST_DIRS` (colon-separated list).

2. **Clipboard Support**
    - Tries `pbcopy`, `xclip`, then `xsel` in that order.
    - Fails with an error if `-c` is used but no supported command is found.

3. **Verbose Logging**
    - Turn on debug logs with `-v`.
    - Helpful for seeing how blacklist patterns, environment variables, and commands are set.

4. **Whitelist Files**
    - Use `--whitelist` to specify files to include.
    - Supports simple shell-glob matching (e.g., `*.sh`).
    - Allows multiple patterns separated by colons. (e.g. `--whitelist '*.sh:*.txt'`)

# Installation
To install:

Clone this repository or download dog.sh directly.

Place it in your PATH, for instance:
```bash
sudo cp dog.sh /usr/local/bin/dog
```

Alternatively, you can place it in your local bin directory:
```bash
cp dog.sh "${HOME}/.local/bin/dog.sh"
```

# Usage

```bash
dog.sh [OPTIONS] [DIRECTORY]
Where:

-c: Copy the combined output to the clipboard (requires pbcopy, xclip, or xsel).
-v: Enable verbose (debug) mode.
[DIRECTORY]: Directory to search (defaults to . if not specified).
```

Example command invocations:

1. Basic usage (no clipboard, default blacklist):
```bash
dog.sh
```

2. Copy to clipboard:
```bash
% dog.sh -c
-----------------------------------------
Processed files:
./dog.sh
./LICENSE
./README.md
-----------------------------------------
All content copied to clipboard.
Words (estimated_tokens) copied to clipboard:     1467
```

3. Enable debug logging:
```bash
% dog.sh -v -c
[DEBUG] DOG_BLACKLIST_DIRS = ''
[DEBUG] Effective BLACKLIST_DIRS = 'cmake-build-debug cmake-build-debug .idea .git'
[DEBUG] Clipboard command = 'pbcopy'
[DEBUG] Copy to clipboard? = 'true'
[DEBUG] Verbose? = 'true'
[DEBUG] Target directory = '.'
[DEBUG] Whitelist enabled? = 'false'
[DEBUG] EXCLUDE_PATTERN = ' -name "cmake-build-debug" -o -name "cmake-build-debug" -o -name ".idea" -o -name ".git"'
[DEBUG] Copying output to clipboard using 'pbcopy'
-----------------------------------------
Processed files:
./dog.sh
./LICENSE
./README.md
-----------------------------------------
All content copied to clipboard.
Words (estimated_tokens) copied to clipboard:     1404
```

4. Specify a directory:
```bash
% ./dog.sh -c /Users/cochner/code/dog
-----------------------------------------
Processed files:
/Users/cochner/code/dog/dog.sh
/Users/cochner/code/dog/LICENSE
/Users/cochner/code/dog/README.md
-----------------------------------------
All content copied to clipboard.
Words (estimated_tokens) copied to clipboard:     1488
```

5. Override blacklist:
```bash
export DOG_BLACKLIST_DIRS="vendor:node_modules"
dog.sh
```

6. Whitelisting is on:
   This will only list files that match CMakeLists.txt or *.sh (using simple shell-glob matching).
```bash
% dog.sh -c --whitelist '*.sh:*.md' .
-----------------------------------------
Processed files:
./dog.sh
./README.md
-----------------------------------------
All content copied to clipboard.
Words (estimated_tokens) copied to clipboard:     1325
```

# Authors:
- Martin | https://github.com/mcochner - Author
- Manuel | https://github.com/manuel-delverme - For the idea and for showing me the workflow that used similar script.
