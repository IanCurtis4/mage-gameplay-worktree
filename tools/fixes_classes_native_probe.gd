extends SceneTree
## Read-only native appearance contact sheets, independent of gameplay and personal saves.
const GROUPS := [[&"swordsman",&"defender",&"berserker",&"geometer"],[&"mage",&"elementalist",&"spiritualist"],[&"archer",&"sentinel",&"hunter"]]
const NAMES := {&"swordsman":"Espadachim",&"defender":"Defensor",&"berserker":"Berserker",&"geometer":"Geômetra",&"mage":"Mago",&"elementalist":"Elementalista",&"spiritualist":"Espiritualista",&"archer":"Arqueiro",&"sentinel":"Sentinela",&"hunter":"Caçadora"}
class Sprite extends Node2D:
	var animation: CharacterAnimation
	func _draw() -> void: animation.draw_on(self,Color.WHITE,2.0)
func _initialize() -> void: _run.call_deferred()
func _run() -> void:
	root.size = Vector2i(1280,720)
	var directory := "res://.godot/verification/e06_playtest_fixes/native_classes"
	DirAccess.make_dir_recursive_absolute(directory)
	for page: int in GROUPS.size():
		var canvas := Control.new();canvas.size=Vector2(1280,720);root.add_child(canvas)
		var background := ColorRect.new();background.size=canvas.size;background.color=Color("172b31");canvas.add_child(background)
		var title := Label.new();title.text="Corpos e anexos · dez identidades · sem arma, frente, costas, ataque e morte";title.position=Vector2(12,8);canvas.add_child(title)
		var labels := ["Sem arma","Equipado / frente","Equipado / costas","Ataque","Morte"]
		for column: int in 5:
			var label := Label.new();label.text=labels[column];label.position=Vector2(column*256+8,35);canvas.add_child(label)
		for row: int in GROUPS[page].size():
			var kind: StringName = GROUPS[page][row]
			var panel := ColorRect.new();panel.position=Vector2(0,60+row*155);panel.size=Vector2(1280,155);panel.color=Color("a3b5a1") if row%2==0 else Color("233c43");canvas.add_child(panel)
			var label := Label.new();label.text=NAMES[kind];label.position=panel.position+Vector2(8,2);label.add_theme_color_override("font_color",Color("182333") if row%2==0 else Color("f1dba4"));canvas.add_child(label)
			var main: StringName = &"axe" if kind==&"berserker" else (&"bow" if kind in [&"archer",&"sentinel",&"hunter"] else (&"staff" if kind in [&"mage",&"elementalist",&"spiritualist",&"geometer"] else &"sword"))
			var off: StringName = &"shield" if kind in [&"swordsman",&"defender"] else (&"prismatic_focus" if kind==&"elementalist" else &"")
			for column: int in 5:
				var animation := CharacterAnimation.new();animation.configure(kind)
				animation.equipment_visual={"main_hand":&"" if column==0 else main,"off_hand":&"" if column==0 else off,"arms":&"wooden_beads" if kind==&"spiritualist" and column!=0 else &""}
				animation.state.face(Vector2.UP if column==2 else Vector2.DOWN)
				if column==3: animation.state.trigger(&"attack",Vector2.DOWN,0.25);animation.state.advance(0.12,Vector2.ZERO)
				if column==4: animation=animation.death_copy();animation.state.advance(0.22,Vector2.ZERO)
				var sprite := Sprite.new();sprite.animation=animation;sprite.position=panel.position+Vector2(column*256+128,137);canvas.add_child(sprite)
		await process_frame
		await RenderingServer.frame_post_draw
		assert(root.get_texture().get_image().save_png(directory.path_join("classes_%d.png" % page))==OK)
		canvas.queue_free();await process_frame
	print("FIXES_CLASSES_NATIVE_OK ten identities, three pages, light/dark, weaponless bodies and equipment")
	quit(0)
