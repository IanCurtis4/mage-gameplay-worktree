extends "res://scripts/presentation/e08_pilot_feedback.gd"
## E08 P6-A2: feedback by recipe. Evolves the pilot pulse layer: same contract (Control child of
## the bridge, fed only by event_confirmed + world_advanced, CAP, cleared on stage change, inactive
## when passive/paused, hidden for occluded anchors, idempotent dispose) but every confirmed event is
## drawn from its FeedbackRecipeCatalog recipe (family x element, signatures). Signatures use the B1
## flipbooks (VfxFlipbookCatalog) and fall back to a code-drawn version when a flipbook is missing.
## Presentation only: no gameplay reads, no RNG, no wall clock; visuals are a pure function of the
## event (event_id seeds the jitter) and the bridge visual clock.
##
## Caps: CAP = 48 live pulses (inherited); impact flood = at most IMPACT_PER_WINDOW impacts per skill
## per IMPACT_WINDOW seconds, one per skill+target per TARGET_GAP (PERIODIC_GAP for DOT recipes);
## flood memory <= FLOOD_MEMORY keys, cleared on stage change. Lifetimes are 0.2 to 1.0 s, except flipbook
## signatures, which play at the manifest suggested_fps (P7-C1: speed factor 1.0 unless SIGNATURE_ART says otherwise,
## never above 1.15), so their life is frames / (fps x speed): 1.0 s (16 fps sheets) to 1.6 s (10 fps sheets).
## Ordering: absolute z_index 4080 in the spatial world (below the view's marker/route/objective/geometer
## layer at 4090 and below every CanvasLayer UI), 10 in the flat arena (below damage numbers, z 20).
const Recipes = preload("res://scripts/presentation/feedback_recipe_catalog.gd")
const Palette = preload("res://scripts/presentation/world_projectile_art.gd")
const IMPACT_WINDOW := 0.06
const IMPACT_PER_WINDOW := 3
const TARGET_GAP := 0.10
const PERIODIC_GAP := 0.40
const FLOOD_MEMORY := 256
const Z_SPATIAL := 4080
const Z_FLAT := 10
const HALO := Color(0.04, 0.05, 0.09, 0.4)
## P7-C5: white hit burst of basic attacks (every class): life in seconds, dark hairline edge, rays and slash.
const BASIC_HIT_LIFE := 0.18
const BASIC_EDGE := Color(0.04, 0.05, 0.09, 0.9)
const BASIC_RAYS := 6
const DRAWN_KINDS: Array[StringName] = [&"cast_start", &"cast_cancel", &"projectile_launch", &"impact", &"area_start", &"area_end", &"teleport", &"death", &"revive",
	&"melee_swing", &"movement", &"effect_start", &"heal", &"summon", &"charge_start", &"trap_trigger"]
## Ground circle -> screen ellipse (world projection / flat arena).
const GROUND_WORLD := Vector2(1.202, 0.601)
const GROUND_FLAT := Vector2(1.0, 0.55)
## signature -> [flipbook id, desired world diameter (px), speed factor on the manifest suggested_fps (1.0 = as authored; max 1.15), tint, forward offset (px)].
## Signatures not listed (or whose flipbook is missing) use the code-drawn version.
const SIGNATURE_ART := {
	&"mage_fireball": [&"fire_burst", 74.0, 1.0, Color.WHITE, 0.0],
	&"mage_teleport": [&"arcane_warp", 84.0, 1.0, Color.WHITE, 0.0],
	&"swordsman_slash": [&"slash_arc", 82.0, 1.0, Color.WHITE, 26.0],
	&"swordsman_terrifying_shout": [&"ground_shockwave", 120.0, 1.0, Color.WHITE, 0.0],
	&"archer_explosive_trap": [&"fire_burst", 96.0, 1.0, Color.WHITE, 0.0],
	&"defender_reprisal_wave": [&"ground_shockwave", 132.0, 1.0, Color(0.85, 0.92, 1.0), 0.0],
	&"defender_counterstroke": [&"shield_bash", 82.0, 1.0, Color.WHITE, 26.0],
	&"berserker_blood_rift": [&"blood_rift", 104.0, 1.0, Color.WHITE, 22.0],
	&"elementalist_lightning_arc": [&"lightning_burst", 60.0, 1.0, Color.WHITE, 0.0],
	&"geometer_collapse": [&"geometer_collapse", 116.0, 1.0, Color.WHITE, 0.0],
	&"sentinel_explosive_shot": [&"fire_burst", 72.0, 1.0, Color.WHITE, 0.0],
	&"hunter_freezing_trap": [&"ice_shatter", 92.0, 1.0, Color.WHITE, 0.0],
	&"warden_summon": [&"summon_portal", 96.0, 1.0, Color.WHITE, 0.0],
	# Second Codex batch (14/11): the eight signatures that were code-drawn only.
	&"archer_arrow_rain": [&"arrow_rain", 120.0, 1.0, Color.WHITE, 0.0],
	&"berserker_wound_leap": [&"wound_leap", 96.0, 1.0, Color.WHITE, 30.0],
	&"elementalist_tri_nova": [&"tri_nova", 140.0, 1.0, Color.WHITE, 0.0],
	&"spiritualist_dissipation": [&"spirit_dissipation", 230.0, 1.0, Color.WHITE, 0.0], # Drawn on the placed point; ~ the 100 radius on screen.
	&"geometer_triangulation": [&"triangulation", 96.0, 1.0, Color.WHITE, 0.0],
	&"sentinel_headshot": [&"headshot", 70.0, 1.0, Color.WHITE, 24.0],
	&"hunter_covering_shot": [&"covering_shot", 70.0, 1.0, Color.WHITE, -18.0], # Plays on the hit (SIGNATURE_ART_ON_IMPACT): arrow tip on the target.
	&"warden_charge": [&"warden_charge", 110.0, 1.0, Color.WHITE, 0.0],
}
## Sheets painted pointing right that rotate with the event direction even outside swings/movement
## (launches and charges); forward offset applies along that direction.
const DIRECTIONAL := [&"headshot", &"covering_shot", &"warden_charge"]
## 15/11 playtest: signatures whose sheet plays on the skill's own impact (on the target) instead of on the
## signature event; the signature event itself (and its audio) is unchanged and drawn by code.
const SIGNATURE_ART_ON_IMPACT := [&"hunter_covering_shot"]
## 15/11 playtest: per-element impact accents of non-signature hits, reusing the painted element sheets.
const IMPACT_ART := {
	&"elementalist_tri_nova": {
		&"fire": [&"fire_burst", 58.0, 1.0, Color.WHITE, 0.0],
		&"ice": [&"ice_shatter", 58.0, 1.0, Color.WHITE, 0.0],
		&"lightning": [&"lightning_burst", 54.0, 1.0, Color.WHITE, 0.0],
	},
}
## Commit effects drawn on the confirmed target point (payload target_anchor / legacy_target_2d) instead of the caster.
const TARGET_ANCHORED: Array[StringName] = [&"spiritualist_dissipation"]
## Movement sheets that play where the travel ends (landing), mirrored by the travel side instead of rotated.
const LANDING_ART := [&"wound_leap"]
## Movement trails drawn along the confirmed travel (payload travel_distance): skill -> style.
const TRAIL_STYLES := {&"berserker_wound_leap": &"leap", &"hunter_covering_shot": &"recoil"}
const TRAIL_BLOOD := Color(0.75, 0.10, 0.20)
const TRAIL_BLOOD_HOT := Color(1.0, 0.62, 0.62)
const TRAIL_WIND := Color(0.91, 0.96, 0.82)
const TRAIL_LEAF := Color(0.42, 0.72, 0.30)
## Non-signature accent: nature trap bursts use the thorns flipbook.
const NATURE_TRAP_ART := [&"nature_thorns", 104.0, 1.0, Color.WHITE, 0.0]
## Dark outline copy (scale) behind the flipbook so pale effects read on light ground.
const OUTLINED := [&"slash_arc", &"lightning_burst", &"ground_shockwave", &"arcane_warp", &"nature_thorns", &"headshot", &"shield_bash", &"spirit_dissipation"]
## P7-C1: the palest/most discreet sheets get a stamped outline (8 offset copies) instead of the single 7% copy:
## flipbook id -> [offset in world px at zoom >= 1, outline colour (alpha is scaled by the frame fade)].
const OUTLINE_STAMP := {
	&"ground_shockwave": [2.2, Color(0.10, 0.06, 0.03, 0.6)],
	&"nature_thorns": [1.5, Color(0.02, 0.07, 0.03, 0.72)],
}
const STAMP_DIRECTIONS := 8
## Ground underlay of the shockwave (dark, translucent) so the pale ring reads on sand/earth and on grass.
const SHOCK_UNDERLAY := Color(0.12, 0.07, 0.03)
## Charge chevrons keep at least this on-screen scale (1.0 = their size at 100% zoom) when the camera zooms out.
const CHEVRON_ZOOM_FLOOR := 0.9
const CHEVRON_SCALE_MAX := 2.0
## Warm physical spark palette: dark edge, orange glow, hot core.
const SPARK_EDGE := Color(0.10, 0.05, 0.02)
const SPARK_GLOW := Color(1.0, 0.62, 0.16)
const SPARK_HOT := Color(1.0, 0.95, 0.72)

