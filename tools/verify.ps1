param(
    [string]$GodotPath = '',
    [switch]$SkipEditorImport,
    [switch]$F1Fixture,
    [string]$VerificationDirectory = "",
    [ValidateRange(60, 300)][int]$CheckTimeoutSeconds = 120,
    [string[]]$Test = @(),
    [ValidateRange(1, 2147483647)][int]$FromStep = 1,
    [ValidateRange(1, 2147483647)][int]$ToStep = 2147483647,
    [switch]$List
)
$ErrorActionPreference = 'Stop'
$projectPath = Split-Path -Parent $PSScriptRoot
$checkPlan = [System.Collections.Generic.List[object]]::new()

function Add-GodotCheck([string[]]$EngineArguments) {
    $scriptArgument = [Array]::IndexOf($EngineArguments, '--script')
    $name = if ($scriptArgument -ge 0) {
        [IO.Path]::GetFileNameWithoutExtension($EngineArguments[$scriptArgument + 1])
    } elseif ($EngineArguments -contains '--recovery-mode') { 'e07_f1_native_import' } elseif ($EngineArguments -contains '--import') { 'editor_import' } else { 'smoke' }
    $checkPlan.Add([pscustomobject]@{ index = $checkPlan.Count + 1; name = $name; arguments = $EngineArguments })
}

function Invoke-GodotCheck($Check) {
    $EngineArguments = $Check.arguments
    $script:verifyCheckIndex += 1
    $checkName = '{0:D3}' -f $Check.index
    $scriptArgument = [Array]::IndexOf($EngineArguments, '--script')
    if ($scriptArgument -ge 0) { $checkName += '-' + [IO.Path]::GetFileNameWithoutExtension($EngineArguments[$scriptArgument + 1]) }
    $logPath = Join-Path $verificationPath ($checkName + '.engine.log')
    $outputPath = Join-Path $verificationPath ($checkName + '.output.log')
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
    $timedOut = -not $process.WaitForExit($CheckTimeoutSeconds * 1000)
    if ($timedOut) {
        $process.Kill($true)
        $process.WaitForExit()
    }
    $checkOutput = $stdoutTask.GetAwaiter().GetResult() + $stderrTask.GetAwaiter().GetResult()
    $checkExitCode = $process.ExitCode
    $process.Dispose()
    Set-Content -LiteralPath $outputPath -Value $checkOutput -Encoding utf8
    $checkFailed = $timedOut -or $checkExitCode -ne 0 -or ($checkOutput -match 'SCRIPT ERROR:|Parse Error:|ERROR:')
    @{ index = $Check.index; execution_index = $script:verifyCheckIndex; name = $Check.name; arguments = $EngineArguments; exit_code = $checkExitCode; timed_out = [bool]$timedOut; timeout_seconds = $CheckTimeoutSeconds; failed = [bool]$checkFailed; output_path = $outputPath; output_sha256 = (Get-FileHash -LiteralPath $outputPath -Algorithm SHA256).Hash; engine_log = $logPath } | ConvertTo-Json -Compress | Add-Content -LiteralPath $manifestPath -Encoding utf8
    Write-Host $checkOutput
    if ($checkFailed) {
        if ($timedOut) { throw "Godot verification timed out after $CheckTimeoutSeconds seconds." }
        throw "Godot verification failed (exit $checkExitCode)."
    }

}

