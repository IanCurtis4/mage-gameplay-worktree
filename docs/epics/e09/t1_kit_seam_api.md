# E09 T1 — API da costura de kits (C1)

Leitores: T5, T6, T9 e K1–K4. Este documento basta para usar a costura; o recibo da
entrega está em [t1_delivery.md](t1_delivery.md) e o contrato em
[e09_contract.md](../e09_contract.md), seção 2.

## 1. Mapa de arquivos

| Arquivo | Papel | Quem edita |
|---|---|---|
| `scripts/classes/class_kit_registry.gd` (`ClassKitRegistry`) | Registro fechado dos 4 IDs, tabela da seção 1, agregação dos dados | só T1 |
| `scripts/classes/class_kit.gd` (`ClassKit`) | Classe base de todo kit: dados de catálogo e ganchos | só T1 |
| `scripts/classes/kit_world_skill_cast.gd` (`KitWorldSkillCast`) | Intenção espacial de uma skill de kit | só T1 |
| `scripts/classes/snapshot_manifest.json` | Esquema das três classes acima | só T1 |
| `scripts/classes/<id>/<id>_kit.gd` | Módulo do kit (hoje um esqueleto vazio) | a tarefa do kit |
| `scripts/classes/<id>/snapshot_manifest.json` | Fragmento de snapshot da pasta | a tarefa do kit |
| `scripts/classes/fixture/fixture_kit.gd` | Kit de fixture dos testes, fora do registro de produção | só T1 |
| `scripts/systems/<nome>/snapshot_manifest.json` | Fragmento de um sistema (T5, T6) | a tarefa do sistema |
| `scripts/core/actor_marks.gd` (`ActorMarks`) | Marcas genéricas em atores | só T1 |
| `scripts/ui/classes/<id>_onboarding.gd` | Onboarding opcional (convenção) | T9 |
| `tests/classes/<id>/`, `tests/systems/<nome>/`, `tests/e09/` | Testes descobertos pelo verificador | a tarefa dona |

| Kit | Pasta | Origem | Afinidade (reservada) | Pasta de corpo | Prefixo |
|---|---|---|---|---|---|
| Paladino | `sp_ac` | `swordsman` | `acolyte` | `paladin` | `paladin_` |
| Taumaturgo | `mg_ac` | `mage` | `acolyte` | `thaumaturge` | `thaumaturge_` |
| Duelista | `sp_la` | `swordsman` | `rogue` | `duelist` | `duelist_` |
| Lâmina Arcana | `mg_la` | `mage` | `rogue` | `arcane_blade` | `arcane_blade_` |

`ClassKitRegistry.SKILL_IDS[<id>]` traz as 7 skills na ordem dos jobs 20, 23, 25, 28,
31, 34 e 37 (`JOB_LEVELS`); `SLOT_CATEGORIES` dá ativa/passiva de cada posição.

## 2. O módulo do kit

Um único script por kit, `scripts/classes/<id>/<id>_kit.gd`, `extends ClassKit`. Ele tem
dois papéis:

1. **Módulo de catálogo.** O registro guarda uma instância e só chama os métodos de dados.
   Eles são puros: não leem nem escrevem variáveis da instância.
2. **Objeto de kit por personagem.** O `PlayerActor` cria a própria instância com
   `create_runtime()` (padrão: `get_script().new()` e `evolution_id = kit_id()`) e chama os
   ganchos. As variáveis do script são estado da run e vão para o snapshot pelo fragmento.

Regras para o estado do kit:
- Nenhuma referência a `Node`, `Callable` ou objeto de outro ator em variáveis do kit.
  Guarde IDs de entidade com os nomes reconhecidos por `SnapshotIdentityRoles` (`victim_id`,
  `target_id`, `owner_id`, `marked_target_id`…), para o snapshot religar o ID na restauração.
- Os ganchos recebem o `player` como argumento; não o guarde.
- Relógios do kit avançam só em `on_tick` (que não roda em pausa) ou em `ActorMarks`.

### 2.1 Dados de catálogo (sobrescreva no módulo)

| Método | Retorno | Regra validada pelo registro |
|---|---|---|
| `kit_id()` | `StringName` | igual à chave do registro (`kit_identity_mismatch`) |
| `ready_for_play()` | `bool` | `false` deixa a evolução fora do `ProfileCatalog` |
| `display_name()` | `String` pt-BR | — (vazio cai no nome da seção 1) |
| `skill_definitions()` | `Array[SkillDefinition]` | ID da tabela do kit; `handler_id = SkillDefinition.Handler.KIT`; `is_rank_catalog_valid()`; categoria da posição; `element` em `ClassKitRegistry.KIT_ELEMENTS`; `tags` só com `EffectTags` |
| `learning_entries()` | `Array[Dictionary]` | uma linha por skill definida (ver abaixo) |
| `passive_modifier_source(skill_id, rank)` | `Dictionary` | mesmo formato de `ClassCatalog.passive_modifier_source` |
| `causal_families()` | `Array[StringName]` | começa com o prefixo do kit |
| `feedback_recipes()` | `{skill_id: [família, elemento, &"", flags]}` | família e elemento de `FeedbackRecipeCatalog.FAMILIES/ELEMENTS`; assinatura vazia |
| `basic_attack_recipe()` | `[família, elemento, &"", flags]` ou `[]` | `[]` usa a linha da origem |
| `skill_texts()` | `{skill_id: {"flavor","effect","combo","mechanics"}}` | só skills definidas |
| `vfx_effects()` | `{effect_id: {"skill_id","kinds","size"}}` | `effect_id` com o prefixo; `kinds` não vazio |
| `draw_vfx(effect_id, canvas, pulse, position, t)` | `bool` | desenho em código; só apresentação |
| `skill_element(skill_id)` | `StringName` | padrão: `SkillDefinition.element` |