## Test hook: Callable(id: StringName) -> Dictionary (empty = flipbook unavailable). Default: VfxFlipbookCatalog.
var flipbook_provider := Callable()
## Test hook: when > 0 replaces the on-screen zoom read from the canvas transform.
var zoom_override := 0.0
var _clock := 0.0
var _windows: Dictionary = {}
var _last_hit: Dictionary = {}
var _recipe_cache: Dictionary = {}
var _flip_cache: Dictionary = {}
## Last launch point per skill (canvas local) so an impact sheet can face the way the shot travelled.
var _launch_from: Dictionary = {}
var _hash_seed := 0
static var _canvas_warmup_scheduled := false

func _init() -> void:
	super()
	z_as_relative = false # Absolute order: the host chain (preview windows, cameras) must not shift it.
	_canvas.z_as_relative = false

func _accepts(kind: StringName) -> bool: return kind in DRAWN_KINDS

func configure(source: PresentationEventBridge, controller: Node) -> void:
	super.configure(source, controller)
	var ready_ids := VfxFlipbookCatalog.preload_all()
	if _canvas_warmup_scheduled or ready_ids.is_empty() or not is_inside_tree():
		return
	if DisplayServer.get_name() == "headless" or RenderingServer.get_current_rendering_method() != &"gl_compatibility":
		return
	_canvas_warmup_scheduled = true
	_warm_canvas.call_deferred(get_tree().root, ready_ids)

## GL Compatibility can initialize its canvas shader variants on the first draw even with
## resident atlases. Draw one offscreen frame during setup, using the textured regions and
## the polygon / antialiased strokes used by the shockwave and thorn underlays.
static func _warm_canvas(root: Window, ready_ids: Array) -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(32, 32)
	viewport.disable_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	var painter := Node2D.new()
	painter.draw.connect(func() -> void:
		painter.draw_colored_polygon(PackedVector2Array([Vector2(2, 2), Vector2(6, 2), Vector2(4, 6)]), Color.WHITE)
		painter.draw_polyline(PackedVector2Array([Vector2(2, 2), Vector2(4, 6), Vector2(6, 2)]), Color.WHITE, 2.0, true)
		for index: int in ready_ids.size():
			var id: StringName = ready_ids[index]
			var texture := VfxFlipbookCatalog.texture(id)
			var origin := Vector2(index % 3, index / 3) * 8.0
			painter.draw_texture_rect_region(texture, Rect2(origin, Vector2(8, 8)), Rect2(VfxFlipbookCatalog.frame_region(id, 0))))
	viewport.add_child(painter)
	root.add_child(viewport)
	RenderingServer.frame_post_draw.connect(viewport.queue_free, CONNECT_ONE_SHOT)

func _world_anchor(event: Dictionary) -> Vector3:
	var anchor: Variant = _target_anchor(event)
	if anchor is Dictionary and str(anchor.get("stage_id", "")) == str(event.stage_id) and anchor.get("position") is Vector3:
		var point: Vector3 = anchor.position
		if point.is_finite(): return point
	return event.position

func _legacy_anchor(event: Dictionary) -> Variant:
	if event.kind == &"effect_start" and event.skill_id in TARGET_ANCHORED and event.payload.get("legacy_target_2d") is Vector2:
		var point: Vector2 = event.payload.legacy_target_2d
		if point.is_finite(): return point
	return super(event)

func _target_anchor(event: Dictionary) -> Variant:
	if event.kind != &"effect_start" or not event.skill_id in TARGET_ANCHORED: return null
	return event.payload.get("target_anchor")

func _on_stage_cleared() -> void:
	_windows.clear(); _last_hit.clear(); _launch_from.clear(); _clock = 0.0

func _advance(delta: float) -> void:
	if _active() and is_finite(delta) and delta > 0.0: _clock += delta
	super._advance(delta)

func recipe_for(event: Dictionary) -> Dictionary:
	var payload: Dictionary = event.get("payload", {})
	var key := "%s|%s|%s|%s|%s" % [event.get("skill_id", &""), payload.get("actor_variant", payload.get("source_variant", "")), payload.get("element", ""), event.get("kind", &""), payload.get("critical", false)]
	if _recipe_cache.has(key): return _recipe_cache[key]
	var recipe := Recipes.for_event(event)
	if _recipe_cache.size() > 512: _recipe_cache.clear()
	_recipe_cache[key] = recipe
	return recipe

## Resolved flipbook for `id` or {} when missing: {texture, grid, cell, frames, fps, hint}.
func flipbook(id: StringName) -> Dictionary:
	if flipbook_provider.is_valid():
		var provided: Variant = flipbook_provider.call(id)
		return provided if provided is Dictionary else {}
	if _flip_cache.has(id): return _flip_cache[id]
	var result := {}
	var definition := VfxFlipbookCatalog.definition(id)
	var texture := VfxFlipbookCatalog.texture(id)
	if not definition.is_empty() and texture != null:
		result = {"texture":texture, "grid":definition.grid, "cell":definition.cell, "frames":int(definition.frames), "fps":float(definition.suggested_fps), "hint":float(definition.get("world_diameter_hint", 150.0))}
	_flip_cache[id] = result
	return result

