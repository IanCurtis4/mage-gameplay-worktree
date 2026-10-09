# E06-T1 — manifesto de APIs e adaptadores

09/10/2026. Fundação sobre D0; este documento acompanha o registro e o recibo
[e06_t1](e06_t1.md). Evidência do autor; R1 ainda pendente.

## Catálogo/composição

| API | Entrada/saída por valor | Regras |
|---|---|---|
| BuildEffectCatalog.pilot() | registro dos cinco augments legados | Nenhum item/carta de produção T1 |
| register_definition(origin: StringName, definition: Resource) -> Dictionary | augment/equipment/card; ok/error_code/request_id/detail | Cópia profunda ao registrar; ID único por origem; sem merge parcial |
| get_definition(origin, id) -> Resource; ids(origin) -> Array[StringName]; copy_catalog() | cópias; IDs em ordem lexical | Alterar Resource devolvido não altera registro |
| BuildEffectComposer.compose(snapshot: BuildSnapshot, run_effects: Dictionary, temporary_sources: Array[Dictionary]=[], catalog: BuildEffectCatalog=null) -> Dictionary | run_effects={augment_stacks, card_sockets}; equipamento de snapshot.equipped | Valida identidade pronta, slots/restrições/ranks, fontes únicas e conflito antes de publicar |
| SkillEffectResolver.preview/capture(skill_id: StringName, rank: int, composed_build: Dictionary) -> Dictionary | rank_definition copiado; values={range,sp_cost,cooldown,projectile_count}, procs, build_version | Mesmo caminho puro; rank/biblioteca são autoridade, barra não é requisito |

Resultado de composição: ok/error_code/request_id/build_version, skill_ranks, stat_sources,
breakdown (StatBreakdown novo), skill_rules, procs, provenance, inactive e conflicts.
Inactive registra source_id/effect_id/reason (skill_not_learned ou identity_restricted).
Falha retorna ok=false/error_code/request_id/detail; não aplicar um resultado parcial.
BuildEffectComposer.copy_result preserva isolamento do breakdown e dos contêineres.

EffectDefinition é Resource declarativo: id/family_id/kind/handler_id/stacking_mode,
conflict_group/trigger/target_skill_ids/restrições/minimum_rank/channel/axis/unit,
magnitude/increased/limit/stack_values. EquipmentDefinition inclui slot/starter;
CardDefinition inclui allowed_slots; AugmentDefinition mantém campos legados e
max_stacks, com effects como autoridade de composição. Transformação exclusiva
requer um stack; curvas numéricas explícitas têm um valor por stack, até três.

Fontes: augment:<id>, equipment:<slot>:<item>, card:<card>:<item>.
Passivas intrínsecas vêm de BuildSnapshot; buffs por source_id/instância passam
como fontes temporárias canônicas. IDs duplicados entre essas listas são erro.
Ordem de fontes/effects é lexical. StatCalculator continua única matemática de
atributos/caps. Percentuais de primários são rejeitados.

## Handlers efetivamente entregues

| Handler | Eixo/trigger/alvo | Composição/limite | Consumidor real/prova |
|---|---|---|---|
| STAT_MODIFIER | canais primary_flat, flat, increased e IDs canônicos; NONE | StatCalculator, flat e increased agregados uma vez | PlayerActor._build_stat_breakdown; cinco augments e regressões E03 |
| PROJECTILE_COUNT | projectile_count; fire_spear/ice_spear/double_shot; NONE | inteiros, (base+sum flat), cap comum declarado <=16 | RunState.projectile_count, PlayerActor.use_spear/use_double_shot; fixtures nas três origens |
| SKILL_SCALAR | range, unit=units; mesmos três skills; NONE | (base+sum flat)*(1+sum increased), cap comum declarado; mínimo zero | skill_range/can_target_skill/emissão; alvo além do alcance base nas três origens |
| HIT_DAMAGE | ON_HIT, physical_damage/magic_damage; IDs de skill aprendida ou basic_attack, ou geral | flat+HP positivo canônico*increased, cap declarado; famílias compatíveis somam antes do claim | prepare_effect_claims/resolve_build_effect_procs -> HealthState -> CombatMath |