Linha de aprendizado:

```gdscript
{"skill_id": &"paladin_oath", "category": &"active", "free_rank": 1,
 "max_purchased_rank": 4, "job_level": 20}
{"skill_id": &"paladin_consecrated_impact", "category": &"active", "free_rank": 0,
 "max_purchased_rank": 5, "job_level": 25, "prerequisites": {&"paladin_oath": 2}}
```

- `category` é `ProfileCatalog.ACTIVE` (`&"active"`) ou `PASSIVE` (`&"passive"`), conforme
  a posição.
- `job_level` é o da posição (20, 23, 25, 28, 31, 34, 37).
- `free_rank` é 1 só na entrada do job 20; nas outras, 0.
- `free_rank + max_purchased_rank` é 5 nas ativas e 3 nas passivas.
- `prerequisites` é opcional nas posições compradas e pode citar skills da origem.
  **A entrada do job 20 não leva `prerequisites`**: o R1 grátis é concedido na evolução e
  não aceita pré-requisito comprado (limitação 3 da K1, decisão A13).

Com `ready_for_play() == true`, o registro exige ainda as 7 skills, um texto `effect` não
vazio e uma receita de feedback para cada uma (`kit_incomplete`).

### 2.2 Onde os dados aparecem

| Consumidor | Como lê o kit |
|---|---|
| `ClassCatalog.skill_definition(id)` | IDs da base primeiro; depois `ClassKitRegistry.skill_definition(id)` |
| `ClassCatalog.passive_modifier_source` | `Handler.KIT` → `passive_modifier_source` do módulo; entra no `BuildSnapshot.stat_breakdown`, logo prévia e execução usam a mesma composição |
| `ProfileCatalog.pilot()` | kits prontos (ou forçados por fixture) registram skills, aprendizado e a evolução |
| `BuildEffectCatalog.is_intrinsic_family` | famílias causais do kit contam como intrínsecas |
| `PlayerActor._begin_effect_emission` | famílias causais do kit entram no plano de toda emissão do jogador |
| `FeedbackRecipeCatalog.recipe` / `for_event` / `known_ids` | receitas do kit; `basic_attack` com variante `<id>` usa `basic_attack_recipe()` ou a linha da origem |
| `SkillCopy.text_for` | `flavor`, `effect`, `combo` do kit (a base vence) |
| `SkillPresentation.mechanics_of` / `describe` | `mechanics` do kit (a base vence) |
| `SkillPresentation.job_name` | nome do kit mesmo antes de pronto |
| `SkillPresentation.icon` | já resolve `assets/art/skills/painted/<id>.png` → `assets/art/skills/<id>.svg` pelo mesmo ID (T3) |

## 3. Disponibilidade e evolução (C1.3, C1.10)

- `ClassKitRegistry.ready_for_play(id)` = módulo existe, `ready_for_play()` é verdadeiro e
  `validate(id)` passa.
- `ProfileCatalog.pilot()` só inclui a evolução de um kit pronto. Um kit que se declara
  pronto com dados inválidos torna o catálogo inválido (falha alta, de propósito).
- Fixture: `ProfileCatalog.pilot({}, {}, {&"sp_ac": {"content_ready": true}})` força a
  evolução (precisa de dados válidos); `{"content_ready": false}` a lista como indisponível.
  Os campos aceitos são os de sempre: `entry_skill_id`, `exclusive_skill_ids`, `content_ready`.
- A evolução do kit entra depois das 12 do E00, com `branch_kind = "2-3"`,
  `affinity_class_id = acolyte|rogue` e `display_name` do módulo. Uma origem pode ter mais
  de duas híbridas: com os dois kits do Espadachim prontos, a ordem é
  `defender, berserker, sp_mg, sp_ar, sp_ac, sp_la`.
- `IdentityIds`: `SP_AC`, `MG_AC`, `SP_LA`, `MG_LA`; `kit_evolution_ids()`;
  `ACOLYTE`/`ROGUE` em `reserved_base_ids()` (não jogáveis, fora de `base_class_ids()`);
  `kit_affinity(id)`. `is_evolution`, `evolution_origin` e `evolution_belongs_to` aceitam
  os quatro. `hybrid_evolution_ids()` continua com as seis de sempre.
- `EquipmentEligibilityRules`: `KIT_IDENTITIES` e `eligible_identities()`; `validate` aceita
  os quatro em `allowed_identities`. `CURRENT_IDENTITIES` continua com as dez (é também a
  lista dos conjuntos de classe).
- A versão do catálogo e o schema de save **não mudaram**.

## 4. Ganchos no jogador (C1.4)

`PlayerActor.kit: ClassKit` existe quando a build persistente tem a evolução de um kit da
mesma origem. `configure()` cria o objeto e chama `on_attach` uma vez; a restauração de
snapshot não chama `on_attach`. Testes podem usar `player.attach_kit(kit)`.

