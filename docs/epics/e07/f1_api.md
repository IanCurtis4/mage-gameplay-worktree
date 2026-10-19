# E07-F1 — API lógica e consumidores em integração

18/10/2026. **EM_EXECUÇÃO; não é a entrega completa F1.**
[Despacho](f1_dispatch.md), [matriz de kits](f1_skill_geometry_matrix.md),
[recibo](delivery/f1.md). Combate D05 autorizado; apresentação ainda pendente.
Este checkpoint não habilita mapa multialtura no menu nem prova os dez kits.

## Autoridade e unidades

`WorldGeometry` consome `ExpeditionManifest.to_data()` real de F0 e copia o estágio.
Não altera Manifest, Resources, gerador, testemunhas ou fórmulas. X/z horizontais,
y vertical, mesma unidade do combate legado. Não recebe pixels projetados.
`ExpeditionWorldPoint` mantém stage_id/surface_id/position. Um suporte desconhecido,
altura fora do plano ou destino ilegal falha; não há nearest-point em F1.

Envelope de consultas: `{ok: bool, error_code: StringName, geometry_revision: int,
data: Dictionary}`; DTOs de saída são cópias. Falha tem data vazio.
configuration_revision aumenta só em configure bem-sucedido. Consumidores capturam
essa identidade: uma revisão nova de obstáculo é reconsultada, enquanto substituir
o mundo invalida atores/voos/áreas/volumes/canais antigos com world_reconfigured.
Release de ator antigo não remove ocupante da nova configuração com o mesmo ID.
Isso é proteção de identidade, não implementação de transição/freeze de F2.

A geometry_revision é local à instância, monotônica em configure/insert/remove; não é a
revision de conteúdo F0. O consumidor precisa conservar também o hash do Manifest.
Uma consulta antiga não autoriza mover ou commitar após alteração da revisão.

## WorldGeometry

| Assinatura real | Resultado e limites |
|---|---|
| `configure(manifest: ExpeditionManifest, stage_id: String) -> Dictionary` | Copia estágio e retorna manifest_hash/stage_id. Reseta ocupantes e obstáculos; invalida revisões anteriores. Falha preserva configuração anterior. |
| `support_at(surface_id: String, horizontal: Vector2, revision: int) -> Dictionary` | Ponto sobre o plano contínuo da superfície indicada. É consulta explícita de suporte, não seleção de piso por proximidade. Não verifica folga do ator; usar position_query. |
| `position_query(point: ExpeditionWorldPoint, profile: Dictionary, revision: int) -> Dictionary` | Suporte/raio/altura e lista ordenada occupants cujos volumes se sobrepõem. Não reserva nem impede atualização de um ocupante existente. |
| `set_occupant(id: String, point: ExpeditionWorldPoint, profile: Dictionary, revision: int) -> Dictionary` | Registra/atualiza cópia do ponto e perfil; IDs são fornecidos pelo consumidor. |
| `remove_occupant(id: String) -> void` | Remove ocupação; não altera geometria. |
| `path(from: ExpeditionWorldPoint, to: ExpeditionWorldPoint, profile: Dictionary, revision: int) -> Dictionary` | points, connection_ids, cost. Destino exato ou erro. Dijkstra no grafo finito de visibilidade: conectores insetados e cantos dos AABBs. Custo soma segmentos 3D reais. Não promete menor caminho contínuo em toda a largura dos conectores. |
| `sweep(from: Vector3, to: Vector3, collider: Dictionary, revision: int, mask: StringName = &"all") -> Dictionary` | hit, fraction [0,1], position, normal, volume_id. Sweep contínuo contra AABBs expandidos pelo corpo vertical. `all` inclui blockers/solids e obstáculos temporários; `supporting_slabs` só sólidos autorados que suportam piso horizontal. IDs temporários estáveis; não usa ordem de criação de Nodes. |
| `query_attack(shape: Dictionary, source: ExpeditionWorldPoint, target: ExpeditionWorldPoint, revision: int) -> Dictionary` | range_ok, los_ok, shape_ok, hit, distance, affected_surfaces. Não causa dano e não altera SP/cooldown. |
| `insert_obstacle(id: String, volume: AABB, revision: int) -> Dictionary` | Volume positivo/finito, ID único. Rejeita interseção com ocupantes e perda de qualquer socket autorado anteriormente alcançável por ocupante registrado. Rejeição é atômica e conserva revisão. |
| `remove_obstacle(id: String, revision: int) -> Dictionary` | Remove ID existente e avança revisão. |
| `resolve_surface(origin: Vector3, direction: Vector3, visible_surfaces: Array[String], revision: int) -> Dictionary` | Ray lógico; data.point e normal. Piso ausente/oculto, oclusão e empate falham. Não inclui câmera, projeção, ponteiro ou renderer. |

