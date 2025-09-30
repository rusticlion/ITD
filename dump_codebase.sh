#!/usr/bin/env bash
set -euo pipefail

# dump_codebase.sh - Generate a Markdown document containing a full dump of the codebase, organized by file.
#
# Usage:
#   ./dump_codebase.sh [-o OUTPUT] [-A] [-D]
#
# Options:
#   -o OUTPUT   Path to write the markdown output (default: CODEBASE_DUMP.md)
#   -A          Use all files under the directory (via find) rather than git-tracked files
#   -D          Exclude contents of docs/ directory from the dump
#   -h          Show help

print_usage() {
  cat << 'USAGE'
Generate a Markdown document containing a full dump of the codebase, organized by file.

Usage:
  ./dump_codebase.sh [-o OUTPUT] [-A] [-D]

Options:
  -o OUTPUT   Path to write the markdown output (default: CODEBASE_DUMP.md)
  -A          Use all files under the directory (via find) rather than git-tracked files
  -D          Exclude contents of docs/ directory from the dump
  -h          Show this help

Notes:
  - Binary files are detected and listed but their raw contents are not embedded.
  - If a file contains triple backticks, the script automatically increases fence length.
USAGE
}

OUTPUT="CODEBASE_DUMP.md"
USE_ALL_FILES=false
EXCLUDE_DOCS=false

while getopts ":o:ADh" opt; do
  case "$opt" in
    o)
      OUTPUT="$OPTARG"
      ;;
    A)
      USE_ALL_FILES=true
      ;;
    D)
      EXCLUDE_DOCS=true
      ;;
    h)
      print_usage
      exit 0
      ;;
    *)
      echo "Unknown option: -$OPTARG" >&2
      print_usage
      exit 2
      ;;
  esac
done

SCRIPT_BASENAME="$(basename "$0")"
OUTPUT_BASENAME="$(basename "$OUTPUT")"

is_git_repo() {
  git rev-parse --is-inside-work-tree >/dev/null 2>&1
}

collect_files_git() {
  # Use git to list tracked files; skip submodules contents unless checked out and tracked
  git ls-files -z | tr '\0' '\n'
}

collect_files_find() {
  # Fallback: find all regular files excluding .git directory
  if "$EXCLUDE_DOCS"; then
    find . -type f \
      -not -path "./.git/*" \
      -not -path "./docs/*" \
      -not -path "./$OUTPUT_BASENAME" \
      -not -name "$OUTPUT_BASENAME" \
      -not -name "$SCRIPT_BASENAME"
  else
    find . -type f \
      -not -path "./.git/*" \
      -not -path "./$OUTPUT_BASENAME" \
      -not -name "$OUTPUT_BASENAME" \
      -not -name "$SCRIPT_BASENAME"
  fi
}

normalize_path() {
  # Remove leading ./ if present
  local p="$1"
  if [[ "$p" == ./* ]]; then
    printf "%s" "${p:2}"
  else
    printf "%s" "$p"
  fi
}

is_binary_file() {
  # Heuristic using `file` utility
  local f="$1"
  if command -v file >/dev/null 2>&1; then
    local enc
    enc="$(file --brief --mime-encoding "$f" 2>/dev/null || true)"
    if echo "$enc" | grep -qi "binary"; then
      return 0
    fi
    # Some systems may not return "binary" for certain binaries; fallback to mime
    local mime
    mime="$(file --brief --mime "$f" 2>/dev/null || true)"
    if echo "$mime" | grep -qi "charset=binary"; then
      return 0
    fi
  fi
  return 1
}

detect_language_tag() {
  # Map file extension to a markdown language tag
  local f="$1"
  local ext
  ext="${f##*.}"
  case "$ext" in
    sh|bash|zsh) echo "bash" ;;
    lua) echo "lua" ;;
    md|markdown|mdown|mkdn) echo "markdown" ;;
    js|mjs|cjs) echo "javascript" ;;
    ts) echo "typescript" ;;
    jsx) echo "jsx" ;;
    tsx) echo "tsx" ;;
    json) echo "json" ;;
    yml|yaml) echo "yaml" ;;
    toml) echo "toml" ;;
    ini|cfg|conf) echo "ini" ;;
    py) echo "python" ;;
    rb) echo "ruby" ;;
    go) echo "go" ;;
    java) echo "java" ;;
    c|h) echo "c" ;;
    cc|cpp|cxx|hpp|hh|hxx) echo "cpp" ;;
    cs) echo "csharp" ;;
    rs) echo "rust" ;;
    swift) echo "swift" ;;
    kt|kts) echo "kotlin" ;;
    php) echo "php" ;;
    html|htm) echo "html" ;;
    css) echo "css" ;;
    scss|sass) echo "scss" ;;
    vue) echo "vue" ;;
    svelte) echo "svelte" ;;
    sql) echo "sql" ;;
    *) echo "" ;;
  esac
}

choose_fence_for_file() {
  # Choose a fence string (sequence of backticks) not present in the file content
  local f="$1"
  local fence='```'
  if [[ -r "$f" ]]; then
    while grep -q "$fence" "$f" 2>/dev/null; do
      fence+='`'
      # Guard against pathological files by capping fence length
      if [[ ${#fence} -gt 8 ]]; then
        break
      fi
    done
  fi
  printf "%s" "$fence"
}

repo_name="$(basename "$(pwd)")"

# Prepare output
{
  printf "# Codebase Dump: %s\n\n" "$repo_name"
  printf "_Generated on %s_\n\n" "$(date -u +'%Y-%m-%d %H:%M UTC')"
} > "$OUTPUT"

# Collect files
files=()
if "$USE_ALL_FILES"; then
  while IFS= read -r f; do
    files+=("$f")
  done < <(collect_files_find)
else
  if is_git_repo; then
    while IFS= read -r f; do
      files+=("$f")
    done < <(collect_files_git)
  else
    while IFS= read -r f; do
      files+=("$f")
    done < <(collect_files_find)
  fi
fi

# Normalize, filter out the output file and this script, sort
filtered=()
for p in "${files[@]}"; do
  rel="$(normalize_path "$p")"
  base="$(basename "$rel")"
  if "$EXCLUDE_DOCS" && [[ "$rel" == docs/* ]]; then
    continue
  fi
  if [[ "$base" == "$OUTPUT_BASENAME" ]]; then
    continue
  fi
  if [[ "$base" == "$SCRIPT_BASENAME" ]]; then
    continue
  fi
  # Also skip .DS_Store
  if [[ "$base" == ".DS_Store" ]]; then
    continue
  fi
  filtered+=("$rel")
done

IFS=$'\n' read -r -d '' -a sorted < <(printf '%s\n' "${filtered[@]}" | sort && printf '\0') || true

# Emit contents
for file in "${sorted[@]}"; do
  if [[ ! -r "$file" ]]; then
    # Skip unreadable files
    continue
  fi

  lang="$(detect_language_tag "$file")"
  fence="$(choose_fence_for_file "$file")"

  printf "## %s\n\n" "$file" >> "$OUTPUT"

  if is_binary_file "$file"; then
    printf "Binary file; contents omitted.\n\n" >> "$OUTPUT"
    continue
  fi

  if [[ -n "$lang" ]]; then
    printf "%s%s\n" "$fence" "$lang" >> "$OUTPUT"
  else
    printf "%s\n" "$fence" >> "$OUTPUT"
  fi
  cat "$file" >> "$OUTPUT"
  printf "\n%s\n\n" "$fence" >> "$OUTPUT"
done

echo "Wrote markdown dump to: $OUTPUT"


