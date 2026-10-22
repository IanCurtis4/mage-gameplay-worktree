# E07 — contrato de arquitetura v1

## Atualização operacional —22/10/2026

F1–F6 integradas conforme [recibo](e07/f1_f6_integration.md). Aprovações humanas
posteriores estão indexadas nas [decisões](e07/e07_decisions.md) e prevalecem sobre
as propostas/pendências históricas v1. F7 autorizado, com [despacho](e07/f7_dispatch.md).
Não há liberação de F8/E08+, merge master ou aceite humano de gameplay E07.

18/10/2026. Papel: Astra, arquitetura documental; esforço Alto. Estado:
**ENTREGUE PARA DECISÕES E INTEGRAÇÃO DOCUMENTAL**, sem liberação de runtime.
Base inspecionada: `029b8ca1d7b1752929d549cbeb51e534ea6d3c1d`, checkout
`C:/Users/João Pedro/Documents/ChatGPT/RagRPG`, branch `codex/playtest`.
Runtime E06 aceito: `a4f846ebaef45e5fa28c113331b6e75b64759525`.

Fontes normativas: [WORKFLOW](../WORKFLOW.md), [direção humana](../PRODUCT_DIRECTION.md),
[abertura E07](e07_launch_queue.md) e [aceite E06](e06/e06_gameplay_acceptance_2026_10_18.md).
Este contrato não transforma propostas de produto em decisões. As dependências
humanas têm IDs em [decisões](e07/e07_decisions.md); tarefas em [plano](e07_tasks.md).
Nomes novos abaixo são interfaces a implementar, não APIs existentes. Uma assinatura
documentada não torna seu consumidor PRONTO.

## Resultado e limites

Entregar uma campanha offline de expedições persistentes: seleção de fase,
montagem modular reproduzível, altura funcional, população temática, limpeza,
portais de ida/volta e conclusão. A mesma expedição conserva montagem, augments,
recursos, ações, mortes, relógios e recibos até conclusão. Ausência não avança
tempo de jogo. Recompensas confirmadas pertencem ao personagem; unlocks ao perfil.

Inclui fundações mínimas de propriedade, wallet de gold para bônus de conclusão,
persistência do mundo e identidade estável. Não inclui lojas, venda/desencaixe,
receitas/consumíveis, profissões, catálogo low-poly, novas classes, multiplayer,
quest engine completa ou economia completa. Contratar um slot para esses sistemas
não autoriza implementá-los. Abas vazias e fixtures não contam como entrega.

Escala final, densidade e quantidade de fases/estágios não são herdadas do piloto.
Primeira amostra proposta em D07; precisa de aceite antes de virar conteúdo de
produção. A prova técnica pequena pode usar fixtures explicitamente artificiais.

## Autoridades e fronteiras

| Responsabilidade | Existente a preservar | Extensão proposta / limite |
|---|---|---|
| Stats, dano, efeitos | StatCalculator, CombatMath, BuildEffectComposer, SkillEffectResolver | Consumir os mesmos resultados; geometria decide validade espacial, não dano |
| Propriedade e transações | ProfileState, ProfileFacade, ProfileCodec, ProfileStore | Bens com owner_character_id; mesmo writer para mundo, bens e recibos |
| Build/augments | RunState, RunBuildService | RunState continua build da expedição; snapshot tipado de ofertas e estados, sem chamar reset ao retomar |
| Causalidade | EffectProcLedger | IDs estáveis na persistência e remapeamento bijetivo de IDs locais ao reconstruir |
| Mundo | ArenaNavigation 2D, PlaytestGameplay fixo | WorldGeometry e ExpeditionAssembler; ponte não pode virar um único chão 2D |
| População | MobDefinition, MobOccurrence, MobCatalog, MobTierRules | PopulationPlan + PopulationState com identidade por slot e geração |
| Recompensa | RunRewardService, MobLootResolver | Tickets persistidos, origem de entrada separada de morte/conclusão |
| Ciclo | RunController em scripts/main.gd | ExpeditionService orquestra regras; controller adapta cenas/input, sem novo writer |
| Combate | EnemyActor com aggro/leash/taunt atuais | Consulta espacial comum; CombatParticipation e ThreatService somente no pacote delimitado |
| UI | DTOs existentes | CampaignView/PortalView/ThreatView copiados, mensagens pt-BR, nenhum cálculo paralelo |

