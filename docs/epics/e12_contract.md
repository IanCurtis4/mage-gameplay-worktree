# E12 — contrato de arquitetura

Índice, decisões e tarefas: [e12.md](e12.md). Precedência: [WORKFLOW](../WORKFLOW.md) para o
fluxo; este contrato para o E12; o [contrato E09](e09_contract.md) e a
[API da costura](e09/t1_kit_seam_api.md) nos pontos não substituídos; E00 e as autoridades de
[ARCHITECTURE](../ARCHITECTURE.md) no resto.

Este contrato **não muda regra de jogo**. Dano, custo, recarga, ameaça, preparo, cancelamento e
save continuam exatamente como no candidato E09. Uma tarefa que precise mudar regra para
mostrar algo para e devolve a pergunta à sessão de arquitetura.

Cores, tamanhos, posições e fontes não estão fixados aqui: são ajuste de playtest, escolhidos
por H3/H4 no estilo atual do HUD e registrados no recibo com captura.

## 1. Ponto de partida (candidato E09, `a0c81525`)

| Peça | Fonte autoritativa hoje | Lacuna |
|---|---|---|
| Graça | `SanctuaryAuthority.grace` (`charges`, `cap`, `is_unlimited()`, `unlimited_remaining`); `SanctuaryAuthority.describe()` | não chega à UI |
| Zona do Santuário | `SanctuaryZone.describe()`: `role`, `shape`, `radius`, `half_angle`, `anchor_mode`, `element`, `remaining`, `duration`, `center` | o sistema não desenha a zona (limitação 5 da T5); o kit só a desenha no instante do cast, e a cor persistente não segue o elemento (limitação 1 da K2) |
| Égide, Selo | `SanctuaryAuthority.aegis_remaining`, `marked_target_id`, marca `seal_key` | não chegam à UI |
| Sentença e vítima | marca `FlankRules.VICTIM_MARK` (`flank_victim`) na vítima, com `"sentence"` no valor, teto `FlankRules.SENTENCE_CAP` (5); `FlankAuthority.victim(player)` e `sentence(player)` | não chega à UI; `FlankAuthority` não tem `describe()` |
| Refração da Lâmina Arcana | `mg_la_kit.refraction_charges`, `refraction_recharge`, `REFRACTION_RECHARGE` | o HUD mostra só a recarga canônica de 1,0 s; sem carga o atalho parece pronto (limitação 1 da K4) |
| Cast do jogador | `PlayerActor.active_cast_skill`, `active_cast_rank`, `active_cast_total`, `active_cast_remaining`, nos dois caminhos (`_advance_active_cast` no mapa plano; `_world_prepared_cast` no mundo); `cancel_active_cast()` emite `presentation_action(&"cast_cancel")` | só texto em `main.gd` ("Conjurando X · 1.2s" e "CONJURANDO 1.2s") |
| Cast de inimigo | `EnemyActor._mob_cast` (`cast_time`, `remaining`, skill capturada por `MobSkillAdapters.capture`); `presentation_action(&"cast" / &"cast_cancel" / &"cast_release")` | só animação |
| Barras sobre atores | `CombatActor._draw`: barra de HP e, logo abaixo, os losangos de Ferida do Berserker | sem barra de cast |

## 2. C1 — leitura de estado do kit (tarefa H1)

### 2.1 Gancho

```gdscript
## ClassKit (scripts/classes/class_kit.gd)
## Pure read of the kit state for the HUD and the world overlay (E12 C1).
## Same purity rule as skill_cost and temporary_stat_sources: no state change, no node
## creation, no signal, no randomness; may run while the tree is paused.
func hud_state(_player: PlayerActor) -> Dictionary:
	return {}
```

- `PlayerActor.kit_hud_state() -> Dictionary`: `{}` sem kit; senão chama `kit.hud_state(self)`,
  valida por `KitHudState.validate()` e devolve o DTO. Um DTO inválido vira `{}` e um único
  aviso por código de erro e por kit (sem inundar o log a cada quadro). Nunca falha o tick.
