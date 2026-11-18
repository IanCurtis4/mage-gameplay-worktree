extends SceneTree
## E08 P6-A2: feedback by recipe (FeedbackVfxLayer), world projectile silhouettes, Elementalist
## world pulses and the bridge element hint. Presentation only: no gameplay value may change.
const Fixture = preload("res://tests/fixtures/e07/f1/fixture_input.gd")
const Layer = preload("res://scripts/presentation/feedback_vfx_layer.gd")
const Base = preload("res://scripts/presentation/e08_pilot_feedback.gd")
const Recipes = preload("res://scripts/presentation/feedback_recipe_catalog.gd")
const Art = preload("res://scripts/presentation/world_projectile_art.gd")
class Host extends Node2D:
	var snapshot_passive := false
var checks := 0
var failures := 0
var serial := 0
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(label)
func _initialize() -> void: _run.call_deferred()

func event(bridge: PresentationEventBridge, kind: StringName, skill: StringName, payload_extra: Dictionary = {}, at: Vector2 = Vector2(50, 50)) -> Dictionary:
	serial += 1
	var payload := {"presentation_epoch":bridge.current_epoch(), "position_unavailable":true, "legacy_position_2d":at, "target_id":str(serial)}
	payload.merge(payload_extra, true)
	return {"event_id":"vfx_%d" % serial, "kind":kind, "stage_id":bridge.stage_id, "actor_id":"fixture", "skill_id":skill, "position":Vector3.ZERO, "surface_id":"", "duration":0.4, "essential":false, "payload":payload}

func rig() -> Dictionary:
	var host := Host.new(); root.add_child(host)
	var bridge := PresentationEventBridge.new(); host.add_child(bridge); bridge.bind_controller(host); bridge.set_process(false)
	var layer: Control = Layer.new(); bridge.add_child(layer); layer.configure(bridge, host)
	bridge.begin_stage("vfx")
	return {"host":host, "bridge":bridge, "layer":layer}

## Kind that carries each family in the bridge (a signature only applies on its own kind).
const FAMILY_KIND := {&"cast":&"cast_start", &"projectile":&"projectile_launch", &"melee":&"melee_swing", &"impact":&"impact", &"area":&"area_start", &"trap":&"trap_trigger",
	&"buff":&"effect_start", &"heal":&"heal", &"movement":&"movement", &"summon":&"summon", &"charge":&"charge_start", &"teleport":&"teleport", &"death":&"death", &"revive":&"revive"}

