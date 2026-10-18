# E07-I0 — inventário factual do runtime

18/10/2026 · Sol / esforço Médio · **ENTREGUE, aguardando validação e integração
pela coordenação**. Este documento subsidia os contratos Astra; não define uma
arquitetura concorrente, não aprova runtime e não reabre a auditoria de E06.

## Base, propriedade e método

- Checkout: `C:/Users/João Pedro/Documents/ChatGPT/RagRPG`.
- Branch observada: `codex/playtest`; HEAD/base conferido:
  `029b8ca1d7b1752929d549cbeb51e534ea6d3c1d`.
- Durante a tarefa, HEAD avançou externamente para
  `82948a66e5d45f678366d6d474c09851063b456f` (`docs: register E07 architecture
  and inventory chats`). O delta conferido contém somente `docs/EPIC_THREADS.md`
  e `docs/epics/e07_launch_queue.md`; as referências de runtime/testes permanecem
  na mesma base. Esta tarefa não realizou esse commit.
- Runtime aceito informado no despacho:
  `a4f846ebaef45e5fa28c113331b6e75b64759525`; o inventário lê a base acima,
  sem substituir o aceite humano por nova certificação.
- Dono exclusivo desta tarefa: somente
  `docs/epics/e07/e07_runtime_inventory.md`. Contratos/guias E07 pertencem a
  Astra; índices globais e integração pertencem à coordenação.
- Leitura de Git, código, testes e runner. Sem executar Godot, importar editor,
  rodar suíte, acessar save pessoal, stagear, commitar, trocar branch ou criar
  worktree/chat/subagente. Nenhuma API futura é apresentada como pronta.
- O checkout já tinha modificações em arquivos `assets/**/*.import` e
  `export_presets.cfg`. Foram preservadas. Não há diff local em `scripts/`,
  `tests/` ou `tools/` na inspeção; referências abaixo correspondem ao código
  dessa base. Linhas são posições de leitura, não promessa de estabilidade.
- A CLI de workflow não existe nesta base. O diretório `tools/` contém o runner
  de testes e ferramentas de conteúdo/probes, sem comando de workflow/approve.
  Não foi buscada origem externa nem fabricado recibo de aprovação.

Precedência lida: [AGENTS](../../../AGENTS.md), [WORKFLOW](../../WORKFLOW.md),
[pacotes](../../REVIEW_WORK_PACKAGES.md), [MVP](../../MVP.md),
[ARCHITECTURE](../../ARCHITECTURE.md),
[PRODUCT_DIRECTION](../../PRODUCT_DIRECTION.md) e
[abertura E07](../e07_launch_queue.md). Direção futura aprovada não torna a
implementação existente defeituosa em relação ao contrato de E06.

## 1. Navegação, geometria e seleção

**Fatos comprovados.**

