# E10a T5 — recibo do módulo da base Acólito (`acolyte`)

Papel: Terra (Claude Sonnet 5.5, esforço alto). Contrato curto com números e as cinco perguntas:
[t5_contract.md](t5_contract.md). Contrato do épico: [e10a_contract.md](../e10a_contract.md) §4 e §4.1.
APIs usadas: [t1_base_seam_api.md](t1_base_seam_api.md) e [t4_madness_api.md](t4_madness_api.md). O recibo
do Sacerdote ([t6_delivery.md](t6_delivery.md)) foi o modelo de módulo pronto.

## Base e checkout

| Item | Valor |
|---|---|
| SHA-base | `0f7d22ea4bf0df1cbdc8a6aca0fbcf3f60d6a1f0` (`git log -1` depois do `git merge --ff-only claude/e10a-candidato`; terceira composição da T13: T1, T2, T3, T4 e T6, mais a ponta da arquitetura `2aa10bf6`) |
| T6 na base | **sim**: `ce629e74` é ancestral (`git merge-base --is-ancestor`); o merge `caa13976` a compôs |
| Partida da worktree | `master` = `7795f56d`, levada ao candidato por fast-forward (sem merge da branch de arquitetura) |
| Branch | `claude/upbeat-chaum-bbbb8f` |
| Checkout | `C:\Users\João Pedro\Documents\ChatGPT\RagRPG\.claude\worktrees\upbeat-chaum-bbbb8f` |
| Commit entregue | o commit que contém este recibo (ponta da branch) |
| Engine | `Godot_v4.7.2-stable_win64.exe` (A7), 4.7.2.stable.official.ed1daf0bf, `-GodotPath`; `editor_import` com `-CheckTimeoutSeconds 300` (a primeira rodada estourou, a segunda passou), depois `e07_f1_import_test` (`source_manifest_sha256=ef090b9ea7599b5c46bc4cb34c1105461d6029560ea5492725b776dea6f82e52`), regenerado uma vez depois da última edição de código |

Sem push, sem `master`, sem tocar em `codex/playtest` nem no save pessoal. Sem worktree extra. Perfis e
saves só de fixture isolada. Os `.import` reescritos pelo editor e os `.gd.uid` de `docs/map_editor/**`
ficaram fora do commit.

## Entregue

Arquivos, todos dentro do dono exclusivo (mais os checks da A11):

- `docs/epics/e10a/t5_contract.md` (antes do código): números por rank das 8 skills, as cinco perguntas,
  estado/snapshot e efeitos reservados.
- `scripts/classes/bases/acolyte/acolyte_base.gd` (`ready_for_play() = true`; substitui o esqueleto da T1) e
  `snapshot_manifest.json` (revisão 2, 20 campos).
- `tests/classes/acolyte/acolyte_base_test.gd` e `acolyte_boss_combat_test.gd` (com os `.uid`).
- `docs/epics/e10a/t5_delivery.md` (este recibo).
- Checks da A11 em `tests/e10a/base_seam_test.gd`, `tests/e08_feedback_recipe_test.gd` e
  `tests/e09/kit_seam_test.gd`. O `tests/e05_evolution_catalog_test.gd` **não precisou de edição**: com o
  filtro da A10.4, a base pronta deixa o Sacerdote entrar na ordem esperada e o teste passa (96 checks).

Não editei `scripts/systems/**`, `scripts/classes/{priest,cultist}/**`, a UI nem arquivos da T1.

### As 8 skills (`acolyte_*`)

