# Supervisão Luna — viewport tools F9

## Identificação e escopo

- Checkout `.tools/map-editor-m5`, branch `codex/map-editor-f9`.
- HEAD congelado confirmado antes/depois: `6d729724ca29449d02847146f989378e194d2073`.
- Godot 4.7.2 standard, SHA256 `AB1824F85BFD8E0E4128182C000C4003A3E042245B2967848D089B2A04B22424`.
- Fixture única `.godot/verification/e07_f1/fixture_project`. Os quatro completion runners fizeram import normal; Core reutilizou essa fixture. Verify usou `-F1Fixture -SkipEditorImport -CheckTimeoutSeconds 300`.
- APPDATA e LOCALAPPDATA apontaram para `.godot/discardable_profile` na fixture durante Verify e foram restaurados ao terminar.
- Execução sequencial: Viewport20, ViewportNative52, LibraryNative53, Shadows28, Core (oito grupos/639) e seleção oficial de cinco checks.

## Resultado dos runners

| Etapa | Resultado | Contagem |
|---|---|---:|
| Viewport | PASS (`F9 Viewport: True`, `ok:true`, exit 0, sem timeout) | 20/20 |
| ViewportNative | PASS (`F9 ViewportNative: True`, `ok:true`, exit 0, sem timeout) | 52/52 |
| LibraryNative | PASS (`F9 LibraryNative: True`, `ok:true`, exit 0, sem timeout) | 53/53 |
| Shadows | PASS (`F9 Shadows: True`, `ok:true`, exit 0, sem timeout) | 28/28 |
| Core candidate | PASS (`M8_SELECTED_PASS`, runs `ok:true`) | 53/53 |
| Core document | PASS | 70/70 |
| Core terrain | PASS | 102/102 |
| Core composition | PASS | 63/63 |
| Core population | PASS | 91/91 |
| Core patrol | PASS | 58/58 |
| Core generation | PASS | 89/89 |
| Core exchange | PASS | 113/113 |

Os nove registros Core (incluindo import) têm exit 0, `ok:true`, `timed_out:false`; os oito grupos somam 639. Logs da seleção sem `SCRIPT ERROR`, `Parse Error` ou `ERROR:`. Evidência de render/UI nativa confirma resultados automatizados e capturas do runner, sem constituir auditoria semântica independente ou aceite visual humano.

## Checks oficiais

`verify -List` e a execução selecionaram cinco passos: `combat_animation_test` (índice 10), `e07_f6_snapshot_test` (252), `e07_f3_snapshot_test` (268), `e07_f1_pilot_scene_test` (296) e `e07_f1_presentation_test` (297). Todos passaram com exit 0, `failed:false`, `timed_out:false`; resumo de saída: animações 39 checks, F6 snapshot 40/0 falhas, F3 snapshot 50/0, F1 piloto 102/0 e F1 apresentação 37/0. Final `Selected checks passed (5/299 steps); unselected steps were not run.`

## Auditoria de inputs pós-Verify

Auditoria inicial depois de Verify: quatro manifests de import (1.955 cada) mais Core (1.955), total 9.775 inputs. Ela cobriu a porção comum registrada pelos manifests de import e não incluiu os seis sidecars `.import` específicos de props, que aparecem nos manifests completos `model/runs.json`, `native/runs.json`, `library/runs.json` e `shadows/runs.json`.

Auditoria completa adicional, registrada em [`core/post_verify_full_input_audit.json`](core/post_verify_full_input_audit.json): recalculei SHA256 para todos os inputs dos quatro manifests completos (1.961 cada) e do manifest Core (1.955), total 9.799 entradas de fonte, sem divergências contra os hashes registrados e contra cada arquivo correspondente na fixture. A verificação inclui os seis `.import` de props adicionados a cada conjunto. HEAD continuou em `6d729724ca29449d02847146f989378e194d2073`.

`project.godot` não é contado como input idêntico entre as raízes. Separei os hashes: fonte `ADF17C0941269918DEE0A0005329D874DA199778DDEFCE294CA00E655367857E`; fixture `33726AFE86093A0D6F580114F803045E4F6624DC94528ECBEBD61FB199A06517`. A comparação linha a linha confirmou como única diferença `version_control/autoload_on_startup=true` na fonte e `false` na fixture, delta declarado para evitar inicialização do GitPlugin indisponível na engine standard.

## Hashes das evidências

Hashes recalculados diretamente dos arquivos:

| Arquivo | SHA256 |
|---|---|
| `model/runs.json` | `5708B0B7EC9FAF7DB654D5F0FF9696ACBDA3BE6E14C72C9408828B0730121FA1` |
| `model/import/manifest.json` | `A98371E4081C1A27DFCA41310804C8073923E08B00A9D375DFAD839C62401E15` |
| `native/runs.json` | `D49BE8B27DA52205039ABA046C0D488048AC0550EAA83591716D1739C6D5DB68` |
| `native/import/manifest.json` | `660D504ACFC5ACC4101E68CA2F2501B7533BA1F4FBDA89EE0DD2AF59FFCA2202` |
| `library/runs.json` | `572EBCA21895F7E9D49F900780E8F3E84331B31201616D6BAAF0A3BC9DB59B67` |
| `library/import/manifest.json` | `6DC5E1DA2702B742CF7A5C5C97C707BB9CC54C586E5A9B1EDA02AEE0A2601C81` |
| `shadows/runs.json` | `D3381A2054B8BFBD24FB4EF25BD70BAE00A62F5BFF3A6F11704612234BFA27C4` |
| `shadows/import/manifest.json` | `E7B98ADEAC82AFD68FBB1EC89434CA0EE408C490F237638BA286C63A19133298` |
| `core/runs.json` | `EF7A6DE71BBDCC320596D36C0968D1519F953AAD19107A49CB28C01FFECA33F8` |
| `core/manifest.json` | `4626C43AE6A8BF8D2B69A5AA94A5EE5D988C362947ABD6E500E653D93C3393C1` |
| `official/plan.json` | `42CF5CB7B695485A56069050F1AF15BB6B332F20919776A760D303B1AAD6B423` |
| `official/checks.jsonl` | `49B2DD00C3E9CDB7C12FDB9620265B5CE9A3D3DE15906E514CB03FF700FDED5F` |
| `core/post_verify_full_input_audit.json` | `935F958F2FACB620B43DEF71C8090176672C9D5E5AD7F4C6323AB70415DC154E` |

## Limites

Esta supervisão confirma execução, contagens, erros, timeouts e proveniência dos inputs. A evidência de ViewportNative usa telas/capturas e automação nativa; não substitui teste humano de produto. Minimap, overlays e foco foram implementados e testados neste componente; permanecem pendentes custos, UX integrada, área final e outros itens F9 do checkpoint. Este lote não certifica F9 completo nem representa aceite humano. Autoria e validações autorais permanecem separadas desta reprodução Luna. A fixture está liberada; checkout pessoal/playtest e saves não foram tocados.