Add-GodotCheck @('--headless', '--path', $projectPath, '--editor', '--import', '--quit')
Add-GodotCheck @('--headless', '--path', $projectPath, '--script', 'res://tests/e06_inventory_resources_test.gd')
Add-GodotCheck @('--headless', '--path', $projectPath, '--script', 'res://tests/e06_inventory_test.gd')
Add-GodotCheck @('--headless', '--path', $projectPath, '--script', 'res://tests/e06_rewards_test.gd')
Add-GodotCheck @('--headless', '--path', $projectPath, '--script', 'res://tests/e06_migration_test.gd')
Add-GodotCheck @('--headless', '--path', $projectPath, '--script', 'res://tests/e06_effects_composition_test.gd')
Add-GodotCheck @('--headless', '--path', $projectPath, '--script', 'res://tests/e06_proc_ledger_test.gd')
Add-GodotCheck @('--headless', '--path', $projectPath, '--script', 'res://tests/e06_effects_runtime_test.gd')
Add-GodotCheck @('--headless', '--path', $projectPath, '--script', 'res://tests/foundation_test.gd')
Add-GodotCheck @('--headless', '--path', $projectPath, '--script', 'res://tests/combat_animation_test.gd')
Add-GodotCheck @('--headless', '--path', $projectPath, '--script', 'res://tests/milestone_one_test.gd')
Add-GodotCheck @('--headless', '--path', $projectPath, '--script', 'res://tests/pursuit_momentum_test.gd')
Add-GodotCheck @('--headless', '--path', $projectPath, '--script', 'res://tests/battle_ui_test.gd')
Add-GodotCheck @('--headless', '--path', $projectPath, '--script', 'res://tests/arena_flow_test.gd')
Add-GodotCheck @('--headless', '--path', $projectPath, '--script', 'res://tests/ui_layout_test.gd')
Add-GodotCheck @('--headless', '--path', $projectPath, '--script', 'res://tests/mage_gameplay_test.gd')
Add-GodotCheck @('--headless', '--path', $projectPath, '--script', 'res://tests/persistent_state_test.gd')
Add-GodotCheck @('--headless', '--path', $projectPath, '--script', 'res://tests/profile_store_test.gd')
Add-GodotCheck @('--headless', '--path', $projectPath, '--script', 'res://tests/profile_facade_test.gd')
Add-GodotCheck @('--headless', '--path', $projectPath, '--script', 'res://tests/profile_run_facade_test.gd')
Add-GodotCheck @('--headless', '--path', $projectPath, '--script', 'res://tests/e01_profile_diagnostic_test.gd')
Add-GodotCheck @('--headless', '--path', $projectPath, '--script', 'res://tests/e02_character_menu_test.gd')
Add-GodotCheck @('--headless', '--path', $projectPath, '--script', 'res://tests/verification_profile_isolation_test.gd')
Add-GodotCheck @('--headless', '--path', $projectPath, '--script', 'res://tests/menu_tabs_test.gd')
Add-GodotCheck @('--headless', '--path', $projectPath, '--script', 'res://tests/e02_run_integration_test.gd')
Add-GodotCheck @('--headless', '--path', $projectPath, '--script', 'res://tests/e03_stat_calculator_test.gd')
Add-GodotCheck @('--headless', '--path', $projectPath, '--script', 'res://tests/stat_threshold_rules_test.gd')
Add-GodotCheck @('--headless', '--path', $projectPath, '--script', 'res://tests/stat_threshold_migration_test.gd')
Add-GodotCheck @('--headless', '--path', $projectPath, '--script', 'res://tests/stat_threshold_preview_integration_test.gd')
Add-GodotCheck @('--headless', '--path', $projectPath, '--script', 'res://tests/e03_stat_matrix_test.gd')
Add-GodotCheck @('--headless', '--path', $projectPath, '--script', 'res://tests/e03_progression_transactions_test.gd')
Add-GodotCheck @('--headless', '--path', $projectPath, '--script', 'res://tests/e03_progression_panel_integration_test.gd')
Add-GodotCheck @('--headless', '--path', $projectPath, '--script', 'res://tests/e03_consumer_integration_test.gd')
Add-GodotCheck @('--headless', '--path', $projectPath, '--script', 'res://tests/e03_integrated_progression_flow_test.gd')
Add-GodotCheck @('--headless', '--path', $projectPath, '--script', 'res://tests/e04_skill_rank_definition_test.gd')
Add-GodotCheck @('--headless', '--path', $projectPath, '--script', 'res://tests/e04_slash_rank_integration_test.gd')
Add-GodotCheck @('--headless', '--path', $projectPath, '--script', 'res://tests/e04_dash_rank_integration_test.gd')
Add-GodotCheck @('--headless', '--path', $projectPath, '--script', 'res://tests/e04_swordsman_resistance_rank_integration_test.gd')
Add-GodotCheck @('--headless', '--path', $projectPath, '--script', 'res://tests/e04_fireball_rank_integration_test.gd')
Add-GodotCheck @('--headless', '--path', $projectPath, '--script', 'res://tests/e04_fire_wall_rank_integration_test.gd')
Add-GodotCheck @('--headless', '--path', $projectPath, '--script', 'res://tests/e04_fire_spear_rank_integration_test.gd')
Add-GodotCheck @('--headless', '--path', $projectPath, '--script', 'res://tests/e04_ice_spear_rank_integration_test.gd')
Add-GodotCheck @('--headless', '--path', $projectPath, '--script', 'res://tests/e04_teleport_rank_integration_test.gd')
Add-GodotCheck @('--headless', '--path', $projectPath, '--script', 'res://tests/e04_mage_sp_regeneration_rank_integration_test.gd')
Add-GodotCheck @('--headless', '--path', $projectPath, '--script', 'res://tests/e04_archer_precision_projectile_test.gd')
Add-GodotCheck @('--headless', '--path', $projectPath, '--script', 'res://tests/e04_archer_double_shot_rank_integration_test.gd')
Add-GodotCheck @('--headless', '--path', $projectPath, '--script', 'res://tests/e04_archer_piercing_arrow_rank_integration_test.gd')
Add-GodotCheck @('--headless', '--path', $projectPath, '--script', 'res://tests/e04_archer_arrow_rain_rank_integration_test.gd')
Add-GodotCheck @('--headless', '--path', $projectPath, '--script', 'res://tests/e04_archer_extended_aim_rank_integration_test.gd')
Add-GodotCheck @('--headless', '--path', $projectPath, '--script', 'res://tests/e04_archer_trap_runtime_test.gd')
Add-GodotCheck @('--headless', '--path', $projectPath, '--script', 'res://tests/e05_hunter_catalog_test.gd')
Add-GodotCheck @('--headless', '--path', $projectPath, '--script', 'res://tests/e05_hunter_opening_test.gd')
Add-GodotCheck @('--headless', '--path', $projectPath, '--script', 'res://tests/e05_hunter_core_integration_test.gd')
Add-GodotCheck @('--headless', '--path', $projectPath, '--script', 'res://tests/e05_hunter_traps_integration_test.gd')
Add-GodotCheck @('--headless', '--path', $projectPath, '--script', 'res://tests/e05_hunter_cover_integration_test.gd')
Add-GodotCheck @('--headless', '--path', $projectPath, '--script', 'res://tests/e05_hunter_passives_test.gd')
Add-GodotCheck @('--headless', '--path', $projectPath, '--script', 'res://tests/e05_hunter_catalog_migration_test.gd')
Add-GodotCheck @('--headless', '--path', $projectPath, '--script', 'res://tests/e05_hunter_builds_test.gd')
Add-GodotCheck @('--headless', '--path', $projectPath, '--script', 'res://tests/e05_hunter_ground_visual_test.gd')
Add-GodotCheck @('--headless', '--path', $projectPath, '--script', 'res://tests/e05_hunter_atlas_test.gd')
Add-GodotCheck @('--headless', '--path', $projectPath, '--script', 'res://tests/e05_hunter_presentation_test.gd')
Add-GodotCheck @('--headless', '--path', $projectPath, '--script', 'res://tests/e05_hunter_active_combat_test.gd')
Add-GodotCheck @('--headless', '--path', $projectPath, '--script', 'res://tests/e04_archer_snare_trap_rank_integration_test.gd')
Add-GodotCheck @('--headless', '--path', $projectPath, '--script', 'res://tests/e04_archer_explosive_trap_rank_integration_test.gd')
Add-GodotCheck @('--headless', '--path', $projectPath, '--script', 'res://tests/e04_archer_slowing_arrow_rank_integration_test.gd')
Add-GodotCheck @('--headless', '--path', $projectPath, '--script', 'res://tests/e04_archer_foliage_shelter_rank_integration_test.gd')
Add-GodotCheck @('--headless', '--path', $projectPath, '--script', 'res://tests/e04_archer_precision_rank_integration_test.gd')
Add-GodotCheck @('--headless', '--path', $projectPath, '--script', 'res://tests/e04_archer_cadence_rank_integration_test.gd')
Add-GodotCheck @('--headless', '--path', $projectPath, '--script', 'res://tests/e04_archer_trap_technique_rank_integration_test.gd')
Add-GodotCheck @('--headless', '--path', $projectPath, '--script', 'res://tests/e04_archer_integrated_closure_test.gd')
Add-GodotCheck @('--headless', '--path', $projectPath, '--script', 'res://tests/e04_mage_lightning_rank_integration_test.gd')
Add-GodotCheck @('--headless', '--path', $projectPath, '--script', 'res://tests/e04_mage_electric_discharge_rank_integration_test.gd')
Add-GodotCheck @('--headless', '--path', $projectPath, '--script', 'res://tests/e04_mage_lightning_wall_rank_integration_test.gd')
Add-GodotCheck @('--headless', '--path', $projectPath, '--script', 'res://tests/e04_mage_soul_impact_rank_integration_test.gd')
Add-GodotCheck @('--headless', '--path', $projectPath, '--script', 'res://tests/e04_mage_haunt_rank_integration_test.gd')
Add-GodotCheck @('--headless', '--path', $projectPath, '--script', 'res://tests/e04_mage_phantom_barrier_rank_integration_test.gd')
Add-GodotCheck @('--headless', '--path', $projectPath, '--script', 'res://tests/e04_mage_ice_wall_rank_integration_test.gd')
Add-GodotCheck @('--headless', '--path', $projectPath, '--script', 'res://tests/e04_mage_integrated_closure_test.gd')
Add-GodotCheck @('--headless', '--path', $projectPath, '--script', 'res://tests/e04_swordsman_shield_wall_rank_integration_test.gd')
Add-GodotCheck @('--headless', '--path', $projectPath, '--script', 'res://tests/e04_swordsman_provoke_rank_integration_test.gd')
Add-GodotCheck @('--headless', '--path', $projectPath, '--script', 'res://tests/e04_swordsman_perseverance_rank_integration_test.gd')
Add-GodotCheck @('--headless', '--path', $projectPath, '--script', 'res://tests/e04_swordsman_piercing_shout_rank_integration_test.gd')
Add-GodotCheck @('--headless', '--path', $projectPath, '--script', 'res://tests/e04_swordsman_fury_rank_integration_test.gd')
Add-GodotCheck @('--headless', '--path', $projectPath, '--script', 'res://tests/e04_swordsman_brutal_strike_rank_integration_test.gd')
Add-GodotCheck @('--headless', '--path', $projectPath, '--script', 'res://tests/e04_swordsman_concentrated_rage_rank_integration_test.gd')
Add-GodotCheck @('--headless', '--path', $projectPath, '--script', 'res://tests/e04_swordsman_terrifying_shout_rank_integration_test.gd')
Add-GodotCheck @('--headless', '--path', $projectPath, '--script', 'res://tests/e04_swordsman_vigor_rank_integration_test.gd')
Add-GodotCheck @('--headless', '--path', $projectPath, '--script', 'res://tests/e04_swordsman_blood_thirst_rank_integration_test.gd')
Add-GodotCheck @('--headless', '--path', $projectPath, '--script', 'res://tests/e04_swordsman_integrated_closure_test.gd')
Add-GodotCheck @('--headless', '--path', $projectPath, '--script', 'res://tests/e04_learn_from_zero_migration_test.gd')
Add-GodotCheck @('--headless', '--path', $projectPath, '--script', 'res://tests/e05_evolution_catalog_test.gd')
Add-GodotCheck @('--headless', '--path', $projectPath, '--script', 'res://tests/e05_evolution_transaction_test.gd')
Add-GodotCheck @('--headless', '--path', $projectPath, '--script', 'res://tests/e05_evolution_menu_integration_test.gd')
Add-GodotCheck @('--headless', '--path', $projectPath, '--script', 'res://tests/e05_training_boss_test.gd')
Add-GodotCheck @('--headless', '--path', $projectPath, '--script', 'res://tests/e05_identity_boundary_test.gd')
Add-GodotCheck @('--headless', '--path', $projectPath, '--script', 'res://tests/e05_defender_catalog_migration_test.gd')
Add-GodotCheck @('--headless', '--path', $projectPath, '--script', 'res://tests/e05_berserker_catalog_migration_test.gd')
Add-GodotCheck @('--headless', '--path', $projectPath, '--script', 'res://tests/e05_elementalist_catalog_migration_test.gd')
Add-GodotCheck @('--headless', '--path', $projectPath, '--script', 'res://tests/e05_spiritualist_catalog_migration_test.gd')
Add-GodotCheck @('--headless', '--path', $projectPath, '--script', 'res://tests/e05_spiritualist_echo_curse_test.gd')
Add-GodotCheck @('--headless', '--path', $projectPath, '--script', 'res://tests/e05_spiritualist_echo_spread_test.gd')
Add-GodotCheck @('--headless', '--path', $projectPath, '--script', 'res://tests/e05_spiritualist_echo_recovery_test.gd')
Add-GodotCheck @('--headless', '--path', $projectPath, '--script', 'res://tests/e05_spiritualist_soul_drain_test.gd')
Add-GodotCheck @('--headless', '--path', $projectPath, '--script', 'res://tests/e05_spiritualist_spectral_veil_test.gd')
Add-GodotCheck @('--headless', '--path', $projectPath, '--script', 'res://tests/e05_spiritualist_channel_focus_test.gd')
Add-GodotCheck @('--headless', '--path', $projectPath, '--script', 'res://tests/e05_spiritualist_procession_test.gd')
Add-GodotCheck @('--headless', '--path', $projectPath, '--script', 'res://tests/e05_spiritualist_dissipation_test.gd')
Add-GodotCheck @('--headless', '--path', $projectPath, '--script', 'res://tests/e05_spiritualist_visuals_test.gd')
Add-GodotCheck @('--headless', '--path', $projectPath, '--script', 'res://tests/e05_spiritualist_integrated_closure_test.gd')
Add-GodotCheck @('--headless', '--path', $projectPath, '--script', 'res://tests/e05_spiritualist_readability_test.gd')
Add-GodotCheck @('--headless', '--path', $projectPath, '--script', 'res://tests/e05_spiritualist_soul_presentation_test.gd')
Add-GodotCheck @('--headless', '--path', $projectPath, '--script', 'res://tests/e05_geometer_construction_test.gd')
Add-GodotCheck @('--headless', '--path', $projectPath, '--script', 'res://tests/e05_geometer_casting_test.gd')
Add-GodotCheck @('--headless', '--path', $projectPath, '--script', 'res://tests/e05_geometer_geometry_integration_test.gd')
Add-GodotCheck @('--headless', '--path', $projectPath, '--script', 'res://tests/e05_geometer_wall_primitives_test.gd')
Add-GodotCheck @('--headless', '--path', $projectPath, '--script', 'res://tests/e05_geometer_wall_effects_test.gd')
Add-GodotCheck @('--headless', '--path', $projectPath, '--script', 'res://tests/e05_geometer_wall_projectile_test.gd')
Add-GodotCheck @('--headless', '--path', $projectPath, '--script', 'res://tests/e05_geometer_triangle_recipes_test.gd')
Add-GodotCheck @('--headless', '--path', $projectPath, '--script', 'res://tests/e05_geometer_triangle_projectile_test.gd')
Add-GodotCheck @('--headless', '--path', $projectPath, '--script', 'res://tests/e05_geometer_editing_test.gd')
Add-GodotCheck @('--headless', '--path', $projectPath, '--script', 'res://tests/e05_geometer_builds_test.gd')
Add-GodotCheck @('--headless', '--path', $projectPath, '--script', 'res://tests/e05_geometer_animation_test.gd')
Add-GodotCheck @('--headless', '--path', $projectPath, '--script', 'res://tests/e05_geometer_onboarding_test.gd')
Add-GodotCheck @('--headless', '--path', $projectPath, '--script', 'res://tests/e05_geometer_g7_test.gd')
Add-GodotCheck @('--headless', '--path', $projectPath, '--script', 'res://tests/e05_geometer_playtest_flow_test.gd')
Add-GodotCheck @('--headless', '--path', $projectPath, '--script', 'res://tests/e05_sentinel_catalog_test.gd')
Add-GodotCheck @('--headless', '--path', $projectPath, '--script', 'res://tests/e05_sentinel_math_test.gd')
Add-GodotCheck @('--headless', '--path', $projectPath, '--script', 'res://tests/e05_sentinel_focus_test.gd')
Add-GodotCheck @('--headless', '--path', $projectPath, '--script', 'res://tests/e05_sentinel_reset_test.gd')
Add-GodotCheck @('--headless', '--path', $projectPath, '--script', 'res://tests/e05_sentinel_piercing_test.gd')
Add-GodotCheck @('--headless', '--path', $projectPath, '--script', 'res://tests/e05_sentinel_net_test.gd')
Add-GodotCheck @('--headless', '--path', $projectPath, '--script', 'res://tests/e05_sentinel_explosive_test.gd')
Add-GodotCheck @('--headless', '--path', $projectPath, '--script', 'res://tests/e05_sentinel_concussion_test.gd')
Add-GodotCheck @('--headless', '--path', $projectPath, '--script', 'res://tests/e05_sentinel_absolute_test.gd')
Add-GodotCheck @('--headless', '--path', $projectPath, '--script', 'res://tests/e05_sentinel_builds_test.gd')
Add-GodotCheck @('--headless', '--path', $projectPath, '--script', 'res://tests/e05_sentinel_atlas_test.gd')
Add-GodotCheck @('--headless', '--path', $projectPath, '--script', 'res://tests/e05_sentinel_onboarding_test.gd')
Add-GodotCheck @('--headless', '--path', $projectPath, '--script', 'res://tests/e05_sentinel_integration_test.gd')
Add-GodotCheck @('--headless', '--path', $projectPath, '--script', 'res://tests/e05_sentinel_review_test.gd')
Add-GodotCheck @('--headless', '--path', $projectPath, '--script', 'res://tests/e05_sentinel_solo_focus_test.gd')
Add-GodotCheck @('--headless', '--path', $projectPath, '--script', 'res://tests/e05_sentinel_solo_integration_test.gd')
Add-GodotCheck @('--headless', '--path', $projectPath, '--script', 'res://tests/action_bar_input_test.gd')
Add-GodotCheck @('--headless', '--path', $projectPath, '--script', 'res://tests/action_bar_ui_test.gd')
Add-GodotCheck @('--headless', '--path', $projectPath, '--script', 'res://tests/action_bar_persistence_test.gd')
Add-GodotCheck @('--headless', '--path', $projectPath, '--script', 'res://tests/action_bar_game_integration_test.gd')
Add-GodotCheck @('--headless', '--path', $projectPath, '--script', 'res://tests/e05_elementalist_catalog_test.gd')
Add-GodotCheck @('--headless', '--path', $projectPath, '--script', 'res://tests/e05_elementalist_animation_test.gd')
Add-GodotCheck @('--headless', '--path', $projectPath, '--script', 'res://tests/e05_elementalist_visuals_test.gd')
Add-GodotCheck @('--headless', '--path', $projectPath, '--script', 'res://tests/e05_elementalist_visual_integration_test.gd')
Add-GodotCheck @('--headless', '--path', $projectPath, '--script', 'res://tests/e05_elementalist_indicators_test.gd')
Add-GodotCheck @('--headless', '--path', $projectPath, '--script', 'res://tests/e05_elementalist_flame_burst_test.gd')
Add-GodotCheck @('--headless', '--path', $projectPath, '--script', 'res://tests/e05_elementalist_prismatic_focus_test.gd')
Add-GodotCheck @('--headless', '--path', $projectPath, '--script', 'res://tests/e05_elementalist_glacial_ring_test.gd')
Add-GodotCheck @('--headless', '--path', $projectPath, '--script', 'res://tests/e05_elementalist_lightning_arc_test.gd')
Add-GodotCheck @('--headless', '--path', $projectPath, '--script', 'res://tests/e05_elementalist_prismatic_resonance_test.gd')
Add-GodotCheck @('--headless', '--path', $projectPath, '--script', 'res://tests/e05_elementalist_ember_path_test.gd')
Add-GodotCheck @('--headless', '--path', $projectPath, '--script', 'res://tests/e05_elementalist_tri_nova_test.gd')
Add-GodotCheck @('--headless', '--path', $projectPath, '--script', 'res://tests/e05_elementalist_integrated_closure_test.gd')
Add-GodotCheck @('--headless', '--path', $projectPath, '--script', 'res://tests/e05_berserker_catalog_test.gd')
Add-GodotCheck @('--headless', '--path', $projectPath, '--script', 'res://tests/e05_berserker_rupture_test.gd')
Add-GodotCheck @('--headless', '--path', $projectPath, '--script', 'res://tests/e05_berserker_execution_test.gd')
Add-GodotCheck @('--headless', '--path', $projectPath, '--script', 'res://tests/e05_berserker_obstinacy_test.gd')
Add-GodotCheck @('--headless', '--path', $projectPath, '--script', 'res://tests/e05_berserker_leap_test.gd')
Add-GodotCheck @('--headless', '--path', $projectPath, '--script', 'res://tests/e05_berserker_pursuit_test.gd')
Add-GodotCheck @('--headless', '--path', $projectPath, '--script', 'res://tests/e05_berserker_rift_test.gd')
Add-GodotCheck @('--headless', '--path', $projectPath, '--script', 'res://tests/e05_berserker_breath_test.gd')
Add-GodotCheck @('--headless', '--path', $projectPath, '--script', 'res://tests/e05_berserker_builds_test.gd')
Add-GodotCheck @('--headless', '--path', $projectPath, '--script', 'res://tests/e05_berserker_playtest_flow_test.gd')
Add-GodotCheck @('--headless', '--path', $projectPath, '--script', 'res://tests/e05_defender_catalog_test.gd')
Add-GodotCheck @('--headless', '--path', $projectPath, '--script', 'res://tests/e05_defender_indicators_test.gd')
Add-GodotCheck @('--headless', '--path', $projectPath, '--script', 'res://tests/e05_defender_guard_test.gd')
Add-GodotCheck @('--headless', '--path', $projectPath, '--script', 'res://tests/e05_defender_skills_test.gd')
Add-GodotCheck @('--headless', '--path', $projectPath, '--script', 'res://tests/e05_defender_watch_test.gd')
Add-GodotCheck @('--headless', '--path', $projectPath, '--script', 'res://tests/e05_defender_builds_test.gd')
Add-GodotCheck @('--headless', '--path', $projectPath, '--script', 'res://tests/e05_defender_playtest_flow_test.gd')
Add-GodotCheck @('--headless', '--path', $projectPath, '--script', 'res://tests/action_bar_review_test.gd')
Add-GodotCheck @('--headless', '--path', $projectPath, '--quit-after', '5')
Add-GodotCheck @('--headless', '--path', $projectPath, '--script', 'res://tests/playtest_admin_progression_test.gd')
Add-GodotCheck @('--headless', '--path', $projectPath, '--script', 'res://tests/e06_review_boundaries_test.gd')
Add-GodotCheck @('--headless', '--path', $projectPath, '--script', 'res://tests/e06_review_identity_test.gd')
Add-GodotCheck @('--headless', '--path', $projectPath, '--script', 'res://tests/e06_review_preset_test.gd')
Add-GodotCheck @('--headless', '--path', $projectPath, '--script', 'res://tests/e06_inventory_persistence_test.gd')
Add-GodotCheck @('--headless', '--path', $projectPath, '--script', 'res://tests/e06_tx_inventory_test.gd')
Add-GodotCheck @('--headless', '--path', $projectPath, '--script', 'res://tests/e06_tx_migration_test.gd')
Add-GodotCheck @('--headless', '--path', $projectPath, '--script', 'res://tests/e06_review_persistence_edges_test.gd')
Add-GodotCheck @('--headless', '--path', $projectPath, '--script', 'res://tests/e06_tx_composition_test.gd')
Add-GodotCheck @('--headless', '--path', $projectPath, '--script', 'res://tests/e06_tx_active_test.gd')
Add-GodotCheck @('--headless', '--path', $projectPath, '--script', 'res://tests/e06_tx_causality_test.gd')
Add-GodotCheck @('--headless', '--path', $projectPath, '--script', 'res://tests/e06_tx_mob_test.gd')
Add-GodotCheck @('--headless', '--path', $projectPath, '--script', 'res://tests/e06_tx_loot_test.gd')
Add-GodotCheck @('--headless', '--path', $projectPath, '--script', 'res://tests/e06_rx_causal_late_test.gd')
Add-GodotCheck @('--headless', '--path', $projectPath, '--script', 'res://tests/e06_rx_mob_ai_test.gd')
Add-GodotCheck @('--headless', '--path', $projectPath, '--script', 'res://tests/e06_tx_late_fields_test.gd')
Add-GodotCheck @('--headless', '--path', $projectPath, '--script', 'res://tests/e06_content_authoring_test.gd')
Add-GodotCheck @('--headless', '--path', $projectPath, '--script', 'res://tests/e06_content_editorial_test.gd')
Add-GodotCheck @('--headless', '--path', $projectPath, '--script', 'res://tests/e06_content_pilot_test.gd')
Add-GodotCheck @('--headless', '--path', $projectPath, '--script', 'res://tests/e06_content_pilot_runtime_test.gd')
Add-GodotCheck @('--headless', '--path', $projectPath, '--script', 'res://tests/e06_pilot_execution_test.gd')
Add-GodotCheck @('--headless', '--path', $projectPath, '--script', 'res://tests/e06_spatial_policies_test.gd')
Add-GodotCheck @('--headless', '--path', $projectPath, '--script', 'res://tests/e06_spatial_execution_test.gd')
Add-GodotCheck @('--headless', '--path', $projectPath, '--script', 'res://tests/e06_transform_policies_test.gd')
Add-GodotCheck @('--headless', '--path', $projectPath, '--script', 'res://tests/e06_transform_execution_test.gd')
Add-GodotCheck @('--headless', '--path', $projectPath, '--script', 'res://tests/e06_directions_test.gd')
Add-GodotCheck @('--headless', '--path', $projectPath, '--script', 'res://tests/e06_publication_test.gd')
Add-GodotCheck @('--headless', '--path', $projectPath, '--script', 'res://tests/e06_ui_inventory_test.gd')
Add-GodotCheck @('--headless', '--path', $projectPath, '--script', 'res://tests/e06_ui_menu_test.gd')
Add-GodotCheck @('--headless', '--path', $projectPath, '--script', 'res://tests/e06_power_progression_test.gd')
Add-GodotCheck @('--headless', '--path', $projectPath, '--script', 'res://tests/e06_power_migration_test.gd')
Add-GodotCheck @('--headless', '--path', $projectPath, '--script', 'res://tests/e06_production_loot_test.gd')



