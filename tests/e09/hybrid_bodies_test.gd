extends SceneTree
## E09 T7 — the four hybrid bodies (C6, second part). Real atlases, the authored calibration and the
## T1 seam: the evolution resolves its own body folder, and falls back to the origin body without art.
const D = preload("res://tests/fixtures/e08_directional/fixture.gd")
const ROOT := "res://assets/art/e08_characters/directional/%s/"
const BODIES := {
	&"sp_ac": {"folder": &"paladin", "origin": &"swordsman"},
	&"mg_ac": {"folder": &"thaumaturge", "origin": &"mage"},
	&"sp_la": {"folder": &"duelist", "origin": &"swordsman"},
	&"mg_la": {"folder": &"arcane_blade", "origin": &"mage"},
}
const LOADOUTS: Array[Dictionary] = [
	{"main_hand": &"sword", "off_hand": &"shield", "arms": &"wooden_beads", "head": &"shared_set_mid_head"},
	{"main_hand": &"staff", "off_hand": &"prismatic_focus", "head": &"shared_set_high_head"},
]
var checks := 0
var failures := 0

func _initialize() -> void:
	_run.call_deferred()

func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("FAIL: " + label)

func _run() -> void:
	_check_resolution()
	for evolution: StringName in BODIES:
		_check_atlas(evolution)
		_check_calibration(evolution)
		_check_head_fit(evolution)
		_check_renderer(evolution)
	_check_fallback()
	print("E09 hybrid bodies: %d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)

# --- Evolution -> actor_kind (C1.8) --------------------------------------------------

func _check_resolution() -> void:
	ClassKitRegistry.clear_fixtures()
	# E10a C1.11: the registry also lists the pure kits; the four hybrids are these bodies.
	_check(ClassKitRegistry.hybrid_ids() == BODIES.keys(), "the four kit hybrids of section 1 are the four bodies")
	for evolution: StringName in BODIES:
		var expected: Dictionary = BODIES[evolution]
		var folder: StringName = expected.folder
		_check(ClassKitRegistry.body_folder(evolution) == folder and ClassKitRegistry.origin(evolution) == expected.origin, "%s: section 1 maps the body folder and the origin" % evolution)
		_check(DirectionalAnimationSet.kit_body_path(folder) == (ROOT % folder) + "presentation.json", "%s: the body manifest is found in the production folder" % folder)
		_check(ClassKitRegistry.actor_kind(evolution, expected.origin) == folder, "%s resolves its own body, not the origin's" % evolution)
		_check(ClassKitRegistry.is_body_kind(folder) and ClassKitRegistry.body_origin(folder) == expected.origin, "%s is a body kind whose fallback is the origin body" % folder)
		var snapshot := BuildSnapshot.new()
		snapshot.base_class_id = expected.origin
		snapshot.evolution_id = evolution
		_check(BuildPresentation.portrait_identity(snapshot) == folder, "%s: the portrait uses the hybrid body" % evolution)
	# origins that did not evolve keep the origin body
	_check(ClassKitRegistry.actor_kind(&"defender", &"swordsman") == &"swordsman" and ClassKitRegistry.actor_kind(&"", &"mage") == &"mage", "non-kit evolutions keep the origin body")

# --- Atlas ----------------------------------------------------------------------------

func _check_atlas(evolution: StringName) -> void:
	var folder: StringName = BODIES[evolution].folder
	var path := (ROOT % folder) + "presentation.json"
	var loaded := DirectionalAnimationSet.load_manifest(path)
	_check(loaded.ok, "%s: the V2 atlas loads and validates: %s" % [folder, str(loaded.get("detail", loaded.get("error_code", "")))])
	if not loaded.ok:
		return
	var bundle: DirectionalAnimationSet = loaded.bundle
	_check(bundle.actor_kind() == folder, "%s: manifest binds its own identity" % folder)
	var atlas := bundle.body(false).get_image()
	var worn := bundle.body(true).get_image()
	_check(atlas.get_size() == Vector2i(256, 1024) and worn.get_size() == Vector2i(256, 1024), "%s: 64 cells of 64x64 (256x1024)" % folder)
	_check(atlas.get_data() == worn.get_data(), "%s: body and weaponless are the same pixels (no embedded weapon)" % folder)
	for direction: int in 4:
		for sequence: Vector2i in [Vector2i(4, 4), Vector2i(8, 4), Vector2i(12, 2), Vector2i(14, 2)]:
			var signatures: Array[PackedByteArray] = []
			for pose: int in range(sequence.x, sequence.x + sequence.y):
				var index := direction * 16 + pose
				var pixels := atlas.get_region(Rect2i(index % 4 * 64, index / 4 * 64, 64, 64)).get_data()
				if pixels not in signatures:
					signatures.append(pixels)
			_check(signatures.size() >= mini(sequence.y, 2), "%s: distinct poses %d/%s" % [folder, direction, sequence])
	var mirrored := true
	for pose: int in 16:
		var east := atlas.get_region(Rect2i(pose % 4 * 64, 512 + pose / 4 * 64, 64, 64))
		var west := atlas.get_region(Rect2i(pose % 4 * 64, 768 + pose / 4 * 64, 64, 64))
		west.flip_x()
		mirrored = mirrored and east.get_data() == west.get_data()
	_check(not mirrored, "%s: the lateral views are not a mirrored sheet" % folder)
	for index: int in 64:
		var tile := atlas.get_region(Rect2i(index % 4 * 64, index / 4 * 64, 64, 64))
		var bounds := tile.get_used_rect()
		_check(bounds.has_area() and bounds.position.x > 0 and bounds.end.x < 64 and bounds.position.y > 0 and bounds.end.y <= 59, "%s: content of cell %d sits inside transparent gutters" % [folder, index])

# --- Calibration ------------------------------------------------------------------------

func _check_calibration(evolution: StringName) -> void:
	var folder: StringName = BODIES[evolution].folder
	var calibration: Dictionary = JSON.parse_string(FileAccess.get_file_as_string((ROOT % folder) + "calibration.json"))
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string((ROOT % folder) + "presentation.json"))
	_check(calibration.get("actor_kind") == String(folder) and (calibration.get("frames", []) as Array).size() == 64, "%s: calibration binds the body and covers 64 poses" % folder)
	_check(calibration.get("authored_rgba_sha256") == manifest.body.rgba_sha256 and manifest.body.rgba_sha256 == manifest.weaponless.rgba_sha256, "%s: calibration hash is the body hash" % folder)
	var loaded := DirectionalAnimationSet.load_manifest((ROOT % folder) + "presentation.json")
	if not loaded.ok:
		return
	var bundle: DirectionalAnimationSet = loaded.bundle
	var atlas := bundle.body(false).get_image()
	for index: int in 64:
		var raw: Dictionary = bundle.frame(index)
		var frame: Dictionary = calibration.frames[index]
		_check(raw.ground_y == frame.ground_y, "%s: pose %d keeps the authored ground" % [folder, index])
		var tile := atlas.get_region(Rect2i(index % 4 * 64, index / 4 * 64, 64, 64))
		_check(int(raw.ground_y) == tile.get_used_rect().end.y - 1, "%s: pose %d ground is the lowest opaque row" % [folder, index])
		for slot: String in ["main_hand", "off_hand", "arms"]:
			_check(raw.slots.has(slot), "%s: pose %d has the %s slot" % [folder, index, slot])
		var head: Dictionary = raw.head
		_check(head.visible and not head.flip and int(head.depth) == 1, "%s: pose %d head anchor is visible, unflipped and in front" % [folder, index])
		if index % 16 >= 14:
			for slot: String in ["main_hand", "off_hand"]:
				var released: Dictionary = raw.slots[slot]
				_check(int(released.depth) == 0 and is_equal_approx(float(released.angle_overrides.sword), PI / 2.0), "%s: dead pose %d releases the %s behind the body" % [folder, index, slot])
			continue
		for slot: String in ["main_hand", "off_hand"]:
			var pose: Dictionary = raw.slots[slot]
			var point := Vector2i(int(pose.point[0]), int(pose.point[1]))
			var crop := Rect2i(int(pose.fingers[0]), int(pose.fingers[1]), int(pose.fingers[2]), int(pose.fingers[3]))
			_check(tile.get_pixelv(point).a > 0.5 and crop.has_point(point), "%s: pose %d %s grip is on the body and inside its finger crop" % [folder, index, slot])
			_check(tile.get_region(crop).get_used_rect().has_area(), "%s: pose %d %s finger crop has pixels" % [folder, index, slot])
		_check(raw.slots.main_hand.point != raw.slots.off_hand.point or index % 16 == 11, "%s: pose %d has two distinct palms" % [folder, index])
		# anatomical convention: main = the character's right hand. South: image left, north: image right
		var main_x := int(raw.slots.main_hand.point[0])
		var off_x := int(raw.slots.off_hand.point[0])
		if index / 16 == 0:
			_check(main_x <= off_x, "%s: south pose %d main hand is the image-left (anatomical right) one" % [folder, index])
		elif index / 16 == 1:
			_check(main_x >= off_x, "%s: north pose %d main hand is the image-right (anatomical right) one" % [folder, index])

