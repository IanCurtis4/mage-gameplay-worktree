extends SceneTree
## Source-pixel and transform invariants for calibrated hand equipment.

const V1 = preload("res://tests/fixtures/e08_directional/fixture.gd")
const RIG := preload("res://scripts/actors/equipment_hand_rig.gd")
const VISUAL := preload("res://scripts/actors/equipment_attachment_visual.gd")
const KINDS: Array[StringName] = [&"swordsman", &"archer", &"berserker", &"defender", &"elementalist", &"hunter", &"mage", &"sentinel", &"spiritualist", &"geometer"]
const EQUIPMENT: Array[StringName] = [&"sword", &"axe", &"staff", &"bow", &"shield", &"prismatic_focus", &"wooden_beads"]
var checks := 0
var failures := 0
var failed_labels: Array[String] = []

func _initialize() -> void:
	_run.call_deferred()

func _check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		failed_labels.append(label)

func _run() -> void:
	_check(RIG.identities().size() == KINDS.size(), "rig has exactly ten supported body identities")
	var rig_data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/art/equipment/hand_rigs.json"))
	var equipment := {"main_hand": &"", "off_hand": &"", "arms": &""}
	for kind: StringName in KINDS:
		var atlas_path := "res://assets/art/animations/%s_weaponless.png" % kind
		_check(FileAccess.get_sha256(atlas_path).to_lower() == String(rig_data["identities"][String(kind)]["atlas_sha256"]), "source atlas hash matches rig calibration %s" % kind)
		var animation := V1.legacy_animation(kind)
		animation.set_equipment_visual(equipment)
		_check(animation.atlas != null and animation.atlas.get_size() == Vector2(256, 512), "32-frame source atlas: %s" % kind)
		var atlas_image := animation.atlas.get_image()
		for frame: int in range(32):
			var pose := RIG.pose(kind, frame)
			_check(not pose.is_empty(), "rig coverage %s/%d" % [kind, frame])
			if pose.is_empty():
				continue
			var cell := atlas_image.get_region(Rect2i(frame % 4 * 64, frame / 4 * 64, 64, 64))
			for slot: StringName in [&"main_hand", &"off_hand"]:
				var anchor: Vector2 = pose["main"] if slot == &"main_hand" else pose["off"]
				var finger: Rect2 = pose["main_fingers"] if slot == &"main_hand" else pose["off_fingers"]
				if frame < 28:
					_check(_opaque_near(cell, anchor, 0), "grip misses source body alpha %s/%d/%s at %s" % [kind, frame, slot, anchor])
				_check(finger.position.x >= 0 and finger.position.y >= 0 and finger.end.x <= 64 and finger.end.y <= 64, "finger crop outside source cell %s/%d/%s" % [kind, frame, slot])
				if frame < 28:
					_check(_rect_has_alpha(cell, finger), "finger crop misses opaque source pixels %s/%d/%s" % [kind, frame, slot])
			_check(animation.destination_rect(frame).size == Vector2(64, 64), "body source crop remains native 64-cell %s/%d" % [kind, frame])

	for key: StringName in EQUIPMENT:
		var texture := load("res://assets/art/equipment/%s.svg" % key) as Texture2D
		_check(texture != null and texture.get_size() == VISUAL.PROFILES[key]["size"], "native texture dimensions preserve profile for %s" % key)

	_check(RIG.pose(&"sentinel", 0)["main"] == Vector2(55, 36), "Sentinel idle main grip is calibrated at (55,36)")
	_check(_opaque_near(load("res://assets/art/animations/sentinel_weaponless.png").get_image().get_region(Rect2i(0, 0, 64, 64)), Vector2(55, 36), 0), "Sentinel idle palm (55,36) is opaque in its source frame")
	_check(_shared_renderer_is_used(), "world actor and inventory preview share CharacterAnimation.draw_on")
	_check(_scale_flip_and_grounding(), "grip anchor follows scale, horizontal flip, and ground offset")
	_check(_death_pose_is_native_and_grounded(), "death equipment stays native size and rests on the ground")
	print("Equipment hand alignment: %d checks, %d failures" % [checks, failures])
	if not failed_labels.is_empty():
		print("Failing anchors/invariants: %s" % "; ".join(failed_labels))
	quit(1 if failures else 0)

func _opaque_near(image: Image, point: Vector2, radius: int) -> bool:
	var center := Vector2i(roundi(point.x), roundi(point.y))
	for y: int in range(center.y - radius, center.y + radius + 1):
		for x: int in range(center.x - radius, center.x + radius + 1):
			if x >= 0 and y >= 0 and x < image.get_width() and y < image.get_height() and image.get_pixel(x, y).a > 0.5:
				return true
	return false

func _rect_has_alpha(image: Image, rect: Rect2) -> bool:
	for y: int in range(floori(rect.position.y), ceili(rect.end.y)):
		for x: int in range(floori(rect.position.x), ceili(rect.end.x)):
			if x >= 0 and y >= 0 and x < image.get_width() and y < image.get_height() and image.get_pixel(x, y).a > 0.5:
				return true
	return false

