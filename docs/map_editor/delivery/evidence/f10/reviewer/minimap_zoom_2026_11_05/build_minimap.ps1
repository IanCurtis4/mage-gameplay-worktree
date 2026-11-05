param([switch]$ReuseExport, [Parameter(Mandatory)][string]$ExpectedCommit)
$ErrorActionPreference = 'Stop'
$buildSource = 'C:\Users\João Pedro\Documents\ChatGPT\RagRPG\.tools\map-editor-m5'
$buildFixture = Join-Path $buildSource '.godot/verification/e07_f1/fixture_project'
$buildEngine = 'C:\Users\João Pedro\Documents\ChatGPT\RagRPG\.tools\godot\Godot_v4.7.2-stable_win64.exe'
$buildTemplate = 'C:/Users/João Pedro/AppData/Roaming/Godot/export_templates/4.7.2.stable/windows_release_x86_64.exe'
$buildHead = (git -C $buildSource rev-parse HEAD).Trim()
if ($LASTEXITCODE -ne 0 -or $buildHead -ne $ExpectedCommit) { throw 'Candidato inesperado.' }
$buildOutput = Join-Path $PSScriptRoot ('minimap_' + $buildHead.Substring(0, 8))
if ((Test-Path -LiteralPath $buildOutput) -and -not $ReuseExport) { throw 'O destino já existe; preservar a entrega anterior.' }
$buildHashes = Get-Content -LiteralPath (Join-Path $buildFixture 'source_hashes.json') -Raw | ConvertFrom-Json -AsHashtable
foreach ($buildRelative in $buildHashes.Keys) {
    foreach ($buildSide in @($buildSource, $buildFixture)) {
        $buildInput = Join-Path $buildSide $buildRelative
        if (-not (Test-Path -LiteralPath $buildInput) -or (Get-FileHash -LiteralPath $buildInput).Hash.ToLowerInvariant() -ne $buildHashes[$buildRelative]) { throw "Fonte divergente: $buildRelative" }
    }
}
[void](New-Item -ItemType Directory -Force -Path $buildOutput)
$buildEvidence = Join-Path $buildOutput 'validation'
[void](New-Item -ItemType Directory -Force -Path $buildEvidence)
$buildExe = Join-Path $buildOutput 'RagRPG-F10-Q5-Mapa.exe'
$buildRuns = [Collections.Generic.List[object]]::new()
if ($ReuseExport) {
    foreach ($buildPriorRun in (Get-Content -LiteralPath (Join-Path $buildEvidence 'runs.json') -Raw | ConvertFrom-Json)) { $buildRuns.Add($buildPriorRun) }
    if (-not @($buildRuns | Where-Object { $_.name -eq 'export' -and $_.ok }).Count) { throw 'Exportação anterior não foi aprovada.' }
    foreach ($buildExistingArtifact in @($buildExe, [IO.Path]::ChangeExtension($buildExe, '.pck'))) { if (-not (Test-Path -LiteralPath $buildExistingArtifact)) { throw 'Artefato anterior ausente.' } }
}
function Invoke-DeliveryProcess([string]$Name, [string]$Executable, [string[]]$Arguments, [int]$TimeoutSeconds = 300) {
    $buildInfo = [Diagnostics.ProcessStartInfo]::new()
    $buildInfo.FileName = $Executable
    $buildInfo.WorkingDirectory = $buildOutput
    $buildInfo.UseShellExecute = $false
    $buildInfo.CreateNoWindow = $true
    $buildInfo.WindowStyle = [Diagnostics.ProcessWindowStyle]::Hidden
    $buildInfo.RedirectStandardOutput = $true
    $buildInfo.RedirectStandardError = $true
    $buildInfo.Environment['APPDATA'] = Join-Path $buildEvidence ($Name + '_profile')
    $buildInfo.Environment['LOCALAPPDATA'] = $buildInfo.Environment['APPDATA']
    $buildInfo.Environment['F10_EVIDENCE'] = $buildEvidence
    [void](New-Item -ItemType Directory -Force -Path $buildInfo.Environment['APPDATA'])
    foreach ($buildArgument in @('--log-file', (Join-Path $buildEvidence ($Name + '.engine.log'))) + $Arguments) { $buildInfo.ArgumentList.Add($buildArgument) }
    $buildProcess = [Diagnostics.Process]::new()
    $buildProcess.StartInfo = $buildInfo
    $buildStarted = [DateTime]::UtcNow
    [void]$buildProcess.Start()
    $buildStdout = $buildProcess.StandardOutput.ReadToEndAsync()
    $buildStderr = $buildProcess.StandardError.ReadToEndAsync()
    $buildTimedOut = -not $buildProcess.WaitForExit($TimeoutSeconds * 1000)
    if ($buildTimedOut) { $buildProcess.Kill($true); $buildProcess.WaitForExit() }
    $buildText = $buildStdout.GetAwaiter().GetResult() + $buildStderr.GetAwaiter().GetResult()
    [IO.File]::WriteAllText((Join-Path $buildEvidence ($Name + '.output.log')), $buildText)
    $buildEngineLog = [IO.File]::ReadAllText((Join-Path $buildEvidence ($Name + '.engine.log')))
    $buildPassed = -not $buildTimedOut -and $buildProcess.ExitCode -eq 0 -and ($buildText + $buildEngineLog) -notmatch 'SCRIPT ERROR:|Parse Error:|ERROR:'
    $buildRuns.Add(@{name=$Name;started_utc=$buildStarted.ToString('o');finished_utc=[DateTime]::UtcNow.ToString('o');exit_code=$buildProcess.ExitCode;timed_out=$buildTimedOut;ok=$buildPassed;arguments=$Arguments})
    [IO.File]::WriteAllText((Join-Path $buildEvidence 'runs.json'), (ConvertTo-Json -InputObject @($buildRuns.ToArray()) -Depth 8))
    $buildProcess.Dispose()
    Write-Output "$Name : $buildPassed"
    if (-not $buildPassed) { throw "Falha na entrega $Name. Consulte os logs preservados." }
}
$buildProjectPath = Join-Path $buildFixture 'project.godot'
$buildPresetPath = Join-Path $buildFixture 'export_presets.cfg'
$buildProjectBefore = [IO.File]::ReadAllBytes($buildProjectPath)
$buildPresetBefore = [IO.File]::ReadAllBytes($buildPresetPath)
if (-not $ReuseExport) { try {
    $buildProject = [IO.File]::ReadAllText((Join-Path $buildSource 'project.godot')).Replace('version_control/autoload_on_startup=true', 'version_control/autoload_on_startup=false').Replace('config/name="RagRPG"', 'config/name="RagRPG F10 Q5 Mapa"')
    $buildProject += "`n[editor_plugins]`nenabled=PackedStringArray(`"res://addons/ragrpg_map_editor/plugin.cfg`")`n"
    if ($buildProject -notmatch 'run/main_scene="res://scenes/character_menu.tscn"') { throw 'A entrega deve abrir no menu normal.' }
    $buildPreset = [IO.File]::ReadAllText((Join-Path $buildSource 'export_presets.cfg')).Replace('custom_template/release=""', ('custom_template/release="' + $buildTemplate + '"')).Replace('exclude_filter=""', 'exclude_filter="addons/godot-git-plugin/*"').Replace('debug/export_console_wrapper=1', 'debug/export_console_wrapper=0')
    [IO.File]::WriteAllText($buildProjectPath, $buildProject)
    [IO.File]::WriteAllText($buildPresetPath, $buildPreset)
    [IO.File]::WriteAllText((Join-Path $buildEvidence 'packaged_project.godot'), $buildProject)
    [IO.File]::WriteAllText((Join-Path $buildEvidence 'packaged_export_presets.cfg'), $buildPreset)
    Invoke-DeliveryProcess 'export' $buildEngine @('--headless', '--path', $buildFixture, '--export-release', 'Windows Desktop', $buildExe)
} finally {
    [IO.File]::WriteAllBytes($buildProjectPath, $buildProjectBefore)
    [IO.File]::WriteAllBytes($buildPresetPath, $buildPresetBefore)
} }
$buildProbe = @'
extends SceneTree
func _initialize() -> void:
	var main_scene: String = ProjectSettings.get_setting("application/run/main_scene", "")
	var app_name: String = ProjectSettings.get_setting("application/config/name", "")
	var result := {"main_scene": main_scene, "app_name": app_name, "user_data_dir": OS.get_user_data_dir(), "character_menu": ResourceLoader.exists("res://scenes/character_menu.tscn"), "forest_phase": FileAccess.file_exists("res://data/expedition/phases/forest_sanctuary.json"), "registry": FileAccess.file_exists("res://data/map_authoring/release_packages.json"), "preparation_manifest": FileAccess.file_exists("res://scripts/core/expedition/snapshot/runtime_manifest.json")}
	var ok := main_scene == "res://scenes/character_menu.tscn" and app_name == "RagRPG F10 Q5 Mapa" and OS.get_user_data_dir().ends_with("RagRPG F10 Q5 Mapa")
	for key: String in ["character_menu", "forest_phase", "registry", "preparation_manifest"]:
		ok = ok and bool(result[key])
	result["ok"] = ok
	print("F10_PACK_INSPECTION ", JSON.stringify(result))
	quit(0 if ok else 1)