- O gancho pode ser chamado a cada atualização do HUD (por quadro). Deve ser barato: sem busca
  na árvore inteira por chamada; `FlankAuthority.victim()` já usa cache de dica.
- Os valores vêm das autoridades; o kit não recalcula fórmula para o HUD. Um número mostrado que
  dependa de fórmula (por exemplo, dano do Juízo) **não** entra no E12.

### 2.2 Formato `ragrpg_kit_hud_v1`

Dicionário; chaves desconhecidas são erro. Todo número é finito; `remaining <= total` quando os
dois existem; contagens são `int >= 0`.

| Chave | Tipo | Conteúdo |
|---|---|---|
| `schema` | `String` | `"ragrpg_kit_hud_v1"` (obrigatória) |
| `kit_id` | `StringName` | igual a `kit.kit_id()` (obrigatória) |
| `resources` | `Array[Dictionary]` | recursos do painel, na ordem de exibição (opcional) |
| `skills` | `Dictionary` | `skill_id → estado de prontidão do kit` (opcional) |
| `zones` | `Array[Dictionary]` | zonas a desenhar no chão (opcional) |
| `target_marks` | `Array[Dictionary]` | marcadores sobre atores (opcional) |

**`resources[i]`**

| Chave | Tipo | Regra |
|---|---|---|
| `id` | `StringName` | único no DTO, com o prefixo do kit ou do sistema (`paladin_`, `sanctuary_`, `flank_`…) |
| `label` | `String` pt-BR | não vazio |
| `kind` | `StringName` | `&"pips"` (contagem com teto), `&"charges"` (cargas com recarga) ou `&"timer"` (prazo) |
| `value`, `max` | `int` | `pips`/`charges`: `0 <= value`, `max >= 1`; `value <= max` salvo `unlimited` |
| `unlimited` | `bool` | só `pips`; quando verdadeiro, a UI mostra ∞ e o prazo |
| `remaining`, `total` | `float` | segundos; `timer` exige os dois; `charges` usa para a recarga da próxima carga; `pips` com `unlimited` usa para o prazo do modo |
| `element` | `StringName` | vazio ou `none`, `fire`, `ice`, `lightning`, `tricolor`, `light`, `arcane` |

**`skills[skill_id]`** (só skills de `kit.skill_definitions()`; o resto é erro `kit_hud_unknown_skill`)

| Chave | Tipo | Regra |
|---|---|---|
| `ready` | `bool` | falso quando o kit recusaria o cast por estado próprio |
| `reason` | `StringName` | o mesmo `error_code` que `can_cast` devolveria; vazio se `ready` |
| `charges`, `max_charges` | `int` | opcionais; juntos |
| `recharge_remaining`, `recharge_total` | `float` | opcionais; juntos |

A recarga canônica (`PlayerActor.skill_cooldown`) continua sendo lida da autoridade atual. O
estado do kit só **acrescenta** a sua razão de não estar pronto; ele não substitui nem esconde a
recarga canônica.

**`zones[i]`**

| Chave | Tipo | Regra |
|---|---|---|
| `role` | `StringName` | papel da zona no kit |
| `space` | `StringName` | `&"world"` (chão do mundo da expedição) ou `&"flat"` (arena antiga) |
| `center` | `Vector3` | no mundo, ponto do chão; no plano, `Vector3(x, y_canvas, 0)` com a posição da arena |
| `shape` | `StringName` | `SanctuaryRules.SHAPES` (círculo, cone, círculo ampliado) |
| `radius` | `float` | `> 0` |
| `half_angle` | `float` | radianos, só no cone |
| `facing` | `Vector3` | direção no chão (cone); no plano, `Vector3(x, y, 0)` do canvas |
| `element` | `StringName` | como em `resources` |
| `remaining`, `total` | `float` | prazo da zona |

**`target_marks[i]`**

| Chave | Tipo | Regra |
|---|---|---|
| `target_id` | `int` | ID de instância de um `CombatActor` vivo |
| `key` | `StringName` | `flank_victim`, `paladin_seal` ou outra chave de marca do kit/sistema |
| `kind` | `StringName` | `&"pips"` ou `&"badge"` |
| `value`, `max` | `int` | `pips`: `0 <= value <= max`, `max >= 1` |
| `element` | `StringName` | como em `resources` |

