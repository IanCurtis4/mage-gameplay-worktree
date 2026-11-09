# E08 P5 — B2b: materiais, variantes de props e republicação da floresta

Sol (Opus), 8/11/2026. Checkout `.tools/map-editor-m5`, branch `codex/e08`, base
fd32d346. Decisões humanas de 8/11 ([contrato](e08_p5_contract.md), seção B1/B2a);
posse em [`e08_p5_files.json`](e08_p5_files.json) `packages.B2b_sol_world`. Sem
commit/push/merge; save e checkout habitual intocados. Aprovação técnica não é aceite
visual: o candidato P5 continua aguardando o usuário.

## O que mudou

| Área | Arquivos |
|---|---|
| Materiais | `assets/art/map_authoring/{grass,earth,sand}_tile_v2.png` (+`.import`, mipmaps como os antigos); `terrain_material.gd` (`terrain_material_v3`, caminhos v2; `stone` = `cliff_tile.png` inalterado) |
| Props | `assets/art/map_authoring/props/{birch_tree,fern_cluster,wildflower_patch,mushroom_ring,fallen_log}.png` (+`.import`); `prop_catalog.json` revisão 2→3, 6→11 definições |
| Proveniência | `materials_provenance.json` e `props/provenance.json`: entradas novas com sha256, dimensões, `source` (staging), `generator` "Codex built-in imagegen", `request` (briefing §2/§3), `prompt` null, `prompt_note`, `status` `generated_project_art_prompt_unrecorded`. Bytes copiados sem alteração. Nenhum prompt inventado. |
| Mapas | `forest_{terraces,valleys,lair}.{source,map,population,patrol}.json`; novos `forest_terraces.f369e42baa7b`, `forest_valleys.71c5d0f5c124`, `forest_lair.3d9af1202829` (`.rpp` + `.navproof`) |
| Consequência mecânica | `sanctuary_woods.f7853673673b.rpp`, `representative.rpp` recompilados das fontes intactas; `release_packages.json`; `asset_manifest.json` (gerado por `tools/map_editor_assets/build_manifest.gd`) |
| Ferramentas | `tools/e08_p5_world_publish.gd` (troca de variantes + fluxo de autoria + bytes de publicação, saída só na evidência), `tools/e08_p5_republish_shim.gd` (roda `republish.gd --file` pelo wrapper), `tools/e08_p5_world_publish_probe.gd` (capturas) |
| Testes | novo `tests/e08_p5_world_republish_test.gd` (63 checks); pinos atualizados: `map_editor_biome_props_test` (6→11 definições, revisão 2→3 do catálogo), `map_editor_objects_test` (inventário de materiais aponta para `*_tile_v2`) |

Texturas antigas (`grass/earth/sand_tile.png`) continuam no disco e no manifesto de
assets (pacotes antigos imutáveis as nomeiam); a revisão nova usa nomes versionados
e `REVISION` `terrain_material_v3`, sem sobrescrever bytes. Pedra nova rejeitada.

## Catálogo

- `birch_tree` "Bétula": cópia do carvalho em corpo e regras (`body_box_xyz`
  [-18,0,-18,36,96,36], `footprint_radius` 26, inclinação 20°, rotações, capacidades
  body/attack_los/camera_occlusion), sprite próprio, pivô **(0,52; 0,94)**, altura 226.
  O perfil alfa das raízes da bétula coincide com o do carvalho (largura máxima a
  0,90, estreitamento a 0,96/0,98), então o pivô geométrico equivalente é o do
  carvalho. A alternativa B2a (0,515/0,977, 228,5) foi renderizada lado a lado
  (`*_birch_z160_noui_alt_pivot977.png`): eleva a bétula ~8 u em relação aos
  carvalhos vizinhos. Escolhido o pivô coerente com o carvalho.
- Decorativos (cópia do arbusto: sem corpo/LoS/oclusão, `footprint_radius` 4,
  inclinação 45°, mesmas rotações): `fern_cluster` (0,49; 0,80; 46),
  `wildflower_patch` (0,50; 0,70; 46), `mushroom_ring` (0,49; 0,73; 46),
  `fallen_log` (0,49; 0,76; 32,5 = escala de pixel do arbusto). Pivô no centro da
  base de contato medida no alfa.

## Regra de colocação (determinística, sem adicionar/remover/mover)

Chave de ordem: `sha256(sal + placement_id)` do id na peça; cotas por arredondamento
meio-para-cima.
- Bétula: primeiros 25% dos carvalhos (sal `e08_p5_b2b/birch/`).
- Decorativos: primeiros 40% dos arbustos (sal `e08_p5_b2b/decor/`), divididos em
  samambaia 40%, flores 30%, tronco 15% e cogumelos o resto. Tronco (≈81 u) e
  canteiro de flores (≈66 u), que deitam no chão, só vão para sítio plano (altura num
  círculo de 48 u, 16 amostras, dentro de 8 u do centro): tronco e depois flores pegam
  os primeiros candidatos planos na ordem; samambaia e cogumelos preenchem o resto na
  ordem; cota plana sem sítios vira samambaia (não ocorreu). Arbustos seguem
  dominantes (60%).