| Autoridade real | Assinaturas e consumidores relevantes | Limite observado |
|---|---|---|
| [ArenaNavigation](../../../scripts/core/arena_navigation.gd), L5–26, L77–99, L124–181 | `configure(bounds: Rect2, obstacles: Array[Rect2], actor_radius: float) -> void`; `get_path(from: Vector2, to: Vector2) -> PackedVector2Array`; `is_segment_clear(from: Vector2, to: Vector2, clearance: float) -> bool`; `is_polygon_clear(points: PackedVector2Array, clearance: float = 0.0) -> bool`; `move_until_blocked(from: Vector2, to: Vector2) -> Vector2` | Uma grade `AStar2D`, um retângulo de bounds, obstáculos retangulares e segmentos temporários no mesmo plano. Não há identidade de superfície, conector de altura ou coordenada vertical de gameplay nessas entradas. |
| Mesma navegação, L28–51 | `add_temporary_segment(...) -> bool`, `remove_temporary_segment(id: int) -> void`, revisão e reconstrução da grade | Obstáculos temporários são compartilhados com consultas espaciais. `configure` limpa esses segmentos; não é uma simples troca visual de mapa. |
| [PlayerActor](../../../scripts/actors/player_actor.gd), L244, L567, L2303–2336, L2947 | `configure(nav: ArenaNavigation, state: RunState) -> void`, `move_to(point: Vector2) -> void`, `can_target_skill(skill_id: StringName, enemy: CombatActor) -> bool`; alcance usa distância `Vector2`; ataque básico também consulta segmento | As validações estão em vários pontos do kit. LoS não é um único serviço separado: alguns casts validam alvo, outros colocação/impacto. |
| [EnemyActor](../../../scripts/actors/enemy_actor.gd), L59–90, L276–295, L328–381 | `configure_occurrence(spawn: MobOccurrence, catalog: MobCatalog, nav: ArenaNavigation, target_player: PlayerActor) -> Dictionary`; caminho, movimento, alcance e LoS para skill | Recebe a mesma navegação; revisão invalida caminho. Alcance/leash são distâncias no plano. |
| [SkillGeometry](../../../scripts/core/skill_geometry.gd), L4–33 | Constantes e `strip_contains`, `cone_contains`, `cone_outline` | Geometria de formas em `Vector2`, sem oclusão ou distância entre alturas por si só. |
| [RunController](../../../scripts/main.gd), L842–847, L1170, L1392–1405, L1480–1492, L2332–2350 | Converte ponteiro pelo canvas; resolve seleção via `BattleTargeting.pick`; áreas/encadeamentos validam segmentos e distâncias | Clique resolve um ponto 2D. Canvas/câmera não selecionam um piso entre superfícies sobrepostas. |
| [BattleTargeting](../../../scripts/core/battle_targeting.gd), L10; [PlayerProjectile](../../../scripts/actors/player_projectile.gd), L46–76, L185–195 | `pick(point: Vector2, actors: Array[CombatActor], previous: CombatActor = null, assist: bool = true) -> CombatActor`; projétil recebe `ArenaNavigation` e corta deslocamento bloqueado | Seleção e colisão de projétil usam a projeção atual. `BODY_OFFSET` é deslocamento 2D, não altura física. |
| [GeometerCasting](../../../scripts/world/geometer_casting.gd), L54–169 | Construção móvel, barreiras e projéteis consultam `player.navigation` e posições de atores | A mudança espacial alcança também construções/âncoras e figuras que se movem com alvos, além do caminho do jogador. |

`get_path` pode resolver destino não caminhável para ponto da grade (L82–89).
O spawn de rota usa o último ponto desse caminho, não necessariamente a posição
pedida. Essa característica precisa ser considerada na futura prova de montagem;
um caminho não vazio isolado não prova que o conector/spawn autorado foi mantido.

Exceção já real: `can_teleport` verifica destino caminhável e alcance, permitindo
cruzar obstáculo no plano; `use_teleport` limpa perseguição/caminho. Não atribuir
LoS universal a todas as habilidades. O teste de mago explicita essa travessia
([mage_gameplay_test](../../../tests/mage_gameplay_test.gd), L145–153).

**Dependência de contrato:** superfícies sobrepostas, distância com desnível,
conectores/rampas, clique, colisão/oclusão, projéteis, formas e exceções de
mobilidade precisam de um contrato comum antes de consumidores. **Inferência de
risco:** adicionar apenas um campo de altura ao desenho deixaria caminho, alcance,
seleção e impacto discordantes. Não se afirma que exista implementação parcial
de pontes pela presença de altura de sprite ou ordenação visual.

## 2. Montagem atual, limpeza e avanço

[PlaytestGameplay](../../../scripts/core/playtest_gameplay.gd), L4–54, contém
`STAGE_COUNT = 6`, três nomes de áreas, `BOUNDS`, `ENTRANCE`, obstáculos por par
de etapas e listas de espécies/categorias. `spawns(stage: int,
rng: RandomNumberGenerator) -> Array[Dictionary]` varia posições em torno de
pontos fixos. Não monta partes conectáveis nem um grafo de estágios.

[RunController](../../../scripts/main.gd), L35–90, é a classe em `main.gd`, não
um arquivo separado `run_controller.gd`. Possui um `encounter_index`, uma
`navigation`, um jogador e um array `enemies`. `_spawn_encounter(index: int)`
(L930–964) marca o encontro ativo, reconfigura mundo, reposiciona jogador na
entrada e cria a população. `_configure_world(stage: int)` (L3137–3156) alimenta
navegação, `ArenaView`, obstáculos e limites da câmera com os mesmos bounds.
[ArenaView](../../../scripts/world/arena_view.gd), L8–26, recebe retângulos para
apresentação; não fornece um segundo mundo navegável.