func _make_pulse(event: Dictionary, local: Vector2, legacy: bool) -> Dictionary:
	var kind: StringName = event.kind
	var payload: Dictionary = event.payload
	if kind == &"area_end" and String(payload.get("reason", "expire")) != "expire": return {} # Trigger/cleanup: nothing to fade.
	var recipe := recipe_for(event)
	# P7-C5: a basic attack has no launch-side burst (the single projectile in flight is its only launch art).
	if kind == &"projectile_launch" and bool(recipe.basic_hit): return {}
	if kind == &"impact" and not _impact_allowed(event, recipe): return {}
	var seed_value: int = String(event.event_id).hash() & 0x7fffffff
	var pulse := {"position":local, "kind":kind, "age":0.0, "family":recipe.family, "element":recipe.element, "skill":event.skill_id,
		"seed":seed_value, "legacy":legacy, "dir":_screen_dir(payload, legacy), "scale":1.0, "signature":&"", "flipbook":&"", "radius":_radius_px(payload, legacy), "basic_hit":bool(recipe.basic_hit)}
	var life := 0.4
	var signed: bool = recipe.is_signature and recipe.signature_kind == kind
	# P7-C7: every physical impact without its own signature art (basic attacks and ordinary physical skills such as brutal_strike or
	# double_shot) draws the white hit burst; the old orange ray burst is gone. Elements and signatures keep their own art.
	pulse["white_hit"] = kind == &"impact" and (bool(recipe.basic_hit) or (recipe.element == &"physical" and not signed))
	if signed: pulse.signature = recipe.signature; pulse.scale = 1.35
	if recipe.periodic: pulse.scale = 0.6
	match kind:
		&"impact": life = BASIC_HIT_LIFE if bool(pulse.white_hit) else 0.38
		&"melee_swing": life = 0.26
		&"area_start": life = 0.55
		&"area_end": life = 0.35
		&"cast_start": life = 0.32; pulse.scale = 0.7 if bool(payload.get("instant", false)) else 1.0
		&"cast_cancel": life = 0.3
		&"projectile_launch": life = 0.2
		&"teleport": life = 0.55
		&"death": life = 0.7
		&"revive": life = 0.7
		&"effect_start": life = 0.55
		&"heal": life = 0.75
		&"movement": life = 0.45
		&"charge_start": life = clampf(float(event.duration), 0.3, 0.9)
		&"summon": life = 0.85
		&"trap_trigger": life = 0.5
	var skill_id: StringName = event.skill_id
	var on_impact: bool = recipe.is_signature and recipe.signature in SIGNATURE_ART_ON_IMPACT
	if kind == &"projectile_launch" and on_impact: _launch_from[skill_id] = local
	if kind == &"impact" and on_impact and _launch_from.has(skill_id):
		var travelled: Vector2 = local - (_launch_from[skill_id] as Vector2)
		if travelled.length_squared() > 16.0: pulse.dir = travelled.normalized()
	if kind == &"movement" and TRAIL_STYLES.has(skill_id):
		var travel := _screen_travel(payload, legacy)
		if travel.length_squared() > 4.0:
			pulse.trail = TRAIL_STYLES[skill_id]
			pulse.travel = travel
			pulse.trail_start = local - travel if str(payload.get("phase", "start")) == "end" else local
			pulse.travel_time = clampf(float(event.duration), 0.05, 0.5)
			life = maxf(life, float(pulse.travel_time) + 0.35)
	var art: Array = []
	if signed and SIGNATURE_ART.has(recipe.signature) and not on_impact: art = SIGNATURE_ART[recipe.signature]
	elif kind == &"impact" and on_impact and SIGNATURE_ART.has(recipe.signature): art = SIGNATURE_ART[recipe.signature]
	elif kind == &"impact" and IMPACT_ART.has(skill_id): art = (IMPACT_ART[skill_id] as Dictionary).get(recipe.element, [])
	elif kind == &"trap_trigger" and recipe.element == &"nature": art = NATURE_TRAP_ART
	if art.is_empty():
		# E09 C1.8: a kit effect plays the flipbook with its own ID when one exists;
		# otherwise the module draws it in code.
		var kit_effect := ClassKitRegistry.vfx_effect(skill_id, kind)
		if not kit_effect.is_empty():
			var effect_id: StringName = kit_effect["effect_id"]
			if not flipbook(effect_id).is_empty(): art = [effect_id, float(kit_effect["size"]), 1.0, Color.WHITE, 0.0]
			else: pulse["kit_effect"] = effect_id; pulse["kit_owner"] = kit_effect["kit"]; life = maxf(life, 0.45)
	if not art.is_empty():
		var book := flipbook(art[0])
		if not book.is_empty() and float(book.fps) > 0.0 and int(book.frames) > 0:
			var speed: float = art[2]
			pulse.flipbook = art[0]; pulse.flip_speed = speed; pulse.flip_size = float(art[1]); pulse.flip_tint = art[3]; pulse.flip_forward = float(art[4])
			# A landing sheet starts as the body comes down (its first frames are the dive).
			pulse.flip_delay = float(pulse.travel_time) * 0.5 if art[0] in LANDING_ART and pulse.has("travel") else 0.0
			life = maxf(life, float(pulse.flip_delay) + float(book.frames) / (float(book.fps) * speed))
	pulse.life = life
	_canvas.z_index = Z_FLAT if legacy else Z_SPATIAL
	z_index = _canvas.z_index
	return pulse

## Confirmed ground travel (payload travel_distance along direction_2d) as a canvas vector.
func _screen_travel(payload: Dictionary, legacy: bool) -> Vector2:
	var raw: Variant = payload.get("travel_distance")
	var direction: Variant = payload.get("direction_2d")
	if typeof(raw) not in [TYPE_FLOAT, TYPE_INT] or not direction is Vector2: return Vector2.ZERO
	var distance := clampf(float(raw), 0.0, 600.0) if is_finite(float(raw)) else 0.0
	var d: Vector2 = direction
	if distance <= 0.0 or not d.is_finite() or d.length_squared() < 0.0001: return Vector2.ZERO
	var ground := d.normalized() * distance
	return ground if legacy else ProjectionMath.project(Vector3(ground.x, 0.0, ground.y))

func _impact_allowed(event: Dictionary, recipe: Dictionary) -> bool:
	var skill := String(event.skill_id)
	var window: Dictionary = _windows.get(skill, {"start":-1.0, "count":0})
	if _clock - float(window.start) >= IMPACT_WINDOW: window = {"start":_clock, "count":0}
	if int(window.count) >= IMPACT_PER_WINDOW: return false
	var target_key := "%s/%s" % [skill, event.payload.get("target_id", event.actor_id)]
	var gap := PERIODIC_GAP if recipe.periodic else TARGET_GAP
	if _last_hit.has(target_key) and _clock - float(_last_hit[target_key]) < gap: return false
	window.count = int(window.count) + 1
	_windows[skill] = window
	if _last_hit.size() >= FLOOD_MEMORY: _last_hit.clear()
	_last_hit[target_key] = _clock
	return true

