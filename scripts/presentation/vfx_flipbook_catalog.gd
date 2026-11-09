class_name VfxFlipbookCatalog
extends RefCounted
## Immutable catalog of the P6 raster VFX flipbooks (4x4 atlases of 160x160 cells).
## Data only: no nodes, no gameplay references. Fails closed on any invalid manifest.

const MANIFESTS := {
	&"arcane_warp": "res://assets/art/e08_vfx/arcane_warp/flipbook.json",
	&"blood_rift": "res://assets/art/e08_vfx/blood_rift/flipbook.json",
	&"fire_burst": "res://assets/art/e08_vfx/fire_burst/flipbook.json",
	&"ground_shockwave": "res://assets/art/e08_vfx/ground_shockwave/flipbook.json",
	&"ice_shatter": "res://assets/art/e08_vfx/ice_shatter/flipbook.json",
	&"lightning_burst": "res://assets/art/e08_vfx/lightning_burst/flipbook.json",
	&"nature_thorns": "res://assets/art/e08_vfx/nature_thorns/flipbook.json",
	&"slash_arc": "res://assets/art/e08_vfx/slash_arc/flipbook.json",
	&"summon_portal": "res://assets/art/e08_vfx/summon_portal/flipbook.json",
}

static var _cache: Dictionary = {}

static func ids() -> Array:
	return MANIFESTS.keys()

static func definition(id: StringName) -> Dictionary:
	return _load(id, MANIFESTS.get(id, "")).duplicate(true)

static func frame_region(id: StringName, frame: int) -> Rect2i:
	var data := _load(id, MANIFESTS.get(id, ""))
	if data.is_empty() or frame < 0 or frame >= int(data.frames):
		return Rect2i()
	var grid: Array = data.grid
	var cell: Array = data.cell
	return Rect2i((frame % int(grid[0])) * int(cell[0]), floori(float(frame) / float(grid[0])) * int(cell[1]), int(cell[0]), int(cell[1]))

static func texture(id: StringName) -> Texture2D:
	var data := _load(id, MANIFESTS.get(id, ""))
	if data.is_empty():
		return null
	var loaded: Resource = load(String(data.texture))
	var result := loaded as Texture2D
	if result == null:
		return null
	var cell: Array = data.cell
	var grid: Array = data.grid
	if result.get_width() != int(cell[0]) * int(grid[0]) or result.get_height() != int(cell[1]) * int(grid[1]):
		return null
	return result

## Frame index for an effect that started elapsed_seconds ago; -1 once finished (never loops).
static func frame_at(id: StringName, elapsed_seconds: float) -> int:
	var data := _load(id, MANIFESTS.get(id, ""))
	if data.is_empty() or not is_finite(elapsed_seconds):
		return -1
	if elapsed_seconds < 0.0:
		return 0
	var index := int(floor(elapsed_seconds * float(data.suggested_fps)))
	return -1 if index >= int(data.frames) else index

static func _load(id: StringName, path: String) -> Dictionary:
	if path.is_empty():
		return {}
	if _cache.has(id):
		return _cache[id]
	var parsed: Variant = null
	if FileAccess.file_exists(path):
		parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	var result: Dictionary = parsed if parsed is Dictionary and _valid(id, parsed) else {}
	_cache[id] = result
	return result

static func _valid(id: StringName, data: Dictionary) -> bool:
	return validate(id, data)

## Public so tests can exercise fail-closed behaviour on synthetic manifests.
static func validate(id: StringName, data: Dictionary) -> bool:
	for key: String in ["id", "grid", "cell", "frames", "texture", "anchor_uv", "suggested_fps", "empty_frames", "loop"]:
		if not data.has(key):
			return false
	if String(data.id) != String(id) or not (data.texture is String):
		return false
	for pair_key: String in ["grid", "cell", "anchor_uv"]:
		if not (data[pair_key] is Array) or (data[pair_key] as Array).size() != 2:
			return false
		for value: Variant in data[pair_key]:
			if not (value is float or value is int):
				return false
	var grid: Array = data.grid
	var cell: Array = data.cell
	if not (data.frames is float or data.frames is int) or not (data.suggested_fps is float or data.suggested_fps is int):
		return false
	if int(grid[0]) < 1 or int(grid[1]) < 1 or int(cell[0]) < 1 or int(cell[1]) < 1:
		return false
	if int(data.frames) < 1 or int(data.frames) > int(grid[0]) * int(grid[1]) or float(data.suggested_fps) <= 0.0:
		return false
	for value: Variant in data.anchor_uv:
		if float(value) < 0.0 or float(value) > 1.0:
			return false
	if not (data.empty_frames is Array):
		return false
	for value: Variant in data.empty_frames:
		if not (value is float or value is int) or int(value) < 0 or int(value) >= int(data.frames):
			return false
	return true
