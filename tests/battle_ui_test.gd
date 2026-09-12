extends SceneTree

var checks := 0
var failures := 0

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	_test_intent()
	_test_targeting()
	_test_geometry()
	_test_preferences()
	print("UI de batalha: %s" % ("PASS (%d checks)" % checks if failures == 0 else "FAIL (%d de %d)" % [failures, checks]))
	quit(0 if failures == 0 else 1)

func _test_intent() -> void:
	var intent := CastIntent.new()
	_check(intent.press(&"slash") == &"" and intent.active_skill == &"slash", "default key press only selects a skill")
	_check(intent.release(&"slash") == &"" and intent.active_skill == &"slash", "key release preserves click-confirmed aim")
	_check(intent.confirm() == &"slash" and intent.confirm() == &"", "confirmation consumes aim exactly once")
	intent.set_mode(CastIntent.Mode.RELEASE)
	intent.press(&"slash")
	intent.press(&"dash")
	_check(intent.release(&"slash") == &"" and intent.release(&"dash") == &"dash", "only release of the currently selected skill casts")
	intent.press(&"slash")
	intent.confirm()
	_check(intent.release(&"slash") == &"", "release after click never duplicates the cast")
	intent.press(&"slash")
	intent.cancel()
	_check(intent.release(&"slash") == &"", "cancel prevents release casting")
	intent.set_mode(CastIntent.Mode.INSTANT)
	_check(intent.press(&"dash") == &"dash" and intent.active_skill == &"", "smart cast emits once on key press without lingering aim")

func _test_targeting() -> void:
	var first := CombatActor.new()
	var second := CombatActor.new()
	first.setup("A", Color.WHITE, RpgStats.derive({}), 19.0)
	second.setup("B", Color.WHITE, RpgStats.derive({}), 19.0)
	root.add_child(first)
	root.add_child(second)
	first.position = Vector2(300, 300)
	second.position = Vector2(390, 300)
	var actors: Array[CombatActor] = [first, second]
	var point := Vector2(350, 282)
	_check(BattleTargeting.pick(point, actors) == second, "acquisition chooses nearest assisted body")
	_check(BattleTargeting.pick(point, actors, first) == first, "small cursor shifts retain the displayed target")
	_check(BattleTargeting.pick(Vector2(385, 282), actors, first) == second, "direct body click overrides a retained target")
	_check(BattleTargeting.pick(Vector2(221, 282), actors, first) == first and BattleTargeting.pick(Vector2(219, 282), actors, first) == null, "lock exits at a finite mouse distance")
	_check(BattleTargeting.pick(point, actors, first, false) == null, "assistance can be disabled for precise targeting")
	first.health.current_hp = 0.0
	_check(BattleTargeting.pick(point, actors, first) == second, "dead target is never retained")
	first.free()
	second.free()

func _test_geometry() -> void:
	var outline := SkillGeometry.cone_outline(Vector2.ZERO, Vector2.RIGHT, PlayerActor.SLASH_RANGE, PlayerActor.SLASH_HALF_ANGLE)
	_check(outline.size() == 35 and outline[0] == Vector2.ZERO and outline[-1] == Vector2.ZERO, "cone preview is a closed footprint")
	_check(SkillGeometry.cone_contains(Vector2(154, 0), Vector2.RIGHT, PlayerActor.SLASH_RANGE, PlayerActor.SLASH_HALF_ANGLE) and not SkillGeometry.cone_contains(Vector2(156, 0), Vector2.RIGHT, PlayerActor.SLASH_RANGE, PlayerActor.SLASH_HALF_ANGLE), "preview and damage share the range boundary")

func _test_preferences() -> void:
	var preferences := ControlPreferences.new()
	preferences.path = "res://.godot/verification/controls_test_%d.cfg" % Time.get_ticks_usec()
	preferences.cast_mode = CastIntent.Mode.RELEASE
	preferences.smart_lock = false
	_check(preferences.save_settings() == OK, "control preferences save successfully")
	var restored := ControlPreferences.new()
	restored.path = preferences.path
	restored.load_settings()
	_check(restored.cast_mode == CastIntent.Mode.RELEASE and not restored.smart_lock, "control preferences survive a new instance")
	var config := ConfigFile.new()
	config.set_value("battle", "cast_mode", "bad")
	config.save(preferences.path)
	var invalid := ControlPreferences.new()
	invalid.path = preferences.path
	invalid.load_settings()
	_check(invalid.cast_mode == CastIntent.Mode.CONFIRM, "invalid preferences fall back to confirmed casting")
	DirAccess.remove_absolute(preferences.path)

func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(label)
