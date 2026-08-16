#!/usr/bin/env bash
#
# Regenerate patches/for-desktop from commits in build/for-desktop.
#
# The workflow for changing a patch:
#
#   1. Edit files in build/for-desktop
#   2. Commit there (or `git commit --amend` / `git rebase -i` onto an
#      existing patch commit)
#   3. Run this script
#   4. Commit the regenerated patches in this repo
#
# Counts commits since the pinned upstream tag, so it stays correct as the
# series grows.

source "$(dirname -- "${BASH_SOURCE[0]}")/lib.sh"

import_upstream

target=$REPO_ROOT/build/for-desktop
patch_dir=$REPO_ROOT/patches/for-desktop

[[ -d $target ]] || die "No build/for-desktop. Run prepare.sh first."

base=$(git -C "$target" rev-list --max-count=1 "tags/$DESKTOP_TAG" 2>/dev/null) ||
    die "Cannot resolve tag $DESKTOP_TAG in the clone."
[[ -n $base ]] || die "Cannot resolve tag $DESKTOP_TAG in the clone."

count=$(git -C "$target" rev-list --count "$base..HEAD")
((count > 0)) || die "No commits on top of $DESKTOP_TAG."

log "Regenerating $count patches from $DESKTOP_TAG..HEAD"

rm -f -- "$patch_dir"/*.patch

git -C "$target" format-patch "$base..HEAD" -o "$patch_dir" --no-signature -q ||
    die "format-patch failed"

find "$patch_dir" -maxdepth 1 -name '*.patch' | sort | while IFS= read -r patch; do
    log "  $(basename -- "$patch")"
done