## Screen-space unit direction: flat arena directions are already on screen; spatial ones are on the ground plane.
func _screen_dir(payload: Dictionary, legacy: bool) -> Vector2:
	var result := Vector2.RIGHT
	if not legacy and payload.get("direction") is Vector3:
		var d3: Vector3 = payload.direction
		var projected := ProjectionMath.project(Vector3(d3.x, 0.0, d3.z))
		if projected.length_squared() > 0.0001: result = projected.normalized()
	elif payload.get("direction_2d") is Vector2 and (payload.direction_2d as Vector2).length_squared() > 0.0001:
		var d: Vector2 = (payload.direction_2d as Vector2).normalized()
		result = d if legacy else ProjectionMath.project(Vector3(d.x, 0.0, d.y)).normalized()
	return result

func _radius_px(payload: Dictionary, legacy: bool) -> float:
	var raw: Variant = payload.get("effect_radius", payload.get("radius", 0.0))
	var radius := float(raw) if typeof(raw) in [TYPE_FLOAT, TYPE_INT] and is_finite(float(raw)) else 0.0
	return clampf(radius, 0.0, 240.0) * (GROUND_FLAT.x if legacy else GROUND_WORLD.x)

# ------------------------------------------------------------------ drawing
func _paint() -> void:
	for pulse: Dictionary in pulses: _draw_pulse(pulse)

func _draw_pulse(p: Dictionary) -> void:
	var t: float = clampf(float(p.age) / float(p.life), 0.0, 1.0)
	var pos: Vector2 = p.position
	if p.has("trail"): _trail(p)
	if p.flipbook != &"" and _draw_flipbook(p, pos, t): return
	if p.has("kit_effect") and ClassKitRegistry.draw_vfx(p["kit_owner"], p["kit_effect"], _canvas, p, pos, t): return
	match p.kind:
		&"impact": _impact(p, pos + Vector2(0, -18), t)
		&"melee_swing": _swing(p, pos + Vector2(0, -14), t)
		&"area_start": _area_ring(p, pos, t, false)
		&"area_end": _area_ring(p, pos, t, true)
		&"trap_trigger": _trap(p, pos, t)
		&"cast_start": _gather(p, pos, t)
		&"cast_cancel": _fizzle(p, pos + Vector2(0, -16), t)
		&"projectile_launch": _muzzle(p, pos + Vector2(0, -18), t)
		&"teleport": _teleport(p, pos, t)
		&"death": _motes(p, pos + Vector2(0, -14), t, Color("b8a9cf"), 7, 26.0)
		&"revive": _revive(p, pos, t)
		&"effect_start": _commit(p, pos, t)
		&"heal": _heal(p, pos + Vector2(0, -20), t)
		&"movement": _dust(p, pos, t)
		&"charge_start": _charge(p, pos, t)
		&"summon": _summon(p, pos, t)

func _palette(p: Dictionary) -> Array:
	return Palette.PALETTE.get(p.element, Palette.PALETTE[&"physical"])

func _r(p: Dictionary, index: int) -> float:
	return fmod(absf(sin(float(int(p.seed) % 9973) * 12.9898 + float(index) * 78.233)) * 43758.5453, 1.0)

func _ease_out(t: float) -> float: return 1.0 - (1.0 - t) * (1.0 - t)

func _stroke(a: Vector2, b: Vector2, color: Color, width: float) -> void:
	_canvas.draw_line(a, b, Color(HALO, HALO.a * color.a), width + 1.8, true)
	_canvas.draw_line(a, b, color, width, true)

func _ring(center: Vector2, rx: float, ry: float, color: Color, width: float, from_angle: float = 0.0, to_angle: float = TAU) -> void:
	var points := PackedVector2Array()
	var steps := 24
	for i: int in steps + 1:
		var a := lerpf(from_angle, to_angle, float(i) / float(steps))
		points.append(center + Vector2(cos(a) * rx, sin(a) * ry))
	_canvas.draw_polyline(points, Color(HALO, HALO.a * color.a), width + 1.8, true)
	_canvas.draw_polyline(points, color, width, true)

func _ground(p: Dictionary) -> Vector2:
	return GROUND_FLAT if p.legacy else GROUND_WORLD

# --- flipbook (signatures) ------------------------------------------------
func _draw_flipbook(p: Dictionary, pos: Vector2, _t: float) -> bool:
	var book := flipbook(p.flipbook)
	if book.is_empty(): return false
	var frame := floori((float(p.age) - float(p.get("flip_delay", 0.0))) * float(book.fps) * float(p.flip_speed))
	var frames := int(book.frames)
	if frame < 0 or frame >= frames: return true # Not started (landing delay) or finished; nothing else to draw.
	var grid: Array = book.grid
	var cell: Array = book.cell
	var region := Rect2(float(frame % int(grid[0])) * float(cell[0]), float(floori(float(frame) / float(grid[0]))) * float(cell[1]), float(cell[0]), float(cell[1]))
	var fit := float(p.flip_size) / maxf(1.0, float(book.hint))
	var half := Vector2(float(cell[0]), float(cell[1])) * 0.5 * fit
	var fade := clampf((float(frames - frame)) / 3.0, 0.0, 1.0)
	var center: Vector2 = pos + Vector2(0, -14)
	var angle := 0.0
	var mirror := Vector2.ONE
	if p.flipbook in LANDING_ART and p.has("travel"):
		var landing: Vector2 = (p.trail_start as Vector2) + (p.travel as Vector2)
		center = landing + Vector2(0, -float(p.flip_size) * 0.12)
		if (p.travel as Vector2).x < 0.0: mirror = Vector2(-1.0, 1.0) # Painted diving left-to-right.
	elif p.kind == &"melee_swing" or p.kind == &"movement" or p.flipbook in DIRECTIONAL:
		var dir: Vector2 = p.dir
		center += dir * float(p.flip_forward)
		angle = dir.angle()
	elif p.kind in [&"effect_start", &"area_start", &"summon", &"charge_start", &"trap_trigger", &"teleport"]:
		center = pos + Vector2(0, -float(p.flip_size) * 0.12) # Ground-seated: centre sits just above the anchor.
	_canvas.draw_set_transform(center, angle, mirror)
	if p.flipbook == &"ground_shockwave": _shock_underlay(half, frame, fade)
	elif p.flipbook == &"nature_thorns": _thorn_ground_ring(half, frame, fade)
	if OUTLINE_STAMP.has(p.flipbook):
		var stamp: Array = OUTLINE_STAMP[p.flipbook]
		var edge: Color = stamp[1]
		for offset: Vector2 in stamp_offsets(float(stamp[0]), zoom_boost()):
			_canvas.draw_texture_rect_region(book.texture, Rect2(-half + offset, half * 2.0), region, Color(edge, edge.a * fade))
	elif p.flipbook in OUTLINED:
		_canvas.draw_texture_rect_region(book.texture, Rect2(-half * 1.07, half * 2.14), region, Color(0.03, 0.04, 0.08, 0.55 * fade))
	var tint: Color = p.flip_tint
	_canvas.draw_texture_rect_region(book.texture, Rect2(-half, half * 2.0), region, Color(tint, tint.a * fade))
	_canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	return true

# --- travel trails (15/11 playtest) ------------------------------------------
func _trail(p: Dictionary) -> void:
	match p.trail:
		&"leap": _leap_trail(p)
		&"recoil": _recoil_trail(p)

## Point `s` (0 = take-off, 1 = landing) of the leap arc, lifted to body height.
func leap_point(p: Dictionary, s: float) -> Vector2:
	var travel: Vector2 = p.travel
	var height := clampf(travel.length() * 0.32, 16.0, 46.0)
	return (p.trail_start as Vector2) + travel * s + Vector2(0, -16.0 - 4.0 * height * s * (1.0 - s))