| Gancho | Quando | Notas |
|---|---|---|
| `on_attach(player)` | uma vez, no `configure` | — |
| `on_tick(player, delta)` | todo tick de gameplay | nunca em pausa nem morto; `player.kit_time` é o relógio |
| `can_cast(player, cast) -> {"ok", "error_code"}` | prévia, pedido, cada frame de preparo e commit | puro; recusa volta como `error_code` do cast |
| `on_cast_requested(player, cast)` | uma vez por pedido aceito, antes do preparo | — |
| `on_cast_confirmed(player, cast)` | logo depois do pagamento canônico (SP e recarga) | — |
| `resolve_cast(player, cast) -> bool` | executa a skill | depois do confirmado e da revelação ofensiva |
| `basic_attack_profile(player) -> {"range", "delivery"}` | ao medir e lançar o ataque básico | `range` substitui `basic_range` da classe; `delivery` = `&"direct"`, `&"mage"` ou `&"precision"` |
| `compose_basic_attack(player, target, request) -> DamageRequest` | a cada ataque básico | devolva o pedido, uma cópia alterada ou um novo de `kit_make_request` |
| `before_hit_mitigation(player, hit) -> {"cancel", "reason", "damage_multiplier"}` | golpe recebido, passo 1 | `cancel: true` anula o golpe inteiro; `damage_multiplier` (T1.1) escala o dano recebido, ver 4.2 |
| `after_hit_mitigation(player, hit, result)` | golpe recebido, passo 2 | `hit.frontal` e `hit.facing_dot` |
| `on_shield_broken(player, hit, result)` | golpe recebido, passo 3 | o golpe levou o último ponto de escudo |
| `on_heal(player, requested, applied, source)` | curas reportadas | excedente = `requested - applied` |
| `on_damage_dealt(player, result)` | dano do jogador confirmado num inimigo | depois do claim do resultado |
| `on_kill_confirmed(player, result)` | abate creditado | uma vez por vítima, inclusive em retry |
| `on_death(player)` | morte do jogador | antes da recuperação de morte da expedição |
| `on_return(player)` | primeiro tick vivo depois de uma morte | volta ao portal ou revive |
| `on_build_changed(player)` | `apply_run_modifiers` (troca de build/aprendizado na run) | sem cura, recarga ou reset implícitos |
| `temporary_stat_sources(player) -> Array[Dictionary]` (T1.1) | toda recomposição do breakdown do jogador | leitura pura do estado do kit; ver 4.4 |
| `skill_cost(player, skill_id, base_cost) -> float` (T1.2) | toda leitura do custo efetivo (prévia, pedido, checagem de pagamento, débito, UI) | skills do kit e da origem; piso 0; ver 4.5 |
| `on_base_skill_committed(player, skill_id, context)` (T1.2) | uma vez por commit pago de skill que não é do kit | mesmo instante de `on_cast_confirmed`; ver 4.5 |
| `on_enemy_attack(player, event)` | um inimigo comprometeu um ataque contra o jogador | ver 5.3 |
| `concealment_active(player) -> bool` | ocultação do kit | ver 6 |
| `on_reveal(player, duration)` | ação ofensiva revelou o jogador | — |
| `snapshot_compact_blocker(player) -> String` | cada corte compacto | não vazio → formato exato |

### 4.1 Ordem de um cast

1. Pedido. No mundo: `RunController.cast_world_skill` → `PlayerActor.request_world_skill`
   → `KitWorldSkillCast` (alvo pelo `SkillDefinition.targeting`). No mapa plano:
   `_commit_skill_with_rank` → `begin_skill_cast` (com tempo de conjuração) ou
   `_execute_skill` → `use_kit_skill`.
2. `can_cast` (puro), depois `on_cast_requested` uma vez.
3. Preparo, quando `skill_cast_time > 0`: `can_cast` é repetido a cada frame. Mover,
   pausar, controle ou build desatualizada cancelam como nas outras skills.
4. Commit: `_commit_action(action_kind)`, `_spend` (SP e recarga),
   `on_cast_confirmed`, `reveal_from_offense()` se a skill é ofensiva, `resolve_cast`.

Descritor `cast` (Dictionary):

| Chave | Tipo | Valor |
|---|---|---|
| `skill_id` | `StringName` | skill |
| `rank` | `int` | rank efetivo do cast (inclui o rank escolhido no atalho) |
| `element` | `StringName` | `skill_element(skill_id)` |
| `world` | `bool` | verdadeiro no mundo da expedição |
| `anchor` | `ExpeditionWorldPoint` ou `null` | ponto (POINT), origem (SELF) ou alvo (SINGLE_TARGET); `null` no mapa plano |
| `point` | `Vector2` | ponto no plano (x/z no mundo) |
| `facing` | `Vector3` | direção no chão |
| `facing_2d` | `Vector2` | a mesma direção em 2D |
| `target` | `CombatActor` ou `null` | alvo vivo |
| `actors` | `Array[CombatActor]` | inimigos vivos candidatos |

### 4.2 Pipeline de golpe recebido (ordem fixa)

Vale para golpes diretos no jogador com kit; ticks secundários (queimadura, sangramento)
não passam pelo pipeline.

