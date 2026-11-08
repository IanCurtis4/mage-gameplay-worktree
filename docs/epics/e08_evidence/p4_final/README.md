# Evidência portátil — P4 integração final

[Entrega e limitações](../../e08_p4_final_delivery.md), [contrato](../../e08_p4_final_integration_contract.md),
[posse](../../e08_p4_final_integration_files.json). Base 085e1a1aa66bedff11f686eace274444413928ab;
candidato é o commit deste recibo, branch codex/e08, checkout .tools/map-editor-m5.
Conferência de integridade Luna pendente; supervisão não é aceite humano.

hashes.json registra cada membro do evidence.zip, engine, PCK final, manifesto da
fixture e o hash dos PNGs que ficaram só em disco. verification_summary.json:
bloco `final_after_lateral_grip_correction` é o estado vigente (regressão
43 etapas/114.876 checks, nativos corrigidos, composição ArqueiroNPC, mosaico
361/0, PCK ca728669… com 7 testes empacotados/98.888 checks). Contadores e
PCK b8249397… anteriores certificavam o candidato pré-correção e ficam como
histórico. performance_summary/preservation/promotion vêm da integração Codex;
promotion foi reconferido após a correção (staging/default idênticos).

O ZIP conserva logs, planos, deltas, versões anteriores, execuções e harness de
TODAS as tentativas, inclusive falhas (extração1, probe encoding, world_integrated1,
export_lateral1 por CWD do processo fora da worktree ao carregar a DLL do plugin
git de editor). PNGs entram só para a prova final: nativos das seis unidades
corrigidas e ArqueiroNPC, galerias das demais, 8 quadros-chave do mosaico,
mundo/rampa/ponte, composição e antes/depois da sonda lateral. Demais capturas
ficam em .godot/verification/p4_final com hash. Exclui APPDATA/LOCALAPPDATA,
perfis/saves/cache/engine/PCK.

## Reprodução em PowerShell 7

Godot 4.7.2 standard SHA256 ab1824f85bfd8e0e4128182c000c4003a3e042245b2967848d089b2a04b22424
e a fixture F1 correspondente. Definir o diretório do PROCESSO na raiz da
worktree (`[Environment]::CurrentDirectory`), não só `Set-Location`. EvidenceName
é imutável; o wrapper isola APPDATA/LOCALAPPDATA e confere hashes fonte/fixture.

```powershell
python tools/fix_e08_lateral_grip_side.py --check   # recusa reaplicar sobre o candidato
& tools/validate_e08_directional_npcs.ps1 -Stage sync -EvidenceName repro1
& tools/verify.ps1 -GodotPath '<engine conferido>' -F1Fixture -SkipEditorImport -Test <seleção de regression_lateral1/plan.json> -VerificationDirectory '.godot/verification/p4_final/repro_regression1'
& tools/validate_e08_directional_npcs.ps1 -Stage native -Kind archer -Default -EvidenceName repro1
& tools/validate_e08_directional_npcs.ps1 -Stage mosaic -EvidenceName repro1
& tools/validate_e08_directional_npcs.ps1 -Stage export -EvidenceName repro1
```

Custo 96 atores não foi repetido após a correção: mudou só metadata por quadro e
um npc_body de mesmo tamanho; caminho de desenho/quads iguais. Não certifica FPS
de mapa/campanha, RSS/VRAM ou ausência de vazamento.
