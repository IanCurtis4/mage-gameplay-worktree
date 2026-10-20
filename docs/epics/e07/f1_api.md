# E07-F1 — API lógica e consumidores em integração

18/10/2026. **EM_EXECUÇÃO; não é a entrega completa F1.**
[Despacho](f1_dispatch.md), [matriz de kits](f1_skill_geometry_matrix.md),
[recibo](delivery/f1.md). Combate D05 e apresentação técnica 2,5D autorizados. Aprovação visual humana em20/10/2026: “Aprovar a proposta D05”. Validação do candidato no recibo.
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
| `path(from: ExpeditionWorldPoint, to: ExpeditionWorldPoint, profile: Dictionary, revision: int) -> Dictionary` | points, connection_ids, cost. Destino exato ou erro. Dijkstra no grafo finito de visibilidade: conectores insetados, cantos dos AABBs e pontos de desvio das cápsulas orientadas. Custo soma segmentos 3D reais. Não promete menor caminho contínuo em toda a largura dos conectores. |
| `sweep(from: Vector3, to: Vector3, collider: Dictionary, revision: int, mask: StringName = &"all") -> Dictionary` | hit, fraction [0,1], position, normal, volume_id. Sweep contínuo contra AABBs e cápsulas verticais orientadas, expandidos pelo corpo explícito. `all` inclui blockers/solids e obstáculos temporários; `supporting_slabs` só sólidos autorados que suportam piso horizontal. IDs temporários estáveis; não usa ordem de criação de Nodes. |
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
liberadas; as demais ativas usam as entradas espaciais nominais descritas abaixo e recusam a entrada2D no binding.

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
Nascimento técnico e animal finito usam as entradas descritas ao final;
spawn/respawn/lifecycle de expedição continuam fora deste bloco.
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
spatial_interceptor_required; o campo espacial suporta transporte/payloads/triângulos conforme seção Geômetra.
SentinelAreaProjectile usa o ramo espacial próprio de Rede/Explosivo descrito abaixo.

WorldEffectArea.configure(world, anchor, traversal, rule, revision) captura cópias;
rule exige ground_connected ou direct_volume. query(actor, range, shape),
query_point(WorldPoint, range), contains_actor(actor, radius), distance_to(actor)
reconsultam a geometria atual. contains_actor acrescenta raio do perfil real;
query conserva o alcance exato. Ground propaga por caminhos/conexões, nunca por
sobreposição dos sprites. ArrowRain e PlayerTrap usam bind_world_area com essa
âncora: cada volley/trigger consulta alvos atuais; ExplosiveTrap/HunterTrap usam
a mesma regra no blast. Entradas de cast/placement dessas ativas estão descritas nas seções transacionais e nominais abaixo.

HunterTarField.bind_world_area ancora slow e a reação por
consume_for_world_explosion(center: WorldPoint, blast_radius); consumo remove slow
antes de callbacks e retry não repete. FoliageShelter.configure_world(player, anchor,
traversal, duration, radius, exit_grace, revision) registra suporte no PlayerActor;
membership/revelação por observador usam query exata. HunterCoverState conserva
seus relógios/budget/grace: dois valores sentinela apenas codificam o booleano de
membership para sua API existente, sem fazer distância de gameplay em Vector2.
RewardPickup.bind_world_area/can_collect_world usam distância de chão exata.
Nascimento técnico e coleta estão ligados conforme seção própria; ciclo de expedição/produção continua fora de F1.

WorldEffectVolume.configure(world, anchor, profile, bounds: AABB, revision) recebe
volume finito explícito; fraction/actor_fraction fazem sweep contínuo do corpo.
PhantomBarrier.bind_world_volume usa esse volume para cruzamentos e intercepção;
capacidade é reivindicada antes do callback. AABB técnica não certifica faixa
rotacionada, construção multissuperfície ou uma política nova de dimensões finais.
Barreira legada ativa em voo hostil bound falha explicitamente. Limites físicos
novos e a escala final ainda precisam da amostra/contrato aplicável.

Em atores bound sem adaptador de apresentação, input/aim legado é recusado. Com ExpeditionGeometryView ligado, input e preview usam WorldPoints conforme a seção D05. A amostra opt-in não habilita um estágio de produção no menu; testes lógicos, integração nominal e inspeção visual têm evidências separadas no recibo.

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
têm suas entradas nominais descritas abaixo. APIs isoladas não substituem a evidência consolidada por kit.

## Entrada transacional de habilidades

`PlayerActor.preview_world_skill(skill, anchor: WorldPoint, facing: Vector3,
victim: CombatActor, actors: Array[CombatActor], revision, requested_rank=0, field_height=0.0)`
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

