# E08 P5 A1 — catálogo de apresentação por espécie (entrega Sol)

Base `fd32d346`, checkout `.tools/map-editor-m5`, branch `codex/e08`. Sem commit.
Contrato: `docs/epics/e08_p5_contract.md` (A1). Propriedade: `e08_p5_files.json`.

## O que mudou

- **Novo** `scripts/presentation/species_presentation_catalog.gd` (script
  pré-carregável, sem `class_name`, sem JSON). `ENTRIES` é `const` (somente
  leitura) por `mob_base_id`:

  | mob_base_id | visual_id | V1 próprio | tinta de fallback | arma embutida |
  |---|---|---|---|---|
  | forest_wolf | e08_forest_wolf | e08_forest_wolf.png | branca | não |
  | forest_boar | e08_forest_boar | e08_forest_boar.png | branca | não |
  | forest_stalker | e08_forest_stalker | — | (0.58, 0.70, 0.59) | não |
  | forest_canopy_archer | e08_forest_canopy_archer | — | (0.77, 0.91, 0.73) | sim |
  | forest_ancient_warden | e08_forest_warden | — | (0.69, 0.85, 0.66) | não |

  API estática: `has`, `ids()` (cópia ordenada), `entry()` (cópia profunda),
  `visual_id`, `legacy_atlas`, `fallback_tint`, `embedded_weapon`. Os atlas V1 de
  lobo/javali continuam pré-carregados (dependência de export explícita).
- `scripts/presentation/e08_pilot_visual.gd`: o stub de coordenação foi
  substituído. `has_species_presentation(id)` consulta o catálogo (main.gd:255
  inalterado). `install_forest_atlas(actor) -> bool` mantém o contrato: `false`
  só sem ocorrência/animação ou se o V1 próprio de lobo/javali falhar; `true` para
  ids fora do catálogo (no-op). Novos auxiliares: `manifest_path(visual_id)`,
  `owns_species_body(animation, id)`, `has_embedded_weapon_body(actor)`.
- `scripts/actors/enemy_actor.gd`: a lista fixa `[forest_wolf, forest_boar]` virou
  consulta ao catálogo; `sync_npc_equipment_visual` não projeta arma quando o
  corpo instalado é o corpo próprio da espécie com `embedded_weapon`. A regra de
  caminho exato do `npc_body` do Arqueiro permanece igual. Nenhum campo novo no
  ator (o `runtime_manifest.json` do snapshot recusaria campo não declarado).
- **Fixture** `tests/fixtures/e08_species/` (`presentation.json`, `body.png`,
  `body.png.import`): cópia byte a byte do corpo V2 `warrior` com o caminho
  reescrito; o `rgba_sha256` é o mesmo (mesmos pixels). Parâmetros de importação
  idênticos aos do original. Não é arte de produto.

## Decisões de fallback e tinta

- **Lobo/javali (idêntico ao anterior):** V2 específico em
  `DirectionalAnimationSet.default_path(visual_id)`; ausente/inválido → V1
  completo da espécie via `set_body_atlas`. Nunca o genérico.
- **Espreitador/Arqueiro da Copa/Guardião:** manifest padrão ausente (hoje) →
  nada é tocado: corpo genérico de `animation_kind` (warrior / archer
  `npc_body` / beast_master) e tinta atual. Manifest presente e válido (e do
  mesmo `actor_kind`) → instala o corpo próprio no mesmo `CharacterAnimation`
  (relógio preservado) e rederiva a projeção. Presente mas inválido ou de outro
  kind → mantém o corpo genérico completo (validação prévia via
  `load_manifest`; nada parcial) e emite `push_warning`, retornando `true`
  (o genérico é apresentação completa; main.gd não acusa erro).
- **Tinta:** a paleta de fallback só vale enquanto a espécie desenha o corpo
  genérico. Com corpo próprio V2 instalado (`owns_species_body`: atlas V2 válido
  no diretório do manifest da espécie), `forest_tint` retorna branco — arte
  própria pintada não recebe tinta dupla. Lobo/javali seguem brancos.
- **Arma embutida:** só o Arqueiro da Copa. Corpo próprio instalado →
  `equipment_visual` vazio, inclusive após `sync_npc_equipment_visual()`. O mesmo
  corpo fora do diretório da espécie segue a regra de caminho exato (arco
  dinâmico), como antes.
- **Troca de espécie:** `configure_occurrence` já cria um `CharacterAnimation`
  novo; corpo, projeção e tinta são todos derivados de `mob_base_id` + caminho
  do atlas, logo nada herda. Restore frio: atlas/projeção vêm do snapshot
  existente; uma ocorrência nova reconstrói pelo `mob_base_id`.
