extends SceneTree
## Full pilot builds, actual paid producers and observable decisions; no balance claim.
const Directions = preload("res://tools/content/directions_bundle.gd")
const Transform = preload("res://tools/content/transform_bundle.gd")
const IDENTITIES := ["swordsman", "mage", "archer", "defender", "berserker", "elementalist", "spiritualist", "sentinel", "hunter", "mg_ar"]
var checks := 0
var failures := 0
var observations: Array[Dictionary] = []
var events: Array[Dictionary] = []
var emissions: Array[StringName] = []
var catalog: BuildEffectCatalog
var comparison: Dictionary
func _initialize() -> void: _run.call_deferred()
func _check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(label)
func _run() -> void:
	var text: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://content/authoring/transform_texts.json"))
	var compiled := ContentAuthoring.compile_bundle(Transform.entries(), text)
	_check(compiled["ok"] and compiled["ready"], "unchanged 69 recipe bundle has complete real editorial")
	if not compiled["ok"]: print(compiled); quit(1); return
	catalog = compiled["catalog"]
	for identity: String in IDENTITIES:
		for branch: int in 2: await _case(identity, branch)
	_check(observations.size() == 20, "twenty full builds observed")
	for index: int in range(0, observations.size() - 1, 2):
		_check(observations[index]["decision"] != observations[index + 1]["decision"], "two decisions differ for %s" % observations[index]["identity"])
	if failures == 0:
		var file := FileAccess.open("res://content/authoring/directions_execution.json", FileAccess.WRITE)
		_check(file != null, "directions report writable")
		if file != null:
			file.store_string(JSON.stringify({"mechanical_digest": compiled["mechanical_digest"], "scope": "full_build_observable_decisions", "production_published": false, "balance_validated": false, "performance_validated": false, "human_playtest": false, "observations": observations}, "\t", true) + "\n")
			file.close()
	print("E06 directions: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
func _scene(identity: String, branch: int) -> RunController:
	comparison = Directions.comparison(identity, branch, catalog)
	_check(comparison["ok"], "canonical purchased ranks and composed build %s/%d" % [identity, branch])
	if not comparison["ok"]: print(comparison); return null
	var state := RunState.from_build("directions-real", comparison["snapshot"])
	state.augment_stacks.assign(comparison["run_effects"]["augment_stacks"])
	state.card_instances = comparison["run_effects"]["card_instances"].duplicate()
	state.card_sockets = comparison["run_effects"]["card_sockets"].duplicate(true)
	_check(state.set_effect_catalog(catalog)["ok"], "full build equipment/card/augment composition injects")
	RunController.pending_run_state = state
	RunController.pending_run_facade = null
	RunController.pending_training_mode = true
	var arena := load("res://scenes/main.tscn").instantiate() as RunController
	root.add_child(arena)
	arena.set_process(false)
	arena.player.set_process(false)
	arena.training_boss.set_process(false)
	arena.training_boss.position = Vector2(1500, 850)
	arena._training_add_elapsed = -1000
	arena.enemies.clear()
	arena.navigation.configure(Rect2(0, 0, 1800, 1000), [], 0)
	arena.player.position = Vector2(400, 350)
	arena.player.health.flee_rating = 0
	arena.rng.seed = 349
	if arena.geometer_casting != null: arena.geometer_casting.set_process(false)
	_check(arena.persistent_facade == null, "training build cannot save personal profile")
	events.clear(); emissions.clear()
	arena.player.status_damage_requested.connect(func(request: DamageRequest, _victim: CombatActor) -> void: emissions.append(request.skill_id))
	return arena
func _victim(arena: RunController, point: Vector2) -> EnemyActor:
	var actor := EnemyActor.new()
	actor.configure(&"chaser", arena.navigation, arena.player)
	actor.position = point
	actor.health.max_hp = 10000
	actor.health.current_hp = 10000
	actor.health.physical_defense = 0
	actor.health.magic_defense = 0
	actor.health.flee_rating = 0
	actor.health.damage_applied.connect(arena._on_enemy_damage_resolved)
	actor.health.damage_applied.connect(func(result: Dictionary) -> void: events.append(result.duplicate(true)))
	actor.attack_requested.connect(arena._on_enemy_attack_requested)
	actor.status_damage_requested.connect(arena._on_attack_requested)
	arena.add_child(actor)
	actor.set_process(false)
	arena.enemies.append(actor)
	return actor
func _projectiles() -> int:
	var count := 0
	for projectile: Node in get_nodes_in_group("player_projectiles"):
		if not projectile.is_queued_for_deletion():
			count += 1; projectile.set_process(false); projectile._process(1)
	return count
func _finish(arena: RunController) -> void:
	paused = false; arena.queue_free(); await process_frame
func _enemy_attack(actor: EnemyActor, arena: RunController) -> void:
	for attempt: int in 4:
		actor._process(0.01 if attempt == 0 else actor.attack_cooldown + 0.001)
		if arena.player.has_defender_token(): break
func _trace(casting: GeometerCasting, target: CombatActor, element: StringName, third: bool = false) -> bool:
	var skill := &"geometer_triangulation" if third else &"geometer_trace"
	var cooldown := casting.player.skill_cooldown(skill)
	if cooldown > 0: casting.player._process(cooldown + 0.001)
	var old: Array[int] = []
	for existing: Node in get_nodes_in_group("player_projectiles"): old.append(existing.get_instance_id())
	casting.construction.grammar.select_element(element)
	casting.launch(casting.capture(skill, target.position))
	for projectile: Node in get_nodes_in_group("player_projectiles"):
		if projectile is GeometerTraceProjectile and not projectile.is_queued_for_deletion() and projectile.get_instance_id() not in old:
			projectile.set_process(false); projectile._process(1); return true
	return false
func _case(identity: String, branch: int) -> void:
	var before_failures := failures
	var arena := _scene(identity, branch)
	if arena == null: return
	var p := arena.player
	var first := _victim(arena, Vector2(455, 350))
	var second := _victim(arena, Vector2(480, 370))
	var outside := _victim(arena, Vector2(345, 350))
	var metrics: Dictionary = {}
	var skills: Array[StringName] = []
	var decision := ""
	match identity:
		"swordsman":
			if branch == 0:
				decision = "alinhar dois inimigos na pressão frontal, deixando o alvo traseiro fora"
				skills = [&"slash"]
				_check(p.use_slash(Vector2.RIGHT, arena.enemies), "full swordsman pressure launches")
				metrics = {"front_targets_hit": int(first.health.current_hp < 10000) + int(second.health.current_hp < 10000), "rear_untouched": outside.health.current_hp == 10000}
				_check(metrics["front_targets_hit"] == 2 and metrics["rear_untouched"], "cone priority depends on facing beyond damage")
			else:
				decision = "orientar a Guarda e provocar a ameaça para manter defesa frontal"
				skills = [&"shield_wall", &"provoke"]
				_check(p.use_shield_wall(Vector2.RIGHT) and p.use_provoke(first), "real guard and taunt commit")
				_check(p.has_shield_stance() and first.taunt_remaining > 0, "defensive path holds frontal stance and selected taunt")
				metrics = {"guard_seconds": p.shield_remaining, "guard_charges": p.shield_resistance, "taunt_seconds": first.taunt_remaining}
		"mage":
			if branch == 0:
				decision = "escolher alvo para projéteis elementais multiplicados pela arma"
				skills = [&"fire_spear"]
				_check(p.use_spear(&"fire_spear", first), "full mage direct spear launches")
				metrics = {"projectiles": _projectiles(), "primary_hp_lost": 10000 - first.health.current_hp}
				_check(metrics["projectiles"] >= 2 and metrics["primary_hp_lost"] > 0, "equipment changes actual direct projectile count")
			else:
				decision = "fechar passagem com área sólida temporária para controlar acesso"
				skills = [&"ice_wall"]
				_check(p.use_ice_wall(Vector2.UP, arena.enemies), "full mage control wall launches")
				var walls: Array[Node] = get_nodes_in_group("player_effects").filter(func(node: Node) -> bool: return node is IceWall)
				_check(walls.size() == 1, "actual wall registered")
				if not walls.is_empty():
					var wall := walls[0] as IceWall; wall.set_process(false)
					metrics = {"crossing_blocked": not arena.navigation.is_segment_clear(p.position, p.position + Vector2(0, -350), 0), "wall_seconds": wall.remaining}
					_check(metrics["crossing_blocked"] and metrics["wall_seconds"] > 0, "wall changes traversable space")
		"archer":
			if branch == 0:
				decision = "alinhar tiros perfurantes em múltiplos alvos"
				skills = [&"piercing_arrow"]
				second.position = Vector2(560, 350)
				_check(p.use_piercing_arrow(Vector2.RIGHT), "full archer piercing emission")
				_projectiles()
				metrics = {"aligned_targets_hit": int(first.health.current_hp < 10000) + int(second.health.current_hp < 10000), "rear_untouched": outside.health.current_hp == 10000}
				_check(metrics["aligned_targets_hit"] == 2 and metrics["rear_untouched"], "piercing decision changes victim coverage")
			else:
				decision = "preparar armadilha antes de conduzir a presa para imobilização"
				skills = [&"snare_trap"]
				first.position = Vector2(600, 350); second.position = Vector2(620, 420)
				_check(p.use_snare_trap(Vector2(500, 350)), "full archer preparation spends on real snare")
				var trap := arena.trap_registry.active_traps()[0] as SnareTrap; trap.set_process(false)
				_check(not first.is_rooted(), "placement cannot grant immediate control")
				trap._process(trap.arming_duration + 0.001); first.position = Vector2(500, 350); trap._process(0.01)
				metrics = {"preparation_seconds": trap.arming_duration, "rooted_after_entry": first.is_rooted()}
				_check(metrics["rooted_after_entry"], "actual entry after arming changes movement")
		"defender":
			if branch == 0:
				decision = "aceitar golpe frontal sob Guarda e gastar resposta preparada"
				skills = [&"shield_wall", &"defender_counterstroke"]
				first.position = Vector2(430, 350)
				_check(p.use_shield_wall(Vector2.RIGHT), "full Defender buys prerequisite guard")
				_enemy_attack(first, arena)
				var token := p.has_defender_token()
				_check(token, "actual enemy frontal attack prepares token")
				_check(p.use_defender_counterstroke(Vector2.RIGHT, arena.enemies), "real response consumes prepared token")
				metrics = {"token_from_enemy_attack": token, "token_consumed": not p.has_defender_token(), "counter_guard_seconds": p.defender_counter_guard_remaining}
				_check(metrics["token_consumed"] and metrics["counter_guard_seconds"] > 0, "response changes protection timing")
			else:
				decision = "ocupar âncora e travar linha territorial de inimigos"
				skills = [&"defender_anchor", &"defender_line_lock"]
				_check(p.use_defender_anchor(p.position) and p.use_defender_line_lock(Vector2.RIGHT, arena.enemies), "full territorial skills commit")
				metrics = {"anchor_seconds": p.defender_anchor_remaining, "front_control": first.is_rooted(), "rear_free": not outside.is_rooted()}
				_check(metrics["anchor_seconds"] > 0 and metrics["front_control"] and metrics["rear_free"], "territory route constrains front line separately from response")
		"berserker":
			if branch == 0:
				decision = "manter ferida periódica e detoná-la com Ruptura"
				skills = [&"berserker_blood_rift", &"berserker_rupture"]
				_check(p.use_berserker_blood_rift(Vector2.RIGHT, arena.enemies), "full sustained pressure starts rift")
				var bleeding := not first.bleed_streams.is_empty(); var hp := first.health.current_hp
				first.advance_statuses(1.01)
				var periodic_hp_lost := hp - first.health.current_hp
				_check(p.use_berserker_rupture(first), "actual Rupture follows pressure")
				metrics = {"periodic_stream": bleeding, "periodic_hp_lost": periodic_hp_lost, "wound_stacks": p.berserker_wound_stacks(first.get_instance_id())}
				_check(bleeding and metrics["periodic_hp_lost"] > 0, "sustained route persists after initial attack")
			else:
				decision = "aproximar por salto e trocar vida por execução"
				skills = [&"berserker_wound_leap", &"berserker_execution"]
				first.position = Vector2(590, 350); var origin := p.position
				_check(p.use_berserker_wound_leap(Vector2.RIGHT, arena.enemies), "real mobility launches")
				p._process(PlayerActor.DASH_DURATION + 0.001)
				var hp := p.health.current_hp
				_check(p.use_berserker_execution(first), "real execution pays HP after approach")
				metrics = {"distance_moved": origin.distance_to(p.position), "hp_paid": hp - p.health.current_hp}
				_check(metrics["distance_moved"] > 0 and metrics["hp_paid"] > 0 and p.is_alive(), "execution path changes position and resource instead of only percentage")
		"elementalist":
			if branch == 0:
				decision = "alternar elementos para recuperar SP e priorizar cadeia elétrica próxima"
				skills = [&"elementalist_flame_burst", &"elementalist_lightning_arc"]
				_check(p.use_elementalist_flame_burst(first.position), "sequence starts by actual Flame Burst")
				var first_element: StringName = p.elementalist_focus_history.get(first.get_instance_id(), {}).get("element", &"")
				var sp_before := p.current_sp
				_check(p.use_elementalist_lightning_arc(first), "sequence follows real electric arc")
				metrics = {"first_element": first_element, "alternating_sp_return": p.current_sp - (sp_before - p.skill_cost(&"elementalist_lightning_arc")), "electrified_targets": int(first.is_electrified()) + int(second.is_electrified())}
				_check(first_element == &"fire" and metrics["alternating_sp_return"] > 0 and metrics["electrified_targets"] >= 2, "actual alternating history refunds SP once and changes chained priorities")
			else:
				decision = "desacelerar área próxima e estender cobertura por centros finitos"
				skills = [&"elementalist_glacial_ring", &"elementalist_ember_path"]
				_check(p.use_elementalist_glacial_ring(), "area route launches Glacial Ring")
				var slowed := first.attribute_debuffs.fraction(AttributeDebuffState.MOVE_SPEED) > 0; var centers := p.elementalist_ember_centers(Vector2.RIGHT)
				_check(p.use_elementalist_ember_path(Vector2.RIGHT), "real Ember Path captures spatial centers")
				metrics = {"slowed_nearby": slowed, "finite_area_centers": centers.size()}
				_check(slowed and centers.size() == 3, "area route changes control and placement")
		"spiritualist":
			if branch == 0:
				decision = "marcar grupo e agendar eco fixo antes de mover o portador"
				skills = [&"spiritualist_echo_curse", &"fire_spear"]
				_check(p.use_spiritualist_echo_curse(first) and p.use_spear(&"fire_spear", first), "real curse plus triggering action commit")
				var sp_before := p.current_sp
				_projectiles(); var hp := second.health.current_hp
				var sp_return := p.current_sp - sp_before
				_check(sp_return > 0, "real echo trigger recovers SP through learned Recolhimento")
				_check(arena.spiritualist_echo_state.pending.size() == 1, "direct action schedules finite wave")
				var carrier_hp := first.health.current_hp
				first.position = Vector2(850, 350)
				for echo: Dictionary in arena.spiritualist_echo_state.advance(0.36): arena._apply_spiritualist_echo(echo)
				arena.spiritualist_echo_state.finish_resolution()
				metrics = {"original_area_hit": second.health.current_hp < hp, "moving_carrier_escaped": first.health.current_hp == carrier_hp, "pending_propagation": arena.spiritualist_echo_state.pending.size(), "trigger_sp_return": sp_return}
				_check(metrics["original_area_hit"] and metrics["moving_carrier_escaped"], "fixed augment creates an actual positioning decision")
			else:
				decision = "permanecer imóvel para completar quatro ticks e inscrever próxima ação"
				skills = [&"spiritualist_soul_drain"]
				first.position = Vector2(500, 350)
				# Actual incoming attack creates the missing HP before channel healing.
				outside.position = Vector2(370, 350); _enemy_attack(outside, arena)
				var hp := p.health.current_hp
				_check(p.use_spiritualist_soul_drain(first), "real full build channel starts")
				for tick: int in 4: arena._advance_spiritualist_drain(0.5)
				metrics = {"resolved_ticks": arena.spiritualist_drain_state.ticks_resolved, "healed_hp": p.health.current_hp - hp, "inscription": arena.spiritualist_echo_state.has_mark(first.get_instance_id())}
				_check(metrics["resolved_ticks"] == 4 and metrics["healed_hp"] > 0 and metrics["inscription"], "drain route needs completed preparation and changes HP plus next action")
		"sentinel":
			p.sentinel_combat_active = true
			var initial_focus := p.sentinel_state.focus
			p._process(0.001) # Observe fixture placement as movement before stability starts.
			p._process(6)
			var prepared_focus := p.sentinel_state.focus
			_check(initial_focus == 0 and prepared_focus > 0, "actual stable player clock produces Focus without grants")
			if branch == 0:
				decision = "guardar estabilidade para pagar tiro preparado de precisão"
				skills = [&"sentinel_headshot"]
				_check(p.use_sentinel_reset(&"sentinel_headshot", first.position, first), "actual Headshot consumes generated Focus")
				_projectiles()
				metrics = {"stable_seconds": 6, "focus_generated": prepared_focus, "net_focus_paid": prepared_focus - p.sentinel_state.focus, "primary_hp_lost": 10000 - first.health.current_hp}
				_check(metrics["net_focus_paid"] > 0 and metrics["primary_hp_lost"] > 0, "precision route spends preparation resource")
			else:
				decision = "lançar rede em ponto escolhido e conservar Foco para tiro de controle"
				skills = [&"sentinel_net_shot", &"sentinel_concussion_shot"]
				_check(p.use_sentinel_net(first.position), "actual net flies to selected point")
				_projectiles(); var net_control := first.is_rooted()
				_check(p.use_sentinel_reset(&"sentinel_concussion_shot", second.position, second), "actual control round spends remaining Focus")
				_projectiles()
				metrics = {"net_root": net_control, "concussion_stun": second.is_stunned(), "focus_remaining": p.sentinel_state.focus}
				_check(net_control and second.is_stunned(), "ammunition route controls distinct threats")
		"hunter":
			if branch == 0:
				decision = "reservar mecanismo à Marca sem restringir preparação por proximidade"
				skills = [&"hunter_mark", &"hunter_freezing_trap"]
				first.position = Vector2(600, 350); second.position = Vector2(500, 350)
				_check(p.use_hunter_mark(first) and p.use_hunter_trap(&"hunter_freezing_trap", second.position), "real marked placement captures selected prey")
				var trap := arena.trap_registry.active_traps()[0] as HunterTrap; trap.set_process(false)
				trap._process(trap.arming_duration + 0.001)
				var ignored := trap.is_active() and not second.is_rooted()
				first.position = Vector2(500, 350); trap._process(0.01)
				metrics = {"unmarked_ignored": ignored, "marked_rooted": first.is_rooted(), "opening_created": not p.hunter_state.opening(first.get_instance_id()).is_empty()}
				_check(ignored and metrics["marked_rooted"] and metrics["opening_created"], "mechanism decision distinguishes trigger target from nearest prey")
			else:
				decision = "consumir abertura preparada em leque e recuar com passo único"
				skills = [&"hunter_freezing_trap", &"hunter_covering_shot"]
				_check(p.use_hunter_trap(&"hunter_freezing_trap", first.position), "inherited learned trap prepares opening for mobility")
				var trap := arena.trap_registry.active_traps()[0] as HunterTrap; trap.set_process(false); trap._process(trap.arming_duration + 0.001)
				var opened := not p.hunter_state.opening(first.get_instance_id()).is_empty(); var origin := p.position
				_check(p.use_hunter_covering_shot(Vector2.RIGHT), "actual mobility shot consumes prepared prey")
				_projectiles()
				var targets: Dictionary = {}
				for event: Dictionary in events:
					if event["skill_id"] == &"hunter_exploit": targets[event["target_id"]] = true
				metrics = {"opening_from_trap": opened, "recoil_distance": origin.distance_to(p.position), "secondary_parcel_targets": targets.size(), "step_seconds": p.hunter_state.step_remaining}
				_check(opened and targets.size() == 2 and metrics["recoil_distance"] > 0 and metrics["step_seconds"] > 0, "mobility route changes pair selection and actual position")
		"mg_ar":
			p.position = Vector2(100, 100); first.position = Vector2(300, 200); second.position = Vector2(500, 200); outside.position = Vector2(400, 420)
			var casting := arena.geometer_casting; casting.targets = arena.enemies
			if branch == 0:
				decision = "construir parede fixa entre impactos e manter interações quando o portador move"
				skills = [&"geometer_trace"]
				_check(_trace(casting, first, &"ice") and _trace(casting, second, &"fire"), "actual two different trace impacts form wall")
				var point := casting.construction.vertices[0].position; first.position = Vector2(330, 310); casting.advance(0.01)
				metrics = {"wall_active": casting.construction.shape == GeometerConstructionState.Shape.WALL, "first_ground_fixed": casting.construction.vertices[0].position == point, "vertices": casting.construction.vertices.size()}
				_check(metrics["wall_active"] and metrics["first_ground_fixed"], "ground augment keeps actual wall position despite carrier movement")
				p.position = Vector2(400, 100); p.pursue(first); p._process(0.01)
				var launched := _projectiles()
				var wall_payloads := events.filter(func(event: Dictionary) -> bool: return event["skill_id"] == &"geometer_wall_exit")
				metrics["actual_owned_wall_payloads"] = wall_payloads.size()
				_check(launched > 0 and not wall_payloads.is_empty(), "real inherited basic projectile captures fire exit by crossing wall")
			else:
				decision = "fechar triângulo misto e consumi-lo pelo primeiro elemento"
				skills = [&"geometer_trace", &"geometer_triangulation", &"geometer_collapse"]
				_check(_trace(casting, first, &"fire") and _trace(casting, second, &"ice") and _trace(casting, outside, &"ice", true), "three actual projectiles satisfy mixed rank grammar")
				var triangle := casting.construction.shape == GeometerConstructionState.Shape.TRIANGLE
				for actor: CombatActor in arena.enemies: actor.advance_statuses(GeometerTriangleField.ROOT_DURATION + 0.001)
				var resolution: Array[Dictionary] = []
				casting.hit.connect(func(request: DamageRequest, _target: CombatActor) -> void:
					if request.skill_id == &"geometer_collapse": resolution.append(request.effect_snapshot.duplicate(true)))
				_check(casting.collapse(casting.capture(&"geometer_collapse", Vector2(400, 280), true)), "real triangle collapsed once")
				metrics = {"mixed_triangle_formed": triangle, "figure_consumed": not casting.construction.has_active_figure(), "resolution_requests": resolution.size(), "collapse_does_not_repeat_ice_root": not first.is_rooted()}
				_check(triangle and metrics["figure_consumed"] and resolution.size() > 0 and metrics["collapse_does_not_repeat_ice_root"], "triangle route changes finite preparation and geometry consumption")
	var snapshot: BuildSnapshot = comparison["snapshot"]
	var instances: Dictionary = {}
	for id: StringName in snapshot.equipment_instances:
		var instance: EquipmentInstance = snapshot.equipment_instances[id]
		var record := instance.to_record()
		if instance.power_ruleset_id == &"legacy_unscaled" and instance.recipe_revision_id == &"catalog_v1":
			record.erase("power_ruleset_id")
			record.erase("recipe_revision_id")
		instances[id] = record
	observations.append({"identity": identity, "branch": "A" if branch == 0 else "B", "decision": decision, "metrics": metrics, "decision_validated": failures == before_failures, "skills_executed": skills, "effect_attribution": {"kit": skills, "recipe_policies": comparison["composed"].get("kit_policies", {}), "recipe_provenance": comparison["composed"].get("provenance", [])}, "build": {"base_class_id": snapshot.base_class_id, "evolution_id": snapshot.evolution_id, "base_level": snapshot.base_level, "job_level": snapshot.job_level, "purchased_ranks": comparison["purchased_ranks"], "support_purchases": comparison.get("support_purchases", {}), "equipment_instances": instances, "effective_ranks": snapshot.skill_ranks, "action_slots": snapshot.action_slots, "equipped": snapshot.equipped, "augment_stacks": arena.run_state.augment_stacks, "card_instances": arena.run_state.card_instances, "card_sockets": arena.run_state.card_sockets}, "observed_secondary_emissions": emissions.duplicate(), "production_published": false, "balance_validated": false, "performance_validated": false})
	await _finish(arena)