Whitelist nominal em WorldSkillCast (63 IDs), também exposta como cast_entry no
inventário: alvo dirigido, cones/linhas,14 tipos de projétil,13 placements,
cinco áreas próprias e quatro estados self_only. Explosivo usa captura interna
pelo próximo auto e API de reserva própria;62 IDs admitem request comum. Isso
classifica intenções, sem certificar todos os efeitos de um kit. Shield Wall/dash/teleporte conservam
as APIs espaciais próprias já documentadas. As cinco famílias de armadilha,
recuo/Leque e coberturas da Caçadora usam os bindings abaixo. Rede/Explosivo usam
voo/áreas/reserva próprios abaixo. Fogo/Raios/Barreira usam os campos descritos
abaixo; Gelo usa o obstáculo orientado descrito ao final. Geômetra tem entrada própria e campos não planos usam patches de suporte explícitos.
Marco/Onda/Fenda e Avanço/Retirada/Salto usam os bindings descritos abaixo.

WorldTargetLock.configure(caster,target,range,revision) valida alcance/LoS somente
na admissão e captura alvo fraco, estágio e identidade da geometria. validate()
conserva o vínculo com esse corpo/suporte atual; não depende da vida/posição do
caster nem adiciona LoS/range aos pulsos emitidos. Troca do mundo ou morte/remoção
do alvo encerra o restante. point() copia o WorldPoint atual do alvo travado.

SoulImpactSequence.configure_world(caster, request, target, range, revision) liga
esse lock ao schedule original de três impactos. Mantém divisão canônica,
scheduled_tick e pausa. O alvo pode se mover/subir por conectores, inclusive
separar-se do caster por uma parede após o commit: os pulsos já emitidos seguem
o mesmo alvo. Revalida identidade/suporte entre callbacks sem virar um canal.
configure legado recusa alvo bound sem guard. Assombro consulta cone/LoS 3D;
Grito Perfurante/Intimidador consultam área de chão da origem capturada, mantendo
a política original de raio sem padding. Dissipação usa placement WorldPoint e
consulta membership antes de dano, Foco, bônus por marca e weaken canônicos.

## Trilha direcional no suporte

WorldGeometry.ground_line_samples(source,heading,spacing,count,profile,revision)
segue a direção horizontal x/z; y vem das superfícies reais. spacing mede distância
3D acumulada, inclusive rampas. Retorna data.points copiados com superfície e
posição, truncated e stop_reason. Aceita só aberturas/conexões autorizadas pelo
perfil, sem detour, salto entre projeções ou reparo de destino. Obstáculo/borda
encerra o prefixo. Query inválida/stale falha; prefixo vazio é no_valid_centers no
cast e não paga. A geometria não registra movimento/ocupante nesta consulta pura.

WorldSkillCast captura e revalida esse plano para Trilha de Brasas antes do custo.
preview expõe ground_points copiados; world_cast_ground_points(skill) entrega
WorldPoints durante o handler. Os três centros a80/160/240 unidades, ou prefixo
legal, alimentam ElementalistSequence com áreas próprias, intervalos0.15 e um
claim por alvo/emissão. Movimento posterior do caster não move centros. Pausa,
remoção/morte da fonte ou troca do mundo impedem próximos pulsos; cada área usa
geometria atual ao resolver dano. Não há fórmula nova nem segundo hit na sobreposição.

## Ecos e saltos elementais

SpiritualistEchoState.mark_world(target,power) registra marca com identidade de
mundo/superfície separada de posições de apresentação. No gatilho, a onda congela
política, lista elegível e contexto causal atuais. Cada portador agenda sua própria
WorldEffectArea copiada; a origem fixa conserva esse suporte e a origem móvel
captura o ponto atual na resolução. A retirada de augment não muda a onda emitida.
Reaplicação preserva identidade espacial para a próxima ação; claims de portador/
par, delay, dano e limites finitos continuam canônicos. É a exceção explícita de
Eco do ledger, não nova raiz/proc genérico. Inscrição de Drenagem usa mark_world.

RunController aplica Maldição coletiva e ecos com ground_connected, ressample na
resolução e entre callbacks. Laje/conexões/range usam unidades lógicas; coordenadas
Vector2 antigas só apresentam VFX. Morte/remoção antes do delay cancela a onda do
portador. Morte durante explosão já iniciada conserva a origem capturada e pode
atingir vizinhos válidos, conforme o contrato nominal. Troca do mundo invalida a
área inteira; remoção da fonte não pode desreferenciar um ator liberado.
WorldEffectArea.is_current_world() permite esse teste de época sem query hostil.

Arco Voltaico tem entrada WorldSkillCast e até dois saltos por volume direto.
Cada salto escolhe o alvo vivo legal mais próximo do WorldPoint anterior, com
range3D/offsets reais do corpo, oclusão e desempate por ID. Captura o próximo ponto
antes de callbacks letais, sem permitir atravessar lajes ou migrar mundos. Repete
admissão antes do dano; dano nulo encerra. Primário e saltos secundários continuam
no resolver central com os coeficientes, marca/bônus/stun e orçamento originais.
A prova lógica desses consumidores não aprova apresentação multialtura.

