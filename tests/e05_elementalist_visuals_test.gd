extends SceneTree

var checks := 0
var failures := 0

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var indicators := BattleIndicators.new()
	root.add_child(indicators)
	indicators.show_elementalist_arc_link(Vector2(20, 30), Vector2(140, 30))
	_check(indicators.elementalist_pulses.is_empty() and indicators.elementalist_arc_links.size() == 1, "Arc link remains outside counted impact pulses")
	indicators.show_elementalist_arc_link(Vector2.INF, Vector2(140, 30))
	_check(indicators.elementalist_arc_links.size() == 1, "nonfinite Arc endpoints never enter the visual queue")
	indicators.show_elementalist_prism(Vector2(80, 70), &"elementalist_prismatic_focus")
	_check(indicators.elementalist_prisms.size() == 1 and indicators.elementalist_prisms[0]["skill_id"] == &"elementalist_prismatic_focus", "Prismatic Focus receives a noncombat prism acknowledgement")
	for index: int in range(BattleIndicators.ELEMENTALIST_MAX_PULSES + 4):
		indicators.show_elementalist_pulse(&"elementalist_flame_burst", Vector2(index, 100), 30.0, &"fire")
	_check(indicators.elementalist_pulses.size() == BattleIndicators.ELEMENTALIST_MAX_PULSES and indicators.elementalist_pulses[0]["center"] == Vector2(4, 100), "impact queue remains capped at 64 newest visuals")
	paused = true
	indicators._process(1.0)
	_check(indicators.elementalist_pulses.size() == BattleIndicators.ELEMENTALIST_MAX_PULSES and indicators.elementalist_arc_links.size() == 1 and indicators.elementalist_prisms.size() == 1, "pause freezes every Elementalist cosmetic queue")
	paused = false
	indicators._process(BattleIndicators.ELEMENTALIST_PULSE_DURATION + 0.01)
	_check(indicators.elementalist_pulses.is_empty() and indicators.elementalist_arc_links.is_empty() and indicators.elementalist_prisms.is_empty(), "all cosmetic visual kinds expire without gameplay work")
	for index: int in range(100):
		indicators.show_elementalist_arc_link(Vector2(index, 0), Vector2(index + 30, 0))
		indicators.show_elementalist_prism(Vector2(index, 80), &"elementalist_prismatic_resonance")
	_check(indicators.elementalist_arc_links.size() == BattleIndicators.ELEMENTALIST_MAX_PULSES and indicators.elementalist_prisms.size() == BattleIndicators.ELEMENTALIST_MAX_PULSES, "each auxiliary queue has a finite independent cap")
	indicators._process(BattleIndicators.ELEMENTALIST_ARC_LINK_DURATION + 0.01)
	_check(indicators.elementalist_arc_links.is_empty() and not indicators.elementalist_prisms.is_empty(), "link lifetime expires independently from passive feedback")
	indicators.free()
	print("Visuais Elementalista: %s" % ("PASS (%d checks)" % checks if failures == 0 else "FAIL (%d de %d)" % [failures, checks]))
	quit(0 if failures == 0 else 1)

func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(label)
