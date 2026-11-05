# Supervisão — minimapa e zoom

Data: 2026-11-05. Candidato `.tools/map-editor-m5`, HEAD `f01d4cd215ddb5c161930cf2399a33d2e29f88e9`. A fixture F1 usada foi `.godot/verification/e07_f1/fixture_project`, com 2.241 entradas em `source_hashes.json`.

## Seleção dirigida

`tools/verify.ps1 -F1Fixture -SkipEditorImport -CheckTimeoutSeconds 300` iniciou 14 seleções, sequencialmente. O processo parou no primeiro teste com saída diferente de zero, antes de executar os IDs posteriores. Doze provas foram executadas: battle UI (47), action bar input (105), action bar UI (80), action bar persistence (270), action bar game integration (68), action bar review (12), E06 inventory window input (34), E07 F4 compatibility (16), E07 F4 resume staging (91), E07 F7 presentation (27) e StageMinimap (18) passaram; `stage_minimap_data_test` terminou com **30 checks, 1 failure**, exit code 1. Total executado: 798 checks, uma falha.

A falha foi `Dead actor binds to its intended world` em `tests/stage_minimap_data_test.gd`, durante a montagem dos atores do próprio teste. A análise do responsável pelo código identificou a causa como fixture incorreta: a instância F1 se chama `slope`, embora a peça seja `ramp`. Portanto este resultado registra uma falha de preparação do teste, não uma falha do runtime. A correção e repetição foram devolvidas a Sol; esta rodada não as inclui.

`e07_f3_snapshot_test`, `e07_f7_flow_test` e GameInterface não foram executados após a falha. Nenhuma outra etapa foi iniciada. O runner encerrou com exit code 1; nenhum timeout foi registrado. A supervisão conferiu execução, contagens, processo e hashes; não é auditoria semântica independente.

## Identificação dos recibos

- `plan.json` SHA-256: `73629C827A297D28ED1EE72567A1371FDB8EABB78935487A659EDC5EA628F600`.
- `checks.jsonl` SHA-256: `9CC79E7ED4326A2D27F3BB965971B125F60036F6AF7504EAC71A57900C0555FC`.
- Saída de `stage_minimap_data_test` SHA-256: `785A34CDD08C3168B3B2E9456C6CE169FE2498E62B57F2823FFCB6ABC90D3A51`.
- SHA-256 do runner `tools/verify.ps1`: `52D6A9B458406BFC5ADB030AB1CDF66630EC88B29C6DADCD524269D36E7D1963`.
- SHA-256 do Godot 4.7.2 standard: `AB1824F85BFD8E0E4128182C000C4003A3E042245B2967848D089B2A04B22424`.
- SHA-256 do teste fonte e da cópia na fixture: `E545063863BD945F428D9CA95F9FE9AB392784E0CE71E19A8601B1B728067950`.
- SHA-256 do UID fonte e da cópia na fixture: `9575058598E40F671A8665F01B9F0B6FF0B1B3BB1E1E0C086A26D67EF5CB4AD3`.
- SHA-256 de `source_hashes.json` da fixture: `3DF3E56CD107986F4BE8448EC7DE214EB72E4F84749CCF2E494497F336D4F41E`.

O teste e seu UID coincidiram byte a byte entre o worktree e a fixture. O Project Manager do usuário (PID 46912) permaneceu ativo; a execução headless foi encerrada. A engine/fixture foram devolvidas para correção e retomada.

## Retomada final

Após a correção da referência de fixture (`ramp` → instância `slope`), executei os mesmos 14 IDs em `verify_04`, sobre a mesma fixture e HEAD. Resultado: **14/14 processos selecionados passaram**, exit code 0; os 14 registros têm `exit_code: 0`, `failed: false` e `timed_out: false`. A saída do minimapa agora registra 30 checks e zero falhas. Incluindo F7 flow (23) e F3 snapshot (52), esta execução contém 873 checks aprovados. Não somo a rodada anterior, que preserva o erro de fixture.

Também conferi o recibo existente `interface_05` sem repetir a sonda nativa. `GameInterface`: exit code 0, `ok: true`, **30/30 checks**, `timed_out: false`; o PNG de interface foi produzido. Os 2.247 inputs listados em `runs.json` existem tanto no worktree quanto na fixture, e seus SHA-256 coincidem integralmente com o manifesto do runner. `source_hashes.json` da fixture contém 2.241 entradas. Esta supervisão confere os recibos e os hashes; não é revisão semântica independente dos testes ou da apresentação.