| Skill | Como |
|---|---|
| `acolyte_punishing_light` | alvo único, projétil mágico (`kit_emit_projectile`), `light`, pode crítico; alcance 300; MATQ × 1,40–2,20 |
| `acolyte_prayer` | própria, cura em 4 pulsos de 1 s (16–32% do HP máx. no total) por `heal_player`, fonte `acolyte_prayer`; recasta renova |
| `acolyte_votive_shield` | própria, barreira de 5 s (`grant_shield`), capacidade `personal_shield_capacity(30–78, stats)` × Fé Protetora; o que sobra some ao fim do prazo, só se ainda for dela |
| `acolyte_shadow_seal` | alvo único, `shadow`: marca de 6 s em `ActorMarks`, `add_accuracy_source` (C1.7, −20 a −36%), DoT de sombra de um pulso por segundo (pedido secundário guardado, `scheduled_tick()`), Loucura 18–26 (T4) |
| `acolyte_disturbing_whisper` | alvo único (a mira dá a direção), `shadow`: cone curto de semiângulo 50° e alcance 150–190; Loucura 24–40 a cada inimigo do cone (chefe incluído); empurra os comuns 45–85 (plano e mundo) e **nunca o chefe**; sem dano |
| `acolyte_eldritch_vision` | própria: +40 a +120 no alcance do ataque básico por 6–10 s; carga que dobra a Loucura do próximo Selo ou Sussurro |
| `acolyte_devotion` | passiva: lê o `context.element` de todo commit (da base pelo `on_cast_confirmed`, da evolução pelo `on_base_skill_committed`); `light` seguido de `shadow` em até 8 s (ou o contrário) reforça a MATQ da **skill seguinte** em +10/15/20%, por fonte temporária (`temporary_stat_sources`); alternar sempre mantém. Sem lista fixa |
| `acolyte_protective_faith` | passiva: toda cura reportada rende uma cura extra de +10/15/20% (fonte `acolyte_faith`, que nem ela nem a fonte do bônus do Santuário multiplicam de novo), e o Escudo Votivo +10/15/20% |

Pré-requisitos fechados nos dados do módulo (rank ≥ 1): Escudo Votivo pede Prece; Selo Sombrio pede Luz
Punitiva; Sussurro pede Selo Sombrio; Visão Eldritch pede Sussurro; Devoção pede Luz Punitiva e Selo
Sombrio; Fé Protetora pede Escudo Votivo. Nível de job 1; sem rank grátis. As duas builds do Sacerdote da T6
gastam seus 19 pontos de base com legalidade confirmada sobre a base real (teste).

Também: atributos INT 8, VIT 7, DEX 5, AGI 4, STR 3, LUK 3; ataque básico mágico, alcance 220, poder 1,0;
skills iniciais Luz Punitiva e Prece; passiva de partida Fé Protetora; sem mobilidade.

### Loucura (T4)

O módulo guarda `madness := MadnessAuthority.new()` (`MadnessAuthority.of(player)` o encontra) e repassa
`on_attach` (`configure` com `stat_source_id = acolyte_ecstasy`), `on_tick`, `on_death`, `on_build_changed` e
`snapshot_compact_blocker`. **Não** repassa `temporary_stat_sources` do Êxtase, `skill_cost` nem
`before_hit_mitigation` (só o Cultista, T7): o Êxtase fica desligado e um teste prova que a base não o
publica. Eventos por `MadnessHelpers.cast_event`, um por cast e por alvo. O Delírio acontece na base só
devagar: com Visão Eldritch carregada, Sussurro (R5: 80) e Selo (R5: 26) chegam a 100; no R1 a mesma
sequência para em 66 (teste), e a Loucura espera 4 s e decai 20 por segundo. O chefe, com a mesma sequência,
entra em Desorientação sem ser empurrado nem redirecionado.

### Efeitos em código e IDs de flipbook reservados

`acolyte_light_bolt` (Luz Punitiva, `impact`), `acolyte_prayer_glow` (Prece, `effect_start`),
`acolyte_votive_ward` (Escudo Votivo, `effect_start`), `acolyte_seal_mark` (Selo Sombrio, `effect_start`),
`acolyte_whisper_wave` (Sussurro, `effect_start`) e `acolyte_vision_eye` (Visão Eldritch, `effect_start`).
Os seis desenhos passam pelo `_draw()` real (teste). Receitas: Luz Punitiva `projectile`+`light`; Prece e
Escudo Votivo `buff`+`light`; Selo Sombrio `buff`+`shadow` periódico; Sussurro `area`+`shadow`; Visão
Eldritch `buff`+`arcane`; passivas `buff` sem evento; ataque básico `projectile`+`light`. Textos pt-BR de
efeito, combo, mecânica e tooltip por rank (`rank_tooltip`).

## Validação

`tools/verify.ps1 -SkipEditorImport -F1Fixture -CheckTimeoutSeconds 300 -Test <nome>`, um teste por
chamada, depois da importação completa e do `e07_f1_import_test` regenerado, todos sobre o código desta
entrega. O sha256 é o da saída do `verify.ps1` de cada teste. Saídas completas ficaram em
`.godot/t5_evidence/final/` (ignorada pelo Git).

