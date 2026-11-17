extends SceneTree
## E12 H3 — HUD visual components (contract docs/epics/e12_contract.md §4):
## CastBar, ActorCastBar, KitResourcePanel, KitWorldOverlay and the shared HudPalette.
## Covers: fixture DTOs of every kind (pips, infinity, charges, timer), cone and circle in
## both spaces, marks with 0 and 5 pips, cast progress at 0 / 50 / 100 %, cancel and release
## flashes, and malformed DTOs (nothing drawn, no SCRIPT ERROR). Components are
## presentation only: no rule, clock or save is touched.
## With a real renderer and one user argument (`-- <directory>`), also saves the native
## captures docs/epics/e12/h3_*.png into that directory.
const FixtureHudKit = preload("res://scripts/classes/fixture/hud/fixture_hud_kit.gd")

var checks := 0
var failures := 0
var _kit: FixtureHudKit

func _initialize() -> void:
	_run.call_deferred()

func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("FAIL: " + label)

func _close(a: float, b: float, label: String) -> void:
	_check(absf(a - b) <= 0.0001, "%s (%s vs %s)" % [label, a, b])

func _run() -> void:
	_kit = FixtureHudKit.new(&"sp_ac")
	var dto := _kit.valid_state(null)
	_check(KitHudState.validate(dto, _kit)["ok"], "the fixture DTO is valid for the format")
	_check_palette()
	_check_progress_reading()
	_check_cast_bar()
	_check_actor_cast_bar()
	_check_panel(dto)
	_check_overlay(dto)
	_check_malformed()
	await _check_drawing(dto)
	print("E12 HUD components: %d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)

# --- Helpers -----------------------------------------------------------------------------

func _progress(remaining: float, total: float = 2.0, label: String = "Juízo") -> Dictionary:
	return {"active": true, "skill_id": &"fixture", "label": label, "total": total, "remaining": remaining, "kind": &"cast", "category": &"player"}

func _kit_dto(variant: StringName) -> Dictionary:
	var kit := FixtureHudKit.new(&"sp_ac")
	kit.hud_variant = variant
	return kit.hud_state(null)

func _actor_at(position: Vector2) -> CombatActor:
	var actor := CombatActor.new()
	actor.position = position
	root.add_child(actor)
	return actor

# --- Palette and cast reading --------------------------------------------------------------

func _check_palette() -> void:
	for element: StringName in KitHudState.ELEMENTS:
		_check(HudPalette.ELEMENT_COLORS.has(element if element != &"" else &"none"), "palette has the element '%s'" % element)
	_check(HudPalette.element_color(&"") == HudPalette.element_color(&"none"), "empty element is none")
	_check(HudPalette.element_color(&"unknown") == HudPalette.NEUTRAL and HudPalette.element_color(7) == HudPalette.NEUTRAL, "unknown element falls back to neutral")
	var colors := {}
	for key: StringName in HudPalette.ELEMENT_COLORS: colors[HudPalette.ELEMENT_COLORS[key]] = true
	_check(colors.size() == HudPalette.ELEMENT_COLORS.size(), "each element has its own color")

func _check_progress_reading() -> void:
	_check(HudPalette.read_cast({"active": false}).is_empty(), "inactive progress reads as nothing")
	_check(HudPalette.read_cast(_progress(1.0)).get("ratio") == 0.5, "ratio is 1 - remaining / total")
	var actor_idle := CombatActor.new()
	_check(HudPalette.read_cast(actor_idle.cast_progress()).is_empty(), "a CombatActor without cast reads as nothing")
	actor_idle.free()
	for bad: Variant in [null, 3, "x", [], {}, {"active": true}, _progress(3.0), _progress(-0.5), _progress(1.0, 0.0), _progress(NAN), _progress(1.0, INF), {"active": true, "total": "2", "remaining": 1.0}, {"active": true, "total": 2.0, "remaining": 1.0, "label": 5}]:
		_check(HudPalette.read_cast(bad).is_empty(), "malformed progress reads as nothing: %s" % [bad])

# --- CastBar -------------------------------------------------------------------------------

func _check_cast_bar() -> void:
	var bar := CastBar.new()
	_check(not bar.visible, "a new cast bar is hidden")
	for case: Array in [[2.0, 0.0, "2.0s"], [1.0, 0.5, "1.0s"], [0.0, 1.0, "0.0s"]]:
		bar.set_progress(_progress(case[0]))
		var plan := bar.plan()
		_check(bar.visible, "bar visible with a cast at %s" % case[1])
		_close(float(plan["ratio"]), case[1], "fill ratio at remaining %s" % case[0])
		_check(plan["time_text"] == case[2] and plan["label"] == "Juízo", "name and time text at remaining %s" % case[0])
		_check(plan["color"] == HudPalette.CAST_FILL, "normal fill color")
	bar.set_progress(_progress(0.0))
	var outline_color: Color = bar.plan()["outline_color"]
	_check(int(bar.plan()["outline_size"]) >= 5 and outline_color.a >= 0.95 and outline_color.get_luminance() < 0.1, "C-H3.1: cast bar text has a dark outline (size >= 5) over any fill")
	var source := FileAccess.get_file_as_string("res://scripts/ui/hud/cast_bar.gd")
	_check(source.count("draw_string(") == source.count("draw_string_outline(") and source.count("HudPalette.TEXT_OUTLINE_SIZE") >= 2, "C-H3.1: every cast bar text draw has an outline draw")
	var actor_source := FileAccess.get_file_as_string("res://scripts/presentation/actor_cast_bar.gd")
	_check(actor_source.count("draw_string(") == actor_source.count("draw_string_outline(") and ActorCastBar.plan_overhead(_progress(1.0), -60.0, 52.0, &"", true)["outline_size"] == HudPalette.TEXT_OUTLINE_SIZE, "C-H3.1: overhead label has the same outline")
	bar.set_progress({"active": false})
	_check(not bar.visible and bar.plan().is_empty(), "{active: false} hides the bar")
	bar.set_progress(_progress(1.2))
	bar.set_progress(null)
	_check(not bar.visible, "malformed progress hides the bar")
	# Cancel: the reading goes inactive at once; the flash keeps the last bar for a moment.
	bar.set_progress(_progress(0.5, 2.0))
	bar.set_progress({"active": false})
	bar.flash(&"cancel")
	_check(bar.visible and bar.is_flashing(), "cancel flash keeps the bar visible")
	_check(bar.plan()["color"] == HudPalette.CAST_CANCEL and absf(float(bar.plan()["ratio"]) - 0.75) < 0.0001, "cancel flash keeps the last ratio in the cancel color")
	bar._process(HudPalette.FLASH_SECONDS + 0.01)
	_check(not bar.visible and not bar.is_flashing(), "the flash ends and the bar hides")
	# Release: the bar fills in the release color.
	bar.set_progress(_progress(0.1))
	bar.set_progress({"active": false})
	bar.flash(&"release")
	_check(bar.plan()["color"] == HudPalette.CAST_RELEASE and float(bar.plan()["ratio"]) == 1.0, "release flash fills the bar in the release color")
	bar._process(1.0)
	bar.flash(&"bogus")
	bar.flash(&"")
	_check(not bar.is_flashing(), "unknown flash kinds are ignored")
	var fresh := CastBar.new()
	fresh.flash(&"cancel")
	_check(not fresh.visible, "a flash without any previous cast shows nothing")
	fresh.free()
	bar.free()

# --- ActorCastBar --------------------------------------------------------------------------

func _check_actor_cast_bar() -> void:
	var bar := CastBar.new()
	for remaining: float in [2.0, 1.0, 0.0]:
		var progress := _progress(remaining)
		bar.set_progress(progress)
		var plan := ActorCastBar.plan_overhead(progress, -60.0, 52.0)
		_close(float(plan["ratio"]), float(bar.plan()["ratio"]), "overhead ratio equals CastBar at remaining %s" % remaining)
		_check(plan["color"] == bar.plan()["color"], "overhead color equals CastBar")
		_close((plan["fill"] as Rect2).size.x, 52.0 * float(plan["ratio"]), "fill width follows the ratio")
		_close((plan["back"] as Rect2).position.y, -60.0, "bar starts at top_y")
		_check(plan["label"] == "", "no label unless show_label")
	bar.free()
	_check(ActorCastBar.plan_overhead(_progress(1.0), -60.0, 52.0, &"", true)["label"] == "Juízo", "show_label includes the skill name")
	_check(ActorCastBar.plan_overhead({"active": false}, -60.0, 52.0).is_empty(), "inactive draws nothing")
	_check(ActorCastBar.plan_overhead(_progress(1.0), -60.0, 0.0).is_empty() and ActorCastBar.plan_overhead(_progress(1.0), NAN, 52.0).is_empty(), "bad geometry draws nothing")
	_check(ActorCastBar.plan_overhead(null, -60.0, 52.0).is_empty() and ActorCastBar.plan_overhead(_progress(9.0), -60.0, 52.0).is_empty(), "malformed progress draws nothing")
	_check(ActorCastBar.plan_overhead(_progress(1.0), -60.0, 52.0, &"cancel")["color"] == HudPalette.CAST_CANCEL, "cancel flash color")
	_check(ActorCastBar.plan_overhead({"active": false}, -60.0, 52.0, &"release")["ratio"] == 1.0, "release flash without progress draws a full bar")
	ActorCastBar.draw_overhead(null, _progress(1.0), -60.0, 52.0)
	_check(true, "draw_overhead with a null canvas returns")

# --- KitResourcePanel ----------------------------------------------------------------------

func _check_panel(dto: Dictionary) -> void:
	var panel := KitResourcePanel.new()
	_check(not panel.visible, "a new panel is hidden")
	panel.set_state(dto)
	var rows := panel.plan()
	_check(panel.visible and rows.size() == 4, "the fixture DTO draws its four resources")
	_check(rows[0]["kind"] == &"pips" and rows[0]["value"] == 3 and rows[0]["max"] == 5 and not rows[0]["unlimited"] and rows[0]["time_text"] == "", "pips: 3 of 5, no deadline")
	_check(rows[1]["kind"] == &"pips" and rows[1]["unlimited"] and rows[1]["time_text"] == "4.5s" and absf(float(rows[1]["ratio"]) - 4.5 / 8.0) < 0.0001, "unlimited pips: infinity with the mode deadline")
	_check(rows[2]["kind"] == &"charges" and rows[2]["value"] == 1 and rows[2]["max"] == 2 and rows[2]["time_text"] == "2.5s", "charges: 1 of 2 with the recharge")
	_check(rows[3]["kind"] == &"timer" and rows[3]["time_text"] == "3.0s" and absf(float(rows[3]["ratio"]) - 0.3) < 0.0001, "timer: remaining and bar")
	_check(rows[0]["color"] == HudPalette.element_color(&"light") and rows[3]["color"] == HudPalette.NEUTRAL, "row colors come from the shared palette")
	_close(panel.custom_minimum_size.y, KitResourcePanel.PADDING * 2.0 + KitResourcePanel.ROW_HEIGHT * 4.0, "panel height follows the rows")
	# Charges full: no recharge text. Pips at 0 and at max.
	var full := _dto_with([
		{"id": &"paladin_grace", "label": "Graça", "kind": &"pips", "value": 0, "max": 5},
		{"id": &"paladin_grace_full", "label": "Graça", "kind": &"pips", "value": 5, "max": 5, "element": &"light"},
		{"id": &"arcane_blade_refraction", "label": "Refração", "kind": &"charges", "value": 2, "max": 2, "remaining": 1.0, "total": 6.0},
	])
	panel.set_state(full)
	_check(panel.plan().size() == 3 and panel.plan()[0]["value"] == 0 and panel.plan()[1]["value"] == 5 and panel.plan()[2]["time_text"] == "", "pips at 0 and 5; full charges show no recharge")
	panel.set_state({})
	_check(not panel.visible and panel.plan().is_empty(), "{} hides the panel")
	panel.set_state(_kit_dto(FixtureHudKit.EMPTY))
	_check(not panel.visible, "a kit without HUD hides the panel")
	var only_marks := _dto_with([])
	panel.set_state(only_marks)
	_check(not panel.visible, "no resources hides the panel")
	panel.free()

func _dto_with(resources: Array) -> Dictionary:
	return {"schema": KitHudState.SCHEMA, "kit_id": &"sp_ac", "resources": resources}

# --- KitWorldOverlay -----------------------------------------------------------------------

func _check_overlay(dto: Dictionary) -> void:
	var ground := KitWorldOverlay.new()
	ground.mode = KitWorldOverlay.MODE_GROUND
	ground.set_state(dto, {})
	var zones := ground.plan()
	_check(zones.size() == 3, "the fixture DTO draws its three zones")
	# Zone 0: world cone, center (120,0,80), facing +x, half angle PI/4, radius 160.
	var cone: Dictionary = zones[0]
	var cone_polygon: PackedVector2Array = cone["polygon"]
	var center := Vector3(120.0, 0.0, 80.0)
	_check(cone["space"] == &"world" and cone["shape"] == &"cone", "zone 0 is the world cone")
	_check(cone_polygon.size() == KitWorldOverlay.CONE_SEGMENTS + 2, "cone polygon: apex plus the arc")
	_check(cone_polygon[0].is_equal_approx(KitWorldOverlay.ProjectionMath.project(center)), "cone apex is the projected center")
	var first := center + Vector3(cos(-PI / 4.0), 0.0, sin(-PI / 4.0)) * 160.0
	var last := center + Vector3(cos(PI / 4.0), 0.0, sin(PI / 4.0)) * 160.0
	_check(cone_polygon[1].is_equal_approx(KitWorldOverlay.ProjectionMath.project(first)) and cone_polygon[cone_polygon.size() - 1].is_equal_approx(KitWorldOverlay.ProjectionMath.project(last)), "cone arc ends are projected point by point")
	_check(cone["color"] == HudPalette.element_color(&"fire"), "cone uses the element color")
	_close(float(cone["ratio"]), 5.0 / 9.0, "zone ratio is remaining / total")
	# Zone 1: flat circle in arena coordinates.
	var circle: Dictionary = zones[1]
	var flat_ok: bool = circle["space"] == &"flat" and circle["shape"] == &"circle" and (circle["polygon"] as PackedVector2Array).size() == KitWorldOverlay.CIRCLE_SEGMENTS
	for point: Vector2 in circle["polygon"]:
		flat_ok = flat_ok and absf(point.distance_to(Vector2(400.0, 350.0)) - 120.0) < 0.001
	_check(flat_ok, "flat circle: arena coordinates, no projection")
	_check(circle["color"] == HudPalette.element_color(&"ice"), "circle uses the element color")
	# Zone 2: world wide circle without deadline.
	_check(zones[2]["shape"] == &"wide_circle" and float(zones[2]["ratio"]) == 1.0 and zones[2]["color"] == HudPalette.element_color(&"tricolor"), "wide circle without deadline, tricolor")
	var ring: PackedVector2Array = zones[2]["polygon"]
	_check(ring.size() == KitWorldOverlay.CIRCLE_SEGMENTS and ring[0].is_equal_approx(KitWorldOverlay.ProjectionMath.project(Vector3(220.0, 0.0, 0.0))), "wide circle is a projected ring")
	# Flat cone, facing +y of the canvas.
	var flat_cone := {"schema": KitHudState.SCHEMA, "kit_id": &"sp_ac", "zones": [{"role": &"x", "space": &"flat", "center": Vector3(100.0, 100.0, 0.0), "shape": &"cone", "radius": 50.0, "half_angle": PI / 6.0, "facing": Vector3(0.0, 1.0, 0.0), "element": &"light"}]}
	ground.set_state(flat_cone, {})
	var flat_polygon: PackedVector2Array = ground.plan()[0]["polygon"]
	_check(flat_polygon[0] == Vector2(100.0, 100.0) and flat_polygon[1].is_equal_approx(Vector2(100.0, 100.0) + Vector2.from_angle(PI / 2.0 - PI / 6.0) * 50.0), "flat cone follows the canvas facing")
	var overhead := KitWorldOverlay.new()
	overhead.mode = KitWorldOverlay.MODE_OVERHEAD
	overhead.set_state(dto, {})
	_check(overhead.plan().is_empty() and ground.plan().size() == 1, "each mode plans only its own section")
	# Marks.
	var actor := _actor_at(Vector2(300.0, 200.0))
	var other := _actor_at(Vector2(500.0, 220.0))
	root.add_child(overhead)
	var id := actor.get_instance_id()
	var marks := {"schema": KitHudState.SCHEMA, "kit_id": &"sp_la", "target_marks": [
		{"target_id": id, "key": &"flank_victim", "kind": &"pips", "value": 0, "max": 5, "element": &"arcane"},
		{"target_id": other.get_instance_id(), "key": &"flank_victim", "kind": &"pips", "value": 5, "max": 5, "element": &"arcane"},
		{"target_id": id, "key": &"paladin_seal", "kind": &"badge", "element": &"light"},
		{"target_id": 987654321, "key": &"flank_victim", "kind": &"pips", "value": 2, "max": 5},
	]}
	overhead.set_state(marks, {id: actor, other.get_instance_id(): other})
	var plan := overhead.plan()
	_check(plan.size() == 3, "marks: three drawn, the unknown target id ignored")
	_check(plan[0]["value"] == 0 and plan[0]["max"] == 5 and plan[1]["value"] == 5 and plan[1]["max"] == 5, "marks with 0 and 5 pips")
	_check((plan[0]["position"] as Vector2).is_equal_approx(actor.position + Vector2(0.0, actor.overhead_bar_y() - KitWorldOverlay.MARK_GAP)), "first mark sits above overhead_bar_y")
	_check((plan[2]["position"] as Vector2).is_equal_approx(actor.position + Vector2(0.0, actor.overhead_bar_y() - KitWorldOverlay.MARK_GAP - KitWorldOverlay.MARK_STACK)), "second mark on the same target stacks upward")
	_check(plan[2]["kind"] == &"badge" and plan[2]["color"] == HudPalette.element_color(&"light"), "badge uses the palette")
	var gone := _actor_at(Vector2.ZERO)
	var gone_id := gone.get_instance_id()
	gone.free()
	overhead.set_state({"schema": KitHudState.SCHEMA, "kit_id": &"sp_la", "target_marks": [{"target_id": gone_id, "key": &"flank_victim", "kind": &"pips", "value": 1, "max": 5}]}, {gone_id: gone})
	_check(overhead.plan().is_empty(), "a freed actor in the map is ignored")
	overhead.set_state({}, {})
	_check(overhead.plan().is_empty(), "{} clears the overlay")
	# Same palette in the panel and the overlay.
	_check(HudPalette.element_color(&"arcane") == KitResourcePanel.rows_for(_dto_with([{"id": &"arcane_blade_x", "label": "X", "kind": &"timer", "remaining": 1.0, "total": 2.0, "element": &"arcane"}]))[0]["color"], "panel and overlay share the element palette")
	root.remove_child(overhead)
	overhead.free()
	ground.free()
	actor.free()
	other.free()

# --- Malformed DTOs ------------------------------------------------------------------------

func _check_malformed() -> void:
	var panel := KitResourcePanel.new()
	var ground := KitWorldOverlay.new()
	var overhead := KitWorldOverlay.new()
	overhead.mode = KitWorldOverlay.MODE_OVERHEAD
	var actor := _actor_at(Vector2(10.0, 10.0))
	var actors := {actor.get_instance_id(): actor, 1: actor}
	var panel_blank: Array[StringName] = [KitHudState.INVALID_SCHEMA, KitHudState.UNKNOWN_KEY, KitHudState.INVALID_RESOURCE, KitHudState.DUPLICATE_RESOURCE, KitHudState.NON_FINITE]
	var ground_blank: Array[StringName] = [KitHudState.INVALID_SCHEMA, KitHudState.UNKNOWN_KEY, KitHudState.INVALID_ZONE]
	var overhead_blank: Array[StringName] = [KitHudState.INVALID_SCHEMA, KitHudState.UNKNOWN_KEY, KitHudState.INVALID_MARK]
	for variant: StringName in FixtureHudKit.variants():
		if variant == FixtureHudKit.EMPTY or variant == FixtureHudKit.VALID: continue
		var dto := _kit_dto(variant)
		panel.set_state(dto)
		ground.set_state(dto, actors)
		overhead.set_state(dto, actors)
		_check(panel.plan().is_empty() == (variant in panel_blank), "panel with variant %s" % variant)
		_check(ground.plan().is_empty() == (variant in ground_blank), "ground overlay with variant %s" % variant)
		_check(overhead.plan().is_empty() == (variant in overhead_blank), "overhead overlay with variant %s" % variant)
	var garbage: Array = [null, 7, "text", [], [1], {"schema": 4}, {"schema": KitHudState.SCHEMA, "resources": "x", "zones": 3, "target_marks": {}}, {"schema": KitHudState.SCHEMA, "resources": [3]}]
	for bad: Variant in garbage:
		panel.set_state(bad)
		ground.set_state(bad, actors)
		overhead.set_state(bad, actors)
		_check(not panel.visible and panel.plan().is_empty() and ground.plan().is_empty() and overhead.plan().is_empty(), "garbage state draws nothing: %s" % [bad])
	ground.set_state({"schema": KitHudState.SCHEMA}, "not a dictionary")
	_check(ground.plan().is_empty(), "no zones, bad actor map")
	var zone := {"role": &"x", "space": &"world", "center": Vector3.ZERO, "shape": &"circle", "radius": 10.0}
	var bad_zones: Array = [
		{"space": &"sky"}, zone.merged({"center": Vector3(NAN, 0.0, 0.0)}, true), zone.merged({"radius": -1.0}, true), zone.merged({"shape": &"cone"}, true),
		zone.merged({"shape": &"cone", "half_angle": 0.5, "facing": Vector3.ZERO}, true), zone.merged({"element": &"plasma"}, true), zone.merged({"remaining": 5.0, "total": 2.0}, true),
		zone.merged({"remaining": 1.0}, true), zone.merged({"space": "world"}, true), 5,
	]
	for bad_zone: Variant in bad_zones:
		ground.set_state({"schema": KitHudState.SCHEMA, "zones": [bad_zone]}, {})
		_check(ground.plan().is_empty(), "malformed zone draws nothing: %s" % [bad_zone])
	var bad_marks: Array = [
		{"target_id": 5, "key": &"k", "kind": &"pips", "value": 6, "max": 5}, {"target_id": 5, "key": &"k", "kind": &"pips"}, {"target_id": "5", "key": &"k", "kind": &"badge"},
		{"target_id": 5, "key": &"k", "kind": &"ring"}, {"target_id": 5, "key": &"k", "kind": &"badge", "element": &"plasma"}, 7,
	]
	for bad_mark: Variant in bad_marks:
		overhead.set_state({"schema": KitHudState.SCHEMA, "target_marks": [bad_mark]}, actors)
		_check(overhead.plan().is_empty(), "malformed mark draws nothing: %s" % [bad_mark])
	panel.set_state(_dto_with([{"id": &"paladin_grace", "label": "", "kind": &"pips", "value": 1, "max": 5}]))
	_check(not panel.visible, "empty label hides the panel")
	panel.set_state(_dto_with([{"id": &"paladin_grace", "label": "Graça", "kind": &"timer", "remaining": 3.0, "total": 2.0}]))
	_check(not panel.visible, "remaining above total hides the panel")
	panel.set_state(_dto_with([{"id": &"paladin_grace", "label": "Graça", "kind": &"pips", "value": 1.5, "max": 5}]))
	_check(not panel.visible, "float pip count hides the panel")
	panel.set_state(_dto_with([{"id": &"paladin_grace", "label": "Graça", "kind": &"pips", "value": 1, "max": 5, "unlimited": true}]))
	_check(not panel.visible, "unlimited without deadline hides the panel")
	panel.free()
	ground.free()
	overhead.free()
	actor.free()

# --- Real drawing ------------------------------------------------------------------------------

class CastProbe extends Node2D:
	var progress: Variant = {}
	var flash: StringName = &""
	var label := false
	var top := -40.0
	var calls := 0
	func _draw() -> void:
		calls += 1
		ActorCastBar.draw_overhead(self, progress, top, 52.0, flash, label)

func _check_drawing(dto: Dictionary) -> void:
	var headless := DisplayServer.get_name() == "headless"
	var holder := Control.new()
	holder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(holder)
	var bar := CastBar.new()
	holder.add_child(bar)
	var panel := KitResourcePanel.new()
	holder.add_child(panel)
	var ground := KitWorldOverlay.new()
	var overhead := KitWorldOverlay.new()
	overhead.mode = KitWorldOverlay.MODE_OVERHEAD
	root.add_child(ground)
	root.add_child(overhead)
	var probe := CastProbe.new()
	root.add_child(probe)
	var actor := _actor_at(Vector2(300.0, 200.0))
	var marks := dto.duplicate(true)
	for mark: Dictionary in marks["target_marks"]: mark["target_id"] = actor.get_instance_id()
	bar.set_progress(_progress(1.0))
	panel.set_state(dto)
	ground.set_state(dto, {})
	overhead.set_state(marks, {actor.get_instance_id(): actor})
	probe.progress = _progress(1.0)
	probe.label = true
	probe.queue_redraw()
	for frame: int in 3: await process_frame
	if not headless:
		_check(bar.draw_count > 0 and panel.draw_count > 0 and ground.draw_count > 0 and overhead.draw_count > 0 and probe.calls > 0, "the four components draw with a real renderer")
	# Malformed input while drawing: still no error.
	bar.set_progress("broken")
	panel.set_state({"schema": "bad"})
	ground.set_state({"zones": 3}, {})
	overhead.set_state(null, {})
	probe.progress = "broken"
	probe.flash = &"cancel"
	probe.queue_redraw()
	for frame: int in 3: await process_frame
	_check(not bar.visible and not panel.visible, "malformed state after drawing hides the components")
	var args := OS.get_cmdline_user_args()
	if not headless and args.size() == 1:
		await _capture(String(args[0]))
	for node: Node in [holder, ground, overhead, probe, actor]: node.queue_free()
	await process_frame

# --- Native captures (docs/epics/e12/h3_*.png) ------------------------------------------------

func _frame_image(path: String, region: Rect2i) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image().get_region(region)
	_check(not image.is_empty() and image.save_png(path) == OK, "native capture " + path.get_file())

func _backdrop(size: Vector2) -> ColorRect:
	var back := ColorRect.new()
	back.color = Color("1d2a2f")
	back.size = size
	root.add_child(back)
	return back

func _caption(parent: Node, text: String, position: Vector2) -> void:
	var label := Label.new()
	label.text = text
	label.position = position
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", HudPalette.TEXT_DIM)
	parent.add_child(label)

func _capture(directory: String) -> void:
	DirAccess.make_dir_recursive_absolute(directory)
	await process_frame
	var size := Vector2(DisplayServer.window_get_size())
	# Player cast bar: 0 %, 50 %, 100 %, cancel, release.
	var back := _backdrop(size)
	var y := 20.0
	var bars: Array[CastBar] = []
	var captions := ["0 % (início do preparo)", "50 %", "100 % (fim do preparo)", "cancelado (flash)", "liberado (flash)"]
	for index: int in 5:
		var bar := CastBar.new()
		bar.position = Vector2(24.0, y + 18.0)
		bar.size = CastBar.BAR_SIZE
		back.add_child(bar)
		_caption(back, captions[index], Vector2(24.0, y))
		if index < 3:
			bar.set_progress(_progress([2.0, 1.0, 0.0][index], 2.0, "Juízo Solar"))
		else:
			bar.set_progress(_progress(0.6, 2.0, "Juízo Solar"))
			bar.set_progress({"active": false})
			bar.flash(&"cancel" if index == 3 else &"release")
			bar.set_process(false)
		bars.append(bar)
		y += 56.0
	await _frame_image(directory.path_join("h3_cast_bar_player.png"), Rect2i(0, 0, 420, int(y)))
	back.queue_free()
	# Enemy and actor cast bars, under the HP bar.
	back = _backdrop(size)
	var specs := [[2.0, &"", false, "0 %"], [1.0, &"", true, "50 % com nome (elite)"], [0.0, &"", false, "100 %"], [0.5, &"cancel", false, "cancelado"], [0.5, &"release", false, "liberado"]]
	var probes: Array[CastProbe] = []
	for index: int in specs.size():
		var holder := Node2D.new()
		holder.position = Vector2(90.0 + index * 150.0, 140.0)
		back.add_child(holder)
		var actor := CombatActor.new()
		actor.setup("Alvo", Color("8a6a9a"), StatBreakdown.new())
		holder.add_child(actor)
		var cast := CastProbe.new()
		cast.progress = _progress(specs[index][0], 2.0, "Chama Negra") if specs[index][1] != &"release" else {"active": false}
		cast.flash = specs[index][1]
		cast.label = specs[index][2]
		cast.top = actor.overhead_bar_y() + 6.0 + 3.0
		holder.add_child(cast)
		_caption(back, specs[index][3], Vector2(30.0 + index * 150.0, 160.0))
		probes.append(cast)
	await _frame_image(directory.path_join("h3_actor_cast_bar.png"), Rect2i(0, 0, 780, 200).intersection(Rect2i(Vector2i.ZERO, DisplayServer.window_get_size())))
	back.queue_free()
	# Resource panel with the fixture DTO, plus a second panel with pips at 0 and 5.
	back = _backdrop(size)
	var panel := KitResourcePanel.new()
	panel.position = Vector2(24.0, 24.0)
	back.add_child(panel)
	panel.set_state(_kit.valid_state(null))
	var edge := KitResourcePanel.new()
	edge.position = Vector2(300.0, 24.0)
	back.add_child(edge)
	edge.set_state(_dto_with([
		{"id": &"paladin_grace", "label": "Graça", "kind": &"pips", "value": 0, "max": 5, "element": &"light"},
		{"id": &"thaumaturge_grace", "label": "Graça", "kind": &"pips", "value": 5, "max": 5, "element": &"tricolor"},
		{"id": &"arcane_blade_refraction", "label": "Refração", "kind": &"charges", "value": 0, "max": 2, "remaining": 4.2, "total": 6.0, "element": &"arcane"},
		{"id": &"flank_duel", "label": "Duelo", "kind": &"timer", "remaining": 9.0, "total": 10.0},
	]))
	await _frame_image(directory.path_join("h3_resource_panel.png"), Rect2i(0, 0, 560, 140))
	back.queue_free()
	# Overlays: flat arena and expedition world, with marks.
	await _capture_overlay(directory.path_join("h3_world_overlay_flat.png"), true)
	await _capture_overlay(directory.path_join("h3_world_overlay_world.png"), false)

func _capture_overlay(path: String, flat: bool) -> void:
	var back := _backdrop(Vector2(DisplayServer.window_get_size()))
	var ground := KitWorldOverlay.new()
	var overhead := KitWorldOverlay.new()
	overhead.mode = KitWorldOverlay.MODE_OVERHEAD
	back.add_child(ground)
	var actor_a := CombatActor.new()
	var actor_b := CombatActor.new()
	actor_a.setup("Vítima", Color("8a6a9a"), StatBreakdown.new())
	actor_b.setup("Alvo", Color("6a8a9a"), StatBreakdown.new())
	back.add_child(actor_a)
	back.add_child(actor_b)
	back.add_child(overhead)
	var zones: Array = []
	if flat:
		actor_a.position = Vector2(300.0, 360.0)
		actor_b.position = Vector2(700.0, 360.0)
		zones = [
			{"role": &"c", "space": &"flat", "center": Vector3(300.0, 360.0, 0.0), "shape": &"cone", "radius": 190.0, "half_angle": PI / 4.0, "facing": Vector3(1.0, 0.0, 0.0), "element": &"fire", "remaining": 6.0, "total": 9.0},
			{"role": &"o", "space": &"flat", "center": Vector3(700.0, 360.0, 0.0), "shape": &"circle", "radius": 130.0, "element": &"ice", "remaining": 3.0, "total": 9.0},
			{"role": &"h", "space": &"flat", "center": Vector3(500.0, 540.0, 0.0), "shape": &"wide_circle", "radius": 70.0, "element": &"tricolor"},
		]
	else:
		var origin := Vector2(500.0, 120.0)
		ground.position = origin
		overhead.position = origin
		var a := Vector3(120.0, 0.0, 80.0)
		var b := Vector3(280.0, 0.0, 20.0)
		actor_a.position = origin + KitWorldOverlay.ProjectionMath.project(a)
		actor_b.position = origin + KitWorldOverlay.ProjectionMath.project(b)
		zones = [
			{"role": &"c", "space": &"world", "center": a, "shape": &"cone", "radius": 170.0, "half_angle": PI / 4.0, "facing": Vector3(1.0, 0.0, 0.0), "element": &"fire", "remaining": 6.0, "total": 9.0},
			{"role": &"o", "space": &"world", "center": b, "shape": &"circle", "radius": 120.0, "element": &"lightning", "remaining": 3.0, "total": 9.0},
			{"role": &"h", "space": &"world", "center": Vector3(200.0, 0.0, 240.0), "shape": &"wide_circle", "radius": 90.0, "element": &"light"},
		]
	var state := {"schema": KitHudState.SCHEMA, "kit_id": &"sp_la", "zones": zones, "target_marks": [
		{"target_id": actor_a.get_instance_id(), "key": &"flank_victim", "kind": &"pips", "value": 5, "max": 5, "element": &"arcane"},
		{"target_id": actor_a.get_instance_id(), "key": &"paladin_seal", "kind": &"badge", "element": &"light"},
		{"target_id": actor_b.get_instance_id(), "key": &"flank_victim", "kind": &"pips", "value": 0, "max": 5, "element": &"arcane"},
	]}
	ground.set_state(state, {})
	overhead.set_state(state, {actor_a.get_instance_id(): actor_a, actor_b.get_instance_id(): actor_b})
	_caption(back, "Espaço %s: cone, círculo e círculo ampliado; Sentença 5/5 com selo, e 0/5" % ("plano" if flat else "do mundo"), Vector2(20.0, 8.0))
	await process_frame
	await _frame_image(path, Rect2i(Vector2i.ZERO, DisplayServer.window_get_size()))
	back.queue_free()
