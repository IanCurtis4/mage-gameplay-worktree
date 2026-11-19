extends SceneTree
## E10a T8 — the three Acolyte-family bodies (C4.2). Real atlases, the authored calibration, the T1 base seam
## and the head-fit data: the base resolves its own body folder (the Mage body is the fallback only while the
## folder has no art), the two pure kits resolve their own, and every body carries the 64-pose V2 contract.
const D = preload("res://tests/fixtures/e08_directional/fixture.gd")
const ROOT := "res://assets/art/e08_characters/directional/%s/"
## folder -> the registry identity that owns it (base or pure kit) and the body one step back without art.
const BODIES := {
	&"acolyte": {"id": &"acolyte", "base": true, "origin": &"acolyte", "fallback": &"mage"},
	&"priest": {"id": &"priest", "base": false, "origin": &"acolyte", "fallback": &"acolyte"},
	&"cultist": {"id": &"cultist", "base": false, "origin": &"acolyte", "fallback": &"acolyte"},
}
const ITEMS: Array[StringName] = [&"prayer_book", &"halo_scepter", &"eye_reliquary"]
const LOADOUTS: Array[Dictionary] = [
	{"main_hand": &"prayer_book"},
	{"main_hand": &"halo_scepter", "head": &"class_set_mage_head"},
	{"main_hand": &"eye_reliquary", "head": &"shared_set_mid_head"},
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
	for folder: StringName in BODIES:
		_check_atlas(folder)
		_check_manifest_and_provenance(folder)
		_check_calibration(folder)
		_check_head_fit(folder)
		_check_renderer(folder)
	_check_family_items()
	_check_prop_angles()
	_check_other_bodies_intact()
	print("E10a family bodies: %d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)

# --- Identity -> actor_kind (C1.8) -----------------------------------------------------

func _check_resolution() -> void:
	ClassKitRegistry.clear_fixtures()
	_check(ClassBaseRegistry.is_base(&"acolyte") and ClassBaseRegistry.body_folder(&"acolyte") == &"acolyte", "section 1: the base maps the acolyte body folder")
	_check(ClassBaseRegistry.fallback_body(&"acolyte") == &"mage", "the base still names the Mage body as its fallback")
	for folder: StringName in BODIES:
		var expected: Dictionary = BODIES[folder]
		_check(DirectionalAnimationSet.kit_body_path(folder) == (ROOT % folder) + "presentation.json", "%s: the body manifest is found in the production folder" % folder)
		_check(ClassKitRegistry.body_folder(expected.id) == folder, "%s: the registry maps the identity to its own body folder" % folder)
		_check(ClassKitRegistry.is_body_kind(folder) and ClassKitRegistry.body_origin(folder) == expected.fallback, "%s is a body kind whose fallback is %s" % [folder, expected.fallback])
	# the base: with art it resolves its own body, an empty evolution resolves the origin alone (C1.8)
	_check(ClassKitRegistry.actor_kind(&"", &"acolyte") == &"acolyte" and ClassKitRegistry.base_actor_kind(&"acolyte") == &"acolyte", "the Acolyte without evolution wears the acolyte body, not the Mage fallback")
	_check(ClassKitRegistry.actor_kind(&"priest", &"acolyte") == &"priest", "the Priest resolves its own body")
	_check(ClassKitRegistry.actor_kind(&"cultist", &"acolyte") == &"cultist", "the Cultist resolves its own body")
	# the fallback chain: pure kit -> base body -> mage -> legacy atlas kind
	_check(ClassKitRegistry.legacy_body_kind(&"priest") == &"mage" and ClassKitRegistry.legacy_body_kind(&"cultist") == &"mage" and ClassKitRegistry.legacy_body_kind(&"acolyte") == &"mage", "all three chains end at the legacy Mage atlas")
	for folder: StringName in [&"priest", &"cultist"]:
		var snapshot := BuildSnapshot.new()
		snapshot.base_class_id = &"acolyte"
		snapshot.evolution_id = folder
		_check(BuildPresentation.portrait_identity(snapshot) == folder, "%s: the portrait uses the pure-kit body" % folder)
	var base_snapshot := BuildSnapshot.new()
	base_snapshot.base_class_id = &"acolyte"
	_check(BuildPresentation.portrait_identity(base_snapshot) == &"acolyte", "acolyte: the portrait uses the base body")
	# origins that did not change keep their body
	_check(ClassKitRegistry.actor_kind(&"", &"mage") == &"mage" and ClassKitRegistry.actor_kind(&"sp_ac", &"swordsman") == &"paladin", "the other origins and the E09 hybrids keep their bodies")
	# no body folder is shared among the three, and none repeats an E08/E09 body
	var seen: Array[StringName] = []
	for folder: StringName in ClassKitRegistry.body_folders():
		_check(folder not in seen or folder == &"", "body folder %s is listed once" % folder)
		seen.append(folder)

# --- Atlas ----------------------------------------------------------------------------------

func _check_atlas(folder: StringName) -> void:
	var loaded := DirectionalAnimationSet.load_manifest((ROOT % folder) + "presentation.json")
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
	var idle_heights: Array[int] = []
	for index: int in 64:
		var tile := atlas.get_region(Rect2i(index % 4 * 64, index / 4 * 64, 64, 64))
		var bounds := tile.get_used_rect()
		_check(bounds.has_area() and bounds.position.x > 0 and bounds.end.x < 64 and bounds.position.y > 0 and bounds.end.y <= 59, "%s: content of cell %d sits inside transparent gutters" % [folder, index])
		if index % 16 == 0:
			idle_heights.append(bounds.size.y)
	# the neutral pipeline normalised the four views to one scale: the idle bodies stay within 6 % of each other
	var lowest: int = idle_heights.min()
	var highest: int = idle_heights.max()
	_check(float(highest - lowest) / float(highest) <= 0.06, "%s: the four idle bodies share one scale (heights %s)" % [folder, str(idle_heights)])

# --- Manifest, recipe and provenance ---------------------------------------------------------

func _check_manifest_and_provenance(folder: StringName) -> void:
	var base := ROOT % folder
	for name: String in ["body.png", "weaponless.png", "calibration.json", "presentation.json", "provenance.json", "recipe.md", "source_recipe.json", "delivery.md"]:
		_check(FileAccess.file_exists(base + name), "%s: %s is delivered" % [folder, name])
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(base + "presentation.json"))
	_check(manifest.get("format") == "ragrpg_directional_animation_v2" and manifest.get("actor_kind") == String(folder), "%s: the manifest is the V2 contract of its identity" % folder)
	_check(manifest.body.path == base + "body.png" and manifest.weaponless.path == base + "weaponless.png", "%s: the manifest points at the delivered atlases" % folder)
	_check(not manifest.has("bare_head") or FileAccess.file_exists(String(manifest.bare_head.path)), "%s: an optional bare_head variant exists when declared" % folder)
	var provenance: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(base + "provenance.json"))
	_check(provenance.get("schema") == "ragrpg_art_provenance_v2" and (provenance.get("records", []) as Array).size() == 2, "%s: provenance v2 with the body and weaponless records" % folder)
	var body_hash := FileAccess.get_sha256(base + "body.png")
	for record: Dictionary in provenance.records:
		_check(String(record.sha256) == FileAccess.get_sha256("res://" + String(record.path)), "%s: provenance hash of %s is the delivered file" % [folder, record.path])
		_check(String(record.sha256) == body_hash and record.refs.size() == 4 and record.get("selected", false), "%s: four selected source views and the same atlas hash" % folder)
		for ref: Dictionary in record.refs:
			var source := "res://" + String(ref.path)
			_check(FileAccess.file_exists(source) and FileAccess.get_sha256(source) == String(ref.sha256), "%s: source %s matches the recorded SHA256" % [folder, ref.path])
		_check(record.measurements.rgba_sha256 == manifest.body.rgba_sha256, "%s: provenance RGBA hash is the manifest body hash" % folder)
	var recipe: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(base + "source_recipe.json"))
	_check(recipe.get("actor_kind") == String(folder) and (recipe.views as Dictionary).size() == 4 and int(recipe.target_height) == 50, "%s: the recipe names the identity, four views and the packer height" % folder)
	if folder == &"acolyte":
		for view: String in ["north", "east", "west"]:
			_check(FileAccess.file_exists(base + String(recipe.views[view].source)), "acolyte: the normalised %s sheet used by the recipe is versioned" % view)

