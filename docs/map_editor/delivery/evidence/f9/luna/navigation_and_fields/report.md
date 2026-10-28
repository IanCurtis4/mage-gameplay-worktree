# Supervisão Luna — navegação e campos

Data da execução: 27/10/2026. Checkout: `C:\Users\João Pedro\Documents\ChatGPT\RagRPG\.tools\map-editor-m5`, branch `codex/map-editor-f9`. HEAD permaneceu `4642dbf878fab4004f98141c7e2437ee11e22bd5` antes e depois das etapas. A fixture única foi `.godot/verification/e07_f1/fixture_project`; não foi criada outra fixture nem alterado o playtest/save pessoal. O perfil temporário apontou `APPDATA` e `LOCALAPPDATA` para `.godot/discardable_profile` dentro da fixture, e as variáveis do processo foram restauradas no `finally`.

## Recibos autorais de navegação

Conferi os sete recibos finais enumerados em `author/navigation_audit.json`. Eles pertencem ao HEAD autoral `f21709ae...`, não são execuções minhas neste SHA. Cada recibo declara 2.002 inputs; recalculei os 14.014 hashes contra o checkout e os mesmos 14.014 contra a fixture: nenhuma ausência ou divergência.

| Recibo | Checks | Resultado do recibo autoral |
| --- | ---: | --- |
| `navigation_prepared_context_02` | 11 | PASS, exit 0, sem timeout |
| `navigation_prepared_lazy_02` | 24 | PASS, exit 0, sem timeout |
| `navigation_prepared_dense_02` | 5 | PASS, exit 0, sem timeout |
| `navigation_prepared_eager_01` | 5 | PASS, exit 0, sem timeout |
| `navigation_prepared_geometry_01` | 46 | PASS, exit 0, sem timeout |
| `navigation_prepared_ports_01` | 92 | PASS, exit 0, sem timeout |
| `navigation_prepared_batch_01` | 36 | PASS, exit 0, sem timeout |

A comparação eager/preparado e os tempos abaixo vêm dos recibos autorais, não foram repetidos nesta supervisão: mesmo mundo/perfil e resultados/digests iguais; eager `160389.246 ms` e preparado `100730.692 ms`. O custo eager continua uma limitação concreta de desempenho. Não inferi FPS nem desempenho geral. A execução `organic_direct_01` antecede quatro deltas e sete arquivos novos; sua compatibilidade anterior de 1.024 testemunhas é apenas evidência autoral histórica, não uma reprodução atribuída a este SHA.

## Execuções desta supervisão

| Etapa | Evidência | Resultado |
| --- | --- | --- |
| Core candidato | `core/runs.json` | PASS: 639 checks em 8 grupos; import e grupos com exit 0, sem timeout |
| `FieldsNative` | `fields_native/runs.json` | PASS: 73 checks, exit 0, sem timeout |
| `GameplayNative` | `gameplay_native/runs.json` | PASS: 52 checks, exit 0, sem timeout; execução SceneTree real |
| `GameplayControls` | `controls/runs.json` | PASS: 29 checks, exit 0, sem timeout; execução SceneTree real |
| Seleção oficial | `official/checks.jsonl` | PASS: 12/12 etapas e 3.649 checks, zero falhas/timeouts/exit não zero |

`verify.ps1 -List -Test ...` confirmou os 12 IDs solicitados (12 de 299 etapas possíveis). O aviso do runner informou que o editor import foi explicitamente omitido. Os logs conferidos não contêm `SCRIPT ERROR`, `Parse Error`, linha `ERROR:`, timeout ou falha. Os termos “error/failure” que aparecem em alguns nomes de checks são casos negativos aprovados, não erros do engine.

## Integridade e hashes

Após o Verify, conferi os inputs de `core/manifest.json` (1.996), `fields_native/import/manifest.json` (1.996), e as listas de inputs de `fields_native`, `gameplay_native` e `controls` (2.002 cada). Nos 9.998 registros somados, todos os arquivos estavam presentes; os hashes de fonte e fixture corresponderam aos recibos, sem divergências. As listas de execução dos três estágios não carregam SHA de fixture separado; comparei cada SHA declarado de fonte com o arquivo correspondente dentro da fixture. Os recibos autorais acima foram auditados separadamente.

`project.godot`: checkout SHA-256 `ADF17C0941269918DEE0A0005329D874DA199778DDEFCE294CA00E655367857E`; fixture SHA-256 `33726AFE86093A0D6F580114F803045E4F6624DC94528ECBEBD61FB199A06517`. A única diferença textual observada foi `version_control/autoload_on_startup=true` no checkout e `false` na fixture.

Engine Godot 4.7.2 standard SHA-256: `AB1824F85BFD8E0E4128182C000C4003A3E042245B2967848D089B2A04B22424`.

