class_name DirectionalAnimationSet
extends RefCounted
## Immutable, validated presentation catalog. Never held in the saved actor graph.
const FORMAT := "ragrpg_directional_animation_v2"
const SIZE := Vector2(256, 1024)
const SLOTS := ["main_hand", "off_hand", "arms"]
const WEAPON_KEYS := ["sword", "axe", "staff", "bow", "shield", "prismatic_focus", "wooden_beads"]
static var _manifests: Dictionary = {}
static var _textures: Dictionary = {}
var _kind: StringName
var _body: Texture2D
var _weaponless: Texture2D
var _bare_head: Texture2D
var _frames: Array = []
var _offsets := PackedFloat32Array()

static func default_path(kind: StringName) -> String:
	return "res://assets/art/animations/directional/%s/presentation.json" % kind

static func load_manifest(path: String) -> Dictionary:
	if _manifests.has(path): return _manifests[path].duplicate()
	var result := _load(path)
	_manifests[path] = result.duplicate()
	if result.get("ok", false):
		var bundle: DirectionalAnimationSet = result.bundle
		for texture: Texture2D in [bundle._body, bundle._weaponless, bundle._bare_head]:
			if texture == null: continue
			# Catalog-owned textures have a direct binding for the render loop.
			# Paths still resolve cold snapshots and equivalent resource handles.
			_textures[texture] = bundle
			_textures[texture.resource_path] = bundle
	return result

static func for_texture(texture: Texture2D) -> DirectionalAnimationSet:
	if texture == null: return null
	var bundle: DirectionalAnimationSet = _textures.get(texture)
	if bundle != null: return bundle
	var path := texture.resource_path
	if _textures.has(path): return _textures[path]
	# Derive the binding from the persisted resource path, also in a fresh process.
	if texture.get_size() == SIZE and _resource_path(path):
		var manifest := path.get_base_dir().path_join("presentation.json")
		if FileAccess.file_exists(manifest):
			load_manifest(manifest)
	if not _textures.has(path): _textures[path] = null
	return _textures[path]

static func _load(path: String) -> Dictionary:
	if not _resource_path(path) or path.get_file() != "presentation.json": return _failure("invalid_manifest_path")
	if not FileAccess.file_exists(path): return _failure("missing_manifest")
	var parser := JSON.new()
	if parser.parse(FileAccess.get_file_as_string(path)) != OK or not parser.data is Dictionary: return _failure("invalid_manifest_json")
	return _validate_data(parser.data,path)

static func _validate_data(data: Dictionary, path: String) -> Dictionary:
	if data.get("format") != FORMAT or (not _point(data.get("pivot")) or int(data.pivot[0])!=32 or int(data.pivot[1])!=58): return _failure("invalid_manifest_format")
	if not data.get("actor_kind") is String or String(data.actor_kind).is_empty(): return _failure("invalid_actor_kind")
	var bundle := DirectionalAnimationSet.new()
	bundle._kind = StringName(data.actor_kind)
	var loaded := _load_texture(data.get("body"), path)
	if not loaded.ok: return loaded
	bundle._body = loaded.texture
	if data.get("weaponless") != null:
		loaded = _load_texture(data.weaponless, path)
		if not loaded.ok: return loaded
		bundle._weaponless = loaded.texture
	# All player identities must provide the equipable body as part of the same unit.
	if bundle._kind in [ &"swordsman", &"archer", &"mage", &"berserker", &"defender", &"hunter", &"sentinel", &"elementalist", &"spiritualist", &"geometer"] and bundle._weaponless == null:
		return _failure("missing_weaponless_body")
	if bundle._weaponless != null and bundle._weaponless.resource_path == bundle._body.resource_path: return _failure("shared_body_paths")
	if data.has("bare_head"):
		if bundle._weaponless==null:return _failure("bare_head_requires_weaponless")
		loaded=_load_texture(data.bare_head,path)
		if not loaded.ok:return loaded
		bundle._bare_head=loaded.texture
		if bundle._bare_head.resource_path in [bundle._body.resource_path,bundle._weaponless.resource_path]:return _failure("shared_bare_head_path")
	if not data.get("frames") is Array or data.frames.size() != 64: return _failure("invalid_frame_count")
	var images: Array[Image] = [bundle._body.get_image()]
	if bundle._weaponless != null: images.append(bundle._weaponless.get_image())
	if bundle._bare_head != null: images.append(bundle._bare_head.get_image())
	for index: int in 64:
		var problem := _validate_frame(data.frames[index], index, images, bundle._weaponless!=null)
		if not problem.is_empty(): return _failure(problem+" frame="+str(index))
	bundle._frames = data.frames.duplicate(true)
	for raw: Dictionary in bundle._frames: bundle._offsets.append(58.0-float(raw.ground_y))
	return {"ok":true, "bundle":bundle}