1. `before_hit_mitigation(player, hit)`. Com `{"cancel": true, "reason": &"..."}` nada mais
   acontece e o resultado é
   `{"landed": false, "cancelled": true, "cancel_reason", "damage": 0, "actual_damage": 0, "absorbed_damage": 0, "critical": false, "killed": false, "can_trigger_effects": false, "source_id", "target_id", "skill_id"}`.
   Sem cancelamento, a chave opcional `"damage_multiplier": float` (T1.1) escala o dano
   recebido: o jogador aplica `damage_dealt_multiplier *= m` numa **cópia** do pedido
   (`request.copy()`), como a redução frontal já faz. O pedido original nunca muda.
   - Valor ausente, não numérico, não finito ou negativo é ignorado; `1.0` segue o caminho
     sem cópia. `0.0` é aceito (golpe aterrissa com dano zero, sem cancelar).
   - `cancel` tem prioridade: com os dois, o golpe é cancelado e o multiplicador some.
   - Quando `m != 1`, o resultado ganha `"kit_damage_multiplier": m`.
   - O multiplicador entra antes das reduções existentes e se multiplica com elas.
2. Mitigação existente (Parede de Escudos, guardas do Defensor, `HealthState`), depois
   `after_hit_mitigation(player, hit, result)`. `hit["request"]` continua sendo o pedido
   original, mesmo com multiplicador.
3. `on_shield_broken(player, hit, result)` se o escudo estava acima de zero e zerou neste golpe.

Descritor `hit`:

| Chave | Valor |
|---|---|
| `request` | o `DamageRequest` recebido |
| `source` / `source_id` | atacante (ou `null`) e seu ID |
| `kind` | `&"melee"`, `&"projectile"`, `&"area"` ou `&"unknown"` (do evento; sem evento, `enemy_claw` → melee e `enemy_arrow` → projectile) |
| `event` | cópia do evento de ataque (5.3) ou `{}` |
| `facing_dot` | produto escalar entre a direção do atacante e o facing de gameplay do jogador, no chão; `-2` sem atacante |
| `frontal` | `facing_dot > 0` (meio-plano da frente). Cones mais estreitos usam `facing_dot` |

### 4.3 Ajudantes do `PlayerActor` para módulos

| Método | Uso |
|---|---|
| `kit_make_request(victim, skill_id, physical, magic, accuracy_mode = CONTESTED, can_crit = true) -> DamageRequest` | pedido com os campos canônicos do atacante (acerto, crítico, multiplicadores, contexto causal, rank, armas). O kit só decide os montantes, sempre a partir de `stat_breakdown`/`CombatMath`, sem fórmula própria de defesa |
| `kit_emit_hit(request, victim)` | golpe direto pelo `RunController` (claims, callbacks e ledger) |
| `kit_emit_projectile(request, victim, delivery = &"mage")` | projétil pelos produtores existentes (`&"mage"` ou `&"precision"`) |
| `heal_player(amount, source) -> float` | cura com `on_heal` (pedido e aplicado) |
| `kit_force_target(enemy, duration)` / `kit_break_sight(enemy, duration)` | primitivas de ameaça (6) a partir do jogador |
| `kit_concealed() -> bool` | ocultação do kit ativa e não revelada |
| `has_kit()`, `kit_owns_skill(skill_id)`, `kit_time` | consultas |
| `refresh_kit_stats()` (T1.1) | recompõe o breakdown depois que as fontes temporárias do kit mudaram (4.4) |
| `skill_cost(skill_id)` / `base_skill_cost(skill_id)` (T1.2) | custo efetivo (com o kit) e custo antes do kit (4.5) |
| `PlayerActor.base_skill_element(skill_id)` (T1.2, estático) | elemento canônico de uma skill que não é do kit (4.5) |

Dano de luz (A2): dano mágico (`magic`) numa skill com `SkillDefinition.element = &"light"`.
Atenção: `SkillDefinition.tags` são descritores de efeito de item (`EffectTags`: `flaming`,
`freezing`…); uma etiqueta fora dessa lista faz a captura de rank falhar com
`unknown_effect_tag`. Por isso o elemento tem campo próprio, `element`, com os valores
`physical`, `fire`, `ice`, `lightning`, `light`, `arcane`, `spirit` ou vazio.

### 4.4 Fontes de atributo temporárias do kit (T1.1)

`ClassKit.temporary_stat_sources(player) -> Array[Dictionary]` devolve vazio por padrão.
`PlayerActor.temporary_stat_sources()` soma o resultado depois das fontes existentes
(passo do Caçador, postura do Sentinela, Fúria, Marco de Guarda). Entradas vazias são
descartadas. O formato é o mesmo da fonte `defender_anchor`:

```gdscript
{"source_id": &"paladin_zone", "label": "Zona consagrada", "increased": {&"physical_defense": 0.2, &"magic_defense": 0.2}}
```

- Use um `source_id` com o prefixo do kit. Os valores entram na composição única de
  `BuildSnapshot.stat_breakdown`, sem fórmula própria no kit.
- O método é leitura pura do estado do kit e roda em toda recomposição (build, Fúria,
  Marco, `refresh_kit_stats`).
- Quando a resposta mudar (entrar ou sair da zona, por exemplo), o kit chama
  `player.refresh_kit_stats()`. Ele recompõe pelo mesmo caminho de Fúria e do Marco
  (`_apply_derived_stats(_build_stat_breakdown())`) e emite `resources_changed`.
  É idempotente, não cura, não recarrega SP e não zera recargas: os déficits de HP e SP
  continuam iguais. Sem `run_state` ou breakdown ainda, não faz nada.
- O breakdown não se recompõe sozinho a cada tick; sem a chamada, a fonte só aparece na
  próxima recomposição de outra origem.