O avanço real é `_start_next_encounter() -> void` (L2138–2144): bloqueios por
encontro, recompensa, escolha/oferta, transação e fim de run; depois incrementa
o índice ou mostra vitória. A UI exibe botão de próximo encontro, sem objeto de
portal com origem/destino/retorno. A primeira entrada não tem livro de visitas
por estágio, e não há mapas anteriores mantidos nessa estrutura.

`_on_enemy_died` (L1875–1940) remove o ator; quando `_required_enemies()` fica
vazio, limpa controles/estados dos kits, construções, armadilhas, projéteis e
efeitos antes de criar o cristal. `_required_enemies()` (L3249–3253) conta vivos
não administrativos e não invocados. Companheiros restantes são descartados.
Essa é a definição atual de conclusão de encontro, não a futura contabilização
contratada de “todos os inimigos” para portais E07.

**Acoplamento demonstrado:** limpeza, limpeza de efeitos, recompensa, augment e
avanço linear estão ligados ao mesmo ciclo. Reusar esse fluxo como visita de
retorno recriaria população/reconfiguraria geometria e executaria transições
que hoje significam novo encontro. **A contratar:** identidade/estado dos
estágios, destinos e acessos locais, abertura permanente, contabilização de
invocações e condições distintas de conclusão/encerramento antecipado.

## 3. População, aggro, morte de mobs e loot

[MobOccurrence](../../../scripts/core/mob_occurrence.gd), L4–21, contém somente
`occurrence_id`, `mob_base_id`, `category_id`, `origin_id`; valida espécie,
categoria e origem pelo catálogo. [MobCatalog](../../../scripts/core/mob_catalog.gd),
L60–79, resolve nível fixo ou por `origin_levels`, depois usa `StatCalculator`
e `MobTierRules`. A API não recebe nível do jogador para escalar mob.

`_spawn_route_enemy(entry: Dictionary, stage: int, summoned: bool = false,
owner_id: int = 0, admin_spawn: bool = false) -> EnemyActor`
([main](../../../scripts/main.gd), L3158–3218) usa caminho acessível, categoria e
origem da etapa. O ID é `trial_<stage>_<get_instance_id()>`: identidade vinculada
ao ator vivo nesta execução, sem chave persistente de slot/onda. O catálogo é
copiado/configurado no ator; definições não são o estado mutável da população.

[EnemyActor](../../../scripts/actors/enemy_actor.gd), L14–37, L374–456, contém
`engagement_mode` (`idle`, `engaged`, `returning`), home, último ponto visto,
timeout de visão e referência única `player: PlayerActor`. `_refresh_engagement`
considera raio, aquisição/ocultação, LoS e leash; dano real do jogador pode iniciar
engajamento. `_process_return` caminha para home. Isso não é uma tabela de ameaça
por participante. `apply_taunt(duration: float) -> bool` (L217–225) grava duração;
o callback de provocar em [main](../../../scripts/main.gd), L1825–1831, também
aplica debuffs. Não há escolha entre vários participantes nessa assinatura.

Companheiro é emitido uma vez por mestre (`summon_used` antes do sinal;
[enemy](../../../scripts/actors/enemy_actor.gd), L439–445). O controller procura
posição válida e atribui dono; morte do mestre remove seu invocado
([main](../../../scripts/main.gd), L3220–3247). Administrativo/invocado não entra
no loot de produção nem na população obrigatória atual.

[RunRewardService](../../../scripts/core/run_reward_service.gd) é a fronteira
real de loot: `configure_mob_loot(table: MobLootTable) -> Dictionary` (L222),
`register_mob_actor(actor: EnemyActor) -> Dictionary` (L246),
`issue_mob_drop(actor: EnemyActor) -> Dictionary` (L261),
`collect(ticket_id: String) -> Dictionary` (L143) e
`collect_pending_mob_tickets() -> Dictionary` (L291). Registro conserva weakref
e cópia da ocorrência, rejeita ocorrência duplicada; evento `mob:<occurrence_id>`
deduplica emissão. Cinco uniformes vêm do RNG do controller; o payload sorteado
fica no ticket em memória. `collect` respeita fila/seq, bloqueia combate/oferta,
reconcilia resultado incerto, marca entregue antes de callback e só tickets não
mob enfileiram escolha de augment (L143–211).