'@
$buildProbePath = Join-Path $buildEvidence 'inspect_pack.gd'
[IO.File]::WriteAllText($buildProbePath, $buildProbe)
if (-not @($buildRuns | Where-Object { $_.name -eq 'inspect_pack_editor' -and $_.ok }).Count) { Invoke-DeliveryProcess 'inspect_pack_editor' $buildEngine @('--headless', '--main-pack', [IO.Path]::ChangeExtension($buildExe, '.pck'), '--script', $buildProbePath) 90 }
if (-not @($buildRuns | Where-Object { $_.name -eq 'normal_boot' -and $_.ok }).Count) { Invoke-DeliveryProcess 'normal_boot' $buildExe @('--rendering-method', 'gl_compatibility', '--quit-after', '120', '--verbose') 90 }
$buildUiProbe = @'
extends SceneTree
func _initialize() -> void:
	call_deferred("_run")
func _run() -> void:
	var menu: Node = (load(ProjectSettings.get_setting("application/run/main_scene")) as PackedScene).instantiate()
	root.add_child(menu)
	await process_frame
	var facade: Variant = menu.get("facade")
	var initially_writable := not bool(menu.get("_read_only")) and facade.current_profile() != null
	(menu.get("name_input") as LineEdit).text = "Verificação F10"
	var created: Dictionary = menu.call("create_character", &"swordsman")
	var persisted := FileAccess.file_exists("user://profile.json")
	var reopened: Dictionary = facade.open_profile()
	var profile: Variant = facade.current_profile()
	var has_character: bool = profile != null and profile.characters.size() == 1
	var forest_listed := false
	if has_character:
		var panel: Node = load("res://scripts/ui/expedition/phase_selection_panel.gd").new()
		menu.add_child(panel)
		panel.call("configure", menu, profile.characters[0].character_id)
		var selector: OptionButton = panel.get("phase_choice")
		for index: int in selector.item_count:
			if selector.get_item_text(index) == "Floresta do Santuário":
				forest_listed = true
				selector.select(index)
				panel.call("_describe")
		await process_frame
		await process_frame
		root.get_texture().get_image().save_png(OS.get_environment("F10_EVIDENCE").path_join("normal_lobby.png"))
	var result := {"menu_writable": initially_writable, "character_created": bool(created.get("ok", false)), "profile_persisted": persisted, "profile_reopened": bool(reopened.get("ok", false)), "one_character": has_character, "forest_listed": forest_listed, "user_data_dir": OS.get_user_data_dir()}
	var ok := initially_writable and bool(created.get("ok", false)) and persisted and bool(reopened.get("ok", false)) and has_character and forest_listed
	result["ok"] = ok
	print("F10_NORMAL_MENU ", JSON.stringify(result))
	menu.queue_free()
	await process_frame
	quit(0 if ok else 1)