| Teste | Resultado | sha256 da saída |
|---|---|---|
| `acolyte_base_test` | 304 checks, 0 falhas | `C6ACB6E5AFDCEF3BFCB70AB14EF45758A9542D10C0D92D403F104837F7485FB2` |
| `acolyte_boss_combat_test` | 275 checks, 0 falhas (19 jobs) | `7471DC5ADFBEEA150625A10EA6477711B98D6380B6F08867EC87CC06D9B96BB9` |
| `base_seam_test` | 172 checks, 0 falhas | `253C1B9F235157BA723685FF48BE6AD3BC2BCF9D6983762946F30542644ADCFF` |
| `enemy_target_test` | 88 checks, 0 falhas | `0009978985B469D67CE261A12A03FF9A0FCC308527D88F949BBEFF6590AAE2CB` |
| `madness_test` | 276 checks, 0 falhas | `36F823D2413F594E3017ADF02361C344560654C4BB585AEC43626D4B1FC5A4C2` |
| `kit_seam_test` | 276 checks, 0 falhas | `BAC8432E84C4804CC3C3C74938DF0BA8B977FFDC9715BA1D5A552FAE879519DD` |
| `kit_seam_hooks_v2_test` | 38 checks, 0 falhas | `4BEF15DD7C28979A0F7D3C493C7B6377759AF1D0F0784C49695D17CE344722C0` |
| `kit_seam_hooks_v3_test` | 63 checks, 0 falhas | `FCBB72D667C3F221A64327E36E2E9F110686A048F2A8BDC9A86E0AD0272C8B8A` |
| `sanctuary_test` | 155 checks, 0 falhas | `67CFCB001DB52D0BE1E45B8B9FB27958D17657AD2DC4D2517B2ED07F6FAC73C8` |
| `e05_evolution_catalog_test` | PASS, 96 checks | `4736DE295189C2BFE0AC039B08CC39D7C93762123D6554AB1EDE630A69FB38D2` |
| `e08_feedback_recipe_test` | PASS, 1385 checks | `00D71E5D091D9E28955085E91EBFC629EBDD8433452425FA769C589CBEA09FC9` |
| `ui_evolution_test` | 97 checks, 0 falhas | `19BDC906A16CDEE71B0D377ED208FBF0931547B685AE121DBE62102F0943C4DF` |
| `e05_identity_boundary_test` | PASS, 18 checks | `CFEB9F97FFFD2E91866677353EDC88184E99CF16EC3F06D6141016BCED302E99` |
| `e06_skill_dependencies_test` | 228 checks, 0 falhas | `A442C3C444E14BABC2DB1046E3CF834ED330E02C62C7F9EF63C32940D36A1AEC` |
| `e06_all_skill_migration_test` | PASS, 36 checks | `2D65D114423BF5AB96AC706E742313F5A447743DCB2D33D66B5AFAE17A2C90A9` |
| `skill_allocation_test` | 44 checks, 0 falhas | `F7C2022811E90D94E3CC682A80EFBA8D232EFE507BFFD55BA8A9E7107C29A00E` |
| `e06_icon_bar_test` | 24 checks, 0 falhas | `24D09405B907F09FAA3B35A86480E564FB1B6F824B6AB4A33E7EFFE6D3239A8C` |
| `priest_kit_test` | 220 checks, 0 falhas | `F3B78EA099EC94563FE76B8D4D86040C43600FFDB7A86FC2830DFCA1301E1F9F` |
| `priest_boss_combat_test` | 32 checks, 0 falhas | `CAE5FBCDAACD4FA315C52A1B4AE76545CEFF8EEF91C73BAAC63B378B4109E9EE` |
| `sp_ac_kit_test` / `sp_ac_boss_combat_test` | 170 / 25 | `673B1A4E6E36B32E30E60A2D0DC42FD2CEEFFCE6FF4FAFAB64334B2E87814629` / `A80DD751DCCC08875F8FDC8DAC2DECBEEBA3D913A2116BFD82644E6777A16F37` |
| `mg_ac_kit_test` / `mg_ac_boss_combat_test` | 177 / 29 | `3794563B300F1619AC854736CE656CDAAB6A2ABCB6FEB465AAD210C0C962D5BB` / `F979AFDCB1542DC5AA7EFA870FE396F066481A5BC5A804A26C201C2058088EA8` |
| `sp_la_kit_test` / `sp_la_boss_combat_test` | 217 / 31 | `BBB06D9A797EB53BAD4B0E72BD170924EDB16933C9EC07E080ED4A12F90E35C9` / `CFD74D5F11FE3BA16729242AA8B891431B08A7BCA8279E0B2E3F3F37619D1DC0` |
| `mg_la_kit_test` / `mg_la_boss_combat_test` | 231 / 33 | `599DECCEEF136F1A30A4E2F08E66BB4198E3BB1E3360CEC91575F97D003B3353` / `3440C19C16556150C26F4B510907572A14A4690551AA174E727717745205259F` |
| `equipment_items_test` | 244 checks, 0 falhas | `F2695D376B95D23FC5C04BF617B7175E0C3DC30A425A9444C3BF47E9958F2D2E` |
| `persistent_state_test` | PASS, 33 checks | `8E80B1A0048FAF208A8FB034256D663D2FE3B72EFE970206255FEF40940B529D` |
| `stat_threshold_rules_test` | PASS, 28090 checks | `4874F403B9C9CB14B2278E63A8C7C82470A8F2CEC98F2D754C2492BBCE2B7ADB` |
| `e06_admin_profile_test` | PASS, 1106 checks | `2019035977F0C8A4EA1345971EA93E031D3500091BB8D69EAD8AD5B8E7CD7237` |
| `e06_publication_test` | 1162 checks, 0 falhas | `BABDFC759A6B57CDC8D6DCDFC9FBE77DB0902856FC9280681EE733C0F7E27708` |
| `e06_migration_test` | 147 checks, 0 falhas | `59ACCF161784A20DD9A7E06F85B1CAFECDA052C7AA9268DEF2B79F612875E716` |
| `e07_f5_death_kits_test` | 191 checks, 0 falhas | `B848D5E0D020BB198965B461592B4BFB3AAD951A543C7E6295912415F96200CC` |
| `e02_character_menu_test` | PASS, 26 checks | `C75096DB83AF7354CC53D1BD3CDD543DEBC5B9A027FC263633444B512AA88537` |
| `e05_evolution_menu_integration_test` | PASS, 25 checks | `FC98C54FEE9D64E4C667E06B22EF6AFD3032A80BC7CC5F666287E7CA5F4ECC11` |
| `profile_facade_test` | PASS, 52 checks | `1F57D57BF74A3147B3FA17E11B9D90F9A6EF36E15F4DDCE183AD4502A895FCDB` |
| `e06_ui_menu_test` | 117 checks, 0 falhas | `E7DCD8C3FAC70CEC32A46637E95D2D39CC0157F1E79DF65EED0EE70C5DCD30A9` |
| `menu_tabs_test` | PASS, 40 checks | `B531352131E66BD450013EC1726A0D28AA65627AE8F3334B87D18F952D6D1D0A` |
| `e08_feedback_vfx_test` | 683 checks, 0 falhas | `071B761969AA062D1104A5C6B5544C474450B1564B35A8D989C5604D313C1A0D` |