static func _load_texture(raw: Variant, manifest: String) -> Dictionary:
	if not raw is Dictionary or not raw.get("path") is String or not raw.get("rgba_sha256") is String: return _failure("invalid_texture_record")
	var path: String = raw.path
	if not _resource_path(path) or path.get_base_dir() != manifest.get_base_dir() or not path.ends_with(".png"): return _failure("texture_outside_manifest_directory")
	if not ResourceLoader.exists(path,"Texture2D"): return _failure("missing_texture")
	var texture := load(path) as Texture2D
	if texture == null or texture.get_size() != SIZE: return _failure("invalid_texture_size")
	var bitmap := texture.get_image()
	if bitmap == null or bitmap.is_empty() or bitmap.is_compressed(): return _failure("invalid_texture_pixels")
	bitmap.convert(Image.FORMAT_RGBA8)
	# Godot's alpha-border fix changes RGB under fully transparent pixels.
	# Ignore only that invisible RGB; every visible RGBA byte remains bound.
	var pixels := bitmap.get_data()
	for i: int in range(0,pixels.size(),4):
		if pixels[i+3]==0: pixels[i]=0; pixels[i+1]=0; pixels[i+2]=0
	var digest := _digest(pixels)
	if digest != raw.rgba_sha256: return _failure("texture_hash_mismatch")
	# A different complete image block is necessary, though not sufficient, for each view.
	bitmap=Image.create_from_data(256,1024,false,Image.FORMAT_RGBA8,pixels)
	var blocks: Array[String] = []
	for direction: int in 4:
		var block := bitmap.get_region(Rect2i(0,direction*256,256,256))
		var hash := _digest(block.get_data())
		if hash in blocks: return _failure("duplicate_direction_blocks")
		blocks.append(hash)
	return {"ok":true,"texture":texture}

static func _validate_frame(raw: Variant, index: int, images: Array[Image], equippable: bool) -> String:
	if not raw is Dictionary or not raw.get("slots") is Dictionary or not raw.get("head") is Dictionary: return "invalid_frame"
	if not _integer(raw.get("ground_y"),0,63): return "invalid_ground"
	for image: Image in images:
		var tile := image.get_region(Rect2i(index%4*64,index/4*64,64,64))
		var bounds := tile.get_used_rect()
		if not bounds.has_area() or bounds.end.y-1 != int(raw.ground_y): return "ground_pixel_mismatch"
		for slot: String in SLOTS:
			if not raw.slots.get(slot) is Dictionary: return "missing_slot"
			var pose: Dictionary = raw.slots[slot]
			if not _point(pose.get("point")) or not _transform(pose): return "invalid_slot_transform"
			if not _crop(pose.get("fingers")): return "invalid_finger_crop"
			if not pose.get("angle_overrides",{}) is Dictionary or not pose.get("depth_overrides",{}) is Dictionary: return "invalid_overrides"
			for key: Variant in pose.get("angle_overrides",{}):
				if key not in WEAPON_KEYS or not _angle(pose.angle_overrides[key]): return "invalid_angle_override"
			for key: Variant in pose.get("depth_overrides",{}):
				if key not in WEAPON_KEYS or not _integer(pose.depth_overrides[key],0,1): return "invalid_depth_override"
			if equippable and slot != "arms" and index%16 < 14:
				if tile.get_pixel(int(pose.point[0]),int(pose.point[1])).a <= 0.5: return "grip_outside_body"
				var crop := tile.get_region(Rect2i(int(pose.fingers[0]),int(pose.fingers[1]),int(pose.fingers[2]),int(pose.fingers[3])))
				if not crop.get_used_rect().has_area(): return "empty_fingers"
	var head: Dictionary = raw.head
	if not _point(head.get("point")) or not _transform(head) or not head.get("visible") is bool: return "invalid_head"
	return ""

static func _resource_path(path: String) -> bool:
	return path.begins_with("res://") and not path.contains("..") and not path.contains("::") and not path.contains("\\")
static func _integer(value: Variant, minimum: int, maximum: int) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) == floorf(float(value)) and value >= minimum and value <= maximum
static func _point(value: Variant) -> bool:
	return value is Array and value.size()==2 and _integer(value[0],0,63) and _integer(value[1],0,63)
static func _angle(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and absf(float(value))<=TAU
static func _transform(value: Dictionary) -> bool:
	return _angle(value.get("angle")) and _integer(value.get("depth"),0,1) and value.get("flip") is bool
static func _crop(value: Variant) -> bool:
	return value is Array and value.size()==4 and _integer(value[0],0,63) and _integer(value[1],0,63) and _integer(value[2],1,64) and _integer(value[3],1,64) and value[0]+value[2]<=64 and value[1]+value[3]<=64
static func _digest(bytes: PackedByteArray) -> String:
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256); context.update(bytes)
	return context.finish().hex_encode()
static func _failure(detail: String) -> Dictionary:
	return {"ok":false,"error_code":&"invalid_directional_presentation","detail":detail}

func actor_kind() -> StringName: return _kind
func body(equipped: bool,head_equipped: bool = false) -> Texture2D:
	if equipped and head_equipped and _bare_head!=null:return _bare_head
	return _weaponless if equipped and _weaponless != null else _body
func has_bare_head() -> bool: return _bare_head!=null
func frame(index: int) -> Dictionary:
	return _frames[index].duplicate(true) if index>=0 and index<64 else {}

func ground_offsets() -> PackedFloat32Array: return _offsets.duplicate()
