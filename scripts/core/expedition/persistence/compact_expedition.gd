extends RefCounted
## The existing snapshot descriptors persist the player and run. Only campaign
## geometry and population are projected out and rebuilt by their authorities.
const Ruins = preload("res://data/expedition/phases/ruined_crossing.gd")
const PublishedPhase = preload("res://scripts/map_authoring/release/phase_release.gd")
const VERSION := 1
const SLOT_FIELDS := ["generation", "life_state", "pending_wave", "initial_resolved", "deaths"]
## Diagnostic tally of compact attempts in this process (probes read it):
## "compact" counts accepted cuts, other keys name why the exact format was kept.
static var cut_tally: Dictionary = {}

static func capture(host: RunController, barrier: SnapshotTickBarrier) -> Dictionary:
	var runtime := host.campaign_runtime
	if runtime == null or host.player == null or host.player.world_motion == null or not runtime.pending_events.is_empty() or not runtime.birth_queue.is_empty():
		return _ineligible("campaign_pending")
	var state := runtime.state
	if not state.valid() or state.completed: return _ineligible("campaign_state")
	var input: Dictionary = state.manifest_data["input"]
	# Published phases are pinned by package releases; generated ones by seed.
	var source := {"phase":String(input.get("phase_id",""))}
	if input.has("phase_hash") and input.get("authored_presentations") is Dictionary:
		source["hash"] = input["phase_hash"]
		source["pins"] = input["authored_presentations"]
	elif input.get("phase_id") == Ruins.PHASE_ID and input.get("seed_text") is String and input.get("generator_revision") is String:
		source["seed"] = input["seed_text"]
		source["revision"] = input["generator_revision"]
		source["hash"] = ExpeditionCanonical.digest(state.manifest_data)
	else:
		return _ineligible("composition_source")
	var excluded := {}
	for actor: EnemyActor in runtime.actors.values():
		if not is_instance_valid(actor) or actor.is_queued_for_deletion(): return _ineligible("enemy_pending_deletion")
		excluded[actor.get_instance_id()] = true
	# Old generations are kept as disabled nodes by the exact runtime.
	for child: Node in host.get_children():
		if child is EnemyActor:
			if child.is_alive() and not excluded.has(child.get_instance_id()): return _ineligible("enemy_outside_population")
			excluded[child.get_instance_id()] = true
		elif child.is_in_group("player_projectiles") or child.is_in_group("player_effects") or child.is_in_group("enemy_projectiles"):
			return _ineligible("projectile_or_effect")
	var player := host.player
	if player.has_active_cast() or player._world_executing_cast != null or player._world_dash_remaining > 0.0 or player._dash_active or not host._world_pending_companions.is_empty():
		return _ineligible("player_action")
	if not _homes_clear(runtime, player.world_point(), player.world_motion._profile): return _ineligible("home_occupied")

	var slots := {}
	for id: String in state.slots:
		var slot := {}
		for field: String in SLOT_FIELDS: slot[field] = state.slots[id][field]
		slots[id] = slot
	var records := {}
	for id: String in runtime.records:
		var original: Dictionary = runtime.records[id]
		var fields: Dictionary = original["fields"].duplicate()
		if fields.has("enemies"):
			for enemy: CombatActor in fields["enemies"]:
				if not enemy is EnemyActor or (enemy.is_alive() and not excluded.has(enemy.get_instance_id())): return _ineligible("stage_enemy_reference")
			fields["enemies"] = [] as Array[CombatActor]
		var nodes: Array = original["nodes"].filter(func(node: Variant) -> bool: return is_instance_valid(node) and not excluded.has(node.get_instance_id()))
		var modes: Dictionary = original["modes"].duplicate()
		for node: Variant in original["modes"]:
			if not is_instance_valid(node) or excluded.has(node.get_instance_id()): modes.erase(node)
		records[id] = {"fields":fields, "nodes":nodes, "modes":modes}
	var overrides := {
		host: {"enemies":[] as Array[CombatActor], "_hovered_enemy":null, "_selected_enemy":null, "_credited_kills":{} as Dictionary[int, bool]},
		player: {"target":null, "_attack_engaged":false},
		host.reward_service: {"_mob_actors":{}, "_occurrence_actors":{}},
		runtime: {"actors":{}, "records":records},
		state: {"manifest_data":{}, "population_rules":{}, "slots":slots},
	}
	for enemy: CombatActor in host.enemies:
		if not enemy is EnemyActor or not excluded.has(enemy.get_instance_id()): return _ineligible("host_enemy_reference")
	if host.combat_participation != null: overrides[host.combat_participation] = {"links":{} as Dictionary[String, bool]}
	for record: Dictionary in runtime.records.values():
		var geometer: GeometerCasting = record["fields"].get("geometer_casting")
		if is_instance_valid(geometer): overrides[geometer] = {"targets":[] as Array[CombatActor]}
	for world: WorldGeometry in runtime.worlds.values():
		if not world._temporary.is_empty() or not world._segments.is_empty(): return _ineligible("temporary_geometry")
		overrides[world] = {"_stage":{}, "_solid_slabs":[] as Array[AABB], "_occupancy":{} as Dictionary[String, Dictionary]}
	if host.geometer_casting != null: overrides[host.geometer_casting] = {"targets":[] as Array[CombatActor]}
	var captured := SnapshotRegistry.new().capture(host, barrier, false, {"fields":overrides, "excluded":excluded})
	if not captured.get("ok",false): return _ineligible("graph_reference")
	var bytes := var_to_bytes({"version":VERSION, "source":source, "graph":captured["encoding"]})
	if bytes.size() > SnapshotRegistry.MAX_BYTES: return _ineligible("too_large")
	cut_tally["compact"] = int(cut_tally.get("compact",0)) + 1
	return {"ok":true,"compact":true,"encoding":bytes,"bytes":bytes.size(),"capture_usec":captured["capture_usec"],"snapshot":captured["snapshot"]}