'@
$buildUiProbePath = Join-Path $buildEvidence 'normal_menu_probe.gd'
[IO.File]::WriteAllText($buildUiProbePath, $buildUiProbe)
Invoke-DeliveryProcess 'normal_menu_pack' $buildEngine @('--main-pack', [IO.Path]::ChangeExtension($buildExe, '.pck'), '--rendering-method', 'gl_compatibility', '--script', $buildUiProbePath) 90
$buildExpectedProfile = Join-Path $buildEvidence 'normal_menu_pack_profile/Godot/app_userdata/RagRPG F10 Q5 Mapa/profile.json'
if (-not (Test-Path -LiteralPath $buildExpectedProfile)) { throw 'A criação de personagem não salvou o perfil isolado esperado.' }
$buildSavedProfile = Get-Content -LiteralPath $buildExpectedProfile -Raw | ConvertFrom-Json
$buildArtifacts = foreach ($buildArtifactPath in @($buildExe, [IO.Path]::ChangeExtension($buildExe, '.pck'))) {
    $buildArtifact = Get-Item -LiteralPath $buildArtifactPath
    @{file=$buildArtifact.Name;bytes=$buildArtifact.Length;sha256=(Get-FileHash -LiteralPath $buildArtifact.FullName).Hash.ToLowerInvariant()}
}
$buildManifest = @{candidate_commit=$buildHead;runtime_commit=$buildHead;source=$buildSource;fixture=$buildFixture;source_inputs_checked=$buildHashes.Count;engine=$buildEngine;engine_sha256=(Get-FileHash -LiteralPath $buildEngine).Hash.ToLowerInvariant();template=$buildTemplate;template_sha256=(Get-FileHash -LiteralPath $buildTemplate).Hash.ToLowerInvariant();artifacts=@($buildArtifacts);main_scene='res://scenes/character_menu.tscn';application_name='RagRPG F10 Q5 Mapa';test_save_directory=(Join-Path $env:APPDATA 'Godot/app_userdata/RagRPG F10 Q5 Mapa');packaging_deltas=@('VCS autoload disabled','Map editor export plugin enabled to preserve original dependency bytes','Release template absolute path','Git plugin excluded','Console wrapper disabled','Application name isolates saves');fixture_project_restored=((Get-FileHash -LiteralPath $buildProjectPath).Hash -eq [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($buildProjectBefore)));fixture_preset_restored=((Get-FileHash -LiteralPath $buildPresetPath).Hash -eq [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($buildPresetBefore)));normal_profile_file=$buildExpectedProfile;runs=$buildRuns.ToArray();generated_utc=[DateTime]::UtcNow.ToString('o')}
[IO.File]::WriteAllText((Join-Path $buildOutput 'build_manifest.json'), (ConvertTo-Json -InputObject $buildManifest -Depth 10))
Write-Output (ConvertTo-Json -InputObject $buildManifest -Depth 4)
$buildForestProbePath = Join-Path $buildEvidence 'forest_map_probe.gd'
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'forest_map_probe.gd') -Destination $buildForestProbePath
Invoke-DeliveryProcess 'forest_map_pack' $buildEngine @('--main-pack', [IO.Path]::ChangeExtension($buildExe, '.pck'), '--rendering-method', 'gl_compatibility', '--script', $buildForestProbePath) 360
$buildForestText = [IO.File]::ReadAllText((Join-Path $buildEvidence 'forest_map_pack.output.log'))
$buildForestMatch = [regex]::Match($buildForestText, '(?m)^F10_FOREST_MAP_RESULT (.+)$')
if (-not $buildForestMatch.Success) { throw 'A prova do mapa não produziu resultado.' }
$buildForestResult = ConvertFrom-Json $buildForestMatch.Groups[1].Value
if (-not $buildForestResult.ok -or $buildForestResult.count -ne 13) { throw 'A prova do mapa completo não foi aprovada.' }
$buildManifest['runs'] = $buildRuns.ToArray()
$buildManifest['forest_map_result'] = $buildForestResult
[IO.File]::WriteAllText((Join-Path $buildOutput 'build_manifest.json'), (ConvertTo-Json -InputObject $buildManifest -Depth 12))
Write-Output 'F10_MINIMAP_BUILD_READY'