## Guardas, campos e deslocamentos com contato

WorldGeometry.trace_ground(source,heading,maximum_distance,profile,revision) é
consulta pura: conserva a direção x/z, segue y das superfícies e mede custo3D.
Retorna data.points (rota copiada com seams), cost, destination e truncated.
Usa ground_line_samples e até32 refinamentos de prefixo para parar antes do
primeiro sólido/borda/abertura incompatível, sem detour ou salto por projeção.
O suporte é verificado continuamente nos intervalos dos predicados de borda e
abertura; endpoints legais não permitem atravessar uma lacuna intermediária.
Prefixo de custo0 é resposta geométrica válida; o cast o recusa antes do custo.
Ground_line_samples acrescenta data.route quando completa os centros pedidos.

WorldActorMotion.plan_ground_line(heading,distance,revision) instala essa rota.
advance(distance) acrescenta data.segments: cada segmento real tem from/to
WorldPoint DTO, incluindo suporte correto nas transições. WorldTravelContact.first
consulta cilindros e oclusão nesses segmentos; não testa a corda entre endpoints
em andares distintos. Salto escolhe primeiro contato por distância/ID; Avanço
conserva a ordem nominal da lista entre contatos elegíveis do frame. Claim antes
do callback limita cada emissão a um alvo; alvos removidos usam referências fracas.

WorldSkillCast acrescenta Marco, Onda, Fenda, Avanço, Retirada e Salto. Preview
inclui travel_plan copiado com maximum_distance composto. Controle/rota inválida
rejeitam antes de custo. Deslocamento pago captura dano/rank e revalida suporte
após callbacks; troca do mundo cancela o efeito sem migrá-lo. Avanço/Salto usam
DASH_DURATION, respeitam pausa e param por controle/revisão/epoch/cleanup ou nova
mobilidade. Retirada faz passo imediato apoiado para trás, mantendo frente3D
original. As três guardas guardam direção3D própria; Shield Wall conserva a frente
horizontal de sua API explícita. Mitigação/eventos usam dano já aceito, sem nova LoS.

Marco armazena WorldEffectArea no suporte colocado. DEF própria e slow de inimigos
usam defender_anchor_contains(actor), raio100 sem padding nominal. Onda usa somente
a origem do Marco ativo, ou somente o caster na ausência dele; conserva token,
dano e padding originais. Empurrão de35 unidades segue suporte, para em sólidos/
bordas e respeita imunidade de boss. Fenda usa ground_connected e strip nominal
x/z220×44; alcance de chão inclui a altura percorrida, a largura não vira um tubo
aéreo. Hemorragia/DeepBleeding herdam o evento aceito e seguem o alvo sem nova LoS.
Não há alteração de fórmulas, catálogo ou significado de SP/token/feridas.

## Disparos diretos do Sentinela

WorldSkillCast acrescenta Tiro na Cabeça/Concussão dirigidos ao alvo e Perfurante
direcional. Preflight usa o cilindro real de precisão (raio4/altura8), origem no
corpo, alcance3D/oclusão e capacidade antes de cobrar. SP e Foco passam pelo
handler canônico use_sentinel_reset; não se duplica SentinelMath ou o ledger.
Cada reset mantém um único projétil especial, recuperação normal do auto e
barreira contra outro auto no mesmo frame. Concussão continua com custo0 de Foco.
A política SkillCastRank existente conserva esses IDs no maior rank aprendido:
requested_rank explícito é recusado. Este delta não amplia essa política.

RunController reutiliza _spawn_world_cast_projectiles(...,sentinel=true) para
criar SentinelProjectile real. Cabeça/Concussão seguem o corpo-alvo por homing;
Perfurante visita até20 corpos, uma vez cada. Dano/crit, stun/debuff e Foco/Leitura
continuam nos callbacks canônicos com payload capturado no lançamento. Pausa,
novo sólido, perda do alvo, troca do mundo e retirada posterior do build têm
cobertura dirigida. A retirada não recalcula um projétil já emitido.

PlayerActor._process remove Postura antes de um auto no mesmo frame após
movimento lógico externo, mesmo sem deslocamento do sprite; Foco e estabilidade
já observam WorldPoint. Marca de Observar também é limpa quando o corpo deixa
de existir. Rede/Explosivo usam os adaptadores próprios descritos abaixo.
Isso não certifica o kit inteiro nem sua apresentação.

## Mecanismos, recuo e coberturas da Caçadora

