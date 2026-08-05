#requires -Version 7
<#
.SYNOPSIS
  Build Stoatium desktop artifacts.
.EXAMPLE
  ./scripts/build.ps1 -Prepare
  Clone upstream, apply patches, install, and make.
.EXAMPLE
  ./scripts/build.ps1
  Rebuild from the existing build/for-desktop tree.
#>
param(
    [switch] $Prepare,
    [switch] $Publish,
    # Also build the appx / flatpak / deb targets. Off by default because
    # they need a toolchain that is not present on a stock machine or on a CI
    # runner: appx wants the Windows SDK (it self-signs, which is slow and
    # produces a package nobody can install without trusting the cert), and
    # flatpak wants flatpak-builder. forge.config.ts skips all three whenever
    # PLATFORM is set.
    [switch] $AllTargets
)

. (Join-Path $PSScriptRoot "lib.ps1")

if (-not $AllTargets -and -not $env:PLATFORM) {
    $env:PLATFORM = "ci"
}

$target = Join-Path $RepoRoot "build\for-desktop"

if ($Prepare -or -not (Test-Path $target)) {
    & (Join-Path $PSScriptRoot "prepare.ps1") -Force
}

$brand = Import-Brand

if ($brand.STOATIUM_SERVER_URL -match "chat\.example\.com") {
    Write-Warning "STOATIUM_SERVER_URL is still the placeholder in brand.env."
    Write-Warning "The build will work, but will point at a domain you do not own."
}

Write-Host ""
Write-Host "Building $($brand.STOATIUM_PRODUCT_NAME)"
Write-Host "  instance : $($brand.STOATIUM_SERVER_URL)"
Write-Host "  app id   : $($brand.STOATIUM_APP_ID)"
Write-Host "  update   : $(if ($brand.STOATIUM_UPDATE_REPO) { $brand.STOATIUM_UPDATE_REPO } else { 'disabled' })"
Write-Host "  discord  : $(if ($brand.STOATIUM_DISCORD_APP_ID) { 'enabled' } else { 'disabled' })"
Write-Host ""

Push-Location $target
try {
    pnpm install --frozen-lockfile
    if ($LASTEXITCODE -ne 0) { throw "pnpm install failed" }

    if ($Publish) {
        if (-not $brand.STOATIUM_PUBLISH_REPO) {
            throw "-Publish requires STOATIUM_PUBLISH_REPO in brand.env"
        }
        pnpm publish
    }
    else {
        pnpm make
    }
    if ($LASTEXITCODE -ne 0) { throw "build failed" }
}
finally {
    Pop-Location
}

Write-Host ""
Write-Host "Artifacts: $target\out\make"
