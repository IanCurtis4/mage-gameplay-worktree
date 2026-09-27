param(
    [Parameter(Mandatory = $true)][string]$GodotPath,
    [switch]$SkipEditorImport
)
$ErrorActionPreference = 'Stop'
$enginePath = (Resolve-Path -LiteralPath $GodotPath).Path
$projectPath = Split-Path -Parent $PSScriptRoot
$verificationPath = Join-Path $projectPath '.godot/verification'
[void](New-Item -ItemType Directory -Force -Path $verificationPath)
$logPath = Join-Path $verificationPath 'godot.log'

function Invoke-GodotCheck([string[]]$EngineArguments) {
    $startInfo = [System.Diagnostics.ProcessStartInfo]::new()
    $startInfo.FileName = $enginePath
    $startInfo.UseShellExecute = $false
    $startInfo.CreateNoWindow = $true
    $startInfo.RedirectStandardOutput = $true
    $startInfo.RedirectStandardError = $true
    foreach ($argument in @('--log-file', $logPath) + $EngineArguments) { $startInfo.ArgumentList.Add($argument) }
    $process = [System.Diagnostics.Process]::new()
    $process.StartInfo = $startInfo
    [void]$process.Start()
    $stdoutTask = $process.StandardOutput.ReadToEndAsync()
    $stderrTask = $process.StandardError.ReadToEndAsync()
    if (-not $process.WaitForExit(60000)) {
        $process.Kill($true)
        throw 'Godot verification timed out after 60 seconds.'
    }
    $checkOutput = $stdoutTask.GetAwaiter().GetResult() + $stderrTask.GetAwaiter().GetResult()
    $checkExitCode = $process.ExitCode
    $process.Dispose()
    Write-Host $checkOutput
    if ($checkExitCode -ne 0 -or ($checkOutput -match 'SCRIPT ERROR:|Parse Error:|ERROR:')) {
        throw "Godot verification failed (exit $checkExitCode)."
    }
}