## Blood arc over the jump: the head follows the body, the tail catches up after landing; drops fall from the arc.
func _leap_trail(p: Dictionary) -> void:
	var flight: float = p.travel_time
	var age: float = p.age
	var head := clampf(age / flight, 0.0, 1.0)
	var tail := clampf((age - flight * 0.35) / (flight + 0.3), 0.0, 1.0)
	if head - tail > 0.01:
		var steps := 16
		var previous := leap_point(p, tail)
		for i: int in range(1, steps + 1):
			var s := lerpf(tail, head, float(i) / float(steps))
			var point := leap_point(p, s)
			var weight := float(i) / float(steps) # Thin at the tail, thick at the head.
			_canvas.draw_line(previous, point, Color(SPARK_EDGE, 0.55 * weight), 2.0 + 6.0 * weight, true)
			_canvas.draw_line(previous, point, Color(TRAIL_BLOOD, 0.85 * weight), 1.2 + 4.5 * weight, true)
			_canvas.draw_line(previous, point, Color(TRAIL_BLOOD_HOT, 0.7 * weight), 0.6 + 1.4 * weight, true)
			previous = point
	for i: int in 6:
		var s := (float(i) + 0.5 + (_r(p, 30 + i) - 0.5) * 0.6) / 6.0
		var since := age - flight * s
		if since <= 0.0 or since > 0.4: continue
		var drop := leap_point(p, s) + Vector2((_r(p, 40 + i) - 0.5) * 8.0, 60.0 * since * since + 10.0 * since)
		_canvas.draw_circle(drop, 2.4 * (1.0 - since / 0.4) + 0.6, Color(TRAIL_BLOOD, 1.0 - since / 0.4))

## Instant recoil: wind streaks from where the shot was taken back to the landing spot, swept toward it, plus loose leaves.
func _recoil_trail(p: Dictionary) -> void:
	var travel: Vector2 = p.travel
	var start: Vector2 = (p.trail_start as Vector2) + Vector2(0, -16)
	var u := clampf(float(p.age) / 0.32, 0.0, 1.0)
	var fade := 1.0 - u
	var perp := travel.normalized().orthogonal()
	for k: int in 3:
		var side := (float(k) - 1.0) * 7.0
		var tail := clampf(_ease_out(u) + 0.12 * float(k % 2), 0.0, 1.0)
		var from := start + travel * tail + perp * side
		var to := start + travel * (0.92 + 0.08 * _r(p, k)) + perp * side * 0.6
		if from.distance_squared_to(to) < 1.0: continue
		_canvas.draw_line(from, to, Color(SPARK_EDGE, 0.35 * fade), 4.0, true)
		_canvas.draw_line(from, to, Color(TRAIL_WIND, 0.85 * fade), 2.0 - 0.5 * absf(float(k) - 1.0), true)
	for i: int in 4:
		var s := 0.15 + 0.22 * float(i)
		var q := start + travel * s + perp * (_r(p, 50 + i) - 0.5) * 20.0 + Vector2(0, 14.0 * u)
		var a := _r(p, 60 + i) * TAU + u * 4.0
		var leaf := PackedVector2Array([q + Vector2.from_angle(a) * 4.0, q + Vector2.from_angle(a + PI * 0.5) * 1.6, q - Vector2.from_angle(a) * 4.0, q - Vector2.from_angle(a + PI * 0.5) * 1.6])
		_canvas.draw_colored_polygon(leaf, Color(TRAIL_LEAF, fade))

## On-screen zoom of the world canvas (1.0 when unknown, e.g. outside the tree or headless).
func current_zoom() -> float:
	if zoom_override > 0.0: return zoom_override
	if _canvas == null or not _canvas.is_inside_tree(): return 1.0
	var value := absf(_canvas.get_global_transform_with_canvas().get_scale().x)
	return value if is_finite(value) and value > 0.01 else 1.0

## Scale that keeps a world-sized mark at >= `floor_zoom` of its 100% on-screen size; 1.0 from `floor_zoom` up.
static func zoom_floor_scale(zoom: float, floor_zoom: float, maximum: float) -> float:
	if not is_finite(zoom) or zoom <= 0.0: return 1.0
	return clampf(floor_zoom / zoom, 1.0, maximum)

func zoom_boost() -> float: return zoom_floor_scale(current_zoom(), 0.8, 2.0)
func chevron_scale() -> float: return zoom_floor_scale(current_zoom(), CHEVRON_ZOOM_FLOOR, CHEVRON_SCALE_MAX)

## Offsets (world px) of the stamped outline copies: STAMP_DIRECTIONS around a circle of radius `radius * boost`.
static func stamp_offsets(radius: float, boost: float) -> Array[Vector2]:
	var result: Array[Vector2] = []
	for i: int in STAMP_DIRECTIONS: result.append(Vector2.from_angle(TAU * float(i) / float(STAMP_DIRECTIONS)) * radius * boost)
	return result

## Dark ground disc + ring under the pale shockwave sheet (drawn in the sheet's centred transform).
func _shock_underlay(half: Vector2, frame: int, fade: float) -> void:
	var u := _ease_out(clampf(float(frame) / 7.0, 0.0, 1.0))
	var rx := half.x * 0.78 * lerpf(0.25, 1.0, u)
	var ry := rx * 0.52
	var points := PackedVector2Array()
	for i: int in 25:
		var a := TAU * float(i) / 24.0
		points.append(Vector2(cos(a) * rx, sin(a) * ry + half.y * 0.04))
	_canvas.draw_colored_polygon(points, Color(SHOCK_UNDERLAY, 0.16 * fade))
	_canvas.draw_polyline(points, Color(SHOCK_UNDERLAY, 0.34 * fade), 3.2, true)

## Bright ground ring under the thorns (dark halo from _ring) so the accent reads on grass and on light ground.
func _thorn_ground_ring(half: Vector2, frame: int, fade: float) -> void:
	var u := _ease_out(clampf(float(frame) / 6.0, 0.0, 1.0))
	var rx := half.x * 0.95 * lerpf(0.3, 1.0, u) # Wider than the plant so the ring is not hidden behind it.
	_ring(Vector2(0, half.y * 0.5), rx, rx * 0.42, Color("c8f07a", 0.85 * fade), 2.6)