static func _homes_clear(runtime: ExpeditionCampaignRuntime, player: ExpeditionWorldPoint, profile: Dictionary) -> bool:
	# Use the same vertical interval and horizontal disk predicate as occupancy.
	var positions: Dictionary = {}
	for id: String in runtime.state.slots:
		var slot: Dictionary = runtime.state.slots[id]
		if slot["life_state"] != "alive" or not runtime.state.stages[slot["stage_id"]]["visited"]: continue
		var home := ExpeditionPopulationPlanner.point(slot["home"])
		var body: Dictionary = slot["traversal"]
		if home.stage_id == player.stage_id and WorldGeometry.bodies_overlap(home.position, body, player.position, profile): return false
		var peers: Array = positions.get(home.stage_id, [])
		for peer: Dictionary in peers:
			if WorldGeometry.bodies_overlap(home.position, body, peer["position"], peer["profile"]): return false
		peers.append({"position":home.position,"profile":body})
		positions[home.stage_id] = peers
	return true

static func decode(bytes: PackedByteArray) -> Dictionary:
	var record: Variant = bytes_to_var(bytes)
	if not record is Dictionary or record.size() != 3 or record.get("version") != VERSION or not record.get("source") is Dictionary or not record.get("graph") is PackedByteArray:
		return StableEntityRegistry.failure(&"invalid_checkpoint","compact envelope")
	var source: Dictionary = record["source"]
	var published := source.has("pins")
	var keys := ["phase","hash","pins"] if published else ["phase","seed","revision","hash"]
	if source.size() != keys.size() or not source.has_all(keys) or not source["phase"] is String or not IdentityIds.is_technical_id(source["phase"]) or not CharacterAssets.valid_digest(source["hash"]):
		return StableEntityRegistry.failure(&"invalid_checkpoint","compact composition source")
	if published and (not source["pins"] is Dictionary or source["pins"].is_empty()):
		return StableEntityRegistry.failure(&"invalid_checkpoint","compact composition pins")
	if not published and (not source["seed"] is String or str(int(source["seed"])) != source["seed"] or not source["revision"] is String or source["revision"].is_empty()):
		return StableEntityRegistry.failure(&"invalid_checkpoint","compact composition source")
	return {"ok":true,"record":record}

static func prepare(source: Dictionary) -> Dictionary:
	if source.has("pins"):
		var entries := []
		for pin: Variant in source["pins"].values():
			if not PublishedPhase.MapRelease.valid_entry(pin): return ExpeditionCheckpointCodec.fail(&"invalid_checkpoint")
			entries.append(pin)
		# The release preparation still validates the immutable pinned package.
		var built := PublishedPhase.prepare(source["phase"], {"registry_version":PublishedPhase.MapRelease.VERSION,"packages":entries})
		if not built.get("ok",false) or built.get("phase_hash") != source["hash"]: return ExpeditionCheckpointCodec.fail(&"content_revision_unavailable")
		if not matches(source,built["manifest"]): return ExpeditionCheckpointCodec.fail(&"content_revision_unavailable")
		return built
	if source["phase"] != Ruins.PHASE_ID: return ExpeditionCheckpointCodec.fail(&"content_revision_unavailable")
	var built := ExpeditionAssembler.build(Ruins.input(source["seed"]))
	if not built.get("ok",false): return ExpeditionCheckpointCodec.fail(&"content_revision_unavailable")
	var manifest: ExpeditionManifest = built["data"]["manifest"]
	if manifest._data["input"]["generator_revision"] != source["revision"] or manifest.canonical_hash() != source["hash"]: return ExpeditionCheckpointCodec.fail(&"content_revision_unavailable")
	return {"ok":true,"manifest":manifest,"rules":Ruins.rules(manifest)}