func _run() -> void:
	check(Fixture.sources_current(), "fixture sources match frozen inputs")
	await _selection()
	await _signatures()
	await _flood_and_lifecycle()
	await _idle_redraw_and_preload()
	await _determinism_and_orientation()
	_projectile_art()
	await _basic_attack_and_trace()
	await _spatial()
	await _playtest_1115()
	print("E08 FEEDBACK VFX: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

func _selection() -> void:
	var r := rig()
	var bridge: PresentationEventBridge = r.bridge
	var layer = r.layer
	var recipes := Recipes.known_ids()
	check(recipes.size() >= 80, "recipe catalog covers the active kit (%d ids)" % recipes.size())
	var drawn_families := {}
	var drawn_elements := {}
	for skill: StringName in recipes:
		var recipe := Recipes.recipe(skill)
		var kind: StringName = FAMILY_KIND[recipe.family]
		# P7-C7: a projectile basic attack (enemy_arrow) has no launch burst by design (C5); its visual is the impact, so select through that kind.
		if bool(recipe.basic_hit) and kind == &"projectile_launch": kind = &"impact"
		layer.pulses.clear(); layer._on_stage_cleared()
		var extra := {"radius":60.0, "direction_2d":Vector2.RIGHT, "instant":false}
		check(bridge.emit_confirmed(event(bridge, kind, skill, extra)), "event accepted for " + str(skill))
		var pulse: Dictionary = layer.pulses.back() if not layer.pulses.is_empty() else {}
		check(not pulse.is_empty() and pulse.family == recipe.family and pulse.element == recipe.element and pulse.kind == kind, "recipe selects family/element for %s (%s/%s)" % [skill, recipe.family, recipe.element])
		drawn_families[recipe.family] = true
		drawn_elements[recipe.element] = true
	for family: StringName in Recipes.FAMILIES:
		if family in [&"death", &"revive"]: continue # No active skill maps to them; covered below.
		check(drawn_families.has(family), "family has a visual: " + str(family))
	# E10a C1.11: shadow has no production recipe until the Acólito family is ready (its
	# modules are skeletons); its own colour and effect are checked through the palette.
	for element: StringName in Recipes.ELEMENTS:
		if element == &"shadow" and not drawn_elements.has(element):
			check(WorldProjectileArt.PALETTE.has(element) and WorldProjectileArt.PALETTE[element] != WorldProjectileArt.PALETTE[&"arcane"], "element has its own palette entry: shadow")
			continue
		check(drawn_elements.has(element), "element has a visual: " + str(element))
	for kind: StringName in [&"death", &"revive", &"area_end", &"cast_cancel", &"teleport"]:
		layer.pulses.clear()
		bridge.emit_confirmed(event(bridge, kind, &"fireball", {"reason":"expire"}))
		check(layer.pulses.size() == 1 and layer.pulses[0].kind == kind, "kind drawn: " + str(kind))
	# Elements: the payload override (Elementalist / Geometer) wins over the skill default.
	for element: StringName in Recipes.ELEMENTS:
		layer.pulses.clear(); layer._on_stage_cleared()
		bridge.emit_confirmed(event(bridge, &"impact", &"elementalist_tri_nova", {"element":String(element)}))
		check(layer.pulses.size() == 1 and layer.pulses[0].element == element, "payload.element selects " + str(element))
	layer.pulses.clear()
	bridge.emit_confirmed(event(bridge, &"impact", &"elementalist_tri_nova", {"element":"bogus"}))
	check(layer.pulses[0].element == &"arcane", "unknown payload.element falls back to the recipe element")
	layer.pulses.clear()
	bridge.emit_confirmed(event(bridge, &"impact", &"totally_unknown_skill"))
	check(layer.pulses.size() == 1 and layer.pulses[0].family == &"impact" and layer.pulses[0].element == &"physical", "unknown skill uses the generic recipe")
	# Kinds that are not feedback.
	layer.pulses.clear()
	bridge.emit_confirmed(event(bridge, &"ui_confirm", &""))
	bridge.emit_confirmed(event(bridge, &"area_end", &"snare_trap", {"reason":"trigger"}))
	bridge.emit_confirmed(event(bridge, &"area_end", &"snare_trap", {"reason":"cleanup"}))
	check(layer.pulses.is_empty(), "ui events and trigger/cleanup area_end draw nothing")
	# Every pulse form draws without error at several ages (draw notification outside a renderer when possible).
	layer.pulses.clear(); layer._on_stage_cleared()
	var kinds: Array = Layer.DRAWN_KINDS.duplicate()
	var smoke := 0
	for skill: StringName in [&"fireball", &"ice_spear", &"lightning", &"slash", &"berserker_blood_rift", &"arrow_rain", &"explosive_trap", &"hunter_freezing_trap", &"elementalist_tri_nova", &"enemy_summon", &"defender_reprisal_wave", &"blood_thirst", &"sentinel_observe", &"warden_charge"]:
		for kind: StringName in kinds:
			layer._advance(0.013)
			if bridge.emit_confirmed(event(bridge, kind, skill, {"radius":50.0, "direction_2d":Vector2(1, 1), "reason":"expire", "effect_radius":70.0})): smoke += 1
			if layer.pulses.size() >= 40:
				layer._canvas.notification(CanvasItem.NOTIFICATION_DRAW)
				layer._advance(0.2)
	layer._canvas.notification(CanvasItem.NOTIFICATION_DRAW)
	check(smoke > 100, "draw smoke exercised %d events" % smoke)
	bridge.queue_free(); (r.host as Node).queue_free(); await process_frame

func _signatures() -> void:
	var r := rig()
	var bridge: PresentationEventBridge = r.bridge
	var layer = r.layer
	var signatures := Recipes.signature_ids()
	check(signatures.size() == 21, "21 signatures listed")
	var with_art := 0
	for sig: StringName in signatures:
		var info := Recipes.signature(sig)
		var skill: StringName = info.skill_id
		var variant: StringName = &"forest_ancient_warden" if str(info.owner).begins_with("forest") else &""
		var extra := {"radius":60.0, "direction_2d":Vector2.RIGHT, "actor_variant":String(variant)} if not variant.is_empty() else {"radius":60.0, "direction_2d":Vector2.RIGHT}
		layer.pulses.clear(); layer._on_stage_cleared(); layer.flipbook_provider = Callable()
		bridge.emit_confirmed(event(bridge, info.kind, skill, extra))
		var pulse: Dictionary = layer.pulses.back() if not layer.pulses.is_empty() else {}
		check(not pulse.is_empty() and pulse.signature == sig, "signature recognised on its own kind: " + str(sig))
		if Layer.SIGNATURE_ART.has(sig) and sig in Layer.SIGNATURE_ART_ON_IMPACT:
			# 15/11 playtest: the sheet plays on the skill's hit; the signature event itself stays code-drawn.
			with_art += 1
			check(pulse.flipbook == &"", "%s signature event is drawn by code (sheet moved to the hit)" % sig)
			layer.pulses.clear(); layer._on_stage_cleared()
			bridge.emit_confirmed(event(bridge, &"impact", skill, extra))
			var hit: Dictionary = layer.pulses.back() if not layer.pulses.is_empty() else {}
			check(not hit.is_empty() and hit.flipbook == Layer.SIGNATURE_ART[sig][0] and hit.signature == &"", "%s plays %s on its impact" % [sig, Layer.SIGNATURE_ART[sig][0]])
			layer._canvas.notification(CanvasItem.NOTIFICATION_DRAW)
		elif Layer.SIGNATURE_ART.has(sig):
			with_art += 1
			var expected: StringName = Layer.SIGNATURE_ART[sig][0]
			check(pulse.flipbook == expected and expected in VfxFlipbookCatalog.ids() and float(pulse.life) >= 0.5, "%s uses flipbook %s" % [sig, expected])
			# Fallback: catalog returns nothing -> still a pulse, drawn by code.
			layer.pulses.clear(); layer._on_stage_cleared()
			layer.flipbook_provider = func(_id: StringName) -> Dictionary: return {}
			bridge.emit_confirmed(event(bridge, info.kind, skill, extra))
			var fallback: Dictionary = layer.pulses.back() if not layer.pulses.is_empty() else {}
			check(not fallback.is_empty() and fallback.flipbook == &"" and fallback.signature == sig, "%s falls back to code when the flipbook is missing" % sig)
			layer._canvas.notification(CanvasItem.NOTIFICATION_DRAW)
			layer.flipbook_provider = Callable()
		else:
			check(pulse.flipbook == &"", "%s is drawn by code (no flipbook mapped)" % sig)
		# The same skill on another kind is not the signature.
		var other: StringName = &"impact" if info.kind != &"impact" else &"melee_swing"
		layer.pulses.clear(); layer._on_stage_cleared()
		bridge.emit_confirmed(event(bridge, other, skill, extra))
		check(layer.pulses.is_empty() or layer.pulses.back().signature == &"", "%s signature does not leak to %s" % [sig, other])
	check(with_art == 21, "all 21 signatures map to flipbooks (%d)" % with_art)
	# Drawing a flipbook pulse at several frames, including the end of the sheet.
	layer.pulses.clear(); layer._on_stage_cleared()
	bridge.emit_confirmed(event(bridge, &"melee_swing", &"slash", {"direction_2d":Vector2.RIGHT}))
	check(layer.pulses.size() == 1 and layer.pulses[0].flipbook == &"slash_arc", "slash uses slash_arc")
	for i: int in 40: # P7-C1: the sheet now plays at the manifest 16 fps (1.0 s); 30 x 0.03 s no longer reaches its end.
		layer._advance(0.03); layer._canvas.notification(CanvasItem.NOTIFICATION_DRAW)
	check(layer.pulses.is_empty(), "flipbook pulse expires with the sheet")
	# Nature trap accent.
	bridge.emit_confirmed(event(bridge, &"trap_trigger", &"hunter_thorn_trap", {"radius":50.0}))
	check(layer.pulses.size() == 1 and layer.pulses[0].flipbook == &"nature_thorns", "nature trap trigger uses the thorns accent")
	layer._canvas.notification(CanvasItem.NOTIFICATION_DRAW)
	_polish_checks(layer)
	bridge.queue_free(); (r.host as Node).queue_free(); await process_frame

## P7-C1 polish: flipbook speed from the manifest, outlines, chevron zoom floor, warm physical sparks.
func _polish_checks(layer) -> void:
	# 1) Every flipbook plays at its manifest suggested_fps (factor 1.0; never above the documented 1.15 ceiling).
	var arts: Array = []
	for sig: StringName in Layer.SIGNATURE_ART: arts.append([String(sig), Layer.SIGNATURE_ART[sig]])
	arts.append(["nature_trap", Layer.NATURE_TRAP_ART])
	for entry: Array in arts:
		var art: Array = entry[1]
		var book := VfxFlipbookCatalog.definition(art[0])
		check(not book.is_empty() and float(art[2]) >= 1.0 and float(art[2]) <= 1.15, "%s speed factor %.2f within [1.0, 1.15]" % [entry[0], float(art[2])])
		check(is_equal_approx(float(art[2]), 1.0), "%s plays at the manifest suggested_fps (factor %.2f)" % [entry[0], float(art[2])])
	var sigs := [[&"melee_swing", &"slash", &"slash_arc"], [&"effect_start", &"terrifying_shout", &"ground_shockwave"], [&"trap_trigger", &"hunter_thorn_trap", &"nature_thorns"], [&"summon", &"enemy_summon", &"summon_portal"],
		[&"impact", &"fireball", &"fire_burst"]]
	for entry: Array in sigs:
		var bridge: PresentationEventBridge = layer.bridge
		layer.pulses.clear(); layer._on_stage_cleared()
		var extra := {"radius":50.0, "direction_2d":Vector2.RIGHT}
		if entry[1] == &"enemy_summon": extra["actor_variant"] = "forest_ancient_warden"
		bridge.emit_confirmed(event(bridge, entry[0], entry[1], extra))
		var pulse: Dictionary = layer.pulses.back() if not layer.pulses.is_empty() else {}
		if pulse.is_empty() or pulse.flipbook == &"": continue # Unmapped skill variants are covered by the signature checks above.
		var def := VfxFlipbookCatalog.definition(pulse.flipbook)
		var expected_life := float(def.frames) / (float(def.suggested_fps) * float(pulse.flip_speed))
		check(is_equal_approx(float(pulse.flip_speed), 1.0) and is_equal_approx(float(pulse.life), expected_life), "%s life %.3f s = frames / suggested_fps (%.3f)" % [pulse.flipbook, float(pulse.life), expected_life])
		check(int(floorf(float(pulse.life) * 0.999 * float(def.suggested_fps))) < int(def.frames), "%s never reads past its last frame before expiring" % pulse.flipbook)
	# 2) Outlines: the stamped outline exists for the palest sheets and is dark; thorns are outlined too.
	for id: StringName in [&"ground_shockwave", &"nature_thorns"]:
		check(Layer.OUTLINE_STAMP.has(id) and id in Layer.OUTLINED, "%s has a stamped outline" % id)
		var edge: Color = Layer.OUTLINE_STAMP[id][1]
		check(edge.get_luminance() < 0.12 and edge.a >= 0.5, "%s outline is dark and visible" % id)
	var offsets := Layer.stamp_offsets(2.2, 1.0)
	check(offsets.size() == Layer.STAMP_DIRECTIONS and is_equal_approx(offsets[0].length(), 2.2), "stamp offsets: %d copies on a circle" % offsets.size())
	check(Layer.stamp_offsets(2.2, 2.0)[0].length() > offsets[0].length(), "stamp grows with the zoom boost")
	check(Layer.NATURE_TRAP_ART[1] >= 100.0, "thorns accent is larger than the old 86 px")
	# 3) Physical sparks: dark edge outermost, hot warm core innermost, edge never lighter than the core.
	var layers := Layer.spark_layers(1.0)
	var outer: Color = layers[0][1]
	var inner: Color = layers[layers.size() - 1][1]
	check(layers.size() >= 3 and float(layers[0][0]) > float(layers[layers.size() - 1][0]), "spark strokes narrow from edge to core")
	check(outer.get_luminance() < 0.2 and inner.get_luminance() > 0.8 and inner.r >= inner.b, "physical sparks: dark edge, hot warm core")
	check(Layer.spark_layers(0.0)[2][1].a == 0.0, "spark layers fade out with the pulse")
	# 4) Chevrons keep a minimum on-screen size when zoomed out, and are not enlarged at high zoom.
	var by_zoom := {}
	for zoom: float in [0.5, 0.75, 1.0, 1.6, 2.0]:
		layer.zoom_override = zoom
		by_zoom[zoom] = layer.chevron_scale()
		var segments: Array = layer.chevron_segments(Vector2.ZERO, Vector2.RIGHT, layer.chevron_scale())
		var arm: float = (segments[0][1] - segments[0][0]).length()
		var base_arm: float = ((layer.chevron_segments(Vector2.ZERO, Vector2.RIGHT, 1.0) as Array)[0][1] - (layer.chevron_segments(Vector2.ZERO, Vector2.RIGHT, 1.0) as Array)[0][0]).length()
		check(arm * zoom >= base_arm * minf(zoom, Layer.CHEVRON_ZOOM_FLOOR) - 0.001, "chevron arm on screen at zoom %.2f keeps >= min(zoom, floor) of its size" % zoom)
	check(by_zoom[0.5] >= 1.7 and by_zoom[0.5] <= Layer.CHEVRON_SCALE_MAX, "chevrons are enlarged at 50%% zoom (x%.2f)" % by_zoom[0.5])
	check(is_equal_approx(by_zoom[1.0], 1.0) and is_equal_approx(by_zoom[1.6], 1.0) and is_equal_approx(by_zoom[2.0], 1.0), "chevrons keep their size from 100%% up")
	check(by_zoom[0.5] * 0.5 >= Layer.CHEVRON_ZOOM_FLOOR - 0.001, "on-screen chevron size at 50%% reaches the floor")
	layer.zoom_override = 0.05
	check(layer.chevron_scale() == Layer.CHEVRON_SCALE_MAX, "chevron scale is capped at extreme zoom-out")
	layer.zoom_override = 0.0
	var narrow: Array = layer.chevron_segments(Vector2.ZERO, Vector2.RIGHT, 1.0)
	var wide: Array = layer.chevron_segments(Vector2.ZERO, Vector2.RIGHT, 1.7)
	check(narrow.size() == 6 and wide.size() == 6 and (wide[0][0] - wide[0][1]).length() > (narrow[0][0] - narrow[0][1]).length() * 1.6, "chevron segments scale with k")
	var bridge: PresentationEventBridge = layer.bridge
	layer.zoom_override = 0.5
	layer.pulses.clear(); layer._on_stage_cleared()
	bridge.emit_confirmed(event(bridge, &"charge_start", &"enemy_charge", {"direction_2d":Vector2.RIGHT, "duration":0.9}))
	layer._canvas.notification(CanvasItem.NOTIFICATION_DRAW)
	for kind: StringName in [&"impact", &"effect_start", &"trap_trigger"]:
		bridge.emit_confirmed(event(bridge, kind, &"enemy_claw" if kind == &"impact" else &"terrifying_shout", {"radius":50.0}))
	layer._canvas.notification(CanvasItem.NOTIFICATION_DRAW)
	layer.zoom_override = 0.0
	layer.pulses.clear(); layer._on_stage_cleared()

## P7-C4: no redraw while idle, one clearing redraw when the last pulse expires, flipbooks preloaded on configure.
func _idle_redraw_and_preload() -> void:
	VfxFlipbookCatalog._preloaded.clear()
	check(VfxFlipbookCatalog.preloaded_ids().is_empty(), "flipbooks start unloaded in this process state")
	var r := rig()
	var bridge: PresentationEventBridge = r.bridge
	var host: Host = r.host
	var layer = r.layer
	var ready_ids := VfxFlipbookCatalog.preloaded_ids()
	check(ready_ids.size() == VfxFlipbookCatalog.ids().size(), "configure preloads all %d P6 flipbooks (%d ready)" % [VfxFlipbookCatalog.ids().size(), ready_ids.size()])
	for id: StringName in VfxFlipbookCatalog.ids():
		check(VfxFlipbookCatalog.texture(id) != null and id in ready_ids, "flipbook %s preloaded with a valid texture" % id)
		check(VfxFlipbookCatalog.texture(id) == VfxFlipbookCatalog._preloaded.get(id), "flipbook %s reuses its validated resident texture" % id)
	check(VfxFlipbookCatalog.preload_all().size() == ready_ids.size(), "preload is idempotent")
	if DisplayServer.get_name() == "headless":
		check(not Layer._canvas_warmup_scheduled, "headless configuration skips the offscreen draw")
	check(VfxFlipbookCatalog.texture(&"no_such_book") == null and not &"no_such_book" in VfxFlipbookCatalog.preloaded_ids(), "unknown flipbook stays fail-closed after preload")
	layer.flipbook_provider = func(_id: StringName) -> Dictionary: return {}
	check(layer.flipbook(&"fire_burst").is_empty(), "missing flipbook still fails closed (provider hook)")
	layer.flipbook_provider = Callable()
	# Idle: zero pulses, many advances, no redraw request.
	var base_requests: int = layer.redraw_requests
	for i: int in 120: bridge.world_advanced.emit(1.0 / 60.0)
	check(layer.pulses.is_empty() and layer.redraw_requests == base_requests, "idle layer with zero pulses requests no redraw (%d)" % (layer.redraw_requests - base_requests))
	# A pulse: redraws while alive, then exactly one clearing redraw at expiry, then silence.
	bridge.emit_confirmed(event(bridge, &"melee_swing", &"slash", {"direction_2d":Vector2.RIGHT}))
	check(layer.pulses.size() == 1 and layer.redraw_requests == base_requests + 1, "a new pulse requests a redraw")
	var life: float = layer.pulses[0].life
	bridge.world_advanced.emit(life * 0.5)
	check(layer.redraw_requests == base_requests + 2 and layer.pulses.size() == 1, "a live pulse redraws on advance")
	bridge.world_advanced.emit(life)
	check(layer.pulses.is_empty() and layer.redraw_requests == base_requests + 3, "expiry of the last pulse requests exactly one clearing redraw")
	for i: int in 60: bridge.world_advanced.emit(1.0 / 60.0)
	check(layer.redraw_requests == base_requests + 3, "no redraw after the clear")
	# Stage change and passive clear still redraw once.
	bridge.emit_confirmed(event(bridge, &"melee_swing", &"slash", {"direction_2d":Vector2.RIGHT}))
	var before_stage: int = layer.redraw_requests
	bridge.begin_stage("idle_next", true)
	check(layer.pulses.is_empty() and layer.redraw_requests > before_stage, "stage change still clears with a redraw")
	bridge.emit_confirmed(event(bridge, &"melee_swing", &"slash", {"direction_2d":Vector2.RIGHT}))
	host.snapshot_passive = true
	var before_passive: int = layer.redraw_requests
	layer._process(0.0)
	check(layer.pulses.is_empty() and layer.redraw_requests == before_passive + 1, "passive staging clears with one redraw")
	layer._process(0.0)
	check(layer.redraw_requests == before_passive + 1, "passive staging does not redraw while already empty")
	host.snapshot_passive = false
	layer.dispose()
	bridge.queue_free(); host.queue_free(); await process_frame

func _flood_and_lifecycle() -> void:
	var r := rig()
	var bridge: PresentationEventBridge = r.bridge
	var host: Host = r.host
	var layer = r.layer
	# Flood: many targets at the same instant.
	for i: int in 12: bridge.emit_confirmed(event(bridge, &"impact", &"fire_wall"))
	check(layer.pulses.size() == Layer.IMPACT_PER_WINDOW, "impact flood: %d per skill per window" % Layer.IMPACT_PER_WINDOW)
	bridge.emit_confirmed(event(bridge, &"impact", &"ice_wall"))
	check(layer.pulses.size() == Layer.IMPACT_PER_WINDOW + 1, "another skill has its own window")
	bridge.world_advanced.emit(Layer.IMPACT_WINDOW + 0.01)
	var before: int = layer.pulses.size()
	for i: int in 5: bridge.emit_confirmed(event(bridge, &"impact", &"fire_wall"))
	check(layer.pulses.size() == before + Layer.IMPACT_PER_WINDOW, "window reopens after %.2f s" % Layer.IMPACT_WINDOW)
	# Same target gap, periodic gap.
	layer.pulses.clear(); layer._on_stage_cleared()
	var first := event(bridge, &"impact", &"fireball", {"target_id":"7"})
	bridge.emit_confirmed(first)
	bridge.world_advanced.emit(Layer.IMPACT_WINDOW + 0.001)
	bridge.emit_confirmed(event(bridge, &"impact", &"fireball", {"target_id":"7"}))
	check(layer.pulses.size() == 1, "same skill + target inside %.2f s is merged" % Layer.TARGET_GAP)
	bridge.world_advanced.emit(Layer.TARGET_GAP)
	bridge.emit_confirmed(event(bridge, &"impact", &"fireball", {"target_id":"7"}))
	check(layer.pulses.size() == 2, "same target draws again after the gap")
	layer.pulses.clear(); layer._on_stage_cleared()
	bridge.emit_confirmed(event(bridge, &"impact", &"burn_tick", {"target_id":"9"}))
	bridge.world_advanced.emit(Layer.TARGET_GAP + 0.05)
	bridge.emit_confirmed(event(bridge, &"impact", &"burn_tick", {"target_id":"9"}))
	check(layer.pulses.size() == 1, "periodic (DOT) ticks use the longer %.2f s gap" % Layer.PERIODIC_GAP)
	bridge.world_advanced.emit(Layer.PERIODIC_GAP)
	bridge.emit_confirmed(event(bridge, &"impact", &"burn_tick", {"target_id":"9"}))
	check(not layer.pulses.is_empty() and is_zero_approx(float(layer.pulses.back().age)), "DOT draws again after the long gap")
	# CAP and memory bound.
	layer.pulses.clear(); layer._on_stage_cleared()
	for i: int in 400:
		bridge.world_advanced.emit(0.001)
		bridge.emit_confirmed(event(bridge, &"melee_swing", &"slash", {"direction_2d":Vector2.RIGHT}))
		bridge.emit_confirmed(event(bridge, &"impact", StringName("flood_%d" % (i % 90)), {"target_id":str(i)}))
	check(layer.pulses.size() <= Layer.CAP and Layer.CAP == 48, "pulses bounded by CAP (%d)" % layer.pulses.size())
	check(layer._last_hit.size() <= Layer.FLOOD_MEMORY and layer._windows.size() <= 100, "flood memory bounded")
	# Clock: impacts after enough virtual time are accepted again; pause freezes the visual clock and ages.
	layer.pulses.clear(); layer._on_stage_cleared()
	bridge.emit_confirmed(event(bridge, &"melee_swing", &"slash", {"direction_2d":Vector2.RIGHT}))
	bridge.world_advanced.emit(0.1)
	var age: float = layer.pulses[0].age
	var clock: float = layer._clock
	paused = true
	bridge.world_advanced.emit(0.1)
	check(is_equal_approx(layer.pulses[0].age, age) and is_equal_approx(layer._clock, clock), "paused world freezes pulse age and flood clock")
	check(not bridge.emit_confirmed(event(bridge, &"impact", &"fireball")), "paused bridge publishes no impact")
	var added: int = layer.pulses.size()
	layer._event(event(bridge, &"impact", &"fireball"))
	check(layer.pulses.size() == added, "layer ignores events while the tree is paused")
	paused = false
	# Passive staging.
	host.snapshot_passive = true
	layer._event(event(bridge, &"impact", &"fireball"))
	layer._process(0.0)
	check(layer.pulses.is_empty(), "passive staging rejects and clears transients")
	host.snapshot_passive = false
	# Stage change.
	bridge.emit_confirmed(event(bridge, &"melee_swing", &"slash", {"direction_2d":Vector2.RIGHT}))
	bridge.begin_stage("next", true)
	check(layer.pulses.is_empty() and layer._last_hit.is_empty() and layer._windows.is_empty(), "stage change clears pulses and flood memory; resume replays nothing")
	# Lifetimes bounded.
	var longest := 0.0
	for kind: StringName in Layer.DRAWN_KINDS:
		layer.pulses.clear()
		bridge.emit_confirmed(event(bridge, kind, &"enemy_summon", {"reason":"expire"}))
		for pulse: Dictionary in layer.pulses: longest = maxf(longest, float(pulse.life))
	check(longest > 0.0 and longest <= 1.6, "pulse lifetimes bounded (max %.2f s)" % longest)
	# Dispose idempotent; the old bridge cannot draw after rebinding.
	layer.dispose(); layer.dispose()
	check(layer.pulses.is_empty() and bridge.event_confirmed.get_connections().is_empty() and bridge.world_advanced.get_connections().is_empty(), "dispose is idempotent and disconnects both listeners")
	bridge.queue_free(); host.queue_free(); await process_frame

func _determinism_and_orientation() -> void:
	var a := rig()
	var b := rig()
	var same := event(a.bridge, &"impact", &"ice_spear", {"target_id":"1"})
	var twin: Dictionary = same.duplicate(true); twin.payload.presentation_epoch = (b.bridge as PresentationEventBridge).current_epoch(); twin.stage_id = (b.bridge as PresentationEventBridge).stage_id
	a.bridge.emit_confirmed(same); b.bridge.emit_confirmed(twin)
	check(a.layer.pulses.size() == 1 and b.layer.pulses.size() == 1 and a.layer.pulses[0] == b.layer.pulses[0], "same event -> identical pulse (deterministic)")
	var different := event(a.bridge, &"impact", &"ice_spear", {"target_id":"2"})
	a.bridge.emit_confirmed(different)
	check(a.layer.pulses.back().seed != a.layer.pulses[0].seed, "different event_id -> different jitter seed")
	# RNG and clocks untouched.
	seed(4242); var expected := randi()
	seed(4242)
	for i: int in 30:
		a.bridge.emit_confirmed(event(a.bridge, &"melee_swing", &"slash", {"direction_2d":Vector2.from_angle(float(i))}))
		a.layer._advance(0.01); a.layer._canvas.notification(CanvasItem.NOTIFICATION_DRAW)
	check(randi() == expected, "layer never consumes the global RNG")
	# Orientation: slash direction.
	a.layer.pulses.clear(); a.layer._on_stage_cleared()
	a.bridge.emit_confirmed(event(a.bridge, &"melee_swing", &"slash", {"direction_2d":Vector2.RIGHT}))
	a.bridge.emit_confirmed(event(a.bridge, &"melee_swing", &"slash", {"direction_2d":Vector2.UP}))
	check(a.layer.pulses[0].dir.is_equal_approx(Vector2.RIGHT) and a.layer.pulses[1].dir.is_equal_approx(Vector2.UP), "flat arena swing follows the payload direction")
	for pair: Array in [[a], [b]]:
		(pair[0].bridge as Node).queue_free(); (pair[0].host as Node).queue_free()
	await process_frame

func _projectile_art() -> void:
	var seen := {}
	var cases := [[MageProjectile, &"fireball", &"orb"], [MageProjectile, &"fire_spear", &"spear"], [MageProjectile, &"ice_spear", &"spear"], [MageProjectile, &"lightning", &"bolt"],
		[MageProjectile, &"electric_discharge", &"bolt"], [MageProjectile, &"basic_attack", &"orb"], [PlayerProjectile, &"basic_attack", &"arrow"], [PlayerProjectile, &"double_shot", &"arrow"],
		[PlayerProjectile, &"slowing_arrow", &"arrow"], [SentinelProjectile, &"sentinel_headshot", &"sentinel_headshot"], [SentinelProjectile, &"sentinel_piercing_shot", &"sentinel_piercing_shot"],
		[SentinelProjectile, &"sentinel_net_shot", &"sentinel_net_shot"], [SentinelProjectile, &"sentinel_explosive_shot", &"sentinel_explosive_shot"], [SentinelProjectile, &"sentinel_concussion_shot", &"sentinel_concussion_shot"],
		[ArrowProjectile, &"enemy_arrow", &"arrow"], [ArrowProjectile, &"basic_attack", &"arrow"]]
	for entry: Array in cases:
		var projectile: Node = entry[0].new()
		var request := DamageRequest.new(); request.skill_id = entry[1]
		projectile.request = request
		var spec := Art.spec(projectile)
		check(spec.shape == entry[2], "%s %s -> %s (%s)" % [projectile.get_class(), entry[1], spec.shape, entry[2]])
		check(spec.element in Recipes.ELEMENTS and spec.core is Color and spec.glow is Color, "projectile spec has a palette: " + str(entry[1]))
		seen[str(spec.shape) + "/" + str(spec.element)] = true
		if entry[1] == &"enemy_arrow": check(spec.hostile, "enemy arrow is marked hostile")
		projectile.free()
	for element: StringName in [&"fire", &"ice", &"lightning"]:
		var trace := GeometerTraceProjectile.new(); trace.request = DamageRequest.new(); trace.request.skill_id = &"geometer_trace"; trace.element = element
		var spec := Art.spec(trace)
		check(spec.shape == &"trace" and spec.element == element and spec.core == Art.PALETTE[element][0], "geometer trace keeps its element look: " + str(element))
		trace.free()
	check(seen.size() >= 10, "projectile silhouettes are distinct (%d)" % seen.size())
	var fire_node := _projectile_for(&"fireball"); var ice_node := _projectile_for(&"ice_spear")
	var fire := Art.spec(fire_node); var ice := Art.spec(ice_node)
	check(fire.core != ice.core, "fire and ice projectiles differ in colour")
	fire_node.free(); ice_node.free()
	# Mage nodes keep the 2D identity colour.
	var mage := MageProjectile.new(); mage.request = DamageRequest.new(); mage.request.skill_id = &"fireball"; mage.color = Color("123456")
	check(Art.spec(mage).core == Color("123456"), "mage projectile uses its own tint")
	mage.free()
	# 2D legacy drawers stay quiet in the spatial world (no stray draw at the node origin).
	for script_path: String in ["res://scripts/actors/mage_projectile.gd", "res://scripts/actors/sentinel_projectile.gd"]:
		check(FileAccess.get_file_as_string(script_path).contains("if world_flight != null: return"), "legacy drawer guards spatial flights: " + script_path)
	# Element on the geometer launch payload (bridge side).
	var bridge := PresentationEventBridge.new()
	for element: StringName in [&"fire", &"ice", &"lightning"]:
		var trace := GeometerTraceProjectile.new(); trace.element = element
		var payload := {}
		bridge._projectile_element(trace, payload)
		check(payload.get("element") == String(element), "geometer launch payload carries element " + str(element))
		trace.free()
	var plain := PlayerProjectile.new(); var payload := {}
	bridge._projectile_element(plain, payload)
	check(not payload.has("element"), "non-geometer projectile adds no element")
	plain.free(); bridge.free()

func _projectile_for(skill: StringName) -> Node:
	var projectile := MageProjectile.new(); projectile.request = DamageRequest.new(); projectile.request.skill_id = skill
	projectile.color = Color.RED if skill == &"fireball" else Color.BLUE
	return projectile

## P7-C5: basic attacks have no launch burst and a brief white hit burst for every class; the movement path trace is gone.
func _basic_attack_and_trace() -> void:
	var r := rig()
	var bridge: PresentationEventBridge = r.bridge
	var layer = r.layer
	for variant: String in ["archer", "mage"]:
		layer.pulses.clear(); layer._on_stage_cleared()
		bridge.emit_confirmed(event(bridge, &"projectile_launch", &"basic_attack", {"source_variant":variant, "direction_2d":Vector2.RIGHT}))
		check(layer.pulses.is_empty(), "basic attack has no launch burst: " + variant)
	layer.pulses.clear(); layer._on_stage_cleared()
	bridge.emit_confirmed(event(bridge, &"projectile_launch", &"double_shot", {"source_variant":"archer", "direction_2d":Vector2.RIGHT}))
	check(layer.pulses.size() == 1, "a skill (double_shot) keeps its launch burst")
	for entry: Array in [[&"basic_attack", "archer"], [&"basic_attack", "mage"], [&"basic_attack", "swordsman"], [&"enemy_claw", ""]]:
		layer.pulses.clear(); layer._on_stage_cleared()
		var payload := {"direction_2d":Vector2.RIGHT}
		if entry[1] != "": payload["source_variant"] = entry[1]
		bridge.emit_confirmed(event(bridge, &"impact", entry[0], payload))
		var pulse: Dictionary = layer.pulses.back() if not layer.pulses.is_empty() else {}
		check(not pulse.is_empty() and bool(pulse.basic_hit) and float(pulse.life) >= 0.15 and float(pulse.life) <= 0.2, "basic hit has the short white burst: %s/%s" % [entry[0], entry[1]])
		layer._canvas.notification(CanvasItem.NOTIFICATION_DRAW)
		layer._advance(0.09); layer._canvas.notification(CanvasItem.NOTIFICATION_DRAW)
		layer._advance(0.2)
		check(layer.pulses.is_empty(), "basic hit burst expires within 0.2 s: " + String(entry[0]))
	layer.pulses.clear(); layer._on_stage_cleared()
	bridge.emit_confirmed(event(bridge, &"impact", &"fireball", {"source_variant":"mage"}))
	check(not bool(layer.pulses.back().basic_hit) and float(layer.pulses.back().life) > 0.3, "signature/skill hits keep their own art")
	# P7-C7: every class auto-attack id (basic_attack for all ten classes/evolutions, plus the enemy claw and arrow) draws the white hit.
	for owner: StringName in FeedbackRecipeCatalog.BASIC_ATTACK_OWNERS:
		for skill: StringName in [&"basic_attack", &""]:
			layer.pulses.clear(); layer._on_stage_cleared()
			bridge.emit_confirmed(event(bridge, &"impact", skill, {"source_variant":String(owner), "direction_2d":Vector2.RIGHT}))
			var own: Dictionary = layer.pulses.back() if not layer.pulses.is_empty() else {}
			check(not own.is_empty() and bool(own.white_hit) and bool(own.basic_hit) and float(own.life) <= 0.2, "class auto-attack draws the white hit: %s/%s" % [owner, skill])
	layer.pulses.clear(); layer._on_stage_cleared()
	bridge.emit_confirmed(event(bridge, &"impact", &"enemy_arrow", {"source_variant":"forest_canopy_archer", "direction_2d":Vector2.RIGHT}))
	check(layer.pulses.size() == 1 and bool(layer.pulses.back().white_hit), "enemy arrow hit draws the white hit")
	bridge.emit_confirmed(event(bridge, &"projectile_launch", &"enemy_arrow", {"source_variant":"forest_canopy_archer", "direction_2d":Vector2.RIGHT}))
	check(layer.pulses.size() == 1, "enemy arrow has no launch burst")
	# Ordinary physical skill hits use the white burst too (no ray burst); elements keep their own art; no physical impact reaches the ray drawer.
	for skill: StringName in [&"brutal_strike", &"double_shot", &"slash", &"piercing_arrow", &"defender_riposte", &"sentinel_piercing_shot", &"hunter_exploit", &"totally_unknown"]:
		layer.pulses.clear(); layer._on_stage_cleared()
		bridge.emit_confirmed(event(bridge, &"impact", skill, {"direction_2d":Vector2.RIGHT}))
		var skill_pulse: Dictionary = layer.pulses.back() if not layer.pulses.is_empty() else {}
		check(not skill_pulse.is_empty() and bool(skill_pulse.white_hit) and float(skill_pulse.life) <= 0.2, "physical skill hit draws the white burst, no rays: " + String(skill))
	for skill: StringName in [&"fire_spear", &"ice_spear", &"lightning", &"berserker_rupture_detonation", &"slowing_arrow"]:
		layer.pulses.clear(); layer._on_stage_cleared()
		bridge.emit_confirmed(event(bridge, &"impact", skill, {"direction_2d":Vector2.RIGHT}))
		check(not layer.pulses.is_empty() and not bool(layer.pulses.back().white_hit) and float(layer.pulses.back().life) > 0.3, "element hit keeps its own art: " + String(skill))
	# Deterministic: the burst is a pure function of the event (same id -> same seed).
	check(Layer.BASIC_HIT_LIFE <= 0.2 and Layer.BASIC_RAYS <= 8, "burst stays small and within the pulse caps")
	bridge.queue_free(); (r.host as Node).queue_free(); await process_frame
	# Movement trace: the view keeps only the target marker; passing a path draws and stores nothing.
	var view := ExpeditionGeometryView.new()
	var point := ExpeditionWorldPoint.create(&"s", &"surface", Vector3(10, 0, 10))
	view.indicate(point, true, [{"position":Vector3.ZERO}, {"position":Vector3(10, 0, 10)}])
	check(view.marker != null and view.marker_valid and view.get("route") == null, "target marker kept; no movement path state remains")
	view.indicate(null, false)
	check(view.marker == null and not view.marker_valid, "marker lifecycle unchanged (cleared by indicate(null))")
	# A rejected destination clears an earlier aim preview and leaves the invalid marker.
	var target := ExpeditionWorldPoint.create(point.stage_id, point.surface_id, Vector3(40, 0, 40))
	view.set_attack_preview(point, target, &"fire_spear")
	check(not view.attack_preview.is_empty(), "the view stores the aim preview before the rejected destination")
	view.indicate(point, false)
	check(view.marker != null and not view.marker_valid and view.attack_preview.is_empty(), "invalid destination keeps only the invalid marker; no aim preview survives")
	view.indicate(null, false)
	check(view.marker == null and view.attack_preview.is_empty(), "invalid marker lifecycle: cleared with indicate(null)")
	view.free()

func _spatial() -> void:
	var sample: Node2D = load("res://tests/fixtures/e07/f1/presentation_sample.tscn").instantiate()
	root.add_child(sample); sample.set_process(false)
	var controller: RunController = sample.controller
	var bridge := controller.presentation_events()
	var layer: Control = bridge.get_node("E08PilotFeedback")
	check(layer.get_script() == Layer and layer is Base and layer._canvas is Node2D and layer._canvas.get_parent() == layer, "the spatial controller installs the recipe layer under the pilot name, painting on a Node2D child (a Control does not paint in the world canvas)")
	var view: ExpeditionGeometryView = sample.view
	var lower: Vector3 = sample.lower.world_point().position
	var upper: Vector3 = sample.upper.world_point().position
	check(not view.point_visible(lower) and view.point_visible(upper), "fixture has occluded lower anchor and visible upper anchor")
	var snapshot := _gameplay_state(controller, sample)
	seed(77); var expected := randi(); seed(77)
	# Occlusion and anchoring.
	var hidden := event(bridge, &"impact", &"fireball"); hidden.position = lower; hidden.payload.erase("position_unavailable"); hidden.payload.erase("legacy_position_2d")
	bridge.emit_confirmed(hidden)
	check(layer.pulses.is_empty(), "occluded anchor draws nothing")
	for kind: StringName in [&"melee_swing", &"area_start", &"effect_start", &"trap_trigger", &"summon", &"charge_start", &"heal", &"movement"]:
		var ev := event(bridge, kind, &"slash", {"direction":Vector3(1, 0, 0), "radius":60.0}); ev.position = lower; ev.payload.erase("position_unavailable"); ev.payload.erase("legacy_position_2d")
		bridge.emit_confirmed(ev)
	check(layer.pulses.is_empty(), "every new kind respects occlusion")
	var visible := event(bridge, &"melee_swing", &"slash", {"direction":Vector3(1, 0, 0)}); visible.position = upper; visible.payload.erase("position_unavailable"); visible.payload.erase("legacy_position_2d")
	bridge.emit_confirmed(visible)
	check(layer.pulses.size() == 1 and layer._canvas.z_index == Layer.Z_SPATIAL and not layer._canvas.z_as_relative, "visible anchor draws above actors in the spatial world (z %d)" % layer._canvas.z_index)
	var expected_dir := ExpeditionGeometryView.project(Vector3(1, 0, 0)).normalized()
	check(layer.pulses[0].dir.is_equal_approx(expected_dir) and layer.pulses[0].flipbook == &"slash_arc", "spatial swing rotates by the projected ground direction")
	check(layer._canvas.z_index < 4090 and layer._canvas.z_index > 4000, "layer sits below the view marker/route layer (4090)")
	layer._canvas.notification(CanvasItem.NOTIFICATION_DRAW)
	# Legacy 2D path in the same layer.
	var flat := event(bridge, &"impact", &"fireball")
	bridge.emit_confirmed(flat)
	check(layer._canvas.z_index == Layer.Z_FLAT, "flat arena events use the low z (%d)" % layer._canvas.z_index)
	# Element hint: Elementalist call site -> impact payload.
	var events: Array[Dictionary] = []
	bridge.event_confirmed.connect(func(e: Dictionary) -> void: events.append(e))
	var request := DamageRequest.new(); request.source_id = 7; request.target_id = sample.upper.get_instance_id(); request.skill_id = &"elementalist_tri_nova"; request.magic_damage = 5.0; request.accuracy_mode = DamageRequest.AccuracyMode.GEOMETRY
	bridge.note_element(sample.upper, &"ice")
	sample.upper.health.apply(request, 0.5, 1.0)
	var hit: Dictionary = events.back() if not events.is_empty() else {}
	check(hit.get("kind") == &"impact" and hit.payload.get("element") == "ice", "same-frame element hint reaches the impact payload")
	check(Recipes.for_event(hit).element == &"ice", "recipe uses the hinted element")
	events.clear()
	sample.upper.health.apply(request.copy(), 0.5, 1.0)
	check(not events.is_empty() and not events.back().payload.has("element"), "no hint -> no element")
	bridge.note_element(sample.upper, &"bogus")
	check(bridge._element_hints.is_empty(), "invalid element hint rejected")
	for i: int in 100: bridge.note_element(sample.upper, &"fire")
	check(bridge._element_hints.size() <= PresentationEventBridge.ELEMENT_HINT_LIMIT, "element hints bounded")
	# World pulses (Elementalist) and arc link in the spatial world.
	var painter: BattleIndicators
	view.show_elementalist_pulse(&"elementalist_flame_burst", lower, 60.0, &"fire")
	check(not is_instance_valid(view._world_pulses) or view._world_pulses.elementalist_pulses.is_empty(), "occluded Elementalist pulse is not drawn")
	view.show_elementalist_pulse(&"elementalist_flame_burst", upper, 60.0, &"fire")
	view.show_elementalist_pulse(&"elementalist_glacial_ring", upper, 60.0, &"ice")
	view.show_elementalist_pulse(&"elementalist_lightning_arc", upper, 30.0, &"lightning")
	painter = view._world_pulses
	check(painter != null and painter.elementalist_pulses.size() == 3 and painter.get_parent() == view._effects, "Elementalist pulses are drawn in the world effects layer")
	check(is_equal_approx(float(painter.elementalist_pulses[0].radius), 60.0 * ExpeditionGeometryView.GROUND_SCREEN_SCALE) and painter.elementalist_pulses[0].center == ExpeditionGeometryView.project(upper), "pulse is projected onto the ground anchor")
	view.show_elementalist_arc_link(upper + Vector3.UP * 20.0, upper + Vector3(60, 20, 0))
	check(painter.elementalist_arc_links.size() == 1, "lightning arc link is drawn in the world")
	check(view._effects.z_index == 4090 and painter.z_index == 0, "pulse painter inherits the effects layer order")
	check(controller.battle_indicators.elementalist_pulses.is_empty(), "flat-arena indicators are untouched by world pulses")
	painter.process_mode = Node.PROCESS_MODE_PAUSABLE
	for i: int in 70: view.show_elementalist_pulse(&"elementalist_flame_burst", upper, 60.0, &"fire")
	check(painter.elementalist_pulses.size() <= BattleIndicators.ELEMENTALIST_MAX_PULSES, "world pulses are bounded")
	controller.snapshot_passive = true
	var queued := painter.elementalist_pulses.size()
	view.show_elementalist_pulse(&"elementalist_flame_burst", upper, 60.0, &"fire")
	check(painter.elementalist_pulses.size() == queued, "passive staging draws no world pulse")
	controller.snapshot_passive = false
	view.clear_world_pulses()
	check(painter.elementalist_pulses.is_empty() and painter.elementalist_arc_links.is_empty(), "clear_world_pulses empties the painter")
	# Pulse ageing follows the pausable process (frozen while paused).
	view.show_elementalist_pulse(&"elementalist_flame_burst", upper, 60.0, &"fire")
	var remaining: float = painter.elementalist_pulses[0].remaining
	paused = true
	painter._process(0.2)
	check(is_equal_approx(float(painter.elementalist_pulses[0].remaining), remaining), "paused tree freezes world pulses")
	paused = false
	painter._process(0.2)
	check(float(painter.elementalist_pulses[0].remaining) < remaining, "world pulses age with the world clock")
	# Nothing above changed the simulation.
	var after := _gameplay_state(controller, sample)
	after[0] = snapshot[0] # The deliberate hint damage above changed HP; compared separately.
	if after != snapshot: print("STATE_DIFF ", snapshot, " -> ", after)
	check(after == snapshot, "gameplay state (SP, positions, cooldowns, RNG state) unchanged by the layer, pulses and hints")
	check(randi() == expected, "global RNG untouched")
	# Last: awaiting a frame lets the boss AI run, so the stale-hint probe goes after the state comparison.
	events.clear()
	bridge.note_element(sample.upper, &"fire")
	await process_frame
	sample.upper.health.apply(request.copy(), 0.5, 1.0)
	check(not events.is_empty() and not events.back().payload.has("element"), "a stale hint is ignored on later frames")
	sample.queue_free(); await process_frame

func _gameplay_state(controller: RunController, sample: Node2D) -> Array:
	var player := controller.player
	return [sample.upper.health.current_hp, player.health.current_hp, player.current_sp, player.world_point().position, sample.lower.world_point().position, sample.upper.world_point().position, controller.rng.state, player.attack_cooldown]

## 15/11 playtest: Dissipation on its placed point, Tri-Nova element hit sheets, Covering Shot sheet on the hit
## facing the shot, leap/recoil trails along the confirmed travel, and the leap sheet on the landing.
func _playtest_1115() -> void:
	var r := rig()
	var bridge: PresentationEventBridge = r.bridge
	var layer = r.layer
	# Dissipation: legacy target point wins over the caster; without one it stays on the caster.
	bridge.emit_confirmed(event(bridge, &"effect_start", &"spiritualist_dissipation", {"legacy_target_2d":Vector2(210, 90)}))
	check(layer.pulses.size() == 1 and layer.pulses[0].position == Vector2(210, 90) and layer.pulses[0].flipbook == &"spirit_dissipation", "dissipation sheet drawn on the placed point")
	layer.pulses.clear()
	bridge.emit_confirmed(event(bridge, &"effect_start", &"spiritualist_dissipation"))
	check(layer.pulses.size() == 1 and layer.pulses[0].position == Vector2(50, 50), "dissipation without a target point stays on the caster")
	layer.pulses.clear()
	bridge.emit_confirmed(event(bridge, &"effect_start", &"terrifying_shout", {"legacy_target_2d":Vector2(210, 90)}))
	check(layer.pulses.size() == 1 and layer.pulses[0].position == Vector2(50, 50), "other commit effects ignore the cast point")
	var anchored := {"kind":&"effect_start", "skill_id":&"spiritualist_dissipation", "stage_id":bridge.stage_id, "position":Vector3(1, 0, 1),
		"payload":{"target_anchor":{"stage_id":bridge.stage_id, "surface_id":"s", "position":Vector3(40, 0, 20)}}}
	check(layer._world_anchor(anchored) == Vector3(40, 0, 20), "world dissipation uses the confirmed target anchor")
	anchored.payload.target_anchor.stage_id = "elsewhere"
	check(layer._world_anchor(anchored) == Vector3(1, 0, 1), "an anchor from another stage is ignored")
	# Tri-Nova hits reuse the painted element sheets; other elements stay code-drawn.
	var books := {&"fire":&"fire_burst", &"ice":&"ice_shatter", &"lightning":&"lightning_burst"}
	for element: StringName in books:
		layer.pulses.clear(); layer._on_stage_cleared()
		bridge.emit_confirmed(event(bridge, &"impact", &"elementalist_tri_nova", {"element":String(element)}))
		check(layer.pulses.size() == 1 and layer.pulses[0].flipbook == books[element], "tri-nova %s hit uses %s" % [element, books[element]])
	layer.pulses.clear(); layer._on_stage_cleared()
	bridge.emit_confirmed(event(bridge, &"impact", &"elementalist_tri_nova", {"element":"arcane"}))
	check(layer.pulses.size() == 1 and layer.pulses[0].flipbook == &"", "tri-nova arcane hit stays code-drawn")
	layer._canvas.notification(CanvasItem.NOTIFICATION_DRAW)
	# Covering Shot: launch is code-drawn; the hit plays the sheet facing launch -> target.
	layer.pulses.clear(); layer._on_stage_cleared()
	bridge.emit_confirmed(event(bridge, &"projectile_launch", &"hunter_covering_shot", {"direction_2d":Vector2.RIGHT}, Vector2(50, 50)))
	check(layer.pulses.size() == 1 and layer.pulses[0].flipbook == &"", "covering shot launch has no sheet")
	bridge.emit_confirmed(event(bridge, &"impact", &"hunter_covering_shot", {}, Vector2(50, 150)))
	var hit: Dictionary = layer.pulses.back()
	check(hit.flipbook == &"covering_shot" and hit.position == Vector2(50, 150) and (hit.dir as Vector2).is_equal_approx(Vector2.DOWN), "covering shot sheet on the target, facing the shot")
	layer._canvas.notification(CanvasItem.NOTIFICATION_DRAW)
	# Recoil trail: emitted after arriving, drawn back to where the shot was taken.
	layer.pulses.clear(); layer._on_stage_cleared()
	bridge.emit_confirmed(event(bridge, &"movement", &"hunter_covering_shot", {"direction_2d":Vector2.LEFT, "travel_distance":60.0, "phase":"end"}, Vector2(100, 50)))
	var recoil: Dictionary = layer.pulses.back()
	check(recoil.get("trail") == &"recoil" and (recoil.travel as Vector2).is_equal_approx(Vector2(-60, 0)) and (recoil.trail_start as Vector2).is_equal_approx(Vector2(160, 50)), "recoil trail spans the confirmed travel back to the shot")
	# Leap: trail from take-off, sheet waits for the landing and plays there, mirrored when leaping left.
	layer.pulses.clear(); layer._on_stage_cleared()
	bridge.emit_confirmed(event(bridge, &"movement", &"berserker_wound_leap", {"direction_2d":Vector2.LEFT, "travel_distance":120.0}, Vector2(200, 80)))
	var leap: Dictionary = layer.pulses.back()
	check(leap.get("trail") == &"leap" and leap.flipbook == &"wound_leap" and (leap.trail_start as Vector2) == Vector2(200, 80) and float(leap.flip_delay) > 0.0, "leap: trail from take-off and delayed landing sheet")
	check(layer.leap_point(leap, 0.5).y < layer.leap_point(leap, 0.0).y - 10.0 and layer.leap_point(leap, 1.0).is_equal_approx(Vector2(80, 64)), "leap arc rises mid-way and ends on the landing")
	for i: int in 60: # 0.2 s landing wait + 16 frames at 12 fps = 1.53 s.
		layer._advance(0.03); layer._canvas.notification(CanvasItem.NOTIFICATION_DRAW)
	check(layer.pulses.is_empty(), "leap pulse expires after its landing sheet")
	# Without a confirmed distance (legacy action path) nothing extra is drawn: the old forward placement remains.
	bridge.emit_confirmed(event(bridge, &"movement", &"berserker_wound_leap", {"direction_2d":Vector2.RIGHT}))
	check(not layer.pulses.back().has("trail") and float(layer.pulses.back().flip_delay) == 0.0, "leap without travel keeps the forward sheet")
	layer._canvas.notification(CanvasItem.NOTIFICATION_DRAW)
	bridge.queue_free(); (r.host as Node).queue_free(); await process_frame
