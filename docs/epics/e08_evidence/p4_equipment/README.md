# Evidência portátil — equipamentos e cabelo base do Mago

Autoria/validação Sol, conferência de integridade Luna pendente após freeze.
[Entrega e limitações](../../e08_p4_gear_integration_delivery.md). Base final
dc5ada5f83e3213cc4857a63c065704eaf51a810; candidato é o commit deste recibo,
branch codex/e08, checkout .tools/map-editor-m5. Este ZIP não é repositório
executável completo: fontes/raster produtivos estão no Git, vinculados por SHA.

hashes.json registra cada membro do evidence.zip,2468inputs, engine e doisPCKs.
input_conformance.json confirma origem/fixture e28metadados gerados. preservation.json
confirma112crops,64grounds/slots, proteção de pixels, perfis/grips/V1 e4backups.
verification_summary.json discrimina24etapas/31.283checks,2consumidores finais,
PCKs,5.568checks nativos/35capturas e movimento76checks/64PNGs. Sem somar reruns.

O ZIP conserva todas as tentativas originais, inclusive import_initial1 falho,
unit_initial2 com42falhas, custos inicial/repetido, fit1 e final2. Inclui logs,
planos/deltas/versões anteriores, manifestos, código do harness e capturas exatas.
Exclui APPDATA/LOCALAPPDATA, perfis/saves/cache/engine/PCK. Prévias GIF usam
paleta256 sem dithering e6,4s;64PNGs nativos originais ficam no ZIP intactos.

## Reprodução em PowerShell7

Usar o candidato exato, Godot4.7.2standardSHA256
ab1824f85bfd8e0e4128182c000c4003a3e042245b2967848d089b2a04b22424,
e única fixture F1 correspondente. Conferir antes os hashes fonte/fixture.
A única diferença de project.godot é version_control/autoload_on_startup=false
na fixture. Nunca usar o habitual ou save pessoal. WORKFLOW_TOOLING/CLI de resume
não existem nesta worktree; retomada foi por contratos/checkpoints/Git locais.

```powershell
$env:APPDATA=Join-Path (Get-Location) '.godot/verification/p4_equipment/repro/appdata'
$env:LOCALAPPDATA=Join-Path (Get-Location) '.godot/verification/p4_equipment/repro/localappdata'
$tests=@('e06_inventory_test','combat_animation_test','e08_presentation_test','e08_pilot_ui_test','e08_audio_test','e08_pilot_test','e08_characters_test','e08_directional_animation_test','e08_directional_integration_test','e08_directional_content_test','e08_directional_units_test','e08_equipment_art_test','e05_spiritualist_visuals_test','e05_elementalist_animation_test','e06_ui_inventory_test','e06_appearance_integration_test','equipment_hand_alignment_test','e06_icon_bar_test','e07_f7_presentation_test','e07_f3_snapshot_test','e07_f3_continuation_test','e07_f3_action_matrix_test','e07_f3_lifecycle_test','e07_f1_presentation_test')
& tools/verify.ps1 -GodotPath '<engine standard conferido>' -F1Fixture -Test $tests -VerificationDirectory '.godot/verification/p4_equipment/repro'
& tools/validate_e08_equipment_art.ps1 -Stage native -EvidenceName reproduction1
& tools/validate_e08_equipment_art.ps1 -Stage motion -EvidenceName reproduction1
& tools/validate_e08_equipment_art.ps1 -Stage export -EvidenceName reproduction1
```

EvidenceName é imutável. Wrapper isola os lançamentos e verifica hashes/engine.
Para reconstruir fixture em outro checkout usar a preparação F1 versionada e
deltas autorizados; não sobrescrever a fixture de outro executor. Baseline foi
capturado ANTES do código e peças novos; reprodução desse controle exige versões
anteriores arquivadas, sem apagar defaults do candidato. Mesma cena96atores,
3x3s moving/idle, GPU GTX1080 e probe b3abacf33f40b8e274a08852ff7d7032d2cefa1828a2b90a0cba880442d9a169.
Performance.MEMORY_STATIC não é RSS/VRAM/FPS de mapa nem prova de vazamento.

PCKs export_final1 e export_final2 ficam fora do Git até conferência e autorização
de remoção Root. Inputs/código deste freeze não mudam durante Luna; futuros
stages de outras unidades estão fora. Supervisão não significa aceite humano.
