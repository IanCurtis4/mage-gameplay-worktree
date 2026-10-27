# Supervisão Luna — consumidor de gameplay F9-11

## Identificação e seleção

- Checkout `.tools/map-editor-m5`, branch `codex/map-editor-f9`.
- HEAD congelado antes/depois: `bf406c36415b9c3508d888ba200d2d1b4ef24494`.
- Godot 4.7.2 standard; SHA256 `AB1824F85BFD8E0E4128182C000C4003A3E042245B2967848D089B2A04B22424`.
- Fixture única `.godot/verification/e07_f1/fixture_project`. GameplayNative usou importação normal. Core reutilizou a fixture. Verify usou `-F1Fixture -SkipEditorImport -CheckTimeoutSeconds 300`; APPDATA/LOCALAPPDATA foram isolados em perfil descartável dentro da fixture e restaurados.
- Ordem executada: GameplayNative52, Core8/639, Verify com seis seleções.

## Resultados automatizados

| Seleção | Resultado | Contagem |
|---|---|---:|
| GameplayNative | PASS (`F9 GameplayNative: True`, `ok:true`, exit0, sem timeout) | 52/52 |
| Core candidate | PASS (`M8_SELECTED_PASS`) | 53/53 |
| Core document | PASS | 70/70 |
| Core terrain | PASS | 102/102 |
| Core composition | PASS | 63/63 |
| Core population | PASS | 91/91 |
| Core patrol | PASS | 58/58 |
| Core generation | PASS | 89/89 |
| Core exchange | PASS | 113/113 |
| Core total | PASS; nove registros incluindo import, todos exit0/`ok:true`/sem timeout | 639/639 |
| Verify selecionado | PASS (`Selected checks passed (6/299 steps)`) | 6 checks |

`verify -List` confirmou `combat_animation_test` (índice10), `e07_f6_snapshot_test` (252), `e07_f5_fault_test` (261), `e07_f3_snapshot_test` (268), `e07_f1_pilot_scene_test` (296) e `e07_f1_presentation_test` (297). Resultados: animações39 checks, F6 snapshot40/0 falhas, fault F5 20/0, F3 snapshot50/0, piloto F1 102/0 e apresentação F1 37/0. Cada linha em `official/checks.jsonl` tem exit0, `failed:false`, `timed_out:false`. Logs examinados sem `SCRIPT ERROR`, `Parse Error` ou `ERROR:`.

## Integridade pós-Verify

Depois de Verify, recalculei SHA256 de cada entrada em `native/runs.json` (1.976) e `core/manifest.json` (1.970), total 3.946 inputs. Fonte atual e fixture conferem com cada hash registrado: 0 divergências em ambos os conjuntos. Os manifests registram HEAD antes/depois exatamente `bf406c36415b9c3508d888ba200d2d1b4ef24494` e engine SHA igual ao registrado acima.

`project.godot` foi conferido separadamente, sem exigir identidade entre source/fixture. Source SHA256 `ADF17C0941269918DEE0A0005329D874DA199778DDEFCE294CA00E655367857E`; fixture SHA256 `33726AFE86093A0D6F580114F803045E4F6624DC94528ECBEBD61FB199A06517`. Ao substituir apenas `version_control/autoload_on_startup=true` por `false` na source, os arquivos ficam idênticos linha a linha. Esse é o delta VCS declarado que evita carregar o GitPlugin local ausente na engine standard.

## Evidência de capturas e hashes

As três imagens registradas pelo teste:

| Captura | SHA256 |
|---|---|
| `native/gameplay_start.png` | `64A7B1469BF7D05ED1EAB9CCD831119B6D9628416C8CE9BDCC4D3DFB7AD9415A` |
| `native/gameplay_combat.png` | `D4E598E59515AB1013A3A7014865D99A669E6D0B6D593ECD0B5CD5D1F4C034E4` |
| `native/gameplay_bridge.png` | `03AAFCD39DA50C092E47989B2E60C7E1843E1FBD21E950B16A30F97FE8852955` |

| Arquivo | SHA256 |
|---|---|
| `native/runs.json` | `ACE95A0FC86449E71097DFEA7A3B2CE7989BA9FB806D8C4D332AA2B94992DF40` |
| `native/import/manifest.json` | `A6C5724BCB6100384DFDC43A7937E2E1BBC0DB84494165C3E61ED81C6AB03835` |
| `core/manifest.json` | `E11C6C2586B840DB63A1E03BE1737BE10A6979CB8D7B145D4893DE918EC0CBCD` |
| `core/runs.json` | `822BC2149002D89E4AD3CADA210B53DCFEA4C62E3B4A89083DBC492534AB8A98` |
| `official/plan.json` | `179215615EF40C948543C833696900543912F7E1C38098CE8C986061EC94130E` |
| `official/checks.jsonl` | `75B6BBB60936B29532CE93CEA08BC1608930FC373A7AC7022C844501FD02D51B` |

## Alcance e limites

GameplayNative executa App e atores canônicos diretamente em SceneTree standalone. Exercita sessão descartável, entrada/ponto real, caminho de rampa/ponte, combate via `damage_applied` observado por um `Control` descartável, snapshot/lifecycle e preservação de perfil/controles. A prova observa o sinal de dano sem escrever HP, falsificar morte ou contornar LoS.

Essa execução automatizada não demonstra que os botões do editor, `OS.create_process` ou a entrega release estão ligados corretamente; tampouco mede FPS ou fluidez. Os recebidos Core/oficiais nesta rodada cobrem o SHA final, mas não constituem auditoria semântica independente nem aceite humano. Falhas históricas Native01–07 permanecem nos registros; nenhuma expectativa foi alterada.

O checkpoint F9 mantém pendência explícita: após `App.restart`, `Launcher.stop` continua apontando para o caminho da sessão anterior. A próxima integração deve estabilizar a identidade da janela/partida. Esta tarefa não corrige essa pendência nem declara F9-11 concluído. Habilidades/interações pelo novo fluxo, negativos adicionais, release limpo e área final também permanecem fora da supervisão. Fixture liberada após encerrar os processos desta execução; nenhum checkout pessoal/save foi tocado e nenhum commit foi feito.