[MobLootResolver](../../../scripts/core/mob_loot_resolver.gd), L67–111, oferece
`validate_occurrence(...) -> Dictionary` e
`roll(occurrence: MobOccurrence, uniforms: Array) -> Dictionary`: resolução pura,
metadados por origem/nível, qualidade e encaixes. Não tem contador de reincidência,
mácula ou onda. O payload de mob em `issue_mob_drop` tem XP Base/Job zero; XP do
roteiro vem da recompensa fixa por etapa em `PlaytestGameplay` L23–29. Nenhuma
carteira de gold está nesses modelos de perfil/personagem ou payloads atuais.

**Acoplamentos para E07:** não há estado de população por estágio descarregado,
relógio global de respawn ou contador de repetição nessas autoridades; IDs de
instância, weakrefs e deduplicação em memória não constituem identidade restaurável.
Além disso, raros/rare_elite/boss têm piso garantido de equipamento no resolver
(L5, L104); como rendimentos decrescentes de respawn afetam garantias e categorias
elegíveis precisa ser contratado, sem alterar os rates de E06 por inferência.
Não há medição de escala/streaming nesta leitura.

## 4. Run, augments, relógios e causalidade

[RunState](../../../scripts/core/run_state.gd), L8–59, guarda snapshot copiado,
augments, oferta/escolhas, revisão runtime, cópias de inventário e ledger.
`from_build(new_run_id: String, source: BuildSnapshot) -> RunState` não restaura
combate: cria estado e chama `reset`. `open_offer(encounter_active: bool,
rng: RandomNumberGenerator) -> Dictionary` (L154), `offer_token` (L151) e
`confirm_offer(token: Dictionary, augment_id: StringName,
encounter_active: bool) -> Dictionary` (L180) protegem oferta/revisão e não
rerrolam uma oferta aberta. `reset()` (L278–293) limpa augments e pendências e
recria ledger. Não há serialização de RunState para suspensão completa.

Os relógios estão distribuídos: RNG criado/seedado em [main](../../../scripts/main.gd)
L41, L143–146; avanços de ecos/drenagem/procissão/construções no controller
L274–303; recargas/SP/casts e recursos em
[PlayerActor](../../../scripts/actors/player_actor.gd) L126–139, L2427–2548;
aggro/casts/recargas próprios em `EnemyActor` L14–37, L91–112, L346–368;
status em [CombatActor](../../../scripts/actors/combat_actor.gd) L340;
voo no projétil. `resource_state()` do jogador (L2980–2981) retorna déficits e
fontes temporárias para transação de build, não um snapshot completo do ator.

Pausa existe na árvore, com nós pausáveis e guardas de avanço. Inventário incerto
chama `set_inventory_freeze(frozen: bool)` ([main](../../../scripts/main.gd),
L2057–2069), trava RunState e conserva pausa anterior. Ofertas também pausam.
**Distinção factual:** congelar nós vivos não persiste/restaura esses nós depois
de mudar cena ou fechar o processo.

[EffectProcLedger](../../../scripts/core/effect_proc_ledger.gd), L25–42, L71–135,
e [CombatEventContext](../../../scripts/core/combat_event_context.gd), L5–25,
mantêm raízes, claims e referências de ledger/budget; alvos/fontes runtime usam
IDs de atores. **Inferência de risco:** reconstituir apenas augments/HP deixaria
ações tardias, reservas, claims, RNG e tickets sem continuidade causal definida.
Contrato Astra deve fechar captura/restauração e identidade, sem presumir que
copiar um DTO de build ou uma oferta restaura toda a expedição.

Morte atualmente chama `_show_result(false)` ([main](../../../scripts/main.gd),
L2159–2222), cancela ledger/efeitos, chama `run_state.reset()` e termina a run.
Voltar ao menu chama `end_run`, muda cena e descarta o controller (L2250–2277).
Esse fluxo precisa de contrato distinto para morte recuperável/suspensão E07;
não implementa retorno ao último portal nem penalidade de relógio.

## 5. Perfil, persistência e propriedade dos bens

