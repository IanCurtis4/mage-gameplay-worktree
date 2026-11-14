extends SceneTree
const Catalog = preload("res://scripts/presentation/vfx_flipbook_catalog.gd")
const Fixture = preload("res://tests/fixtures/e07/f1/fixture_input.gd")
const STAGING := "assets/art/e08_vfx/staging/"
## Second Codex batch (14/11): own staging folder, prompts recorded per sheet.
const CODEX_1114 := "assets/art/e08_codex_1114/vfx/"
## 15/11 repaints of two second-batch sheets: own folder and provenance; the 14/11 rows stay as history.
const CODEX_1115 := "assets/art/e08_codex_1115/vfx/"
const CODEX_1115_IDS := [&"spirit_dissipation", &"tri_nova"]
const CODEX_1114_IDS := [&"arrow_rain", &"covering_shot", &"geometer_collapse", &"headshot", &"shield_bash", &"spirit_dissipation", &"tri_nova", &"triangulation", &"warden_charge", &"wound_leap"]
var checks := 0
var failures := 0
func _initialize() -> void: _run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(label)
func _ints(values: Array) -> Array:
	var result := []
	for value: Variant in values: result.append(int(value))
	return result
func _rgba_hash(image: Image) -> String:
	var data := image.get_data()
	for offset: int in range(0, data.size(), 4):
		if data[offset+3] == 0:
			data[offset] = 0; data[offset+1] = 0; data[offset+2] = 0
	var context := HashingContext.new(); context.start(HashingContext.HASH_SHA256); context.update(data)
	return context.finish().hex_encode()
