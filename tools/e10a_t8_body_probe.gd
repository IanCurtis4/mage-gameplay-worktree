extends "res://tools/e08_directional_unit_probe.gd"
## E10a T8 native evidence: the real CharacterAnimation / EquipmentAttachmentVisual / EquipmentHeadVisual
## renderer, windowed, with the three Acolyte-family bodies selected the way the game does it (the body folder of
## the base or of the evolution through ClassKitRegistry.actor_kind), never by a staged manifest.
## Args: <folder> [kind ...]. Per kind (acolyte, priest, cultist):
##   bare_<kind>        64 poses, no equipment                 (south+north, east+west: rows of 16)
##   book_<kind>        prayer_book in the main hand           (same grid; 2x)
##   scepter_<kind>     halo_scepter in the main hand
##   reliquary_<kind>   eye_reliquary in the main hand
##   grip_<kind>        markers: grip point (red) and finger crop (green) over the book sheet
##   head_<kind>_<id>   head pieces on poses 0,4,8,9,12,14,15 for the four directions (shared_set_mid/high, class_set_mage)
const KINDS: Array[StringName] = [&"acolyte", &"priest", &"cultist"]
const HEAD_POSES: Array[int] = [0, 4, 8, 9, 12, 14, 15]
const HEAD_PIECES: Array[StringName] = [&"shared_set_mid_head", &"shared_set_high_head", &"class_set_mage_head"]
const LOADOUTS := {
	"book": {"main_hand": &"prayer_book"},
	"scepter": {"main_hand": &"halo_scepter"},
	"reliquary": {"main_hand": &"eye_reliquary"},
}

func grass(width: int, height: int) -> void:
	var bg := Polygon2D.new()
	bg.color = Color("5d8a3c")
	bg.polygon = PackedVector2Array([Vector2(0, 0), Vector2(width, 0), Vector2(width, height), Vector2(0, height)])
	page.add_child(bg)

func body(kind: StringName, direction: int, pose: int, visual: Dictionary, point: Vector2, scale_value: float, markers: bool = false) -> Preview:
	var view := Preview.new()
	view.animation = CharacterAnimation.new()
	view.animation.configure(kind)
	check(view.animation.actor_kind == kind and view.animation.render_descriptor().version == 2, "%s body selected as V2 by kind" % kind)
	view.animation.set_equipment_visual(visual)
	view.animation.state = D.state(direction, pose)
	view.position = point
	view.scale = Vector2.ONE * scale_value
	view.markers = markers
	page.add_child(view)
	check(view.animation.render_descriptor().frame == direction * 16 + pose, "%s authored frame %d/%d" % [kind, direction, pose])
	return view

func grid(kind: StringName, visual: Dictionary, title: String, tag: String, markers: bool = false) -> void:
	# two shots per sheet (south+north, east+west): the window is 1280x720
	for half: int in 2:
		clear_page("%s · %s" % [title, ["sul + norte", "leste + oeste"][half]])
		grass(1280, 720)
		for row: int in 2:
			var direction := half * 2 + row
			for pose: int in 16:
				body(kind, direction, pose, visual, Vector2(64 + (pose % 8) * 150, 130 + row * 330 + (pose / 8) * 130), 2.0, markers)
		await shot(tag + ["_sn", "_ew"][half])

func run() -> void:
	var args := OS.get_cmdline_user_args()
	folder = args[0]
	DirAccess.make_dir_recursive_absolute(folder)
	root.size = Vector2i(1280, 720)
	var kinds: Array[StringName] = []
	for index: int in range(1, args.size()):
		kinds.append(StringName(args[index]))
	if kinds.is_empty():
		kinds = KINDS
	for kind: StringName in kinds:
		await grid(kind, {}, "%s · 64 poses · sem equipamento · sul/norte/leste/oeste" % kind, "bare_" + String(kind))
		for loadout: String in LOADOUTS:
			await grid(kind, LOADOUTS[loadout], "%s · %s · 64 poses" % [kind, loadout], loadout + "_" + String(kind))
		await grid(kind, LOADOUTS["book"], "%s · marcadores de grip (vermelho) e dedos (verde)" % kind, "grip_" + String(kind), true)
		for piece: StringName in HEAD_PIECES:
			clear_page("%s · %s · poses 0,4,8,9,12,14,15 · sul/norte/leste/oeste" % [kind, piece])
			grass(1280, 720)
			for direction: int in 4:
				for column: int in HEAD_POSES.size():
					body(kind, direction, HEAD_POSES[column], {"head": piece}, Vector2(80 + column * 170, 150 + direction * 160), 2.2)
			await shot("head_%s_%s" % [kind, piece])
	write_json("result.json", {"checks": checks, "failures": failures, "captures": captures, "kinds": kinds})
	print("E10a T8 native: %d checks, %d captures, %d failures" % [checks, captures.size(), failures])
	quit(1 if failures else 0)
