# Stoatium

A debranded, self-host-configurable build of [Stoat](https://github.com/stoatchat)
— what VSCodium is to VS Code. Desktop and web client.

**Not affiliated with or endorsed by the Stoat project.** Report bugs here, not
upstream, unless you can reproduce them on an official build.

## Why

Upstream's desktop app is an Electron wrapper that loads a remote URL. Its
`--force-server` switch is per-launch and undiscoverable — every user edits a
shortcut, on every machine. Stoatium bakes the instance in at build time.

The web client is patched for Russian localisation, UI fixes and higher media
quality; it needs no patch to be *configurable*, since upstream substitutes
`__VITE_*__` sentinels at container start.

## Design: patch series, not a fork

No upstream source is vendored. `scripts/prepare.ps1` clones a pinned tag and
applies the patch series, the way VSCodium does. Bumping upstream is `git am`,
and conflicts surface as failed patches at a moment you chose rather than as
silent drift.

```
brand.env              branding + your instance URL
upstream.env           pinned upstream tags
patches/for-desktop/   3 patches: runtime URL, debranding, opt-in updates
patches/for-web/       11 patches: ru catalog, UI, media quality
brand/desktop/         your icons, overlaid onto upstream's assets
scripts/               prepare, build, regen-patches
```

## Build

PowerShell 7+, Node 22+, pnpm 11+, git.

```powershell
# edit brand.env -> STOATIUM_SERVER_URL, then:
./scripts/build.ps1 -Prepare
```

Artifacts land in `build/for-desktop/out/make`: a Squirrel installer and ZIP on
Windows, ZIP on Linux. Builds are unsigned, so SmartScreen will warn.

The appx, flatpak and deb makers are skipped by default — they need toolchains
absent on stock machines and CI runners. `-AllTargets` enables them; AppX
self-signs and cannot be installed without trusting the generated certificate
first, so it is not a distribution path without your own signing identity.

The web client is built separately: apply `patches/for-web/` to upstream
`for-web` at the pinned revision and build its Dockerfile. Deployment
manifests are instance-specific and are not published here.

## Changing a patch

```powershell
# edit files in build/for-desktop, commit there, then:
./scripts/regen-patches.ps1
```

Bumping upstream is `upstream.env` then `./scripts/prepare.ps1 -Force`. A patch
that no longer applies aborts with the filename.

The web catalog has its own generator: `scripts/regen-web-catalog.mjs` verifies
every ICU placeholder survives, which matters because lingui renders a dropped
`{0}` as literal braces at runtime rather than failing the build. Prefer it to
editing the `.po` by hand.

## Licensing

Upstream is **AGPL-3.0**, which grants the right to fork, modify and
redistribute. If you distribute builds: keep it AGPL-3.0-or-later, publish your
modified source (this repo plus the patch series), state your changes (the
series is the statement), and under §13 offer the source to anyone using a
modified version **over a network** — which is why the in-app Source Code link
points here.

AGPL grants **no trademark rights**. That is why debranding is mandatory rather
than cosmetic: you may ship the code, not the name, logo, or any implication of
endorsement.

## Known gaps

- **Mobile is not covered.** `for-android` is Kotlin and would need a server
  field on the login screen; `for-ios` hits the well-known conflict between App
  Store terms and GPL-family licenses, leaving sideloading or the web PWA.
- **No in-app server picker.** The instance is chosen at build time, with
  `--force-server` as the escape hatch.
- **You must supply icons.** Upstream keeps artwork in a submodule that the
  build imports directly. Leave `brand/desktop/` empty and you get a working
  build carrying **upstream's logos** — fine locally, not redistributable.