# --- impact -----------------------------------------------------------------
func _impact(p: Dictionary, c: Vector2, t: float) -> void:
	if bool(p.get("white_hit", p.get("basic_hit", false))):
		_basic_hit_burst(p, c, t)
		return
	var pal := _palette(p)
	var core: Color = pal[0]
	var glow: Color = pal[1]
	var s: float = p.scale
	var fade := 1.0 - t * t
	var n := 6 + int(p.seed) % 4
	var reach := (13.0 + 20.0 * _ease_out(t)) * s
	_canvas.draw_circle(c, (8.0 * fade + 2.0) * s, Color(core, 0.75 * fade))
	match p.element:
		&"fire":
			for i: int in n:
				var a := TAU * float(i) / float(n) + _r(p, i) * 0.6
				_stroke(c + Vector2.from_angle(a) * reach * 0.4, c + Vector2.from_angle(a) * reach, Color(glow, fade * 0.9), 2.0)
			for i: int in 4:
				var x := (_r(p, 20 + i) - 0.5) * 18.0 * s
				_canvas.draw_circle(c + Vector2(x, -t * 24.0 * s - 3.0), 1.8 * s, Color(core, fade))
		&"ice":
			for i: int in 5:
				var a := TAU * float(i) / 5.0 + _r(p, i) * 0.5
				var tip := c + Vector2.from_angle(a) * reach
				var side := Vector2.from_angle(a + PI * 0.5) * 2.4 * s
				var base := c + Vector2.from_angle(a) * reach * 0.35
				_canvas.draw_colored_polygon(PackedVector2Array([base + side, tip, base - side]), Color("e7fbff", fade * 0.95))
				_canvas.draw_polyline(PackedVector2Array([base + side, tip, base - side]), Color(glow, fade), 1.2, true)
		&"lightning":
			for i: int in 4:
				var a := TAU * float(i) / 4.0 + _r(p, i) * 0.8
				var q := PackedVector2Array([c])
				for k: int in range(1, 4):
					q.append(c + Vector2.from_angle(a + (_r(p, 8 + i * 3 + k) - 0.5) * 0.9) * reach * float(k) / 3.0)
				_canvas.draw_polyline(q, Color(HALO, 0.35 * fade), 4.0, true)
				_canvas.draw_polyline(q, Color(core, fade), 2.0, true)
		&"arcane":
			_ring(c, reach * 0.8, reach * 0.8, Color(glow, fade * 0.9), 1.6)
			for i: int in 4:
				var a := PI * 0.25 + TAU * float(i) / 4.0
				_stroke(c + Vector2.from_angle(a) * reach * 0.3, c + Vector2.from_angle(a) * reach * 1.05, Color(core, fade), 1.6)
		&"spirit":
			for i: int in 5:
				var x := (_r(p, i) - 0.5) * 24.0 * s
				var rise := t * (14.0 + 14.0 * _r(p, 10 + i)) * s
				_canvas.draw_circle(c + Vector2(x, -rise), (2.4 - t) * s, Color(core, fade * 0.8))
			_ring(c, reach * 0.7, reach * 0.4, Color(glow, fade * 0.6), 1.2)
		&"nature":
			for i: int in 6:
				var a := TAU * float(i) / 6.0 + _r(p, i)
				var q := c + Vector2.from_angle(a) * reach * (0.5 + 0.5 * t) + Vector2(0, t * 8.0)
				_canvas.draw_colored_polygon(PackedVector2Array([q + Vector2(-2.6, 0), q + Vector2(0, -4.0 * s), q + Vector2(2.6, 0), q + Vector2(0, 2.0)]), Color(glow, fade * 0.95))
		&"geometry":
			var tri := PackedVector2Array()
			for i: int in 4:
				tri.append(c + Vector2.from_angle(-PI * 0.5 + TAU * float(i % 3) / 3.0) * reach * 0.85)
			_canvas.draw_polyline(tri, Color(HALO, 0.35 * fade), 3.6, true)
			_canvas.draw_polyline(tri, Color(core, fade), 1.8, true)
		&"blood":
			for i: int in n:
				var a := TAU * float(i) / float(n) + _r(p, i) * 0.5
				var q := c + Vector2.from_angle(a) * reach * 0.9 * _ease_out(t) + Vector2(0, t * t * 14.0)
				_canvas.draw_circle(q, (2.6 - 1.2 * t) * s, Color(glow, fade))
			_canvas.draw_arc(c, reach * 0.5, -PI * 0.9, -PI * 0.1, 10, Color(core, fade * 0.8), 2.0, true)
		_:
			# Only reachable by a physical impact that is not a white hit (none today: physical impacts are white hits since P7-C7).
			_physical_sparks(p, c, n, reach * 1.15, s, fade)

## P7-C5: brief sharp white starburst + one slash line at the victim; dark hairline edge so it reads on pale ground.
## Deterministic (seeded by the event); size follows the zoom floor so it stays visible when zoomed out.
func _basic_hit_burst(p: Dictionary, c: Vector2, t: float) -> void:
	var boost := zoom_boost()
	var fade := 1.0 - t * t
	var grow := _ease_out(minf(1.0, t * 2.2))
	var base := _r(p, 0) * TAU
	for i: int in BASIC_RAYS:
		var a := base + TAU * float(i) / float(BASIC_RAYS) + (_r(p, 1 + i) - 0.5) * 0.35
		var long_ray := i % 2 == 0
		var inner := (3.0 + 2.0 * grow) * boost
		var outer := ((10.0 if long_ray else 7.0) + (13.0 if long_ray else 8.0) * grow) * boost
		var dir := Vector2.from_angle(a)
		_canvas.draw_line(c + dir * inner, c + dir * outer, Color(BASIC_EDGE, BASIC_EDGE.a * fade), (3.4 if long_ray else 2.8) * boost, true)
		_canvas.draw_line(c + dir * inner, c + dir * outer, Color(1.0, 1.0, 1.0, fade), (1.8 if long_ray else 1.4) * boost, true)
	var slash := Vector2.from_angle(base + 0.6 + (_r(p, 9) - 0.5) * 0.5) * (7.0 + 11.0 * grow) * boost
	_canvas.draw_line(c - slash, c + slash, Color(BASIC_EDGE, BASIC_EDGE.a * fade), 3.6 * boost, true)
	_canvas.draw_line(c - slash, c + slash, Color(1.0, 1.0, 1.0, fade), 2.0 * boost, true)
	_canvas.draw_circle(c, (3.2 * fade + 1.0) * boost, Color(1.0, 1.0, 1.0, fade))

## Strokes of a physical spark, outermost first: dark edge, orange glow, hot core.
static func spark_layers(fade: float) -> Array:
	return [[4.4, Color(SPARK_EDGE, 0.85 * fade)], [3.0, Color(SPARK_GLOW, fade)], [1.5, Color(SPARK_HOT, fade)]]

func _physical_sparks(p: Dictionary, c: Vector2, n: int, reach: float, s: float, fade: float) -> void:
	var flash := (8.0 * fade + 2.0) * s
	_canvas.draw_circle(c, flash + 1.8, Color(SPARK_EDGE, 0.5 * fade))
	_canvas.draw_circle(c, flash, Color(SPARK_GLOW, 0.9 * fade))
	_canvas.draw_circle(c, flash * 0.55, Color(SPARK_HOT, fade))
	var layers := spark_layers(fade)
	for i: int in n:
		var a := TAU * float(i) / float(n) + _r(p, i) * 0.6
		var from := c + Vector2.from_angle(a) * reach * 0.3
		var to := c + Vector2.from_angle(a) * reach
		for style: Array in layers: _canvas.draw_line(from, to, style[1], float(style[0]), true)
		_canvas.draw_circle(to, 2.2, Color(SPARK_HOT, fade))