### 2.3 `KitHudState`

`scripts/classes/kit_hud_state.gd`, `class_name KitHudState`, só estático:
- `const SCHEMA := "ragrpg_kit_hud_v1"`;
- `validate(state: Dictionary, kit: ClassKit) -> Dictionary` →
  `{"ok": bool, "error_code": StringName, "detail": String}`;
- códigos: `kit_hud_invalid_schema`, `kit_hud_kit_mismatch`, `kit_hud_unknown_key`,
  `kit_hud_invalid_resource`, `kit_hud_duplicate_resource`, `kit_hud_unknown_skill`,
  `kit_hud_invalid_skill`, `kit_hud_invalid_zone`, `kit_hud_invalid_mark`,
  `kit_hud_non_finite`.
- `{}` é válido (kit sem HUD) e não gera aviso.

### 2.4 Prova (H1)

- O kit de fixture (`scripts/classes/fixture/`) devolve um DTO que usa todas as chaves e
  `kind`s, e uma variante inválida por código de erro.
- Pureza: chamar `hud_state` 100 vezes não muda nenhum campo do fragmento de snapshot do kit
  nem `kit_time`; funciona com a árvore pausada.
- Nenhuma revisão de fragmento muda; os 4 kits de produção continuam devolvendo `{}` até H2.

## 3. C2 — relógio de cast comum (tarefa H1)

```gdscript
## CombatActor (scripts/actors/combat_actor.gd). Read-only view of the cast clock (E12 C2).
## Default: no cast. PlayerActor and EnemyActor override; no rule, signal or field changes.
func cast_progress() -> Dictionary:
	return {"active": false}
```

Com cast ativo:

| Chave | Tipo | Valor |
|---|---|---|
| `active` | `bool` | `true` |
| `skill_id` | `StringName` | skill em preparo |
| `label` | `String` pt-BR | `display_name` da definição canônica (`ClassCatalog.skill_definition`, que já inclui kits e skills de mob) |
| `total`, `remaining` | `float` | segundos, `0 < total`, `0 <= remaining <= total` |
| `kind` | `StringName` | `&"cast"`; `&"channel"` fica reservado (nenhum canal com duração existe hoje) |
| `category` | `StringName` | jogador: `&"player"`; inimigo: `occurrence.category_id` quando é uma das `MobCatalog.CATEGORIES`, `&"boss"` com `hard_controls.boss`, senão `&"normal"` (mesma fonte de `FlankRules.category_of`, sem importar o sistema de flanco no ator) |

- **Jogador:** lê `active_cast_*` nos dois caminhos. Skill sem preparo (`skill_cast_time == 0`)
  nunca aparece como ativa.
- **Inimigo:** lê `_mob_cast` somente quando `cast_time > 0`.
- **Pausa:** os relógios já congelam; a leitura não avança nada.
- `CombatActor.overhead_bar_y() -> float`: a altura da barra de HP sobre o ator, extraída da
  conta que `_draw` já faz, sem mudar o resultado visual. A barra de cast e os marcadores usam
  essa altura como referência.
- `player_actor.gd` continua sem nomear `EnemyActor` (A10 do E09).

**Prova (H1):** cast com preparo no mapa plano e no mundo (início, meio, fim, cancelamento por
movimento e por Esc); cast instantâneo nunca ativo; cast de mob com e sem `cast_time`; pausa no
meio do cast mantém `remaining`; regressão por impacto dos testes de cast existentes sem mudar
expectativas.

## 4. C3 — componentes visuais (tarefa H3)

Todos são apresentação: não leem nem escrevem regra, timers ou save, e recebem dados prontos.

