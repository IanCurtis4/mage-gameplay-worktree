# Supervisão Luna — clientes GUI/AX/CLI de gameplay F9

## Identificação e execução

- Checkout `.tools/map-editor-m5`, branch `codex/map-editor-f9`.
- HEAD congelado confirmado: `8610171e329b2b03b622dd275f13246dbcc225d2`; permaneceu inalterado.
- Godot 4.7.2 standard; SHA256 `AB1824F85BFD8E0E4128182C000C4003A3E042245B2967848D089B2A04B22424`.
- Fixture única `.godot/verification/e07_f1/fixture_project`; imports normais nos quatro completion stages e no candidato.
- Sequência executada até a falha: GameplayEditorNative, GameplayCli, GameplayNative, GameplayWindow, Candidate Native49 e Core. A seleção Core parou em `composition`; os grupos posteriores e Verify oficial não foram executados.

## Seleções concluídas antes da falha

| Seleção | Resultado | Contagem |
|---|---|---:|
| GameplayEditorNative | PASS (`F9 GameplayEditorNative: True`, exit0, `ok:true`, sem timeout) | 22/22 |
| GameplayCli | PASS (`F9 GameplayCli: True`, exit0, `ok:true`, sem timeout) | 18/18 |
| GameplayNative | PASS (`F9 GameplayNative: True`, exit0, `ok:true`, sem timeout) | 52/52 |
| GameplayWindow | PASS (`F9 GameplayWindow: True`, exit0, `ok:true`, sem timeout) | 33/33 |
| Candidate Native | PASS (`M8_SELECTED_PASS`, exit0, `ok:true`, sem timeout) | 49/49 |
| Core candidate | PASS | 53/53 |
| Core document | PASS | 70/70 |
| Core terrain | PASS | 102/102 |
| Core composition | **FAIL** (`ok:false`, exit1, sem timeout) | 60/63 |

Falharam exatamente estes três checks em `core/composition.output.log`: `seam_closed_outside_opening`, `wall_blocks_los` e `large_field_plus_small_room`. O registro `M3_RESULT` mostra `count:63`, `ok:false`, `package_bytes:22360`, `compile_ms:154.895`, `large_package_bytes:8` e `large_compile_ms:2109.675`. O Core runner encerrou no primeiro grupo com falha; population91, patrol58, generation89 e exchange113 não foram executados. Não alterei fonte, teste ou expectativa, não repeti o grupo e não executei Verify após a falha.

No recibo do CLI, `preview_process_exit.all_closed` é `true` para os dois PIDs externos criados. Nenhum processo de usuário foi encerrado. Logs da falha não mostram `SCRIPT ERROR`, `Parse Error` ou erro de engine associado; a falha observada é o resultado dos três checks acima.

## Estado e hashes conferidos

| Evidência | SHA256 |
|---|---|
| `editor/runs.json` | `B8D2D155F1936F7B0708C1B8102210E8DCED19A71F8DE1F212F73631458AB202` |
| `editor/import/manifest.json` | `E1B868A887927BD96D8EF2C97945C2D699FE196CF67393E23AFBC27BAE8D4053` |
| `cli/runs.json` | `7C5F4F7A24768403D605A94B7AEF5039294EA2D7F41A2AC7A8F3B8A05A7F932C` |
| `cli/import/manifest.json` | `AFF1969E94BDB23676A36E940F377689E5A074A8CC03EE1A6373EF318FF66B3F` |
| `native/runs.json` | `5C79F4F2AEEFFD4B45C81145D3B9894FDF3B9468FE42CE259ECB7D87C49A321E` |
| `native/import/manifest.json` | `FAC764C7466C7142B1AEF809A40A97A8913300118835A012B0E0589F4EE7F8BB` |
| `window/runs.json` | `D64039251E505B2A334FB7D41690C863EFFE8729C2AB9DF8940E73AB192287A4` |
| `window/import/manifest.json` | `9D08D4481A876677D992BA0621AF95C6BDA7340D5995074E002D34351498A3C8` |
| `candidate_native/runs.json` | `8A156FE90606DF4A097EF5C82318C3D1B4E2F077F47517A102C3A4172F7C1439` |
| `core/runs.json` (partial; stopped at composition) | `F0787523BBF54B8776E03166114222A6671950B25A224098A8F9EA1CA5517EFC` |

Capturas preservadas: `editor/gameplay_editor.png` SHA256 `4923A2F7264EEF1916FD027AD913CE9BF953D1BD91EA241914F27FCC571D23FC`; `native/gameplay_start.png` `835A1F8A3C7267D53E21256FEDF88058C8EEAB3A65FB87347359183A32B61D91`; `native/gameplay_combat.png` `02913A5F88D89638065E6FEB5DB947F526B17523B7951A6EB7E9D9040FD4BB21`; `native/gameplay_bridge.png` `9A84F0E698A6CC87A2C97B67B5869B6A642CFF0BF1797F6524FB51112F083CD2`.

Não houve Verify pós-Core, portanto não há recibo de Verify, auditoria pós-Verify de inputs ou hashes oficiais nesta rodada. Os manifests dos runners concluídos registram o SHA congelado antes/depois e o SHA de engine acima. Fixture liberada ao terminar a coleta; nenhuma alteração de fonte/teste/expectativa ou commit foi feita.

## Limites

Este é um relatório de supervisão de execução, não auditoria semântica independente. Registros GUI/AX/CLI aprovados permanecem evidência parcial diante da falha Core. Falhas históricas CLI01/02 estão preservadas separadamente; não são a falha desta rodada. A negativa da porta24 continua explicitamente coberta pelo autor, sem relaxamento nesta supervisão. VFX dos quatro campos, release, responsividade, síntese regional e outras frentes F9 continuam abertos; nenhum aceite humano ou conclusão F9 é inferido.