Busca por `SCRIPT ERROR`, `still in use`, `Parse Error` e `FAIL:` (caixa exata) nas 40 saídas: **0 ocorrências**.
Esta não é a suíte completa (352 de 354 passos continuam por conta da T13): rodei o lote pedido pela tarefa
mais os testes que citam base, identidade ou catálogo de criação (grep), porque ligar a base mexe nesses.

### Testes novos, em resumo

- **`acolyte_base_test` (304):** catálogo e textos pt-BR, atributos, ataque, iniciais, elementos
  (`light`/`shadow`), pré-requisitos (módulo, `SkillDependencyRules`, legalidade de compras e das builds do
  Sacerdote sobre a base real), os seis desenhos no `_draw()` real, cada skill com números de R1 e R5 (SP,
  recarga, dano, cura, escudo, marca, Loucura, cone, empurrão), o chefe que fica onde está, a carga dobrada
  da Visão, o Delírio lento na base, a Devoção (par, janela, elemento neutro, mesma sombra, expiração,
  sem a passiva, e o par pela skill do Sacerdote), Fé Protetora sem recursão (também dentro do Santuário),
  fiação da autoridade (`of()`, Êxtase desligado), troca de build, morte, pausa, os dois formatos de snapshot
  (todo campo do módulo está no fragmento), as destinações da evolução e o caminho do mundo
  (`resolve_cast` com cone, empurrão e chefe no mundo da fixture F1).
