extends SceneTree

var checks := 0
var failures := 0

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var navigation := ArenaNavigation.new()
	navigation.configure(Rect2(0, 0, 1000, 700), [], 20.0)
	var snapshot := BuildSnapshot.new()
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
	indicators.show_aim(&"elementalist_tri_nova", actor, actor.global_position + Vector2.RIGHT * 900.0, true)
	_check(indicators.endpoint == actor.global_position and is_equal_approx(SkillGeometry.ELEMENTALIST_TRI_NOVA_RADIUS, 170.0), "Tri Nova preview remains centered with its closed radius")
	indicators.show_elementalist_pulse(&"elementalist_tri_nova", actor.global_position, SkillGeometry.ELEMENTALIST_TRI_NOVA_RADIUS, &"lightning")
	_check(is_equal_approx(indicators.elementalist_pulse_lifetime, BattleIndicators.ELEMENTALIST_PULSE_DURATION) and indicators.elementalist_pulse_element == &"lightning", "elemental pulse is presentation state with an explicit element")
	indicators._process(0.31)
	_check(is_zero_approx(indicators.elementalist_pulse_lifetime) and not indicators.elementalist_pulse_center.is_finite(), "expired elemental pulse clears without gameplay side effects")
	actor.free()
	indicators.free()
	print("Indicadores Elementalista: %s" % ("PASS (%d checks)" % checks if failures == 0 else "FAIL (%d de %d)" % [failures, checks]))
	quit(0 if failures == 0 else 1)

func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(label)