WorldSkillCast acrescenta Congelante/Piche/Espinhos, Abrigo, Cobertura Total e
Tiro de Cobertura; Laço/Explosiva herdadas deixam o bloqueio temporário anterior.
Colocação/preview/preparo usam suporte/conexões/range reais. A LoS nominal Hunter
é adicional à propagação de chão, consultada na colocação, trigger e em cada
vítima após callbacks. Não se torna LoS universal para outros efeitos de chão.
IDs desconhecidos continuam unsupported_world_skill; não há fallback por mira.

_hunter_trap_policy_check() é a admissão única de Mecanismo Marcado: exige Marca
viva elegível antes do custo e captura o ID no trap emitido. Trocar/expirar Marca
ou retirar receita não redireciona o mecanismo; alvo morto/removido não transfere
o trigger. FIFO3, armar, lifetime, abertura, CC, bleed e Passo continuam canônicos.
Laço/Congelante são presa única; Piche/Espinhos abrem os ocupantes iniciais.
Referências liberadas são filtradas antes de conversão tipada, inclusive depois
do primeiro callback de dano. Estado TRIGGERED é reivindicado antes dos callbacks.

Piche nasce com área copiada da âncora do trap. Entradas tardias recebem slow
sem nova abertura. A reação usa consume_for_world_explosion(WorldPoint,radius),
conexão de chão/alcance e LoS entre centros; identidade do mundo do dono também
precisa coincidir, mesmo se dois mundos tiverem os mesmos IDs/coordenadas. Uma
reação consome campo/slow próprio antes dos hits; bônus e pedido original mantêm
a matemática existente. Epoch/incompatibilidade do dono encerra campo sem migrá-lo.
Bleed aplicado herda aceitação e segue a vítima sem reavaliar LoS a cada tick.

Tiro de Cobertura preflighta projétil4×8 e TODO o recuo80 em suporte (métrica3D).
Prefixo truncado/borda/controle recusa tiro e recuo sem custo. A emissão captura
origem anterior; o passo imediato não muda os clocks do auto e o voo usa os specs
capturados, não a posição atual do caster. Leque seleciona após o hit o próximo
corpo vivo mais próximo por distância3D≤80, LoS e desempate por ID. Preserva as
metades, fallback, claims/ledger e exceção de secundário já existentes; não consome
a abertura do segundo corpo. Receita retirada após o disparo não muda o snapshot.

Abrigo e Cobertura Total usam FoliageShelter.configure_world e área no suporte.
HunterCoverState continua dono do budget3s/revelação1.25s/graça até1s/CD comum18s;
membership e observador usam WorldPoints. Abrigo conserva raio110 sem graça extra;
Total usa125/graça1. Expiração/cleanup/epoch removem zona/graça sem devolver budget
ou apagar reveal. A API de ator continua already_bound; não foi criado rebind,
respawn ou lifecycle F2. Archer base conserva seu contrato sem budget Hunter.
Bindings opt-in e fixtures dirigidas não habilitam apresentação D05 ou campanha.

## Rede e munição Explosiva do Sentinela

Na retomada de Rede/Explosivo, WorldSkillCast classificava59 IDs nominais: Rede acrescenta intenção de ponto e
Explosivo usa a captura interna de alvo. Explosivo NÃO admite request/preview
comum: retorna reservation_entry_required. A entrada explícita é
PlayerActor.prepare_world_sentinel_explosive(revision) -> Dictionary, que valida
binding/suporte/revisão e chama a reserva/cancelamento canônico. Nenhum custo,
root causal, CD ou reset é criado ao reservar. Segundo toggle libera; cancelamento
explícito anterior continua disponível. Pausa/controle, recursos livres e ranks
continuam nas autoridades anteriores; não se inventa expiração em combate.

Próximo auto revalida alvo3D/LoS, origem/cilindro4×8, capacidade e recursos totais
reservados antes de liberar a reserva. O handler canônico paga SP/Foco uma vez,
substitui o dano físico por SentinelMath e emite com recuperação normal. Resets
não consomem munição. Reentrada de cast/reserva durante emissão é cast_busy.
Falha pré-lançamento conserva reserva/custo/CD; perda do alvo após lançar termina
sem refund. Retirar build não recalcula um pedido já emitido.

Rede conserva preparo DES/custo/CD e root magic posterior ao impacto positivo,
sem reset do auto nem custo de Foco. WorldPoint de destino é explícito e validado
por alcance no chão conectado; não há clamp/snap silencioso do destino inválido.
SentinelAreaProjectile.bind_world_delivery(world,spec,profile,endpoint) liga os
specs capturados ao voo contínuo real. Primeiro corpo captura seu suporte; endpoint
sem contato conserva o suporte escolhido. Contato de terreno consulta
WorldGeometry.ground_line_point_at(source,horizontal,profile,revision): percorre
somente a direção original e conexões apoiadas até aquele x/z, sem buscar andar
vizinho, detour ou prefixo reparador. Sem suporte legal, não abre área. Compartilha
travessia com ground_line_samples; esta mantém sua métrica3D anterior. Rede de
distância zero abre no próprio WorldPoint, sem fabricar alcance de projétil.