Nos logs de engine/saída de `verify_04` e `interface_05`, não encontrei `SCRIPT ERROR`, `Parse Error` ou `ERROR:`; nenhum timeout foi registrado. O runner permaneceu em SHA-256 `52D6A9B458406BFC5ADB030AB1CDF66630EC88B29C6DADCD524269D36E7D1963`, e o Godot standard em `AB1824F85BFD8E0E4128182C000C4003A3E042245B2967848D089B2A04B22424`.

Recibos finais:

- `verify_04/plan.json` SHA-256: `36D03C2801EA41EF971905E9E51ED66417219A750D77FA4020716899C45DD7FC`.
- `verify_04/checks.jsonl` SHA-256: `244510EA8629F2D74B8EB37BAAA3894F49EC78BB9538101C924CCA4A8CD9CF1D`.
- `interface_05/runs.json` SHA-256: `E0897A66BB071519F0B6A454AD2437B441D299040503D864587192557589CCDE`.
- `interface_05/geometry.output.log` SHA-256: `59DBB0DD419FDBF5F6964E2CE3CDF0BE9E23333E7583051B8AD8C9B2198172DE`.
- `interface_05/minimap_interface.png` SHA-256: `E45CB69B4F442FEEE2D23C00BB641DDF721611C65798A61BB1158ACD9A89C307`.

O Project Manager do usuário (PID 46912) permaneceu ativo. Os processos de validação headless terminaram; a engine foi devolvida ao responsável pelo export.

## Fechamento após o ajuste final do HUD

O runtime final está no commit `c9a3673f201f38f33d2a7200b61de12d3ebce84e`, sobre `8ca89b1b5b7ff6f538898f6f62b3c6cf9e9c8e86`. O ajuste após o primeiro executável reservou espaço para o botão de classe no HUD. A compatibilidade é registrada por fatias: a seleção core `verify_04` continua sendo a prova dirigida de 14 IDs/873 checks já registrada, e, depois do delta exclusivo de layout, `verify_05` repetiu apenas a cauda afetada (StageMinimap, F7 flow e F3 snapshot). O `plan.json` histórico de `verify_04` retém seu campo `source_commit` original; este recibo não o sobrescreve nem conta novamente seus checks.

`verify_05` selecionou 3 de 303 passos e passou nos três: StageMinimap 18 checks, F7 flow 23 e F3 snapshot 52, total **93 checks**, todos exit code 0, sem timeout. O `plan.json` registra HEAD antes/depois `8ca89b1b5b7ff6f538898f6f62b3c6cf9e9c8e86`; o estado de trabalho incluía o ajuste de layout que a rodada repete. O runner de conclusão não foi repetido por Luna.

`interface_06` é a prova nativa final de GameInterface: **31/31**, exit code 0, `ok: true`, sem timeout ou checks falhos. Inclui o novo oráculo `minimap_clears_class_button`, além de zoom por roda e botão, limites/reset, modais, movimento após zoom e persistência após retomada. Os 2.247 inputs de `runs.json` foram conferidos por SHA-256 contra worktree e fixture: zero ausentes ou divergentes. Os hashes de `scripts/main.gd` coincidem entre o recibo e o commit final. Nenhuma sonda nativa foi repetida nesta supervisão.

Os logs `verify_05` e `interface_06` não contêm `SCRIPT ERROR`, `Parse Error` ou `ERROR:`; nenhum timeout foi registrado. Essa verificação e a conferência de hashes supervisionam os recibos, sem auditoria semântica independente. O build final ainda depende do resultado do pacote exportado; esta seção não declara o PCK de floresta nem o executável aprovados.

Recibos desta fatia:

- `verify_05/plan.json` SHA-256: `E48B50EC64CC7EDC13F4E8C607CBF191252506C2DED64927DF221FEF26644FDA`.
- `verify_05/checks.jsonl` SHA-256: `085DF0BFB882252AFCA6EA480E5AB6C85C1046A0146B167C79ABC586AACAEA2A`.
- `interface_06/runs.json` SHA-256: `D54BFD3A8A1B7D814385B32F049E08E29344FA6CD49B3831E3B858F8BE586E32`.
- `interface_06/geometry.output.log` SHA-256: `236121DFC5429403D46CF9A31BDD5C202CEB830E8C4A198D703238B819286C0F`.
- `interface_06/minimap_interface.png` SHA-256: `4911D24C135B8A333DCC72F9D9C9ED100DEFC362111AE9FE34A8CCC2C496A129`.
