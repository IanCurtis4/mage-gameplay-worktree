# E12 H1 — API da costura de HUD (C1, C2)

Leitores: H2 (estado de HUD dos quatro kits), H3 (componentes visuais) e H4 (ligação no HUD).
Este documento basta para usar a costura. O contrato está em
[e12_contract.md](../e12_contract.md), §2 e §3; o recibo da entrega, em
[h1_delivery.md](h1_delivery.md). A costura de kits do E09 continua valendo:
[t1_kit_seam_api.md](../e09/t1_kit_seam_api.md).

Nada aqui muda regra, fórmula, sinal de gameplay ou campo/revisão de snapshot. São só leituras.

## 1. Mapa de arquivos

| Arquivo | Papel |
|---|---|
| `scripts/classes/class_kit.gd` (`ClassKit.hud_state`) | Gancho de leitura do kit; padrão `{}` |
| `scripts/classes/kit_hud_state.gd` (`KitHudState`) | Validador estático do formato `ragrpg_kit_hud_v1` |
| `scripts/actors/player_actor.gd` (`kit_hud_state`, `cast_progress`) | Leitura validada do kit e relógio de cast do jogador |
| `scripts/actors/enemy_actor.gd` (`cast_progress`) | Relógio de cast do mob |
| `scripts/actors/combat_actor.gd` (`cast_progress`, `overhead_bar_y`) | Padrão sem cast e altura da barra de HP |
| `scripts/classes/fixture/hud/fixture_hud_kit.gd` | Kit de fixture com o DTO completo e uma variante inválida por código |
| `scripts/classes/fixture/hud/snapshot_manifest.json` | Fragmento do kit de fixture (`hud_variant`) |
| `tests/e12/hud_seam_test.gd` | Prova da costura (descoberto por `tools/verify.ps1`, grupo `tests/e12`) |

## 2. Estado do kit para o HUD (C1)

### 2.1 Gancho do kit

```gdscript
## ClassKit (sobrescreva no módulo do kit)
func hud_state(player: PlayerActor) -> Dictionary:
	return {}
```

- **Puro.** Mesma regra de `skill_cost` e `temporary_stat_sources`: não muda estado, não cria
  nó, não emite sinal, não sorteia. Pode rodar a cada atualização do HUD e com a árvore
  pausada.
- **Barato.** Sem busca na árvore por chamada. Use as autoridades e caches que já existem
  (`FlankAuthority.victim()` já tem dica).
- **Sem fórmula.** Os valores vêm das autoridades (`SanctuaryAuthority`, `FlankAuthority`,
  estado do kit). Número que dependa de fórmula (por exemplo, dano do Juízo) não entra.
- `{}` significa "sem HUD" e é sempre válido, sem aviso.

### 2.2 Leitura pelo jogador

```gdscript
player.kit_hud_state() -> Dictionary
```

- Sem kit: `{}`.
- Com kit: chama `kit.hud_state(player)`, valida por `KitHudState.validate` e devolve o
  **mesmo** dicionário quando válido.
- Inválido: devolve `{}` e emite **um** `push_warning` por par (kit, código de erro), nunca
  repetido (`KitHudState.reported_warnings()` lista os pares `"<kit_id>:<código>"`). O tick
  nunca falha.
- H4 lê **uma vez** por atualização do HUD e repassa o mesmo DTO ao painel e aos overlays.

### 2.3 Formato `ragrpg_kit_hud_v1`

Regras gerais, verificadas por `KitHudState.validate`:
- chave desconhecida em qualquer nível é erro (o código é o da seção onde ela está);
- todo número é finito (floats e componentes de `Vector2`/`Vector3`);
- campos `int` exigem `TYPE_INT`; campos de segundos e distâncias (`float`) aceitam `int` ou
  `float`;
- `StringName` exige `StringName` (`&"..."`), não `String`; `label` e `schema` são `String`;
- um par de prazo (`remaining`/`total`, `recharge_remaining`/`recharge_total`) vem completo ou
  ausente, com `total > 0` e `0 <= remaining <= total`.

**Topo**

