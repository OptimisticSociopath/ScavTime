param(
  [ValidateSet('BUILD_PACKAGE')][string]$Mode = 'BUILD_PACKAGE',
  [string]$GameRoot = 'C:\SPT',
  [string]$BundleRoot,
  [string]$DownloadDir
)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$ok = $false
function Stop-Build([string]$reason) { throw ('SCAVTIME_P03_R3|' + $reason) }
function Require-File([string]$p) { if (-not [IO.File]::Exists($p)) { Stop-Build ('MISSING_FILE|' + $p) } }
function Sha([string]$p) { return (Get-FileHash -LiteralPath $p -Algorithm SHA256).Hash.ToUpperInvariant() }
try {
  if ($PSVersionTable.PSVersion.Major -ne 5 -or $PSVersionTable.PSVersion.Minor -ne 1 -or -not [Environment]::Is64BitProcess) { Stop-Build 'PS51_X64_REQUIRED' }
  if ([string]::IsNullOrWhiteSpace($BundleRoot) -or -not [IO.Directory]::Exists($BundleRoot)) { Stop-Build 'SOURCE_STAGE_REQUIRED' }
  if ([string]::IsNullOrWhiteSpace($DownloadDir) -or -not [IO.Directory]::Exists($DownloadDir)) { Stop-Build 'DOWNLOADS_REQUIRED' }
  $game = [IO.Path]::GetFullPath($GameRoot).TrimEnd('\')
  $stage = [IO.Path]::GetFullPath($BundleRoot).TrimEnd('\')
  $downloads = [IO.Path]::GetFullPath($DownloadDir).TrimEnd('\')
  if ($stage.Equals($game,[StringComparison]::OrdinalIgnoreCase) -or $stage.StartsWith($game+'\',[StringComparison]::OrdinalIgnoreCase)) { Stop-Build 'STAGE_INSIDE_SPT_FORBIDDEN' }
  if ($downloads.Equals($game,[StringComparison]::OrdinalIgnoreCase) -or $downloads.StartsWith($game+'\',[StringComparison]::OrdinalIgnoreCase)) { Stop-Build 'OUTPUT_INSIDE_SPT_FORBIDDEN' }
  $runtime = Join-Path $game 'SPT_Runtime'
  $mods = Join-Path $runtime 'user\mods'
  $modInstalled = Join-Path $mods 'ScavTime'
  if ([IO.Directory]::Exists($modInstalled)) { Write-Host 'INFO|EXISTING_SCAVTIME_INSTALL_PRESENT|BUILD_ONLY_NO_OVERWRITE' }
  if ([IO.Directory]::Exists((Join-Path $mods 'fika-server'))) { Write-Host 'INFO|FIKA_SERVER_FOLDER_PRESENT|NOT_RUNTIME_VERIFIED' } else { Write-Host 'INFO|FIKA_SERVER_FOLDER_ABSENT|STANDALONE_BUILD_SUPPORTED' }
  $dllNames = @('SPTarkov.Server.Core.dll','SPTarkov.DI.dll','SPTarkov.Common.dll','SemanticVersioning.dll')
  foreach ($name in $dllNames) { Require-File (Join-Path $runtime $name) }
  $coreVer = [Reflection.AssemblyName]::GetAssemblyName((Join-Path $runtime 'SPTarkov.Server.Core.dll')).Version
  if ($coreVer.Major -ne 4 -or $coreVer.Minor -ne 1 -or $coreVer.Build -ne 6) { Stop-Build ('SPT_CORE_416_REQUIRED_FOUND_' + $coreVer) }
  Write-Host ('PASS|SPT_CORE_VERSION|' + $coreVer)
  Write-Host 'BOUNDARY=READ_ONLY_SPT|NO_LIVE_CONFIG_EDIT|BUILD_ONLY|OUTPUT_DOWNLOADS'
  $dotnetCmd = Get-Command dotnet.exe -ErrorAction Stop
  $sdks = @(& $dotnetCmd.Source '--list-sdks')
  if ($LASTEXITCODE -ne 0 -or @($sdks | Where-Object { $_ -match '^10\.' }).Count -eq 0) { Stop-Build 'DOTNET_10_SDK_REQUIRED' }
  Write-Host ('PASS|DOTNET_SDK|' + @($sdks | Where-Object { $_ -match '^10\.' })[-1])
  $proj = Join-Path $stage 'src\ScavTime.Server.csproj'
  $testProj = Join-Path $stage 'tests\ScavTime.Tests.csproj'
  Require-File $proj
  Require-File $testProj
  Require-File (Join-Path $stage 'src\ScavTime.cs')
  Require-File (Join-Path $stage 'tests\Program.cs')
  Require-File (Join-Path $stage 'assets\icon.png')
  $feed = Join-Path $stage '_OFFLINE_EMPTY_FEED'
  [void][IO.Directory]::CreateDirectory($feed)
  $env:DOTNET_CLI_TELEMETRY_OPTOUT = '1'
  $env:DOTNET_SKIP_FIRST_TIME_EXPERIENCE = '1'
  $env:DOTNET_CLI_WORKLOAD_UPDATE_NOTIFY_DISABLE = 'true'
  $env:NUGET_PACKAGES = Join-Path $stage '_PRIVATE_NUGET'
  $property = '-p:SptRuntime=' + $runtime
  Write-Host 'STARTING=OFFLINE_TEST_RESTORE'
  & $dotnetCmd.Source restore $testProj '--source' $feed $property '-p:NuGetAudit=false' '--verbosity' 'minimal'
  if ($LASTEXITCODE -ne 0) { Stop-Build ('TEST_RESTORE_RC_' + $LASTEXITCODE) }
  Write-Host 'STARTING=BUILD_AND_RUN_BEHAVIOR_TESTS'
  & $dotnetCmd.Source run '--project' $testProj '--configuration' 'Release' '--no-restore' $property '--verbosity' 'minimal'
  if ($LASTEXITCODE -ne 0) { Stop-Build ('BEHAVIOR_TESTS_RC_' + $LASTEXITCODE) }
  Write-Host 'PASS|BEHAVIOR_TESTS_RC0'
  Write-Host 'STARTING=BUILD_RELEASE_SERVER_MOD'
  & $dotnetCmd.Source build $proj '--configuration' 'Release' '--no-restore' $property '--verbosity' 'minimal'
  if ($LASTEXITCODE -ne 0) { Stop-Build ('SERVER_BUILD_RC_' + $LASTEXITCODE) }
  $binary = Join-Path $stage 'src\bin\Release\net10.0\ScavTime.Server.dll'
  Require-File $binary
  if ((Get-Item -LiteralPath $binary).Length -lt 4096) { Stop-Build 'DLL_TOO_SMALL' }
  Write-Host ('PASS|BUILT_SERVER_DLL|SHA256=' + (Sha $binary))
  $pRoot = Join-Path $stage '_OUTPUT_PACKAGE'
  if ([IO.Directory]::Exists($pRoot)) { Stop-Build 'PACKAGE_STAGE_ALREADY_EXISTS' }
  $target = Join-Path $pRoot 'SPT_Runtime\user\mods\ScavTime'
  [void][IO.Directory]::CreateDirectory($target)
  $stagedDll = Join-Path $target 'ScavTime.Server.dll'
  [IO.File]::Copy($binary,$stagedDll)
  $stagedIcon = Join-Path $pRoot 'icon.png'
  [IO.File]::Copy((Join-Path $stage 'assets\icon.png'),$stagedIcon)
  $stagedModIcon = Join-Path $target 'icon.png'
  [IO.File]::Copy((Join-Path $stage 'assets\icon.png'),$stagedModIcon)
  if ((Sha $stagedIcon) -ne (Sha $stagedModIcon)) { Stop-Build 'ICON_COPY_MISMATCH' }
  $readme = Join-Path $pRoot 'INSTALL_README.txt'
  $notes = @'
ScavTime - Never be late for a Raid! v1.0.0
Author: Vargor / OptimisticSociopath | SPT 4.1.6 | Fika backend-compatible (co-op testing pending)
Mod GUID: com.vargor.scavtime

WHAT IT DOES
ScavTime disables SPT's random late Scav raid entry by setting the server-side
Scav raid time reduction chance to 0%. It does not extend normal PMC raid time,
change loot, spawn waves, extracts, or edit profiles.

SINGLE-PLAYER SPT
1. Close the SPT server and game.
2. Remove the OLD ScavFullRaidTime folder if you still have the previous mod.
   If updating ScavTime itself, first back up its existing folder.
3. Extract this ZIP into your main SPT directory (for example, C:\SPT).
   Verify that these two files are installed:
      SPT_Runtime/user/mods/ScavTime/ScavTime.Server.dll
      SPT_Runtime/user/mods/ScavTime/icon.png
   Do not install the DLL under BepInEx/plugins.
4. Restart the SPT server; look for [ScavTime] ACTIVE in its log.
5. Start a NEW Scav raid and verify its starting timer.

FIKA SHARED SERVER
Server administrator:
1. Stop the shared SPT/Fika backend and any running raid sessions.
2. Install ScavTime.Server.dll and icon.png in:
      SPT_Runtime/user/mods/ScavTime/
   on the SHARED SPT backend (not on every player's client).
3. Make sure the old ScavFullRaidTime server mod is not installed alongside it.
4. Restart the backend. Check [ScavTime] ACTIVE and the Fika folder diagnostic.

Players:
1. Install a compatible version of Fika as usual and connect to that backend.
2. No ScavTime client DLL, BepInEx plugin, or F12 configuration is required.
3. Enter a Scav lobby BEFORE the host starts the raid; verify full starting time.

The host controls the active raid clock. ScavTime does NOT reset an already
running raid for late arrivals, reconnecting players, or newly joining clients.
Fika folder detection is only diagnostic; successful multiplayer behavior still
requires a live host/client test. Fika is OPTIONAL in ordinary solo SPT.

IS FIKA HEADLESS REQUIRED?
No. Fika Headless is optional. You may use it as a dedicated raid host, but
ScavTime does not require it. If you use Headless, still install ScavTime on the
shared SPT backend and test the raid timer there.

UNINSTALL
Close the SPT/Fika backend and remove ONLY:
      SPT_Runtime/user/mods/ScavTime/
Do not delete other mods or game configuration files.

PACKAGE CONTENTS
- SPT_Runtime/user/mods/ScavTime/ScavTime.Server.dll
- SPT_Runtime/user/mods/ScavTime/icon.png
- icon.png (a duplicate copy for the mod listing/thumbnail)
- INSTALL_README.txt
- MANIFEST_SHA256.csv

STATUS: SPT 4.1.6 compilation and Fika co-op runtime must be verified using the
build/test procedure. The Fika compatibility claim is backend-level only until
confirmed in a shared live raid.
'@
  [IO.File]::WriteAllText($readme,$notes,([Text.UTF8Encoding]::new($false)))
  $man = Join-Path $pRoot 'MANIFEST_SHA256.csv'
  $relDll = 'SPT_Runtime/user/mods/ScavTime/ScavTime.Server.dll'
  $relModIcon = 'SPT_Runtime/user/mods/ScavTime/icon.png'
  $manifestLines = @(
    'Path,Sha256,Bytes',
    ($relDll + ',' + (Sha $stagedDll) + ',' + (Get-Item -LiteralPath $stagedDll).Length),
    ('icon.png,' + (Sha $stagedIcon) + ',' + (Get-Item -LiteralPath $stagedIcon).Length),
    ($relModIcon + ',' + (Sha $stagedModIcon) + ',' + (Get-Item -LiteralPath $stagedModIcon).Length),
    ('INSTALL_README.txt,' + (Sha $readme) + ',' + (Get-Item -LiteralPath $readme).Length)
  )
  [IO.File]::WriteAllLines($man,$manifestLines,([Text.UTF8Encoding]::new($false)))
  Add-Type -AssemblyName System.IO.Compression
  Add-Type -AssemblyName System.IO.Compression.FileSystem
  $finalName = 'ScavTime-Never-be-late-for-a-Raid-v1.0.0.zip'
  $final = Join-Path $downloads $finalName
  $partial = $final + '.partial'
  if ([IO.File]::Exists($final) -or [IO.File]::Exists($partial)) { Stop-Build 'FINAL_ZIP_EXISTS_NO_OVERWRITE' }
  [IO.Compression.ZipFile]::CreateFromDirectory($pRoot,$partial)
  $wanted = @($relDll,$relModIcon,'icon.png','INSTALL_README.txt','MANIFEST_SHA256.csv')
  $z = [IO.Compression.ZipFile]::OpenRead($partial)
  try {
    if ($z.Entries.Count -ne 5) { Stop-Build 'FINAL_ZIP_ENTRY_COUNT_INVALID' }
    $seen = @{}
    foreach ($e in $z.Entries) {
      $rel = $e.FullName.Replace('\','/')
      if (-not ($wanted -ccontains $rel) -or $seen.ContainsKey($rel)) { Stop-Build ('FINAL_ZIP_UNEXPECTED|' + $rel) }
      $seen[$rel] = $true
      $expectedFile = Join-Path $pRoot ($rel.Replace('/','\'))
      $digest = [Security.Cryptography.SHA256]::Create()
      $stream = $e.Open()
      try { $contentHash = ([BitConverter]::ToString($digest.ComputeHash($stream))).Replace('-','') }
      finally { $stream.Dispose(); $digest.Dispose() }
      if ($contentHash -ne (Sha $expectedFile) -or $e.Length -ne (Get-Item -LiteralPath $expectedFile).Length) { Stop-Build ('FINAL_ZIP_CONTENT_MISMATCH|' + $rel) }
    }
    if ($seen.Count -ne 5) { Stop-Build 'FINAL_ZIP_SET_INCOMPLETE' }
  }
  finally { $z.Dispose() }
  [IO.File]::Move($partial,$final)
  Write-Host 'PASS|FINAL_ZIP_EXACT_SET|5/5'
  Write-Host 'PASS|FINAL_ZIP_CONTENT_SHA256|5/5'
  Write-Host ('READY_ZIP=' + $final)
  Write-Host ('READY_ZIP_SHA256=' + (Sha $final))
  Write-Host 'STATUS=PASS_SCAVTIME_P03_R3_BUILD_PACKAGE'
  Write-Host 'FIKA_COOP_RUNTIME=NOT_VERIFIED'
  Write-Host 'RUNTIME_TEST=NOT_PERFORMED_INSTALL_MANUALLY'
  $ok = $true
}
catch {
  Write-Host ('FAIL_CLOSED=' + $_.Exception.Message) -ForegroundColor Red
  Write-Host ('BUILD_EVIDENCE=' + $BundleRoot)
  Write-Host 'STATUS=REVIEW_REQUIRED_NO_INSTALL'
  exit 1
}
finally {
  Write-Host 'SPT_INSTALLATION_UNCHANGED'
}
