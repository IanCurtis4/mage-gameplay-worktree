extends SceneTree
## Visual-only contact sheets, explicit frames and no save access.
const KINDS = [&"swordsman", &"defender", &"berserker", &"mage", &"elementalist", &"spiritualist", &"geometer", &"archer", &"sentinel", &"hunter"]
const KEYS = [&"sword", &"sword", &"axe", &"staff", &"staff", &"staff", &"staff", &"bow", &"bow", &"bow"]
class PoseCanvas extends Node2D:
	var animation: CharacterAnimation
	var visual_scale := 2.0
	func _draw() -> void: animation.draw_on(self,Color.WHITE,visual_scale)
func _initialize() -> void: run.call_deferred()
static func set_frame(state: CombatAnimationState,frame: int) -> void:
	state.back_view = frame in range(12,24) or frame in [26,27,30,31]
	if frame>=28:
		state.dead=true
		state.death_time=0.2 if frame%2 else 0.0
	elif frame>=24: state.hurt_remaining=0.05 if frame%2 else 0.15
	elif frame in range(8,12) or frame in range(20,24):
		state.action=&"attack"
		state.action_duration=1.0
		state.action_remaining=1.0-(frame%4+0.1)/4.0
	elif frame in range(4,8) or frame in range(12,16):
		state.moving=true
		state.walk_distance=(frame%4)*16.0
	else: state.idle_time=(frame%4+0.1)/4.0
	assert(state.frame_index()==frame)
func run() -> void:
	root.size=Vector2i(1280,720)
	root.transparent_bg=false
	var flipped := "flip" in OS.get_cmdline_user_args()
	var directory="res://.godot/verification/e06_equipment_alignment"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
	for index: int in range(KINDS.size()):
		var holder=Node2D.new()
		root.add_child(holder)
		for frame: int in range(32):
			var origin=Vector2(frame%8*160,(frame/8)*170)
			var tile=ColorRect.new()
			tile.position=origin
			tile.size=Vector2(160,170)
			tile.color=Color("192936") if frame%2==0 else Color("698274")
			holder.add_child(tile)
			var label=Label.new()
			label.text="%s %02d" % [KINDS[index],frame]
			label.position=origin+Vector2(5,3)
			holder.add_child(label)
			var canvas=PoseCanvas.new()
			canvas.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
			canvas.position=origin+Vector2(80,145)
			canvas.animation=CharacterAnimation.new()
			canvas.animation.configure(KINDS[index])
			canvas.animation.equipment_visual={"main_hand":KEYS[index],"off_hand":&"shield" if index in [0,1] else &"", "arms":&"wooden_beads" if index==5 else &""}
			set_frame(canvas.animation.state,frame)
			canvas.animation.state.flip_h=flipped
			holder.add_child(canvas)
		await process_frame
		await process_frame
		await RenderingServer.frame_post_draw
		var equipped_image := root.get_texture().get_image()
		assert(equipped_image.save_png(directory+"/%s%s.png" % [KINDS[index],"_flip" if flipped else ""])==OK)
		if index>=7:
			for child: Node in holder.get_children():
				if child is PoseCanvas:
					child.animation.equipment_visual={"main_hand":&"","off_hand":&"","arms":&""}
					child.queue_redraw()
			await process_frame
			await RenderingServer.frame_post_draw
			var naked_image := root.get_texture().get_image()
			# Compare opaque face pixels with the actual renderer without any equipment.
			# Recoil must not let a bow/string cover eyes or face; contours remain antialiased.
			var compared := 0
			for child: Node in holder.get_children():
				if not child is PoseCanvas:continue
				var animation: CharacterAnimation = child.animation
				var frame := animation.state.frame_index()
				if frame not in [24,25]:continue
				var cell := animation.atlas.get_image().get_region(Rect2i(animation.source_region(frame)))
				for y: int in range(15,32):
					for x: int in range(20,51):
						if cell.get_pixel(x,y).a<0.99:continue
						var local := animation.destination_rect(frame).position+Vector2(x+0.5,y+0.5)
						if flipped:local.x=-local.x
						var at := Vector2i(child.position+local*2.0)
						assert(equipped_image.get_pixelv(at).is_equal_approx(naked_image.get_pixelv(at)),"bow covers face %s/%d/%s" % [KINDS[index],frame,at])
						compared+=1
			assert(compared>0)
			print("RECOIL_FACE_PIXELS_OK ",KINDS[index]," ",compared," flip=",flipped)
		holder.queue_free()
		await process_frame
	await pieces_sheet(directory)
	print("EQUIPMENT_ALIGNMENT_NATIVE_OK 10 identities / 320 poses")
	quit(0)

func pieces_sheet(directory: String) -> void:
	var keys := [&"sword",&"axe",&"staff",&"bow",&"shield",&"prismatic_focus",&"wooden_beads"]
	var kinds := [&"swordsman",&"berserker",&"mage",&"sentinel",&"defender",&"elementalist",&"spiritualist"]
	var names := ["Espada","Machado","Cajado","Arco","Escudo","Foco prismático","Contas no pulso"]
	for page: int in range(2):
		var holder := Node2D.new()
		root.add_child(holder)
		for row: int in range(4):
			var index := page*4+row
			if index>=keys.size():continue
			var tile := ColorRect.new()
			tile.position=Vector2(0,row*170)
			tile.size=Vector2(1280,170)
			tile.color=Color("172936") if row%2==0 else Color("698274")
			holder.add_child(tile)
			var label := Label.new()
			label.text=names[index]
			label.position=tile.position+Vector2(10,3)
			holder.add_child(label)
			var icon := Sprite2D.new()
			icon.texture=load("res://assets/art/equipment/%s.svg" % keys[index])
			icon.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
			icon.position=tile.position+Vector2(75,100)
			holder.add_child(icon)
			for column: int in range(4):
				var canvas := PoseCanvas.new()
				canvas.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
				canvas.visual_scale=1.0 if column==0 else 2.4
				canvas.position=tile.position+Vector2(220+column*290,160)
				canvas.animation=CharacterAnimation.new()
				canvas.animation.configure(kinds[index])
				canvas.animation.equipment_visual={"main_hand":keys[index] if index<4 else &"","off_hand":keys[index] if index in [4,5] else &"","arms":keys[index] if index==6 else &""}
				canvas.animation.state.back_view=column==2
				canvas.animation.state.flip_h=column==3
				holder.add_child(canvas)
		await process_frame
		await process_frame
		await RenderingServer.frame_post_draw
		assert(root.get_texture().get_image().save_png(directory+"/seven_pieces_%d.png" % page)==OK)
		holder.queue_free()
		await process_frame