func _scale_flip_and_grounding() -> bool:
	var ok := true
	var equipment := {"main_hand": &"", "off_hand": &"", "arms": &""}
	for kind: StringName in KINDS:
		var animation := V1.legacy_animation(kind)
		animation.set_equipment_visual(equipment)
		var body_image := animation.atlas.get_image()
		for frame: int in range(32):
			var state := _state_for_frame(frame)
			_check(state.frame_index() == frame, "animation maps to rig frame %s/%d (got %d)" % [kind, frame, state.frame_index()])
			var origin := animation.destination_rect(frame).position
			var placed: Dictionary = VISUAL.placement(kind, state, &"sword", &"main_hand", origin)
			if frame<28:
				var pose := RIG.pose(kind,frame)
				_check(Vector2(placed["point"]).is_equal_approx(origin+Vector2(pose["main"])),"grip lands on body palm with real ground offset %s/%d" % [kind,frame])
				var shifted := VISUAL.placement(kind,state,&"sword",&"main_hand",origin+Vector2(3,7))
				_check((Vector2(shifted["point"])-Vector2(placed["point"])).is_equal_approx(Vector2(3,7)),"equipment follows a shifted body origin %s/%d" % [kind,frame])
			for scale: float in [1.0, 2.4]:
				for flipped: bool in [false, true]:
					state.flip_h = flipped
					var transform: Transform2D = VISUAL.piece_transform(placed, scale, flipped)
					var expected := Vector2((-1.0 if flipped else 1.0) * placed["point"].x, placed["point"].y) * scale
					var forward := Vector2.RIGHT.rotated(float(placed["angle"]))*scale
					if flipped:forward.x=-forward.x
					_check(transform.x.is_equal_approx(forward),"rotation reflects exactly once %s/%d scale=%s flip=%s" % [kind,frame,scale,flipped])
					if not transform.origin.is_equal_approx(expected):
						failed_labels.append("grip transform mismatch %s/%d scale=%s flip=%s" % [kind, frame, scale, flipped])
						failures += 1
						ok = false
					if not is_equal_approx(transform.x.length(), scale) or not is_equal_approx(transform.y.length(), scale):
						failed_labels.append("equipment scale mismatch %s/%d scale=%s flip=%s" % [kind, frame, scale, flipped])
						failures += 1
						ok = false
			if placed["size"] != VISUAL.PROFILES[&"sword"]["size"]:
				failed_labels.append("native profile size changed %s/%d" % [kind, frame])
				failures += 1
				ok = false
			var bounds := body_image.get_region(Rect2i(frame % 4 * 64, frame / 4 * 64, 64, 64)).get_used_rect()
			var destination_bottom := animation.destination_rect(frame).position.y + float(bounds.end.y - 1)
			if not is_equal_approx(destination_bottom, 0.0):
				failed_labels.append("ground offset mismatch %s/%d" % [kind, frame])
				failures += 1
				ok = false
	return ok

func _state_for_frame(frame: int) -> CombatAnimationState:
	var state := CombatAnimationState.new()
	if frame < 4:
		state.idle_time = float(frame) * 0.25
	elif frame < 8:
		state.moving = true
		state.walk_distance = float(frame - 4) * CombatAnimationState.WALK_FRAME_DISTANCE
	elif frame < 12:
		state.trigger(&"attack")
		state.action_remaining = 0.25 - float(frame - 8) * 0.0625
	elif frame < 16:
		state.face(Vector2.UP)
		state.moving = true
		state.walk_distance = float(frame - 12) * CombatAnimationState.WALK_FRAME_DISTANCE
	elif frame < 20:
		state.face(Vector2.UP)
		state.idle_time = float(frame - 16) * 0.25
	elif frame < 24:
		state.face(Vector2.UP)
		state.trigger(&"attack")
		state.action_remaining = 0.25 - float(frame - 20) * 0.0625
	elif frame < 28:
		if frame >= 26:
			state.face(Vector2.UP)
			state.hurt_remaining = 0.08 if frame == 27 else 0.18
		else:
			state.hurt_remaining = 0.08 if frame == 25 else 0.18
	else:
		if frame >= 30:
			state.face(Vector2.UP)
		state.trigger(&"death")
		state.death_time = 0.2 if frame % 2 == 1 else 0.0
	return state

func _death_pose_is_native_and_grounded() -> bool:
	var state := CombatAnimationState.new()
	state.trigger(&"death")
	state.death_time = 0.2
	var placed := VISUAL.placement(&"sentinel", state, &"sword", &"main_hand", Vector2(-32, -58))
	if placed.is_empty() or placed["size"] != Vector2(16, 32):
		return false
	var transform := VISUAL.piece_transform(placed, 1.0, false)
	var texture := load("res://assets/art/equipment/sword.svg") as Texture2D
	var bounds := texture.get_image().get_used_rect()
	var grip: Vector2 = placed["grip"]
	var lowest := -INF
	for point: Vector2 in [Vector2(bounds.position), Vector2(bounds.end - Vector2i.ONE), Vector2(bounds.position.x, bounds.end.y - 1), Vector2(bounds.end.x - 1, bounds.position.y)]:
		lowest = maxf(lowest, (point - grip).rotated(float(placed["angle"])).y)
	return absf(transform.origin.y + lowest) <= 1.0

func _shared_renderer_is_used() -> bool:
	var actor_source := FileAccess.get_file_as_string("res://scripts/actors/combat_actor.gd")
	var preview_source := FileAccess.get_file_as_string("res://scripts/ui/inventory_character_preview.gd")
	return actor_source.contains("character_animation.draw_on(self") and preview_source.contains("_animation.draw_on(_sprite")