- **`acolyte_boss_combat_test` (275):** um combate por nível de job de 1 a 19 contra o Mestre das Feras
  (`test_beast_master`, `rare`, origem da fase do roteiro que casa com o job: níveis 2, 4, 6, 9, 12 e 15), sem
  adds e sem augment. A alocação dos pontos de base (J − 1) segue uma ordem fixa legal (confirmada pelo
  `ProfileCatalog`) e os atributos, uma alocação legal do nível de base J. Em todos os 19 o Acólito vence o
  mestre e sobrevive (job 1 só com o ataque básico: 27,6 s, 56 de 170 HP; job 19: 17,2 s, 584 de 624 HP);
  Luz Punitiva é lançada do job 2, Selo Sombrio e Sussurro do job 8, Visão Eldritch do job 14; o mestre
  acumula Loucura da base (72 no job 19).
- **Sacerdote e Cultista como destinos:** `_check_evolution_destinations` prova que as destinações do Acólito
  são exatamente as puras prontas, na ordem do registro (hoje `[priest]`; com a T7 será `[priest, cultist]`
  sem editar o teste), com origem e ramo vindos do registro. O Cultista ainda é esqueleto neste ramo; o
  `base_seam_test` prova que ele fica de fora e que o Sacerdote só sai da oferta com uma base não pronta.

## Ajustes em testes legados (A9, A10, A11; regra A15 do E09)

Ligar a base muda enumerações exatas de outros arquivos. Pela A11, atualizei só esses checks, com número
exato e sem `>=`, sem enfraquecer outro check. Os números são os do **meu ramo**: o Sacerdote (T6) entra, o
Cultista (T7) ainda é esqueleto, e a T13 soma o dele.

| Arquivo | Ajuste | Conta |
|---|---|---|
| `tests/e10a/base_seam_test.gd`, estado de produção | o módulo do Acólito valida **e está pronto**; as 8 skills são **publicadas** pelo catálogo; o catálogo oferece a base na criação; as destinações do Acólito são `[priest]`; os atributos da base são os de D2 | 171 checks (T6) → 172: o que antes afirmava "esqueleto, não pronto" agora afirma o oposto, e **um check novo** |
| `tests/e10a/base_seam_test.gd`, regra C1.3 | a prova "a pura pronta não é oferecida com a base não pronta" perdeu o alvo (a base de produção está pronta). Passou a usar um fixture `UnreadyBase` (estende o `fixture_base` e devolve `ready_for_play() = false`) e, ao limpar o fixture, confirma que o Sacerdote volta a ser oferecido | o invariante C1.3 continua provado, agora contra a base de fixture |
| `tests/e08_feedback_recipe_test.gd`, `_library()` | o laço de bases inclui `acolyte` (antes só as três do E00), porque o catálogo agora publica a biblioteca da base e as puras prontas dela (A10.3) | — |
| `tests/e08_feedback_recipe_test.gd`, contagem de skills publicadas (linha 102) | **20/8 → 31/12** (ativas/passivas) | 20/8 dos quatro kits do E09, **+ 6/2 da base Acólito + 5/2 do Sacerdote**; o Cultista (5/2) fica para a T13: 36/14 na soma final |
| `tests/e08_feedback_recipe_test.gd`, `_expected_kit_skills()` | a tabela esperada passou a incluir a biblioteca das bases registradas disponíveis (6 ativas e 2 passivas do Acólito), por `ClassBaseRegistry.SKILL_CATEGORIES`; o filtro de base disponível (A10.2) **ficou** e agora deixa o Sacerdote entrar | a igualdade "o catálogo publica exatamente a tabela" continua exata |
| `tests/e08_feedback_recipe_test.gd`, `KIT_AUDIO_GAPS` | acrescentei `acolyte_shadow_seal/impact` e `priest_sanctuary/impact`: duas lacunas **registradas** de deixa de áudio (D5 e C1.8: sem som novo), da mesma família do `paladin_oath/impact` (queimadura periódica cai em `world.impact`). Só aparecem agora porque as skills passam a ser publicadas | a lista exata passa de 4 para 6; o check "as lacunas são exatamente a lista" continua exato |
| `tests/e09/kit_seam_test.gd` | com a base pronta, o Sacerdote entra no catálogo: `evolution_definitions().size()` **12 → 13** (zero prontos), **14 → 15** (alguns) e **16 → 17** (quatro prontos) | +1 em cada, o Sacerdote; as listas de destinos das três origens do E00 não mudaram |
| `tests/e05_evolution_catalog_test.gd` | **nenhum ajuste**: a ordem esperada vem de `_ready_kit_ids()`, que com o filtro da A10.4 passa a incluir o Sacerdote; o teste passa com 96 checks (conferido) | — |