Quantidade base: double_shot=2, lanças=1. Redução de custo/cooldown, área/duração,
espalhamento, mudança de elemento/targeting/fluxo, triggers ON_KILL/ON_CAST/
ENCOUNTER_END e outros alvos de transformação não têm handler de receita T1.
Enum não significa suporte: validador os rejeita. Timing/custo continuam ranks e
StatCalculator/SentinelMath existentes. Receita T3 que precisar de novo eixo volta
à tarefa T1, conforme DAG, antes de entrar no catálogo publicado.
Famílias/IDs intrínsecos são reservados: HIT_DAMAGE não pode se disfarçar de kit;
novas receitas que alterem esse kit exigem adaptador específico.

## Estado e ofertas da run

| API RunState | Contrato |
|---|---|
| effect_catalog() -> BuildEffectCatalog; effect_state() -> Dictionary | cópias do catálogo e {augment_stacks,card_sockets} |
| set_effect_catalog(catalog) -> Dictionary | valida candidato antes de substituir; oferta aberta bloqueia; runtime_revision incrementa uma vez |
| composed_build(temporary_sources=[]) -> Dictionary; skill_effect_capture(id) -> Dictionary | getters por valor; cache privado detecta identidade/ranks/atributos/fontes/versões |
| composition_revision() -> int; effects_valid() -> bool | consulta interna leve; não expõe cache; PlayerActor reaproveita ranks privados por revisão; snapshot ausente falha e restauração recompõe |
| queue_choice(); can_open_choice(encounter_active) | tickets monotônicos de pendência; não abre durante encontro |
| open_offer(encounter_active, rng) -> Dictionary; offer_token() -> Dictionary | token choice_id/offer_id/runtime_revision; IDs/definitions copiados, empty e request_id; máximo três sem reposição |
| confirm_offer(token, augment_id, encounter_active) -> Dictionary | ID deve estar na oferta; revisão válida; um stack e uma pendência; replay falha |
| consume_empty_offer(token, encounter_active) -> Dictionary | somente pool vazio; uma pendência; mensagem pt-BR; replay não consome próxima |
| build_offer/confirm | adaptadores legados sobre as mesmas primitivas |
| reset() | descarta cartas/augments/ofertas; cancela ledger anterior; novos tokens não reutilizam serial |

RNG só é consumido ao construir a primeira oferta validada. Reabrir/renderizar
não rerrola. Pool exige efeito efetivo; ganho totalmente absorvido por cap é
inútil, inclusive proc cujo payload já satura para todo HP positivo. Oferta aberta
continua bloqueando mutação mesmo sem janela visível. T2 deve usar esse lock,
revisões e cópias candidatas; estes métodos não autorizam equipar/persistir.

## Contexto/ledger e ordem

DamageRequest.context é CombatEventContext; effect_snapshot copia procs e versão
na emissão. DamageRequest.copy conserva root/event/flags, cancelled, metadata e
poder. secondary permanece verdadeiro no envelope mesmo após tentar limpar o
bool. HealthState.apply carimba a entrega e chama apply_once antes de HP/listeners.
Cópia de entrega já carimbada conserva event_id e não aplica novamente. Cada
projétil copia o protótipo; perfuração carimba nova colisão preservando a raiz.

| API | Garantia |
|---|---|
| EffectProcLedger.new_root(owner_id, secondary=false, ancestor="", intrinsic=false) -> CombatEventContext | null se cancelado/saturado; raiz paga/auto; registro fraco, envelope mantém orçamento vivo |
| claim_batch(context, candidates: Array[Dictionary]) -> Array[Dictionary] | candidatos family_id/source_id/target_id; ordena e reserva família/alvo/raiz; devolve child context secundário antes de callbacks |
| claim_intrinsic(context, candidates) | somente protótipo de componente/tick contratado; rejeita proc_child; usa mesmo 16 |
| take_result_claim(result, family, target) -> CombatEventContext | reserva preparada consumida uma vez antes de listener |
| claim_kit_recovery(context,family,source,target) -> bool | exceções restritas blood_thirst/spiritualist_drain_heal; mesmo teto e dedupe |
| claim_echo_pair(context,carrier,target) -> CombatEventContext | exceção humana; raiz primária original, portador/alvo uma vez, saldo comum |
| apply_once(context) -> bool; applications(context) -> int; cancel() | entrega idempotente; sem reembolso de absorção/invalidação; cancel invalida todos envelopes |
| CombatEventContext.copy_context/secondary_prototype/impact/scheduled_tick | preserva raiz/flags; tick novo retém ancestralidade; proc_child não pode criar tick |
| DamageRequest.scheduled_tick() -> DamageRequest; inherit_root(parent); child_request(parent,family,source,victim) | cancelado se tick inválido/saturado; herança não lava secondary/proc_child; criança de proc não causa novos procs |
| projectile_slots_available(tree, needed) -> bool | 128 vivos mundial, aliados+hostis; não descarta hostis para abrir vaga |

