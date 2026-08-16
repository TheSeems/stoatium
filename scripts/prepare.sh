#!/usr/bin/env bash
#
# Clone upstream at the pinned tag and apply the patch series.
#
#   scripts/prepare.sh [-f|--force]
#
# Destructive and idempotent: build/for-desktop is deleted and recreated, so
# any uncommitted work there is lost. That is deliberate -- the patch series
# is the source of truth, not the working tree.
#
# Use scripts/regen-patches.sh to turn working-tree commits back into patches
# before re-running this.

source "$(dirname -- "${BASH_SOURCE[0]}")/lib.sh"

force=0
while (($#)); do
    case $1 in
        -f | --force) force=1 ;;
        -h | --help)
            echo "usage: scripts/prepare.sh [-f|--force]"
            echo
            echo "  --force   discard an existing build/for-desktop and start over"
            exit 0
            ;;
        *) die "unknown argument: $1" ;;
    esac
    shift
done

import_upstream

target=$REPO_ROOT/build/for-desktop
patch_dir=$REPO_ROOT/patches/for-desktop

if [[ -d $target && $force -ne 1 ]]; then
    die "build/for-desktop already exists. Re-run with --force to discard it."
fi

if [[ -d $target ]]; then
    log "Clearing existing $target"

    # Clear the *contents* rather than the directory itself. On Windows a
    # directory that is any process's working directory cannot be removed --
    # including this shell's, if you ever cd'd into it -- but its contents
    # can. git clone is happy to clone into an existing empty directory, so
    # this sidesteps the problem entirely instead of retrying against it.
    find "$target" -mindepth 1 -maxdepth 1 -exec rm -rf -- {} +

    left=$(find "$target" -mindepth 1 | wc -l | tr -d '[:space:]')
    if ((left > 0)); then
        die "Could not clear $target - $left items remain. Close anything using it."
    fi
else
    mkdir -p "$target"
fi

log "Cloning $DESKTOP_REPO at $DESKTOP_TAG"

# core.autocrlf=false is load-bearing: with Git's Windows default the working
# tree gets CRLF, every patch hunk mismatches, and the series fails to apply.
git -c advice.detachedHead=false -c core.autocrlf=false \
    clone --depth 1 --branch "$DESKTOP_TAG" \
    "$DESKTOP_REPO" "$target" ||
    die "clone failed"

git -C "$target" config core.autocrlf false
git -C "$target" config user.email "stoatium@localhost"
git -C "$target" config user.name "Stoatium Build"

# Icons live in the `assets` submodule, which the build imports directly
# (src/native/tray.ts). It is declared `update = none`, so a plain
# --recurse-submodules clone silently skips it and the build fails late with
# an unresolved import. Force the checkout.
log "Fetching assets submodule"
git -C "$target" submodule update --init --force --checkout assets ||
    die "failed to fetch assets submodule"

# That submodule is stoatchat/assets -- upstream's actual logos. Overlay our
# own on top when supplied, so a redistributable build carries no upstream
# artwork.
overlay=$REPO_ROOT/brand/desktop
dest=$target/assets/desktop

overlay_files=()
while IFS= read -r -d '' file; do
    overlay_files+=("$file")
done < <(find "$overlay" -type f ! -name README.md -print0 2>/dev/null)

if ((${#overlay_files[@]} > 0)); then
    log "Overlaying ${#overlay_files[@]} branded assets from brand/desktop"
    for file in "${overlay_files[@]}"; do
        rel=${file#"$overlay"/}
        mkdir -p "$dest/$(dirname -- "$rel")"
        cp -f -- "$file" "$dest/$rel"
    done
else
    warn "brand/desktop is empty - this build uses UPSTREAM'S ICONS."
    warn "Fine for local testing. Do not redistribute: the AGPL does"
    warn "not license their artwork. See NOTICE.md."
fi

patches=()
while IFS= read -r patch; do
    patches+=("$patch")
done < <(find "$patch_dir" -maxdepth 1 -name '*.patch' | sort)

((${#patches[@]} > 0)) || die "no patches found in $patch_dir"

log "Applying ${#patches[@]} patches"

for patch in "${patches[@]}"; do
    log "  $(basename -- "$patch")"
    if ! git -C "$target" am --keep-cr "$patch"; then
        git -C "$target" am --abort 2>/dev/null || true
        die "Patch failed: $(basename -- "$patch"). Upstream likely moved; rebase the series."
    fi
done

log "Ready: $target"