Add-GodotCheck @('--headless', '--path', $projectPath, '--script', 'res://tests/e06_gameplay_content_test.gd')
Add-GodotCheck @('--headless', '--path', $projectPath, '--script', 'res://tests/e06_gameplay_ai_test.gd')
Add-GodotCheck @('--headless', '--path', $projectPath, '--script', 'res://tests/e06_gameplay_route_test.gd')

# Indices always refer to the complete plan, including editor import.
Add-GodotCheck @('--headless', '--path', $projectPath, '--script', 'res://tests/e06_permanent_cards_test.gd')

Add-GodotCheck @('--headless', '--path', $projectPath, '--script', 'res://tests/e06_inventory_profile_panel_test.gd')
Add-GodotCheck @('--headless', '--path', $projectPath, '--script', 'res://tests/e06_admin_profile_test.gd')
Add-GodotCheck @('--headless', '--path', $projectPath, '--script', 'res://tests/e06_admin_run_test.gd')
Add-GodotCheck @('--headless', '--path', $projectPath, '--script', 'res://tests/e06_inventory_window_input_test.gd')
Add-GodotCheck @('--headless', '--path', $projectPath, '--script', 'res://tests/e06_fixes_performance_cache_test.gd')

Add-GodotCheck @('--headless', '--path', $projectPath, '--script', 'res://tests/e06_expanded_equipment_content_test.gd')

