extends SceneTree
## Extraction uses production V1 API, never a copied angle/depth formula.
const D = preload("res://tests/fixtures/e08_directional/fixture.gd")
const KINDS: Array[StringName] = [&"swordsman",&"mage",&"archer",&"defender",&"berserker",&"hunter",&"sentinel",&"geometer"]
func _initialize() -> void:
	var output: Dictionary={}
	for kind: StringName in KINDS:
		var frames: Array=[]
		for direction: int in 2:
			for pose: int in 14:
				var state := D.state(direction,pose)
				var slots: Dictionary={}
				for slot: StringName in [&"main_hand",&"off_hand",&"arms"]:
					var keys: Dictionary={}
					for key: StringName in EquipmentAttachmentVisual.SUPPORTED:
						var placed := EquipmentAttachmentVisual.placement(kind,state,key,slot,Vector2.ZERO)
						var point: Vector2=placed.point;var fingers: Rect2=placed.finger_rect
						keys[String(key)]={"point":[point.x,point.y],"fingers":[fingers.position.x,fingers.position.y,fingers.size.x,fingers.size.y],"angle":placed.angle,"depth":placed.depth}
					slots[String(slot)]=keys
				frames.append({"index":direction*16+pose,"legacy_frame":state.frame_index(),"slots":slots})
			
		output[String(kind)]=frames
	var file := FileAccess.open(OS.get_cmdline_user_args()[0].path_join("reference.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(output,"  ",true));file.close()
	print("V1 reference: ",KINDS.size()*28*3*7," placements extracted via existing API")
	quit()
