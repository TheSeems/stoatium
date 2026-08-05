#requires -Version 7
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$script:RepoRoot = Split-Path -Parent $PSScriptRoot

<#
.SYNOPSIS
  Parse a KEY=VALUE file into a hashtable.
#>
function Read-EnvFile {
    param([Parameter(Mandatory)][string] $Path)

    $result = @{}
    foreach ($line in Get-Content $Path) {
        $trimmed = $line.Trim()
        if (-not $trimmed -or $trimmed.StartsWith("#")) { continue }

        $idx = $trimmed.IndexOf("=")
        if ($idx -lt 1) { continue }

        $key = $trimmed.Substring(0, $idx).Trim()
        $value = $trimmed.Substring($idx + 1).Trim()
        $result[$key] = $value
    }
    return $result
}

<#
.SYNOPSIS
  Export brand.env into the process environment for the build.
.DESCRIPTION
  Values already present in the environment win, so CI can override any
  single setting without rewriting the file.
#>
function Import-Brand {
    $brand = Read-EnvFile (Join-Path $script:RepoRoot "brand.env")

    foreach ($key in $brand.Keys) {
        $existing = [Environment]::GetEnvironmentVariable($key)
        if ([string]::IsNullOrEmpty($existing)) {
            [Environment]::SetEnvironmentVariable($key, $brand[$key])
        }
    }

    return $brand
}

function Get-Upstream {
    return Read-EnvFile (Join-Path $script:RepoRoot "upstream.env")
}