world_burst(WorldEffectArea,Vector3,DamageRequest,Dictionary) reivindica abertura
antes de callbacks. Rede consulta alcance/conexão de chão e LoS nominal por
vítima. Explosivo usa centro3D real do cilindro no impacto e o centro do corpo da
vítima, com raio nominal+raio do corpo, sweep de oclusão e sem projetar em piso
próximo. WorldEffectArea guarda um suporte fonte válido e source_offset explícito
para esse centro aéreo; isso não o converte em área de chão. Um único loop de
dano preserva deduplicação/ledger/Foco/Leitura e não soma hit direto ao burst.
Vítimas são revalidadas após callbacks; referências liberadas são filtradas antes
da conversão tipada. Epoch termina voo; obstáculo tardio intercepta geometria atual.
O burst multialtura não desenha VFX com coordenadas lógicas como se fossem pixels;
renderer/input/prova visual usam a amostra D05 descrita ao final.

## Adaptador plano e próximos consumidores

`FlatWorldGeometry.new(navigation: ArenaNavigation)` é adaptador explícito E06;
world_point(Vector2) cria stage legacy_arena/surface legacy_arena/floor e y=0.
path(from,to,revision) delega sem alterar pontos legados e informa requested_destination,
resolved_destination/destination_adjusted, inclusive nearest-point do legado.
query_attack(source,target,maximum_range,teleport,revision) conserva a exceção plana.
Outra altura/superfície é invalid_support; não a descarta silenciosamente.
O adaptador está testado, mas o piloto não foi refeito para passar por essa classe.

Nascimento técnico usa spawn_world_enemy descrito abaixo. reserve_spawn/
portal_arrival, lifecycle, reserva idempotente, reposição e regras de segurança da
campanha não foram implementados.
A matriz distingue os consumidores já ligados dos casts, construções, canais,
interceptores e suportes dos kits descritos nas seções nominais. O recibo consolida
as evidências deste F1 e a amostra multialtura técnica aprovada na D05.

## Nascimento técnico, animal finito e coleta

RunController.spawn_world_enemy(entry,point,traversal,revision,stage=1,
companion_traversal={}) -> Dictionary retorna data.actor após configurar a espécie/
ocorrência real, ligar WorldActorMotion e publicar no controlador. Entry exige
species/category; stage1–6 refere-se somente à origem do piloto atual. Point e
profiles são copiados; raio/altura/conexões são explícitos, sem inferência visual.
Mestre exige companion_traversal válido antes de nascer; não inventa altura do
animal. Consulta suporte/revisão/ocupação e rota real desde o jogador antes de
publicar. Falha não desloca jogador, consome RNG ou registra loot; falha no registro
do serviço retira o ator e sua ocupação. Preserva configuração/tiers/stats e
snapshot de ocorrência do serviço canônico. Outro piso no mesmo x/z permanece
posição distinta. Não é serviço persistente/idempotente de spawn ou respawn.

Entradas de spawn/encounter/configuração por pixels recusam controlador bound com
world_birth_required/world_lifecycle_required antes de mutar etapa/navegação.
A criação espacial não inicia lobby/expedição ou adaptação visual do piloto.

Mestre criado por essa entrada conserva o claim summon_used antes do sinal real
adiado. Atores sem controlador/contrato de nascimento conservam o bloqueio
spatial_spawn_required. O callback valida dono vivo/atual/membro, geometria e
estado do encontro. Uma tentativa por dono, inclusive busca sem local legal;
pausa retém WeakRef pendente e retoma sem simulação/loop durante a pausa. Mantém
os quatro offsets nominais e a exclusão45, agora em coordenadas3D: suporte exato
na direção original, ocupação e rota, sem snap/detour/andar vizinho. Animal
captura etapa de nascimento do Mestre, categoria inferior e dono; não usa um
índice global posteriormente alterado. Não gera child/loot/XP próprio, não bloqueia
limpeza e conserva remoção na morte do Mestre/fim. Sem retry/respawn novo.

Última morte canônica cria RewardPickup apoiado no WorldPoint atual do jogador,
como a posição nominal de limpeza do piloto estendido. Pickup duplicado conserva
a instância. Tickets continuam no RunRewardService anterior; não migram perfil,
carteira ou bens. _collect_reward valida binding atual, vida/pausa/encontro e
alcance48 de chão conectado ANTES da autoridade de grant, incluindo retry/atalho.
Pickup bound com jogador sem binding é recusado. Erro transitório preserva tickets,
pickup e RNG; retorno legal entrega os tickets já emitidos, sem novo roll. Ator
morto libera sua ocupação no cleanup. Apresentação multialtura/death visual segue
separada da prova de apresentação D05; essas APIs e fixtures não certificam campanha ou save pessoal.

