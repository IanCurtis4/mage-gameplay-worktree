@tool
extends "res://scripts/map_authoring/preview/map_canvas.gd"
const Population = preload("res://scripts/map_authoring/population/population_compiler.gd")
const Catalog = preload("res://scripts/map_authoring/population/population_catalog.gd")
signal painted(point: Dictionary)
signal slot_selected(id: String)
var source: Dictionary = {}
var preview_diff: Dictionary = {}
var encounters: Dictionary = {}
var campaign: ExpeditionCampaignState
var paint_enabled := false
var selected_slot := ""
func set_encounters(value: Dictionary) -> void:
	encounters = value.duplicate(true); set_package(value.map_package)
	geometry = WorldGeometry.new(); geometry.configure(Population.manifest(value),"map_preview"); redraw()
func start_test() -> Dictionary:
	if encounters.is_empty(): return {"ok":false}
	stop_test()
	var created := Population.make_campaign(encounters)
	if not created.ok: return created
	campaign = created.state; campaign.visit("map_preview")
	motion = Motion.new()
	var result := motion.configure(geometry,ExpeditionPopulationPlanner.point(campaign.anchor),encounters.profile,"discardable_editor_actor")
	testing = result.ok; redraw(); return result
func stop_test() -> void:
	super.stop_test(); campaign = null
func simulate_death(id: String) -> Dictionary:
	if campaign == null or not campaign.slots.has(id): return {"ok":false}
	var slot: Dictionary = campaign.slots[id]
	var result := campaign.record_death(id,slot.generation,"editor_death_"+id+"_"+str(slot.generation)); redraw(); return result
func simulate_wave() -> void:
	if campaign == null: return
	campaign.advance(campaign.clock.interval)
	for id: String in campaign.slots:
		if campaign.slots[id].life_state == "respawn_pending": campaign.admit_respawn(id)
	redraw()
func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and not testing:
		var hit := pick(event.position)
		if not hit.ok: status.emit("Sem superfície visível. Escolha a camada correta."); return
		if paint_enabled: painted.emit({"surface_id":hit.data.point.surface_id,"position_xyz":Population.xyz(hit.data.point.position)}); return
		var nearest := ""; var distance := 14.0
		for slot: Dictionary in source.get("slots",[]):
			var d := screen(Population.vector(slot.position_xyz)).distance_to(event.position)
			if d < distance: nearest = slot.slot_id; distance = d
		if nearest != "": selected_slot = nearest; slot_selected.emit(nearest); redraw(); return
	super._gui_input(event)
func _draw_world() -> void:
	super._draw_world()
	if package.is_empty() or source.is_empty(): return
	for region: Dictionary in source.get("exclusions",[]): _ring(Population.vector(region.center_xyz),region.radius,Color("f28b82"))
	for brush: Dictionary in source.get("brushes",[]): _ring(Population.vector(brush.center_xyz),brush.radius,Color("92bde8"))
	for entry: Dictionary in source.get("entrance",[]): _label(Population.vector(entry.position_xyz),"Entrada",Color("9ae2ba"))
	for interaction: Dictionary in source.get("interactions",[]):
		_label(Population.vector(interaction.position_xyz),{"portal":"Portal","phase_completion":"Conclusão","early_exit":"Saída","thematic_encounter":"Palco"}[interaction.kind],Color("e7c77a"))
	for slot: Dictionary in source.get("slots",[]):
		var at := screen(Population.vector(slot.position_xyz)); var alive: bool = campaign == null or campaign.slots[slot.slot_id].life_state == "alive"
		var color := Color("f2b875") if slot.fixed else Color("ed859a")
		var caption := "Fixo" if slot.fixed else "Inimigo"
		if slot.slot_id in preview_diff.get("changed",[]): color = Color("bba2ff"); caption = "Alterado"
		elif slot.slot_id in preview_diff.get("added",[]): caption = "Novo"
		if not alive: color = Color("777777")
		_overlay.draw_circle(at,6,color)
		if slot.fixed: _overlay.draw_rect(Rect2(at-Vector2(9,9),Vector2(18,18)),color,false,2)
		if selected_slot == slot.slot_id: _overlay.draw_circle(at,12,Color.WHITE,false,2)
		_overlay.draw_string(ThemeDB.fallback_font,at+Vector2(8,-6),caption,HORIZONTAL_ALIGNMENT_LEFT,-1,12,color)
func _label(point: Vector3, text: String, color: Color) -> void:
	var at := screen(point); _overlay.draw_circle(at,5,color)
	_overlay.draw_string(ThemeDB.fallback_font,at+Vector2(8,-8),text,HORIZONTAL_ALIGNMENT_LEFT,-1,13,color)
func _ring(point: Vector3, radius: float, color: Color) -> void:
	var points := PackedVector2Array()
	for i: int in 49:
		var angle := TAU*float(i)/48; points.append(screen(point+Vector3(cos(angle)*radius,0,sin(angle)*radius)))
	_overlay.draw_polyline(points,color,1.5)
