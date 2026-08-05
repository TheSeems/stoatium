#requires -Version 7
<#
.SYNOPSIS
  Clone upstream at the pinned tag and apply the patch series.
.DESCRIPTION
  Destructive and idempotent: build/for-desktop is deleted and recreated, so
  any uncommitted work there is lost. That is deliberate — the patch series
  is the source of truth, not the working tree.

  Use scripts/regen-patches.ps1 to turn working-tree commits back into
  patches before re-running this.
#>
param(
    [switch] $Force
)

. (Join-Path $PSScriptRoot "lib.ps1")

$upstream = Get-Upstream
$target = Join-Path $RepoRoot "build\for-desktop"
$patchDir = Join-Path $RepoRoot "patches\for-desktop"

if ((Test-Path $target) -and -not $Force) {
    throw "build\for-desktop already exists. Re-run with -Force to discard it."
}

if (Test-Path $target) {
    Write-Host "Clearing existing $target"

    # Clear the *contents* rather than the directory itself. On Windows a
    # directory that is any process's working directory cannot be removed —
    # including this shell's, if you ever cd'd into it — but its contents can.
    # git clone is happy to clone into an existing empty directory, so this
    # sidesteps the problem entirely instead of retrying against it.
    Get-ChildItem $target -Force | Remove-Item -Recurse -Force

    $left = @(Get-ChildItem $target -Force -Recurse -ErrorAction SilentlyContinue)
    if ($left.Count -gt 0) {
        throw "Could not clear $target - $($left.Count) items remain. Close anything using it."
    }
}
else {
    New-Item -ItemType Directory -Force $target | Out-Null
}

Write-Host "Cloning $($upstream.DESKTOP_REPO) at $($upstream.DESKTOP_TAG)"

# core.autocrlf=false is load-bearing: with Git's Windows default the working
# tree gets CRLF, every patch hunk mismatches, and the series fails to apply.
git -c advice.detachedHead=false -c core.autocrlf=false `
    clone --depth 1 --branch $upstream.DESKTOP_TAG `
    $upstream.DESKTOP_REPO $target
if ($LASTEXITCODE -ne 0) { throw "clone failed" }

git -C $target config core.autocrlf false
git -C $target config user.email "stoatium@localhost"
git -C $target config user.name "Stoatium Build"

# Icons live in the `assets` submodule, which the build imports directly
# (src/native/tray.ts). It is declared `update = none`, so a plain
# --recurse-submodules clone silently skips it and the build fails late with
# an unresolved import. Force the checkout.
Write-Host "Fetching assets submodule"
git -C $target submodule update --init --force --checkout assets
if ($LASTEXITCODE -ne 0) { throw "failed to fetch assets submodule" }

# That submodule is stoatchat/assets — upstream's actual logos. Overlay our
# own on top when supplied, so a redistributable build carries no upstream
# artwork.
$overlay = Join-Path $RepoRoot "brand\desktop"
$overlayFiles = @(Get-ChildItem $overlay -Recurse -File -ErrorAction SilentlyContinue |
    Where-Object { $_.Name -ne "README.md" })

if ($overlayFiles.Count -gt 0) {
    Write-Host "Overlaying $($overlayFiles.Count) branded assets from brand/desktop"
    Copy-Item -Path (Join-Path $overlay "*") -Destination (Join-Path $target "assets\desktop") `
        -Recurse -Force -Exclude "README.md"
}
else {
    Write-Warning "brand/desktop is empty - this build uses UPSTREAM'S ICONS."
    Write-Warning "Fine for local testing. Do not redistribute: the AGPL does"
    Write-Warning "not license their artwork. See NOTICE.md."
}

$patches = Get-ChildItem $patchDir -Filter "*.patch" | Sort-Object Name
Write-Host "Applying $($patches.Count) patches"

foreach ($patch in $patches) {
    Write-Host "  $($patch.Name)"
    git -C $target am --keep-cr $patch.FullName
    if ($LASTEXITCODE -ne 0) {
        git -C $target am --abort 2>$null
        throw "Patch failed: $($patch.Name). Upstream likely moved; rebase the series."
    }
}

Write-Host "Ready: $target"