## Campos Fogo/Raios/Barreira com altura explícita

preview_world_skill e request_world_skill recebem field_height:float=0.0 após
requested_rank; RunController.cast_world_skill o recebe após rank. Os demais
casts conservam seus argumentos/semântica. Para fire_wall, lightning_wall e
phantom_barrier, altura ausente/não finita/não positiva falha com
authored_field_height_required antes de custo, root, recarga ou publicação.
Altura é dado técnico explícito do chamador, não dimensão derivada de sprite nem
valor de produção escolhido por F1. Direção precisa ser horizontal não nula.
Preview acrescenta data.field, um DTO copiado com kind/anchor/normal/height/
half_length/half_width. Mutar esse DTO não altera um cast posterior.

WorldGroundField.configure(world,source,facing,placement_range,traversal,kind,
vertical_extent,revision,layout) captura geometria/epoch, suporte e direção.
Layout interno vem das constantes canônicas dos três nodes; não recalcula dano.
ground_line_samples mede o alcance real3D até o centro; ground_line_point_at
consulta os extremos laterais e quatro centros de Fogo, com raio/altura e
clearance explícitos. Não inventa suporte, snap, rota desviada ou piso próximo.
Neste checkpoint, diferença de altura lateral retorna non_planar_field_support
gratuitamente; campo inclinado/piecewise ainda é lacuna. Há suporte para eixos
laterais planos e não planos, inclusive footprint repartido em rampa/conexões conforme WorldSupportRegion.
Esse limite não certifica paredes em todas as superfícies possíveis.

WorldActorMotion.traversed(segments:Array[Dictionary]) emite cópia dos segmentos
reais somente após avanço/registro bem-sucedidos. Cada segmento de caminhada
conserva from/to com suporte próprio. Não reconstrói uma corda entre extremos
quando a rota passa por rampa/ponte. Teleport emite relocação from/to com
kind=teleport após sucesso; contato de campo exige suporte exato no ponto
interpolado, em uma das superfícies dos extremos. Não é certificação de travessia
teleportada por todo suporte intermediário. Falha de movimento não emite contato.

world_cast_field(skill) fornece o plano somente durante emissão comprometida.
O controlador liga FireWall/LightningWall/PhantomBarrier reais; track captura
alvos fracos, conecta seus segmentos e close desconecta no cleanup. Contatos
usam o corpo explícito, volume vertical e ground_connected na revisão atual.
Mesmo x/z em piso superior não é contato. Mudança de epoch cancela o campo;
mudança de build não reinterpreta emissão já paga. Pausa congela relógio/contatos.

Fogo usa quatro cilindros nos espaçamentos/raios existentes, um único burn source
por ator; o DoT já aplicado continua pela autoridade canônica. Raios usa cápsula
horizontal com tampas circulares, não cantos de um retângulo expandido. Barreira
usa faixa retangular orientada. Ocupação inicial de Raios/Barreira não cria
travessia; segmentos que entram/cruzam aplicam o efeito nominal, com claim do ICD
antes de callbacks. Não há tick por permanecer dentro. Alvos removidos durante
outro impacto são filtrados antes da conversão tipada; reentrada não avança o
relógio ou duplica hit.

WorldEffectVolume.configure_oriented(world,point,profile,normal,half_length,
half_width,height,revision) adiciona caixa local orientada horizontalmente.
PhantomBarrier.world_interception_fraction usa esse volume para flechas hostis
reais: altura/raio do cilindro e ordem de contato precedem absorb_projectile.
Flecha acima do topo não gasta capacidade; capacidade esgotada deixa a próxima
passar. Entrada 2D de interceptação recusa node já ligado a volume espacial.
Duração, ICDs, fonte de slow/weaken, potência e capacidade por rank permanecem
canônicos. Os draws bound aguardam D05; nenhuma projeção visual foi criada.

Amostragem com delta zero preserva a regra legada dos campos: consome contatos
pendentes/aplica o efeito sem avançar lifetime/ICD. Deltas negativos ou não finitos
não avançam relógio nem drenam segmentos. A regressão de FireWall._process(0.0)
foi detectada pelo teste legado de rank e corrigida no runtime; o oráculo original
permanece intacto.

## Parede de Gelo e obstáculo sólido orientado

WorldSolidSegment.configure(point,normal,half_length,half_width,height,traversal)
captura cópias do WorldPoint/profile e a cápsula horizontal extrudida verticalmente.
Dimensões finitas acima de EPS, direção horizontal não nula e ponto explícito são
obrigatórios. EPS é tolerância numérica, não tuning de altura de produção.
snapshot retorna outro segmento; anchor/profile também são cópias. contact
intersecta o corpo vertical com a união exata de faixa orientada e tampas
circulares. Cantos de uma caixa maior não se tornam colisão. Os pontos corners
são apenas candidatos de desvio, sempre filtrados pela mesma consulta física.

