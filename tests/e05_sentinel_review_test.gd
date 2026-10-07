extends "res://tests/e05_sentinel_explosive_test.gd"
## Independent integrated regressions: real death callbacks and pause modals.

func _run() -> void:
	for skill: StringName in [EXPLOSIVE, &"sentinel_net_shot"]:
		await _lethal_area(skill)
	await _pause_modals()
	print("Sentinel integrated review: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

func _lethal_area(skill: StringName) -> void:
	var arena := _scene()
	arena.training_boss.position = Vector2(900, 600)
	var victims: Array[EnemyActor] = []
	for index: int in range(4):
		var victim := arena._spawn_enemy(&"chaser", Vector2(470 + index * 8, 300))
		victim.set_process(false)
		victim.health.current_hp = 1.0 if index < 3 else 1000.0
		victim.health.max_hp = 1000.0
		victims.append(victim)
	var request := DamageRequest.new()
	request.source_id = arena.player.get_instance_id()
	request.skill_id = skill
	request.emission_id = 123
	request.magic_damage = 500.0
	request.can_crit = false
	request.accuracy_mode = DamageRequest.AccuracyMode.GEOMETRY
	arena._on_sentinel_burst(Vector2(480, 300), request, SentinelTuning.values(skill, 5))
	for index: int in range(3):
		_check(not victims[index].is_alive() and not arena.enemies.has(victims[index]), "%s resolves every lethal victim despite synchronous removal" % skill)
	_check(victims[3].health.current_hp < 1000.0, "%s reaches surviving victim after deaths" % skill)
	if skill == &"sentinel_net_shot":
		_check(victims[3].is_rooted(), "net roots survivor after earlier lethal impacts")
	arena.queue_free()
	await process_frame

func _pause_modals() -> void:
	var arena := _scene()
	var player := arena.player
	_check(player.prepare_sentinel_explosive(), "prepare ammunition for class pause")
	var before := _fingerprint(player)
	arena._open_class_menu()
	_check(paused and arena.class_overlay.visible, "class menu is a pause modal")
	_check(_fingerprint(player) == before, "class pause preserves ammunition and resources")
	arena._close_class_menu()
	_check(not paused and _fingerprint(player) == before, "closing class pause preserves ammunition")
	if not player.sentinel_state.explosive_prepared:
		player.prepare_sentinel_explosive()
	before = _fingerprint(player)
	arena.encounter_active = false
	arena.run_state.queue_choice()
	arena._open_augment_menu()
	_check(paused and arena.augment_overlay.visible, "augment selection opens pause")
	_check(_fingerprint(player) == before, "augment pause preserves ammunition and resources")
	paused = false
	arena._cancel_casting()
	_check(not player.sentinel_state.explosive_prepared, "explicit cancellation still releases ammunition")
	arena.queue_free()
	await process_frame
