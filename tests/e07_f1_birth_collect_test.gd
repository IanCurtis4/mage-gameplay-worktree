extends SceneTree
const Fixture = preload("res://tests/fixtures/e07/f1/fixture_input.gd")
class Controller extends RunController:
	var grants := 0
	var fail_next := false
	func _ready() -> void: pass
	func _spawn_death_visual(_actor: CombatActor,_after_run: bool = false) -> void: pass # D05 presentation is pending.
	func _grant_persistent_encounter_reward() -> Dictionary:
		grants += 1
		if fail_next: fail_next = false; return {"ok":false,"error_code":&"save_in_progress"}
		return super._grant_persistent_encounter_reward()
var checks := 0
var failures := 0
var owned: Array[Node] = []
var c: Controller
var world: WorldGeometry
var profile: Dictionary
var input: ExpeditionGenerationInput
func check(ok: bool,label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(label)
func _initialize() -> void: _run.call_deferred()
func _run() -> void:
	if not Fixture.sources_current(): push_error("stale fixture"); quit(1); return
	_birth()
	for reason: String in ["occupied","stale","height","surface","outside","profile","disconnected","dead","paused","finished","stage","species","category","missing_companion_profile"]: _invalid(reason)
	for mode: String in ["normal","origin","owner_death","paused","removed","epoch","end","incompatible","blocked"]: await _companion(mode)
	await _death_collect()
	_collection_guards()
	for item: Variant in owned:
		if is_instance_valid(item): item.free()
	await process_frame
	print("E07 F1 birth and collection: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
func _birth() -> void:
	_setup()
	var point := Fixture.point("root",Vector3(240,0,600))
	var body := profile.duplicate(true)
	var result := c.spawn_world_enemy({"species":&"test_gel","category":&"normal"},point,body,world.geometry_revision,4)
	check(result["ok"],"real catalog enemy born on exact authored support")
	if not result["ok"]: return
	var actor := result["data"]["actor"] as EnemyActor; actor.set_process(false)
	check(actor.get_parent() == c and actor in c.enemies and actor.world_point().to_data() == point.to_data() and actor._world_home.to_data() == point.to_data(),"actor is bound before publication and captures logical leash home")
	point.position.x = 350; body["radius"] = 99
	check(actor.world_point().position.x == 240 and actor.world_motion.profile()["radius"] == profile["radius"],"birth copies caller point and traversal")
	check(actor.occurrence.origin_id == PlaytestGameplay.origin(4) and c.reward_service._mob_actors.has(actor.get_instance_id()),"actual origin and reward service register the born actor")
	var snapshot: MobOccurrence = c.reward_service._mob_actors[actor.get_instance_id()]["occurrence"]
	check(snapshot.occurrence_id == actor.occurrence.occurrence_id and snapshot != actor.occurrence,"loot holds independent immutable occurrence snapshot")
	var upper := c.spawn_world_enemy({"species":&"test_gel","category":&"normal"},Fixture.point("bridge",Vector3(240,40,600)),profile,world.geometry_revision,4)
	check(upper["ok"],"same x/z on bridge is distinct unoccupied support")
	if upper["ok"]:
		var other := upper["data"]["actor"] as EnemyActor; other.set_process(false)
		check(actor.global_position == other.global_position and actor.world_distance_to(other) == 40,"pixel equality cannot collapse two births into one floor")
	var count := c.enemies.size(); var revision := c.navigation.revision; var index := c.encounter_index
	check(c._spawn_enemy(&"chaser",Vector2(10,10)) == null and c._spawn_route_enemy({"species":&"test_gel","category":&"normal","position":Vector2(10,10)},4) == null and c.enemies.size() == count,"pixel spawn entries remain blocked in a bound controller")
	c._spawn_encounter(5); c._configure_world(5)
	check(c.world_spawn_error == &"world_lifecycle_required" and c.encounter_index == index and c.navigation.revision == revision and c.enemies.size() == count,"legacy stage switch cannot relocate a bound player or reconfigure its world")
func _invalid(reason: String) -> void:
	_setup()
	var point := Fixture.point("root",Vector3(240,0,600)); var body := profile.duplicate(true)
	var entry := {"species":&"test_gel","category":&"normal"}; var revision := world.geometry_revision; var stage := 4
	match reason:
		"occupied": point = c.player.world_point()
		"stale": revision -= 1
		"height": point.position.y = 1
		"surface": point.surface_id = "missing"
		"outside": point.position.x = 9999
		"profile": body["radius"] = 0
		"disconnected": body["connector_kinds"] = ["missing"]; point = Fixture.point("bridge",Vector3(240,40,600))
		"dead": c.player.health.current_hp = 0
		"paused": paused = true
		"finished": c.run_finished = true
		"stage": stage = 0
		"species": entry["species"] = &"unknown"
		"category": entry["category"] = &"unknown"
		"missing_companion_profile": entry = {"species":&"test_beast_master","category":&"rare"}
	var before := c.rng.state; var pose := c.player.world_point().to_data()
	var result := c.spawn_world_enemy(entry,point,body,revision,stage)
	check(not result["ok"] and not str(result["error_code"]).is_empty() and c.enemies.is_empty(),"invalid birth is rejected before publication: "+reason)
	check(c.rng.state == before and c.player.world_point().to_data() == pose and not c._startup_error and c.reward_service._mob_actors.is_empty(),"failed birth leaves RNG/player/loot intact: "+reason)
	paused = false
func _companion(mode: String) -> void:
	_setup(mode != "blocked")
	var point := Fixture.point("landing",Vector3(1000,40,600)) if mode != "blocked" else Fixture.point("bridge",Vector3(50,40,150))
	var result := c.spawn_world_enemy({"species":&"test_beast_master","category":&"rare"},point,profile,world.geometry_revision,4,profile)
	check(result["ok"],"real Master born with explicit child body: "+mode)
	if not result["ok"]: return
	var master := result["data"]["actor"] as EnemyActor; master.set_process(false); master.engagement_mode = &"engaged"
	var rng_before := c.rng.state
	master._request_companion_once(); master._request_companion_once()
	check(master.summon_used and c.enemies.size() == 1,"Master claims one finite real deferred request before callback")
	match mode:
		"origin": c.encounter_index = 5
		"paused": paused = true
		"removed": c.enemies.erase(master); master.free()
		"epoch": world.configure(ExpeditionAssembler.build(input)["data"]["manifest"],"sample")
		"end": c.encounter_active = false
		"incompatible":
			var replacement := WorldGeometry.new(); replacement.configure(ExpeditionAssembler.build(input)["data"]["manifest"],"sample")
			c.player.world_motion.geometry = replacement
	await process_frame
	if mode == "paused":
		check(c.enemies.size() == 1 and c._world_pending_companions.size() == 1,"pause retains one deferred attempt without creating an actor")
		paused = false; c._advance_world_companion_requests()
	check(c.rng.state == rng_before,"companion placement never consumes loot/RNG stream")
	var children: Array[EnemyActor] = []
	for actor: CombatActor in c.enemies:
		if actor is EnemyActor and actor.is_summoned: children.append(actor)
	if mode in ["normal","origin","owner_death","paused"]:
		check(children.size() == 1,"one supported animal is born through actual controller")
		if children.size() != 1: return
		var child := children[0]; child.set_process(false)
		check(child.world_point().surface_id == master.world_point().surface_id and child.world_point().position == master.world_point().position+Vector3(-185,0,45),"first canonical offset resolves on source support without projection/snap")
		check(child.summoner_id == master.get_instance_id() and child.occurrence.category_id == MobTierRules.lower_category(master.occurrence.category_id) and child.occurrence.origin_id == master.occurrence.origin_id,"child preserves owner, lower category and origin")
		check(c._required_enemies() == [master] and not c.reward_service._mob_actors.has(child.get_instance_id()),"child never blocks clear or acquires its own loot registration")
		child._request_companion_once(); c._on_companion_requested(master)
		check(c.enemies.size() == 2 and not child.summon_used,"child cannot recursively summon; duplicate owner callback creates nothing")
		if mode == "owner_death":
			var body := child.world_point(); var id := str(child.get_instance_id())
			_kill(master)
			check(c.enemies.is_empty() and child.is_queued_for_deletion() and c.reward != null and not c.encounter_active,"Master death removes live child and clears canonical encounter")
			await process_frame
			check(not world.position_query(body,profile,world.geometry_revision)["data"]["occupants"].has(id),"removed live companion releases only its own world occupancy")
			check(c.reward_service._queue.size() == 2,"Master alone produces one mob ticket plus encounter ticket, never a companion reward")
			return
		var queue := c.reward_service._queue.duplicate(); _kill(child)
		check(c.reward_service._queue == queue and not c._credited_kills.has(child.get_instance_id()) and c.encounter_active,"actual child death grants no loot/kill credit and leaves Master encounter active")
	else: check(children.is_empty(),"late incompatible/removed/ended or unsupported attempt never spawns flat: "+mode)
func _death_collect() -> void:
	_setup()
	var born := c.spawn_world_enemy({"species":&"test_gel","category":&"normal"},Fixture.point("root",Vector3(240,0,600)),profile,world.geometry_revision,4)
	check(born["ok"],"death fixture uses actual born mob")
	if not born["ok"]: return
	var actor := born["data"]["actor"] as EnemyActor; actor.set_process(false)
	var occupant := str(actor.get_instance_id()); var dead_pose := actor.world_point()
	_kill(actor)
	check(not c.encounter_active and c.reward != null and c.reward.world_area != null and c.reward.world_area.anchor().to_data() == c.player.world_point().to_data(),"real final death creates supported pickup at player's nominal clear position")
	check(not c.reward.ticket_id.is_empty() and c.reward_service._queue.size() == 2,"normal loot and encounter reward remain canonical queued tickets")
	var pickup := c.reward
	check(c._create_reward_pickup()["ok"] and c.reward == pickup,"duplicate placement does not create another pickup or ticket")
	await process_frame
	check(not world.position_query(dead_pose,profile,world.geometry_revision)["data"]["occupants"].has(occupant),"dead actor cleanup releases its own spatial occupant")
	var anchor := c.reward.world_area.anchor()
	check(c.player.move_world_to(Fixture.point("bridge",Vector3(anchor.position.x,40,anchor.position.z)),world.geometry_revision)["ok"],"collector reaches overlapping upper support through real connectors")
	c.player.advance_world(10000)
	var queue := c.reward_service._queue.duplicate(); var rng_before := c.rng.state
	check(not c._collect_reward()["ok"] and c.grants == 0 and c.reward_service._queue == queue and c.reward == pickup,"direct collection/shortcut cannot bypass lower-floor distance or consume tickets")
	check(c.player.move_world_to(anchor,world.geometry_revision)["ok"],"collector returns by connected route")
	c.player.advance_world(10000)
	c.fail_next = true
	check(not c._collect_reward()["ok"] and c.grants == 1 and c._reward_retry_pending and c.reward == pickup and c.reward_service._queue == queue,"injected transient grant error leaves actual tickets and pickup pending")
	check(c.player.move_world_to(Fixture.point("root",Vector3(240,0,600)),world.geometry_revision)["ok"],"collector may leave pending pickup")
	c.player.advance_world(10000)
	check(not c._collect_reward()["ok"] and c.grants == 1 and c.reward_service._queue == queue,"retry also validates spatial range before authority call")
	check(c.player.move_world_to(anchor,world.geometry_revision)["ok"],"retry collector returns")
	c.player.advance_world(10000)
	check(c._collect_reward()["ok"] and c.grants == 2 and c.reward == null and c.reward_service._queue.is_empty() and not c._reward_retry_pending,"actual service delivers existing tickets exactly once after legal retry")
	check(not c._collect_reward()["ok"] and c.grants == 2 and c.rng.state == rng_before,"consumed pickup cannot reroll or reconcede")
func _collection_guards() -> void:
	for mode: String in ["pause","dead","combat","epoch","mixed"]:
		_setup(); c.encounter_active = false
		check(c._create_reward_pickup()["ok"] and c._ensure_reward_ticket()["ok"],"guard fixture issues actual encounter ticket")
		var queue := c.reward_service._queue.duplicate()
		match mode:
			"pause": paused = true
			"dead": c.player.health.current_hp = 0
			"combat": c.encounter_active = true
			"epoch": world.configure(ExpeditionAssembler.build(input)["data"]["manifest"],"sample")
			"mixed": c.player.world_motion = null
		check(not c._collect_reward()["ok"] and c.grants == 0 and c.reward_service._queue == queue,"invalid bound collection is rejected before any grant: "+mode)
		paused = false
func _kill(actor: EnemyActor) -> void:
	var request := DamageRequest.new(); request.source_id = c.player.get_instance_id(); request.target_id = actor.get_instance_id(); request.skill_id = &"f1_birth_fixture"; request.magic_damage = 1000000; request.accuracy_mode = DamageRequest.AccuracyMode.GEOMETRY; request.can_crit = false
	actor.apply_damage(request,c.rng)
func _setup(large: bool = true) -> void:
	input = Fixture.make()
	if large:
		for part: ExpeditionPartDefinition in input.parts:
			for surface: ExpeditionSurfaceDefinition in part.surfaces:
				for i: int in surface.vertices.size(): surface.vertices[i] = _scale(surface.vertices[i])
			for connector: ExpeditionConnectorDefinition in part.connectors: connector.position = _scale(connector.position); connector.width *= 4
			for socket: ExpeditionSocketDefinition in part.sockets: socket.position = _scale(socket.position)
			for i: int in part.solid_volumes.size():
				var box: AABB = part.solid_volumes[i]; part.solid_volumes[i] = AABB(_scale(box.position),_scale(box.size))
	world = WorldGeometry.new(); check(world.configure(ExpeditionAssembler.build(input)["data"]["manifest"],"sample")["ok"],"unmodified F0 assembler builds explicit technical fixture")
	profile = input.traversal.to_data()
	c = Controller.new(); root.add_child(c); owned.append(c); c.set_process(false)
	c.navigation.configure(Rect2(0,0,4000,4000),[],0); c.run_state = RunState.new(&"mage"); c.encounter_index = 4; c.encounter_active = true; c.gameplay_extension = true; c.rng.seed = 711
	c.player = PlayerActor.new(); c.add_child(c.player); c.player.configure(c.navigation,c.run_state); c.player.set_process(false)
	check(c.player.bind_world_geometry(world,Fixture.point("root",Vector3(80,0,600) if large else Vector3(20,0,150)),profile,str(c.player.get_instance_id()))["ok"],"fixture player bound")
	c.player.set_process(false)
	c.status_label = Label.new(); c.add_child(c.status_label); c.augment_button = Button.new(); c.add_child(c.augment_button)
	c.battle_indicators = BattleIndicators.new(); c.add_child(c.battle_indicators); c.trap_registry = PlayerTrapRegistry.new(); c.add_child(c.trap_registry)
	c.reward_feedback = RewardFeedbackPanel.new(); c.add_child(c.reward_feedback); c.reward_feedback.configure(c.acquisition_journal,c.run_state.effect_catalog(),false)
	c.reward_service = RunRewardService.new(c)
	check(c.reward_service.configure_mob_loot(EquipmentLootProfiles.production(c.run_state.effect_catalog()))["ok"],"actual loot resolver installed without personal profile")
func _scale(point: Vector3) -> Vector3: return Vector3(point.x*4,point.y,point.z*4)