# --- Calibration ------------------------------------------------------------------------------

func _check_calibration(folder: StringName) -> void:
	var calibration: Dictionary = JSON.parse_string(FileAccess.get_file_as_string((ROOT % folder) + "calibration.json"))
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string((ROOT % folder) + "presentation.json"))
	_check(calibration.get("actor_kind") == String(folder) and (calibration.get("frames", []) as Array).size() == 64, "%s: calibration binds the body and covers 64 poses" % folder)
	_check(calibration.get("authored_rgba_sha256") == manifest.body.rgba_sha256 and manifest.body.rgba_sha256 == manifest.weaponless.rgba_sha256, "%s: calibration hash is the body hash" % folder)
	var loaded := DirectionalAnimationSet.load_manifest((ROOT % folder) + "presentation.json")
	if not loaded.ok:
		return
	var bundle: DirectionalAnimationSet = loaded.bundle
	var atlas := bundle.body(false).get_image()
	var live_grips := 0
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
		var head_point := Vector2i(int(head.point[0]), int(head.point[1]))
		_check(tile.get_pixelv(head_point).a > 0.5, "%s: pose %d head anchor sits on the body" % [folder, index])
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
			live_grips += 1
		_check(raw.slots.main_hand.point != raw.slots.off_hand.point or index % 16 == 11, "%s: pose %d has two distinct palms" % [folder, index])
		# anatomical convention: main = the character's right hand. South: image left, north: image right
		var main_x := int(raw.slots.main_hand.point[0])
		var off_x := int(raw.slots.off_hand.point[0])
		if index / 16 == 0:
			_check(main_x <= off_x, "%s: south pose %d main hand is the image-left (anatomical right) one" % [folder, index])
		elif index / 16 == 1:
			_check(main_x >= off_x, "%s: north pose %d main hand is the image-right (anatomical right) one" % [folder, index])
	_check(live_grips == 112, "%s: 112 live grips (56 living poses x two hands)" % folder)

