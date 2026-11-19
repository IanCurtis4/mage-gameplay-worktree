# E10a T13 (C10): candidate export, exact-PCK probes, crowd measurement against the E08 candidate
# db7f9252, review profiles (4, job 40), launchers and smoke. Derived from tools/e09_package.ps1:
# standard engine, verified release template, map-editor export plugin enabled for byte parity,
# isolated app name and APPDATA. Never touches the habitual checkout (codex/playtest) or personal saves.
# The export runs from the F1 fixture that the full verify round created from this worktree.
param(
    [Parameter(Mandatory)][ValidateSet('Export','Inspect','Measure','Profiles','Launchers','Smoke')][string]$Stage,
    [Parameter(Mandatory)][ValidatePattern('^[0-9a-f]{40}$')][string]$CandidateCommit,
    [ValidatePattern('^[a-z0-9_]+$')][string]$EvidenceName='',
    [ValidateRange(1,5)][int]$Rounds=2
)
$ErrorActionPreference = 'Stop'
$pkSource = Split-Path -Parent $PSScriptRoot
[Environment]::CurrentDirectory = $pkSource
Set-Location -LiteralPath $pkSource
$pkMain = 'C:/Users/João Pedro/Documents/ChatGPT/RagRPG'
$pkFixture = Join-Path $pkSource '.godot/verification/e07_f1/fixture_project'
$pkEngine = Join-Path $pkMain '.tools/godot/Godot_v4.7.2-stable_win64.exe'
$pkEngineSha = 'ab1824f85bfd8e0e4128182c000c4003a3e042245b2967848d089b2a04b22424'
$pkTemplate = 'C:/Users/João Pedro/AppData/Roaming/Godot/export_templates/4.7.2.stable/windows_release_x86_64.exe'
$pkTemplateSha = 'd34d36f3be1a6c49c56525ae86469b92e4f417ddf0b43cf00dd80c385c4b0562'
$pkAppName = 'RagRPG E10a Candidato'
$pkBaseName = 'RagRPG-E10a-Candidato'
$pkOutput = Join-Path $pkMain ('.tools/playtest_e10a/' + $CandidateCommit.Substring(0, 8))
$pkExe = Join-Path $pkOutput ($pkBaseName + '.exe')
$pkPck = Join-Path $pkOutput ($pkBaseName + '.pck')
$pkEvidence = Join-Path $pkOutput 'validation'
$pkReference = Join-Path $pkMain '.tools/playtest_e08/e08_db7f9252/RagRPG-E08-Candidato.pck'
$pkReferenceSha = '3d7456fb4734d294a18940a232fcb2af1799ee3ec9aebfc18bab00f384687330'
$pkKits = [ordered]@{
    priest = @{ origin = 'acolyte'; body = 'priest'; name = 'Sacerdote' }
    cultist = @{ origin = 'acolyte'; body = 'cultist'; name = 'Cultista' }
}
# The base is a registered base, not a kit; its body and icons belong to the same family.
$pkBodies = @('acolyte', 'priest', 'cultist')
$pkItems = [ordered]@{ prayer_book = 'prayer_book'; halo_scepter = 'halo_scepter'; eye_reliquary = 'eye_reliquary' }
$pkFixtureFolders = @('scripts/classes/fixture/', 'scripts/classes/cultist/fixture/', 'scripts/systems/sanctuary/fixture/', 'scripts/systems/flank/fixture/', 'scripts/systems/madness/fixture/')
# Later commits may only add these relative to the exported candidate (never exported runtime).
$pkToolOnly = '^(docs/|export_presets\.cfg$|tools/e10a_(package\.ps1|release_probe\.gd(\.uid)?|crowd_probe\.gd(\.uid)?))'
if ((Get-FileHash -LiteralPath $pkEngine -Algorithm SHA256).Hash.ToLowerInvariant() -ne $pkEngineSha) { throw 'Unexpected standard engine.' }
function Get-Sha([string]$Path) { (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant() }
function Add-Run([string]$RunsFile, [hashtable]$Record) {
    $all = [Collections.Generic.List[object]]::new()
    if (Test-Path -LiteralPath $RunsFile) { foreach ($old in @(Get-Content -LiteralPath $RunsFile -Raw | ConvertFrom-Json)) { $all.Add($old) } }
    $all.Add($Record)
    [IO.File]::WriteAllText($RunsFile, (ConvertTo-Json -InputObject @($all.ToArray()) -Depth 20))
}
# One process, sampled working set while alive, raw output kept, strict error scan.
function Invoke-Pk([string]$Name, [string]$Executable, [string[]]$Arguments, [string]$Folder, [string]$ProfileDir, [int]$TimeoutSeconds = 300, [string]$Marker = '', [hashtable]$Environment = @{}, [string]$WorkingDirectory = '') {
    [void](New-Item -ItemType Directory -Force -Path $Folder)
    [void](New-Item -ItemType Directory -Force -Path $ProfileDir)
    $info = [Diagnostics.ProcessStartInfo]::new()
    $info.FileName = $Executable
    $info.WorkingDirectory = $(if ($WorkingDirectory) { $WorkingDirectory } else { $Folder })
    $info.UseShellExecute = $false; $info.CreateNoWindow = $true
    $info.RedirectStandardOutput = $true; $info.RedirectStandardError = $true
    $info.Environment['APPDATA'] = Join-Path $ProfileDir 'appdata'
    $info.Environment['LOCALAPPDATA'] = Join-Path $ProfileDir 'localappdata'
    foreach ($key in $Environment.Keys) { $info.Environment[$key] = $Environment[$key] }
    $log = Join-Path $Folder ($Name + '.engine.log')
    foreach ($arg in @('--log-file', $log) + $Arguments) { $info.ArgumentList.Add($arg) }
    $process = [Diagnostics.Process]::new(); $process.StartInfo = $info
    $started = [DateTime]::UtcNow
    [void]$process.Start()
    $stdout = $process.StandardOutput.ReadToEndAsync(); $stderr = $process.StandardError.ReadToEndAsync()
    $watch = [Diagnostics.Stopwatch]::StartNew(); $timedOut = $false; $peakWs = 0L
    while (-not $process.WaitForExit(250)) {
        try { $process.Refresh(); $peakWs = [Math]::Max($peakWs, $process.PeakWorkingSet64) } catch [InvalidOperationException] {}
        if ($watch.Elapsed.TotalSeconds -gt $TimeoutSeconds) { $timedOut = $true; break }
    }
    if ($timedOut) { $process.Kill($true); $process.WaitForExit() }
    $text = $stdout.GetAwaiter().GetResult() + $stderr.GetAwaiter().GetResult()
    [IO.File]::WriteAllText((Join-Path $Folder ($Name + '.output.log')), $text)
    $engineText = if (Test-Path -LiteralPath $log) { [IO.File]::ReadAllText($log) } else { '' }
    $errors = @([regex]::Matches($text + "`n" + $engineText, '(?m)^.*(SCRIPT ERROR:|Parse Error:|ERROR:).*$') | ForEach-Object { $_.Value } | Select-Object -Unique)
    $result = $null
    if ($Marker) {
        $match = [regex]::Matches($text, '(?m)^' + $Marker + ' (.+)$')
        if ($match.Count) { $result = $match[$match.Count - 1].Groups[1].Value | ConvertFrom-Json -AsHashtable }
    }
    $ok = -not $timedOut -and $process.ExitCode -eq 0 -and $errors.Count -eq 0 -and (-not $Marker -or ($null -ne $result -and $result.ok))
    $record = [ordered]@{ name = $Name; ok = $ok; exit_code = $process.ExitCode; timed_out = $timedOut; started_utc = $started.ToString('o'); elapsed_seconds = [Math]::Round(([DateTime]::UtcNow - $started).TotalSeconds, 3); executable = $Executable; executable_sha256 = (Get-Sha $Executable); arguments = $Arguments; profile = $ProfileDir; sampled_peak_working_set_bytes = $(if ($peakWs -gt 0) { $peakWs } else { $null }); error_lines = $errors; output_sha256 = (Get-Sha (Join-Path $Folder ($Name + '.output.log'))); result = $result }
    $process.Dispose()
    Write-Host ("{0}: ok={1} exit={2} timeout={3} {4:n1}s" -f $Name, $ok, $record.exit_code, $timedOut, $record.elapsed_seconds)
    return $record
}

if ($Stage -eq 'Export') {
    $head = (git -C $pkSource rev-parse HEAD).Trim()
    if ($head -ne $CandidateCommit) { throw "HEAD $head is not the candidate $CandidateCommit." }
    if (@(git -C $pkSource status --porcelain --untracked-files=no).Count -gt 0) { throw 'Tracked changes present: commit the candidate before export.' }
    if ((Get-Sha $pkTemplate) -ne $pkTemplateSha) { throw 'Unexpected Windows release template.' }
    if ((Get-PSDrive C).Free -lt 2GB) { throw 'Insufficient free space.' }
    if (Test-Path -LiteralPath $pkOutput) { throw "Destination exists; preserve it: $pkOutput" }
    # 1. Fixture parity: every manifest input equal in source and fixture; every tracked runtime file
    #    of the commit present and equal in the fixture.
    $hashes = Get-Content -LiteralPath (Join-Path $pkFixture 'source_hashes.json') -Raw | ConvertFrom-Json -AsHashtable
    foreach ($rel in $hashes.Keys) {
        foreach ($side in @($pkSource, $pkFixture)) {
            $inPath = Join-Path $side $rel
            if (-not (Test-Path -LiteralPath $inPath) -or (Get-Sha $inPath) -ne $hashes[$rel]) { throw "Source/fixture mismatch (rerun e07_f1_import_test): $rel" }
        }
    }
    $tracked = @(git -C $pkSource ls-files -- scripts scenes assets data resources content addons) | Where-Object { $_ -notlike 'addons/godot-git-plugin/*' }
    $trackedSet = [Collections.Generic.HashSet[string]]::new([string[]]$tracked)
    $runtimeMissing = [Collections.Generic.List[string]]::new(); $differs = [Collections.Generic.List[string]]::new()
    foreach ($rel in $tracked) {
        $target = Join-Path $pkFixture $rel
        $runtime = $rel -match '\.(gd|tscn|tres|wav|ogg|rpp|navproof|cfg|ttf|otf|gdshader|import|svg)$' -or ($rel -match '\.png$' -and $trackedSet.Contains($rel + '.import')) -or ($rel -match '\.json$' -and $rel -notmatch '(/staging/|provenance\.json$|source_recipe\.json$|selection\.json$|/e08_head_fit/)')
        if (-not (Test-Path -LiteralPath $target)) { if ($runtime) { $runtimeMissing.Add($rel) }; continue }
        if ($rel -notlike '*.import' -and (Get-Sha (Join-Path $pkSource $rel)) -ne (Get-Sha $target)) { $differs.Add($rel) }
    }
    if ($runtimeMissing.Count -or $differs.Count) { throw ("Fixture is not the candidate: missing runtime " + ($runtimeMissing -join ', ') + ' / differs ' + ($differs -join ', ')) }
    # 2. Source art stays out of the pack (E08 rule): an image/audio file under assets/ is runtime only
    #    when its .import is tracked. The fixture holds the editor's untracked imports of source art.
    $sourceArt = @(Get-ChildItem -LiteralPath (Join-Path $pkFixture 'assets') -Recurse -File -Filter '*.import' | ForEach-Object {
        [IO.Path]::GetRelativePath($pkFixture, $_.FullName).Replace('\', '/')
    } | Where-Object { -not $trackedSet.Contains($_) } | ForEach-Object { $_.Substring(0, $_.Length - '.import'.Length) } | Sort-Object)
    [void](New-Item -ItemType Directory -Force -Path $pkEvidence)
    [IO.File]::WriteAllText((Join-Path $pkEvidence 'fixture_parity.json'), (ConvertTo-Json -Depth 4 -InputObject ([ordered]@{ candidate_commit = $CandidateCommit; manifest_inputs_checked = $hashes.Count; tracked_runtime_dirs = $tracked.Count; source_art_excluded = $sourceArt; fixture_folders_excluded = $pkFixtureFolders; rule = 'source art = image/audio under assets/ whose .import is not tracked; it is not exported' })))
    # 3. Packaged project/preset written into the fixture for the export only, then restored.
    $projectPath = Join-Path $pkFixture 'project.godot'; $presetPath = Join-Path $pkFixture 'export_presets.cfg'
    $projectBefore = [IO.File]::ReadAllBytes($projectPath)
    $presetExisted = Test-Path -LiteralPath $presetPath
    $presetBefore = if ($presetExisted) { [IO.File]::ReadAllBytes($presetPath) } else { $null }
    $runs = Join-Path $pkEvidence 'runs.json'
    try {
        $project = [IO.File]::ReadAllText((Join-Path $pkSource 'project.godot')).Replace('version_control/autoload_on_startup=true', 'version_control/autoload_on_startup=false').Replace('config/name="RagRPG"', ('config/name="' + $pkAppName + '"'))
        if ($project -notmatch [regex]::Escape('config/name="' + $pkAppName + '"')) { throw 'Application name not applied.' }
        if ($project -notmatch 'run/main_scene="res://scenes/character_menu.tscn"') { throw 'The candidate must open in the normal menu.' }
        $project += "`n[editor_plugins]`nenabled=PackedStringArray(`"res://addons/ragrpg_map_editor/plugin.cfg`")`n"
        $preset = [IO.File]::ReadAllText((Join-Path $pkSource 'export_presets.cfg'))
        $exclude = [regex]::Match($preset, '(?m)^exclude_filter="([^"]*)"').Groups[1].Value
        foreach ($folder in $pkFixtureFolders) { if ($exclude -notmatch [regex]::Escape($folder + '*')) { throw "Committed exclude_filter lacks $folder*" } }
        $packagedExclude = (@('addons/godot-git-plugin/*') + @($exclude -split ',' | Where-Object { $_ }) + $sourceArt) -join ','
        $preset = $preset.Replace('custom_template/release=""', ('custom_template/release="' + $pkTemplate + '"')).Replace(('exclude_filter="' + $exclude + '"'), ('exclude_filter="' + $packagedExclude + '"')).Replace('debug/export_console_wrapper=1', 'debug/export_console_wrapper=0')
        if ($preset -notmatch [regex]::Escape($pkTemplate)) { throw 'Release template not applied.' }
        [IO.File]::WriteAllText($projectPath, $project); [IO.File]::WriteAllText($presetPath, $preset)
        [IO.File]::WriteAllText((Join-Path $pkEvidence 'packaged_project.godot'), $project)
        [IO.File]::WriteAllText((Join-Path $pkEvidence 'packaged_export_presets.cfg'), $preset)
        $record = Invoke-Pk 'export' $pkEngine @('--headless', '--path', $pkFixture, '--export-release', 'Windows Desktop', $pkExe) $pkEvidence (Join-Path $pkEvidence 'profile_export') 1200
        Add-Run $runs $record
        if (-not $record.ok) { throw 'Export failed; logs preserved.' }
    } finally {
        [IO.File]::WriteAllBytes($projectPath, $projectBefore)
        if ($presetExisted) { [IO.File]::WriteAllBytes($presetPath, $presetBefore) } else { Remove-Item -LiteralPath $presetPath -Force -ErrorAction SilentlyContinue }
    }
    $restored = (Get-Sha $projectPath) -eq ([Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($projectBefore))).ToLowerInvariant() -and ($(if ($presetExisted) { (Get-Sha $presetPath) -eq ([Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($presetBefore))).ToLowerInvariant() } else { -not (Test-Path -LiteralPath $presetPath) }))
    if (-not $restored) { throw 'Fixture project/preset not restored.' }
    $artifacts = foreach ($path in @($pkExe, $pkPck)) { $item = Get-Item -LiteralPath $path; [ordered]@{ file = $item.Name; bytes = $item.Length; sha256 = (Get-Sha $path) } }
    $manifest = [ordered]@{ candidate_commit = $CandidateCommit; source = $pkSource; fixture = $pkFixture; engine = $pkEngine; engine_sha256 = (Get-Sha $pkEngine); template = $pkTemplate; template_sha256 = (Get-Sha $pkTemplate); application_name = $pkAppName; main_scene = 'res://scenes/character_menu.tscn'; artifacts = @($artifacts); packaging_deltas = @('VCS autoload disabled', 'Map editor export plugin enabled to preserve original dependency bytes', 'Release template absolute path', 'Git plugin excluded', 'Source art without tracked .import excluded', 'Console wrapper disabled', 'Application name isolates saves'); fixture_project_restored = $restored; generated_utc = [DateTime]::UtcNow.ToString('o') }
    [IO.File]::WriteAllText((Join-Path $pkOutput 'build_manifest.json'), (ConvertTo-Json -InputObject $manifest -Depth 8))
    Write-Output (ConvertTo-Json -InputObject $manifest -Depth 4)
    return
}

if (-not (Test-Path -LiteralPath $pkPck)) { throw 'Export the candidate first.' }
$pkBuild = Get-Content -LiteralPath (Join-Path $pkOutput 'build_manifest.json') -Raw | ConvertFrom-Json
foreach ($artifact in $pkBuild.artifacts) {
    $path = Join-Path $pkOutput $artifact.file
    if ((Get-Item -LiteralPath $path).Length -ne $artifact.bytes -or (Get-Sha $path) -ne $artifact.sha256) { throw "Artifact changed after export: $($artifact.file)" }
}
$pkHead = (git -C $pkSource rev-parse HEAD).Trim()
if ($pkHead -ne $CandidateCommit) {
    $later = @(git -C $pkSource diff --name-only $CandidateCommit $pkHead)
    if ($later | Where-Object { $_ -notmatch $pkToolOnly }) { throw 'HEAD has runtime deltas after the candidate.' }
}
$pkRuns = Join-Path $pkEvidence 'runs.json'
$pkStamp = [DateTime]::UtcNow.ToString('yyyyMMddTHHmmss')

if ($Stage -eq 'Inspect') {
    $files = @(git -C $pkSource ls-tree -r --name-only $CandidateCommit -- assets data scripts/actors/equipment_head_fit_data.gd)
    $set = [Collections.Generic.HashSet[string]]::new([string[]]$files)
    $res = { param($p) 'res://' + $p }
    # E08 groups, unchanged (regression of the E08 content in the E09 pack).
    $e08 = [ordered]@{
        audio_e08 = @($files | Where-Object { $_ -match '^assets/audio/e08/[^/]+\.wav$' } | ForEach-Object { & $res $_ })
        audio_p6 = @($files | Where-Object { $_ -match '^assets/audio/e08/p6/[^/]+\.wav$' } | ForEach-Object { & $res $_ })
        vfx_flipbooks = @($files | Where-Object { $_ -match '^assets/art/e08_vfx/[a-z_]+/[^/]+\.(png|json)$' -and $_ -notmatch '/staging/' -and ($_ -match '\.json$' -or $set.Contains($_ + '.import')) } | ForEach-Object { & $res $_ })
        directional_bodies = @($files | Where-Object { $_ -match '^assets/art/animations/directional/[^/]+/[^/]+\.(png|json)$' -and ($_ -match '\.json$' -or $set.Contains($_ + '.import')) } | ForEach-Object { & $res $_ })
        legacy_species_atlases = @($files | Where-Object { $_ -match '^assets/art/animations/e08_forest_[a-z_]+\.png$' } | ForEach-Object { & $res $_ })
        terrain_v2_tiles = @($files | Where-Object { $_ -match '^assets/art/map_authoring/[a-z_]+_v2\.png$' } | ForEach-Object { & $res $_ })
        props = @($files | Where-Object { $_ -match '^assets/art/map_authoring/props/[^/]+\.png$' -and $set.Contains($_ + '.import') } | ForEach-Object { & $res $_ })
        equipment_art = @($files | Where-Object { $_ -match '^assets/art/equipment/(painted|headgear)/[^/]+\.png$' -and $set.Contains($_ + '.import') } | ForEach-Object { & $res $_ })
        head_fit_data = @($files | Where-Object { $_ -eq 'scripts/actors/equipment_head_fit_data.gd' } | ForEach-Object { & $res $_ })
        map_packages = @($files | Where-Object { $_ -match '^data/map_authoring/[^/]+\.(rpp|navproof)$' -or $_ -in @('data/map_authoring/release_packages.json', 'data/map_authoring/prop_catalog.json', 'data/expedition/phases/forest_sanctuary.json') } | ForEach-Object { & $res $_ })
    }
    [void](New-Item -ItemType Directory -Force -Path $pkEvidence)
    $e08Path = Join-Path $pkEvidence 'expected_assets_e08.json'
    [IO.File]::WriteAllText($e08Path, (ConvertTo-Json -InputObject $e08 -Depth 4))
    # E10a expectations, from the candidate commit itself.
    $iconManifest = (git -C $pkSource show "$($CandidateCommit):assets/art/skills/manifest.json") -join "`n" | ConvertFrom-Json
    $bodyIds = @($pkBodies)
    $icons = @($iconManifest.entries | Where-Object { $_.class -in $bodyIds } | ForEach-Object { 'res://assets/art/skills/' + $_.id + '.svg' } | Sort-Object)
    $kits = [ordered]@{}
    $bodyTextures = [Collections.Generic.List[string]]::new()
    foreach ($id in $pkKits.Keys) {
        $folder = 'assets/art/e08_characters/directional/' + $pkKits[$id].body
        $kits[$id] = [ordered]@{ origin = $pkKits[$id].origin; presentation = 'res://' + $folder + '/presentation.json' }
    }
    $bodies = [ordered]@{}
    foreach ($body in $pkBodies) {
        $folder = 'assets/art/e08_characters/directional/' + $body
        $bodies[$body] = [ordered]@{ presentation = 'res://' + $folder + '/presentation.json' }
        foreach ($sheet in @('body.png', 'weaponless.png')) { if ($set.Contains("$folder/$sheet.import")) { $bodyTextures.Add('res://' + $folder + '/' + $sheet) } }
    }
    $items = [ordered]@{}
    foreach ($id in $pkItems.Keys) { $items[$id] = [ordered]@{ resource = "res://resources/e06_inventory_content/equipment/e10a_$id.tres"; prop = $pkItems[$id] } }
    $fragmentFiles = @(git -C $pkSource ls-tree -r --name-only $CandidateCommit -- scripts/classes scripts/systems | Where-Object { $_ -match '(^|/)snapshot_manifest\.json$' })
    $fragments = @($fragmentFiles | Where-Object { $path = $_; -not ($pkFixtureFolders | Where-Object { $path.StartsWith($_) }) } | ForEach-Object { 'res://' + $_ } | Sort-Object -CaseSensitive)
    $kinds = [Collections.Generic.List[string]]::new()
    foreach ($fragment in $fragments) {
        $parsed = (git -C $pkSource show ("$($CandidateCommit):" + $fragment.Substring(6))) -join "`n" | ConvertFrom-Json -AsHashtable
        foreach ($kind in $parsed.Keys) { $kinds.Add($kind) }
    }
    $e09 = [ordered]@{ kits = $kits; bodies = $bodies; body_textures = @($bodyTextures); skill_icons = $icons; items = $items; fragments = $fragments; fragment_kinds = @($kinds); forbidden_prefixes = @($pkFixtureFolders | ForEach-Object { 'res://' + $_ }) }
    $e09Path = Join-Path $pkEvidence 'expected_e10a.json'
    [IO.File]::WriteAllText($e09Path, (ConvertTo-Json -InputObject $e09 -Depth 6))
    $e08Probe = Join-Path $pkSource 'tools/e08_p7_release_probe.gd'
    $e09Probe = Join-Path $pkSource 'tools/e10a_release_probe.gd'
    Copy-Item -LiteralPath $e08Probe -Destination (Join-Path $pkEvidence 'e08_p7_release_probe.gd') -Force
    Copy-Item -LiteralPath $e09Probe -Destination (Join-Path $pkEvidence 'e10a_release_probe.gd') -Force
    $summary = [ordered]@{}
    $r = Invoke-Pk 'inspect_pack_e10a' $pkEngine @('--headless', '--main-pack', $pkPck, '--script', $e09Probe, '--', 'inspect', $pkEvidence, $e09Path, $pkAppName) $pkEvidence (Join-Path $pkEvidence ('profile_inspect_e10a_' + $pkStamp)) 300 'E10A_T13_INSPECT_RESULT'
    Add-Run $pkRuns $r; $summary.inspect_e10a = $r.ok
    $r = Invoke-Pk 'inspect_pack_e08' $pkEngine @('--headless', '--main-pack', $pkPck, '--script', $e08Probe, '--', 'inspect', $pkEvidence, $e08Path, $pkAppName) $pkEvidence (Join-Path $pkEvidence ('profile_inspect_e08_' + $pkStamp)) 300 'E08_P7_INSPECT_RESULT'
    Add-Run $pkRuns $r; $summary.inspect_e08 = $r.ok
    $r = Invoke-Pk 'normal_boot' $pkExe @('--rendering-method', 'gl_compatibility', '--quit-after', '120', '--verbose') $pkEvidence (Join-Path $pkEvidence ('profile_boot_' + $pkStamp)) 120
    Add-Run $pkRuns $r; $summary.normal_boot = $r.ok
    $r = Invoke-Pk 'forest_map_pack' $pkEngine @('--main-pack', $pkPck, '--rendering-method', 'gl_compatibility', '--script', $e08Probe, '--', 'forest', $pkEvidence) $pkEvidence (Join-Path $pkEvidence ('profile_forest_' + $pkStamp)) 480 'E08_P7_FOREST_RESULT'
    Add-Run $pkRuns $r; $summary.forest_map_pack = $r.ok
    $r = Invoke-Pk 'export_content' $pkEngine @('--headless', '--main-pack', $pkPck, '--script', (Join-Path $pkSource 'tools/export_content_probe.gd'), '--', $pkPck) $pkEvidence (Join-Path $pkEvidence ('profile_content_' + $pkStamp)) 240
    Add-Run $pkRuns $r; $summary.export_content = $r.ok
    $summary | ConvertTo-Json | Write-Output
    return
}

if ($Stage -eq 'Measure') {
    # Crowd probe, E10a candidate (Delirium active) against the E08 candidate db7f9252. No FPS claim.
    if (-not $EvidenceName) { throw 'Measure requires -EvidenceName.' }
    if ((Get-Sha $pkReference) -ne $pkReferenceSha) { throw 'E08 candidate db7f9252 PCK mismatch.' }
    $root = Join-Path $pkOutput ('measure_' + $EvidenceName)
    if (Test-Path -LiteralPath $root) { throw "Evidence name already used: $root" }
    [void](New-Item -ItemType Directory -Force -Path $root)
    $packMap = [ordered]@{ e08_db7f9252 = $pkReference; e10a_candidate = $pkPck }
    $script = Join-Path $pkSource 'tools/e10a_crowd_probe.gd'
    $gpu = @(Get-CimInstance Win32_VideoController | ForEach-Object { "$($_.Name) $($_.DriverVersion)" })
    $cpu = @(Get-CimInstance Win32_Processor | ForEach-Object { $_.Name })
    [IO.File]::WriteAllText((Join-Path $root 'protocol.json'), (ConvertTo-Json -Depth 5 -InputObject ([ordered]@{ candidate_commit = $CandidateCommit; packs = [ordered]@{ e08_db7f9252 = @{ path = $pkReference; sha256 = $pkReferenceSha }; e10a_candidate = @{ path = $pkPck; sha256 = (Get-Sha $pkPck) } }; engine_sha256 = $pkEngineSha; probe = 'tools/e10a_crowd_probe.gd'; probe_sha256 = (Get-Sha $script); renderer = 'gl_compatibility windowed 1280x720 vsync off'; rounds = $Rounds; order = 'pack order alternates each round'; gpu = $gpu; cpu = $cpu; claim = 'paired same-session comparison only; not an FPS certification' })))
    for ($round = 1; $round -le $Rounds; $round++) {
        $order = @($packMap.Keys); if ($round % 2 -eq 0) { [array]::Reverse($order) }
        foreach ($pack in $order) {
            $name = "r$($round)_$($pack)_crowd"
            $folder = Join-Path $root $name
            $r = Invoke-Pk $name $pkEngine @('--main-pack', $packMap[$pack], '--rendering-method', 'gl_compatibility', '--script', $script) $folder (Join-Path $folder 'profile') 600 'WORLD_CROWD_RESULT'
            $r['pack'] = $pack; $r['round'] = $round; $r['pack_sha256'] = (Get-Sha $packMap[$pack])
            Add-Run (Join-Path $root 'runs.json') $r
        }
    }
    return
}

if ($Stage -eq 'Profiles') {
    # T9 tool on the EXACT pack: one isolated profile per named build, job 40 (A18), never the
    # personal save. Then each profile becomes the user folder of its own launcher.
    $tool = Join-Path $pkSource 'tools/e10a_review_profiles.gd'
    Copy-Item -LiteralPath $tool -Destination (Join-Path $pkEvidence 'e10a_review_profiles.gd') -Force
    $raw = Join-Path $pkOutput 'review_profiles_raw'
    if (Test-Path -LiteralPath $raw) { throw "Review profiles already generated; preserving them: $raw" }
    $rawArg = [IO.Path]::GetFullPath($raw).Replace('\', '/')
    $r = Invoke-Pk 'review_profiles' $pkEngine @('--headless', '--main-pack', $pkPck, '--script', $tool, '--', $rawArg) $pkEvidence (Join-Path $pkEvidence ('profile_review_' + $pkStamp)) 300
    $text = [IO.File]::ReadAllText((Join-Path $pkEvidence 'review_profiles.output.log'))
    $start = $text.IndexOf('{'); $report = if ($start -ge 0) { $text.Substring($start) | ConvertFrom-Json -AsHashtable } else { $null }
    $r['report'] = $report
    $profiles = @(if ($report) { $report.profiles } else { @() })
    $r['profiles_count'] = $profiles.Count
    $r['ok'] = $r.ok -and $null -ne $report -and $report.ok -and $profiles.Count -eq 4 -and $report.invalid.Count -eq 0
    Add-Run $pkRuns $r
    if (-not $r.ok) { throw "Review profiles failed ($($profiles.Count) profiles)." }
    $index = [Collections.Generic.List[object]]::new()
    foreach ($row in $profiles) {
        $key = "$($row.identity_id)__$($row.build_id)"
        $source = Join-Path $raw $key
        $userDir = Join-Path $pkOutput ("profiles/$key/appdata/Godot/app_userdata/$pkAppName")
        if (Test-Path -LiteralPath (Join-Path $userDir 'profile.json')) { throw "Profile $key already prepared; preserving it." }
        [void](New-Item -ItemType Directory -Force -Path $userDir)
        Copy-Item -Path (Join-Path $source '*') -Destination $userDir -Recurse
        $builds = (git -C $pkSource show ("$($CandidateCommit):scripts/classes/$($row.identity_id)/review_builds.json")) -join "`n" | ConvertFrom-Json
        $build = $builds.builds | Where-Object { $_.id -eq $row.build_id }
        $index.Add([ordered]@{ key = $key; identity_id = $row.identity_id; build_id = $row.build_id; class_name = $pkKits[$row.identity_id].name; build_name = $build.name; profile_sha256 = (Get-Sha (Join-Path $userDir 'profile.json')) })
    }
    [IO.File]::WriteAllText((Join-Path $pkOutput 'profiles/index.json'), (ConvertTo-Json -InputObject @($index.ToArray()) -Depth 4))
    $index | ForEach-Object { "$($_.key) $($_.profile_sha256)" } | Write-Output
    return
}

if ($Stage -eq 'Launchers') {
    $index = Get-Content -LiteralPath (Join-Path $pkOutput 'profiles/index.json') -Raw | ConvertFrom-Json
    $shell = New-Object -ComObject WScript.Shell
    foreach ($row in $index) {
        $cmd = Join-Path $pkOutput ("launch_$($row.key).cmd")
        $body = "@echo off`r`nrem RagRPG E10a candidato - perfil isolado $($row.key) (nao usa o perfil pessoal)`r`nset `"APPDATA=%~dp0profiles\$($row.key)\appdata`"`r`nset `"LOCALAPPDATA=%~dp0profiles\$($row.key)\localappdata`"`r`nstart `"`" /D `"%~dp0`" `"%~dp0$pkBaseName.exe`"`r`n"
        [IO.File]::WriteAllText($cmd, $body, [Text.Encoding]::ASCII)
        $link = $shell.CreateShortcut((Join-Path $pkOutput ("Jogar E10a - $($row.class_name) - $($row.build_name).lnk")))
        $link.TargetPath = $cmd; $link.WorkingDirectory = $pkOutput; $link.WindowStyle = 7
        $link.IconLocation = $pkExe + ',0'; $link.Description = "RagRPG E10a candidato - $($row.class_name), $($row.build_name) (perfil isolado)"
        $link.Save()
    }
    Get-ChildItem -LiteralPath $pkOutput -Filter '*.lnk' | ForEach-Object { Write-Output $_.Name }
    return
}

if ($Stage -eq 'Smoke') {
    # Open the EXE through one launcher environment briefly, then close it; profile must not change.
    $index = Get-Content -LiteralPath (Join-Path $pkOutput 'profiles/index.json') -Raw | ConvertFrom-Json
    $key = $index[0].key
    $grpProfile = Join-Path $pkOutput "profiles/$key"
    $profileFile = Join-Path $grpProfile ("appdata/Godot/app_userdata/$pkAppName/profile.json")
    $before = Get-Sha $profileFile
    $info = [Diagnostics.ProcessStartInfo]::new(); $info.FileName = $pkExe; $info.WorkingDirectory = $pkOutput; $info.UseShellExecute = $false
    $info.Environment['APPDATA'] = Join-Path $grpProfile 'appdata'; $info.Environment['LOCALAPPDATA'] = Join-Path $grpProfile 'localappdata'
    $smokeLog = Join-Path $pkEvidence 'smoke.engine.log'
    foreach ($arg in @('--log-file', $smokeLog)) { $info.ArgumentList.Add($arg) }
    $process = [Diagnostics.Process]::Start($info)
    Start-Sleep -Seconds 25
    $alive = -not $process.HasExited
    $process.Refresh(); $title = $process.MainWindowTitle; $ws = $process.WorkingSet64
    $closed = $false
    if ($alive) { $closed = $process.CloseMainWindow(); if (-not $process.WaitForExit(15000)) { $process.Kill($true); $process.WaitForExit() } }
    $engineText = if (Test-Path -LiteralPath $smokeLog) { [IO.File]::ReadAllText($smokeLog) } else { '' }
    $errors = @([regex]::Matches($engineText, '(?m)^.*(SCRIPT ERROR:|Parse Error:|ERROR:).*$') | ForEach-Object { $_.Value })
    $after = Get-Sha $profileFile
    $record = [ordered]@{ name = 'smoke_open_close'; ok = ($alive -and $errors.Count -eq 0); alive_after_25s = $alive; window_title = $title; working_set_bytes = $ws; close_requested = $closed; exit_code = $process.ExitCode; error_lines = $errors; profile = $grpProfile; profile_sha256_before = $before; profile_sha256_after = $after }
    Add-Run $pkRuns $record
    $record | ConvertTo-Json -Depth 5 | Write-Output
    return
}