| Chave | Tipo | Regra |
|---|---|---|
| `schema` | `String` | `"ragrpg_kit_hud_v1"` (`KitHudState.SCHEMA`), obrigatória |
| `kit_id` | `StringName` | igual a `kit.kit_id()`, obrigatória |
| `resources` | `Array` de `Dictionary` | opcional; ordem de exibição |
| `skills` | `Dictionary` `StringName → Dictionary` | opcional |
| `zones` | `Array` de `Dictionary` | opcional |
| `target_marks` | `Array` de `Dictionary` | opcional |

**`resources[i]`**

| Chave | `pips` | `charges` | `timer` |
|---|---|---|---|
| `id` (`StringName`) | obrigatório | obrigatório | obrigatório |
| `label` (`String`, não vazio, pt-BR) | obrigatório | obrigatório | obrigatório |
| `kind` (`StringName`) | `&"pips"` | `&"charges"` | `&"timer"` |
| `value`, `max` (`int`) | obrigatórios; `value >= 0`, `max >= 1`, `value <= max` salvo `unlimited` | obrigatórios; `value >= 0`, `max >= 1`, `value <= max` | proibidos |
| `unlimited` (`bool`) | opcional | proibido | proibido |
| `remaining`, `total` | obrigatórios se e só se `unlimited` (prazo do modo ∞) | opcionais (recarga da próxima carga) | obrigatórios |
| `element` (`StringName`) | opcional | opcional | opcional |

- `id` único no DTO (`kit_hud_duplicate_resource`) e com prefixo: o do kit
  (`ClassKitRegistry.IDENTITIES[kit_id]["prefix"]`: `paladin_`, `thaumaturge_`, `duelist_`,
  `arcane_blade_`) ou um de sistema (`KitHudState.SYSTEM_PREFIXES`: `sanctuary_`, `flank_`),
  com algo depois do prefixo. Outro prefixo de sistema exige pedido à arquitetura.
- `element`: vazio, `none`, `fire`, `ice`, `lightning`, `tricolor`, `light` ou `arcane`
  (`KitHudState.ELEMENTS`).

**`skills[skill_id]`**

| Chave | Tipo | Regra |
|---|---|---|
| (chave) | `StringName` | uma skill de `kit.skill_definitions()`; outra é `kit_hud_unknown_skill` |
| `ready` | `bool` | obrigatória; falsa quando o kit recusaria o cast por estado próprio |
| `reason` | `StringName` | vazia (ou ausente) com `ready`; **não vazia** sem `ready`, igual ao `error_code` de `can_cast` (A6) |
| `charges`, `max_charges` | `int` | juntos; `max_charges >= 1`, `0 <= charges <= max_charges` |
| `recharge_remaining`, `recharge_total` | número | juntos; par de prazo |

A recarga canônica (`PlayerActor.skill_cooldown`) continua sendo lida da autoridade atual; o
kit só acrescenta a sua razão (contrato §2.2). A invariante A6 é de H2.

**`zones[i]`**

| Chave | Tipo | Regra |
|---|---|---|
| `role` | `StringName` | não vazio |
| `space` | `StringName` | `&"world"` ou `&"flat"` |
| `center` | `Vector3` | mundo: ponto do chão; plano: `Vector3(x, y_canvas, 0)`, com `z == 0` |
| `shape` | `StringName` | `SanctuaryRules.SHAPES` (`circle`, `cone`, `wide_circle`) |
| `radius` | número | `> 0` |
| `half_angle` | número | só no cone, onde é obrigatório; `0 < half_angle <= PI` |
| `facing` | `Vector3` | obrigatório no cone, opcional nos outros; não nulo; no plano, `z == 0` |
| `element` | `StringName` | como em `resources` |
| `remaining`, `total` | número | opcional, par de prazo |

**`target_marks[i]`**

| Chave | Tipo | Regra |
|---|---|---|
| `target_id` | `int` | `> 0`; ID de instância de um `CombatActor` vivo |
| `key` | `StringName` | não vazia (`flank_victim`, `paladin_seal`…); par `(target_id, key)` único |
| `kind` | `StringName` | `&"pips"` ou `&"badge"` |
| `value`, `max` | `int` | `pips`: obrigatórios, `max >= 1`, `0 <= value <= max`; `badge`: proibidos |
| `element` | `StringName` | como em `resources` |

