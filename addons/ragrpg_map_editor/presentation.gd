@tool
extends VBoxContainer
## Presentation only. Every action calls its original producer control.
static var active_mode := "ux"
static var hosts: Array[WeakRef] = []
const ACTION_IDS := {
	"Aplicar borda à peça":"apply_border_profile","Ligar por talude de transição":"apply_border_transition",
	"Objetos e vegetação…":"open_objects",
	"Nova peça":"new_piece","Compor mapa…":"compose_map","Abrir…":"open","Salvar":"save","Salvar como…":"save_as","Desfazer":"undo","Refazer":"redo",
	"Recuperar cópia":"recover_copy","Buscar rascunho…":"browse_draft","Adicionar":"add_layer","Duplicar":"duplicate_layer","Travar":"toggle_layer_lock","Aplicar nome":"apply_name",
	"Contexto da peça…":"piece_context","Intercâmbio com skills…":"exchange","Enquadrar":"fit_view","Compilar peça":"compile_piece","Cancelar":"cancel",
	"Exemplo rampa/ponte":"ramp_bridge_sample","Exemplo de peça grande":"large_piece_sample","Nova grade":"add_grid","Adicionar ponte":"add_bridge","Adicionar / atualizar":"save_connector","Remover":"remove_connector",
	"Novo mapa":"new_map","Adicionar peça…":"add_piece","Exemplo com duas peças":"two_piece_sample","Compilar mapa":"compile_map","Testar / parar":"toggle_test",
	"Publicar localmente…":"publish_local","Recuperar rascunho":"recover_draft","Encontros…":"open_population","Geração assistida…":"open_generation","Aplicar posição":"apply_placement",
	"Remover…":"remove_selected","Vincular aberturas":"link_connectors","Remover vínculo selecionado":"remove_link","Contexto do mapa…":"map_context",
	"Novo":"new_document","Importar mapa…":"import_map","Recuperar":"recover","Preparar prévia":"prepare_preview","Atual / prévia":"toggle_preview","Aplicar prévia…":"apply_preview","Compilar":"compile",
	"Patrulhas…":"open_patrols","Aplicar parâmetros ao pincel":"apply_brush","Adicionar / atualizar peso":"save_species_weight","Remover espécie":"remove_species","Fixar / liberar":"toggle_slot_pin",
	"Remover slot…":"remove_slot","Vincular portal selecionado ao destino":"link_portal","Remover marcador / pincel…":"remove_marker","Simular morte do slot selecionado":"simulate_death","Avançar uma onda de respawn":"advance_respawn_wave",
	"Importar encontros…":"import_population","Testar atores":"test_actors","Retomar teste":"resume_test","Nova rota":"add_route","Aplicar":"apply_wait","↑":"move_waypoint_up","↓":"move_waypoint_down",
	"Remover ponto…":"remove_waypoint","Vincular slots selecionados":"assign_slots","Reimportar composição":"reimport_map","Abrir pedido…":"open_request","Salvar pedido…":"save_request",
	"Desfazer pedido":"undo_request","Refazer pedido":"redo_request","Gerar prévia":"generate_preview","Comparar assembler atual":"compare_assembler","Aplicar proposta ao mapa":"apply_map_proposal",
	"Adicionar candidato":"add_candidate","Remover candidato selecionado":"remove_candidate","Definir quota da peça escolhida":"set_piece_quota","Remover quota selecionada":"remove_quota"}
var screen: Control
var screen_id := ""
var get_source: Callable
var actions: Dictionary = {}
var menus: Dictionary = {}
var mode_choice: OptionButton
var section_choice: OptionButton
var sections: Dictionary = {}
var overlay: PanelContainer
var overlay_buttons: Dictionary = {}
var guide: Label

