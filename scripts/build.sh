#!/usr/bin/env bash
#
# Build Stoatium desktop artifacts.
#
#   scripts/build.sh --prepare    clone upstream, apply patches, install, make
#   scripts/build.sh              rebuild from the existing build/for-desktop
#
# Options:
#   --prepare       (re-)create build/for-desktop from the patch series first
#   --publish       run `pnpm publish` instead of `pnpm make`
#   --all-targets   also build the appx / flatpak / deb targets. Off by
#                   default because they need a toolchain that is not present
#                   on a stock machine or on a CI runner: appx wants the
#                   Windows SDK (it self-signs, which is slow and produces a
#                   package nobody can install without trusting the cert), and
#                   flatpak wants flatpak-builder. forge.config.ts skips all
#                   three whenever PLATFORM is set.

source "$(dirname -- "${BASH_SOURCE[0]}")/lib.sh"

usage() {
    cat <<'EOF'
usage: scripts/build.sh [--prepare] [--publish] [--all-targets]

  --prepare       (re-)create build/for-desktop from the patch series first
  --publish       run `pnpm publish` instead of `pnpm make`
  --all-targets   also build the appx / flatpak / deb targets
EOF
}

prepare=0 publish=0 all_targets=0
while (($#)); do
    case $1 in
        --prepare) prepare=1 ;;
        --publish) publish=1 ;;
        --all-targets) all_targets=1 ;;
        -h | --help)
            usage
            exit 0
            ;;
        *) die "unknown argument: $1" ;;
    esac
    shift
done

if ((all_targets == 0)) && [[ -z ${PLATFORM:-} ]]; then
    export PLATFORM=ci
fi

target=$REPO_ROOT/build/for-desktop

if ((prepare == 1)) || [[ ! -d $target ]]; then
    "$(dirname -- "${BASH_SOURCE[0]}")/prepare.sh" --force
fi

import_brand

if [[ $STOATIUM_SERVER_URL == *chat.example.com* ]]; then
    warn "STOATIUM_SERVER_URL is still the placeholder in brand.env."
    warn "The build will work, but will point at a domain you do not own."
fi

log ""
log "Building $STOATIUM_PRODUCT_NAME"
log "  instance : $STOATIUM_SERVER_URL"
log "  app id   : $STOATIUM_APP_ID"
log "  update   : ${STOATIUM_UPDATE_REPO:-disabled}"
log "  discord  : $([[ -n ${STOATIUM_DISCORD_APP_ID:-} ]] && echo enabled || echo disabled)"
log ""

cd "$target"

pnpm install --frozen-lockfile || die "pnpm install failed"

if ((publish == 1)); then
    [[ -n ${STOATIUM_PUBLISH_REPO:-} ]] ||
        die "--publish requires STOATIUM_PUBLISH_REPO in brand.env"
    pnpm publish || die "publish failed"
else
    pnpm make || die "build failed"
fi

log ""
log "Artifacts: $target/out/make"
