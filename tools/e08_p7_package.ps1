# E08 P7-C3: candidate export, exact-PCK probes, measurements, review profiles, launchers and smoke.
# Derived from tools/build_e08_pilot.ps1 (P0/P3 pilot protocol): standard engine, verified release
# template, map-editor export plugin enabled for byte parity, isolated app name and APPDATA.
# Never touches the habitual checkout (codex/playtest), the P3 pilot folder or personal saves.
param(
    [Parameter(Mandatory)][ValidateSet('Export','Inspect','Measure','Profiles','Launchers','Smoke')][string]$Stage,
    [Parameter(Mandatory)][ValidatePattern('^[0-9a-f]{40}$')][string]$CandidateCommit,
    [ValidatePattern('^[a-z0-9_]+$')][string]$EvidenceName='',
    [ValidateSet('baseline','pilot','reference','candidate')][string[]]$Packs=@('baseline','pilot','candidate'),
    # Optional earlier candidate PCK (exact path) measured in the same session as 'reference'.
    [string]$ReferencePack='',
    [ValidateSet('crowd','forest','preparation','ablation','p6_cost')][string[]]$Probes=@('crowd','forest','preparation','ablation'),
    [ValidateRange(1,5)][int]$Rounds=2,
    [int]$LockWaitMinutes=60
)
$ErrorActionPreference = 'Stop'
$pkSource = Split-Path -Parent $PSScriptRoot
[Environment]::CurrentDirectory = $pkSource
Set-Location -LiteralPath $pkSource
$pkFixture = Join-Path $pkSource '.godot/verification/e07_f1/fixture_project'
$pkEngine = Join-Path (Split-Path -Parent $pkSource) 'godot/Godot_v4.7.2-stable_win64.exe'
$pkEngineSha = 'ab1824f85bfd8e0e4128182c000c4003a3e042245b2967848d089b2a04b22424'
$pkTemplate = 'C:/Users/João Pedro/AppData/Roaming/Godot/export_templates/4.7.2.stable/windows_release_x86_64.exe'
$pkTemplateSha = 'd34d36f3be1a6c49c56525ae86469b92e4f417ddf0b43cf00dd80c385c4b0562'
$pkAppName = 'RagRPG E08 Candidato'
$pkBaseName = 'RagRPG-E08-Candidato'
$pkOutput = Join-Path (Split-Path -Parent $pkSource) ('playtest_e08/e08_' + $CandidateCommit.Substring(0, 8))
$pkExe = Join-Path $pkOutput ($pkBaseName + '.exe')
$pkPck = Join-Path $pkOutput ($pkBaseName + '.pck')
$pkEvidence = Join-Path $pkOutput 'validation'
$pkBaseline = Join-Path (Split-Path -Parent $pkSource) 'playtest_f10/terrain_2ff1c00f/RagRPG-F10-Q5-Terreno.pck'
$pkBaselineSha = '136d35e0d059572b633e2d743fba839e97273b1aaa11d7f41c28ad9b0b9dee3a'
$pkPilot = Join-Path (Split-Path -Parent $pkSource) 'playtest_e08/pilot_ad09b99d/RagRPG-E08-Piloto1.pck'
$pkPilotSha = 'd91bc71373ec370e744b61032b7aed036f4895620241027b29c0b505c81246e2'
$pkGroups = [ordered]@{ melee = 'Corpo a corpo'; magic = 'Magia'; ranged = 'Arco' }
$pkLock = Join-Path $pkSource '.godot/verification/p5/fixture.lock'
if ($pkOutput -match 'pilot_') { throw 'Refusing the P3 pilot folder.' }
if ((Get-FileHash -LiteralPath $pkEngine -Algorithm SHA256).Hash.ToLowerInvariant() -ne $pkEngineSha) { throw 'Unexpected standard engine.' }
function Get-Sha([string]$Path) { (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant() }
function Enter-Lock([string]$Owner) {
    $deadline = [DateTime]::UtcNow.AddMinutes($LockWaitMinutes)
    while ($true) {
        try { [void](New-Item -ItemType Directory -Path $pkLock -ErrorAction Stop); break } catch {
            if ([DateTime]::UtcNow -gt $deadline) { throw "Fixture lock busy: $pkLock" }
            Start-Sleep -Seconds 10
        }
    }
    Set-Content -LiteralPath (Join-Path $pkLock 'owner.txt') -Value "C3_sol_release $Owner $([DateTime]::UtcNow.ToString('o'))"
}
function Exit-Lock { Remove-Item -LiteralPath $pkLock -Recurse -Force -ErrorAction SilentlyContinue }
function Add-Run([string]$RunsFile, [hashtable]$Record) {
    $all = [Collections.Generic.List[object]]::new()
    if (Test-Path -LiteralPath $RunsFile) { foreach ($old in @(Get-Content -LiteralPath $RunsFile -Raw | ConvertFrom-Json)) { $all.Add($old) } }
    $all.Add($Record)
    [IO.File]::WriteAllText($RunsFile, (ConvertTo-Json -InputObject @($all.ToArray()) -Depth 20))
}
# One process, sampled working set (RSS) while alive, raw output kept, strict error scan.
function Invoke-Pk([string]$Name, [string]$Executable, [string[]]$Arguments, [string]$Folder, [string]$ProfileDir, [int]$TimeoutSeconds = 300, [string]$Marker = '', [hashtable]$Environment = @{}) {
    [void](New-Item -ItemType Directory -Force -Path $Folder)
    [void](New-Item -ItemType Directory -Force -Path $ProfileDir)
    $info = [Diagnostics.ProcessStartInfo]::new()
    $info.FileName = $Executable
    $info.WorkingDirectory = $Folder
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
    $watch = [Diagnostics.Stopwatch]::StartNew(); $timedOut = $false; $peakWs = 0L; $peakPrivate = 0L
    while (-not $process.WaitForExit(250)) {
        try { $process.Refresh(); $peakWs = [Math]::Max($peakWs, $process.PeakWorkingSet64); $peakPrivate = [Math]::Max($peakPrivate, $process.PrivateMemorySize64) } catch [InvalidOperationException] {}
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
    $record = [ordered]@{ name = $Name; ok = $ok; exit_code = $process.ExitCode; timed_out = $timedOut; started_utc = $started.ToString('o'); elapsed_seconds = [Math]::Round(([DateTime]::UtcNow - $started).TotalSeconds, 3); executable = $Executable; executable_sha256 = (Get-Sha $Executable); arguments = $Arguments; profile = $ProfileDir; sampled_peak_working_set_bytes = $(if ($peakWs -gt 0) { $peakWs } else { $null }); sampled_peak_private_bytes = $(if ($peakPrivate -gt 0) { $peakPrivate } else { $null }); error_lines = $errors; output_sha256 = (Get-Sha (Join-Path $Folder ($Name + '.output.log'))); result = $result }
    $process.Dispose()
    Write-Host ("{0}: ok={1} exit={2} timeout={3} {4:n1}s" -f $Name, $ok, $record.exit_code, $timedOut, $record.elapsed_seconds)
    return $record
}

if ($Stage -eq 'Export') {
    $head = (git -C $pkSource rev-parse HEAD).Trim()
    if ($head -ne $CandidateCommit) { throw "HEAD $head is not the candidate $CandidateCommit." }
    # Uncommitted edits are allowed only in packaging tools/docs (never exported runtime).
    $dirty = @(git -C $pkSource status --porcelain --untracked-files=no | ForEach-Object { $_.Substring(3) })
    if ($dirty | Where-Object { $_ -notmatch '^(docs/|tools/(e08_p7_|prepare_e08_p4_review_profile))' }) { throw 'Tracked runtime changes present: commit the candidate before export.' }
    if ((Get-Sha $pkTemplate) -ne $pkTemplateSha) { throw 'Unexpected Windows release template.' }
    if ((Get-PSDrive C).Free -lt 1GB) { throw 'Insufficient free space.' }
    if (Test-Path -LiteralPath $pkOutput) { throw "Destination exists; preserve it: $pkOutput" }
    Enter-Lock 'export'
    try {
        # 1. Fixture parity: every manifest input equal in source and fixture; every tracked
        #    runtime-relevant file of the commit present and equal in the fixture.
        $hashes = Get-Content -LiteralPath (Join-Path $pkFixture 'source_hashes.json') -Raw | ConvertFrom-Json -AsHashtable
        foreach ($rel in $hashes.Keys) {
            foreach ($side in @($pkSource, $pkFixture)) {
                $inPath = Join-Path $side $rel
                if (-not (Test-Path -LiteralPath $inPath) -or (Get-Sha $inPath) -ne $hashes[$rel]) { throw "Source/fixture mismatch (sync first): $rel" }
            }
        }
        $tracked = @(git -C $pkSource ls-files -- scripts scenes assets data resources content addons) | Where-Object { $_ -notlike 'addons/godot-git-plugin/*' }
        $trackedSet = [Collections.Generic.HashSet[string]]::new([string[]]$tracked)
        $notInFixture = [Collections.Generic.List[string]]::new(); $runtimeMissing = [Collections.Generic.List[string]]::new(); $differs = [Collections.Generic.List[string]]::new()
        foreach ($rel in $tracked) {
            $target = Join-Path $pkFixture $rel
            $runtime = $rel -match '\.(gd|tscn|tres|wav|ogg|rpp|navproof|cfg|ttf|otf|gdshader|import)$' -or ($rel -match '\.png$' -and $trackedSet.Contains($rel + '.import')) -or ($rel -match '\.json$' -and $rel -notmatch '(/staging/|provenance\.json$|source_recipe\.json$|/e08_head_fit/)')
            if (-not (Test-Path -LiteralPath $target)) { $notInFixture.Add($rel); if ($runtime) { $runtimeMissing.Add($rel) }; continue }
            if ($rel -notlike '*.import' -and (Get-Sha (Join-Path $pkSource $rel)) -ne (Get-Sha $target)) { $differs.Add($rel) }
        }
        if ($runtimeMissing.Count -or $differs.Count) { throw ("Fixture is not the candidate: missing runtime " + ($runtimeMissing -join ', ') + ' / differs ' + ($differs -join ', ')) }
        [void](New-Item -ItemType Directory -Force -Path $pkEvidence)
        [IO.File]::WriteAllText((Join-Path $pkEvidence 'fixture_parity.json'), (ConvertTo-Json -Depth 4 -InputObject ([ordered]@{ candidate_commit = $CandidateCommit; manifest_inputs_checked = $hashes.Count; tracked_runtime_dirs = $tracked.Count; tracked_not_in_fixture_non_runtime = @($notInFixture.ToArray()); rule = 'non-runtime = source art/recipes/provenance without tracked .import; they are not exported' })))
        # 2. Packaged project/preset written into the fixture for the export only, then restored.
        $projectPath = Join-Path $pkFixture 'project.godot'; $presetPath = Join-Path $pkFixture 'export_presets.cfg'
        $projectBefore = [IO.File]::ReadAllBytes($projectPath); $presetBefore = [IO.File]::ReadAllBytes($presetPath)
        $runs = Join-Path $pkEvidence 'runs.json'
        try {
            $project = [IO.File]::ReadAllText((Join-Path $pkSource 'project.godot')).Replace('version_control/autoload_on_startup=true', 'version_control/autoload_on_startup=false').Replace('config/name="RagRPG"', ('config/name="' + $pkAppName + '"'))
            if ($project -notmatch [regex]::Escape('config/name="' + $pkAppName + '"')) { throw 'Application name not applied.' }
            if ($project -notmatch 'run/main_scene="res://scenes/character_menu.tscn"') { throw 'The candidate must open in the normal menu.' }
            $project += "`n[editor_plugins]`nenabled=PackedStringArray(`"res://addons/ragrpg_map_editor/plugin.cfg`")`n"
            $preset = [IO.File]::ReadAllText((Join-Path $pkSource 'export_presets.cfg')).Replace('custom_template/release=""', ('custom_template/release="' + $pkTemplate + '"')).Replace('exclude_filter=""', 'exclude_filter="addons/godot-git-plugin/*"').Replace('debug/export_console_wrapper=1', 'debug/export_console_wrapper=0')
            [IO.File]::WriteAllText($projectPath, $project); [IO.File]::WriteAllText($presetPath, $preset)
            [IO.File]::WriteAllText((Join-Path $pkEvidence 'packaged_project.godot'), $project)
            [IO.File]::WriteAllText((Join-Path $pkEvidence 'packaged_export_presets.cfg'), $preset)
            $record = Invoke-Pk 'export' $pkEngine @('--headless', '--path', $pkFixture, '--export-release', 'Windows Desktop', $pkExe) $pkEvidence (Join-Path $pkEvidence 'profile_export') 900
            Add-Run $runs $record
            if (-not $record.ok) { throw 'Export failed; logs preserved.' }
        } finally {
            [IO.File]::WriteAllBytes($projectPath, $projectBefore); [IO.File]::WriteAllBytes($presetPath, $presetBefore)
        }
        $restored = (Get-Sha $projectPath) -eq ([Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($projectBefore))).ToLowerInvariant() -and (Get-Sha $presetPath) -eq ([Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($presetBefore))).ToLowerInvariant()
        if (-not $restored) { throw 'Fixture project/preset not restored.' }
        $artifacts = foreach ($path in @($pkExe, $pkPck)) { $item = Get-Item -LiteralPath $path; [ordered]@{ file = $item.Name; bytes = $item.Length; sha256 = (Get-Sha $path) } }
        $manifest = [ordered]@{ candidate_commit = $CandidateCommit; source = $pkSource; fixture = $pkFixture; engine = $pkEngine; engine_sha256 = (Get-Sha $pkEngine); template = $pkTemplate; template_sha256 = (Get-Sha $pkTemplate); application_name = $pkAppName; main_scene = 'res://scenes/character_menu.tscn'; artifacts = @($artifacts); packaging_deltas = @('VCS autoload disabled', 'Map editor export plugin enabled to preserve original dependency bytes', 'Release template absolute path', 'Git plugin excluded', 'Console wrapper disabled', 'Application name isolates saves'); fixture_project_restored = $restored; generated_utc = [DateTime]::UtcNow.ToString('o') }
        [IO.File]::WriteAllText((Join-Path $pkOutput 'build_manifest.json'), (ConvertTo-Json -InputObject $manifest -Depth 8))
        Write-Output (ConvertTo-Json -InputObject $manifest -Depth 4)
    } finally { Exit-Lock }
    return
}

if (-not (Test-Path -LiteralPath $pkPck)) { throw 'Export the candidate first.' }
$pkBuild = Get-Content -LiteralPath (Join-Path $pkOutput 'build_manifest.json') -Raw | ConvertFrom-Json
foreach ($artifact in $pkBuild.artifacts) {
    $path = Join-Path $pkOutput $artifact.file
    if ((Get-Item -LiteralPath $path).Length -ne $artifact.bytes -or (Get-Sha $path) -ne $artifact.sha256) { throw "Artifact changed after export: $($artifact.file)" }
}
# Later commits may only add tools/docs relative to the exported candidate.
$pkHead = (git -C $pkSource rev-parse HEAD).Trim()
if ($pkHead -ne $CandidateCommit) {
    $later = @(git -C $pkSource diff --name-only $CandidateCommit $pkHead)
    if ($later | Where-Object { $_ -notmatch '^(docs/|tools/(e08_p7_|prepare_e08_p4_review_profile))' }) { throw 'HEAD has runtime deltas after the candidate.' }
}
$pkRuns = Join-Path $pkEvidence 'runs.json'

if ($Stage -eq 'Inspect') {
    # Expected E08 runtime assets, from the candidate commit itself.
    $files = @(git -C $pkSource ls-tree -r --name-only $CandidateCommit -- assets data scripts/actors/equipment_head_fit_data.gd)
    $set = [Collections.Generic.HashSet[string]]::new([string[]]$files)
    $res = { param($p) 'res://' + $p }
    $expected = [ordered]@{
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
    # Import chain of every headgear PNG: commit blob == worktree file, md5 == fixture import source_md5, fixture .ctex sha256.
    $expected.image_identity = @($files | Where-Object { $_ -match '^assets/art/equipment/headgear/[^/]+\.png$' -and $set.Contains($_ + '.import') } | ForEach-Object {
        if ((git -C $pkSource hash-object -- $_).Trim() -ne (git -C $pkSource rev-parse "$($CandidateCommit):$_").Trim()) { throw "Worktree PNG differs from candidate: $_" }
        $ctexRes = ([regex]::Match((Get-Content -LiteralPath (Join-Path $pkFixture ($_ + '.import')) -Raw), '(?m)^path="(res://[^"]+\.ctex)"')).Groups[1].Value
        $ctexDisk = Join-Path $pkFixture $ctexRes.Substring(6)
        $md5File = [IO.Path]::ChangeExtension($ctexDisk, '.md5')
        $sourceMd5 = ([regex]::Match((Get-Content -LiteralPath $md5File -Raw), 'source_md5="([0-9a-f]+)"')).Groups[1].Value
        [ordered]@{ res = 'res://' + $_; png_sha256 = (Get-Sha (Join-Path $pkSource $_)); ctex = $ctexRes; ctex_sha256 = (Get-Sha $ctexDisk); source_md5_ok = ((Get-FileHash -LiteralPath (Join-Path $pkFixture $_) -Algorithm MD5).Hash.ToLowerInvariant() -eq $sourceMd5 -and (Get-Sha (Join-Path $pkFixture $_)) -eq (Get-Sha (Join-Path $pkSource $_))) }
    })
    [void](New-Item -ItemType Directory -Force -Path $pkEvidence)
    $expectedPath = Join-Path $pkEvidence 'expected_assets.json'
    [IO.File]::WriteAllText($expectedPath, (ConvertTo-Json -InputObject $expected -Depth 4))
    $probe = Join-Path $pkSource 'tools/e08_p7_release_probe.gd'
    Copy-Item -LiteralPath $probe -Destination (Join-Path $pkEvidence 'e08_p7_release_probe.gd') -Force
    # Fresh profile per Inspect run, so a rerun never reuses a profile with a character in it.
    $pkStamp = [DateTime]::UtcNow.ToString('yyyyMMddTHHmmss')
    $summary = [ordered]@{}
    $r = Invoke-Pk 'inspect_pack' $pkEngine @('--headless', '--main-pack', $pkPck, '--script', $probe, '--', 'inspect', $pkEvidence, $expectedPath, $pkAppName) $pkEvidence (Join-Path $pkEvidence ('profile_inspect_' + $pkStamp)) 240 'E08_P7_INSPECT_RESULT'
    Add-Run $pkRuns $r; $summary.inspect = $r.ok
    $r = Invoke-Pk 'normal_boot' $pkExe @('--rendering-method', 'gl_compatibility', '--quit-after', '120', '--verbose') $pkEvidence (Join-Path $pkEvidence ('profile_boot_' + $pkStamp)) 120
    Add-Run $pkRuns $r; $summary.normal_boot = $r.ok
    $r = Invoke-Pk 'forest_map_pack' $pkEngine @('--main-pack', $pkPck, '--rendering-method', 'gl_compatibility', '--script', $probe, '--', 'forest', $pkEvidence) $pkEvidence (Join-Path $pkEvidence ('profile_forest_' + $pkStamp)) 480 'E08_P7_FOREST_RESULT'
    Add-Run $pkRuns $r; $summary.forest_map_pack = $r.ok
    $r = Invoke-Pk 'export_content' $pkEngine @('--headless', '--main-pack', $pkPck, '--script', (Join-Path $pkSource 'tools/export_content_probe.gd'), '--', $pkPck) $pkEvidence (Join-Path $pkEvidence ('profile_content_' + $pkStamp)) 240
    Add-Run $pkRuns $r; $summary.export_content_exit = $r.exit_code
    $summary.export_content = $r.ok
    $summary | ConvertTo-Json | Write-Output
    return
}

if ($Stage -eq 'Measure') {
    if (-not $EvidenceName) { throw 'Measure requires -EvidenceName.' }
    if ((Get-Sha $pkBaseline) -ne $pkBaselineSha) { throw 'F10 baseline PCK mismatch.' }
    if ((Get-Sha $pkPilot) -ne $pkPilotSha) { throw 'P3 pilot PCK mismatch.' }
    $root = Join-Path $pkSource ('.godot/verification/p7/C3_sol_release_measure_' + $EvidenceName)
    if (Test-Path -LiteralPath $root) { throw "Evidence name already used: $root" }
    [void](New-Item -ItemType Directory -Force -Path $root)
    $packMap = @{ baseline = $pkBaseline; pilot = $pkPilot; candidate = $pkPck }
    if ($Packs -contains 'reference') { if (-not $ReferencePack -or -not (Test-Path -LiteralPath $ReferencePack)) { throw 'reference requires -ReferencePack' }; $packMap.reference = $ReferencePack }
    $scripts = @{ crowd = 'tools/e08_crowd_compare.gd'; forest = 'tools/e08_terrain_compare.gd'; preparation = 'tools/e08_p7_measure_probe.gd'; ablation = 'tools/e08_p7_measure_probe.gd'; p6_cost = 'tools/e08_p6_vfx_probe.gd' }
    $markers = @{ crowd = 'WORLD_CROWD_RESULT'; forest = 'TERRAIN_PERF_RESULT'; preparation = 'PREPARATION_FINAL_RESULT'; ablation = 'TERRAIN_PERF_RESULT'; p6_cost = '' }
    $gpu = @(Get-CimInstance Win32_VideoController | ForEach-Object { "$($_.Name) $($_.DriverVersion)" })
    $cpu = @(Get-CimInstance Win32_Processor | ForEach-Object { $_.Name })
    [IO.File]::WriteAllText((Join-Path $root 'protocol.json'), (ConvertTo-Json -Depth 5 -InputObject ([ordered]@{ candidate_commit = $CandidateCommit; packs = [ordered]@{ baseline = @{ path = $pkBaseline; sha256 = $pkBaselineSha }; pilot = @{ path = $pkPilot; sha256 = $pkPilotSha }; candidate = @{ path = $pkPck; sha256 = (Get-Sha $pkPck) }; reference = $(if ($ReferencePack) { @{ path = $ReferencePack; sha256 = (Get-Sha $ReferencePack) } } else { $null }) }; engine_sha256 = $pkEngineSha; renderer = 'gl_compatibility windowed 1280x720 vsync off'; seed = 42; rounds = $Rounds; order = 'round-robin by probe, pack order alternates each round'; gpu = $gpu; cpu = $cpu; probes = $scripts })))
    Enter-Lock ('measure ' + $EvidenceName)
    try {
        for ($round = 1; $round -le $Rounds; $round++) {
            $order = @($Packs); if ($round % 2 -eq 0) { [array]::Reverse($order) }
            foreach ($probe in $Probes) {
                foreach ($pack in $order) {
                    if ($probe -eq 'p6_cost' -and $pack -ne 'candidate') { continue }
                    $name = "r$($round)_$($pack)_$probe"
                    $folder = Join-Path $root $name
                    $script = Join-Path $pkSource $scripts[$probe]
                    $arguments = @('--main-pack', $packMap[$pack], '--rendering-method', 'gl_compatibility', '--script', $script)
                    if ($probe -in @('preparation', 'ablation')) { $arguments += @('--', $probe) }
                    if ($probe -eq 'p6_cost') { $arguments += @('--', $folder, 'forest_terraces', 'cost') }
                    $r = Invoke-Pk $name $pkEngine $arguments $folder (Join-Path $folder 'profile') 600 $markers[$probe] @{ TERRAIN_EVIDENCE = $folder }
                    $r['pack'] = $pack; $r['probe'] = $probe; $r['round'] = $round; $r['pack_sha256'] = (Get-Sha $packMap[$pack]); $r['probe_sha256'] = (Get-Sha $script)
                    Add-Run (Join-Path $root 'runs.json') $r
                }
            }
        }
    } finally { Exit-Lock }
    return
}

if ($Stage -eq 'Profiles') {
    $helper = Join-Path $pkSource 'tools/prepare_e08_p4_review_profile.gd'
    Copy-Item -LiteralPath $helper -Destination (Join-Path $pkEvidence 'prepare_e08_p4_review_profile.gd') -Force
    $rootArg = [IO.Path]::GetFullPath($pkOutput).Replace('\', '/')
    foreach ($group in $pkGroups.Keys) {
        $grpProfile = Join-Path $pkOutput ('profiles/' + $group)
        $userDir = Join-Path $grpProfile ('appdata/Godot/app_userdata/' + $pkAppName)
        if (Test-Path -LiteralPath (Join-Path $userDir 'profile.json')) { throw "Profile $group already prepared; preserving it." }
        $r = Invoke-Pk ('profile_' + $group) $pkEngine @('--headless', '--main-pack', $pkPck, '--script', $helper, '--', $group, $rootArg) $pkEvidence $grpProfile 300
        $receipt = Join-Path $userDir 'p4_review_setup.json'
        $r['group'] = $group; $r['receipt'] = $(if (Test-Path -LiteralPath $receipt) { Get-Content -LiteralPath $receipt -Raw | ConvertFrom-Json } else { $null })
        $r['profile_sha256'] = $(if (Test-Path -LiteralPath (Join-Path $userDir 'profile.json')) { Get-Sha (Join-Path $userDir 'profile.json') } else { $null })
        Add-Run $pkRuns $r
        if (-not $r.ok) { throw "Profile $group failed." }
    }
    return
}

if ($Stage -eq 'Launchers') {
    $shell = New-Object -ComObject WScript.Shell
    foreach ($group in $pkGroups.Keys) {
        $cmd = Join-Path $pkOutput ("launch_$group.cmd")
        $body = "@echo off`r`nrem RagRPG E08 candidato - perfil isolado do grupo $group (nao usa o perfil pessoal)`r`nset `"APPDATA=%~dp0profiles\$group\appdata`"`r`nset `"LOCALAPPDATA=%~dp0profiles\$group\localappdata`"`r`nstart `"`" /D `"%~dp0`" `"%~dp0$pkBaseName.exe`"`r`n"
        [IO.File]::WriteAllText($cmd, $body, [Text.Encoding]::ASCII)
        $link = $shell.CreateShortcut((Join-Path $pkOutput ("Jogar E08 - " + $pkGroups[$group] + '.lnk')))
        $link.TargetPath = $cmd; $link.WorkingDirectory = $pkOutput; $link.WindowStyle = 7
        $link.IconLocation = $pkExe + ',0'; $link.Description = "RagRPG E08 candidato - $($pkGroups[$group]) (perfil isolado)"
        $link.Save()
    }
    Get-ChildItem -LiteralPath $pkOutput -Filter '*.lnk' | ForEach-Object { Write-Output $_.Name }
    return
}

if ($Stage -eq 'Smoke') {
    # Open the EXE through the melee launcher environment briefly, then close it.
    $grpProfile = Join-Path $pkOutput 'profiles/melee'
    $before = Get-Sha (Join-Path $grpProfile ('appdata/Godot/app_userdata/' + $pkAppName + '/profile.json'))
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
    $after = Get-Sha (Join-Path $grpProfile ('appdata/Godot/app_userdata/' + $pkAppName + '/profile.json'))
    $record = [ordered]@{ name = 'smoke_open_close'; ok = ($alive -and $errors.Count -eq 0); alive_after_25s = $alive; window_title = $title; working_set_bytes = $ws; close_requested = $closed; exit_code = $process.ExitCode; error_lines = $errors; profile = $grpProfile; profile_sha256_before = $before; profile_sha256_after = $after; user_dir_listing = @(Get-ChildItem -LiteralPath (Join-Path $grpProfile 'appdata/Godot/app_userdata') -Recurse -File | ForEach-Object { [IO.Path]::GetRelativePath($grpProfile, $_.FullName) }) }
    Add-Run $pkRuns $record
    $record | ConvertTo-Json -Depth 5 | Write-Output
    return
}