# --- Head fit (generated data) ------------------------------------------------------------

func _check_head_fit(evolution: StringName) -> void:
	var folder: StringName = BODIES[evolution].folder
	var entry: Dictionary = EquipmentHeadFitData.DATA.classes.get(String(folder), {})
	_check(entry.get("frames", []).size() == 64 and entry.get("rotated_offset", []).size() == 4, "%s: head-fit data covers the 64 poses and four directions" % folder)
	_check(entry.get("source") == "weaponless.png", "%s: head fit is measured on the drawn atlas" % folder)
	var loaded := DirectionalAnimationSet.load_manifest((ROOT % folder) + "presentation.json")
	if not loaded.ok or entry.is_empty():
		return
	var atlas := (loaded.bundle as DirectionalAnimationSet).body(true).get_image()
	for index: int in 64:
		var measured: Array = entry.frames[index]
		var tile := atlas.get_region(Rect2i(index % 4 * 64, index / 4 * 64, 64, 64))
		_check(int(measured[1]) >= tile.get_used_rect().position.y and int(measured[1]) < 50 and float(measured[2]) >= 14.0 and float(measured[2]) <= 28.0, "%s: pose %d head top and width are measured on the body" % [folder, index])

# --- Native renderer ----------------------------------------------------------------------

func _check_renderer(evolution: StringName) -> void:
	var folder: StringName = BODIES[evolution].folder
	var animation := CharacterAnimation.new()
	animation.configure(folder)
	_check(animation.actor_kind == folder and animation.render_descriptor().version == 2, "%s: configure selects the V2 hybrid body" % folder)
	_check(animation.atlas.resource_path == (ROOT % folder) + "body.png", "%s: the atlas is the production body" % folder)
	var loaded := DirectionalAnimationSet.load_manifest((ROOT % folder) + "presentation.json")
	if not loaded.ok:
		return
	var bundle: DirectionalAnimationSet = loaded.bundle
	for visual: Dictionary in LOADOUTS:
		animation.set_equipment_visual(visual)
		for direction: int in 4:
			for pose: int in 16:
				animation.state = D.state(direction, pose)
				var descriptor := animation.render_descriptor()
				_check(descriptor.version == 2 and descriptor.frame == direction * 16 + pose and not descriptor.flip, "%s: common 64-frame selection %d/%d" % [folder, direction, pose])
				_check(is_zero_approx(descriptor.origin.y + bundle.frame(descriptor.frame).ground_y), "%s: exact ground contact %d/%d" % [folder, direction, pose])
				_check(descriptor.head.view == direction, "%s: the head piece shares the body direction %d/%d" % [folder, direction, pose])
				for placed: Dictionary in descriptor.equipment:
					var raw: Dictionary = bundle.frame(descriptor.frame).slots[String(placed.slot)]
					var expected: Vector2 = descriptor.origin + Vector2(raw.point[0], raw.point[1])
					if not descriptor.dead:
						_check(placed.point == expected, "%s: living equipment uses the authored grip %d/%d/%s" % [folder, direction, pose, placed.slot])
					else:
						_check(is_equal_approx(placed.point.x, expected.x), "%s: dropped equipment preserves the authored X %d/%d" % [folder, direction, pose])
	animation.set_equipment_visual({})
	animation.state = D.state(3, 10)
	_check(animation.death_copy().render_descriptor().direction == 3, "%s: the death copy keeps the west view of the hybrid body" % folder)

