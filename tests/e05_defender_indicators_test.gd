extends SceneTree

var checks := 0
var failures := 0

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	_test_closed_preview_geometry()
	_test_wall_advance_safe_endpoint()
	_test_transient_zone_state()
	print("Indicadores Defendente: %s" % ("PASS (%d checks)" % checks if failures == 0 else "FAIL (%d de %d)" % [failures, checks]))
	quit(0 if failures == 0 else 1)

func _test_closed_preview_geometry() -> void:
	var clamped := BattleIndicators.defender_clamped_point(Vector2.ZERO, Vector2(300, 0), BattleIndicators.DEFENDER_ANCHOR_RANGE)
	_check(is_equal_approx(clamped.length(), 150.0), "anchor preview clamps the point to 150 units")
	var cone := SkillGeometry.cone_outline(Vector2.ZERO, Vector2.RIGHT, BattleIndicators.DEFENDER_COUNTERSTROKE_RANGE, BattleIndicators.DEFENDER_COUNTERSTROKE_HALF_ANGLE)
	_check(cone[0] == Vector2.ZERO and cone[-1] == Vector2.ZERO and cone.size() > 4, "counterstroke preview uses a closed 90 degree cone")
	_check(is_equal_approx(BattleIndicators.DEFENDER_LINE_LOCK_LENGTH, 170.0) and is_equal_approx(BattleIndicators.DEFENDER_LINE_LOCK_HALF_WIDTH * 2.0, 44.0), "line lock preview preserves the closed 170 by 44 strip")
	_check(is_equal_approx(BattleIndicators.DEFENDER_ANCHOR_RADIUS, 100.0) and is_equal_approx(BattleIndicators.DEFENDER_REPRISAL_WAVE_RADIUS, 130.0), "anchor and reprisal radii stay separate")

func _test_wall_advance_safe_endpoint() -> void:
	var origin := Vector2(10, 20)
	var direction := Vector2.RIGHT
	var safe := BattleIndicators.defender_wall_advance_endpoint(origin, direction, Vector2(90, 20), 130.0)
	_check(safe == Vector2(90, 20), "wall advance shows the navigation-cleared endpoint")
	var over_range := BattleIndicators.defender_wall_advance_endpoint(origin, direction, Vector2(200, 20), 130.0)
	_check(over_range == Vector2(140, 20), "wall advance rejects a supplied endpoint beyond rank distance")
	var behind := BattleIndicators.defender_wall_advance_endpoint(origin, direction, Vector2(0, 20), 130.0)
	_check(behind == Vector2(140, 20), "wall advance rejects a supplied endpoint behind the actor")
	var fallback := BattleIndicators.defender_wall_advance_endpoint(origin, direction, Vector2.INF, 95.0)
	_check(fallback == Vector2(105, 20), "wall advance has a bounded preview before navigation supplies an endpoint")

func _test_transient_zone_state() -> void:
	var indicators := BattleIndicators.new()
	root.add_child(indicators)
	indicators.show_defender_anchor(Vector2(75, 90), 0.25)
	_check(indicators.defender_anchor_position == Vector2(75, 90) and is_equal_approx(indicators.defender_anchor_remaining, 0.25), "anchor VFX stores one owner zone and its remaining duration")
	indicators.show_defender_reprisal_wave(Vector2(75, 90))
	_check(is_equal_approx(indicators.defender_wave_lifetime, 0.32), "reprisal wave starts as a cosmetic transient")
	indicators._process(0.40)
	_check(not indicators.defender_anchor_position.is_finite() and is_zero_approx(indicators.defender_wave_lifetime), "expired Defender VFX clears without combat side effects")
	indicators.free()

func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(label)