| Mapa | carvalho→bétula | arbusto→samambaia/flores/tronco/cogumelos | restam carvalho / arbusto / rocha |
|---|---|---|---|
| terraces | 132→33 | 90→14/11/5/6 | 99 / 54 / 16 |
| valleys | 48→12 | 40→6/5/2/3 | 36 / 24 / 14 |
| lair | 10→3 | 14→2/2/1/1 | 7 / 8 / 0 |

## Republicação e prova de igualdade

Fluxo: troca de variantes na peça → `carry_forward.piece_into_map` (compila o mapa) →
encontros com o mapa novo, **rebind identidade** (mesmo layout de instâncias,
verificado), `PopulationCompiler.regenerate` mantendo todos os slots sem sortear +
compile → patrulha com os encontros novos e `PatrolCompiler.compile` → bytes `RPP1`
idênticos ao formato de `MapRelease.publish`/`PatrolStore.publish`, gravados na
evidência e copiados; registro pelo mesmo formato de `publish`. Navproof por
`MapRelease.bake_preparation`. O carry canônico `map_into_population` foi executado
(evidência `population2`) e **não** foi usado: com mapa idêntico ele regrava todo
ponto autoral como float32 (19.4148→19.41477…) e, em valleys, reamarrou 7 âncoras
situadas na borda exata entre células da grade à célula vizinha (`…_80_*`→`…_64_*`),
mudança sem causa geométrica. O rebind identidade preserva os literais.

| Mapa | pacote antigo → novo | fonte patrol antiga → nova |
|---|---|---|
| terraces | d9d52701a7a4 → f369e42baa7b | 832634d0… → 4f3610a5… |
| valleys | 2faa15085074 → 71c5d0f5c124 | cff11918… → 19626e1a… |
| lair | c19cad53def8 → 3d9af1202829 | b484d5e4… → 73eaa5c6… |
| sanctuary_woods | 41a8e11a6c70 → f7853673673b | 58df5d63… (igual) |
| representative.rpp | sha do arquivo 2fe63793… → 18d0cdcf… (payload) | fonte intacta |

O que muda e por quê (provado por `e08_p5_world_republish_test`, todos os mapas):
- Peça: só `definition_id` das 69/28/9 colocações trocadas e as dependências de
  prop novas → hash da peça (terraces 60968f04→0f39d871, valleys b27a7f05→ef50206b,
  lair 0f5b4ed4→c3021f78) → nome da parte composta `piece_<hash>` e fonte do mapa
  (terraces 0c15d9e2→d4dd3af6, valleys 5d182c10→004d0da4, lair e5ca0edc→17f0ca7c).
- Encontros: só `map` embutido e `plan_hash` (a receita cobre o mapa; terraces
  59f6cbe4→4b0d8824, valleys fa13c4d6→b47c38f4, lair ee97d631→2e57243a); slots,
  pincéis, entrada, interações e exclusões byte-iguais (62/59/5 slots mantidos, nenhum
  sorteado). Patrulha: só `population` (rotas idênticas).
- Pacote: dependências mudam **apenas** em texturas grass/earth/sand (antigas→v2),
  `prop_catalog.json` e sprites novos; cliff/água/shaders/bordas iguais.
- Igual depois de renomear só o id da parte: manifesto da patrulha (estágio,
  superfícies, slots, rotas, objetivos, portais, testemunhas), manifesto/regras/perfil
  dos encontros, `catalog_hash`/`policy_hash`, manifesto do mapa, barreiras, bordas e
  todo o pacote do mapa fora `definition_id/definition` dos objetos trocados.
- Objetos: mesmos ids, posições, rotações, superfícies e `body_volume` (bétula =
  volume do carvalho; decorativos sem volume, como o arbusto).
- Navproof: testemunhas (raízes, nós, caminhos, alvos) idênticas; só as chaves
  (hash do estágio, que nomeia a parte) e o pino do pacote mudam. Mesmos bytes de
  tamanho (976.772 / 849.200 / 66.708).
- sanctuary_woods e representative: consequência mecânica dos pinos de hash do
  catálogo e dos materiais (todo pacote valida esses hashes; precedente 2d0626a9),
  recompilados por `republish.gd --file` da fonte intacta: mesmo `source_hash`, sem
  tocar fontes nem os quatro `.bak`. Aceite: `sanctuary_source_unchanged_and_loads`,
  `phase_release` 11/11 e `phase_presentation` 10/10 (preparam o Bosque), e
  `representative_release_package_validates`.