# --- Fallback (C1.8: no art -> the origin body) ----------------------------------------------

func _check_fallback() -> void:
	_check(DirectionalAnimationSet.kit_body_path(&"").is_empty() and DirectionalAnimationSet.kit_body_path(&"paladin_missing").is_empty(), "a kit body folder without art has no manifest")
	_check(not DirectionalAnimationSet.load_manifest(ROOT % &"paladin_missing" + "presentation.json").ok, "a missing manifest is refused, not half-loaded")
	_check(ClassKitRegistry.actor_kind(&"unknown_evolution", &"swordsman") == &"swordsman", "an evolution without a body folder uses the origin body")
	# the origin bodies stay intact and keep their own art
	for origin: StringName in [&"swordsman", &"mage"]:
		var animation := CharacterAnimation.new()
		animation.configure(origin)
		_check(animation.actor_kind == origin and animation.atlas.resource_path.begins_with("res://assets/art/animations/"), "%s body is untouched" % origin)
	# a manifest of another identity is rejected atomically
	var duelist := CharacterAnimation.new()
	duelist.configure(&"duelist")
	var before := duelist.atlas
	var wrong := duelist.set_directional_manifest((ROOT % &"paladin") + "presentation.json")
	_check(not wrong.ok and duelist.actor_kind == &"duelist" and duelist.atlas == before, "a manifest of another body is rejected without changing the unit")