| Fronteira | Fato e consequência contratual |
|---|---|
| [ProfileState](../../../scripts/core/profile_state.gd), L5–36 | Schema 7, catálogo 14, `stat_thresholds_v1`. `equipment_instances`, contador e `card_inventory` estão na raiz do perfil, compartilhados. `characters` guarda personagens; `reward_session` é cursor de recompensa. |
| [CharacterState](../../../scripts/core/character_state.gd), L9–24 | Identidade, XP, aprendizado, equipado/presets/atalhos. Não contém contêiner próprio de itens ou carteira; equipado referencia exemplares da raiz. |
| [ProfileCodec](../../../scripts/core/profile_codec.gd), L27–43, L726–738, L902–941, L1045 | Codifica/valida perfil; lista campos runtime proibidos, incluindo HP/SP, cooldowns, augments, oferta, RNG e inimigos. `reward_session` aceita exatamente `run_id`, `character_id`, `last_committed_seq`; não contém mapas, mortes, tickets pendentes ou relógios. Campos desconhecidos têm preservação própria, não são uma API contratada para suspender combate. |
| [ProfileStore](../../../scripts/core/profile_store.gd), L15, L53, L80–129, L184 | `load_profile() -> Dictionary`, `commit(source: ProfileState) -> Dictionary`; default `user://`. Guardas de escrita, revisão, validação de pending, backup e rename para primary. Nova persistência deve respeitar esse writer e os estados incertos/recuperação, sem writer paralelo. |
| [ProfileFacade](../../../scripts/core/profile_facade.gd), L684–720, L739–855 | `start_run(request_id: String, expected_revision: int) -> Dictionary` cria sessão exclusiva e RunState novo; retorna `run_active` se já há sessão. `_grant_reward_payload` aplica XP ao personagem da sessão, mas equipamentos/cartas ao perfil; cursor e bens são gravados juntos. `end_run(..., outcome: StringName) -> Dictionary` aceita completed/death/abandoned e remove sessão. |
| Mesma facade, L914–950 | Abrir perfil com sessão abandonada remove a sessão após commit, sem restauração da run. `_build_snapshot(character: CharacterState, owner_profile: ProfileState = null) -> BuildSnapshot` injeta o conjunto compartilhado de equipamentos/cartas. |
| [RunBuildService](../../../scripts/core/run_build_service.gd), L23–83, L99–181 | `preview_change(intent: Dictionary)`, `commit_change(intent: Dictionary)`, `reconcile_change(request_id: String)` retornam Dictionary. Validam sessão/revisões/recursos, barram encontro ativo, usam instâncias do perfil e preservam déficits na publicação. A posse atual é “existe no perfil”, não “pertence a este personagem”. |

`ProfileFacade.preview_inventory_change(character_id: String, intent: Dictionary)`
e `commit_inventory_change(...)` (L1104–1156) são a entrada do inventário no menu;
`_commit_candidate` (L952–978) também verifica presets/efeitos dos alts quando
cartas mudam. A migração precisa alcançar snapshots, opções de build, concessões,
inventário, encaixes e referências dos presets, não apenas mover o array JSON.

**Decisão humana já dada:** bens/gold individuais, unlocks por perfil e sem
transferências entre personagens. **Pendência real:** destinação de cada exemplar
compartilhado, conflitos entre alts/presets e cartas encaixadas, contadores,
recibos e recuperação. O runtime não oferece uma política pronta para essa
migração; este inventário não atribui bens ao ativo nem duplica exemplares.

## 6. Integração de UI e lobby

[CharacterMenu](../../../scripts/ui/character_menu.gd), L205–237, chama
`facade.start_run`, publica estado/facade nas variáveis estáticas `pending_*` do
controller e muda para `scenes/main.tscn`. Treino usa caminho separado, sem
facade persistente. É menu de personagens/build/progressão e entrada na
demonstração; essa entrada não recebe `phase_id`, requisitos de fase, seed de
expedição ou destino de retorno. A futura seleção no lobby não tem API pronta.

Na batalha, [main](../../../scripts/main.gd) L2082–2144 controla escolha/pausa e
botão de avanço; L3121–3132 abre/fecha inventário. Coleta, equipamento e escolhas
usam `encounter_active` como fronteira. `sentinel_combat_active` e regeneração
HP recebem esse estado (L274–276); `RunBuildService` também o usa. **Inferência
de risco:** identificar combate apenas com “estágio ainda não limpo” confundiria
a futura ausência de aggro com progressão dos portais. Ameaça, participação e
limpeza precisam ser distinguidas no contrato antes de UI/consumíveis.

## 7. Testes existentes localizados — sem execução