Decisão sobre a prece: a receita da Prece era `heal` + periódica; periódica faria `acolyte_prayer/impact`
cair em mais uma lacuna de áudio, e `heal` já é silenciosa (`thaumaturge_healing_refraction/heal`). Como a
Prece não gera golpe, usei `buff` + `light` no commit: sem lacuna nova e com a deixa de família × físico.

## Decisões dentro do contrato (para a arquitetura conferir)

- **Sussurro é de alvo único**, com a mira dando a direção do cone, em vez de `SELF` com `facing` incerto:
  assim o cone tem sempre uma direção real e o teste exercita os dois caminhos. O alcance de colocação do
  alvo é o do cone (150–190).
- **Luz Punitiva "fere o primeiro inimigo da linha"** é o projétil mágico mirado no alvo escolhido (o
  produtor existente de projétil), sem colisão em linha própria.
- **Visão Eldritch** aumenta o alcance do **ataque básico**; não há gancho para alterar o alcance de skills
  de kit, então Luz Punitiva e o Selo mantêm 300.
- **Fé Protetora** cobre qualquer cura reportada (gancho `on_heal`) e o Escudo Votivo; **não** cobre a
  barreira da Égide do Sacerdote nem outras barreiras de fora, porque a costura não tem gancho de barreira
  recebida. Se a arquitetura quiser, é um gancho novo na T1.
- **Devoção:** a skill que forma o par não é reforçada; só a seguinte. O reforço é uma fonte temporária de
  MATQ (vale para a Luz Punitiva, para o Selo e também para as skills da evolução). Alternância contínua
  mantém o reforço.
- **O DoT do Selo não usa o `apply_burn`** do `CombatActor`: perderia a etiqueta `shadow` e desenharia fogo
  no inimigo. É um pedido secundário guardado no módulo e repetido por `scheduled_tick()`, como a
  queimadura do Santuário.
- **Selo e Escudo bloqueiam o corte compacto** (a marca e o debuff ficam no inimigo, e a barreira não tem
  projeção compacta); a Loucura segue a restauração do inimigo (A4).

## Limitações

1. **Combate com HP de substituição.** A espécie `test_beast_master` do catálogo é fraca (192–348 HP): o
   teste a eleva a `600 + 220 × job` (820 no job 1, 4780 no job 19), como o teste do Sacerdote faz com 6000.
   O projétil mágico voa no jogo por `Main._on_mage_projectile_requested`; o teste o substitui por um impacto
   imediato. É prova de laço, não de balanceamento.
2. **O Delírio no combate integrado não acontece:** o mestre chega a 72 de Loucura (job 19), porque o
   Sussurro e o Selo ficam em recarga entre os ciclos. O Delírio na base está provado nos testes de invariante
   (R5 com a Visão), não no combate de 19 jobs.
3. **Só o caminho do mapa plano usa `use_kit_skill`.** O mundo da expedição está provado por `resolve_cast`
   direto com um cast montado à mão (cone, empurrão, chefe parado e marca do Selo), não pelo comando de
   skill do mundo.
4. **Sem captura nativa.** Os seis desenhos em código passam pelo `_draw()` real, mas a tarefa não tem parte
   visual validada por captura. Passivas não emitem evento; o corpo usa a reserva (`mage`) até a T8.
5. **Os números são ajuste de playtest.** Em particular o Delírio lento da base, o reforço da Devoção e a
   Prece (16–32% do HP máximo em 4 s, recarga 10 s).
6. **Não rodei a suíte completa** (a T13 faz). O passo 148 (`e05_sentinel_net_test`, A7) e o 255 ficam como
   a arquitetura os classificou.
7. **Composição com a T7:** o Cultista deve ler `MadnessAuthority.of(player)` e ligar o Êxtase pela passiva
   (`madness.set_ecstasy_enabled`). Os números da T7 para a T13: contagem de skills publicadas 36/14,
   `evolution_definitions().size()` 14/16/18, e as lacunas de áudio de skills periódicas do Cultista, se houver.

## Próximo passo

T13 compõe esta entrega em `claude/e10a-candidato` e soma a do Cultista nas contas acima. A T10 (criação,
escolha de evolução e onboarding do Acólito, o `has_kit()` que agora vale só com a origem) parte do candidato
depois desta. T11 (augments do Acólito) e T12 (o `hud_state` da base passa à T12; a Loucura em `target_marks`
vem de `MadnessAuthority.describe()`) dependem dela.