**Decisão de H1 sobre `target_id`.** O validador confere tipo e sinal, mas não a vida do alvo:
uma vítima que morre no quadro não pode apagar o HUD inteiro. H2 só publica IDs de atores vivos;
o overlay de H3/H4 desenha só os IDs presentes no mapa `target_id → CombatActor` que recebe e
ignora os outros sem erro.

### 2.4 `KitHudState`

```gdscript
KitHudState.SCHEMA                                  # "ragrpg_kit_hud_v1"
KitHudState.validate(state: Dictionary, kit: ClassKit) -> Dictionary
	# {"ok": bool, "error_code": StringName, "detail": String}
KitHudState.checked(state, kit) -> Dictionary       # state se válido; {} e um aviso por (kit, código)
KitHudState.reported_warnings() -> Array[String]    # pares "<kit_id>:<código>" já avisados
KitHudState.reset_reports()                         # só testes
KitHudState.ERROR_CODES, TOP_KEYS, RESOURCE_KEYS, SKILL_KEYS, ZONE_KEYS, MARK_KEYS,
RESOURCE_KINDS, MARK_KINDS, SPACES, ELEMENTS, SYSTEM_PREFIXES   # constantes públicas
```

`detail` aponta o caminho do primeiro problema (`resources[1].value`, `zones[0].half_angle`).
`validate` não altera o dicionário recebido. As skills válidas de cada script de kit ficam em
cache (dados de catálogo são imutáveis), então `skill_definitions()` não roda por quadro.

Ordem das verificações: `schema` → `kit_id` → chaves do topo → números não finitos →
`resources` → `skills` → `zones` → `target_marks`. O primeiro erro encontrado é o devolvido.

| Código | Quando |
|---|---|
| `kit_hud_invalid_schema` | `schema` ausente, não `String` ou diferente de `SCHEMA` |
| `kit_hud_kit_mismatch` | `kit_id` ausente, não `StringName`, diferente de `kit.kit_id()`, ou kit nulo |
| `kit_hud_unknown_key` | chave do topo fora de `TOP_KEYS` (ou não `String`) |
| `kit_hud_invalid_resource` | `resources` não é `Array`, ou uma entrada fere a tabela de `resources` |
| `kit_hud_duplicate_resource` | dois `resources` com o mesmo `id` |
| `kit_hud_unknown_skill` | chave de `skills` que não é skill do kit (ou não `StringName`) |
| `kit_hud_invalid_skill` | `skills` não é `Dictionary`, ou uma entrada fere a tabela de `skills` |
| `kit_hud_invalid_zone` | `zones` não é `Array`, ou uma entrada fere a tabela de `zones` |
| `kit_hud_invalid_mark` | `target_marks` não é `Array`, entrada inválida ou par `(target_id, key)` repetido |
| `kit_hud_non_finite` | qualquer `float` ou componente de vetor `NaN`/`±INF` |

### 2.5 Kit de fixture

`scripts/classes/fixture/hud/fixture_hud_kit.gd` estende o kit de fixture do E09 e fica fora do
registro de produção. Instale com `ClassKitRegistry.install_fixture(&"sp_ac", FixtureHudKit.new(&"sp_ac"))`
(ou outro dos quatro IDs) e crie o jogador do kit como de costume.

- `hud_variant = FixtureHudKit.VALID` (padrão): o DTO completo de `valid_state(player)`. Usa
  todas as chaves de todas as seções; `pips` com e sem `unlimited`, `charges` com recarga,
  `timer`; uma skill pronta e uma recusada com cargas e recarga; zonas em cone (mundo), círculo
  (plano, centrado no jogador) e círculo ampliado (mundo, sem prazo); marcadores `pips` e
  `badge` sobre `victim_id` (ou o próprio jogador, quando não há vítima).
- `hud_variant = FixtureHudKit.EMPTY`: `{}`.
- `hud_variant = <código>` (cada item de `KitHudState.ERROR_CODES`): o DTO completo com um
  único defeito que produz exatamente esse código.
- `FixtureHudKit.variants()` lista as 12 variantes.

H3 pode usar `valid_state(player)` (ou `hud_state` com cada variante) para desenhar e recusar
DTOs nos testes de componente.

