class_name ExpeditionCampaignRuntime
extends RefCounted
## All stage graphs remain owned by the one host/snapshot. Inactive graphs are
## disabled, not rebuilt; there is one player, one build and one reward service.
const LOCAL_FIELDS := ["navigation", "enemies", "trap_registry", "hunter_tar_field", "geometer_casting", "spiritualist_echo_state", "spiritualist_drain_state", "spiritualist_veil_state", "spiritualist_procession_state", "spiritualist_veil_fraction", "_spiritualist_veil_members", "_defender_slowed_enemies", "_world_pending_companions", "_world_companion_attempts"]
var state: ExpeditionCampaignState
var worlds: Dictionary = {}
var records: Dictionary = {}
var actors: Dictionary = {}
var pending_events: Array[Dictionary] = []
var death_serial := 0

func configure(host: RunController, id: String, manifest: ExpeditionManifest, rules: Dictionary) -> Dictionary:
	var created := ExpeditionCampaignState.create(id, host.run_state.character_id, manifest, host.run_state.effect_catalog().mob_catalog(), rules)
	if not created["ok"]: return created
	state = created["state"]
	worlds = created["worlds"]
	if float(state.manifest_data["input"]["traversal"]["radius"]) < host.player.collision_radius: return BuildEffectCatalog.failure(&"invalid_profile")
	host.encounter_active = false
	# This adapter is explicit. It cannot replace a running legacy encounter.
	if not host.enemies.is_empty(): return BuildEffectCatalog.failure(&"world_not_empty")
	if is_instance_valid(host.geometer_casting): host.geometer_casting.free()
	if is_instance_valid(host.trap_registry): host.trap_registry.free()
	host.geometer_casting = null
	host.trap_registry = null
	var entered := activate_stage(host, state.current_stage_id, state.anchor)
	if entered["ok"]:
		for source: String in state.visit(state.current_stage_id): host.run_state.queue_choice()
	return entered

func save_stage(host: RunController) -> void:
	var record: Dictionary = records[state.current_stage_id]
	for field: String in LOCAL_FIELDS: record["fields"][field] = host.get(field)
	# Register newly emitted stage-local actions before unloading.
	for child: Node in host.get_children():
		if child == host.player or child is Control or child is CanvasLayer or child is ArenaView or child is ExpeditionGeometryView or child is BattleIndicators or child is SpiritualistHaloUnderlay or child is ActorDeathVisual: continue
		if child.get_script() == null: continue
		var owned_elsewhere := false
		for other: Dictionary in records.values():
			if other == record: continue
			if child in other["nodes"]: owned_elsewhere = true; break
		if not owned_elsewhere and child not in record["nodes"]: record["nodes"].append(child)
	for node: Node in record["nodes"]:
		if not is_instance_valid(node): continue
		record["modes"][node] = node.process_mode
		node.process_mode = Node.PROCESS_MODE_DISABLED
		if node is CanvasItem: node.hide()
	if host.geometer_casting != null and host.player.geometer_cast_ready.is_connected(host.geometer_casting.launch): host.player.geometer_cast_ready.disconnect(host.geometer_casting.launch)

func activate_stage(host: RunController, stage_id: String, arrival: Dictionary) -> Dictionary:
	var world: WorldGeometry = worlds.get(stage_id)
	if world == null: return BuildEffectCatalog.failure(&"invalid_destination")
	var profile: Dictionary = state.manifest_data["input"]["traversal"]
	var point := ExpeditionPopulationPlanner.point(arrival)
	var safe := world.position_query(point, profile, world.geometry_revision)
	if not safe["ok"]: return BuildEffectCatalog.failure(&"destination_unsafe")
	var occupants: Array = safe["data"]["occupants"].duplicate()
	occupants.erase("expedition_player")
	if not occupants.is_empty(): return BuildEffectCatalog.failure(&"destination_unsafe")
	if not records.is_empty(): save_stage(host)
	if host.player.world_motion != null: host.player.world_motion.release()
	host.player.world_motion = null
	var bound := host.player.bind_world_geometry(world, point, profile, "expedition_player")
	if not bound["ok"]: return bound
	state.current_stage_id = stage_id
	if records.has(stage_id):
		var record: Dictionary = records[stage_id]
		for field: String in LOCAL_FIELDS: host.set(field, record["fields"][field])
		for node: Node in record["nodes"]:
			if not is_instance_valid(node): continue
			node.process_mode = record["modes"].get(node, Node.PROCESS_MODE_PAUSABLE)
			if node is CanvasItem and (not node is CombatActor or node.is_alive()): node.show()
		if host.geometer_casting != null and not host.player.geometer_cast_ready.is_connected(host.geometer_casting.launch): host.player.geometer_cast_ready.connect(host.geometer_casting.launch)
	else:
		host.navigation = ArenaNavigation.new()
		var bounds := Rect2()
		var initial := true
		for cell: Dictionary in world._stage["surfaces"]:
			for vertex: Vector3 in cell["vertices"]:
				var projected := Vector2(vertex.x, vertex.z)
				if initial: bounds = Rect2(projected, Vector2.ZERO); initial = false
				else: bounds = bounds.expand(projected)
		host.navigation.configure(bounds.grow(32.0), [], host.player.collision_radius)
		host.enemies = []
		host.trap_registry = PlayerTrapRegistry.new()
		host.add_child(host.trap_registry)
		host.hunter_tar_field = null
		host.spiritualist_echo_state = SpiritualistEchoState.new()
		host.spiritualist_echo_state.source_id = host.player.get_instance_id()
		host.spiritualist_drain_state = SpiritualistDrainState.new()
		host.spiritualist_veil_state = SpiritualistVeilState.new()
		host.spiritualist_procession_state = SpiritualistProcessionState.new()
		host.spiritualist_veil_fraction = 0.0
		host._spiritualist_veil_members = {}
		host._defender_slowed_enemies = {}
		host._world_pending_companions = {}
		host._world_companion_attempts = {}
		if host.expedition_field_height <= 0.0: host.expedition_field_height = float(profile["height"]) * 0.5
		host.geometer_casting = null
		var local_nodes: Array[Node] = [host.trap_registry]
		if host.run_state.build_snapshot.evolution_id == &"mg_ar":
			host.geometer_casting = GeometerCasting.new()
			host.geometer_casting.configure(host.player)
			host.geometer_casting.targets = host.enemies
			host.geometer_casting.hit.connect(host._on_attack_requested)
			host.add_child(host.geometer_casting)
			var spatial := host.geometer_casting.bind_world_construction(host.expedition_field_height)
			if not spatial["ok"]: return spatial
			local_nodes.append(host.geometer_casting)
		records[stage_id] = {"fields": {}, "nodes": local_nodes, "modes": {}}
		for id: String in state.slots:
			if state.slots[id]["stage_id"] == stage_id and state.slots[id]["life_state"] == "alive":
				var spawned := spawn_slot(host, id)
				if not spawned["ok"]: return spawned
	host.player.navigation = host.navigation
	host.player.target = null
	host.player.global_position = Vector2(point.position.x, point.position.z)
	var screen_bounds := Rect2()
	var first_vertex := true
	for cell: Dictionary in world._stage["surfaces"]:
		for vertex: Vector3 in cell["vertices"]:
			var screen_point := ExpeditionGeometryView.project(vertex)
			if first_vertex: screen_bounds = Rect2(screen_point, Vector2.ZERO); first_vertex = false
			else: screen_bounds = screen_bounds.expand(screen_point)
	host.active_bounds = screen_bounds.grow(64.0)
	return {"ok": true}

