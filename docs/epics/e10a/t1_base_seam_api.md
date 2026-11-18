# E10a T1 — API da costura de base e das primitivas de alvo (C1)

Leitores: T4, T5, T6, T7, T8, T9 e T10. Este documento basta para usar a costura; o
contrato está em [e10a_contract.md](../e10a_contract.md) §2 e o recibo em
[t1_delivery.md](t1_delivery.md). Tudo o que a [API da costura de kits do E09](../e09/t1_kit_seam_api.md)
diz sobre `ClassKit` continua valendo; aqui está só o que muda ou é novo.

## 1. Mapa de arquivos

| Arquivo | Papel | Quem edita |
|---|---|---|
| `scripts/classes/class_base_registry.gd` (`ClassBaseRegistry`) | Registro fechado das bases novas (`acolyte`), IDs da biblioteca, corpo e corpo de reserva | só T1 |
| `scripts/classes/bases/class_base.gd` (`ClassBase extends ClassKit`) | Classe de todo módulo de base: dados de base e os ganchos de `ClassKit` | só T1 |
| `scripts/classes/bases/acolyte/acolyte_base.gd` | Módulo do Acólito (esqueleto vazio, não pronto) | T5 |
| `scripts/classes/bases/acolyte/snapshot_manifest.json` | Fragmento do módulo | T5 |
| `scripts/classes/priest/priest_kit.gd`, `scripts/classes/cultist/cultist_kit.gd` | Kits puros (esqueletos vazios) e fragmentos | T6 e T7 |
| `scripts/classes/class_kit_registry.gd` | Ganha `priest`/`cultist`, ramo por dado, e agrega também os módulos de base | só T1 |
| `scripts/classes/kit_decoy.gd` (`KitDecoy`) | Isca: ator temporário com HP, sem IA | só T1 |
| `scripts/classes/fixture/fixture_base.gd` | Base de fixture dos testes (fora do registro) | só T1 |
| `tests/e10a/base_seam_test.gd`, `tests/e10a/enemy_target_test.gd` | Prova da costura e das primitivas | só T1 |

| Identidade | ID | Origem | Ramo | Afinidade | Corpo | Reserva | Prefixo |
|---|---|---|---|---|---|---|---|
| Acólito | `acolyte` | — | — | — | `acolyte` | `mage` | `acolyte_` |
| Sacerdote | `priest` | `acolyte` | `2-1` | — | `priest` | (base) | `priest_` |
| Cultista | `cultist` | `acolyte` | `2-2` | — | `cultist` | (base) | `cultist_` |

`ClassBaseRegistry.SKILL_IDS[&"acolyte"]` traz as 8 skills da biblioteca na ordem do §1 do
contrato; `SKILL_CATEGORIES` dá seis ativas e duas passivas (Devoção e Fé Protetora).
`ClassKitRegistry.SKILL_IDS[&"priest"|&"cultist"]` traz as 7 de cada pura (jobs 20…37).

## 2. O módulo de base (T5)

Um script `scripts/classes/bases/acolyte/acolyte_base.gd`, `extends ClassBase`. Como um kit,
é módulo de catálogo (métodos de dados puros) e objeto por personagem (`create_runtime()`;
as variáveis do script são estado da run e vão pelo fragmento). Todos os métodos de dados e
ganchos de `ClassKit` valem (skills, passivas, famílias causais, receitas, textos, efeitos,
desenhadores e todos os ganchos de jogador). `kit_id()` devolve `base_id()`, e
`evolution_id` do objeto vale `acolyte`.

### 2.1 Dados próprios de base

