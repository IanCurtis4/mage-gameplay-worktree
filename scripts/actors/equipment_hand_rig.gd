class_name EquipmentHandRig
extends RefCounted
## Explicit immutable cell-space hand calibration; never inspects pixels during play.
const PATH := "res://assets/art/equipment/hand_rigs.json"
static var _data: Dictionary = {}
static func pose(kind: StringName,frame: int) -> Dictionary:
	if _data.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
		if not parsed is Dictionary or parsed.get("format")!="equipment_hand_rigs_v1": return {}
		_data=parsed
	var identity: Dictionary = _data["identities"].get(String(kind),{})
	if identity.is_empty() or frame<0 or frame>=32:return {}
	var raw: Dictionary = identity["frames"][frame]
	return {"main":Vector2(raw["main"][0],raw["main"][1]),"off":Vector2(raw["off"][0],raw["off"][1]),"main_fingers":Rect2(raw["main_fingers"][0],raw["main_fingers"][1],raw["main_fingers"][2],raw["main_fingers"][3]),"off_fingers":Rect2(raw["off_fingers"][0],raw["off_fingers"][1],raw["off_fingers"][2],raw["off_fingers"][3]),"back":raw["back"]}
static func identities() -> Array:
	pose(&"swordsman",0)
	return _data.get("identities",{}).keys()