static func matches(source: Dictionary, manifest: ExpeditionManifest) -> bool:
	var input: Dictionary = manifest._data["input"]
	if input.get("phase_id") != source["phase"]: return false
	if source.has("pins"): return input.get("authored_presentations") == source["pins"] and input.get("phase_hash") == source["hash"]
	return input.get("generator_revision") == source["revision"] and input.get("seed_text") == source["seed"] and manifest.canonical_hash() == source["hash"]

static func rebuild(host: RunController, prepared: Dictionary) -> Dictionary:
	var runtime := host.campaign_runtime
	if runtime == null or runtime.state == null or host.player == null: return StableEntityRegistry.failure(&"invalid_checkpoint","compact campaign binding")
	var state := runtime.state
	var manifest: ExpeditionManifest = prepared["manifest"]
	var rules: Dictionary = prepared["rules"]
	var planned := ExpeditionPopulationPlanner.build(manifest, host.run_state.effect_catalog().mob_catalog(), rules)
	if not planned["ok"]: return planned
	if runtime.worlds.size() != planned["worlds"].size() or state.slots.size() != planned["slots"].size(): return StableEntityRegistry.failure(&"invalid_checkpoint","compact stage or slot count")
	for id: String in planned["slots"]:
		var saved: Variant = state.slots.get(id)
		if not saved is Dictionary or saved.size() != SLOT_FIELDS.size() or not saved.has_all(SLOT_FIELDS): return StableEntityRegistry.failure(&"invalid_checkpoint","compact slot "+id)
		planned["slots"][id].merge(saved,true)
	state.slots = planned["slots"]
	state.manifest_data = manifest.to_data()
	state.population_rules = rules
	if not state.valid() or not runtime.actors.is_empty(): return StableEntityRegistry.failure(&"invalid_checkpoint","compact campaign state")
	for id: String in planned["worlds"]:
		var saved: WorldGeometry = runtime.worlds.get(id)
		if saved == null or not saved._stage.is_empty() or not saved._occupancy.is_empty() or not saved._temporary.is_empty() or not saved._segments.is_empty(): return StableEntityRegistry.failure(&"invalid_checkpoint","compact world "+id)
		var fresh: WorldGeometry = planned["worlds"][id]
		saved._stage = fresh._stage
		saved._solid_slabs = fresh._solid_slabs
	var motion := host.player.world_motion
	if motion == null or motion._point == null or motion.geometry != runtime.worlds.get(state.current_stage_id) or motion._occupant_id != "expedition_player" or not runtime.records.has(state.current_stage_id): return StableEntityRegistry.failure(&"invalid_checkpoint","compact player world")
	return motion.geometry.set_occupant(motion._occupant_id, motion._point, motion._profile, motion.geometry.geometry_revision)

static func spawn(host: RunController) -> Dictionary:
	var runtime := host.campaign_runtime
	var current := runtime.state.current_stage_id
	var active_enemies := host.enemies
	var active_navigation := host.navigation
	for stage: String in runtime.records:
		if not runtime.state.stages.has(stage) or not runtime.state.stages[stage]["visited"]: return StableEntityRegistry.failure(&"invalid_checkpoint","compact stage record")
		var record: Dictionary = runtime.records[stage]
		if stage != current:
			host.enemies = record["fields"]["enemies"]
			host.navigation = record["fields"]["navigation"]
		for id: String in runtime.state.slots:
			var slot: Dictionary = runtime.state.slots[id]
			if slot["stage_id"] != stage or slot["life_state"] != "alive": continue
			var made := runtime.spawn_slot(host,id)
			if not made["ok"]: return made
			if stage != current:
				var actor: EnemyActor = runtime.actors[id]
				record["modes"][actor] = actor.process_mode
				actor.process_mode = Node.PROCESS_MODE_DISABLED
				actor.hide()
		var geometer: GeometerCasting = host.geometer_casting if stage == current else record["fields"].get("geometer_casting")
		if geometer != null: geometer.targets = host.enemies
		host.enemies = active_enemies
		host.navigation = active_navigation
	if not runtime.valid(): return StableEntityRegistry.failure(&"invalid_checkpoint","compact restored population")
	return {"ok":true}

static func _ineligible(reason: String) -> Dictionary:
	cut_tally[reason] = int(cut_tally.get(reason,0)) + 1
	return {"ok":false,"error_code":&"compact_cut_unrepresentable","detail":reason}