| Método | Retorno | Regra validada |
|---|---|---|
| `base_id()` | `StringName` | igual à chave do registro (`base_identity_mismatch`) |
| `ready_for_play()` | `bool` | falso deixa a base fora da criação e as evoluções dela fora do catálogo |
| `display_name()` | `String` pt-BR | vazio cai no nome do registro |
| `initial_attributes()` | `Dictionary[StringName, int]` | os seis IDs, cada um ≥ 1, soma 30 (`base_attributes_invalid`); D2: INT 8, VIT 7, DEX 5, AGI 4, STR 3, LUK 3 |
| `basic_attack()` | `{"delivery", "range", "power"}` | `delivery` em `&"magic"`, `&"precision"`, `&"direct"`; `range` e `power` finitos > 0 (`base_attack_invalid`) |
| `starting_skill_ids()` | `Array[StringName]` | skills da biblioteca (`base_starting_invalid`) |
| `starting_passive_id()` | `StringName` | uma passiva da biblioteca, ou vazio |
| `skill_definitions()` | `Array[SkillDefinition]` | IDs da tabela; `handler_id = KIT`; ranks válidos; categoria da tabela; `element` em `ClassBaseRegistry.BASE_ELEMENTS` (inclui `light` e `shadow`); `tags` só `EffectTags` |
| `learning_entries()` | `Array[Dictionary]` | uma linha por skill definida (abaixo) |

Linha de aprendizado da base (carteira de base, 19 pontos):

```gdscript
{"skill_id": &"acolyte_votive_shield", "category": &"active", "max_purchased_rank": 5,
 "job_level": 1, "prerequisites": {&"acolyte_prayer": 1}}
```

- `category` é `&"active"` ou `&"passive"`, conforme `SKILL_CATEGORIES`;
  `max_purchased_rank` é 5 nas ativas e 3 nas passivas; `free_rank` é sempre 0 (omitir).
- `job_level` é opcional (1 a 19; padrão 1). `prerequisites` cita só skills desta base, rank ≥ 1.
- O `ProfileCatalog` registra as linhas com `BASE_WALLET`; `SkillDependencyRules.requirements_for(id)`
  devolve os pré-requisitos do módulo (o mapa fixo continua para os IDs antigos).

Com `ready_for_play() == true`, o registro exige as 8 skills, atributos, ataque básico, skills
iniciais, texto `effect` e receita para cada skill (`base_incomplete`).

`basic_attack_profile(player)` já vem implementado em `ClassBase` e lê `basic_attack()`: o
módulo de base não precisa sobrescrever. Um kit de evolução que declara o próprio perfil o
substitui (C1.4). `basic_attack_recipe()` dá a linha de feedback do ataque básico (vazio: a
linha do tipo de entrega, magic → Mago).

### 2.2 Onde os dados aparecem

| Consumidor | Como lê a base |
|---|---|
| `IdentityIds.is_base_class(id)` | verdadeiro para as três do E00 e para as registradas |
| `IdentityIds.base_class_ids()` | **continua com as três do E00** (contrato estável) |
| `IdentityIds.registered_base_ids()`, `all_base_ids()`, `is_registered_base(id)` | bases registradas, em ordem do registro |
| `IdentityIds.initial_attributes(id)` | do módulo (vazio enquanto ele não tiver) |
| `ClassCatalog.class_definition(id)` | composta do módulo a cada chamada: nome, atributos, `skill_ids` (iniciais), `passive_id`, `basic_power`, `basic_range` e o campo novo `basic_delivery` (`&"mage"`, `&"precision"` ou `&"direct"`) |
| `ClassCatalog.skill_definition(id)` | skills de base pela agregação de `ClassKitRegistry` (módulo válido) |
| `ProfileCatalog.pilot()` | biblioteca da base só com o módulo pronto (ou fixture); `base_class_is_available(&"acolyte")` exige o módulo pronto e atributos |
| `ClassKitRegistry.skill_owner/skill_definition/passive_modifier_source/feedback_recipe/feedback_recipe_ids/skill_text/vfx_effect/draw_vfx/causal_families` | agregam kits **e** bases (`seam_ids()`, `seam_module(id)`) |
| `FeedbackRecipeCatalog.recipe(&"basic_attack", &"acolyte")` | linha do módulo, ou a do tipo de entrega; um kit puro sem linha própria cai na da base |
| `SkillCopy`, `SkillPresentation.mechanics_of`, `SkillPresentation.job_name(&"", &"acolyte")` | textos e nome do módulo |
| `PlayerActor.base_skill_element(id)` | `SkillDefinition.element` da skill de base |

### 2.3 Disponibilidade e fixtures

- `ClassBaseRegistry.ready_for_play(id)` = módulo existe, declara pronto (ou foi forçado) e
  `validate(id)` passa. Um módulo que se declara pronto com dados inválidos torna o catálogo
  inválido (falha alta, de propósito).
