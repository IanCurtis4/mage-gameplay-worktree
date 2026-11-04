param([switch]$Preview)
$ErrorActionPreference = 'Stop'
if ($PSVersionTable.PSVersion.Major -lt 7) {
    $q5ReviewBootstrap = @('-NoProfile','-ExecutionPolicy','Bypass','-File',$PSCommandPath)
    if ($Preview) { $q5ReviewBootstrap += '-Preview' }
    & (Get-Command pwsh -ErrorAction Stop).Source @q5ReviewBootstrap
    exit $LASTEXITCODE
}
$q5ReviewRoot = git -C $PSScriptRoot rev-parse --show-toplevel
if ($LASTEXITCODE -ne 0) { throw 'Não foi possível localizar o candidato.' }
$q5ReviewFixture = Join-Path $q5ReviewRoot '.godot/verification/e07_f1/fixture_project'
$q5ReviewEngine = Join-Path (Split-Path -Parent $q5ReviewRoot) 'godot/Godot_v4.7.2-stable_win64.exe'
foreach ($q5Required in @($q5ReviewEngine, (Join-Path $q5ReviewFixture 'project.godot'), (Join-Path $q5ReviewFixture 'source_hashes.json'))) {
    if (-not (Test-Path -LiteralPath $q5Required -PathType Leaf)) { throw 'A fixture atual precisa ser preparada pelo responsável antes da revisão.' }
}
$q5ReviewProfile = Join-Path $q5ReviewFixture '.godot/manual_review_profile'
if ($Preview) {
    [pscustomobject]@{candidate=(git -C $q5ReviewRoot rev-parse HEAD);project=$q5ReviewFixture;engine=$q5ReviewEngine;profile=$q5ReviewProfile}
    return
}
if (@(Get-Process -Name '*Godot*' -ErrorAction SilentlyContinue).Count) { throw 'Finalize as janelas de teste do Godot antes de abrir a revisão.' }
$q5ReviewHashes = Get-Content -LiteralPath (Join-Path $q5ReviewFixture 'source_hashes.json') -Raw | ConvertFrom-Json -AsHashtable
foreach ($q5Relative in $q5ReviewHashes.Keys) {
    foreach ($q5ReviewSide in @($q5ReviewRoot,$q5ReviewFixture)) {
        $q5ReviewFile = Join-Path $q5ReviewSide $q5Relative
        if (-not (Test-Path -LiteralPath $q5ReviewFile) -or (Get-FileHash -LiteralPath $q5ReviewFile).Hash.ToLowerInvariant() -ne $q5ReviewHashes[$q5Relative]) { throw 'A fonte ou a fixture mudou depois da preparação. Peça ao responsável para consolidar a revisão antes de abrir.' }
    }
}
[void](New-Item -ItemType Directory -Force -Path $q5ReviewProfile)
$q5ReviewConfig = Join-Path $q5ReviewFixture 'project.godot'
Copy-Item -LiteralPath $q5ReviewConfig -Destination (Join-Path $q5ReviewProfile ('project_before_'+[DateTime]::UtcNow.ToString('yyyyMMdd_HHmmss')+'.godot'))
$q5ReviewText = [IO.File]::ReadAllText((Join-Path $q5ReviewRoot 'project.godot')).Replace('version_control/autoload_on_startup=true','version_control/autoload_on_startup=false')
$q5ReviewText += "`n[editor_plugins]`nenabled=PackedStringArray(`"res://addons/ragrpg_map_editor/plugin.cfg`")`n"
[IO.File]::WriteAllText($q5ReviewConfig,$q5ReviewText)
$q5ReviewProcess = [Diagnostics.ProcessStartInfo]::new()
$q5ReviewProcess.FileName = $q5ReviewEngine
$q5ReviewProcess.UseShellExecute = $false
$q5ReviewProcess.Environment['APPDATA'] = $q5ReviewProfile
$q5ReviewProcess.Environment['LOCALAPPDATA'] = $q5ReviewProfile
foreach ($q5Argument in @('--path',$q5ReviewFixture,'--editor','--rendering-method','gl_compatibility','--log-file',(Join-Path $q5ReviewProfile 'review.engine.log'))) { $q5ReviewProcess.ArgumentList.Add($q5Argument) }
[void][Diagnostics.Process]::Start($q5ReviewProcess)
Write-Output 'Revisão aberta na fixture descartável. Abra a aba Mapas; salve suas cópias em res://.godot/manual_review_sources/.'