static func mount(parent: Control, id: String, source: Callable, viewport: Control = null, groups: Dictionary = {}) -> Control:
	var host := load("res://addons/ragrpg_map_editor/presentation.gd").new() as Control
	host.screen = parent; host.screen_id = id; host.get_source = source; host.sections = groups
	parent.add_child(host); parent.move_child(host,0)
	host.build(viewport)
	return host

func build(viewport: Control) -> void:
	name = "AuthoringPresentation"
	var bar := HFlowContainer.new(); add_child(bar)
	var title := Label.new(); title.text = "Modo de trabalho"; bar.add_child(title)
	mode_choice = OptionButton.new(); mode_choice.name = "AuthoringMode"
	mode_choice.add_item("UX · criação guiada"); mode_choice.add_item("AX · ações diretas"); bar.add_child(mode_choice)
	mode_choice.item_selected.connect(func(index: int) -> void: set_mode("ux" if index == 0 else "ax"))
	if screen_id == "terrain": title.hide(); mode_choice.hide()
	for category: String in ["Arquivo","Editar","Criar","Visualizar","Validar e testar","Intercâmbio"]:
		var menu := MenuButton.new(); menu.text = category; bar.add_child(menu); menus[category] = menu
		menu.get_popup().about_to_popup.connect(func() -> void: _update_menu(category))
		menu.get_popup().id_pressed.connect(func(index: int) -> void: _invoke(menu.get_popup().get_item_metadata(index),false))
	_collect(screen)
	if not sections.is_empty():
		section_choice = OptionButton.new(); section_choice.add_item("Ferramenta: nenhuma")
		for label: String in sections: section_choice.add_item(label)
		bar.add_child(section_choice); section_choice.select(1)
		section_choice.item_selected.connect(func(_index: int) -> void: _apply_mode())
	guide = Label.new(); guide.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	guide.text = {"piece":"Crie o terreno, configure os encaixes e as áreas de encontro. Salve a peça para reutilizá-la em mapas manuais ou por seed.","map":"Escolha peças, posicione-as e vincule as aberturas. Confira o contexto do mapa e compile antes de testar.","population":"Escolha o pincel e pinte no mapa. Compare a prévia antes de aplicar os encontros.","patrol":"Crie uma rota, marque os pontos no mapa e vincule os monstros. Compile para conferir o percurso.","generation":"Fixe as regiões preservadas, escolha variantes e compare seeds antes de aplicar."}.get(screen_id,"")
	add_child(guide)
	if viewport != null:
		overlay = PanelContainer.new(); overlay.name = "AgentActionsOverlay"
		overlay.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE); overlay.offset_bottom = 108
		viewport.add_child(overlay)
		var scroll := ScrollContainer.new(); scroll.custom_minimum_size.y = 108; overlay.add_child(scroll)
		var flat := HFlowContainer.new(); flat.size_flags_horizontal = SIZE_EXPAND_FILL; scroll.add_child(flat)
		for id: String in actions:
			var button := Button.new(); button.text = actions[id].text; button.tooltip_text = id
			button.pressed.connect(func() -> void: ax_invoke(id)); flat.add_child(button); overlay_buttons[id] = button
	hosts.append(weakref(self)); _apply_mode()

func _collect(node: Node) -> void:
	for child: Node in node.get_children():
		if child == self or child is Window: continue
		if child != screen and child.get_node_or_null("AuthoringPresentation") != null: continue
		if child.get_class() == "Button":
			var button := child as Button
			var base: String = screen_id+"/"+ACTION_IDS.get(button.text,"action_"+button.text.sha256_text().substr(0,12)); var id := base; var ordinal := 2
			while actions.has(id): id = base+"_"+str(ordinal); ordinal += 1
			button.set_meta("authoring_action_id",id)
			var category := _category(button.text)
			var ax_only := button.text.begins_with("Simular") or button.text.begins_with("Avançar uma onda") or button.text in ["Matar selecionado","Avançar onda"]
			actions[id] = {"control":button,"text":button.text,"category":category,"ax_only":ax_only,"visible":button.visible}
			if not ax_only:
				var popup: PopupMenu = menus[category].get_popup(); popup.add_item(button.text)
				popup.set_item_metadata(popup.item_count-1,id)
		else: _collect(child)