| Componente | Arquivo | API mínima |
|---|---|---|
| `CastBar` (`Control`) | `scripts/ui/hud/cast_bar.gd` | `set_progress(progress: Dictionary)`; `{"active": false}` esconde; mostra nome, tempo restante (`%.1fs`) e preenchimento `1 - remaining/total`; `flash(kind: StringName)` com `&"cancel"` ou `&"release"` |
| `ActorCastBar` | `scripts/presentation/actor_cast_bar.gd` | `static func draw_overhead(canvas: CanvasItem, progress: Dictionary, top_y: float, width: float, flash: StringName = &"", show_label: bool = false) -> void`; mesma razão e mesmas cores de `CastBar` |
| `KitResourcePanel` (`Control`) | `scripts/ui/hud/kit_resource_panel.gd` | `set_state(dto: Dictionary)`; desenha `resources` (pips, ∞ com prazo, cargas com recarga, prazos); `{}` esconde |
| `KitWorldOverlay` (`Node2D`) | `scripts/presentation/kit_world_overlay.gd` | `mode` = `&"ground"` (zonas, abaixo dos atores) ou `&"overhead"` (marcadores, acima); `set_state(dto: Dictionary, actors: Dictionary)` com `target_id → CombatActor`; zonas do mundo projetadas ponto a ponto por `expedition_projection.gd` (`ProjectionMath.project`), zonas do plano em coordenadas da arena |

- Regras visuais fixas: Sentença e Graça em pontos (como os losangos do Berserker); ∞ quando
  `unlimited`; nome da skill do inimigo só com `show_label` (H4 liga para `elite`,
  `rare_elite` e `boss`, D5).
- Uma paleta única por elemento, compartilhada por painel e overlay, em
  `scripts/ui/hud/` ou `scripts/presentation/` (arquivo de H3).
- DTO malformado: o componente não desenha nada e não gera SCRIPT ERROR (o DTO já chega
  validado por `PlayerActor.kit_hud_state`, mas o componente não confia nisso).
- **Prova (H3):** DTOs de fixture cobrindo cada `kind`, ∞, zona em cone e círculo nos dois
  espaços, marcadores com 0 e 5; `cast_progress` de fixture com 0 %, 50 % e 100 %, cancelamento
  e liberação; capturas nativas de cada estado em `docs/epics/e12/h3_*.png`.

## 5. C4 — estado de HUD dos kits (tarefa H2)

Cada kit implementa `hud_state(player)` na própria pasta, lendo as autoridades. Lista mínima
(H2 pode acrescentar prazos coerentes com a ficha e registra a lista final no recibo):

| Kit | `resources` | `skills` | `zones` | `target_marks` |
|---|---|---|---|---|
| Paladino `sp_ac` | Graça (`pips`, ∞ + prazo na Hora); prazos do Juramento, da Égide e da Hora | — (ou o que `can_cast` recusa por Graça) | cone do Juramento; círculo na Hora | Selo (`badge`) no alvo selado |
| Taumaturgo `mg_ac` | Graça (`pips`, ∞ + prazo na Aurora); prazo do Círculo com o elemento atual; prazos do Coro e da Aurora | as recusas por estado próprio do kit | Círculo Votivo, com o elemento atual (fecha a limitação 1 da K2) | — |
| Duelista `sp_la` | prazos do Duelo e do Aparo automático; Guarda Paciente quando pronta | as recusas por estado próprio do kit | — | Sentença (`pips`, teto 5) na vítima |
| Lâmina Arcana `mg_la` | Refração (`charges`, recarga própria); prazo da ocultação | Refração com `ready`, `reason = arcane_blade_refraction_recharging`, cargas e recarga (fecha a limitação 1 da K4) | — | Sentença (`pips`, teto 5) na vítima; reflexos do Espectro (`badge`) |

- `FlankAuthority.describe(player) -> Dictionary` (novo, leitura): vítima, Sentença, teto,
  ocultação e aparo abertos com prazos. `SanctuaryAuthority.describe()` pode ganhar chaves de
  leitura (por exemplo, `unlimited_remaining`) sem mudar as existentes.
- **Invariante A6 (obrigatória, por kit):** em estados gerados pelo combate integrado de cada
  kit, para toda skill em `skills`, `ready == false` se e só se `can_cast` recusa por estado do
  kit, e `reason` é o mesmo `error_code`.