func spawn_slot(host: RunController, slot_id: String) -> Dictionary:
	var slot: Dictionary = state.slots[slot_id]
	var world: WorldGeometry = worlds[slot["stage_id"]]
	var profile: Dictionary = slot["traversal"]
	var home := ExpeditionPopulationPlanner.point(slot["home"])
	var legal := world.position_query(home, profile, world.geometry_revision)
	if not legal["ok"] or not legal["data"]["occupants"].is_empty(): return BuildEffectCatalog.failure(&"destination_unsafe")
	var actor := EnemyActor.new()
	var checked := actor.configure_occurrence(state.occurrence(slot_id), host.run_state.effect_catalog().mob_catalog(), host.navigation, host.player)
	if not checked["ok"]: actor.free(); return checked
	var binding := actor.bind_world_geometry(world, home, profile, "slot_" + slot_id)
	if not binding["ok"]: actor.free(); return binding
	if slot.has("patrol"):
		var patrolled := actor.bind_patrol(slot["patrol"])
		if not patrolled["ok"]: actor.world_motion.release(); actor.free(); return patrolled
	actor.global_position = Vector2(home.position.x, home.position.z)
	actor.actor_died.connect(host._on_enemy_died)
	actor.attack_requested.connect(host._on_enemy_attack_requested)
	actor.mob_skill_requested.connect(host._on_mob_skill_requested)
	actor.health.damage_applied.connect(host._on_enemy_damage_resolved)
	actor.status_damage_requested.connect(host._on_attack_requested)
	actor.companion_requested.connect(host._queue_companion_request)
	actor.set_meta("world_companion_traversal", profile.duplicate(true))
	actor.set_meta("world_birth_stage", 1)
	host.add_child(actor)
	host.enemies.append(actor)
	actors[slot_id] = actor
	records[slot["stage_id"]]["nodes"].append(actor)
	if host.reward_service.mob_loot_enabled(): return host.reward_service.register_mob_actor(actor)
	return {"ok": true}

func admit_pending(host: RunController) -> Dictionary:
	for id: String in state.slots:
		var slot: Dictionary = state.slots[id]
		if slot["stage_id"] != state.current_stage_id or slot["life_state"] != "respawn_pending": continue
		var world: WorldGeometry = worlds[slot["stage_id"]]
		var home := ExpeditionPopulationPlanner.point(slot["home"])
		var queried := world.position_query(home, slot["traversal"], world.geometry_revision)
		if not queried["ok"] or not queried["data"]["occupants"].is_empty(): continue
		# Commit generation only when its actual birth can be admitted.
		state.admit_respawn(id)
		var spawned := spawn_slot(host, id)
		if not spawned["ok"]: return spawned
	return {"ok": true}

func slot_for_actor(actor: CombatActor) -> String:
	for id: String in actors:
		if actors[id] == actor: return id
	return ""

func valid() -> bool:
	if state == null or not state.valid(): return false
	for id: String in state.slots:
		var slot: Dictionary = state.slots[id]
		if slot["generation"] < 0 or slot["life_state"] not in ["alive", "dead", "respawn_pending"] or (slot["trash"] and slot["occurrence_category"] not in ["normal", "elite"]): return false
		if actors.has(id):
			var actor: EnemyActor = actors[id]
			if not is_instance_valid(actor) or actor.occurrence.occurrence_id != state.occurrence(id).occurrence_id: return false
			if actor.is_alive() and (actor.world_motion == null or actor.world_motion.geometry != worlds.get(slot["stage_id"]) or float(actor.world_motion.profile()["radius"]) < actor.collision_radius): return false
			if slot["life_state"] == "alive" and not actor.is_alive() and not pending_events.any(func(event: Dictionary) -> bool: return event["kind"] == "mob_death" and event["slot_id"] == id): return false
		elif state.stages[slot["stage_id"]]["visited"] and slot["life_state"] == "alive": return false
	return true