E07 não precisa de lojas para gold, nem de ameaça multiplayer para gerar mapas.
Precisa de posse individual antes de conceder qualquer loot E07; de checkpoint
durável antes de anunciar suspensão; de participação em combate antes de prometer
saída de combate coerente. A ameaça nova é uma fundação separada condicionada a
D06, não substitui navegação, e não autoriza habilidades novas.

## Modelo de dados proposto

IDs persistidos são strings técnicas validadas, nunca NodePath, ponteiros ou
get_instance_id(). Usar tipos GDScript nos limites; serialização contém somente
valores validados. Números não finitos, referências ausentes e revisões incompatíveis
falham sem mutação. Inteiros persistidos respeitam precisão exata do codec; RNG
de 64 bits usa representação textual sem perda, não número JSON arredondado.

| Tipo | Campos mínimos e autoridade |
|---|---|
| PhaseDefinition (imutável) | phase_id, recipe_revision, unlock/requisitos, grafo de destinos, origens/biomas, política de geração, referências a políticas de onda/recompensa aprovadas |
| PartDefinition (imutável) | part_id/revision, superfícies, conectores, volumes de colisão/oclusão, entradas seguras, slots temáticos e tags de bioma |
| GenerationInput | seed, generator_revision, recipe/part/catalog hashes, phase_id, capturas de objetivos e políticas; ordenação canônica |
| ExpeditionManifest | entrada completa, stage_ids, part_instances/transforms, conexões, portais, slots de população/objetivo, caminhos testemunha, hash canônico |
| WorldPoint | stage_id, surface_id, posição Vector3 em unidades comuns; projeção visual é derivada |
| ExpeditionState | expedition_id, character_id, phase_id, revision, lifecycle, manifest, current_stage_id, last_portal_anchor, relógio global, stage_states, build/runtime snapshot, RNG streams, mácula, tickets/recibos |
| StageState | visited, cleared_once, portal_open flags, population slots, objetivos, ações/entidades locais, clocks locais e grants de primeira entrada |
| PopulationSlot | slot_id, species_id, occurrence_category, origin_id, home WorldPoint, respawn_policy_id, blocks_clear, reward_policy_id; gerações/life_state separados |
| RewardSource | expedition_id + stage_id + slot_id/generation ou entrada/objetivo/conclusão; identidade canônica persistida |
| ExpeditionCheckpoint | codec_revision, content compatibility, profile revision, snapshot completo, digest, sequência durável e pendências |

Guardar o manifesto realizado, além da seed. Seed sem versões/entradas não é
contrato de reprodução. Upgrade não remonta expedição em curso silenciosamente.
Manter compatibilidade suportada ou reportar `content_revision_unavailable` e
preservar bytes; descarte/migração que altere experiência exige decisão humana.

## Protocolo comum das APIs novas

Resultados públicos usam DTO copiado com `ok: bool`, `error_code: StringName`,
`request_id: String`, `revision: int` e `data` tipado por operação. Sucesso tem
error_code vazio; falha não contém candidato parcialmente publicado. Consultas
são puras. Mutações recebem identidade da expedição/personagem, request_id estável,
expected_revision e payload; reenvio idêntico retorna recibo, reuso do mesmo ID
com outro payload retorna `request_conflict`. A API existente pode conservar seu
formato com adaptador; não renomear tudo só para coincidir com esta tabela.

