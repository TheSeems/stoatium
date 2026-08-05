#requires -Version 7
<#
.SYNOPSIS
  Regenerate patches/for-desktop from commits in build/for-desktop.
.DESCRIPTION
  The workflow for changing a patch:

    1. Edit files in build/for-desktop
    2. Commit there (or `git commit --amend` / `git rebase -i` onto an
       existing patch commit)
    3. Run this script
    4. Commit the regenerated patches in this repo

  Counts commits since the pinned upstream tag, so it stays correct as the
  series grows.
#>

. (Join-Path $PSScriptRoot "lib.ps1")

$upstream = Get-Upstream
$target = Join-Path $RepoRoot "build\for-desktop"
$patchDir = Join-Path $RepoRoot "patches\for-desktop"

if (-not (Test-Path $target)) { throw "No build/for-desktop. Run prepare.ps1 first." }

$base = git -C $target rev-list --max-count=1 "tags/$($upstream.DESKTOP_TAG)"
if ($LASTEXITCODE -ne 0 -or -not $base) {
    throw "Cannot resolve tag $($upstream.DESKTOP_TAG) in the clone."
}

$count = (git -C $target rev-list --count "$base..HEAD")
if ([int]$count -eq 0) { throw "No commits on top of $($upstream.DESKTOP_TAG)." }

Write-Host "Regenerating $count patches from $($upstream.DESKTOP_TAG)..HEAD"

Remove-Item -Force (Join-Path $patchDir "*.patch") -ErrorAction SilentlyContinue

git -C $target format-patch "$base..HEAD" -o $patchDir --no-signature -q
if ($LASTEXITCODE -ne 0) { throw "format-patch failed" }

Get-ChildItem $patchDir -Filter "*.patch" | Sort-Object Name | ForEach-Object {
    Write-Host "  $($_.Name)"
}