Add-GodotCheck @('--headless', '--path', $projectPath, '--script', 'res://tests/e06_appearance_integration_test.gd')

Add-GodotCheck @('--headless', '--path', $projectPath, '--script', 'res://tests/e06_card_migration_store_test.gd')
Add-GodotCheck @('--headless', '--path', $projectPath, '--script', 'res://tests/equipment_hand_alignment_test.gd')

Add-GodotCheck @('--headless', '--path', $projectPath, '--script', 'res://tests/reward_feedback_test.gd')

Add-GodotCheck @('--headless', '--path', $projectPath, '--script', 'res://tests/skill_allocation_test.gd')
Add-GodotCheck @('--headless', '--path', $projectPath, '--script', 'res://tests/skill_window_test.gd')
Add-GodotCheck @('--headless', '--path', $projectPath, '--script', 'res://tests/e06_skill_downrank_test.gd')
Add-GodotCheck @('--headless', '--path', $projectPath, '--script', 'res://tests/e06_swordsman_cluster_test.gd')
Add-GodotCheck @('--headless', '--path', $projectPath, '--script', 'res://tests/e06_skill_ux_iteration_test.gd')

Add-GodotCheck @('--headless', '--path', $projectPath, '--script', 'res://tests/e06_icon_bar_test.gd')
Add-GodotCheck @('--headless', '--path', $projectPath, '--script', 'res://tests/e06_skill_dependencies_test.gd')
Add-GodotCheck @('--headless', '--path', $projectPath, '--script', 'res://tests/e06_all_skill_migration_test.gd')
Add-GodotCheck @('--headless', '--path', $projectPath, '--script', 'res://tests/e06_dependency_navigation_test.gd')