- Fixture: `ClassBaseRegistry.install_fixture(&"acolyte", base)` troca o módulo até
  `ClassKitRegistry.clear_fixtures()` (que limpa as duas); `force_ready_fixture(id)` força a
  disponibilidade de um módulo válido. Ambos sobem `ClassKitRegistry.revision`, então os
  catálogos se recompõem.
- Perfis existentes continuam válidos; a versão do catálogo e o schema de save não mudaram. A
  base nova só cria personagens novos.

## 3. Kits puros (T6, T7)

`priest` e `cultist` são kits comuns da costura do E09 (`extends ClassKit`, mesmas regras de
validação, posições e linhas de aprendizado; a entrada do job 20 sem pré-requisitos). O que muda:

- `ClassKitRegistry.origin(id) == &"acolyte"`, `branch(id)` = `&"2-1"`/`&"2-2"`,
  `affinity(id)` vazio, `is_pure(id)`; `hybrid_ids()` lista as quatro do E09 e `pure_ids()` as
  duas. `ids()` lista as seis.
- `IdentityIds.evolution_origin`, `kit_affinity` e `kit_evolution_ids` leem o registro (sem
  `match` para IDs novos). `ProfileCatalog` cria a evolução com o ramo do registro.
- **Oferta (C1.3):** a evolução entra no catálogo só com o kit pronto **e** a base pronta.
  Override de fixture (`ProfileCatalog.pilot({}, {}, {&"priest": {...}})`) continua forçando.
- Pré-requisitos das linhas do kit podem citar skills da base (elas precisam existir no
  catálogo, ou seja, base pronta).
- `on_base_skill_committed` do kit puro recebe os commits pagos das skills da base (abaixo).

## 4. Dois módulos por jogador (C1.4)

`PlayerActor.origin_kit: ClassKit` é o objeto da base registrada (nulo nas três do E00); ele
fica ligado antes e depois da evolução. `PlayerActor.kit` continua sendo o objeto da evolução.
`configure()` liga primeiro a origem, depois o kit (`attach_origin_kit`/`attach_kit`, cada um
chama `on_attach` uma vez). Testes podem chamar os dois diretamente.

| Ajudante | Uso |
|---|---|
| `kit_modules()` | `[origin_kit, kit]` sem nulos, na ordem dos ganchos |
| `kit_for_skill(skill_id)` | módulo ligado dono da skill, ou nulo |
| `kit_owns_skill(skill_id)` | dono é a origem **ou** a evolução |
| `has_kit()` | **verdadeiro também só com a origem** (veja limitação 2) |

Composição:

| Gancho | Regra |
|---|---|
| `on_tick`, `on_return`, `on_death`, `on_heal`, `on_damage_dealt`, `on_kill_confirmed`, `on_build_changed`, `on_enemy_attack`, `on_reveal`, `after_hit_mitigation`, `on_shield_broken` | origem primeiro, depois evolução |
| `can_cast` | os dois são consultados; a primeira recusa vale, com o código dela |
| `on_cast_requested`, `on_cast_confirmed`, `resolve_cast` | só o módulo dono da skill |
| `on_base_skill_committed` | o outro módulo, no mesmo instante do `on_cast_confirmed` do dono, na ordem origem → evolução. Para as skills que nenhum módulo possui (itens), os dois recebem. Assim a evolução vê as skills da base e a base vê as da evolução (a Devoção lê `context.element`) |
| `skill_cost` | encadeado: origem recebe o custo base, evolução recebe o resultado; piso 0; resposta não finita mantém o valor anterior |
| `basic_attack_profile` (`range`, `delivery`) | a evolução vence quando declara; senão a origem (dados de `basic_attack()`); senão a classe |
| `compose_basic_attack` | encadeado, origem e depois evolução (a evolução pode substituir o pedido) |
| `before_hit_mitigation` | origem e depois evolução; o primeiro `cancel` cancela o golpe e o módulo seguinte **não é consultado**; os `damage_multiplier` válidos se multiplicam (o resultado leva o produto em `kit_damage_multiplier`) |
| `temporary_stat_sources` | concatenadas, origem primeiro |
| `concealment_active` | qualquer um |
| `snapshot_compact_blocker` | qualquer um bloqueia; vale o primeiro motivo |
| famílias causais | as dos dois módulos entram no plano de toda emissão |