func _run() -> void:
	if not Fixture.sources_current(): push_error("stale fixture"); quit(1); return
	var ids := Catalog.ids()
	check(ids.size() == 19, "catalog lists nineteen flipbooks")
	var batch_root := FileAccess.get_file_as_string("res://source_root.txt").strip_edges()
	var batch_file := "res://"+CODEX_1114+"provenance.json"
	if not FileAccess.file_exists(batch_file) and not batch_root.is_empty(): batch_file = batch_root.path_join(CODEX_1114+"provenance.json")
	var batch: Variant = JSON.parse_string(FileAccess.get_file_as_string(batch_file))
	check(batch is Array and (batch as Array).size() == CODEX_1114_IDS.size(), "second batch provenance parses")
	var batch_assets: Dictionary = {}
	if batch is Array:
		for row: Variant in batch:
			if row is Dictionary: batch_assets[StringName(String(row.get("path", "")).get_file().get_basename())] = row
	var repaint_file := "res://"+CODEX_1115+"provenance.json"
	if not FileAccess.file_exists(repaint_file) and not batch_root.is_empty(): repaint_file = batch_root.path_join(CODEX_1115+"provenance.json")
	var repaint: Variant = JSON.parse_string(FileAccess.get_file_as_string(repaint_file))
	check(repaint is Array and (repaint as Array).size() == CODEX_1115_IDS.size(), "15/11 repaint provenance parses")
	var repaint_assets: Dictionary = {}
	if repaint is Array:
		for row: Variant in repaint:
			if row is Dictionary: repaint_assets[StringName(String(row.get("path", "")).get_file().get_basename())] = row
	var provenance: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://"+STAGING+"provenance.json"))
	check(provenance is Dictionary and (provenance as Dictionary).get("assets") is Dictionary, "provenance parses")
	var assets: Dictionary = (provenance as Dictionary).get("assets", {}) if provenance is Dictionary else {}
	var source_root := FileAccess.get_file_as_string("res://source_root.txt").strip_edges()
	for id: StringName in ids:
		var def := Catalog.definition(id)
		check(not def.is_empty() and def.id == String(id) and def.revision == 1, "manifest valid: "+String(id))
		if def.is_empty(): continue
		check(_ints(def.grid) == [4,4] and _ints(def.cell) == [160,160] and int(def.frames) == 16 and def.loop == false, "grid contract: "+String(id))
		check(int(def.suggested_fps) in [10,12,16], "fps in the documented set: "+String(id))
		check(float(def.world_diameter_hint) > 20.0 and float(def.world_diameter_hint) <= 160.0, "diameter hint plausible: "+String(id))
		var path := "res://assets/art/e08_vfx/%s/flipbook.png" % id
		check(FileAccess.get_sha256(path) == def.png_sha256, "png_sha256 matches: "+String(id))
		var image := Image.load_from_file(ProjectSettings.globalize_path(path))
		check(image != null and image.get_width() == 640 and image.get_height() == 640, "atlas is 640x640: "+String(id))
		if image == null: continue
		image.convert(Image.FORMAT_RGBA8)
		check(_rgba_hash(image) == def.rgba_sha256, "rgba_sha256 matches: "+String(id))
		var texture := Catalog.texture(id)
		check(texture != null and texture.get_width() == 640 and texture.get_height() == 640, "texture imports at 640x640: "+String(id))
		var empty := _ints(def.empty_frames)
		var tolerated_empty := true
		for frame: int in 16:
			var region := Catalog.frame_region(id, frame)
			check(region == Rect2i((frame % 4)*160, floori(float(frame) / 4.0)*160, 160, 160), "frame region %d: %s" % [frame, id])
			var count := 0
			var border := 0
			for y: int in 160:
				for x: int in 160:
					if image.get_pixel(region.position.x+x, region.position.y+y).a8 > 8:
						count += 1
						if x == 0 or y == 0 or x == 159 or y == 159: border += 1
			check(border == 0, "content stays inside cell %d: %s" % [frame, id])
			if frame in empty: check(count == 0, "listed empty frame %d is empty: %s" % [frame, id])
			else: check(count > 0, "frame %d not empty: %s" % [frame, id])
		check(not (0 in empty) and empty.size() <= 1 and tolerated_empty, "only the last frame may be empty: "+String(id))
		# fully transparent pixels carry bled colour (no black halo seed) near content
		var bled := 0
		for y: int in range(0, 640, 7):
			for x: int in range(0, 640, 7):
				var pixel := image.get_pixel(x, y)
				if pixel.a8 == 0 and (pixel.r8 + pixel.g8 + pixel.b8) > 0: bled += 1
		check(bled > 0, "alpha bleed present: "+String(id))
		# timing
		var fps := float(def.suggested_fps)
		check(Catalog.frame_at(id, 0.0) == 0 and Catalog.frame_at(id, -1.0) == 0, "frame_at starts at 0 and clamps negatives: "+String(id))
		check(Catalog.frame_at(id, 1.5/fps) == 1 and Catalog.frame_at(id, 15.5/fps) == 15, "frame_at steps by fps: "+String(id))
		check(Catalog.frame_at(id, 16.0/fps) == -1 and Catalog.frame_at(id, 999.0) == -1 and Catalog.frame_at(id, INF) == -1, "frame_at finishes without looping: "+String(id))
		check(Catalog.frame_region(id, -1) == Rect2i() and Catalog.frame_region(id, 16) == Rect2i(), "frame_region out of range is empty: "+String(id))
		# provenance
		if id in CODEX_1115_IDS:
			var row: Dictionary = repaint_assets.get(id, {})
			var sheet_hash := FileAccess.get_sha256("res://"+CODEX_1115+"%s.png" % id)
			if sheet_hash.is_empty() and not batch_root.is_empty(): sheet_hash = FileAccess.get_sha256(batch_root.path_join(CODEX_1115+"%s.png" % id))
			check(def.source == CODEX_1115+"%s.png" % id and sheet_hash == def.source_sha256 and row.get("sha256") == def.source_sha256, "15/11 repaint source hash: "+String(id))
			check(row.get("generator") == "Codex built-in imagegen" and row.get("prompt") is String and String(row.get("prompt")).length() > 80 and int(row.get("width", 0)) == 1254 and int(row.get("height", 0)) == 1254, "15/11 repaint prompt recorded: "+String(id))
			continue
		if id in CODEX_1114_IDS:
			var row: Dictionary = batch_assets.get(id, {})
			var sheet_hash := FileAccess.get_sha256("res://"+CODEX_1114+"%s.png" % id)
			if sheet_hash.is_empty() and not batch_root.is_empty(): sheet_hash = FileAccess.get_sha256(batch_root.path_join(CODEX_1114+"%s.png" % id))
			check(def.source == CODEX_1114+"%s.png" % id and sheet_hash == def.source_sha256 and row.get("sha256") == def.source_sha256, "second batch source hash: "+String(id))
			check(row.get("generator") == "Codex built-in imagegen" and row.get("prompt") is String and String(row.get("prompt")).length() > 80 and int(row.get("width", 0)) == 1254 and int(row.get("height", 0)) == 1254, "second batch prompt recorded: "+String(id))
			continue
		var entry: Dictionary = assets.get(id, {})
		var staging_path := "res://"+STAGING+"%s.png" % id
		var staged_hash := FileAccess.get_sha256(staging_path)
		if staged_hash.is_empty() and not source_root.is_empty(): staged_hash = FileAccess.get_sha256(source_root.path_join(STAGING+"%s.png" % id))
		check(not entry.is_empty() and entry.sha256 == def.source_sha256 and (staged_hash.is_empty() or staged_hash == entry.sha256), "provenance sha256 matches staging sheet: "+String(id))
		check(entry.get("generator") == "Codex built-in imagegen" and entry.get("prompt") == null and entry.get("status") == "generated_project_art_prompt_unrecorded" and entry.get("rights_basis") == "project_generated_output" and entry.get("width") == 1254 and entry.get("height") == 1254, "provenance policy fields: "+String(id))
	# copies
	var first := Catalog.definition(&"fire_burst")
	first.grid[0] = 99; first.erase("cell"); first["empty_frames"].append(3)
	var second := Catalog.definition(&"fire_burst")
	check(_ints(second.grid) == [4,4] and second.has("cell") and _ints(second.empty_frames) == [15], "definition returns independent copies")
	var listing := Catalog.ids(); listing.clear()
	check(Catalog.ids().size() == 19, "ids returns a copy")
	# fail closed
	check(Catalog.definition(&"missing").is_empty() and Catalog.texture(&"missing") == null and Catalog.frame_at(&"missing", 0.0) == -1 and Catalog.frame_region(&"missing", 0) == Rect2i(), "unknown id fails closed")
	var good := Catalog.definition(&"slash_arc")
	check(Catalog.validate(&"slash_arc", good), "validator accepts a real manifest")
	for mutation: String in ["id","grid","cell","frames","texture","anchor_uv","suggested_fps","empty_frames","bad_grid","bad_frames","bad_anchor","bad_fps","bad_empty","wrong_id"]:
		var bad := good.duplicate(true)
		match mutation:
			"bad_grid": bad.grid = [0,4]
			"bad_frames": bad.frames = 17
			"bad_anchor": bad.anchor_uv = [1.5,0.5]
			"bad_fps": bad.suggested_fps = 0
			"bad_empty": bad.empty_frames = [16]
			"wrong_id": bad.id = "other"
			_: bad.erase(mutation)
		check(not Catalog.validate(&"slash_arc", bad), "validator rejects: "+mutation)
	print("E08 VFX ART: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