### 4.5 Custo efetivo e commits das skills da origem (T1.2, decisão A13)

**Custo.** `PlayerActor.skill_cost(skill_id)` é a fonte única do custo de SP efetivo, para
skills do kit e da origem.
- `base_skill_cost(skill_id)` é o custo antes do kit: o rank em execução, já com os
  modificadores de item, ou a definição sem ranks.
- Com kit, o valor passa por `ClassKit.skill_cost(player, skill_id, base_cost)`. O jogador
  aplica piso 0 e ignora resposta não finita, voltando ao custo base.
- `_can_pay_skill` (prévia, pedido, cada frame de preparo) e o débito de `_spend` leem
  `skill_cost`. A UI que mostra custo efetivo (cartões e atalhos do HUD, mensagens de
  bloqueio) também lê `skill_cost`. As linhas "SP base" do tooltip e do seletor de rank
  continuam mostrando o custo base.
- O método é leitura pura: roda muitas vezes por frame.
- **Reserva do Sentinela.** `sentinel_explosive_shot` reserva `skill_cost` na preparação, e o
  disparo cobra exatamente o valor reservado, mesmo que o custo do kit tenha mudado. A
  reserva não é pagamento nem commit.

Exemplo da Aurora (K2), com feitiços pela metade:

```gdscript
func skill_cost(_player: PlayerActor, skill_id: StringName, base_cost: float) -> float:
	return base_cost * 0.5 if aurora_active and skill_id in SPELLS else base_cost
```

**Commit da origem.** `ClassKit.on_base_skill_committed(player, skill_id, context)`.
- Chamado uma vez por commit pago de skill que o kit não possui, nos caminhos plano e de
  mundo. Inclui `slash`, `dash`, `teleport` e as ativas de item.
- Momento: dentro do pagamento canônico, depois de SP e recarga, antes da resolução. É o
  mesmo instante de `on_cast_confirmed` em `_use_kit_cast`.
- Nunca é chamado em cast recusado (recarga, SP, alvo, posição), na reserva do Sentinela, num
  segundo pagamento do mesmo comando de mundo, nem no ataque básico. O disparo da reserva
  conta uma vez, no commit real.
- O gancho não deve lançar skill nem gastar recurso.

| Chave de `context` | Valor |
|---|---|
| `target` | `CombatActor` vivo ou `null` |
| `point` | `Vector2` no plano; no mundo, x/z |
| `world` | `true` no mundo da expedição |
| `rank` | rank efetivo do commit |
| `element` | elemento canônico (`base_skill_element`) ou vazio |

De onde vêm `point` e `target`:
- Comando de mundo: âncora do comando ou, sem âncora, a posição mais a direção; o alvo é o
  do comando.
- Despacho plano do `RunController._execute_skill`: o ponto clicado e o alvo selecionado.
- Teleporte e investida, no plano e no mundo: o destino.
- Traçado, edição e Colapso do Geômetra: o ponto e o alvo do comando.
- Disparo da reserva do Sentinela: o alvo e a posição dele.
- Chamada direta sem entrada, como `use_slash` num teste: posição do jogador, sem alvo.

O registro da entrada (`note_base_commit`) vale só para o próximo pagamento da mesma
skill. O pagamento consome o registro, inclusive quando o comando de mundo é recusado em
`_spend`, e o `RunController` limpa a sobra quando o cast é recusado. O registro é transitório:
nunca existe entre frames, e o `runtime_manifest.json` o declara em `omitted`. Um kit não deve
ler nem guardar esse registro; o contexto do gancho é a única interface.

**Elemento canônico.** `PlayerActor.base_skill_element(skill_id)` devolve
`SkillDefinition.element` quando a definição tem um. Sem isso, consulta a tabela de
gameplay `PlayerActor.BASE_SKILL_ELEMENTS`:

| Elemento | Skills |
|---|---|
| fogo | `fireball`, `fire_wall`, `fire_spear` e as de fogo do Elementalista |
| gelo | `ice_spear`, `ice_wall`, `elementalist_glacial_ring` |
| raio | `lightning`, `electric_discharge`, `lightning_wall`, `elementalist_lightning_arc` |

Skills físicas, de movimento e o teleporte ficam com elemento vazio. A receita de
apresentação (`FeedbackRecipeCatalog`) não é fonte de gameplay.

## 5. Inimigos (C1.5)

### 5.1 `ActorMarks` — `CombatActor.marks`

Marcas por chave, com dono, valor e expiração no relógio de gameplay (avançam em
`advance_statuses`, congelam na pausa e somem com `clear_statuses`, ou seja, na morte e na
recuperação de morte).

| Método | Retorno |
|---|---|
| `set_mark(key, owner_id, value, duration = NO_EXPIRY)` | `bool` (falso: chave vazia, duração não finita, valor objeto/callable, ou `MAX_MARKS` = 32) |
| `has_mark(key)`, `get_mark(key)` (`{owner_id, value, remaining}`), `value(key, default)`, `owner_of(key)`, `remaining(key)` | consulta |
| `update_value(key, value)` | troca o valor, mantendo dono e prazo |
| `remove(key)`, `remove_owner(owner_id) -> int`, `clear()` | remoção |
| `keys()` (ordenadas), `is_empty()`, `valid()`, `revision` | — |

Use chaves com o prefixo do kit ou do sistema (`paladin_seal`, `flank_sentence`).
`owner_id` é o ID de instância do dono; o snapshot religa. O valor deve ser dado simples.
A mesma chave aparece uma vez no manifesto (`res://scripts/core/actor_marks.gd`).