Add-GodotCheck @('--headless', '--path', $projectPath, '--script', 'res://tests/e06_export_content_test.gd')

Add-GodotCheck @('--headless', '--path', $projectPath, '--script', 'res://tests/e07_f0_import_test.gd')
$fixtureF0Path = Join-Path $projectPath '.godot/verification/e07_f0/fixture_project'
Add-GodotCheck @('--headless', '--path', $fixtureF0Path, '--script', 'res://tests/e07_f0_generation_test.gd')
Add-GodotCheck @('--headless', '--path', $fixtureF0Path, '--script', 'res://tests/e07_f0_adversarial_test.gd')
Add-GodotCheck @('--headless', '--path', $fixtureF0Path, '--script', 'res://tests/e07_f0_consumer_test.gd')

Add-GodotCheck @('--headless', '--path', $projectPath, '--editor', '--recovery-mode', '--import', '--quit')

Add-GodotCheck @('--headless', '--path', $projectPath, '--script', 'res://tests/e07_f1_import_test.gd')
$fixtureF1Path = Join-Path $projectPath '.godot/verification/e07_f1/fixture_project'
Add-GodotCheck @('--headless', '--path', $fixtureF1Path, '--script', 'res://tests/e07_f1_geometry_test.gd')
Add-GodotCheck @('--headless', '--path', $fixtureF1Path, '--script', 'res://tests/e07_f1_actor_integration_test.gd')