| Interface proposta | Entrada → saída | Falhas além das comuns |
|---|---|---|
| ExpeditionAssembler.build | GenerationInput → Manifest + diagnóstico/caminhos | invalid_recipe, incompatible_connector, objective_unreachable, generation_exhausted |
| WorldGeometry.path | WorldPoint origem/destino, TraversalProfile, revision → PathResult | unknown_surface, blocked, unreachable, stale_geometry |
| WorldGeometry.query_attack | AttackGeometry + origem/alvo + revision → validade/impacto/obstrução | out_of_range, occluded, invalid_surface, unsupported_geometry_rule |
| PopulationPlanner.build | Manifest + PopulationRecipe → PopulationPlan validado | incompatible_species, missing_thematic_site, population_unreachable |
| ExpeditionService.enter | fase, personagem, request/revision → expedição existente ou nova | phase_locked, requirements_unmet, expedition_conflict, policy_unresolved |
| ExpeditionService.travel | portal_id, expected stage/revision, request → estado e ArrivalAnchor | portal_closed, invalid_destination, transition_pending, destination_unsafe |
| ExpeditionService.suspend/resume | request/revision → checkpoint/estado restaurado | checkpoint_incomplete, unknown_runtime_kind, content_revision_unavailable |
| ExpeditionService.record_death | entidade + generation + event_id → estado/ticket/limpeza | stale_entity_generation, invalid_death_source |
| ExpeditionService.revive | death_event_id + request/revision → retorno e onda resultante | policy_unresolved, invalid_return_anchor |
| ExpeditionService.finish | outcome + objective/source + request/revision → recibo | completion_unmet, unsupported_quest_exception |
| CharacterAssets.preview/commit | personagem + intenção + request/revision → bens/recibo | not_owner, locked_by_expedition, migration_required |
| ThreatService.observe/query | evento causal confirmado / enemy_id → lista/alvo/limiar | invalid_participant, unsupported_threat_rule |

Erros comuns: stale_revision, invalid_identity, invalid_payload, save_in_progress,
recovery_required, request_conflict. `policy_unresolved` impede uso em produção;
nenhum default de gameplay substitui uma decisão pendente. UI traduz códigos,
sem tratá-los como sucesso nem abrir fase nova por falha de retomada.

## Máquina de estados e transações

`created → active ↔ suspended`; `active → recovering → active` na morte;
`active → completed` apenas por condição válida de conclusão. Estado transacional
`reconciling` bloqueia novas intenções até resolução do writer. Estados são
persistidos na mesma unidade de commit que suas consequências.

Sair ao lobby produz suspensão, não `end_run(abandoned)`. Morte não chama
`end_run(death)` do piloto nem recria RunState. Reabrir UI, viajar e retomar não
chamam o construtor de uma nova expedição. `completed` concede gold/EXP uma vez,
encerra augments e permite nova montagem. Quest antecipada é operação distinta:
sem bônus por padrão; política de continuidade/mácula depende de D02, não mapear
automaticamente para completed ou abandoned.

Ordem de mutação: revalidar entrada → construir candidato → claim/evento e ticket
congelados no candidato → persistir atomicamente → publicar/sinalizar. Callbacks
que podem reentrar só depois do claim. Falha conhecida preserva estado anterior;
gravação incerta congela comandos, reconcilia e publica somente estado durável.
Não há dois arquivos independentes confirmando loot e morte em ordens incompatíveis.

Morte de mob registra conjuntamente tombstone da geração, ticket congelado,
contagem de limpeza e flags de portal. Crédito material pode aguardar coleta,
mas sua fonte não pode ser esquecida ou rerrolada. Retomada não recria geração
morta nem concede novamente ticket confirmado. Bônus de conclusão e unlocks
compartilham a transação de completed. Nenhum equipamento garantido nesse bônus.

## Limpeza, portais, augments e ondas

- População obrigatória é o manifesto completo, inclusive atores descarregados
  e memoráveis presentes. Contar Nodes vivos na cena não prova limpeza.
- `cleared_once` só passa a true quando todos os slots obrigatórios da geração
  inicial e bloqueadores contratados estão resolvidos. Uma vez true, não volta.
  Boss morto permanece morto. Spawn admin não bloqueia nem concede produção.
