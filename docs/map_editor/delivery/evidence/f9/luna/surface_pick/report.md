# F9 SurfacePick — emendas contínuas e retomada in-game

Data: 28/10/2026. Papel: autoria/supervisão Luna. Checkout de execução: `.tools/map-editor-m5`; Godot 4.7.2 standard (`Godot_v4.7.2-stable_win64.exe`, SHA-256 `AB1824F85BFD8E0E4128182C000C4003A3E042245B2967848D089B2A04B22424`). Freeze executado: `58350cab28da7053eba9151d448911abd5b32a5c`. Cada completion-runner `runs.json` confirma esse mesmo `head_before` e `head_after`, saída 0, timeout falso, e compara os hashes de todos os inputs entre source e fixture sem divergência.

## Resultado

| Etapa | Resultado |
|---|---:|
| SurfacePick | PASS 24/24 |
| Geometry | PASS 46/46 |
| Ports | PASS 92/92 |
| F1 geometry oficial (#273 de 299) | PASS; 33 verificações, zero falhas |
| F1 actor integration oficial (#274 de 299) | PASS; 193 verificações, zero falhas |
| RoundedNative | PASS 20/20 |
| RoundedResume, nova sessão compatível | PASS 13/13 |

Somente as duas provas F1 selecionadas foram executadas; suíte completa, navegação extensa de 1.000 witnesses e lotes SnapshotDensity/F3/F6 não foram repetidos.

## Prova SurfacePick

O novo teste `F9_PICK_RESULT` usa o WorldGeometry canônico em pequenos stages derivados de uma cópia da fixture F1. Passaram: escolha do menor `surface_id` em seam plana e rampa não coplanar; hit de câmera projetada por `ExpeditionGeometryView.ray(project(point))` com a tolerância existente; vértice compartilhado por três faces; resultado invariável ao inverter a ordem de surfaces/connectors/links/visible; travessia pelo `WorldActorMotion` com corpo 20×32 e validação de suporte em cada passo.

Também passaram os casos negativos: contato sem link, overlap coplanar interior, candidato coplanar rogue não ligado, abertura remota, ligação desligada, one-way, connector kinds incompatíveis, abertura não-walk, dois hits próximos em cotas diferentes, stale revision, raio zero e slab superior oculto que continua oclusor. Um interior simples ainda resolve e a face visível mais próxima segue vencendo.

Evidência: `pick/runs.json`, `pick/geometry.output.log`, `pick/geometry.engine.log`.

## Geometria e interfaces

Geometry manteve os 46 checks, incluindo caminhadas/obstáculos/caps e interpolações de rampas em alturas 40/160/200. Ports manteve 92 checks. Na operação perfilada de Ports: elapsed 40.478 ms, 244 conexões, 17.778 estados e pico de armazenamento de navegação de 202.419.320 bytes; 8.606 witness points e 8.268 witness segments. É o custo de uma operação explicitamente medida nesse teste, sem inferência para a navegação geral ou para uma busca de 1.000 witnesses.

Os dois testes oficiais selecionados passaram. A primeira execução dos mesmos IDs (`official/`) foi feita com `tools/verify.ps1` sem definir APPDATA/LOCALAPPDATA. A inspeção confirmou que esses dois testes não chamam `user://`, ProfileStore ou save persistente; não há escrita de perfil pessoal indicada. Para satisfazer a reprodução isolada, os mesmos dois IDs foram repetidos em `official_isolated/`, com ambas as variáveis apontando à pasta descartável `.godot/discardable_profile` da fixture e restauradas no fim. Ambos passaram também nessa execução; nenhum perfil pessoal foi modificado.

## Gameplay real e retomada

`RoundedNative` refez o fluxo GUI/AX, compilou e publicou a peça, criou candidato e nova sessão, abriu a App, selecionou o apoio elevado, iniciou a caminhada canônica, chegou ao alvo mantendo o corpo original e salvou a captura de gameplay. Medidas: compile/prepare 3.299 ms; publicação 27.167 ms; abertura App 48.976 ms; início App 31.419 ms; pedido de movimento 46.033 ms; caminhada in-game 3.061 ms. 120 durações de frame durante essa caminhada: p50 19.216 ms, p95 29.432 ms e máximo 115.871 ms. Escopo: uma peça publicada, uma rota e uma caminhada; isso não é FPS geral.

A sessão nova `d82baa96dfdc98bcf7e74806` foi criada pelo fluxo canônico dentro da fixture e está ligada ao candidate hash `e0746eedf91518c2996662518140d9956814caf1fdd213dd09d724975a7d31f8`. Não foi usado nem adulterado o checkpoint anterior incompatível com a fonte atual. Checkpoint suspenso antes de retomar: formato 2, 3.594.152 bytes (limite 4.194.304), payload SHA-256 `2d1ed5e7b3d493464bb1d961c92c1116c3edfe9c0ee6751b951f09a90988adef`, bytes comprimidos SHA-256 `c1947a348a02313fccf70f4ecdc377a2aec9779ceaa00bc76549ab6b632be670`; `session.bin` SHA-256 `A45A8FFF03E43A4206A52405BD5AB7D0C2BC437DD569C66F51F678593D4CA6B2`.

`RoundedResume` em processo novo passou abertura, retomada, mesmo candidato, geometria restaurada (536 superfícies/828 conexões), posição salva `XZ 760/780`, apoio elevado no alvo `780/780`, pick, caminhada curta, clearance e captura. Resuspensão canônica gravou checkpoint formato 2 com 3.589.468 bytes, ainda abaixo de 4 MiB. Tempos: abertura 49.118 ms, início/resume 30.111 ms, pedido de movimento 8.775 ms, curta caminhada 109.024 ms. Somente duas durações de frame foram amostradas neste deslocamento breve (p50/p95 38.048 ms, máximo 62.020 ms); essa amostra não é FPS geral.

Evidência e imagens:
- `native/geometry.output.log`, `native/geometry.engine.log`, `native/runs.json`
- `native/rounded_hill_curve_and_path.png` — SHA-256 `BCB5DC58416F891B135C357D31C84F5BD307C6644C29849F948F5197093A60BD`
- `native/rounded_hill_gameplay_walk.png` — SHA-256 `F4065F693CC7E5A281527B83FB3A61ACED9461B75E2C93FB30673A1686764A19`
- `resume/geometry.output.log`, `resume/geometry.engine.log`, `resume/runs.json`
- `resume/rounded_hill_resumed_gameplay.png` — SHA-256 `846C14ECF1AB88749542BF55BAFA8BC70577B6758BF26D49C5A16DD0EC14798E`

## Hashes dos inputs centrais

Os valores vêm do manifesto do runner da retomada; o runner comparou cada hash fonte/fixture para o conjunto completo de inputs.

| Arquivo | SHA-256 |
|---|---|
| `tests/map_editor_surface_pick_test.gd` | `A5E214CF6C35850ACCA8D4FD6E75DB9E19EF173C8B1A5E45C5E48C37A1C5D12D` |
| `tests/map_editor_rounded_hill_ui_test.gd` | `DD219485633AD78B30B486631F2C9E7716A7D902268E6A60C78F015E874D5145` |
| `tests/map_editor_rounded_hill_resume_test.gd` | `B0F545ED1FCF18D008E81736BC1196B6FE857FBD9868C8DCB2FA5ECE4DD25D0F` |
| `scripts/core/expedition/spatial/world_geometry.gd` | `F70A42020EEB230453D6E29DD00C2AE9C1580709CE6B626355D5A8B6CD74A004` |
| `scripts/core/expedition/spatial/world_support_patch.gd` | `A0B5EFEEBA4FA152F64E38A1305FE70477F2469A50027F364FAEA73D4717A8AC` |
| `scripts/world/expedition_geometry_view.gd` | `08280CD4BF1A031CE505375FC11C9E0FE957DE15E7AB91C97A7739D318901F19` |
| `scripts/world/expedition_projection.gd` | `F1C2C8335DE8D7AC1264C4A28B07C20E96477C0775BA22ABE17AB70E52D8811D` |
| `tests/fixtures/e07/f1/fixture_input.gd` | `5774FF357A8CBA564F83658DF6C2F659D1B792702943D04CA9963C17DCC79571` |
| `tools/map_editor_completion/run.ps1` | `E6B7F365198956BF7D92CAF674B04375F7DA1C8C44004952DD47DCA73520D735` |

## Limites

O seam picking, geometria de F1, interfaces e retomada densa testadas passaram neste freeze. Este pacote não fecha F9 global, não certifica uma suíte completa ou FPS, e não substitui playtest humano. Os tempos de abertura/preparação do App seguem em torno de 49/30 segundos e continuam documentados separadamente do movimento e dos frames in-game.