# --- Head fit (generated data) ----------------------------------------------------------------

func _check_head_fit(folder: StringName) -> void:
	var entry: Dictionary = EquipmentHeadFitData.DATA.classes.get(String(folder), {})
	_check(entry.get("frames", []).size() == 64 and entry.get("rotated_offset", []).size() == 4, "%s: head-fit data covers the 64 poses and four directions" % folder)
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string((ROOT % folder) + "presentation.json"))
	_check(entry.get("source") == ("bare_head.png" if manifest.has("bare_head") else "weaponless.png"), "%s: head fit is measured on the atlas the renderer draws under a helmet" % folder)
	var loaded := DirectionalAnimationSet.load_manifest((ROOT % folder) + "presentation.json")
	if not loaded.ok or entry.is_empty():
		return
	var atlas := (loaded.bundle as DirectionalAnimationSet).body(true).get_image()
	var worn := (loaded.bundle as DirectionalAnimationSet).body(true, true).get_image()
	for index: int in 64:
		var measured: Array = entry.frames[index]
		var tile := worn.get_region(Rect2i(index % 4 * 64, index / 4 * 64, 64, 64))
		_check(int(measured[1]) >= tile.get_used_rect().position.y and int(measured[1]) < 50 and float(measured[2]) >= 12.0 and float(measured[2]) <= 28.0, "%s: pose %d head top and width are measured on the body" % [folder, index])
	_check(atlas.get_size() == worn.get_size(), "%s: the helmet-worn atlas keeps the 256x1024 layout" % folder)

# --- Native renderer ---------------------------------------------------------------------------

