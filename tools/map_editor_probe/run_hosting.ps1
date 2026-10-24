param(
    [Parameter(Mandatory)][string]$GodotPath,
    [Parameter(Mandatory)][string]$EvidenceDirectory
)
$ErrorActionPreference = 'Stop'
$probeRoot = Join-Path $PSScriptRoot 'hosting'
$probeEngine = (Resolve-Path -LiteralPath $GodotPath).Path
$probeEvidence = [IO.Path]::GetFullPath($EvidenceDirectory)
[void](New-Item -ItemType Directory -Force -Path $probeEvidence)
$probeIsolation = Join-Path $probeRoot '.godot/m0_profile'
[void](New-Item -ItemType Directory -Force -Path $probeIsolation)
$probeRuns = @(
    @{name='headless_01'; arguments=@('--headless','--editor'); checks=30},
    @{name='headless_02'; arguments=@('--headless','--editor'); checks=30},
    @{name='native_01'; arguments=@('--editor','--rendering-method','gl_compatibility'); checks=31},
    @{name='runtime_guard'; arguments=@('--headless','--script','res://runtime_guard.gd'); checks=1}
)
$probeResults = @()
foreach ($probeRun in $probeRuns) {
    $probeInfo = [Diagnostics.ProcessStartInfo]::new()
    $probeInfo.FileName = $probeEngine
    $probeInfo.UseShellExecute = $false
    $probeInfo.CreateNoWindow = $true
    $probeInfo.WindowStyle = [Diagnostics.ProcessWindowStyle]::Hidden
    $probeInfo.RedirectStandardOutput = $true
    $probeInfo.RedirectStandardError = $true
    $probeInfo.Environment['APPDATA'] = $probeIsolation
    $probeInfo.Environment['LOCALAPPDATA'] = $probeIsolation
    if ($probeRun.name -eq 'native_01') { $probeInfo.Environment['M0_CAPTURE'] = Join-Path $probeEvidence 'hosting.png' }
    else { $probeInfo.Environment.Remove('M0_CAPTURE') | Out-Null }
    foreach ($probeArg in @('--path', $probeRoot, '--log-file', (Join-Path $probeEvidence ($probeRun.name + '.engine.log'))) + $probeRun.arguments) {
        $probeInfo.ArgumentList.Add($probeArg)
    }
    $probeProcess = [Diagnostics.Process]::new()
    $probeProcess.StartInfo = $probeInfo
    $probeWatch = [Diagnostics.Stopwatch]::StartNew()
    [void]$probeProcess.Start()
    $probeOut = $probeProcess.StandardOutput.ReadToEndAsync()
    $probeErr = $probeProcess.StandardError.ReadToEndAsync()
    $probeTimeout = -not $probeProcess.WaitForExit(60000)
    if ($probeTimeout) { $probeProcess.Kill($true); $probeProcess.WaitForExit() }
    $probeWatch.Stop()
    $probeOutput = $probeOut.GetAwaiter().GetResult() + $probeErr.GetAwaiter().GetResult()
    $probeOutputPath = Join-Path $probeEvidence ($probeRun.name + '.output.log')
    [IO.File]::WriteAllText($probeOutputPath, $probeOutput)
    $probeMatch = [regex]::Match($probeOutput, '(?m)^M0_RESULT (.+)$')
    $probePayload = $null
    if ($probeMatch.Success) { $probePayload = ConvertFrom-Json $probeMatch.Groups[1].Value }
    $probePass = (-not $probeTimeout) -and $probeProcess.ExitCode -eq 0 -and $null -ne $probePayload -and $probePayload.ok -and $probePayload.checks.Count -eq $probeRun.checks -and @($probePayload.checks | Where-Object { -not $_.ok }).Count -eq 0 -and $probeOutput -notmatch 'SCRIPT ERROR:|Parse Error:|ERROR:'
    $probeResults += [pscustomobject]@{name=$probeRun.name; ok=$probePass; exit_code=$probeProcess.ExitCode; timed_out=$probeTimeout; elapsed_ms=$probeWatch.Elapsed.TotalMilliseconds; output_sha256=(Get-FileHash -LiteralPath $probeOutputPath -Algorithm SHA256).Hash; result=$probePayload}
    $probeProcess.Dispose()
    [IO.File]::WriteAllText((Join-Path $probeEvidence 'runs.json'), (ConvertTo-Json -InputObject @($probeResults) -Depth 12))
    Write-Output ($probeRun.name + ': ' + $probePass)
    if (-not $probePass) { Write-Output $probeOutput; throw ('M0 hosting failed: ' + $probeRun.name) }
}
$probeFiles = Get-ChildItem -LiteralPath $PSScriptRoot -Recurse -File | Where-Object { $_.FullName -notmatch '[\\/]\.godot[\\/]' }
$probeSources = @($probeFiles | ForEach-Object { @{path=[IO.Path]::GetRelativePath($PSScriptRoot, $_.FullName).Replace('\','/'); sha256=(Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash} })
$probeManifest = @{engine_path=$probeEngine; engine_sha256=(Get-FileHash -LiteralPath $probeEngine -Algorithm SHA256).Hash; sources=$probeSources; runs=$probeResults}
[IO.File]::WriteAllText((Join-Path $probeEvidence 'manifest.json'), (ConvertTo-Json $probeManifest -Depth 14))
Write-Output 'M0_HOSTING_ALL_PASS'