O descritor `cast` é o do E09; `element` é o de `skill_element` do módulo dono.

## 5. Alvo inimigo (C1.6)

### 5.1 Sobrescrita do alvo de combate (`EnemyActor`)

| Método | Efeito | Erros |
|---|---|---|
| `set_target_override(target, owner_id, duration, reason) -> {"ok", "error_code"}` | perseguição, alcance e ataque passam a mirar `target` (outro inimigo ou uma isca vivos) por `duration` s; substitui a anterior | `boss_refuses_target`, `invalid_target` (morto, ele mesmo, o jogador, fora da árvore), `incompatible_target` (plano × mundo), `invalid_payload` |
| `clear_target_override()` | volta ao jogador | — |
| `combat_target()` | o alvo da sobrescrita, senão o jogador | — |
| `has_target_override()`, `target_override_remaining()`, `target_override_reason()`, `target_override_owner_id()` | consulta | — |

- O prazo corre no relógio de gameplay (`_process`), congela na pausa e termina quando o alvo
  morre ou sai da árvore/do mundo, e com os status (morte do inimigo).
- Vale nos dois caminhos: mapa plano (rota até o alvo, alcance 55 ou o alcance declarado do
  arqueiro) e mundo da expedição (`world_can_reach`, plano de rota até o ponto do alvo).
- O inimigo ataca com o **ataque básico do arquétipo** (garra ou flecha). Skills declaradas de
  mob ficam para o jogador (limitação 3). A ameaça não muda; o chefe nunca aceita.
- Estado em `target_override` (`target_id`, `owner_id`, `remaining`, `reason`), no manifesto.

### 5.2 Desvio no commit

| Método | Efeito |
|---|---|
| `register_commit_deflection(source, owner_id, chance, radius, duration)` | no commit de cada ataque deste inimigo (básico, flecha e skill de mob na liberação), com chance `chance` (0..1), o golpe vai para um inimigo vivo **não chefe** a até `radius`, sorteado pelo RNG do inimigo; substitui o registro da mesma fonte |
| `remove_commit_deflection(source)` | remove |

- Sem candidato ao alcance, o golpe segue para o alvo normal e nenhum sorteio é gasto.
- O provedor não cria golpe: é o mesmo pedido, com `target_id` trocado e a autoria do dono.
- O RNG é próprio do inimigo (`combat_rng_state`, inteiro no manifesto, semeado pelo
  `occurrence_id`), determinístico e restaurável.

### 5.3 Dano entre inimigos

Quando o alvo de uma sobrescrita ou de um desvio é outro inimigo e o `owner_id` é um jogador
vivo, `EnemyActor.relay_authorship(request, victim, owner_id)`:
- põe `source_id = owner_id` e um contexto raiz novo do `EffectProcLedger` do jogador
  (`PlayerActor.enemy_relay_context()`); claims, `apply_once`, `on_damage_dealt`,
  `on_kill_confirmed` e `_credited_kills` tratam o golpe como do jogador; XP e loot seguem a
  morte do inimigo como sempre;
- marca `effect_snapshot[EnemyActor.RELAY_KEY] = {"actor_id": atacante, "owner_id": dono}`;
- a vítima **não muda ameaça nem engajamento** (`EnemyActor.is_relay_result(result)`);
- o `RunController` lança flecha/projétil a partir de `EnemyActor.attacker_id(request)`.

Sem dono vivo, o golpe fica com a autoria do inimigo. Golpe numa isca é sempre do inimigo.

### 5.4 Isca (`KitDecoy`)

| Método | Uso |
|---|---|
| `KitDecoy.spawn(host, owner, point, hp, duration, drawer_id, source_tag = &"") -> {"ok", "error_code", "decoy"}` | cria sob `host` (o `RunController`); `point` é `Vector2` no mapa plano ou `ExpeditionWorldPoint` no mundo (dono ligado ao mundo). Erros: `invalid_owner`, `invalid_payload`, `spatial_binding_required` e os de posição do mundo |
| `KitDecoy.decoys_of(host, owner_id = 0, source_tag = &"")` | iscas vivas do host, por dono e etiqueta (ex.: "um Ídolo por dono") |
| `decoy.remove(reason = &"removed")` | remove (idempotente); emite `decoy_removed(decoy, reason)` |
| `KitDecoy.register_drawer(id, Callable(canvas, decoy, remaining))`, `unregister_drawer(id)` | desenhador do sistema (só apresentação, não persiste) |