if ($SkipEditorImport) {
    Write-Host 'Editor import explicitly skipped; verify import in a clean worktree before using this option.'
} else {
    Invoke-GodotCheck @('--headless', '--path', $projectPath, '--editor', '--import', '--quit')
}
Invoke-GodotCheck @('--headless', '--path', $projectPath, '--script', 'res://tests/foundation_test.gd')
Invoke-GodotCheck @('--headless', '--path', $projectPath, '--script', 'res://tests/combat_animation_test.gd')
Invoke-GodotCheck @('--headless', '--path', $projectPath, '--script', 'res://tests/milestone_one_test.gd')
Invoke-GodotCheck @('--headless', '--path', $projectPath, '--script', 'res://tests/pursuit_momentum_test.gd')
Invoke-GodotCheck @('--headless', '--path', $projectPath, '--script', 'res://tests/battle_ui_test.gd')
Invoke-GodotCheck @('--headless', '--path', $projectPath, '--script', 'res://tests/arena_flow_test.gd')
Invoke-GodotCheck @('--headless', '--path', $projectPath, '--script', 'res://tests/ui_layout_test.gd')
Invoke-GodotCheck @('--headless', '--path', $projectPath, '--script', 'res://tests/mage_gameplay_test.gd')
Invoke-GodotCheck @('--headless', '--path', $projectPath, '--script', 'res://tests/persistent_state_test.gd')
Invoke-GodotCheck @('--headless', '--path', $projectPath, '--script', 'res://tests/profile_store_test.gd')
Invoke-GodotCheck @('--headless', '--path', $projectPath, '--script', 'res://tests/profile_facade_test.gd')
Invoke-GodotCheck @('--headless', '--path', $projectPath, '--script', 'res://tests/profile_run_facade_test.gd')
Invoke-GodotCheck @('--headless', '--path', $projectPath, '--script', 'res://tests/e01_profile_diagnostic_test.gd')
Invoke-GodotCheck @('--headless', '--path', $projectPath, '--script', 'res://tests/e02_character_menu_test.gd')
Invoke-GodotCheck @('--headless', '--path', $projectPath, '--script', 'res://tests/e02_run_integration_test.gd')
Invoke-GodotCheck @('--headless', '--path', $projectPath, '--script', 'res://tests/e03_stat_calculator_test.gd')
Invoke-GodotCheck @('--headless', '--path', $projectPath, '--script', 'res://tests/e03_stat_matrix_test.gd')
Invoke-GodotCheck @('--headless', '--path', $projectPath, '--script', 'res://tests/e03_progression_transactions_test.gd')
Invoke-GodotCheck @('--headless', '--path', $projectPath, '--script', 'res://tests/e03_progression_panel_integration_test.gd')
Invoke-GodotCheck @('--headless', '--path', $projectPath, '--script', 'res://tests/e03_consumer_integration_test.gd')
Invoke-GodotCheck @('--headless', '--path', $projectPath, '--script', 'res://tests/e03_integrated_progression_flow_test.gd')
Invoke-GodotCheck @('--headless', '--path', $projectPath, '--script', 'res://tests/e04_skill_rank_definition_test.gd')
Invoke-GodotCheck @('--headless', '--path', $projectPath, '--script', 'res://tests/e04_slash_rank_integration_test.gd')
Invoke-GodotCheck @('--headless', '--path', $projectPath, '--script', 'res://tests/e04_dash_rank_integration_test.gd')
Invoke-GodotCheck @('--headless', '--path', $projectPath, '--script', 'res://tests/e04_swordsman_resistance_rank_integration_test.gd')
Invoke-GodotCheck @('--headless', '--path', $projectPath, '--script', 'res://tests/e04_fireball_rank_integration_test.gd')
Invoke-GodotCheck @('--headless', '--path', $projectPath, '--script', 'res://tests/e04_fire_wall_rank_integration_test.gd')
Invoke-GodotCheck @('--headless', '--path', $projectPath, '--script', 'res://tests/e04_fire_spear_rank_integration_test.gd')
Invoke-GodotCheck @('--headless', '--path', $projectPath, '--script', 'res://tests/e04_ice_spear_rank_integration_test.gd')
Invoke-GodotCheck @('--headless', '--path', $projectPath, '--script', 'res://tests/e04_teleport_rank_integration_test.gd')
Invoke-GodotCheck @('--headless', '--path', $projectPath, '--script', 'res://tests/e04_mage_sp_regeneration_rank_integration_test.gd')
Invoke-GodotCheck @('--headless', '--path', $projectPath, '--script', 'res://tests/e04_archer_precision_projectile_test.gd')
Invoke-GodotCheck @('--headless', '--path', $projectPath, '--script', 'res://tests/e04_archer_double_shot_rank_integration_test.gd')
Invoke-GodotCheck @('--headless', '--path', $projectPath, '--script', 'res://tests/e04_archer_piercing_arrow_rank_integration_test.gd')
Invoke-GodotCheck @('--headless', '--path', $projectPath, '--script', 'res://tests/e04_archer_arrow_rain_rank_integration_test.gd')
Invoke-GodotCheck @('--headless', '--path', $projectPath, '--script', 'res://tests/e04_archer_extended_aim_rank_integration_test.gd')
Invoke-GodotCheck @('--headless', '--path', $projectPath, '--script', 'res://tests/e04_archer_trap_runtime_test.gd')
Invoke-GodotCheck @('--headless', '--path', $projectPath, '--script', 'res://tests/e04_archer_snare_trap_rank_integration_test.gd')
Invoke-GodotCheck @('--headless', '--path', $projectPath, '--script', 'res://tests/e04_archer_explosive_trap_rank_integration_test.gd')
Invoke-GodotCheck @('--headless', '--path', $projectPath, '--script', 'res://tests/e04_archer_slowing_arrow_rank_integration_test.gd')
Invoke-GodotCheck @('--headless', '--path', $projectPath, '--script', 'res://tests/e04_archer_foliage_shelter_rank_integration_test.gd')
Invoke-GodotCheck @('--headless', '--path', $projectPath, '--script', 'res://tests/e04_archer_precision_rank_integration_test.gd')
Invoke-GodotCheck @('--headless', '--path', $projectPath, '--script', 'res://tests/e04_archer_cadence_rank_integration_test.gd')
Invoke-GodotCheck @('--headless', '--path', $projectPath, '--script', 'res://tests/e04_archer_trap_technique_rank_integration_test.gd')
Invoke-GodotCheck @('--headless', '--path', $projectPath, '--script', 'res://tests/e04_archer_integrated_closure_test.gd')
Invoke-GodotCheck @('--headless', '--path', $projectPath, '--script', 'res://tests/e04_mage_lightning_rank_integration_test.gd')
Invoke-GodotCheck @('--headless', '--path', $projectPath, '--script', 'res://tests/e04_mage_electric_discharge_rank_integration_test.gd')
Invoke-GodotCheck @('--headless', '--path', $projectPath, '--script', 'res://tests/e04_mage_lightning_wall_rank_integration_test.gd')
Invoke-GodotCheck @('--headless', '--path', $projectPath, '--script', 'res://tests/e04_mage_soul_impact_rank_integration_test.gd')
Invoke-GodotCheck @('--headless', '--path', $projectPath, '--script', 'res://tests/e04_mage_haunt_rank_integration_test.gd')
Invoke-GodotCheck @('--headless', '--path', $projectPath, '--script', 'res://tests/e04_mage_phantom_barrier_rank_integration_test.gd')
Invoke-GodotCheck @('--headless', '--path', $projectPath, '--script', 'res://tests/e04_mage_ice_wall_rank_integration_test.gd')
Invoke-GodotCheck @('--headless', '--path', $projectPath, '--script', 'res://tests/e04_mage_integrated_closure_test.gd')
Invoke-GodotCheck @('--headless', '--path', $projectPath, '--script', 'res://tests/e04_swordsman_shield_wall_rank_integration_test.gd')
Invoke-GodotCheck @('--headless', '--path', $projectPath, '--script', 'res://tests/e04_swordsman_provoke_rank_integration_test.gd')
Invoke-GodotCheck @('--headless', '--path', $projectPath, '--script', 'res://tests/e04_swordsman_perseverance_rank_integration_test.gd')
Invoke-GodotCheck @('--headless', '--path', $projectPath, '--script', 'res://tests/e04_swordsman_piercing_shout_rank_integration_test.gd')
Invoke-GodotCheck @('--headless', '--path', $projectPath, '--script', 'res://tests/e04_swordsman_fury_rank_integration_test.gd')
Invoke-GodotCheck @('--headless', '--path', $projectPath, '--script', 'res://tests/e04_swordsman_brutal_strike_rank_integration_test.gd')
Invoke-GodotCheck @('--headless', '--path', $projectPath, '--script', 'res://tests/e04_swordsman_concentrated_rage_rank_integration_test.gd')
Invoke-GodotCheck @('--headless', '--path', $projectPath, '--script', 'res://tests/e04_swordsman_terrifying_shout_rank_integration_test.gd')
Invoke-GodotCheck @('--headless', '--path', $projectPath, '--script', 'res://tests/e04_swordsman_vigor_rank_integration_test.gd')
Invoke-GodotCheck @('--headless', '--path', $projectPath, '--script', 'res://tests/e04_swordsman_blood_thirst_rank_integration_test.gd')
Invoke-GodotCheck @('--headless', '--path', $projectPath, '--script', 'res://tests/e04_swordsman_integrated_closure_test.gd')
Invoke-GodotCheck @('--headless', '--path', $projectPath, '--script', 'res://tests/e04_learn_from_zero_migration_test.gd')
Invoke-GodotCheck @('--headless', '--path', $projectPath, '--script', 'res://tests/e05_evolution_catalog_test.gd')
Invoke-GodotCheck @('--headless', '--path', $projectPath, '--script', 'res://tests/e05_evolution_transaction_test.gd')
Invoke-GodotCheck @('--headless', '--path', $projectPath, '--script', 'res://tests/e05_evolution_menu_integration_test.gd')
Invoke-GodotCheck @('--headless', '--path', $projectPath, '--script', 'res://tests/e05_identity_boundary_test.gd')
Invoke-GodotCheck @('--headless', '--path', $projectPath, '--script', 'res://tests/e05_defender_catalog_migration_test.gd')
Invoke-GodotCheck @('--headless', '--path', $projectPath, '--script', 'res://tests/e05_berserker_catalog_migration_test.gd')
Invoke-GodotCheck @('--headless', '--path', $projectPath, '--script', 'res://tests/e05_berserker_catalog_test.gd')
Invoke-GodotCheck @('--headless', '--path', $projectPath, '--script', 'res://tests/e05_berserker_rupture_test.gd')
Invoke-GodotCheck @('--headless', '--path', $projectPath, '--script', 'res://tests/e05_berserker_execution_test.gd')
Invoke-GodotCheck @('--headless', '--path', $projectPath, '--script', 'res://tests/e05_berserker_obstinacy_test.gd')
Invoke-GodotCheck @('--headless', '--path', $projectPath, '--script', 'res://tests/e05_berserker_leap_test.gd')
Invoke-GodotCheck @('--headless', '--path', $projectPath, '--script', 'res://tests/e05_defender_catalog_test.gd')
Invoke-GodotCheck @('--headless', '--path', $projectPath, '--script', 'res://tests/e05_defender_indicators_test.gd')
Invoke-GodotCheck @('--headless', '--path', $projectPath, '--script', 'res://tests/e05_defender_guard_test.gd')
Invoke-GodotCheck @('--headless', '--path', $projectPath, '--script', 'res://tests/e05_defender_skills_test.gd')
Invoke-GodotCheck @('--headless', '--path', $projectPath, '--script', 'res://tests/e05_defender_watch_test.gd')
Invoke-GodotCheck @('--headless', '--path', $projectPath, '--script', 'res://tests/e05_defender_builds_test.gd')
Invoke-GodotCheck @('--headless', '--path', $projectPath, '--script', 'res://tests/e05_defender_playtest_flow_test.gd')
Invoke-GodotCheck @('--headless', '--path', $projectPath, '--quit-after', '5')
Write-Host 'All foundation and milestone-one checks passed.'
Invoke-GodotCheck @('--headless', '--path', $projectPath, '--script', 'res://tests/playtest_admin_progression_test.gd')