## 3. Relógio de cast (C2)

```gdscript
actor.cast_progress() -> Dictionary   # todo CombatActor
```

Sem cast: exatamente `{"active": false}`. Com cast, exatamente estas sete chaves:

| Chave | Tipo | Valor |
|---|---|---|
| `active` | `bool` | `true` |
| `skill_id` | `StringName` | skill em preparo |
| `label` | `String` pt-BR | `ClassCatalog.skill_definition(skill_id).display_name` (kits e skills de mob incluídos); `"Conjuração"` se faltar |
| `total` | `float` | segundos, `> 0` |
| `remaining` | `float` | segundos, `0 <= remaining <= total` |
| `kind` | `StringName` | `&"cast"` (`&"channel"` reservado; nenhum canal com duração existe hoje) |
| `category` | `StringName` | jogador: `&"player"`; inimigo: `normal`, `rare`, `elite`, `rare_elite` ou `boss` |

- **Jogador.** Lê `active_cast_skill`, `active_cast_total` e `active_cast_remaining`, comuns ao
  mapa plano (`begin_skill_cast` → `_advance_active_cast`) e ao mundo
  (`request_world_skill` com preparo → `_advance_world_cast`). Skill sem preparo
  (`skill_cast_time == 0`) nunca aparece ativa, nem durante os próprios sinais do commit.
- **Inimigo.** Lê `_mob_cast` só quando `cast_time > 0`. `skill_id` vem do pedido capturado
  (`MobSkillAdapters.capture`). `category`: `occurrence.category_id` quando está em
  `MobCatalog.CATEGORIES`; senão `&"boss"` com `hard_controls.boss`; senão `&"normal"`. É a
  mesma fonte de `FlankRules.category_of`, sem importar o sistema de flanco no ator.
- **Padrão.** `CombatActor` devolve `{"active": false}`; um aliado futuro sobrescreve o método.
- **Pausa.** Os relógios já congelam; a leitura não avança nada.
- **Cancelamento e liberação.** Continuam sendo os `presentation_action` existentes
  (`&"cast"`, `&"cast_cancel"`, `&"cast_release"`), sem sinal novo. Depois de um cancelamento
  ou do fim do preparo, a leitura volta a `{"active": false}` no mesmo instante. No mundo, o
  movimento chega ao ator pela mesma chamada do Esc (`main.gd` chama `cancel_active_cast` antes
  de adotar a rota); no plano, `move_to` cancela.

```gdscript
actor.overhead_bar_y() -> float
```

Altura local (y) do topo da barra de HP sobre o ator, a mesma conta que `_draw` usa:
`-_sprite_visible_height * sprite_visual_scale - 8` com sprite pintado; senão
`-54 * sprite_visual_scale`. A barra tem 6 px de altura e largura 52 (104 com
`sprite_visual_scale > 1`). A barra de cast e os marcadores usam essa altura como referência
(por exemplo, `overhead_bar_y() + 6 + margem` logo abaixo da barra de HP).

## 4. O que fica para cada tarefa

| Tarefa | Usa |
|---|---|
| H2 | sobrescreve `hud_state` nos quatro kits; valida por `KitHudState`; prova A6 |
| H3 | desenha DTOs (`valid_state` e variantes do fixture) e `cast_progress` de fixture; não confia no DTO |
| H4 | `player.kit_hud_state()` uma vez por atualização; `cast_progress()` do jogador e dos inimigos; `overhead_bar_y()` em `_draw` (dono transferido) |

## 5. Limitações conhecidas

- A vida do `target_id` não é validada (seção 2.3); o consumidor faz a busca.
- O cache de skills de `KitHudState` é por script e `kit_id`. Um kit que gere skills diferentes
  para o mesmo script e o mesmo `kit_id` não existe e não é suportado.
- O aviso de DTO inválido é por `kit_id` e código durante o processo; uma segunda instância do
  mesmo kit com o mesmo defeito não repete o aviso.
- A pureza de `hud_state` dos kits de produção é responsabilidade de H2 (comparação do snapshot
  exato antes e depois); H1 prova a pureza com o kit de fixture e compara os campos de primeiro
  nível dos kits de produção, que hoje devolvem `{}`.