# --- melee swing -------------------------------------------------------------
func _swing(p: Dictionary, c: Vector2, t: float) -> void:
	var dir: Vector2 = p.dir
	var base := dir.angle()
	var pal := _palette(p)
	var core: Color = Color("eef2f8") if p.element == &"physical" else pal[0]
	var glow: Color = Color("9fb4cc") if p.element == &"physical" else pal[1]
	var s: float = p.scale
	var sweep := deg_to_rad(120.0)
	var head := lerpf(-sweep * 0.5, sweep * 0.5, _ease_out(minf(1.0, t * 1.6)))
	var tail := maxf(-sweep * 0.5, head - deg_to_rad(80.0))
	var fade := 1.0 - maxf(0.0, (t - 0.45) / 0.55)
	var radius := 30.0 * s
	var steps := 10
	var origin := c + dir * 6.0
	var prev := Vector2.ZERO
	for i: int in steps + 1:
		var a := base + lerpf(tail, head, float(i) / float(steps))
		var q := origin + Vector2(cos(a) * radius, sin(a) * radius * 0.78)
		if i > 0:
			var w := lerpf(0.8, 4.2 * s, float(i) / float(steps))
			var alpha := lerpf(0.1, 1.0, float(i) / float(steps)) * fade
			_canvas.draw_line(prev, q, Color(HALO, HALO.a * alpha), w + 2.0, true)
			_canvas.draw_line(prev, q, Color(glow, alpha * 0.9), w + 1.0, true)
			_canvas.draw_line(prev, q, Color(core, alpha), maxf(1.0, w - 1.0), true)
		prev = q
	if p.element == &"blood":
		for i: int in 3:
			_canvas.draw_circle(prev + Vector2.from_angle(base + head + 0.5 + _r(p, i)) * (4.0 + 6.0 * t * float(i + 1)), 1.8, Color(glow, fade))

# --- areas, traps -------------------------------------------------------------
func _area_ring(p: Dictionary, pos: Vector2, t: float, closing: bool) -> void:
	var g := _ground(p)
	var pal := _palette(p)
	var core: Color = pal[0]
	var glow: Color = pal[1]
	var maximum: float = float(p.radius) if float(p.radius) > 1.0 else 48.0 * g.x
	if p.signature == &"archer_arrow_rain" and not closing:
		_arrow_volley(p, pos, maximum, t)
		return
	var u := _ease_out(t)
	var radius := maximum * (1.0 - 0.15 * u) if closing else maximum * 0.92 * (0.35 + 0.65 * u)
	var alpha := (1.0 - t) * (0.3 if closing else 0.65)
	_ring(pos, radius, radius * g.y / g.x, Color(glow, alpha), 2.4)
	_ring(pos, radius * 0.97, radius * 0.97 * g.y / g.x, Color(core, alpha * 0.5), 1.0)
	if closing: return
	var spikes := 8
	for i: int in spikes:
		var a := TAU * float(i) / float(spikes) + _r(p, 1) * 0.4
		var rim := pos + Vector2(cos(a) * radius, sin(a) * radius * g.y / g.x)
		_rim_accent(p, rim, a, t, core, glow)

func _rim_accent(p: Dictionary, rim: Vector2, a: float, t: float, core: Color, glow: Color) -> void:
	var fade := (1.0 - t) * 0.8
	match p.element:
		&"fire":
			_canvas.draw_colored_polygon(PackedVector2Array([rim + Vector2(-2.5, 0), rim + Vector2(0, -8.0 - 3.0 * sin(a * 3.0 + t * 9.0)), rim + Vector2(2.5, 0)]), Color(glow, fade))
		&"ice":
			_canvas.draw_colored_polygon(PackedVector2Array([rim + Vector2(-2.2, 0), rim + Vector2(0, -9.0), rim + Vector2(2.2, 0)]), Color(core, fade))
		&"lightning":
			_stroke(rim, rim + Vector2(cos(a * 2.0), -1.0) * 7.0, Color(core, fade), 1.6)
		&"nature":
			_canvas.draw_colored_polygon(PackedVector2Array([rim + Vector2(-2.4, 0), rim + Vector2(0, -6.0), rim + Vector2(2.4, 0)]), Color(glow, fade))
		&"blood":
			_canvas.draw_circle(rim + Vector2(0, -1), 1.8, Color(glow, fade))
		_:
			_canvas.draw_circle(rim, 1.5, Color(core, fade * 0.8))

func _arrow_volley(p: Dictionary, pos: Vector2, maximum: float, t: float) -> void:
	var g := _ground(p)
	var fade := 1.0 - t
	for i: int in 10:
		var phase := fmod(t * 1.8 + _r(p, i) * 0.9, 1.0)
		var angle := TAU * _r(p, 20 + i)
		var spot := pos + Vector2(cos(angle), sin(angle)) * Vector2(maximum, maximum * g.y / g.x) * sqrt(_r(p, 40 + i)) * 0.85
		var top := spot + Vector2(-8, -40)
		var tip := top.lerp(spot, phase)
		_stroke(tip + Vector2(-5, -14) * (1.0 - phase * 0.3), tip, Color("f6dfad", fade * 0.9), 1.6)
	_ring(pos, maximum * 0.9, maximum * 0.9 * g.y / g.x, Color("d29a4a", fade * 0.4), 1.4)

func _trap(p: Dictionary, pos: Vector2, t: float) -> void:
	_area_ring(p, pos, minf(1.0, t * 1.4), false)
	var q := p.duplicate()
	q.scale = maxf(float(p.scale), 1.4)
	_impact(q, pos + Vector2(0, -10), t)

# --- instants -------------------------------------------------------------------
func _gather(p: Dictionary, pos: Vector2, t: float) -> void:
	var pal := _palette(p)
	var core: Color = pal[0]
	var glow: Color = pal[1]
	var s: float = p.scale
	var radius := lerpf(26.0, 8.0, _ease_out(t)) * s
	var alpha := sin(t * PI) * 0.8
	var g := _ground(p)
	_ring(pos, radius, radius * g.y / g.x, Color(glow, alpha), 1.8)
	for i: int in 5:
		var a := TAU * float(i) / 5.0 + _r(p, i) + t * 2.0
		_canvas.draw_circle(pos + Vector2(cos(a) * radius, sin(a) * radius * g.y / g.x - t * 10.0), 1.6, Color(core, alpha))

func _fizzle(p: Dictionary, c: Vector2, t: float) -> void:
	_motes(p, c, t, Color("b8a9cf"), 4, 12.0)

func _muzzle(p: Dictionary, c: Vector2, t: float) -> void:
	var pal := _palette(p)
	var core: Color = pal[0]
	var glow: Color = pal[1]
	var dir: Vector2 = p.dir
	var fade := 1.0 - t
	var tip := c + dir * 12.0
	_canvas.draw_circle(tip, (6.0 * fade + 1.5), Color(glow, 0.6 * fade))
	_canvas.draw_circle(tip, 3.0 * fade + 1.0, Color(core, fade))
	for i: int in 3:
		var a := dir.angle() + (_r(p, i) - 0.5) * 1.2
		_stroke(tip, tip + Vector2.from_angle(a) * (6.0 + 8.0 * t), Color(core, fade * 0.9), 1.4)

func _teleport(p: Dictionary, pos: Vector2, t: float) -> void:
	var g := _ground(p)
	var radius := lerpf(8.0, 30.0, _ease_out(t)) * float(p.scale)
	var fade := 1.0 - t
	_ring(pos, radius, radius * g.y / g.x, Color("a7e8ff", fade * 0.85), 1.8)
	_ring(pos, radius * 0.6, radius * 0.6 * g.y / g.x, Color("d8b4ff", fade * 0.7), 1.2)
	for i: int in 6:
		var x := (_r(p, i) - 0.5) * radius * 1.4
		_stroke(pos + Vector2(x, 0), pos + Vector2(x, -10.0 - 34.0 * _ease_out(t) * (0.6 + _r(p, 9 + i))), Color("c9f0ff", fade * 0.8), 1.4)