static func _category(caption: String) -> String:
	if "Intercâmbio" in caption: return "Intercâmbio"
	if caption.begins_with("Salvar") or caption.begins_with("Abrir") or "rascunho" in caption.to_lower() or caption.begins_with("Recuperar") or caption.begins_with("Publicar"): return "Arquivo"
	if "Desfazer" in caption or "Refazer" in caption or "Remover" in caption or "Aplicar" in caption: return "Editar"
	if "Compilar" in caption or "Testar" in caption or "teste" in caption or "Cancelar" in caption or "prévia" in caption: return "Validar e testar"
	if "Enquadrar" in caption or "proposta" in caption.to_lower() or "Comparar" in caption: return "Visualizar"
	return "Criar"

func set_mode(value: String) -> Dictionary:
	if value not in ["ux","ax"]: return {"ok":false,"code":"presentation_mode_invalid"}
	active_mode = value
	var live: Array[WeakRef] = []
	for reference: WeakRef in hosts:
		var host: Variant = reference.get_ref()
		if is_instance_valid(host): live.append(reference); host._apply_mode()
	hosts = live
	return {"ok":true}

func _apply_mode() -> void:
	var ax := active_mode == "ax"
	mode_choice.select(1 if ax else 0)
	guide.visible = not ax
	for category: String in menus: menus[category].visible = not ax and menus[category].get_popup().item_count > 0
	for id: String in actions:
		var action: Dictionary = actions[id]
		action.control.visible = ax and action.visible
	if overlay != null: overlay.visible = ax
	if section_choice != null:
		section_choice.visible = not ax
		for label: String in sections:
			for control: Control in sections[label]: control.visible = ax or section_choice.get_item_text(section_choice.selected) == label

func _update_menu(category: String) -> void:
	var popup: PopupMenu = menus[category].get_popup()
	for index: int in popup.item_count:
		var button: Button = actions[popup.get_item_metadata(index)].control
		popup.set_item_disabled(index,button.disabled or not button.get_parent().is_visible_in_tree())

func _process(_delta: float) -> void:
	if active_mode != "ax": return
	for id: String in overlay_buttons: overlay_buttons[id].disabled = actions[id].control.disabled

func _invoke(id: String, agent: bool) -> Dictionary:
	if not actions.has(id): return {"ok":false,"code":"action_missing"}
	if agent and active_mode != "ax": return {"ok":false,"code":"ax_mode_required"}
	var action: Dictionary = actions[id]
	if action.control.disabled: return {"ok":false,"code":"action_disabled"}
	if action.ax_only and not agent: return {"ok":false,"code":"ax_mode_required"}
	action.control.pressed.emit()
	return {"ok":true,"action_id":id}

func ax_invoke(id: String, parameters: Dictionary = {}) -> Dictionary:
	if screen.has_method("authoring_commands") and screen.has_method("ax_command"):
		for command: Dictionary in screen.authoring_commands():
			if command.id != id: continue
			if active_mode != "ax": return {"ok":false,"code":"ax_mode_required"}
			return screen.ax_command(id,parameters)
	if not parameters.is_empty(): return {"ok":false,"code":"arguments_invalid"}
	return _invoke(id,true)

func ax_snapshot() -> Dictionary:
	var records: Array = []
	for id: String in actions:
		var action: Dictionary = actions[id]
		records.append({"id":id,"label":action.text,"enabled":not action.control.disabled,"test_only":action.ax_only})
	return {"mode":active_mode,"screen":screen_id,"source":get_source.call().duplicate(true),"actions":records,"commands":screen.authoring_commands() if screen.has_method("authoring_commands") else []}
