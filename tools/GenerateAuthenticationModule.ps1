# Copyright (c) Microsoft Corporation. All rights reserved.
# Licensed under the MIT License.
Param(
  [string] $RepositoryName = "PSGallery",
  [string] $RepositoryApiKey,
  [string] $ArtifactsLocation = (Join-Path $PSScriptRoot "..\artifacts\"),
  [switch] $Build,
  [switch] $Pack,
  [switch] $Publish,
  [switch] $EnableSigning,
  [switch] $BuildWhenEqual
)
enum VersionState {
  Invalid
  Valid
  EqualToFeed
  NotOnFeed
}
$ErrorActionPreference = 'Stop'
$LASTEXITCODE = $null
if ($PSEdition -ne 'Core') {
  Write-Error 'This script requires PowerShell Core to execute. [Note] Generated cmdlets will work in both PowerShell Core or Windows PowerShell.'
}

$ModulePrefix = "Microsoft.Graph"
$ModuleName = "Authentication"
$AuthModuleManifest = "Microsoft.Graph.Authentication.psd1"
$BuildModulePS1 = Join-Path $PSScriptRoot ".\BuildModule.ps1" -Resolve
$PackModulePS1 = Join-Path $PSScriptRoot ".\PackModule.ps1" -Resolve
$PublishModulePS1 = Join-Path $PSScriptRoot ".\PublishModule.ps1" -Resolve
$ValidateUpdatedModuleVersionPS1 = Join-Path $PSScriptRoot ".\ValidateUpdatedModuleVersion.ps1" -Resolve
$AuthModulePath = Join-Path $PSScriptRoot "..\src\Authentication\Authentication\" -Resolve

# Read ModuleVersion set on local auth module.
$ManifestContent = Import-LocalizedData -BaseDirectory $AuthModulePath -FileName $AuthModuleManifest
if ($null -eq $ManifestContent.ModuleVersion) {
  # Module version not set in module manifest (psd1).
  Write-Error "Version number is not set on $ModulePrefix.$ModuleName module. Please set 'ModuleVersion' in $AuthModulePath\$AuthModuleManifest."
}

# Validate module version with the one on PSGallery.
[VersionState]$VersionState = & $ValidateUpdatedModuleVersionPS1 -ModuleName "$ModulePrefix.$ModuleName" -NextVersion $ManifestContent.ModuleVersion

if ($VersionState.Equals([VersionState]::Invalid)) {
  Write-Warning "The specified version in $ModulePrefix.$ModuleName module is either higher or lower than what's on $RepositoryName. Update 'ModuleVersion' in $AuthModulePath$AuthModuleManifest."
}
elseif ($VersionState.Equals([VersionState]::EqualToFeed) -and !$BuildWhenEqual) {
  Write-Warning "$ModulePrefix.$ModuleName module skipped. Version has not changed and is equal to what's on $RepositoryName."
}
elseif ($VersionState.Equals([VersionState]::Valid) -or $VersionState.Equals([VersionState]::NotOnFeed) -or $BuildWhenEqual) {
  $ModuleVersion = $VersionState.Equals([VersionState]::NotOnFeed) ? "0.1.1" : $ManifestContent.ModuleVersion
  # Build and pack generated module.
  if ($Build) {
    if ($EnableSigning) {
      & $BuildModulePS1 -Module $ModuleName -ModulePrefix $ModulePrefix -ModuleVersion $ModuleVersion -ReleaseNotes $ManifestContent.PrivateData.PSData.ReleaseNotes -EnableSigning
    }
    else {
      & $BuildModulePS1 -Module $ModuleName -ModulePrefix $ModulePrefix -ModuleVersion $ModuleVersion -ReleaseNotes $ManifestContent.PrivateData.PSData.ReleaseNotes
    }
  }

  if ($Pack) {
    & $PackModulePS1 -Module $ModuleName -ArtifactsLocation $ArtifactsLocation
  }

  if ($Publish) {
    & $PublishModulePS1 -Modules $ModuleName -ModulePrefix $ModulePrefix -ArtifactsLocation $ArtifactsLocation -RepositoryName $RepositoryName -RepositoryApiKey $RepositoryApiKey
  }
}