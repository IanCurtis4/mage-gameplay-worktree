extends SceneTree
## Guide/tooltip presentation only. Fixtures never open a persistent profile.

var checks := 0
var failures := 0

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	_tooltips()
	await _guide()
	print("Sentinel S7 onboarding: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

func _build(sentinel: bool = true) -> BuildSnapshot:
	var build := BuildSnapshot.new()
	build.character_id = "sentinel-guide-fixture"
	build.base_class_id = &"archer"
	build.evolution_id = &"sentinel" if sentinel else &""
	build.base_level = 20
	build.job_level = 40
	build.library_skill_ids = ProfileCatalog.pilot().skill_ids_for_identity(&"archer", build.evolution_id)
	build.skill_ranks = {&"sentinel_headshot": 1, &"sentinel_observe": 1, &"sentinel_explosive_shot": 1}
	build.active_slots = [&"sentinel_headshot", &"sentinel_observe", &"sentinel_explosive_shot", null, null] if sentinel else [null, null, null, null, null]
	build.passive_slots = [null, null]
	return build

func _player(sentinel: bool = true) -> PlayerActor:
	var nav := ArenaNavigation.new()
	nav.configure(Rect2(0, 0, 1280, 720), [], 20.0)
	var player := PlayerActor.new()
	player.position = Vector2(300, 500)
	player.configure(nav, RunState.from_build("", _build(sentinel)))
	root.add_child(player)
	player.set_process(false)
	player.sentinel_combat_active = true
	return player

func _fingerprint(player: PlayerActor) -> Array:
	var state := player.sentinel_state
	return [state.focus, state.stable_time, state.inactive_time, state.observed_target_id, state.observation_remaining, state.observation_charges, state.observation_cooldown, state.opening_cooldown, state.absolute_remaining, state.reserved_focus, state.reserved_sp, state.explosive_prepared, player.current_sp, player.health.current_hp, player.attack_cooldown, player.mage_cooldowns.duplicate(true), player.global_position, player.velocity]

func _tooltips() -> void:
	var menu := CharacterMenu.new()
	for id: StringName in SentinelTuning.SKILL_IDS:
		var maximum := SentinelTuning.max_rank(id)
		for rank: int in [0, 1, maximum - 1, maximum]:
			var next: Variant = rank + 1 if rank < maximum else null
			var option := {"skill_id": id, "rank": rank, "maximum_rank": maximum, "next_rank": next, "next_rank_requirement": {"job_level": 20, "skill_ranks": {}}, "metadata": {"category": ProfileCatalog.PASSIVE if id in [&"sentinel_precision_stance", &"sentinel_opening_read"] else ProfileCatalog.ACTIVE, "wallet": ProfileCatalog.EVOLUTION_WALLET}}
			var tooltip := menu._skill_progression_tooltip(option)
			_check(("Atual R%d: %s" % [rank, ClassCatalog.sentinel_description(id, rank)]) in tooltip if rank > 0 else not "Atual R0" in tooltip, "%s R%d current description matches catalog without invented rank0" % [id, rank])
			_check(("Próximo R%d: %s" % [next, ClassCatalog.sentinel_description(id, next)]) in tooltip if next != null else "Rank máximo atingido." in tooltip and not "Próximo R" in tooltip, "%s R%d next description matches catalog / bounded cap" % [id, rank])
			_check("Aprender não equipa automaticamente." in tooltip and "carteira evolução" in tooltip, "%s tooltip preserves progression contract" % id)
	menu.free()

func _guide() -> void:
	root.size = Vector2i(1280, 720)
	root.content_scale_size = Vector2i(1280, 720)
	var player := _player()
	player.sentinel_state.focus = 80.0
	player.sentinel_state.stable_time = 1.0
	var guide := SentinelOnboarding.new()
	guide.configure(player)
	root.add_child(guide)
	await process_frame
	await process_frame
	_check(guide.visible and not guide.help_label.visible and guide.toggle_button.text == "Guia +", "Sentinel guide starts compact with closed help")
	_check("80 livre" in guide.status_label.text and "+10/s" in guide.status_label.text, "read-only current resource and steady generation")
	_check(guide._panel.size.x <= 420.0 and guide._panel.size.y <= 145.0, "closed guide bounded and compact at1280x720")
	_mouse_filters(guide)
	player.sentinel_state.observe(player.get_instance_id(), 1)
	player.sentinel_state.explosive_prepared = true
	player.sentinel_state.reserved_focus = 25.0
	player.sentinel_state.reserved_sp = 20.0
	player.sentinel_state.absolute_remaining = 4.5
	var before := _fingerprint(player)
	guide.refresh()
	_check("55 livre" in guide.status_label.text and "25 reservado" in guide.status_label.text and "20 SP reservado" in guide.status_label.text, "guide separates free / reserved SP and Focus")
	_check("Observar 3/3" in guide.status_label.text and "Absoluto 4.5 s" in guide.status_label.text and "+15/s" in guide.status_label.text, "live mark charges, ammunition and Absolute clock read only")
	_check(_fingerprint(player) == before, "refresh cannot advance clocks or change combat state")
	var input_probe := WorldInputProbe.new()
	input_probe.process_mode = Node.PROCESS_MODE_ALWAYS
	root.add_child(input_probe)
	for mode: int in [CastIntent.Mode.CONFIRM, CastIntent.Mode.RELEASE, CastIntent.Mode.INSTANT]:
		input_probe.intent.set_mode(mode)
		input_probe.intent.active_skill = &"sentinel_headshot"
		before = _fingerprint(player)
		guide.toggle_button.pressed.emit()
		await process_frame
		_check(guide.help_label.visible and guide.toggle_button.text == "Guia −", "help expands in cast mode%d" % mode)
		_check(input_probe.intent.active_skill == &"sentinel_headshot" and _fingerprint(player) == before, "help leaves targeting/resources unchanged in mode%d" % mode)
		_check(guide._panel.size.x <= 420.0 and guide._panel.size.y <= 370.0 and guide._panel.get_global_rect().end.x <= 1280, "expanded help remains bounded in mode%d" % mode)
		if "--sentinel-ui-preview" in OS.get_cmdline_user_args():
			await _click_button(guide.toggle_button)
			_check(not guide.help_label.visible and input_probe.world_clicks == 0, "native UI button consumes click before combat in mode%d" % mode)
			_check(input_probe.intent.active_skill == &"sentinel_headshot" and _fingerprint(player) == before, "native click cannot launch/cancel cast in mode%d" % mode)
		else:
			guide.toggle_button.pressed.emit()
		await process_frame
		_check(not guide.help_label.visible and guide._panel.size.y < 190.0, "collapse shrinks former expanded container in mode%d" % mode)
	_check("Repita Explosivo ou Esc" in guide.help_label.text and "sem auto extra" in guide.help_label.text and "não reseta" in guide.help_label.text and "alvo ainda pode atacar" in guide.help_label.text, "short Portuguese help distinguishes reset/preparation/root")
	paused = true
	before = _fingerprint(player)
	guide.refresh()
	guide.toggle_button.pressed.emit()
	await process_frame
	_check(guide.help_label.visible and "Pausa" in guide.status_label.text and _fingerprint(player) == before, "help works during pause without advancing or spending")
	if "--sentinel-ui-preview" in OS.get_cmdline_user_args():
		await _capture()
	paused = false
	var archer := _player(false)
	guide.configure(archer)
	_check(not guide.visible, "base Archer never shows Sentinel guide")
	guide.configure(player)
	player.health.current_hp = 0.0
	guide.refresh()
	_check(not guide.visible, "dead actor hides guide without cleanup mutation")
	guide.configure(null)
	_check(not guide.visible, "missing actor hides guide safely")
	player.queue_free()
	archer.queue_free()
	guide.queue_free()
	input_probe.queue_free()
	await process_frame
	_check(not is_instance_valid(guide) and not is_instance_valid(player), "scene teardown leaves no guide or actor owner")

func _mouse_filters(node: Node) -> void:
	if node is Control:
		var control := node as Control
		if control is Button:
			_check(control.mouse_filter == Control.MOUSE_FILTER_STOP and control.focus_mode == Control.FOCUS_NONE, "sole guide button stops mouse without stealing skill key focus")
		else:
			_check(control.mouse_filter == Control.MOUSE_FILTER_IGNORE, "informative control lets clicks through: %s" % control.get_class())
	for child: Node in node.get_children():
		_mouse_filters(child)

func _click_button(button: Button) -> void:
	var point := button.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = point
	motion.global_position = point
	Input.parse_input_event(motion)
	await process_frame
	for pressed: bool in [true, false]:
		var click := InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		click.position = point
		click.global_position = point
		click.pressed = pressed
		Input.parse_input_event(click)
		await process_frame

func _capture() -> void:
	if DisplayServer.get_name() == "headless":
		_check(false, "UI preview requires a real renderer")
		return
	await process_frame
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://.godot/verification"))
	_check(root.get_texture().get_image().save_png("res://.godot/verification/sentinel_onboarding_native.png") == OK, "real renderer guide capture saved")

func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(label)

class WorldInputProbe extends Node:
	var world_clicks := 0
	var intent := CastIntent.new()
	func _unhandled_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			world_clicks += 1
			intent.confirm()