- **Outras invariantes:** o DTO valida em todo tick do combate integrado; `hud_state` não muda
  o snapshot exato do kit (comparação antes e depois); Graça e Sentença do DTO batem com
  `grace.charges` e com a marca da vítima; com o jogador morto e depois do retorno, o DTO segue
  o estado das autoridades.
- Nenhuma revisão de `snapshot_manifest.json` muda (A5).

## 6. C5 — ligação no HUD (tarefa H4)

- `main.gd`:
  - lê `player.kit_hud_state()` **uma vez** por atualização do HUD e repassa o mesmo DTO ao
    painel e aos dois overlays (sem chamar o kit por ator);
  - painel de recurso junto de VIDA e SP, só para jogador com kit;
  - `CastBar` centralizada acima da barra de atalhos, alimentada por `player.cast_progress()`;
    a linha de ajuda "mover / Direito / Esc cancela" continua; o texto "Conjurando X · Ns" e o
    estado "CONJURANDO Ns" do atalho saem, substituídos pela barra;
  - flashes ligados aos `presentation_action` existentes (`cast_cancel`, `cast_release`), sem
    sinal novo;
  - overlays `ground` e `overhead` na camada do mundo, com o mapa `target_id → ator` dos inimigos
    vivos que o `RunController` já conhece.
- `battle_controls.gd`: o atalho de uma skill com `skills[id].ready == false` mostra o estado
  "sem carga" (ou a razão traduzida em pt-BR) e a recarga do kit, além da recarga canônica.
  Prioridade de exibição: recarga canônica > recarga do kit > pronto.
- `combat_actor.gd` (`_draw`, dono transferido de H1): chama `ActorCastBar.draw_overhead` logo
  abaixo da barra de HP quando `cast_progress().active`, com `show_label` para `elite`,
  `rare_elite` e `boss`, e pede `queue_redraw()` só enquanto há cast ou flash.
- O onboarding da T9 continua como está.
- **Prova (H4):** teste integrado com perfis de fixture das quatro híbridas (perfis da T9, job
  40) no mapa plano e no mundo: painel aparece só com kit; atalho da Refração sem carga mostra o
  estado e o cast continua sendo recusado pela regra; barra do jogador cobre o preparo inteiro;
  barra do inimigo aparece em cast de mob; nada disso muda dano, SP, recarga ou snapshot
  (comparação antes e depois). Capturas nativas das quatro híbridas e de um cast de mob, nos
  dois espaços, em `docs/epics/e12/h4_*.png`.

## 7. C6 — integração e candidato (tarefas H5 e H6)

- **Composição.** Branch `claude/e12-candidato` a partir do commit de arquitetura, merge na
  ordem do DAG, só conflitos mecânicos. Pela D6, depois do aceite do E09 em `master`, a
  composição é rebaseada sobre `master` e revalidada por impacto antes do playtest.
- **Verificação.** Suíte completa de `tools/verify.ps1` (sem `-Test`, com `editor_import` em
  worktree limpo), com o executável de [TESTING](../TESTING.md) passado em `-GodotPath`.
  Supervisão Luna (H6): conclusão, ausência de SCRIPT ERROR, timeouts e hashes.
- **Release.** Exportação para
  `C:/Users/João Pedro/Documents/ChatGPT/RagRPG/.tools/playtest_e12/<sha>/`; sondas no PCK dos
  scripts novos (`kit_hud_state`, `cast_bar`, `kit_resource_panel`, `actor_cast_bar`,
  `kit_world_overlay`). Perfis de revisão da T9 (`tools/e09_review_profiles.gd`) e smoke.
- **Medição.** Sonda de multidão contra a mesma referência do E09, registrada sem alegar FPS; o
  objetivo é mostrar que ler o DTO por quadro e desenhar barras não cria custo visível.
- **Roteiro** em `docs/epics/e12/playtest_guide.md`: com cada híbrida, o que observar nos
  marcadores e nas barras; um mob com cast; pausa no meio de um cast.
- **Playtest habitual.** Avanço só depois da aprovação técnica e do aceite do E09, pelo
  procedimento do WORKFLOW, preservando alterações locais e o save pessoal. Sem `master`, sem
  push.