- Campos no manifesto: `owner_id`, `remaining`, `drawer_id`, `source_id_tag`, `removal_reason`.
- Não entra em `RunController.enemies`: o jogador nunca a mira nem a atinge em área.
- Expira no relógio de gameplay (`&"expired"`), congela na pausa, some a 0 HP (`&"destroyed"`).
- Fica no grupo `player_effects`, o que já torna o corte compacto inelegível
  (`CompactExpedition`: `projectile_or_effect`) e a limpa no fim do encontro e na recuperação de
  morte. Sobrevive ao snapshot exato com o dono religado.

## 6. Modificadores no inimigo (C1.7)

Fontes em `CombatActor`, compostas **uma vez** em `CombatMath`:

| Método | Efeito |
|---|---|
| `add_received_damage_source(source, multiplier, duration, owner_id = 0, element = &"")` | multiplicador de dano recebido; `owner_id` filtra o autor (0 = qualquer), `element` filtra a etiqueta (vazio = qualquer) |
| `remove_received_damage_source(source)`, `received_damage_multiplier(author_id, element)` | — |
| `add_accuracy_source(source, reduction, duration, owner_id = 0)` | reduz (0..1) o acerto dos ataques do próprio ator |
| `remove_accuracy_source(source)`, `outgoing_hit_rating(base)` | — |
| `CombatMath.received_damage_multiplier(sources, author_id, element)`, `CombatMath.accuracy_multiplier(sources)` | a composição única (produto) |
| `CombatActor.request_element(request)` | etiqueta do pedido = `SkillDefinition.element` da skill |

- O multiplicador entra em `apply_damage` numa cópia do pedido, junto do aumento de dano
  recebido existente. A redução de acerto entra nos pedidos do inimigo (básico, flecha e skill
  de mob na liberação).
- Prazos no relógio de gameplay (`advance_statuses`), congelam na pausa e somem com os status.
- **Desorientação de movimento:** `apply_disorient(duration, heading = Vector2.ZERO) -> float`,
  família `disorient` do `HardControlState` (resistência a CC mágico, tetos). **O chefe recusa
  (0).** Sem `heading`, o inimigo sorteia uma direção de 90° a 270° longe do alvo. Enquanto
  dura, ele anda nessa direção (plano e mundo) e não ataca nem conjura.
  `is_disoriented()`, `disorient_remaining()`.
- Raiz e lentidão continuam `apply_root` e `apply_slow`.

## 7. Elementos e apresentação (C1.8)

- `shadow` entra em `ClassKitRegistry.KIT_ELEMENTS` e em `ClassBaseRegistry.BASE_ELEMENTS`,
  ao lado de `light`: dano mágico com etiqueta, sem eixo de resistência.
- `FeedbackRecipeCatalog.ELEMENTS` ganha `light` e `shadow`; `WorldProjectileArt.PALETTE` tem
  `light` (marfim e dourado) e `shadow` (magenta sobre preto-azulado, com o acento turquesa
  `SHADOW_ACCENT`); a camada de efeitos desenha impacto e borda próprios para os dois.
- O Paladino e o Taumaturgo mostram as linhas `arcane` como `light`
  (`ClassKitRegistry.LIGHT_PRESENTATION_KITS`), sem tocar nos módulos nem no gameplay.
- Áudio: nenhuma deixa nova; `light` e `shadow` caem em família × físico e depois na deixa do
  tipo. A lista exata família × elemento está no recibo e em
  `tests/e08_feedback_recipe_test.gd`: as 13 famílias de deixa não têm `light` nem `shadow`;
  `area`, `buff`, `cast`, `charge`, `impact`, `melee`, `movement` e `projectile` caem em
  família × físico; `dot` cai em `world.impact`, `trap` em `world.area_end`, `teleport` na
  deixa do tipo, e `heal` e `summon` ficam em silêncio. Esse teste percorre só as três bases
  do E00: as skills da família Acólito não entram nele. Se uma tarefa quiser cobrir as skills
  da família ali, a extensão do teste passa pela arquitetura (o arquivo não é de módulo).
