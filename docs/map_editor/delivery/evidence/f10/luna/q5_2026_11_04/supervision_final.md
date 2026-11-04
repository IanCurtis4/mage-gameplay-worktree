# F10 Q5 — recibo final de supervisão Luna

Data: 2026-11-04  
Worktree: `.tools/map-editor-m5`  
HEAD antes/depois: `34bf16511019e88bf34ddfabfab624e533d7c20d`  
Engine: Godot 4.7.2 standard, SHA256 `AB1824F85BFD8E0E4128182C000C4003A3E042245B2967848D089B2A04B22424`  
Fixture única: `.godot/verification/e07_f1/fixture_project`

## Execuções

Todas as etapas foram executadas sequencialmente. Os runners M8 e completion registraram `ok=true`, exit code 0, sem timeout ou abort. A busca dos logs não encontrou `SCRIPT ERROR`, `Parse Error`, `ERROR` nem timeout. O aviso conhecido de projeto Godot aninhado ignorado apareceu em logs nativos; não afetou os resultados.

| Evidência / etapa | Resultado | SHA256 de `runs.json` |
|---|---:|---|
| `.godot/q5_validation/core_final` — Core | M8_SELECTED_PASS; seleção Core completa | `74D08D9611A65997F40C92DF04DAA0C5FB7678CBD5A9AA543761553118409C16` |
| `.godot/q5_validation/final_ManualBrushNative` | 20/20 | `9DDD28DF76FE70F56E3EA7FBE755709A88311C8EB136F8F493BDFAB0BB4FB00D` |
| `.godot/q5_validation/final_TerrainNative` | 45/45 | `62A6EA3218FAA3C6B16902EBA604B3CDE3D8A2C49005B1A99E5FE89585A272C4` |
| `.godot/q5_validation/final_SocketFollow` | 10/10 | `E97399CB85A109BF9B4FF65409DB8F4C6B9BA26C75EC80BD234B378ECFE9D127` |
| `.godot/q5_validation/final_GridRegional` | 10/10 | `59B6198563A97FA17BC197784143D906B40E658089592C12A7DCD0546CCF4282` |
| `.godot/q5_validation/final_ReleaseApi` | 11/11 | `5326D8A98C301F96CD7F5BC5FC21D9C9ADA3B2663818CE12BBF83BC4F052B1B5` |
| `.godot/q5_validation/final_WorkflowNative` | 28/28 | `FC102CDE1231F9F05DBF04DCD69D2083D24AA14DEB50C94E7615DA671695205F` |
| `.godot/q5_validation/final_ExchangeMergeNative` | 10/10 | `867B9B12D8FAB2BF0ECF140A4397FCFC4571537D8237C0E3D61F1390FC626283` |
| `.godot/q5_validation/final_RootSynthesisNative` | 11/11 | `19E426833056BAFFB324A5EDE3DA34D01EDE9912938B2A737B2C6DF362B3C85E` |
| `.godot/q5_validation/final_EncounterAuthoringNative` | 25/25 | `DF1AE9F0BAE76DB43B0947CEA5C89E141B1D10664A280E8615E9ABA80B167E4B` |
| `.godot/q5_validation/final_ViewportNative` | 52/52 | `34AC1D9C3E3B9EA21E38A9C725ED1118A3BB40526EED36236C6200444E7FD30E` |
| `.godot/q5_validation/final_OcclusionNative` | 12/12 | `A6770DF0870F95059A8D236F36655022A1938EB2E56B8945BE5F9774A2F5827A` |
| `.godot/q5_validation/official_ui_recovery` — F7 presentation/flow/actions | 3/3 processes; 10 + 23 + 28 checks/assertions | `checks.jsonl`: `1FBB057BDA4E0350D799082CC791498A256D2BB14C71A32BD4B74106369585F7`; `plan.json`: `27BDD0E14321ABD776A531B969C0DDE8A372273F42B3A7C48CBE46499665A4D3` |
| `.godot/q5_validation/release_final` — release / Bosque / forest | 6/6, 8/8, 14/14; M8_SELECTED_PASS | `runs.json`: `D0E9B44F5CA6A673F48931066A3C4911114EA5BD514D472A9BC5C7C34DE6480C`; `manifest.json`: `B2748642EB1F794E641941D7EDF6A6737322C858D7EC74AA31122AAA38949EB9` |

## Integridade e release

O manifesto final lista 2.214 entradas de código/recursos com zero diferenças entre hash de origem e hash da fixture. O HEAD permaneceu igual antes e depois do lote. O runner definiu diferenças de `project.godot` para desligar inicialização VCS, habilitar a UI nativa e selecionar a cena/preset de exportação; os hashes globais do projeto de origem e fixture são, respectivamente, `ADF17C0941269918DEE0A0005329D874DA199778DDEFCE294CA00E655367857E` e `33726AFE86093A0D6F580114F803045E4F6624DC94528ECBEBD61FB199A06517`.

Medição M8 de pico sampled working set: import 911.187.968 B; export 1.033.338.880 B; release 622.022.656 B; Bosque 880.156.672 B; forest 1.097.490.432 B. Forest registrou entrada 161.504,868 ms, suspensão 7.245,373 ms e retomada 23.023,537 ms. As capturas `release.png`, `release_sanctuary_woods.png` e `release_forest.png` estão em `.godot/q5_validation/release_final`.

Hashes de pacote: release `b6ffc4b62c6dfc7583351bc8adc24d707b42e0282c8502ac635a829e1355f024`; Bosque `41a8e11a6c70fdc9c87cec67a2c9f8fc8fb7af5ecfdc1690ba532472c0e52587`.

## Limites

Este recibo confirma execução, conclusão, contagens, logs e hashes; não é uma auditoria semântica independente. A seleção F7 foi executada com `-SkipEditorImport` sobre a fixture F1 sincronizada; plano confirma os três IDs, timeout 300 s e exit code 0 em cada processo. Nenhuma fonte, teste, runner ou expectativa foi editada nesta supervisão. Sol inspecionou release_forest.png e consultou Get-Process separadamente, confirmando zero processos Godot remanescentes. A verificação de inicialização CUA após reset falhou antes de alcançar o código, com erro de escrita dos kernel assets (OS error 3); o percurso GUI por operador permanece pendente. Portanto este recibo não declara Q5/F10 fechado.


Integração Sol: o recibo foi transferido do destino documental incorreto no checkout principal para este worktree, com hash conferido antes de remover somente o arquivo próprio. O original recebido está preservado em `../../reviewer/q5_2026_11_04/supervision_received.txt`. Corrigido o hash literal do plano F7 por leitura direta do arquivo arquivado; contagens e resultados não mudaram. O hash de projeto da fixture acima é o da configuração normal restaurada pelo finally; o projeto usado no export está fixado em release_manifest.json.

As pastas .godot citadas são os locais de execução originais. Seus recibos/capturas foram arquivados, com verificação byte a byte, em `../../reviewer/q5_2026_11_04/`; logs redundantes e builds gerados foram removidos depois. A fixture única foi retida para a revisão humana.