### 5.2 Facing de gameplay

| Método de `CombatActor` | Uso |
|---|---|
| `gameplay_facing() -> Vector2` | direção desenhada (canvas); o override ativo vence |
| `gameplay_ground_facing() -> Vector3` | a mesma no chão (x/z); no mapa plano, x/y → x/z |
| `override_gameplay_facing(direction: Vector2, duration, owner = &"") -> bool` | "girar": regra e sprite passam a usar a direção |
| `override_gameplay_ground_facing(direction: Vector3, duration, owner = &"")` | o mesmo a partir do chão |
| `gameplay_facing_override_remaining()`, `gameplay_facing_override_owner()`, `clear_gameplay_facing_override()` | — |
| `CombatActor.canvas_to_ground_direction(v2)`, `ground_to_canvas_direction(v3)` | conversões pela projeção compartilhada |

O override expira no relógio de gameplay, congela na pausa e some na morte. Um novo override
substitui o anterior.

### 5.3 Evento de ataque inimigo

`RunController` publica `enemy_attack_committed(event)` e chama `kit.on_enemy_attack` no
commit de todo ataque de inimigo contra o jogador com kit (ataque corpo a corpo, flecha e
skill de mob). Chaves:

| Chave | Valor |
|---|---|
| `kind` | `&"melee"` (corpo a corpo), `&"projectile"` (flecha ou skill de mob) ou `&"area"` (reservado: nenhum inimigo atual produz) |
| `attacker_id`, `target_id` | IDs de instância |
| `skill_id` | `enemy_claw`, `enemy_arrow` ou a skill do mob |
| `commit_time` | `player.kit_time` no commit |
| `impact_time` | igual ao commit no corpo a corpo; `-1` no projétil até o impacto |

No impacto, o `hit.event` do pipeline traz o mesmo evento com `impact_time` preenchido. O
evento de um projétil em voo não entra no snapshot: depois de uma restauração, o impacto
usa o próprio instante como commit.

## 6. Ameaça e ocultação (C1.6, C1.7)

`ThreatService` (um por inimigo):

| Método | Efeito | Erros |
|---|---|---|
| `force_target(source, duration)` | o slot forçado (o mesmo da provocação) aponta para `source`, sem mexer nos montantes; um force mais longo na mesma fonte é mantido | `invalid_participant`, `invalid_payload`, `participant_ineligible` |
| `break_sight(source, duration)` | `source` fica inelegível por `duration` e um force nele termina | `invalid_participant`, `invalid_payload` |
| `sight_broken(source)`, `sight_break_remaining(source)` | consulta | — |

Os dois prazos avançam em `advance(delta, frozen)`. A regra de escolha (maior ameaça,
limiar de 1,1) não mudou. No mundo, um inimigo que perdeu de vista o jogador também não o
adquire (`can_be_acquired_by_world`). No mapa plano antigo vale só a inelegibilidade na
ameaça.