- **Ponto de teste:** `E08PilotVisual.set_manifest_override_for_tests(visual_id,
  path)` (variável estática, vazia no jogo, `""` limpa). Escolhido em vez de um
  parâmetro porque instalação, `sync_npc_equipment_visual` e `forest_tint`
  precisam resolver o mesmo caminho; nada é escrito em `assets/`.

## Testes

Todas via `tools/e08_p5_fixture.ps1` (motor 4.7.2 padrão), evidências em
`.godot/verification/p5/`:

- `A1_sol_species_verify_a1_verify3` (após `..._sync_a1_sync3`): novo
  `e08_species_presentation_test` — **147 checks, 0 falhas**.
- `A1_sol_species_verify_a1_reg2_verify1` (após `..._sync_a1_reg2_sync1`),
  9/9 passos aprovados: species presentation 147/0; e08_directional_npcs 1292/0;
  e08_presentation 2204/0; e08_characters 1350/0; e06_tx_mob 27/0;
  e06_rx_mob_ai 4/0; e07_f3_snapshot 52/0; e07_f3_continuation 2743/0
  (30 cenários); e07_f3_mob_state 372/0 (4 cenários).
- `e08_pilot_test`: em `A1_sol_species_verify_a1_reg_verify2` … `reg_verify6`
  rodou **191 checks, 2 falhas**, ambas de áudio do pacote A2
  (`production WAV valid` e `audible non-clipped PCM` de
  `assets/audio/e08/ambience_forest.wav`, em edição pela Terra). As checagens de
  lobo/javali (atlas próprio, morte, restore, ocorrência após retomada) passaram.
  Nova tentativa `A1_sol_species_verify_a1_pilot_verify1` expirou em 120 s sem
  saída, com o áudio da A2 ainda em edição; código A1 idêntico ao das execuções
  anteriores. **Pendente:** repetir `e08_pilot_test` quando A2 estabilizar.

Cobertura do teste novo: `ENTRIES` somente leitura e cópias desacopladas
(`ids`, `entry`); ids = exatamente as espécies da população da fase
`forest_sanctuary` e `MobDefinition` reais; `has_species_presentation`
verdadeiro para as 5 e falso para demo/test/pilot/vazio; lobo/javali com caminho
V2 inalterado e V1 completo sob manifest ausente/de outro kind; três espécies
com manifest ausente (override explícito e o padrão real) → corpo genérico
exato, sem projeção, tinta legada, instalação no-op; unidades válidas
(fixture `e08_species` para o Espreitador, instalada no lugar preservando o
relógio; `npc_archer_unarmed` para o Arqueiro da Copa; `e08_enemies/beast_master`
para o Guardião) sem tinta; arma embutida → `equipment_visual` vazio mesmo após
resync, e controle fora do diretório da espécie volta a ter arco; inválidos
(kind divergente, registro de textura inválido, manifest forçado negativo) →
genérico completo; troca de espécie limpa corpo, arma e tinta; reconstrução
fria por `configure_occurrence` e captura/restauração de snapshot (caches
limpos) com descritor e tinta idênticos.

## Falhas encontradas

- A primeira `import` (`A1_sol_species_import_a1_import1`) falhou por erro de
  script de `main.gd`/`forest_ambience_layer.gd` (A2 em andamento); o
  `body.png.import` da fixture já tinha sido gerado no fixture (mesmos
  `[params]` do original `warrior`) e foi copiado de volta.
- Várias tentativas de sync/verify colidiram com edições concorrentes da A2
  (`Source/fixture mismatch`); repetidas com nomes novos de evidência.
- Nenhuma falha própria da A1: o teste novo passou na primeira execução.

## Limitações

- Um manifest futuro de `e08_forest_canopy_archer` com `actor_kind: archer`
  precisa trazer também `weaponless` (regra do carregador para identidades de
  jogador); só `body` é recusado como `missing_weaponless_body` → fallback genérico.
- Se um manifest de espécie ficar inválido *depois* de instalado num ator vivo,
  `install_forest_atlas` não desinstala o corpo; a recuperação existente de
  `CharacterAnimation` (V1 completo do kind) cobre só pacotes que deixam de validar
  em processo novo. Recriar pelo `configure_occurrence` resolve.
- `forest_tint` resolve o diretório da espécie a cada desenho (três espécies,
  operações de string baratas); não foi medido em cena cheia.
- `tests/e08_directional_npcs_test.gd` e `e08_pilot_test.gd` não foram alterados:
  as expectativas antigas continuam corretas com o catálogo.
- Probes em `tools/` (fora do pacote) ainda citam a lista antiga localmente; não
  afetam o runtime.
