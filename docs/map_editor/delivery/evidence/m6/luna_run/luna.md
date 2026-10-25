# Supervisão automatizada Luna — M6

- Candidato congelado: `227dfb4e3646c4312ea075bca4d1e4a6dfb64a93` (branch `codex/map-editor-m6`, checkout `.tools/map-editor-m5`). HEAD antes/depois: o mesmo SHA.
- Papel: Luna supervisionou execução, término, contagens, erros, timeouts e hashes. Não fez auditoria semântica; não editou runtime, testes, runner, oráculos ou expectativas. Nenhum commit foi criado.
- Engine: `C:/Users/João Pedro/Documents/ChatGPT/RagRPG/.tools/godot/Godot_v4.7.2-stable_win64.exe`, Godot `4.7.2.stable.official.ed1daf0bf`; SHA256 `AB1824F85BFD8E0E4128182C000C4003A3E042245B2967848D089B2A04B22424`.
- Janela da execução do runner (UTC): 2026-10-25 12:10:56–12:11:39. Seleção oficial concluída em seguida; o manifesto oficial registra criação às 12:11:57 UTC.
- Fixture reutilizada: `.godot/verification/e07_f1/fixture_project`. O runner registrou `head_before`/`head_after` idênticos, restaurou o `project.godot` para o estado de base antes do verify oficial, e confirmou igualdade fonte/fixture para 1.805 arquivos de entrada. SHA256 do `project.godot` fonte: `ADF17C0941269918DEE0A0005329D874DA199778DDEFCE294CA00E655367857E`; fixture depois do driver nativo (delta declarado): `E4EF076D9091EC927398E5F882168A0EC9C92890DB1F7951A9A439AB58BBB7CB`. O verify oficial confirmou `source_root.txt` apontando para este checkout e carregou 1.805 hashes-fonte.

## Runner M6

Execução: `tools/map_editor_generation/run.ps1 -GodotPath <engine> -EvidenceDirectory docs/map_editor/delivery/evidence/m6/luna_run -Native`.

| Etapa | Resultado |
|---|---|
| Importação | PASS, exit 0, sem timeout/aborto |
| Geração | PASS, 89/89 checks; hash do pacote `ea7f01e8c3f371c6abceada3c03602450a1f5f446413969b2b7acfed1e30e121` |
| CLI A | PASS, exit 0 |
| CLI B | PASS, exit 0 |
| UI nativa | PASS, 28/28 checks; exit 0 |

As duas saídas CLI produziram o mesmo `output_hash` do pacote de geração (`ea7f01e8…e121`). Todas as cinco etapas concluíram; `runs.json` marca `ok=true`, `timed_out=false`, `aborted=false`, `exit_code=0` em cada uma. Os logs de saída e engine foram varridos: nenhum `SCRIPT ERROR`, `Parse Error`, `ERROR` ou indicação de timeout. Houve apenas um aviso do editor na importação oficial sobre uma pasta aninhada `tools/map_editor_probe/hosting` ignorada; o processo concluiu com exit 0 e não houve erro.

## Verify oficial selecionado

Primeiro, `tools/verify.ps1 -List` foi salvo em `official/list.txt` (299 etapas catalogadas; SHA256 `4F5454C58D762BE98F4C7F969085B272E9E74D7AB0E22A1AE848012A490504D9`). Depois foi executada, na mesma fixture, a seleção aprovada por Sol:

| Índice | Check | Resultado |
|---:|---|---|
| 1 | `editor_import` | PASS, exit 0, sem timeout |
| 273 | `e07_f1_geometry_test` | PASS, 33 checks, zero falhas; seed 711; manifesto `1f17a2dee4e34e41a22f0be992265c440bae3c9db966655238c008f5c8db879c` |
| 274 | `e07_f1_actor_integration_test` | PASS, 193 checks, zero falhas |

Resultado: 3/299 executados e aprovados; 296/299 etapas não executadas. A etapa 296 `e07_f1_pilot_scene_test` e a 299 `e07_f8_candidate_resume` permaneceram fora da seleção, junto das demais etapas não selecionadas. Não foi iniciado bootstrap de cópia: o verify usou `-F1Fixture` e a fixture já existente.

## Hashes de evidência

Os caminhos são relativos ao checkout e cada hash abaixo é SHA256 do arquivo indicado.

| Arquivo | SHA256 |
|---|---|
| `runs.json` | `88795AD5F36B3CCB465E036FA3C55FBED0C1F03166CB58E9D63E3E0136C53E9A` |
| `manifest.json` | `4276816AB8643E8C05B92020DD38DFAB6EF2E4851D2A48F747CC69C642EE0C7E` |
| `import.output.log` | `65266ECC51590D7E85010DAB58E897AC1A8BD879079AA036BDFA5F18A05C9AA7` |
| `import.engine.log` | `5FADBFDEE9D3B8366EB72E65BD33C2D4FE56DB9AC49C87E052255E678F4FA283` |
| `generation.output.log` | `87E5ADC0BEE0E0134576142873C06A92EBFB90C0FEA25EAD0E846D7271C5E400` |
| `generation.engine.log` | `88C2C6E0C807E4002F1F6319E9D2686BAC4E789F9FF4128AD2AFC99074095D4E` |
| `cli_a.output.log` / `cli_b.output.log` | `0A35D7E0A7F66A47EFCC2A842A3D93C0751401EC4EC7AE9524FD9FC2F56CE0DF` (idênticos) |
| `cli_a.engine.log` / `cli_b.engine.log` | `92385FEA22FF4307C87F4EF7C8218F761825353B88CF1715EC056BC44EAB8CEC` (idênticos) |
| `native_ui.output.log` | `E8EA329DCD127D9172ACEBB31C7267329DF617DCCBF7511D83B2D35284C0AC1D` |
| `native_ui.engine.log` | `96BE7DE9BFBCDD3423B2B8FE8DFE3748BC1DDA6D19349E9A34802ED60E2B6B2B` |
| `official/plan.json` | `202497FA390AEBC0B2CB1C3470EF38F7986E885326D372CD8E1232C4520B2672` |
| `official/checks.jsonl` | `2C70F40C27602C938073F9BC85896CAE91C34943D2A43EAB027762F7E0FF038B` |
| `official/001.output.log` | `25FCA8A857A8124F4CE408CD0C0220024CE77463C49CFC70DBD6DE33A5EF97F0` |
| `official/001.engine.log` | `5FADBFDEE9D3B8366EB72E65BD33C2D4FE56DB9AC49C87E052255E678F4FA283` |
| `official/273-e07_f1_geometry_test.output.log` | `71628C66E650C01AEE64383E660745233CC8908C6C07CE436BD389457176DE81` |
| `official/273-e07_f1_geometry_test.engine.log` | `9952DEC095753E42EB9EA511E5457619DAF54BBC708300170C5ABD2B146E8106` |
| `official/274-e07_f1_actor_integration_test.output.log` | `3228E013C9DC947B57FB21801D73C20CE639257E73554894961555FD5960A14E` |
| `official/274-e07_f1_actor_integration_test.engine.log` | `FB5C6ADF5F346C4593A4B312FE7968B37777D50D08A0A358E403302E69F5BC0E` |

`official/checks.jsonl` registra exit 0, sem timeout e sem falha para os três checks. Os logs completos, `runs.json`, `manifest.json`, `plan.json`, listagem e hashes-fonte estão preservados em `luna_run/` ou na fixture indicada. As verificações provam apenas as execuções listadas; não abrangem os outros 296 checks nem constituem validação semântica independente ou aceite de produto. Execuções autorais anteriores e a inspeção visual de Sol não são atribuídas a Luna.