Perfil obrigatório: radius/height positivos e finitos; connector_kinds não vazio.
O perfil F0 `to_data()` é aceito diretamente. Collider de sweep usa radius/height
não negativos: origem nos pés, extensão horizontal por radius e vertical para cima
por height. Uma esfera emitida pelo centro precisa de sua origem/envelope explícitos.
Contato no topo do suporte não bloqueia o corpo; entrar na base de parede bloqueia.
Tolerância técnica 1e-5, sem degrau jogável. Não há promessa de escala extensa.

Shape exige geometry_rule_id e range finito não negativo. Regras executáveis:

- `direct_volume`: distância euclidiana 3D e sweep de oclusão; source_offset e
  target_offset Vector3 opcionais e explícitos permitem volumes aéreos.
- `ground_connected`: exige traversal; propagação usa rota real/custo nas conexões.
  Não aceita offsets aéreos. O orçamento segue o caminho encontrado; ainda não
  prova a menor distância contínua para toda autoria possível.
- `teleport_legal`: destino com suporte/folga e range 3D, sweep do corpo contra
  lajes de suporte. Conserva travessia de blockers planos e paredes temporárias
  do E06; não impõe LoS universal. O corpo pode sair do topo de um piso sólido.

affected_surfaces fica vazio quando hit=false; não declara pisos atingidos por uma consulta bloqueada.

Kind opcional: sphere (padrão), cone ou line. Cone/line exigem direction Vector3
finita não zero; cone usa half_angle em radianos [0,PI]; line usa half_width.
Não há multiplicador de dano por altura. self_only/inherit_parent/walk_path da
matriz são classificações de consumidores, não regras aceitas por query_attack.

A identificação de laje deste checkpoint cobre sólidos AABB com topo coincidindo
com superfície horizontal realizada. Rampas usam suporte planar contínuo; volumes
sólidos inclinados arbitrários não são certificados por esse predicado. WorldGeometry continua separando ocupação de sweep estático. WorldProjectileMotion
compõe o sweep estático com contatos contínuos contra corpos de atores; os limites
dos interceptores estão descritos abaixo.

Erros concretos: invalid_manifest, unknown_stage, stale_geometry, invalid_profile,
invalid_support, invalid_position, unknown_surface, invalid_identity, unreachable,
invalid_collider, invalid_mask, invalid_shape, unknown_geometry_rule,
invalid_destination, invalid_volume, occupied, would_disconnect, unknown_obstacle,
invalid_ray, ambiguous_surface, hidden_or_missing_surface, occluded_surface.

## Movimento e consumidores reais já adaptados

`WorldActorMotion.configure(world, point, profile, occupant_id)` valida/registra;
point()/profile() retornam cópias. plan(destination, revision) captura rota atual;
advance(distance) executa segmentos apoiados/swept, conserva superfície e rejeita
revisão obsoleta. Falha restaura ponto/cursor anteriores ao avanço. teleport
valida destino/alcance/lajes; release remove ocupante. Sem Node2D/câmera nessa classe.

`CombatActor.bind_world_geometry(world, point, traversal, occupant_id)` instala
movimento e mantém os relógios de status. PlayerActor/EnemyActor agora desviam a
locomoção para o ramo espacial; não executam o caminhamento legado em Vector2.
world_point(), world_distance_to(), world_attack_query() e world_can_reach()
compartilham os pontos/perfis reais. O último usa LoS entre centros dos corpos.
_exit_tree libera ocupação. Não sincroniza desenho, global_position ou input.

`WorldActorMotion.cancel()/has_route()` controlam a rota explícita. displace(destination,
maximum_distance, revision) aceita somente rota colinear em x/z (pode subir rampa),
avança pelo orçamento 3D e encerra a rota. Rejeita desvio ao redor de parede;
falha conserva ponto/rota anteriores. Não aproxima destino inválido.

