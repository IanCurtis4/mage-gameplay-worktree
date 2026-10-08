extends SceneTree
## Cosmetic state cannot claim gameplay; exclusively isolated in-memory actors.
var checks := 0
var failures := 0

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var nav := ArenaNavigation.new()
	nav.configure(Rect2(0, 0, 2000, 1500), [], 20.0)
	var build := BuildSnapshot.new()
	build.base_class_id = &"archer"
	build.evolution_id = &"hunter"
	var player := PlayerActor.new()
	player.configure(nav, RunState.from_build("h6-cosmetic-unit", build))
	root.add_child(player)
	player.set_process(false)
	var visual := player.hunter_presentation
	visual.set_process(false)
	_check(visual != null and visual.get_parent() == player and visual.process_mode == Node.PROCESS_MODE_PAUSABLE, "owned pausable cosmetic consumer")
	var victim := CombatActor.new()
	victim.setup("Presa", Color.WHITE, player.stat_breakdown)
	root.add_child(victim)
	victim.set_process(false)
	victim.global_position = Vector2(300, 300)
	var snapshot := HunterMath.opening_request(player.get_instance_id(), &"hunter_freezing_trap", 1, player.stat_breakdown, 1.0)
	_check(player.activate_hunter_opening(1234, victim, snapshot), "real activation accepted")
	_check(player.hunter_state.mark(victim.get_instance_id(), 1), "priority accepted")
	var markers := visual._collect_markers()
	_check(markers.size() == 1 and markers[0]["marked"] and markers[0]["open"], "priority diamond and broken opening share one marker")
	var remaining := float(player.hunter_state.opening(victim.get_instance_id())["remaining"])
	var hp := victim.health.current_hp
	var sp := player.current_sp
	for index: int in 100:
		visual.notify_consumed(victim.global_position)
		visual.notify_trap(victim.global_position, &"hunter_thorn_trap", 85.0)
	_check(visual.events.size() == HunterPresentation.EVENT_CAP, "cosmetic bursts bounded independently of claims")
	visual._process(0.1)
	_check(victim.health.current_hp == hp and player.current_sp == sp and float(player.hunter_state.opening(victim.get_instance_id())["remaining"]) == remaining, "visual clock causes no damage/cost/gameplay expiry")
	paused = true
	var phase := visual.visual_time
	var event_remaining := float(visual.events[0]["remaining"])
	visual._process(2.0)
	visual.notify_consumed(victim.global_position)
	_check(visual.visual_time == phase and float(visual.events[0]["remaining"]) == event_remaining, "pause freezes even direct diagnostic calls")
	paused = false
	visual._process(0.4)
	_check(visual.events.is_empty(), "bursts expire without gameplay mutation")
	visual.notify_consumed(Vector2.INF)
	visual.notify_trap(Vector2.ZERO, &"other_skill", 85.0)
	visual.notify_trap(Vector2.ZERO, &"hunter_thorn_trap", NAN)
	_check(visual.events.is_empty(), "invalid cosmetic inputs rejected")
	player.hunter_state.step_remaining = 1.5
	for index: int in 40:
		player.global_position += Vector2(2, 0)
		visual._process(0.01)
	_check(not visual.trails.is_empty() and visual.trails.size() <= HunterPresentation.TRAIL_CAP, "short foot trail accumulates sub-stride frames and stays bounded")
	_check(player.hunter_state.step_remaining == 1.5, "cosmetics never advance movement buff")
	player.hunter_state.discard_target(victim.get_instance_id())
	_check(visual._collect_markers().is_empty(), "expired/discarded target removes priority and opening")
	player.activate_hunter_opening(1235, victim, snapshot)
	victim.queue_free()
	_check(visual._collect_markers().is_empty(), "queued target is never retained or drawn")
	player.clear_hunter_state()
	_check(visual.events.is_empty() and visual.trails.is_empty() and visual._collect_markers().is_empty(), "terminal cleanup erases all cosmetic state")
	var prey := CombatActor.new()
	prey.setup("Callback", Color.WHITE, player.stat_breakdown)
	root.add_child(prey)
	prey.set_process(false)
	player.activate_hunter_opening(1236, prey, snapshot)
	var result := {"source_id": player.get_instance_id(), "target_id": prey.get_instance_id(), "skill_id": &"basic_attack", "actual_damage": 1.0, "emission_id": 77, "can_trigger_effects": true}
	player.record_hunter_damage(result)
	_check(visual.events.size() == 1 and player.hunter_state.opening(prey.get_instance_id()).is_empty(), "committed consume creates exactly one impact")
	player.record_hunter_damage(result)
	_check(visual.events.size() == 1, "duplicate callback never creates another impact")
	player.clear_hunter_state()
	visual.notify_consumed(Vector2.ZERO)
	player.health.current_hp = 0.0
	visual._process(0.1)
	_check(visual.events.is_empty() and visual.trails.is_empty() and visual._collect_markers().is_empty(), "dead owner removes cosmetics without requiring target callbacks")
	prey.queue_free()
	for id: StringName in HunterTuning.SKILL_IDS:
		var texture := load("res://assets/art/icons/hunter/%s.svg" % id) as Texture2D
		_check(texture != null and texture.get_size() == Vector2(64, 64), "%s exclusive icon is a real 64px asset" % id)
	player.queue_free()
	await process_frame
	print("E05 Hunter H6 presentation: %s (%d checks)" % ["PASS" if failures == 0 else "FAIL", checks])
	quit(0 if failures == 0 else 1)

func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(label)