func _check_renderer(folder: StringName) -> void:
	var animation := CharacterAnimation.new()
	animation.configure(folder)
	_check(animation.actor_kind == folder and animation.render_descriptor().version == 2, "%s: configure selects the V2 body" % folder)
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
				_check(not visual.has("head") or descriptor.head.view == direction, "%s: the head piece shares the body direction %d/%d" % [folder, direction, pose])
				_check(descriptor.equipment.size() == 1, "%s: the main-hand item is placed %d/%d" % [folder, direction, pose])
				for placed: Dictionary in descriptor.equipment:
					var raw: Dictionary = bundle.frame(descriptor.frame).slots[String(placed.slot)]
					var expected: Vector2 = descriptor.origin + Vector2(raw.point[0], raw.point[1])
					if not descriptor.dead:
						_check(placed.point == expected, "%s: living equipment uses the authored grip %d/%d/%s" % [folder, direction, pose, placed.slot])
					else:
						_check(is_equal_approx(placed.point.x, expected.x), "%s: dropped equipment preserves the authored X %d/%d" % [folder, direction, pose])
	animation.set_equipment_visual({})
	animation.state = D.state(3, 10)
	_check(animation.death_copy().render_descriptor().direction == 3, "%s: the death copy keeps the west view of the body" % folder)

# --- Angle per prop (T16, A15) ---------------------------------------------------------------------

## The Priest's halo scepter (profile 0.2) leans away from the face in the south and east views. That angle is
## an override of the prop (`angle_overrides.halo_scepter`, the full angle), never the main-hand slot angle,
## so the book and the reliquary stay straight in every bearer. direction index -> scepter angle.
const SCEPTER_ANGLES := {0: -0.15, 2: -0.25}

func _check_prop_angles() -> void:
	for folder: StringName in BODIES:
		var loaded := DirectionalAnimationSet.load_manifest((ROOT % folder) + "presentation.json")
		_check(loaded.ok, "%s: the manifest accepts prop ids in its angle overrides" % folder)
		if not loaded.ok:
			continue
		var bundle: DirectionalAnimationSet = loaded.bundle
		for index: int in 64:
			var pose: Dictionary = bundle.frame(index).slots.main_hand
			var overrides: Dictionary = pose.angle_overrides
			var leaning := folder == &"priest" and index % 16 < 14 and SCEPTER_ANGLES.has(index / 16)
			_check(is_zero_approx(float(pose.angle)), "%s: pose %d keeps a zero main-hand slot angle" % [folder, index])
			_check(overrides.has("halo_scepter") == leaning, "%s: pose %d carries the scepter override only on the Priest's living south and east poses" % [folder, index])
			_check(not overrides.has("prayer_book") and not overrides.has("eye_reliquary"), "%s: pose %d never tilts the book or the reliquary" % [folder, index])
			if leaning:
				_check(is_equal_approx(float(overrides.halo_scepter), float(SCEPTER_ANGLES[index / 16])), "%s: pose %d scepter angle" % [folder, index])
		var animation := CharacterAnimation.new()
		animation.configure(folder)
		for item: StringName in ITEMS:
			animation.set_equipment_visual({"main_hand": item})
			for direction: int in 4:
				for pose: int in 14:
					animation.state = D.state(direction, pose)
					var placed: Dictionary = animation.render_descriptor().equipment[0]
					var expected := float(EquipmentAttachmentVisual.PROFILES[item].angle)
					if folder == &"priest" and item == &"halo_scepter" and SCEPTER_ANGLES.has(direction):
						expected = float(SCEPTER_ANGLES[direction])
					_check(is_equal_approx(float(placed.angle), expected), "%s: %s angle %d/%d is %.2f" % [folder, item, direction, pose, expected])
	var book: Dictionary = EquipmentAttachmentVisual.PROFILES[&"prayer_book"]
	_check(book.size == Vector2(16, 24) and book.grip == Vector2(8, 12) and is_zero_approx(float(book.angle)), "the book is the reduced 16x24 with its grip at (8, 12) and no angle")

# --- The reduced book against the face and the ground (T16, A15) ---------------------------------

## Raised-hand and prayer poses put the palm beside the face, so a few living poses still touch the head rows;
## the count below is measured on the three bodies (the head rows are the 14 rows from the top of the body).
const BOOK_FACE_TOUCHES := 11

