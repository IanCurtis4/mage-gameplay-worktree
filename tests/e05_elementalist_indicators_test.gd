extends SceneTree

var checks := 0
var failures := 0

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var navigation := ArenaNavigation.new()
	navigation.configure(Rect2(0, 0, 1000, 700), [], 20.0)
	var snapshot := BuildSnapshot.new()
	snapshot.job_level = 40 # Legal fixture: all purchased evolution entry gates are satisfied.
	snapshot.base_class_id = &"mage"
	snapshot.evolution_id = &"elementalist"
	var actor := PlayerActor.new()
	actor.configure(navigation, RunState.from_build("elementalist-indicators", snapshot))
	actor.global_position = Vector2(300, 300)
	root.add_child(actor)
	var indicators := BattleIndicators.new()
	root.add_child(indicators)
	indicators.show_aim(&"elementalist_flame_burst", actor, actor.global_position + Vector2.RIGHT * 900.0, true)
	_check(is_equal_approx(indicators.origin.distance_to(indicators.endpoint), actor.skill_range(&"elementalist_flame_burst")), "Flame Burst preview clamps its point to the live skill range")
	indicators.show_aim(&"elementalist_glacial_ring", actor, actor.global_position + Vector2.RIGHT * 900.0, true)
	_check(indicators.endpoint == actor.global_position and is_equal_approx(SkillGeometry.ELEMENTALIST_GLACIAL_RING_RADIUS, 145.0), "Glacial Ring preview stays on the actor with its closed radius")
	indicators.show_aim(&"elementalist_lightning_arc", actor, actor.global_position + Vector2.RIGHT * 900.0, true)
	_check(is_equal_approx(indicators.origin.distance_to(indicators.endpoint), actor.skill_range(&"elementalist_lightning_arc")) and is_equal_approx(SkillGeometry.ELEMENTALIST_LIGHTNING_CHAIN_RANGE, 110.0), "Lightning Arc keeps target range separate from chain range")
	var embers := BattleIndicators.elementalist_ember_centers(actor.global_position, Vector2.RIGHT)
	_check(embers.size() == 3 and embers[0] == actor.global_position + Vector2(80, 0) and embers[2] == actor.global_position + Vector2(240, 0), "Ember Path preview uses the three closed 80-unit steps")
	navigation.configure(Rect2(0, 0, 1000, 700), [Rect2(415, 250, 20, 100)], 20.0)
	indicators.show_aim(&"elementalist_ember_path", actor, actor.global_position + Vector2.RIGHT * 900.0, true)
	_check(indicators.elementalist_ember_preview == PackedVector2Array([Vector2(380, 300)]) and indicators.endpoint == Vector2(380, 300), "live trail preview shares runtime truncation at wall")
	navigation.configure(Rect2(0, 0, 1000, 700), [Rect2(335, 250, 20, 100)], 20.0)
	indicators.show_aim(&"elementalist_ember_path", actor, actor.global_position + Vector2.RIGHT * 900.0, false)
	_check(indicators.elementalist_ember_preview.is_empty() and not indicators.available, "fully blocked trail has no fake valid preview circles")
	indicators.show_aim(&"elementalist_tri_nova", actor, actor.global_position + Vector2.RIGHT * 900.0, true)
	_check(indicators.endpoint == actor.global_position and is_equal_approx(SkillGeometry.ELEMENTALIST_TRI_NOVA_RADIUS, 170.0), "Tri Nova preview remains centered with its closed radius")
	indicators.show_elementalist_pulse(&"elementalist_tri_nova", actor.global_position, SkillGeometry.ELEMENTALIST_TRI_NOVA_RADIUS, &"lightning")
	_check(indicators.elementalist_pulses.size() == 1 and is_equal_approx(float(indicators.elementalist_pulses[0]["remaining"]), BattleIndicators.ELEMENTALIST_PULSE_DURATION) and indicators.elementalist_pulses[0]["element"] == &"lightning", "elemental pulse is presentation state with an explicit element")
	indicators._process(BattleIndicators.ELEMENTALIST_PULSE_DURATION + 0.01)
	_check(indicators.elementalist_pulses.is_empty(), "expired elemental pulse clears without gameplay side effects")
	for index: int in range(3):
		indicators.show_elementalist_pulse(&"elementalist_lightning_arc", Vector2(200 + index * 80, 300), 30.0, &"lightning")
	_check(indicators.elementalist_pulses.size() == 3 and indicators.elementalist_pulses[0]["center"] == Vector2(200, 300) and indicators.elementalist_pulses[2]["center"] == Vector2(360, 300), "three synchronous impacts remain visible in the same frame")
	paused = true
	indicators._process(0.5)
	_check(indicators.elementalist_pulses.size() == 3, "pause freezes simultaneous pulse lifetimes")
	paused = false
	indicators._process(0.2)
	indicators.show_elementalist_pulse(&"elementalist_glacial_ring", actor.global_position, 145.0, &"ice")
	indicators._process(BattleIndicators.ELEMENTALIST_PULSE_DURATION - 0.19)
	_check(indicators.elementalist_pulses.size() == 1 and indicators.elementalist_pulses[0]["element"] == &"ice", "older pulses expire independently from newer impact")
	for index: int in range(100):
		indicators.show_elementalist_pulse(&"elementalist_lightning_arc", Vector2(index, 300), 30.0, &"lightning")
	_check(indicators.elementalist_pulses.size() == BattleIndicators.ELEMENTALIST_MAX_PULSES, "visual pulse list has a finite memory cap")
	actor.free()
	indicators.free()
	print("Indicadores Elementalista: %s" % ("PASS (%d checks)" % checks if failures == 0 else "FAIL (%d de %d)" % [failures, checks]))
	quit(0 if failures == 0 else 1)

func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(label)
