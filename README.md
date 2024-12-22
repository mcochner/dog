# Introduction

**dog.sh** is a Bash script that:
- Recursively lists files within a target directory (default: current directory).
- Ignores blacklisted directories (set via environment variable or defaults).
- Prints the contents of each file with clear delimiters.
- Optionally copies the concatenated output to your system clipboard (if a suitable command is available).
- Supports verbose debugging mode.

# Features

1. **Blacklist Directories**
    - By default, ignores `cmake-build-debug`, `cmake-build-release` and `.idea`.
    - Override by setting `DOG_BLACKLIST_DIRS` (colon-separated list).

2. **Clipboard Support**
    - Tries `pbcopy`, `xclip`, then `xsel` in that order.
    - Fails with an error if `-c` is used but no supported command is found.

3. **Verbose Logging**
    - Turn on debug logs with `-v`.
    - Helpful for seeing how blacklist patterns, environment variables, and commands are set.

# Usage

```bash
./dog.sh [OPTIONS] [DIRECTORY]
Where:

-c: Copy the combined output to the clipboard (requires pbcopy, xclip, or xsel).
-v: Enable verbose (debug) mode.
[DIRECTORY]: Directory to search (defaults to . if not specified).
```

Example command invocations:

1. Basic usage (no clipboard, default blacklist):
```bash
./dog.sh
```

2. Copy to clipboard:
```bash
./dog.sh -c
```

3. Enable debug logging:
```bash
./dog.sh -v
```

4. Specify a directory:
```bash
./dog.sh /path/to/directory
```

5. Override blacklist:
```bash
export DOG_BLACKLIST_DIRS="vendor:node_modules"
./dog.sh
```

# Installation
To install:

Clone this repository or download dog.sh directly.

Place it in your PATH, for instance:
```bash
sudo mv dog.sh /usr/local/bin/dog
```

Alternatively, you can place it in your local bin directory:
```bash
mv dog.sh "${HOME}/.local/bin"
```


# Authors:
- Martin | https://github.com/mcochner - Author
- Manuel | https://github.com/manuel-delverme - For the idea and for showing me the workflow that used similar script.