Até 16 aplicações secundárias/raiz; 512 raízes vivas/ledger. Sem TTL que reabra
claims. Eventos candidatos do resultado são reservados num lote por Main/Player
antes de executar procs/passivas; ordem temporal de colisões permanece física.
Componentes intrínsecos de projétil/campo são entregas próprias na ordem da
geometria E05; cópias conservam raiz e concorrem no mesmo saldo. Miss/zero/escudo
integral não armam ON_HIT. Filhos genéricos não consomem RNG HIT/crítico, não
criam dano/cura/controle/timer derivados. Ataques primários preservam sua sequência
legada de RNG, incluindo impactos geométricos. HP da execução é custo, não hit.

## Matriz origem -> adaptador -> consumidor

| Produtor/origem | Transporte/adaptação | Consumidor e cota |
|---|---|---|
| três tipos de receita | BuildEffectCatalog/Composer -> SkillEffectResolver -> RunState -> PlayerActor | skill_range, emissões e snapshots; procs -> Main -> HealthState/CombatMath |
| PlayerActor._spend/_try_basic_attack | _begin_effect_emission/_make_request; emission_id=serial da raiz | Main._on_attack_requested e callbacks de skills; mesma raiz para AoE/multi-projétil |
| EnemyActor._try_attack | ledger do dono; ArrowProjectile copia e entrega | PlayerActor/HealthState; rejeita raiz/projétil saturado antes de cooldown |
| PlayerProjectile/ArrowProjectile/SentinelAreaProjectile | copy nos configure; colisão física/perfuração; area copia por vítima | Main/HealthState; contexto/metadata conservados |
| ArrowRain | snapshot; raiz nova por volley agendada, mesma raiz da volley por vítimas | Main/HealthState; ticks conservam secondary/ancestralidade |
| ExplosiveTrap/HunterTrap | snapshot de colocação; cópia por vítima; ledger de mecanismo E05 | dano primário conserva raiz; abertura -> HunterOpeningState.consume/child_request (hunter_exploit) |
| CombatActor.apply_burn/apply_bleed | dono/skill, prazo maior, DPS substituído; até quatro streams comuns; relógio antes do callback | scheduled_tick -> status_damage_requested -> Main/HealthState; cada tick raiz própria, secondary |
| FireWall | captura burn_request e aplica ao alvo; não recompõe build no contato | mesmo adaptador burn; controles de terreno E05 preservados |
| LightningWall | crossing contratado cria scheduled_tick; snapshot da parede | Main/HealthState; cota por cruzamento, ancestralidade e secundário |
| ElementalistSequence | pedidos copiados por elemento; sequência finita da ação | Main/HealthState; raiz única da ação; Foco Prismático reserva elementalist_focus |
| SoulImpactSequence/SpiritualistProcessionState | três pulsos contratados; raiz por tick; primeiro direto e restantes secundários | Main/HealthState; emission_id E05 permanece; proc_child nunca instala essa sequência |
| SpiritualistDrainState | snapshot, primeiro tick direto/restantes secundários, raiz por tick | Main -> HealthState + heal_from_spiritualist_drain; spiritualist_drain_heal e channel_focus no saldo do tick |
| SpiritualistEchoState | conjunto finito inicial, fila 0,35 s, raiz do gatilho e poder/multiplicador capturados | Main._apply_spiritualist_echo; claim_pair + claim_echo_pair antes do dano; cap16 comum |
| GeometerCasting/GeometerWallField/GeometerTriangleField | snapshots da formação; raiz própria para manutenção/cruzamento; payload de incidência/fundamento/arco herda projétil | casting.hit -> Main/HealthState; ledger E05 de construção continua adicional, não substitui 16 |
| intercepção hostil Geômetra | ArrowProjectile entrega contexto a intercept_hostile | geometer_incidence_refund na raiz hostil, além do claim E05/ICD |
| passivas/gatilhos do resultado | prepare_effect_claims + reservas kit, generic proc e fontes adicionais de Main | hunter_exploit, sentinel_focus, berserker_wound/pursuit/breath_heal, elementalist_focus, spiritualist_echo_recovery/drain_heal, defender_watch, blood_thirst |
| guarda frontal Defensor | resultado recebido -> lote defender_token/defender_guard_return na raiz atacante | token/retorno SP uma vez; absorção frontal contratada pode gerar token sem dano HP |