`PlayerActor.use_world_teleport(destination, revision)` e use_world_dash(destination,
revision) usam custos/cooldowns canônicos; falha espacial não gasta. Dash agora
avança pelo tick na duração DASH_DURATION, sobre a rota, com interrupção por
controle/revisão. Movimento normal e pursuit de básico também usam WorldActorMotion.
Use_world_shield_wall(direction: Vector3, revision) aceita direção horizontal
explícita e reutiliza rank/pagamento/resistência existentes. Mitigação frontal e
interceptação usam posições/corpos lógicos. As quatro entradas self_only ficam
liberadas; as demais ativas legadas continuam recusadas. Não é kit completo.

O preflight do básico ranged valida o envelope de lançamento antes de iniciar
a recarga: uma linha central livre não basta se o corpo do projétil começa em parede.
O básico real das dez identidades emite world_attack_requested(request, target,
projectile_kind). RunController conecta o sinal: melee revalida oclusão/alcance,
projéteis usam a trajetória lógica e os callbacks canônicos de dano/efeitos.
O controlador também liga flecha e magia dos mobs bound à mesma trajetória.
Os perfis da fixture são explícitos; o envelope emitido pelo controlador usa
projectile_radius horizontal e height=2*radius, centralizado no corpo lógico.
Nenhum desses valores vem da posição dos sprites.

EnemyActor mantém aquisição, percepção, perseguição, medo, taunt, preparação,
leash/timeout e retorno ao WorldPoint home. Archer conserva a política de standoff;
o endpoint precisa ter suporte/rota exatos, sem nearest-point. Cast de mob captura
a revisão e revalida revisão/alcance/LoS antes de SP/cooldown. A fixture prova
travessia autônoma e retorno por rampa, laje impedindo percepção e cast obsoleto.
Invocações/posicionamento de companions e demais spawns continuam pendentes.
Um mob bound com summons retorna diagnóstico spatial_spawn_required antes de
reivindicar summon_used; não chama o spawn plano por fallback.

## Trajetórias, áreas e interceptores reais

WorldProjectileMotion.configure(world, origin: WorldPoint, offset: Vector3,
facing: Vector3, collider, maximum_distance, revision) captura a origem/collider.
contact(distance, actors) retorna data com actor, terrain, distance, fraction,
position, volume_id e exhausted. Usa a revisão ATUAL por passo de voo: parede
inserida após lançamento intercepta. Alvo de outro mundo/sem binding falha com
incompatible_target. Não procura piso para ponto aéreo e não usa BODY_OFFSET.
O envelope é cilindro vertical: raio x/z, height para cima; contato de corpos
intersecta quadratic radial e intervalo vertical, sem amostragem por frame.
Empate corpo/terreno conserva a prioridade do projétil aliado; corpos empatados
usam instance_id. Piercing exclui antes do callback e tolera alvo removido nele.

PlayerProjectile.bind_world_flight(world, origin, offset, facing, collider, revision)
instala essa trajetória para PlayerProjectile/MageProjectile/SentinelProjectile;
_prepare_impact, causalidade e modificadores permanecem canônicos. Homing acompanha
o corpo 3D. ArrowProjectile expõe o mesmo binding para voo hostil fixo e ordena
corpo, terreno, escudo e PhantomBarrier. GeometerWallField legado é recusado com
spatial_interceptor_required; transporte, payloads e triângulos ainda bloqueiam F1.
SentinelAreaProjectile ainda não usa esse ramo: sua ativa permanece bloqueada.

WorldEffectArea.configure(world, anchor, traversal, rule, revision) captura cópias;
rule exige ground_connected ou direct_volume. query(actor, range, shape),
query_point(WorldPoint, range), contains_actor(actor, radius), distance_to(actor)
reconsultam a geometria atual. contains_actor acrescenta raio do perfil real;
query conserva o alcance exato. Ground propaga por caminhos/conexões, nunca por
sobreposição dos sprites. ArrowRain e PlayerTrap usam bind_world_area com essa
âncora: cada volley/trigger consulta alvos atuais; ExplosiveTrap/HunterTrap usam
a mesma regra no blast. Entrada de cast/placement dessas ativas segue pendente.

