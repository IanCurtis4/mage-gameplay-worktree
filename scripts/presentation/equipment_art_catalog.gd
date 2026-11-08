class_name EquipmentArtCatalog
extends RefCounted
## Immutable cosmetic bindings by existing definition ID; never gameplay eligibility.
const FORMAT := &"painted_equipment_v1"
const HEAD_IDS: Array[StringName] = [&"pilot_head",&"class_set_swordsman_head",&"class_set_archer_head",&"class_set_mage_head",&"class_set_defender_head",&"class_set_berserker_head",&"class_set_elementalist_head",&"class_set_spiritualist_head",&"class_set_sentinel_head",&"class_set_hunter_head",&"class_set_mg_ar_head",&"shared_set_low_head",&"shared_set_mid_head",&"shared_set_high_head"]
const PROP_KEYS: Array[StringName] = [&"sword",&"axe",&"staff",&"bow",&"shield",&"prismatic_focus",&"wooden_beads"]
const HEAD_CELL := Vector2(24,24)
const HEAD_ANCHOR := Vector2(12,13)
const SOURCE_SCALE := 4.0
static var _raw: Dictionary = {}
static var _filtered: Dictionary = {}
static var _icons: Dictionary = {}
static var _bounds: Dictionary = {}
static var _errors: Dictionary = {}
static func head_ids() -> Array[StringName]: return HEAD_IDS.duplicate()
static func has_head(id: StringName) -> bool: return id in HEAD_IDS
static func head_path(id: StringName) -> String:
	return "res://assets/art/equipment/headgear/%s.png" % id if has_head(id) else ""
static func prop_path(key: StringName) -> String:
	return "res://assets/art/equipment/painted/%s.png" % key if key in PROP_KEYS else ""
static func _checked(path: String,expected: Vector2) -> Texture2D:
	if path.is_empty():return null
	if _raw.has(path):return _raw[path] as Texture2D
	var texture: Texture2D
	var detail := "missing_painted_texture"
	if ResourceLoader.exists(path,"Texture2D"):
		texture=load(path) as Texture2D
		if texture!=null and texture.get_size()==expected:
			var image := texture.get_image()
			if image!=null and not image.is_empty() and image.get_used_rect().has_area():
				_raw[path]=texture;return texture
		detail="invalid_painted_texture"
	_raw[path]=null;_errors[path]=detail
	push_warning("Equipment art fallback: "+detail+" "+path)
	return null
static func error_for(path: String) -> String: return _errors.get(path,"")
static func _linear(texture: Texture2D) -> Texture2D:
	if texture==null:return null
	var path := texture.resource_path
	if not _filtered.has(path):
		var canvas := CanvasTexture.new();canvas.diffuse_texture=texture
		canvas.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR
		_filtered[path]=canvas
	return _filtered[path] as Texture2D
static func head_texture(id: StringName) -> Texture2D:
	return _linear(_checked(head_path(id),Vector2(384,96)))
static func prop_texture(key: StringName,logical_size: Vector2) -> Texture2D:
	return _linear(_checked(prop_path(key),logical_size*SOURCE_SCALE))
static func prop_bounds(key: StringName,logical_size: Vector2) -> Rect2:
	var path := prop_path(key)
	var texture := _checked(path,logical_size*SOURCE_SCALE)
	if texture==null:return Rect2()
	if not _bounds.has(path):
		var pixels := texture.get_image().get_used_rect()
		_bounds[path]=Rect2(Vector2(pixels.position)/SOURCE_SCALE,Vector2(pixels.size)/SOURCE_SCALE)
	return _bounds[path]
static func head_icon(id: StringName) -> Texture2D:
	if not has_head(id):return null
	if not _icons.has(id):
		var texture := head_texture(id)
		if texture==null:return null
		var region := AtlasTexture.new();region.atlas=texture;region.region=Rect2(0,0,96,96);region.filter_clip=true
		_icons[id]=region
	return _icons[id] as Texture2D