func _revive(p: Dictionary, pos: Vector2, t: float) -> void:
	var g := _ground(p)
	var fade := 1.0 - t
	var radius := lerpf(10.0, 26.0, _ease_out(t))
	_ring(pos, radius, radius * g.y / g.x, Color("a7e8ff", fade * 0.9), 1.8)
	for i: int in 5:
		var x := (_r(p, i) - 0.5) * radius * 1.3
		_stroke(pos + Vector2(x, 0), pos + Vector2(x, -12.0 - 30.0 * _ease_out(t)), Color("ffffff", fade * 0.7), 1.4)

func _motes(p: Dictionary, c: Vector2, t: float, color: Color, count: int, spread: float) -> void:
	var fade := 1.0 - t
	for i: int in count:
		var x := (_r(p, i) - 0.5) * spread
		var rise := t * (10.0 + 18.0 * _r(p, 12 + i))
		_canvas.draw_circle(c + Vector2(x, -rise), 2.2 - 1.0 * t, Color(color, fade * 0.8))

func _commit(p: Dictionary, pos: Vector2, t: float) -> void:
	var pal := _palette(p)
	var core: Color = pal[0]
	var glow: Color = pal[1]
	var g := _ground(p)
	var fade := 1.0 - t
	var s: float = p.scale
	if p.signature == &"elementalist_tri_nova":
		for k: int in 3:
			var delay := float(k) * 0.18
			var u := clampf((t - delay) / maxf(0.01, 1.0 - delay), 0.0, 1.0)
			if u <= 0.0: continue
			var tone: Array = Palette.PALETTE[[&"fire", &"ice", &"lightning"][k]]
			var radius := lerpf(10.0, 44.0, _ease_out(u))
			_ring(pos, radius, radius * g.y / g.x, Color(tone[1], (1.0 - u) * 0.9), 2.0)
		return
	if p.family == &"buff":
		for k: int in 2:
			var u := fmod(t * 1.3 + float(k) * 0.5, 1.0)
			var radius := 20.0 * s
			var lift := u * 30.0
			_ring(pos + Vector2(0, -lift), radius, radius * g.y / g.x, Color(glow, (1.0 - u) * fade * 0.9), 1.8)
		for i: int in 3:
			var x := (float(i) - 1.0) * 10.0
			var y := -8.0 - t * 30.0 - float(i) * 3.0
			_stroke(pos + Vector2(x - 3, y + 3), pos + Vector2(x, y), Color(core, fade), 1.6)
			_stroke(pos + Vector2(x + 3, y + 3), pos + Vector2(x, y), Color(core, fade), 1.6)
		return
	var radius := lerpf(12.0, 40.0, _ease_out(t)) * s
	_ring(pos, radius, radius * g.y / g.x, Color(glow, fade * 0.85), 2.0)
	_ring(pos, radius * 0.6, radius * 0.6 * g.y / g.x, Color(core, fade * 0.6), 1.2)
	for i: int in 6:
		var a := TAU * float(i) / 6.0 + _r(p, i)
		_rim_accent(p, pos + Vector2(cos(a) * radius, sin(a) * radius * g.y / g.x), a, t, core, glow)

func _heal(p: Dictionary, c: Vector2, t: float) -> void:
	var fade := 1.0 - t
	var green := Color("8ff0a8")
	_canvas.draw_circle(c + Vector2(0, 4), 12.0 * fade + 4.0, Color(green, 0.18 * fade))
	for i: int in 3:
		var x := (float(i) - 1.0) * 11.0 + (_r(p, i) - 0.5) * 4.0
		var y := -t * (22.0 + 6.0 * float(i)) - float(i) * 3.0
		var q := c + Vector2(x, y)
		_stroke(q + Vector2(-3, 0), q + Vector2(3, 0), Color(green, fade), 2.0)
		_stroke(q + Vector2(0, -3), q + Vector2(0, 3), Color(green, fade), 2.0)

func _dust(p: Dictionary, pos: Vector2, t: float) -> void:
	var dir: Vector2 = p.dir
	var pal := _palette(p)
	var tone: Color = Color("c9b79a") if p.element == &"physical" else pal[1]
	var fade := 1.0 - t
	for i: int in 5:
		var back := -dir * (6.0 + 10.0 * float(i)) * (0.6 + 0.6 * t)
		var q := pos + back + Vector2((_r(p, i) - 0.5) * 6.0, -t * 6.0 - 1.0)
		_canvas.draw_circle(q, (3.2 - 0.3 * float(i)) * (0.6 + t), Color(tone, fade * 0.45))
	if p.element == &"blood":
		_stroke(pos - dir * 26.0, pos, Color(pal[1], fade * 0.8), 2.0)

## Chevron segments [from, to, index] for the charge telegraph; `k` scales sizes/spacing (zoom floor).
func chevron_segments(pos: Vector2, dir: Vector2, k: float) -> Array:
	var perp := dir.orthogonal()
	var result: Array = []
	for i: int in 3:
		var at := pos + dir * (26.0 + 24.0 * float(i)) * k + Vector2(0, -6.0 * k)
		result.append([at - dir * 9.0 * k + perp * 10.0 * k, at + dir * 3.0 * k, i])
		result.append([at - dir * 9.0 * k - perp * 10.0 * k, at + dir * 3.0 * k, i])
	return result

func _charge(p: Dictionary, pos: Vector2, t: float) -> void:
	var k := chevron_scale()
	var tone := Color("ff8a5c") if p.element != &"nature" else Color("ffb36a")
	var pulse := 0.55 + 0.45 * sin(t * TAU * 3.0)
	for segment: Array in chevron_segments(pos, p.dir, k):
		var a := Color(tone, pulse * (1.0 - 0.2 * float(segment[2])) * (1.0 - t * 0.5))
		_canvas.draw_line(segment[0], segment[1], Color(SPARK_EDGE, 0.5 * a.a), 3.0 * k + 3.0, true) # Dark edge: reads on sand and grass.
		_stroke(segment[0], segment[1], a, 3.0 * k)

func _summon(p: Dictionary, pos: Vector2, t: float) -> void:
	var g := _ground(p)
	var fade := 1.0 - t
	var green := Color("8fe3a0") if p.element == &"nature" else Color("d8b4ff")
	var radius := lerpf(10.0, 26.0, _ease_out(minf(1.0, t * 2.0)))
	_ring(pos, radius, radius * g.y / g.x, Color(green, fade * 0.95), 2.0)
	_ring(pos, radius * 0.55, radius * 0.55 * g.y / g.x, Color(green.lightened(0.4), fade * 0.7), 1.2)
	for i: int in 6:
		var a := TAU * float(i) / 6.0 + t * 3.0
		var q := pos + Vector2(cos(a) * radius * 0.8, sin(a) * radius * 0.8 * g.y / g.x - t * 18.0)
		_canvas.draw_circle(q, 1.8, Color(green.lightened(0.5), fade))