HunterTarField.bind_world_area ancora slow e a reação por
consume_for_world_explosion(center: WorldPoint, blast_radius); consumo remove slow
antes de callbacks e retry não repete. FoliageShelter.configure_world(player, anchor,
traversal, duration, radius, exit_grace, revision) registra suporte no PlayerActor;
membership/revelação por observador usam query exata. HunterCoverState conserva
seus relógios/budget/grace: dois valores sentinela apenas codificam o booleano de
membership para sua API existente, sem fazer distância de gameplay em Vector2.
RewardPickup.bind_world_area/can_collect_world usam distância de chão exata; a
ligação de spawns/chegadas e do nascimento desse loot segue pendente.

WorldEffectVolume.configure(world, anchor, profile, bounds: AABB, revision) recebe
volume finito explícito; fraction/actor_fraction fazem sweep contínuo do corpo.
PhantomBarrier.bind_world_volume usa esse volume para cruzamentos e intercepção;
capacidade é reivindicada antes do callback. AABB técnica não certifica faixa
rotacionada, construção multissuperfície ou uma política nova de dimensões finais.
Barreira legada ativa em voo hostil bound falha explicitamente. Limites físicos
novos e a escala final ainda precisam da amostra/contrato aplicável.

Em atores bound, o controlador recusa input/aim legado até D05 visual. Isso não
é renderer/projeção/clique implementados. APIs opt-in da fixture não habilitam
um estágio de produção no menu. Teste de consumidor não certifica sozinho o cast,
preview, item/augment, construção ou kit completo listado na matriz.

## Canais e pulsos finitos

WorldLockedAction.configure(caster, target, maximum_range, stationary, revision)
valida o par real e captura origem/identidade do mundo. validate() reconsulta
alcance/oclusão atuais; stationary também cancela por mudança de WorldPoint ou
root/stun/fear. paused() conserva o relógio. Usa o mesmo EPS de movimento do ator.
SpiritualistDrainState.start_world e SpiritualistProcessionState.start_world
recebem caster/target/request/range/revision e usam esse guard nos agendadores
existentes: quatro ticks e três aparições, respectivamente. Não alteram potência,
recovery, inscrição, heal ou planos causais. scheduled_tick mantém a regra E06:
raiz intrínseca própria por pulso, com ancestor_root_id da emissão original.
RunController liga os pedidos bound a essas entradas e consulta alvo em 3D.

SpiritualistVeilState.start_world(world, anchor, profile, duration, revision) usa
WorldEffectArea; contains_actor/query ground e o controlador mantêm aplicação e
remoção da própria fonte de weaken. O placement de Véu agora entra por request_world_skill, conforme a seção abaixo.

ElementalistSequence.configure_world(caster, anchors: Array[WorldPoint], requests,
elements, radius, interval, once_per_target, revision, marked_bonus) valida TODAS
as âncoras antes do primeiro pulso, copia requests e conserva schedule/hit_ids.
world_pulse_requested entrega WorldEffectArea ao callback espacial do controlador,
que reaproveita a aplicação elemental canônica. As posições Vector2.ZERO são
somente placeholders de apresentação; o ramo world nunca calcula alcance nelas.
Tri Nova captura a origem pelo cast espacial; Ember Path e seus demais efeitos
seguem pendentes. APIs de consumidor não equivalem a suporte completo de kit.

## Entrada transacional de habilidades

`PlayerActor.preview_world_skill(skill, anchor: WorldPoint, facing: Vector3,
victim: CombatActor, actors: Array[CombatActor], revision, requested_rank=0)`
retorna `{ok,error_code,data}`. Preview não inicia preparo, não move o ator,
não paga nem altera recarga/status da última intenção. Quando aceita, data contém
skill_id, geometry_revision, source/anchor copiados e specs de todos os projéteis.
Não é seleção por clique: o chamador fornece superfície e direção lógicas.

`request_world_skill` tem os mesmos argumentos; `RunController.cast_world_skill`
recebe a mesma intenção sem actors, usando sua lista real de inimigos. Retorna
state preparing ou committed quando aceita. `world_cast_status()` copia o último
resultado. WorldSkillCast captura origem/âncora, direção, weak refs, rank/capture,
configuration_revision, geometry_revision e composition_revision do RunState.
Origem/destino não são reconstruídos a partir de centros Vector2 dos sinais antigos.
Alvo dirigido pode mover durante preparo se ainda satisfizer alcance/oclusão;
a direção do tiro acompanha o alvo atual no commit. Direção livre permanece capturada.

