# Shared helpers. Sourced, never executed.
# shellcheck shell=bash

set -euo pipefail

REPO_ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)

die() {
    printf 'error: %s\n' "$*" >&2
    exit 1
}

log() {
    printf '%s\n' "$*"
}

warn() {
    printf 'warning: %s\n' "$*" >&2
}

# Parse a KEY=VALUE file and export every entry.
#
# Lines are KEY=VALUE. No quotes, no shell expansion, # starts a comment.
# Values are used verbatim after trimming, so a `#` mid-line stays part of
# the value -- same as brand.env documents.
#
# With --keep-existing, a variable already set in the environment wins, so CI
# can override any single setting without rewriting the file.
load_env_file() {
    local path=$1
    local mode=${2:-}
    local line key value

    [[ -f $path ]] || die "no such env file: $path"

    # `|| [[ -n $line ]]` so a final line without a trailing newline is read.
    while IFS= read -r line || [[ -n $line ]]; do
        line=${line%$'\r'} # tolerate a CRLF checkout
        line=${line#"${line%%[![:space:]]*}"}
        line=${line%"${line##*[![:space:]]}"}

        [[ -z $line || $line == '#'* || $line != *'='* ]] && continue

        key=${line%%=*}
        value=${line#*=}
        key=${key%"${key##*[![:space:]]}"}
        value=${value#"${value%%[![:space:]]*}"}
        value=${value%"${value##*[![:space:]]}"}

        [[ $key =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]] || continue

        if [[ $mode == --keep-existing && -n ${!key:-} ]]; then
            continue
        fi

        printf -v "$key" '%s' "$value"
        export "${key?}"
    done <"$path"
}

# Export brand.env into the environment for the build.
import_brand() {
    load_env_file "$REPO_ROOT/brand.env" --keep-existing
}

# Export the pinned upstream revisions.
import_upstream() {
    load_env_file "$REPO_ROOT/upstream.env"
}