- Porta local tem identidade/tipo próprios e acesso independente da limpeza
  que exige o memorável atrás dela. Portal de avanço abre por limpeza total;
  retorno preserva o grafo/estado e não exige matar novamente reposições.
- Primeira entrada no primeiro estágio agenda duas origens distintas de escolha;
  primeira entrada nos demais, uma. Claims persistidos antecedem callbacks/UI.
  Não conceder no fim por herança de PlaytestGameplay. Extras só por fonte
  contratada; escolha continua fora de combate, com pool vazio resolvido.
- Primeira limpeza de qualquer estágio arma o único relógio global da fase.
  Pausa/suspensão congelam; viagem não reinicia. Cada onda repõe apenas slots
  elegíveis mortos de estágios já limpos; não duplica vivos nem fecha portais.
- slot_id é estável; generation aumenta somente quando uma reposição é admitida.
  Onda cria intenção para slot morto; se chegada não é segura, conserva pendência
  única em vez de gerar cópias. Elegibilidade e segurança são D03.
- Redução de recompensas é política versionada por tipo, aplicada antes de sortear
  e congelar o ticket. Curva/escopo/início são D03. Replay nunca recalcula a taxa.
- Reviver usa a mesma expedição/build e reduz remaining do relógio uma vez por
  death_event_id. Se chegar a zero, uma onda elegível; excesso não cria ondas
  extras silenciosamente. Intervalo/penalidade/morte pré-limpeza são D04.

Detalhamento: [mundo](e07/guides/world_geometry.md),
[estado](e07/guides/persistence_and_identity.md),
[população e ameaça](e07/guides/population_and_combat.md),
[validação](e07/guides/validation.md).

## Invariantes de aceitação

| ID | Propriedade verificável |
|---|---|
| I01 | Resources/catálogos não são mutados; estado pertence à instância |
| I02 | Mesma entrada e versões geram mesmo manifesto canônico, ou mesma falha limitada |
| I03 | Todo inimigo obrigatório/objetivo/saída tem caminho testemunha compatível com raio e conectores |
| I04 | Clique, rota, spawn, mira, impacto e portal consultam a mesma geometria com altura |
| I05 | Altura entra na distância; não introduz multiplicador de dano/high ground |
| I06 | Uma fonte concede no máximo um ticket/grant; retry/revisita/restart não rerrolam |
| I07 | Suspender/restaurar preserva estado e próximo efeito; nenhum avanço offline ou reset |
| I08 | Uma entidade viva por slot/generation; boss morto não retorna; onda só em estágio limpo |
| I09 | Portal aberto e cleared_once são monotônicos; retorno não concede entrada novamente |
| I10 | Itens/cartas/gold têm um dono; encaixes seguem host; unlock não duplica bens |
| I11 | Perfil, estado de expedição e recibos concordam após qualquer falha de gravação |
| I12 | Morte não apaga build/mácula/loot; revive idempotente aplica somente a penalidade aprovada |
| I13 | Conclusão tem um bônus gold/EXP; quest antecipada não recebe exceção implícita |
| I14 | Ativação/descarregamento não cura, reabastece summons, limpa ameaça ou créditos |
| I15 | UI/preview e execução usam as mesmas políticas/revisões; nenhum segredo de estado depende do desenho |

## Liberação

Atualização de coordenação18/10 posterior à arquitetura: F0 integrado em
`42604ef8674a2c28f5aadc633b73cda15178e0b3`; F1 autorizado pelo usuário, com
combate D05 aprovado e apresentação ainda pendente. [Despacho F1](e07/f1_dispatch.md)
delimita o trabalho independente permitido; demais propostas seguem pendentes.

Registro histórico da rodada arquitetural: somente arquitetura estava autorizada. F0 é o primeiro pacote técnico
preparável após integração documental e dispatch explícito com SHA real. Outros
pacotes aguardam produtores e decisões indicados no plano. Nenhum SHA futuro é
fornecido. Coordenação integra documentos e registra base; este chat permanece
arquitetural, sem implementar, despachar ou integrar. Não há gate Astra automático.