WorldGeometry.can_insert_segment(id,segment,revision) -> Dictionary é consulta
pura: revisão/ID único entre AABBs e cápsulas, suporte/clearance do footprint,
ausência de interseção estática e de ocupantes, e conservação de cada socket
autorado que qualquer ocupante registrado alcançava. Para testar alcance após
a colocação, o grafo existente recebe o candidato como argumento privado, sem
instalar/remover obstáculo, mutar revisão, copiar um mapa alternativo ou emitir
callbacks. Falha occupied/would_disconnect conserva o estado inteiro.
insert_segment usa a mesma validação, armazena snapshot e avança revisão uma vez.
remove_obstacle atende as duas formas e avança uma vez; duplicata falha.
configure de outro mundo/epoch limpa ambas as coleções, preservando monotonicidade.

Path usa a mesma geometria prospectiva/registrada para filtrar origens, destinos,
conectores, pontos de desvio e cada aresta. Seu custo continua soma real3D e
destino exato; não promete caminho contínuo mínimo em qualquer autoria. Sweep
com mask all acrescenta cápsulas com ID temporary/<id>, altura e corpo explícitos.
supporting_slabs continua restrito às lajes autoradas: teleporte pode passar pela
parede plana, mas não terminar dentro dela ou atravessar uma laje. Projéteis em
voo consultam a revisão atual; atores rejeitam rotas capturadas antes da inserção.

ice_wall usa a entrada comum preview/request/cast com field_height explícito.
WorldGroundField captura alcance200 e footprint pelas constantes originais de
IceWall, com suporte contínuo por patches em rampa e nas conexões. Preview não
registra obstáculo. Preparo revalida ocupação, build, controle e revisão.
O handler canônico usa o rank capturado para SP/recarga/duração, sem novo dano.
Todas as consultas falíveis antecedem pagamento. _spend não emite sinais, cede
execução ou escreve no mundo; seu último preflight e a inserção imediata formam
uma transação síncrona no mesmo thread. Nenhum callback externo ocorre entre
esses passos; a asserção de inserção detecta violação dessa invariante interna.

IceWall.configure_world registra na WorldGeometry; não registra na navegação2D.
O sinal existente publica o mesmo node no controlador. Pausa congela duração;
delta zero só amostra, negativo/não finito não avança. Expiração ou remoção da
árvore liberam a identidade exatamente uma vez. Mudança de build não altera o
volume emitido; mudança de epoch cancela o node sem remover uma identidade
reutilizada no mundo novo. A amostra D05 é uma apresentação técnica; não escolhe altura de produção, dano ou catálogo.

e07_f1_ice_test dirige PlayerActor/RunController/IceWall/ArrowProjectile e
MageProjectile reais: ranks1/5, orientação cardinal/diagonal, custos, rotas antigas,
desvio real, corpo/LoS no piso inferior, passagem superior, flecha acima de parede
baixa, parede criada durante voo, teleporte legal e cancelamentos/cleanup.
A prova não plana e Geômetra são adicionais descritos abaixo; não certificam campanha.

## Regiões de chão e campos não planos

`WorldGeometry.ground_region(anchor,polygon,profile,revision)` exige polígono convexo finito, perfil legal e revisão atual. Retorna o envelope comum com geometry_revision, patches copiados (surface_id, polygon, origin, normal), anchor e profile. Intersecta o footprint com as superfícies reais, exige cobertura completa e acesso por linhas apoiadas a cada patch. Bordas/vértices, volumes interiores e cápsulas registradas são validados; não infere outro andar por x/z. Concavidade, auto-interseção, lacuna, parede ou suporte incompatível falham gratuitamente.

`WorldSupportRegion` calcula contenção e contato contínuo do footprint extrudido pela altura explícita; `ground_contains` exige também o stage original. `WorldEffectVolume.configure_ground_region` captura esses patches; `WorldSolidSegment` captura a mesma base por partes, com extremidades nas alturas reais. Círculos/cápsulas conservam os caps arredondados e a tolerância vertical do corpo. Campos de Fogo mantêm bases próprias dos quatro pilares; Raios/Barreira/Gelo seguem o suporte repartido em patches, inclusive nas costuras. A reserva de Gelo revalida a região inteira e a segurança de ocupantes/sockets antes de pagar e registrar. O footprint de placement das cápsulas é conservador (retângulo envolvente); contato usa a cápsula arredondada.

A tolerância de coordenadas `point_tolerance` acrescenta quatro ULPs f32 à EPS em comparações de pontos apoiados/arestas, sem criar degrau, bônus de alcance ou tuning de produto. Linha de chão segue suporte/conexões, conserva custo real3D e não contorna paredes para reparar um cast.