Add-GodotCheck @('--headless', '--path', $fixtureF1Path, '--script', 'res://tests/e07_f1_inventory_test.gd')

Add-GodotCheck @('--headless', '--path', $fixtureF1Path, '--script', 'res://tests/e07_f1_adversarial_test.gd')
Add-GodotCheck @('--headless', '--path', $fixtureF1Path, '--script', 'res://tests/e07_f1_consumer_test.gd')
Add-GodotCheck @('--headless', '--path', $fixtureF1Path, '--script', 'res://tests/e07_f1_channels_test.gd')
Add-GodotCheck @('--headless', '--path', $fixtureF1Path, '--script', 'res://tests/e07_f1_cast_test.gd')
Add-GodotCheck @('--headless', '--path', $fixtureF1Path, '--script', 'res://tests/e07_f1_area_cast_test.gd')
Add-GodotCheck @('--headless', '--path', $fixtureF1Path, '--script', 'res://tests/e07_f1_echo_test.gd')
Add-GodotCheck @('--headless', '--path', $fixtureF1Path, '--script', 'res://tests/e07_f1_chain_test.gd')
Add-GodotCheck @('--headless', '--path', $fixtureF1Path, '--script', 'res://tests/e07_f1_ember_test.gd')
Add-GodotCheck @('--headless', '--path', $fixtureF1Path, '--script', 'res://tests/e07_f1_guard_travel_test.gd')
Add-GodotCheck @('--headless', '--path', $fixtureF1Path, '--script', 'res://tests/e07_f1_sentinel_direct_test.gd')
Add-GodotCheck @('--headless', '--path', $fixtureF1Path, '--script', 'res://tests/e07_f1_hunter_traps_test.gd')
Add-GodotCheck @('--headless', '--path', $fixtureF1Path, '--script', 'res://tests/e07_f1_hunter_cover_test.gd')
Add-GodotCheck @('--headless', '--path', $fixtureF1Path, '--script', 'res://tests/e07_f1_sentinel_area_test.gd')
Add-GodotCheck @('--headless', '--path', $fixtureF1Path, '--script', 'res://tests/e07_f1_birth_collect_test.gd')
Add-GodotCheck @('--headless', '--path', $fixtureF1Path, '--script', 'res://tests/e07_f1_fields_test.gd')