- Corpo: `ClassKitRegistry.actor_kind(evolution, origin)` → pasta do kit com arte; senão
  `base_actor_kind(origin)` → pasta da base com arte; senão o corpo de reserva (`mage`).
  `body_origin(kind)` dá um passo da cadeia (kit → base → reserva) e
  `legacy_body_kind(kind)` a percorre até um atlas legado. `CharacterAnimation`,
  `BuildPresentation.portrait_identity` e o jogador usam a mesma regra.

## 8. Snapshot (C1.9, A4)

- Fragmentos: `scripts/classes/bases/snapshot_manifest.json` (`class_base.gd`),
  `bases/acolyte/`, `priest/`, `cultist/` (vazios, revisão 1) e o de `scripts/classes/`
  (`kit_decoy.gd`). Ao acrescentar variáveis, a tarefa dona lista os campos e sobe a revisão.
- Manifesto principal: `PlayerActor.origin_kit`; `CombatActor.received_damage_sources`,
  `accuracy_sources`, `disorient_heading`; `EnemyActor.target_override`,
  `commit_deflections`, `combat_rng_state`; `ClassDefinition.basic_delivery`.
- Estado no jogador (dos dois módulos) sobrevive aos formatos exato e compacto; marcas,
  sobrescrita, desvios e modificadores seguem a restauração do inimigo (o compacto o devolve à
  origem sem eles); isca ativa ou zona do módulo tornam o compacto inelegível.

## 9. Códigos de erro novos

| Código | Onde |
|---|---|
| `base_unknown_identity`, `base_module_missing`, `base_identity_mismatch`, `base_skill_outside_identity`, `base_skill_duplicate`, `base_skill_invalid`, `base_learning_invalid`, `base_starting_invalid`, `base_attributes_invalid`, `base_attack_invalid`, `base_recipe_invalid`, `base_family_invalid`, `base_vfx_invalid`, `base_text_invalid`, `base_incomplete` | `ClassBaseRegistry.validate` |
| `boss_refuses_target`, `invalid_target`, `incompatible_target`, `invalid_payload` | `EnemyActor.set_target_override`, `register_commit_deflection` |
| `invalid_owner`, `invalid_payload`, `spatial_binding_required` | `KitDecoy.spawn` |

## 10. Limitações conhecidas (para quem consome)

1. **Executável.** Nesta máquina o `Godot_v4.7.2-stable_win64_console.exe` falha com
   `CreateProcess failed, error 193` (também fora do sandbox). A T1 rodou a suíte com o
   `Godot_v4.7.2-stable_win64.exe` da mesma pasta, mesma build (`4.7.2.stable.official.ed1daf0bf`).
2. **`has_kit()` mudou de sentido:** agora é verdadeiro só com a origem. Quem lê `player.kit`
   deve testar `player.kit != null`. `scripts/ui/classes/kit_onboarding_base.gd:112` faz
   `_player.has_kit() and _player.kit.evolution_id`; um onboarding do Acólito (T10) precisa
   tratar o jogador só com `origin_kit`. O `RunController` escolhe o onboarding da evolução e,
   sem ela, o da base.
3. **Sob sobrescrita, o inimigo usa só o ataque básico do arquétipo**; um mob cujo ataque é uma
   skill declarada não a usa contra o alvo da sobrescrita (a T4 pode pedir a extensão).
4. **Filtro de elemento** lê só `SkillDefinition.element`. Skills do E00 sem o campo (fogo,
   gelo, raio do Mago) têm etiqueta vazia; `light` e `shadow` sempre vêm do campo.
5. **Itens com `allowed_origins` vazio** continuam valendo só para as três do E00; a T9
   acrescenta `acolyte` explicitamente.
6. **Skills iniciais** (`starting_skill_ids`) alimentam só a `ClassDefinition` do mapa plano;
   personagens persistentes nascem com os atalhos vazios, como as bases do E00.
7. **XP e loot** de um abate entre inimigos seguem a morte do inimigo (sem teste de campanha
   nesta tarefa); o crédito ao jogador (`_credited_kills`, `on_kill_confirmed`) está provado.