## Geômetra — gramática, figuras e receitas completas

`GeometerCasting.bind_world_construction(field_height=0)` liga construção vazia ao mundo/perfil; altura positiva explícita é obrigatória para figuras. As entradas `preview_world_trace(skill,point,victim,revision,requested_rank=0)` e `begin_world_trace(...)` admitem Traçado, Triangulação, Translação, Reescrita e Colapso. Delegam ao PlayerActor, com captura de rank/composição, elemento, WorldPoints, alvo/dono fracos, origem, revisão/epoch e geração. O preparo comum e o pagamento canônico são reutilizados. Preview não reserva nem paga; commit revalida suporte, alcance, corpo, grammar, controle e composição antes de custo/recarga/ticket. Último preflight e reserva/edição/consumo são síncronos, sem callback externo entre eles.

`WorldGeometerConstruction` e `WorldGeometerNavigation` adaptam o core canônico sem modificá-lo: FIFO, tickets monotônicos, identidade, ranks, limites, clocks e expiração permanecem. Âncoras/tickets recebem sidecars WorldPoint; alvo móvel usa o suporte atual, morte/remoção fixa o último suporte válido. Chaves x/z conflitantes entre andares são recusadas. Cada aresta usa ground_line_to, custo3D e limite600 com tolerância numérica; separação24 continua canônica. Figuras exigem interior inteiro apoiado/livre e altura de campo explícita, incluindo ramps e costuras válidas. Obstáculo novo suspende a figura e pode retomá-la sem trocar identidade ou renovar relógios.

`GeometerTraceProjectile` conserva voo cilíndrico real, homing, orçamento/timeout e captura no impacto; callbacks2D não reclamam ticket espacial. Confirmação/reserva precede dano e callbacks. Alteração da geração/identidade por callback invalida o processamento tardio anterior.

As seis paredes e27 triângulos mantêm receitas e snapshots canônicos. Travessias reais, alvo por suporte/altura, manutenção1s sem catchup e contenção são consumidas pelos campos existentes. Translação/Reescrita preservam clocks/snapshots/ledger sem repetir resolução C; edição inválida não paga. Colapso captura pontos/região/altura antes de limpar e executa uma vez a receita C ou a política composta do primeiro elemento; não apaga construção nova criada por callback.

Projéteis reais ordenam contato de campo contra terreno/corpo usando `WorldProjectileMotion.peek` sem mutação. Condução caminha pela rota apoiada finita; redireção exige alvo legal por chão/alcance e voo livre; payloads Fogo/fundação/regra mantêm claims únicos. Flecha hostil baixa pode ser interceptada por saída Gelo com refund de Incidência canônico; acima da parede não é interceptada/refundada. Nenhuma fórmula de dano foi duplicada.

## Apresentação D05, input e amostra nativa

`WorldGeometry.presentation_snapshot(revision)` retorna cópia das superfícies/volumes para leitura; renderer não escreve colisão. `ExpeditionGeometryView.configure(world)` captura epoch, projeta `(x-z)*0.85,(x+z)*0.425-y` e preserva sprites/câmera atuais. `project`, `ray`, `pick(canvas_point,revision)`, `actor_at`, `observe`, `sync` e `indicate(point,valid,route)` são o adaptador de apresentação. `pick` envia o ray lógico à mesma `resolve_surface`; superfícies ocultas, obstrução, revisão antiga e empates falham. O ray usa envelope conservador de precisão f32 nas bordas, sem escolher pela ordem de iteração. Ocultar o teto altera somente desenho/seleção, nunca volumes/revisão.

`RunController.attach_expedition_view(view,field_height)` exige binding de mundo compatível e altura positiva. O clique esquerdo, mira por atalho/confirmação e preview chamam `spatial_pointer_move` / `spatial_pointer_skill`; selecionam WorldPoint ou alvo com suporte visível. Movimento usa path real até o andar selecionado; rejeição não cancela/move/paga. Skills usam os consumidores espaciais existentes, incluindo entradas próprias de Geômetra, dash/teleport/escudo e reserva Explosiva. Nenhum Vector2 projetado é usado como distância, destino físico ou fallback de combate. Markers/rotas e voos mostram os dados lógicos.

Amostra: `tests/fixtures/e07/f1/presentation_sample.tscn`, F0 real seed711, escala técnica3, run fixture e nenhum ProfileFacade. Usa main.tscn/HUD/PlayerActor/treinamento reais, câmera original e rampa/ponte/passagem inferior; não aparece no lobby nem abre campanha. `presentation_capture.gd` roda no projeto importado isolado e exige diretório absoluto de saída: captura ponte, ator na rampa com rota/marcador e ataque entre pisos recusado sem custo/dano. A avaliação e hashes estão no recibo; imagem não prova FPS/escala/balanceamento ou aceite humano.