func _check_book_clearance() -> void:
	var profile: Dictionary = EquipmentAttachmentVisual.PROFILES[&"prayer_book"]
	var touches := 0
	for folder: StringName in BODIES:
		var loaded := DirectionalAnimationSet.load_manifest((ROOT % folder) + "presentation.json")
		if not loaded.ok:
			continue
		var bundle: DirectionalAnimationSet = loaded.bundle
		var atlas := bundle.body(false).get_image()
		for index: int in 64:
			if index % 16 >= 14:
				continue
			var raw: Dictionary = bundle.frame(index)
			var pose: Dictionary = raw.slots.main_hand
			var rect := Rect2i(Vector2i(Vector2(pose.point[0], pose.point[1]) - profile.grip), Vector2i(profile.size))
			if index % 16 < 4:
				_check(rect.end.y <= int(raw.ground_y) + 1, "%s: the idle book stays above the ground %d (bottom %d, ground %d)" % [folder, index, rect.end.y, raw.ground_y])
			if int(pose.depth) != 1:
				continue
			var tile := atlas.get_region(Rect2i(index % 4 * 64, index / 4 * 64, 64, 64))
			var top := tile.get_used_rect().position.y
			var head_rows := Rect2i(0, top, 64, 14)
			var hit := false
			for y: int in range(maxi(rect.position.y, head_rows.position.y), mini(rect.end.y, head_rows.end.y)):
				for x: int in range(maxi(rect.position.x, 0), mini(rect.end.x, 64)):
					hit = hit or tile.get_pixel(x, y).a > 0.5
			touches += 1 if hit else 0
	_check(touches == BOOK_FACE_TOUCHES, "the book touches the head rows in %d living poses (the raised-hand ones): %d" % [BOOK_FACE_TOUCHES, touches])

# --- The three family items in the hands of the three bodies (A12) ------------------------------

func _check_family_items() -> void:
	for folder: StringName in BODIES:
		var loaded := DirectionalAnimationSet.load_manifest((ROOT % folder) + "presentation.json")
		if not loaded.ok:
			continue
		var bundle: DirectionalAnimationSet = loaded.bundle
		var atlas := bundle.body(false).get_image()
		for item: StringName in ITEMS:
			var profile: Dictionary = EquipmentArtCatalog.e09_prop_profile(item)
			_check(not profile.is_empty(), "%s/%s: the T9 prop profile exists" % [folder, item])
			var inside := 0
			for index: int in 64:
				if index % 16 >= 14:
					continue
				var placed := EquipmentAttachmentVisual.resolve_equipment(folder, CombatAnimationState.new(), {"main_hand": item}, Vector2.ZERO, bundle.frame(index))
				_check(placed.size() == 1 and placed[0].key == item, "%s/%s: frame %d places the item with the authored frame" % [folder, item, index])
				if placed.is_empty():
					continue
				var pose: Dictionary = placed[0]
				var hand := Vector2i(int(pose.point.x), int(pose.point.y))
				var tile := atlas.get_region(Rect2i(index % 4 * 64, index / 4 * 64, 64, 64))
				if tile.get_pixelv(hand).a > 0.5:
					inside += 1
			_check(inside == 56, "%s/%s: the grip of all 56 living frames is on a body pixel" % [folder, item])

# --- Other bodies stay as they were --------------------------------------------------------------

func _check_other_bodies_intact() -> void:
	for kind: StringName in [&"swordsman", &"mage", &"paladin", &"thaumaturge", &"duelist", &"arcane_blade"]:
		var animation := CharacterAnimation.new()
		animation.configure(kind)
		_check(animation.actor_kind == kind, "%s body is untouched" % kind)
	_check(not DirectionalAnimationSet.load_manifest((ROOT % &"acolyte_missing") + "presentation.json").ok, "a missing manifest is refused, not half-loaded")
	var priest := CharacterAnimation.new()
	priest.configure(&"priest")
	var before := priest.atlas
	var wrong := priest.set_directional_manifest((ROOT % &"cultist") + "presentation.json")
	_check(not wrong.ok and priest.actor_kind == &"priest" and priest.atlas == before, "a manifest of another body is rejected without changing the unit")