Ocultação do kit: `concealment_active(player)` torna o jogador oculto
(`is_concealed`), e ninguém o adquire enquanto ela vale (não há exceção de "estar no
mesmo abrigo"). Atacar revela como na Caçadora: `reveal_from_offense()` chama
`on_reveal(player, duration)` e liga `concealment_reveal_remaining`. A Caçadora e os
abrigos atuais não mudaram.

## 7. Apresentação (C1.8)

- **Efeitos.** Para cada evento confirmado sem arte própria, a camada procura
  `vfx_effects()` do kit pelo `skill_id` e pelo tipo (`impact`, `melee_swing`,
  `area_start`, `effect_start`, `projectile_launch`, `cast_start`, …). Se existir o flipbook
  `assets/art/e08_vfx/<effect_id>/` (`VfxFlipbookCatalog`), ele toca com o tamanho `size`;
  senão, `draw_vfx(effect_id, canvas, pulse, position, t)` desenha em código (`t` de 0 a 1;
  `pulse` tem `element`, `dir`, `seed`, `legacy`, `radius`). Reserve cada `effect_id` no
  recibo do kit.
- **Corpo.** `ClassKitRegistry.actor_kind(evolution, origin)` devolve a pasta de corpo quando
  existe `presentation.json` em `assets/art/animations/directional/<pasta>/` ou em
  `assets/art/e08_characters/directional/<pasta>/`
  (`DirectionalAnimationSet.kit_body_path`); senão, o corpo da origem. Um manifesto inválido
  também cai, inteiro, no corpo da origem. O jogador, o retrato
  (`BuildPresentation.portrait_identity`) e `CharacterAnimation.configure` usam a mesma regra.
  Pastas de kit exigem `weaponless` como as identidades atuais.
- **Corpo de fixture (A14, só testes).**
  - `ClassKitRegistry.install_fixture_body(evolution, pasta)` aponta a pasta de corpo de uma
    das quatro identidades para uma pasta de fixture, até `clear_fixtures()`.
  - A instalação é recusada para identidade fora dos kits, nome vazio ou pasta que já pertence
    a uma identidade.
  - Use uma pasta que nunca tem arte para provar o fallback da origem sem depender da arte de
    produção. A prova de que cada híbrida resolve o próprio corpo é da T7
    (`tests/e09/hybrid_bodies_test.gd`).

## 8. Snapshot (C1.9)

- Cada pasta em `scripts/classes/**` e `scripts/systems/**` pode ter `snapshot_manifest.json`,
  no formato do manifesto principal:

  ```json
  {
    "res://scripts/classes/sp_ac/sp_ac_kit.gd": {"revision": 1, "fields": ["grace"], "omitted": {}}
  }
  ```

- O `SnapshotRegistry` agrega todos os fragmentos (`SnapshotRegistry.fragment_paths()`).
  Um fragmento só descreve scripts da **própria pasta** e nunca um tipo já declarado.
  Problemas viram `fragment_errors` e fazem toda captura falhar com o código
  (`fragment_kind_outside_folder`, `fragment_kind_duplicate`, `invalid_manifest_fragment`).
- Toda variável de script precisa estar em `fields` ou em `omitted` (com motivo), inclusive
  as de classes auxiliares da pasta; o verificador de captura acusa `checkpoint_incomplete`.
  Ao mudar os campos, suba `revision`.
- Os fragmentos entram nas revisões de fonte, como os scripts: mudar um fragmento invalida
  snapshots antigos.
- Estado no jogador (variáveis do kit, `kit_time`) sobrevive à suspensão nos formatos exato
  e compacto.
- Marcas em inimigos seguem o inimigo: no exato voltam com ele; no compacto o inimigo volta
  à origem e sem marcas. Um kit que guarda referência de objeto de inimigo torna o compacto
  inelegível (`dangling_entity_reference`) e o save cai no exato.
- Zona ativa ou entidade temporária: `snapshot_compact_blocker(player)` devolve um motivo, e a
  captura compacta falha com `kit_compact_ineligible`; o save usa o formato exato. Nós de zona
  nos grupos `player_effects`/`player_projectiles` já bloqueiam o compacto por si.
- A pausa congela todos os relógios de kit: `on_tick`, `ActorMarks`, override de facing e
  prazos da ameaça.

## 9. Verificador (C1.11)

`tools/verify.ps1` acrescenta, depois das etapas existentes (os índices antigos não mudam):
1. `tests/e09/**/*_test.gd`, `tests/systems/**/*_test.gd` e `tests/classes/**/*_test.gd`,
   descobertos por pasta em ordem estável; o nome da etapa é o nome do arquivo sem `.gd`
   (`-Test 'kit_seam_test'`, `-Test 'sp_ac_*'`);
2. `art_pipeline_tests`, quando `tools/art_pipeline/tests/` existe e tem `test_*.py`:
   `python -I -m unittest discover -s tools/art_pipeline/tests -t . -p "test_*.py" -v`, na
   raiz do projeto. `-PythonPath` escolhe o Python; sem ele, `python`, `python3` ou `py` do
   PATH. Uma seleção só com essa etapa não precisa de `-GodotPath`.

Nomes de teste devem ser únicos no projeto, porque `-Test` seleciona pelo nome.

## 10. Onboarding (C1.12)

Se `res://scripts/ui/classes/<id>_onboarding.gd` existir, o `RunController` instancia o
script ao montar a interface de um jogador com esse kit. Se for `Control`, ele entra em
`ui_root`, o painel de ajuda genérico some, e são chamados `configure(player)` (se existir)
e `refresh()` (se existir) a cada atualização do HUD, como no `geometer_onboarding`.

## 11. Códigos de erro

| Código | Onde | Significado |
|---|---|---|
| `kit_unknown_identity` | `ClassKitRegistry.validate` | ID fora do registro |
| `kit_module_missing` | `validate` | script do módulo ausente ou não `ClassKit` |
| `kit_identity_mismatch` | `validate` | `kit_id()` diferente da chave |
| `kit_skill_outside_identity` | `validate` | skill fora da tabela do kit |
| `kit_skill_duplicate` | `validate` | skill definida duas vezes |
| `kit_skill_invalid` | `validate` | handler diferente de `KIT`, ranks inválidos, categoria trocada, `element` fora de `KIT_ELEMENTS` ou `tags` fora de `EffectTags` |
| `kit_learning_invalid` | `validate` | linha de aprendizado sem skill, job, categoria ou ranks da seção 1 |
| `kit_recipe_invalid` | `validate` | receita com família/elemento desconhecido ou assinatura |
| `kit_family_invalid` | `validate` | família causal sem o prefixo |
| `kit_vfx_invalid` | `validate` | efeito sem prefixo, skill ou tipos |
| `kit_text_invalid` | `validate` | texto de skill não definida |
| `kit_incomplete` | `validate` | kit pronto sem as 7 skills, texto `effect` ou receita |
| `kit_unavailable` | cast no mundo | skill não pertence ao kit ligado |
| (do kit) | cast | `error_code` devolvido por `can_cast` (padrão `kit_refused`) |
| `participant_ineligible` | `ThreatService.force_target` | fonte morta, invisível ou sem visão |
| `kit_compact_ineligible` | `SnapshotRegistry.capture` compacta | `snapshot_compact_blocker` não vazio |
| `fragment_kind_outside_folder`, `fragment_kind_duplicate`, `invalid_manifest_fragment` | `SnapshotRegistry` | fragmento de manifesto inválido |

## 12. Exemplo mínimo

```gdscript
# scripts/classes/sp_ac/sp_ac_kit.gd
extends ClassKit

var grace := 0 # estado da run: entra em fields do fragmento

func kit_id() -> StringName: return &"sp_ac"
func display_name() -> String: return "Paladino"
func ready_for_play() -> bool: return false # true só depois dos testes de tests/classes/sp_ac/

func skill_definitions() -> Array[SkillDefinition]:
	var oath := SkillDefinition.new()
	oath.id = &"paladin_oath"
	oath.display_name = "Juramento"
	oath.handler_id = SkillDefinition.Handler.KIT
	oath.targeting = SkillDefinition.Targeting.SELF
	oath.action_kind = SkillDefinition.ActionKind.DEFENSIVE
	oath.element = &"light"
	for rank: int in range(1, 6):
		var values := SkillRankDefinition.new()
		values.rank = rank
		values.sp_cost = 18.0
		values.cooldown = 12.0
		values.power = 0.10 + 0.02 * rank
		oath.ranks.append(values)
	return [oath]

func learning_entries() -> Array[Dictionary]:
	return [{"skill_id": &"paladin_oath", "category": &"active", "free_rank": 1, "max_purchased_rank": 4, "job_level": 20}]

func feedback_recipes() -> Dictionary:
	return {&"paladin_oath": [&"buff", &"arcane", &"", FeedbackRecipeCatalog.COMMIT]}

func skill_texts() -> Dictionary:
	return {&"paladin_oath": {"flavor": "", "effect": "Ergue um cone de guarda à frente.", "combo": "", "mechanics": "Zona em cone presa ao facing."}}

func vfx_effects() -> Dictionary:
	return {&"paladin_oath_cone": {"skill_id": &"paladin_oath", "kinds": [&"effect_start"], "size": 120.0}}

func draw_vfx(effect_id: StringName, canvas: CanvasItem, _pulse: Dictionary, position: Vector2, t: float) -> bool:
	if effect_id != &"paladin_oath_cone": return false
	canvas.draw_arc(position, 30.0 + 40.0 * t, -0.6, 0.6, 16, Color(1.0, 0.9, 0.5, 1.0 - t), 3.0)
	return true

func resolve_cast(_player: PlayerActor, cast: Dictionary) -> bool:
	if cast["skill_id"] == &"paladin_oath": grace = mini(grace + 1, 5)
	return true

func after_hit_mitigation(_player: PlayerActor, hit: Dictionary, result: Dictionary) -> void:
	if hit["frontal"] and float(result.get("actual_damage", 0.0)) > 0.0: grace = mini(grace + 1, 5)
```

```json
// scripts/classes/sp_ac/snapshot_manifest.json
{"res://scripts/classes/sp_ac/sp_ac_kit.gd": {"revision": 1, "fields": ["grace"], "omitted": {}}}
```

O kit de fixture completo, que exercita todos os ganchos, está em
`scripts/classes/fixture/fixture_kit.gd`, e o teste em `tests/e09/kit_seam_test.gd`. Os
ganchos de T1.1 (multiplicador de dano recebido e fontes temporárias) têm teste próprio,
`tests/e09/kit_seam_hooks_v2_test.gd`, com uma subclasse do kit de fixture. Os de T1.2
(custo efetivo e commit da origem) estão em `tests/e09/kit_seam_hooks_v3_test.gd`; o kit de
fixture expõe `cost_scale`, `cost_offset` (identidade por padrão) e `base_commits`.

## 13. Limitações conhecidas (para quem consome)

- **Políticas de kit em itens (`EffectDefinition.Kind.KIT_RULE`).** Não entram pela costura:
  `BuildEffectComposer` lê `BuildEffectCatalog.KIT_POLICIES` direto, e esse arquivo não é de
  T1. Um kit que precise disso pede a mudança à sessão de arquitetura.
- **Teste de catálogo do E05.** `tests/e05_evolution_catalog_test.gd` espera exatamente quatro
  destinos do Mago (`elementalist, spiritualist, mg_sp, mg_ar`). Quando K2 ou K4 ligar
  `ready_for_play`, esse teste falha por expectativa, não por defeito; a atualização
  precisa de decisão da arquitetura (o arquivo não é de nenhuma tarefa de kit). O mesmo vale
  para o Espadachim se algum teste listar os destinos dele.
- **Exportação.** Os fragmentos são JSON lidos com `FileAccess`. O `include_filter` de
  `export_presets.cfg` precisa ganhar `scripts/classes/*/snapshot_manifest.json`,
  `scripts/classes/snapshot_manifest.json` e `scripts/systems/*/snapshot_manifest.json`
  antes do candidato (T10). Sem isso, a captura de um jogador com kit falha no PCK com
  `unknown_runtime_kind`, sem perder dados.
- **Mapa plano antigo.** `break_sight` não impede a aquisição pela posição
  (`can_be_acquired_by(position)` não conhece o observador); só a ameaça.
- **Ciclos de script no Godot 4.7.2.** `player_actor.gd` não nomeia `EnemyActor` como tipo
  (`as`, anotação ou acesso estático); chega ao livro de ameaça por `has_method`/`get`.
  O ciclo jogador ↔ inimigo entre scripts não é liberado na saída do motor ("resources still
  in use"), e o verificador trata isso como falha da etapa. `kit_seam_test` impede que a
  referência volte. Um kit pode usar `EnemyActor` no próprio módulo, porque o registro carrega
  os módulos por caminho e eles não entram no grafo de compilação de `PlayerActor`. Se uma
  etapa passar a acusar recursos presos na saída, procure primeiro uma referência nova entre
  scripts que feche um ciclo.