Controles/escudos ativos e auras de terreno E05 são componentes explícitos do kit,
com suas quotas/CC já contratadas; não são novos handlers de proc secundário.
Não expor chamadas apply_root/heal/current_sp como handler genérico de receita.
Resonância Prismática/Obstinação são modificadores capturados do dano primário;
não criam eventos secundários extras. Foco reserva sentinel_focus/vítima/raiz; SentinelFocusState mantém cotas e
cadência por emissão, permitindo a marca de uma vítima posterior de perfuração.
Ranks, números, quota de Foco/mecanismos/
construções e fórmulas de CC continuam em seus módulos canônicos.

Exceções preservadas: Ruptura paga mantém contested (flag restrita ao ID intrínseco,
sem crit/proc e vedada a proc_child); Sede de Sangue usa killed real inclusive DoT;
Drenagem cura ticks secundários até o teto do canal; Foco de canal concede após
conclusão finita; onda de Eco usa portador/alvo conforme decisão humana.

APIs de teste puro ainda aceitam DamageRequest sem contexto para fixtures legadas;
nessa entrada não há garantia de cota/replay. Todos produtores de combate normal
acima fornecem envelope. A fábrica privada _make_request tem serial de emissão
legado quando chamada isoladamente sem ação; isso não cria uma ação paga/runtime.

## Erros publicados e provas

Catálogo: invalid_definition_type, duplicate_or_empty_id, invalid_restrictions,
invalid_slot, invalid_stacks, duplicate_effect, exclusive_requires_one_stack,
invalid_curve, invalid_effect, non_finite_parameter, invalid_conflict_group,
unknown_skill_target, invalid_stat_handler, invalid_stat_axis, invalid_skill_rule,
invalid_projectile_rule, unsupported_skill_axis, unsupported_proc,
intrinsic_family_requires_adapter, unsupported_handler.
Composição: missing_snapshot, identity_unavailable, duplicate_source,
unknown_definition, identity_restricted, stack_cap, duplicate_card,
socket_item_not_equipped, slot_restricted, effect_conflict,
incompatible_axis_limits/incompatible_family, mais erros canônicos do snapshot/stats.
Resolver: invalid_composed_build/rank_mismatch/skill_not_learned.
O rank passado precisa coincidir com skill_ranks capturado na composição.
Run/oferta: missing_catalog, offer_open, encounter_active, no_pending_choice,
missing_rng, stale_offer, stale_revision, offer_not_open, not_in_offer,
offer_not_empty, no_effective_gain e erros propagados de composição.

Fixtures e06_effects_fixture.gd são Resources/valores locais aos testes, nunca
save/grant/catalog de produção. e06_effects_composition_test cobre três origens,
ordem/duplicata/caps/conflitos, dez prontas/cinco bloqueadas, curvas, ofertas
e invalidação/restauração após remoção do snapshot.
e06_proc_ledger_test cobre 16/17, famílias, reentrada/replay, escudo/letal/zero,
ref tardia, 512, cancelamento, timer proibido e Eco. e06_effects_runtime_test usa
ator real e callback real: quantidade/alcance nas três origens, snapshot após
remoção, passiva+três origens no último slot, Eco finito/cota compartilhada,
cura por DoT, pausa/limite de streams e rejeição mundial antes de cobrança.
Regressões legadas são reproduzidas intactas pelo runner integral.