if (-not $PSBoundParameters.ContainsKey('ToStep')) { $ToStep = $checkPlan.Count }
if ($FromStep -gt $ToStep -or $ToStep -gt $checkPlan.Count) {
    throw "Invalid step range $FromStep..$ToStep; use 1..$($checkPlan.Count)."
}
$matchedNames = @{}
if ($PSBoundParameters.ContainsKey('Test')) {
    if ($Test.Count -eq 0) { throw 'Test selection cannot be empty.' }
    foreach ($pattern in $Test) {
        if ([string]::IsNullOrWhiteSpace($pattern)) { throw 'Test selection cannot contain an empty name/pattern.' }
        $matches = @($checkPlan | Where-Object { $_.name -like $pattern })
        if ($matches.Count -eq 0) { throw "No check matches '$pattern'. Use -List to inspect names." }
        foreach ($check in $matches) { $matchedNames[$check.name] = $true }
    }
}
$selectedChecks = @($checkPlan | Where-Object {
    $_.index -ge $FromStep -and $_.index -le $ToStep -and
    (-not $PSBoundParameters.ContainsKey('Test') -or $matchedNames.ContainsKey($_.name)) -and
    (-not $SkipEditorImport -or $_.name -ne 'editor_import')
})
if ($selectedChecks.Count -eq 0) { throw 'No checks remain after applying the selection, step range and import option.' }
if ($List) {
    Write-Host "Plan only: $($selectedChecks.Count)/$($checkPlan.Count) steps selected; no checks executed."
    $selectedChecks
    return
}
# F1 opt-in: execute unchanged real tests against the full imported native copy.
# Only VCS autoload differs; verify every primary source on both sides before running.
if ($F1Fixture) {
    $sourceManifest = Join-Path $fixtureF1Path 'source_hashes.json'
    if (-not (Test-Path -LiteralPath $sourceManifest)) { throw 'Run e07_f1_import_test before using F1Fixture.' }
    $sourceHashes = Get-Content -LiteralPath $sourceManifest -Raw | ConvertFrom-Json -AsHashtable
    foreach ($relative in $sourceHashes.Keys) {
        foreach ($root in @($projectPath, $fixtureF1Path)) {
            $sourceFile = Join-Path $root $relative
            if (-not (Test-Path -LiteralPath $sourceFile) -or (Get-FileHash -LiteralPath $sourceFile -Algorithm SHA256).Hash.ToLowerInvariant() -ne $sourceHashes[$relative]) { throw "F1 fixture source mismatch: $relative ($root)" }
        }
    }
    $originalConfig = [IO.File]::ReadAllText((Join-Path $projectPath 'project.godot'))
    $fixtureConfig = [IO.File]::ReadAllText((Join-Path $fixtureF1Path 'project.godot'))
    if ($originalConfig.Replace('version_control/autoload_on_startup=true', 'version_control/autoload_on_startup=false') -cne $fixtureConfig) { throw 'Unexpected F1 project config delta.' }
    foreach ($check in $selectedChecks) {
        if ($check.name -in @('e07_f1_import_test', 'e07_f1_native_import', 'e07_f0_import_test')) { throw 'Bootstrap imports must run without F1Fixture.' }
        $pathIndex = [Array]::IndexOf($check.arguments, '--path')
        if ($pathIndex -ge 0 -and $check.arguments[$pathIndex + 1] -eq $projectPath) { $check.arguments[$pathIndex + 1] = $fixtureF1Path }
    }
}
if ([string]::IsNullOrWhiteSpace($GodotPath)) { throw 'GodotPath is required to execute checks; use -List to inspect the plan.' }
$enginePath = (Resolve-Path -LiteralPath $GodotPath).Path
$verificationPath = if ($VerificationDirectory) { [System.IO.Path]::GetFullPath($VerificationDirectory) } else { Join-Path $projectPath '.godot/verification' }
[void](New-Item -ItemType Directory -Force -Path $verificationPath)
$selection = [ordered]@{
    test = @($Test); test_filter_specified = $PSBoundParameters.ContainsKey('Test')
    from_step = $FromStep; to_step = $ToStep; skip_editor_import = [bool]$SkipEditorImport
}
[ordered]@{
    created_utc = [DateTime]::UtcNow.ToString('o')
    f1_native_fixture = [bool]$F1Fixture
    source_commit = (git -C $projectPath rev-parse HEAD)
    working_tree_status = @(git -C $projectPath status --porcelain)
    runner_sha256 = (Get-FileHash -LiteralPath $PSCommandPath -Algorithm SHA256).Hash
    engine_path = $enginePath; engine_sha256 = (Get-FileHash -LiteralPath $enginePath -Algorithm SHA256).Hash
    timeout_seconds = $CheckTimeoutSeconds; selection = $selection
    total_steps = $checkPlan.Count; selected_steps = $selectedChecks.Count; checks = $selectedChecks
} | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath (Join-Path $verificationPath 'plan.json') -Encoding utf8
$manifestPath = Join-Path $verificationPath 'checks.jsonl'
Set-Content -LiteralPath $manifestPath -Value '' -Encoding utf8
$script:verifyCheckIndex = 0
if ($SkipEditorImport) {
    Write-Host 'Editor import explicitly skipped; verify import in a clean worktree before using this option.'
} elseif ('editor_import' -notin $selectedChecks.name) {
    Write-Host 'Editor import is outside the selected plan; compatible imported resources are required.'
}
foreach ($check in $selectedChecks) { Invoke-GodotCheck $check }
if ($selectedChecks.Count -eq $checkPlan.Count) {
    Write-Host 'All foundation and milestone-one checks passed.'
} else {
    Write-Host "Selected checks passed ($($selectedChecks.Count)/$($checkPlan.Count) steps); unselected steps were not run."
}