IDs abaixo são os nomes exatos aceitos por `-Test` de
[tools/verify.ps1](../../../tools/verify.ps1). O runner deriva o ID do basename
do script (L16–20), filtra por nome/padrão (L311–331), oferece `-List` sem engine
(L333–337) e registra plano/resultado/hash quando executado (L49–52, L339–352).
Aqui houve somente leitura; nem `-List` foi necessário executar. Os números de
linha do runner indicam inscrição, não índice de etapa nem resultado PASS.

| Fronteira a preservar/estender | IDs existentes e localização no runner | Evidência que a leitura permite afirmar |
|---|---|---|
| Navegação/raio/segmentos e fluxo atual | `milestone_one_test` L72; `arena_flow_test` L75; `mage_gameplay_test` L77 | [milestone_one_test.gd](../../../tests/milestone_one_test.gd) L95 inicia testes de navegação; [arena_flow_test.gd](../../../tests/arena_flow_test.gd) L45–109 verifica limpeza, oferta, pausa e reinício; mago L145–176 cobre destino de teleporte e pausa de cast. |
| Formas móveis/barreiras e efeitos tardios | `e05_geometer_geometry_integration_test` L175; `e06_spatial_policies_test` L260; `e06_spatial_execution_test` L261; `e06_tx_late_fields_test` L254; `e06_rx_causal_late_test` L252; `e06_proc_ledger_test` L68 | [geometer](../../../tests/e05_geometer_geometry_integration_test.gd) L104–137 considera interior de triângulo/obstáculo temporário; L170–174 pausa. [spatial](../../../tests/e06_spatial_execution_test.gd) L105–111 e L153–157 pausa de eco/voo. Não demonstram altura real nem serialização. |
| Roteiro/população/aggro | `e06_gameplay_content_test` L274; `e06_gameplay_ai_test` L275; `e06_gameplay_route_test` L276; `e06_rx_mob_ai_test` L253; `e06_tx_mob_test` L250 | [AI](../../../tests/e06_gameplay_ai_test.gd) L80/118/152/185 testa aquisição/dano, visão/retorno, ocultação/taunt e invocação; [rota](../../../tests/e06_gameplay_route_test.gd) L23 em diante percorre seis etapas, contagem finita, loot e uma escolha por etapa. Não prova retorno, geração modular ou onda global. |
| Loot/retry/concessão | `e06_production_loot_test` L270; `e06_tx_loot_test` L251; `e06_rewards_test` L65 | [produção](../../../tests/e06_production_loot_test.gd) L30 inicia integração; [rewards](../../../tests/e06_rewards_test.gd) L67/93 cobre terminal e fronteiras. Candidatos a regressão de identidade/tickets; não são prova de mácula. |
| Codec/store/sessão | `persistent_state_test` L78; `profile_store_test` L79; `profile_facade_test` L80; `profile_run_facade_test` L81; `e06_review_persistence_edges_test` L246 | [store](../../../tests/profile_store_test.gd) L48/123/231/256 cobre roundtrip/desconhecidos, falhas, backup e arquivos futuros/inválidos; [run facade](../../../tests/profile_run_facade_test.gd) L139/219 cobre incerteza e reabertura de sessão abandonada. Esse último contrato atual precisa de delta explícito para suspensão E07. |
| Bens/encaixes/alternância de personagem | `e06_inventory_persistence_test` L243; `e06_tx_inventory_test` L244; `e06_permanent_cards_test` L279; `e06_card_migration_store_test` L291; `e06_inventory_profile_panel_test` L281 | [inventory persistence](../../../tests/e06_inventory_persistence_test.gd) L10/44 trata identidade/conflitos. Cobertura existente da posse compartilhada não comprova propriedade individual futura. |
| Menu/entrada/transações | `e02_character_menu_test` L83; `e02_run_integration_test` L86; `e06_ui_menu_test` L267; `e06_ui_inventory_test` L266; `verification_profile_isolation_test` L84 | Fluxos atuais e isolamento de fixtures; não há seletor de fases validado por esses nomes. Inspeção visual futura continua necessária. |

Essa tabela é mapa por impacto, não seleção fechada de execução futura. Testes
atuais codificam comportamentos que E07 substituirá deliberadamente (morte
terminal, uma escolha pós-etapa, sessão abandonada e posse compartilhada).
Atualizações exigirão o contrato aprovado e invariantes novas; não tratar suas
expectativas como decisões de produto E07 nem alterá-las para ocultar falhas.

