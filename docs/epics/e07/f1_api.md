# E07-F1 — API lógica do checkpoint inicial

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
A revisão é local à instância, monotônica em configure/insert/remove; não é a
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

Kind opcional: sphere (padrão), cone ou line. Cone/line exigem direction Vector3
finita não zero; cone usa half_angle em radianos [0,PI]; line usa half_width.
Não há multiplicador de dano por altura. self_only/inherit_parent/walk_path da
matriz são classificações de consumidores, não regras aceitas por query_attack.

A identificação de laje deste checkpoint cobre sólidos AABB com topo coincidindo
com superfície horizontal realizada. Rampas usam suporte planar contínuo; volumes
sólidos inclinados arbitrários não são certificados por esse predicado. Também
não há sweep contra atores dentro de WorldGeometry: ocupação é query separada e
os consumidores de projétil ainda precisam ordenar contatos contra atores/interceptores.

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
esse movimento e desliga o tick legado em Vector2. Só para fixture técnica limpa,
sem efeitos legados em voo. Rebinding retorna already_bound. world_point,
move_world_to e advance_world são as entradas lógicas. _exit_tree libera ocupação.
Isso prova travessia manual de PlayerActor/EnemyActor, **não perseguição/leash AI**.
Não sincroniza desenho, global_position ou input.

`PlayerActor.use_world_teleport(destination, revision)` e
`use_world_dash(destination, revision)` usam custos/cooldowns canônicos existentes;
falha espacial não gasta nem emite cast. Dash prepara rota dentro do alcance;
fixture dirige advance_world, sem duração/animação integrada ainda. Todas as demais
entradas legadas de cast e ataque básico são recusadas quando há binding espacial.
Essa barreira explícita evita fallback 2D, mas não é suporte completo de kit.

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
A matriz registra os consumidores ainda pendentes: projéteis, áreas, construções,
interceptores, suportes, combate e AI dos kits. O próximo executor deve continuar
neste F1, sem liberar amostra multialtura enquanto houver esses bloqueios.