Validação ocorre na entrada, a cada tick de preparo, no commit e imediatamente
antes do custo canônico. Stun/fear/pausa, HP não letal de Execução, token de Riposta,
Foco do Sentinela, elegibilidade/rank, fontes, capacidade, suporte, revisões e
alvo/LoS pertinentes podem recusar. Alterar a composição durante preparo invalida
com stale_build; remover a última fonte também pode retornar skill_unavailable
ou cast_cancelled quando a camada de modificadores cancela o preparo primeiro.
Troca do mundo, revisão de obstáculo, movimento do caster e alvo removido retornam
world_reconfigured/stale_geometry/caster_moved/invalid_target. Falhas pré-commit
não pagam SP/recarga nem emitem o efeito. Claims de commit precedem callbacks;
reentrada retorna cast_busy. O contexto de rank externo é restaurado.

Projéteis prevalidam TODAS as origens e seus cilindros físicos (Mago raio6/altura12,
precisão raio4/altura8), incluindo deslocamento lateral de14 unidades. Count e
range/custo/potência usam a captura composta do rank selecionado; geometria e
capacidade se revalidam antes do pagamento único. `world_cast_projectiles(skill)`
fornece cópias apenas durante a emissão comprometida. O controlador configura
Player/MageProjectile e liga WorldProjectileMotion, homing/piercing e callbacks
canônicos. Uma parede surgida depois do commit pode interceptar o voo pago.
GeometerWallField legado requer spatial_interceptor_required; não é ignorado.

`world_cast_anchor()` fornece cópia durante a emissão. Chuva, traps base,
Flame Burst, Glacial Ring, Tri Nova e Véu consomem essa âncora explícita. Tri Nova
configura suas três áreas/schedule originais; Dreno/Procissão iniciam os guards
espaciais existentes. Cones/linhas corpo a corpo consultam direção/LoS 3D no
handler canônico, sem refazer fórmulas. Os placeholders Vector2 são apresentação.

Whitelist nominal em WorldSkillCast (39 IDs), também exposta como cast_entry no
inventário: alvo dirigido, cones/linhas, oito tipos de projétil, seis placements,
quatro áreas próprias e quatro estados self_only. Isso informa entrada disponível,
não certifica todos os efeitos de um kit. Shield Wall/dash/teleporte conservam
as APIs espaciais próprias já documentadas. Snare/Explosive herdadas pela Caçadora
retornam spatial_hunter_composition_required até ligar reação/abertura espaciais;
Geômetra, ecos, paredes, demais campos e mobilidades continuam pendentes.

SoulImpactSequence.configure_world(caster, request, target, range, revision) liga
WorldLockedAction não estacionário ao schedule original de três impactos. Mantém
a divisão canônica do orçamento e scheduled_tick; consulta alcance/oclusão antes
de CADA pulso, inclusive entre callbacks dentro do mesmo frame. Pausa congela;
alvo removido, parede ou troca do mundo encerram somente o restante já pago.
configure legado recusa alvo bound sem guard. Assombro consulta cone/LoS 3D;
Grito Perfurante/Intimidador consultam área de chão da origem capturada, mantendo
a política original de raio sem padding. Dissipação usa placement WorldPoint e
consulta membership antes de dano, Foco, bônus por marca e weaken canônicos.

## Adaptador plano e próximos consumidores

`FlatWorldGeometry.new(navigation: ArenaNavigation)` é adaptador explícito E06;
world_point(Vector2) cria stage legacy_arena/surface legacy_arena/floor e y=0.
path(from,to,revision) delega sem alterar pontos legados e informa requested_destination,
resolved_destination/destination_adjusted, inclusive nearest-point do legado.
query_attack(source,target,maximum_range,teleport,revision) conserva a exceção plana.
Outra altura/superfície é invalid_support; não a descarta silenciosamente.
O adaptador está testado, mas o piloto não foi refeito para passar por essa classe.

Spawn/chegada poderão usar position_query e ocupação; reserve_spawn/portal_arrival,
lifecycle, reserva idempotente e regras de segurança da campanha não foram implementados.
A matriz distingue os consumidores já ligados dos casts, construções, canais,
interceptores e suportes dos kits ainda pendentes. O próximo executor deve continuar
neste F1, sem liberar amostra multialtura enquanto houver esses bloqueios.