## 8. Respostas de produto existentes e pendências contratuais

Fonte: seções homônimas de [PRODUCT_DIRECTION](../../PRODUCT_DIRECTION.md).
Esta separação não autoriza consumidores nem decide pendências humanas.

| Tema | Já respondido pelo usuário | Ainda requer contrato/decisão delimitada |
|---|---|---|
| Campanha/grafo | Fases repetíveis, nível mínimo e unlocks por perfil; ramos/retorno permitidos; múltiplos destinos, acessos locais distintos; não exigir todos os ramos | Requisitos adicionais por entrada ou permanentes, alts; captura/conflitos de quests, ramos exclusivos, indicação de destino; distinção objetivo/fase/saída antecipada. |
| Montagem/altura | Partes conectáveis, mapas grandes/labirínticos, elevação funcional; desnível conta no alcance, sem bônus de high ground | Geometria/superfícies/oclusão e exceções dos kits; versões/entradas da geração, limites de falha, budgets e escala medida. Referências humanas não fixam pixels nem algoritmo. |
| Limpeza/respawn | Todos os inimigos derrotados abrem portais; memoráveis contam; primeira limpeza inicia timer único da fase; ondas globais longas em estágios limpos, somente mortos elegíveis; portais permanecem abertos; bosses não voltam | Invocações e elegibilidade de memoráveis/raros/elites; intervalo, segurança em mapa ocupado/descarregado, identidade origem/onda, reincidência/curvas/pisos e proteção de recompensa única/augment. |
| Continuidade/mácula | Mesma expedição até conclusão, incluindo montagem/progresso/augments; só conclusão restaura rendimento; suspensão congela tudo, sem progresso offline; reentrada não rerrola nem reconcede | Captura/restauração de atores/ações/RNG/claims/tickets; simultaneidade por personagem/fase e interação com lobby; granularidade/início da redução por recompensa e exceções de quest. |
| Morte | Conserva expedição/build/bens; último portal; reduz tempo restante da próxima onda, reposição elegível ao zero | Portal qualificável/primeira entrada/retorno seguro; HP/SP, efeitos/recargas, valor da redução, mortes repetidas e morte antes da primeira limpeza. |
| Augments | Dois no primeiro estágio, um no início dos seguintes, uma vez por origem/primeira visita; extras memoráveis somente contratados; não permanentes | Registro das origens, elegibilidade/limites de extras e proteção contra farm de respawn. Não herdar concessão no fim da etapa. |
| Ameaça | Lista individual por inimigo, geração diferente de dano, limiar para troca, provocar/redução ativa e UI; participação do grupo distinta do alvo | Fórmulas/números/empates, cura/suporte/DoT/pets, LoS/alcance/leash/reset e X segundos sem aggro; implementação não libera multiplayer. |
| Bens/economia | Itens/gold por personagem, unlocks por perfil, sem transferências; aquisições confirmadas ficam; venda confirmada perde cartas encaixadas; conclusão sem equipamento garantido | Migração de IDs/encaixes/presets/recibos; regras de contêiner/carteira/transação quando autorizadas. Economia, consumíveis, quests completas e low-poly mantêm suas trilhas/gates. |

## Conclusão e limites da entrega documental

O runtime oferece autoridades aproveitáveis de navegação 2D, composição,
transações de perfil/inventário, ocorrência/loot e causalidade. Os bloqueios
concretos para consumidores E07 são: ciclo linear e destrutivo de encontro;
coordenadas sem superfície/altura; persistência restrita a perfil e cursor;
identidade de ator em memória; ausência de estado/relógio global de reposição;
aggro com alvo único; e posse compartilhada consultada por múltiplos serviços.

Referências locais, assinaturas, inscrições de testes, branch/base e diff foram
conferidos por leitura. **Nenhum teste foi executado ou declarado PASS; não houve
suíte de gameplay, importação, inspeção visual ou medição de desempenho.** Sem
alteração de runtime/configuração/save por esta tarefa. Não houve stage/commit,
integração, aprovação técnica do candidato ou autoarquivamento. Próximo passo:
coordenação valida/integra este inventário e Astra usa os fatos no contrato E07,
mantendo as decisões humanas e pendências acima.