## Testes (evidência em `.godot/verification/p5/`)

Registrados no `verify.ps1`, `B2b_sol_world_verify_b2b_verify3` (pacotes finais): e08_pilot 191/0,
e08_species_presentation 172/0, e08_forest_ambience 58/0, e07_f3_snapshot 52/0,
e07_f3_continuation 2743/0, e07_f1_presentation 39/0, map_editor_asset_manifest 7/7.

Não registrados no `verify.ps1` (rodam pelos estágios de
`tools/map_editor_completion/run.ps1`); executados com `-Stage probe -Headless`,
evidência `B2b_sol_world_probe_b2b_<teste>_3`: terrain 102, terrain_scale 46,
biome_props 30, objects 53, cliff 61, forest_species 7, phase_rules 12, phase_release
11, phase_presentation 10, forest_phase 9 (todos ok; contagens = esperadas do run.ps1).
Nativos (`_2`, janela real, renderer padrão do wrapper, não `gl_compatibility` como no
run.ps1): forest_profile 3/3 e forest_play 20/20 (rodada 2: `_1`
3/3 e 20/20).
`map_editor_terrain_ui_test` não foi executado: é teste de plugin do editor
(`TerrainNative`), que injeta o plugin no `project.godot` da fixture; o wrapper não
permite.

Novo invariante: `tests/e08_p5_world_republish_test.gd` — 63/63
(`B2b_sol_world_probe_b2b_republish_test5`, ~50 s, cabe no limite de 120 s do
verify). Precisa de registro no `verify.ps1` pela coordenação.

## Achados visuais (`b2b_visual4_<mapa>`, finais; 1280×720, UI 120%, z50/100/160)

- Grama nova lisa e mais clara; areia quase igual; terra nova vermelho-ferrugem forte
  no caminho (decisão humana consciente); penhascos com `cliff_tile` idênticos.
- Bétula com a mesma escala/assentamento dos carvalhos (raízes no chão); copa clara e
  tronco branco destacam no bosque misto. Decorativos assentam no chão sem flutuar.
- Rodadas 1–2 deixaram tronco e depois flores atravessando bordas de penhasco em
  valleys; a regra de sítio plano corrige (ver falhas).
- Em valleys algumas flores/samambaias ficam atrás de faces de penhasco (vale estreito
  visto por trás de uma crista): posições autorais dos arbustos, mesma oclusão de
  antes; uma samambaia compacta ocupa agora o sítio de borda que tinha flores.
- O HUD a 120% cobre a metade de baixo; as vistas `*_noui` existem só para contato.

## Falhas e correções

- `population1`/`recertify1`: estouro do limite fixo de 300 s do wrapper; a
  coordenação acrescentou `-TimeoutSeconds`.
- `population2`: carry canônico regravou âncoras (ver acima); descartado.
- Rodada 1 (`*_variants1`/`popkeep1`/`patrolkeep1`, pacotes `0e8a8bee2143`,
  `aaf2026f84d9`, `2461e7cebdaf`): tronco de valleys sobre borda de penhasco
  (`b2b_visual2_forest_valleys`). Rodada 2 (`*2`, pacotes `8bf4eebaab9c`,
  `3942c828f669`, `c8a756cc6389`): tronco corrigido, mas um canteiro de flores de
  valleys ainda deitava sobre a borda (`b2b_visual3_forest_valleys`); regra plana
  estendida às flores. Rodada 3 (`lair *3`, `valleys/terraces *4`) é a publicada.
  Os 12 arquivos `.rpp`/`.navproof` das rodadas 1–2 ficaram no disco e no manifesto
  da fixture, **sem referência no registro**: não commitar (a coordenação pode
  apagá-los e ressincronizar). `valleys_variants3` é evidência vazia (tentativa
  recusada pelo wrapper por fonte já copiada).
- `republish_test1`: o teste comparava ids com prefixo de instância e não previa o
  nome da parte; corrigido o teste (não a expectativa de igualdade). `test3`: erro de
  tipagem no teste.

## Limitações

- Aceite visual humano pendente (terra forte, densidade/tamanho dos decorativos).
- `map_editor_library_ui_test` (busca "Árvores" espera só o carvalho; 6 miniaturas)
  e `map_editor_biome_props_ui_test` (6 entradas na paleta) fixam a contagem antiga do
  catálogo e devem falhar; estão fora da posse B2b e não foram executados.
- `scripts/world/expedition_backdrop.gd` (A2) ainda usa `grass_tile.png` antigo para o
  fundo fora do mapa da floresta.
- Release exportado (`map_editor_candidate -Stage Release`) não foi rodado.
