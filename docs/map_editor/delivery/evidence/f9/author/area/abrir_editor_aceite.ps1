# Abre o editor de mapas F9 numa copia de aceite separada (.tools\f9_aceite).
# Sem parametros: reabre a copia (cria na primeira vez, ~1-3 min de copia).
# -Novo: guarda a copia atual com a data no nome e cria outra a partir da fixture.
# -SoPreparar: so cria/atualiza a copia, sem abrir o editor.
param([switch]$Novo,[switch]$SoPreparar)
$ErrorActionPreference = 'Stop'
$bridge = $PSScriptRoot
$tools = Split-Path $bridge -Parent
$wt = Join-Path $tools 'map-editor-m5'
$engine = Join-Path $tools 'godot\Godot_v4.7.2-stable_win64.exe'
$fx = Join-Path $wt '.godot\verification\e07_f1\fixture_project'
$copy = Join-Path $tools 'f9_aceite'
if ($Novo -and (Test-Path -LiteralPath $copy)) {
  $kept = $copy + '_' + (Get-Date -Format 'yyyyMMdd_HHmmss')
  Rename-Item -LiteralPath $copy -NewName (Split-Path $kept -Leaf)
  Write-Host "Copia anterior guardada em $kept"
}
if (-not (Test-Path -LiteralPath (Join-Path $copy 'project.godot'))) {
  Write-Host 'Criando a copia de aceite (so na primeira vez)...'
  # Sem sessoes de teste, probes, drivers de teste e verificacoes da fixture.
  robocopy $fx $copy /E /NFL /NDL /NJH /NJS /NP /R:1 /W:1 /XD (Join-Path $fx '.godot\map_authoring') (Join-Path $fx '.godot\verification') (Join-Path $fx 'f9_probe') (Join-Path $fx '.godot\discardable_profile') | Out-Null
  foreach ($driver in Get-ChildItem -LiteralPath (Join-Path $copy 'addons') -Directory | Where-Object { $_.Name -ne 'ragrpg_map_editor' -and $_.Name -ne 'godot-git-plugin' }) { Remove-Item -LiteralPath $driver.FullName -Recurse -Force }
  $project = Get-Content -LiteralPath (Join-Path $copy 'project.godot') -Raw
  $project = [regex]::Replace($project,'(?ms)^\[editor_plugins\].*?(?=^\[|\z)','')
  $project = $project.TrimEnd() + "`n`n[editor_plugins]`n`nenabled=PackedStringArray(`"res://addons/ragrpg_map_editor/plugin.cfg`")`n"
  [IO.File]::WriteAllText((Join-Path $copy 'project.godot'),$project)
  # Fontes atuais do Bosque e da lista de mapas publicados, a partir do worktree.
  Copy-Item -Path (Join-Path $wt 'data\map_authoring\*') -Destination (Join-Path $copy 'data\map_authoring') -Force
}
# Perfil descartavel: nem o save pessoal nem as preferencias do Godot sao tocados.
$perfil = Join-Path $copy '.godot\perfil_aceite'
New-Item -ItemType Directory -Force -Path $perfil | Out-Null
$env:APPDATA = $perfil; $env:LOCALAPPDATA = $perfil
if ($SoPreparar) { Write-Host "Copia pronta em $copy"; return }
Write-Host 'Abrindo o editor de mapas (aba "Mapas" no topo).'
Start-Process -FilePath $engine -ArgumentList @('--path',"`"$copy`"",'--editor')
Start-Sleep -Seconds 3