| Artefato | SHA-256 |
| --- | --- |
| `core/manifest.json` | `E5CE55C5BA5468259D732605CD2B033879E5ACA38EFF14EA292838341F6E4B65` |
| `core/runs.json` | `D6804AC8CED005ECAF3D16105DD17AFDDA54F1AA7FB5B2755AC210EDB66C1F27` |
| `fields_native/import/manifest.json` | `4D355BFD6333BC98B0D07BBD3FD44FC0E8CC67A6E2CB94CA47C33D4F837802D3` |
| `fields_native/import/runs.json` | `CC94CD1B1DDD79FA068BAAF533526BCE63B5C7AE7EF2245F976342AEFDBE157B` |
| `fields_native/runs.json` | `7B76F46D721C2FF27F3123588AE47DDE5D9568097A6CF1B3A75F4C3807E19A53` |
| `gameplay_native/runs.json` | `18C1E6489AA3F5B0F7388CE81B50F9596302148F36BE8DBBF28130067DE2210E` |
| `controls/runs.json` | `87AD5F4501A5A7A8349B179A433755608D083912360EE7291F5FE39C62D4421A` |
| `official/checks.jsonl` | `F70A49993D5A082414E9227F23EED5F97486A859EC512914F7D7AC0537ADFCDE` |
| `official/plan.json` | `7C29CF2748E82D13E2F7BC6B4F625751CBDEBBE4A02B12D1B22F8D54B37E9F13` |

| Captura PNG | SHA-256 |
| --- | --- |
| `fields_native/fire_wall_on_bridge_field.png` | `CE86851628BE7E9FBE0975EB838285CF0AE96290AADFDBA4D1154DDF110BA4C2` |
| `fields_native/fire_wall_ramp_field.png` | `416B0179A4A8813B627B6AD6F990F93DF1BA705752EC0C7CF97E1B5038F054FA` |
| `fields_native/fire_wall_under_bridge_field.png` | `2C251A9A3211DB7A70E8EA67DBF205EBCC872849BE5F28627AEEF9B3DF94400E` |
| `fields_native/fire_wall_under_bridge_occluded.png` | `E3395DDD7AF81128D77E4CB2213164AC9C7D0DE5EEA044B3951E5E3AD5101150` |
| `fields_native/lightning_wall_on_bridge_field.png` | `2B5CD6BE861510DCFBA097CC9ED42132DD091A2B6FAFCF0B8F3437B6C7E980B7` |
| `fields_native/lightning_wall_ramp_field.png` | `356E446663BD4AC0966AB0CA07F5C8AC49AD006B743065AB171516300AB7C89E` |
| `fields_native/lightning_wall_under_bridge_field.png` | `C8413946F3BAFBED415BD16537A82350E758A6C0D8101CCFD4BD3258BB17122B` |
| `fields_native/lightning_wall_under_bridge_occluded.png` | `E3395DDD7AF81128D77E4CB2213164AC9C7D0DE5EEA044B3951E5E3AD5101150` |
| `fields_native/phantom_barrier_on_bridge_field.png` | `FE106FDF8CD945C29644E0F4E69B6078F05BDFCA9819E85EDD41E4EC002950E8` |
| `fields_native/phantom_barrier_ramp_field.png` | `50D5C5FCD09CEAD984204588912A62A7748FD86A37D44578C6CE9C37C018071B` |
| `fields_native/phantom_barrier_under_bridge_field.png` | `137DAF1C81864B86FEA6162490443B199DD595C1AC027B4E160A699D055FC5D0` |
| `fields_native/phantom_barrier_under_bridge_occluded.png` | `E3395DDD7AF81128D77E4CB2213164AC9C7D0DE5EEA044B3951E5E3AD5101150` |
| `fields_native/ice_wall_on_bridge_field.png` | `B8AC603EBBBCEDAC3D18804F3C477A3AE78056300679E8AEFB85CAAE92CE2C77` |
| `fields_native/ice_wall_ramp_field.png` | `AC69080F14929E904823FD9082F861A5E50C6891641E8EE3ADBE49C977F4FF37` |
| `fields_native/ice_wall_under_bridge_field.png` | `337C7F5126969FAF9C9D38F652EE73982CFF7B634142693E6DF363238DBCEDBA` |
| `fields_native/ice_wall_under_bridge_occluded.png` | `E3395DDD7AF81128D77E4CB2213164AC9C7D0DE5EEA044B3951E5E3AD5101150` |
| `gameplay_native/gameplay_start.png` | `2E3D4507227A1D7ED53A5F6AE314F11EB7D704F49E0A61D575FDD48DEB920545` |
| `gameplay_native/gameplay_combat.png` | `3F85C337584D0224F9FDD2B2927E68EF1BBEDA3A137DFC6569277DC621DFAE16` |
| `gameplay_native/gameplay_bridge.png` | `A97A908CB61FA80EA8B2F5A9C1CF29B6E74EA3EC997B064A00AC1F322E118007` |

## Escopo e liberação

Este registro supervisiona execução, conclusão, logs e hashes; não é auditoria semântica independente nem aceite humano/de produto. Os testes não demonstram fechamento de F9; continuam pendentes custos/performance in-game, UX integrada e os campos finais ainda abertos no checkpoint. Não alego FPS, integração visual completa ou validação manual. A fixture está liberada para a próxima tarefa autorizada. Nenhum código, teste, expectativa ou HEAD foi alterado por esta supervisão.
