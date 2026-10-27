@tool
extends VBoxContainer
const Catalog = preload("res://scripts/map_authoring/objects/prop_catalog.gd")
const Ops = preload("res://scripts/map_authoring/objects/object_operations.gd")
const Metadata = preload("res://scripts/map_authoring/objects/object_schema.gd")
const Canvas = preload("res://scripts/map_authoring/terrain/terrain_canvas.gd")
const Schema = preload("res://scripts/map_authoring/document/source_schema.gd")
const Preferences = preload("res://scripts/map_authoring/library/editor_preferences.gd")
const Library = preload("res://scripts/map_authoring/library/library_model.gd")
const CATEGORIES := {"trees":"Árvores","rocks":"Rochas","vegetation":"Vegetação","structures":"Estruturas"}
var session: RefCounted
var canvas: Control
var palette: ItemList
var objects: ItemList
var search: LineEdit
var category_filter: OptionButton
var favorites_only: CheckButton
var favorite_button: Button
var surfaces: OptionButton
var mode: OptionButton
var x: SpinBox
var z: SpinBox
var snap: SpinBox
var radius: SpinBox
var quantity: SpinBox
var spacing: SpinBox
var seed_text: LineEdit
var group_name: LineEdit
var status: Label
var details: Label
var selected_ids: Array[String] = []
var selected_definition := "woodland_shrub"
var pending: Dictionary = {}
var _confirmation: ConfirmationDialog
var _refreshing := false
var _preferences_seen := ""
var prepare_inspection: Callable
var prepare_button: Button

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	size_flags_horizontal = SIZE_EXPAND_FILL; size_flags_vertical = SIZE_EXPAND_FILL
	var title := Label.new(); title.text = "Objetos e vegetação"; title.add_theme_font_size_override("font_size",24); add_child(title)
	var hint := Label.new(); hint.text = "Escolha um objeto e um piso. Coloque, selecione ou mova na prévia; cada alteração pode ser desfeita."; add_child(hint)
	var toolbar := HBoxContainer.new(); add_child(toolbar)
	mode = OptionButton.new()
	for text: String in ["Selecionar","Colocar","Mover selecionado"]: mode.add_item(text)
	toolbar.add_child(mode); mode.item_selected.connect(func(_i: int) -> void: invalidate_preview(); _sync_tool())
	surfaces = OptionButton.new(); toolbar.add_child(surfaces); surfaces.item_selected.connect(func(_i: int) -> void: invalidate_preview(); _sync_tool())
	button(toolbar,"Desfazer",func() -> void: session.undo())
	button(toolbar,"Refazer",func() -> void: session.redo())
	button(toolbar,"Enquadrar",func() -> void: canvas.fit())
	prepare_button = Button.new(); prepare_button.text = "Compilar peça"; prepare_button.disabled = not prepare_inspection.is_valid(); prepare_button.set_meta("authoring_keep_visible",true)
	prepare_button.tooltip_text = "Prepara a inspeção de corpo e linha de visão com o compilador compartilhado da peça."
	prepare_button.pressed.connect(func() -> void:
		if prepare_inspection.is_valid(): status.text = "Preparando a inspeção da peça…"; prepare_inspection.call())
	toolbar.add_child(prepare_button)
	var split := HSplitContainer.new(); split.size_flags_vertical = SIZE_EXPAND_FILL; add_child(split)
	var left := VBoxContainer.new(); left.custom_minimum_size.x = 210; split.add_child(left)
	search = LineEdit.new(); search.placeholder_text = "Buscar objeto ou categoria"; left.add_child(search); search.text_changed.connect(func(_s: String) -> void: refresh_palette())
	category_filter = OptionButton.new(); category_filter.add_item("Todas as categorias"); category_filter.set_item_metadata(0,"")
	for id: String in CATEGORIES: category_filter.add_item(CATEGORIES[id]); category_filter.set_item_metadata(category_filter.item_count-1,id)
	left.add_child(category_filter); category_filter.item_selected.connect(func(_i: int) -> void: refresh_palette())
	favorites_only = CheckButton.new(); favorites_only.text = "Somente favoritos"; left.add_child(favorites_only); favorites_only.toggled.connect(func(_on: bool) -> void: refresh_palette())
	favorite_button = button(left,"Favoritar selecionado",toggle_favorite)
	favorite_button.set_meta("authoring_keep_visible",true)
	palette = ItemList.new(); palette.size_flags_vertical = SIZE_EXPAND_FILL; palette.fixed_icon_size = Vector2i(72,72); palette.icon_mode = ItemList.ICON_MODE_TOP; palette.max_columns = 2; left.add_child(palette)
	palette.item_selected.connect(func(i: int) -> void:
		invalidate_preview(); selected_definition = palette.get_item_metadata(i); mode.select(1); _sync_tool(); _describe_definition(); _favorite_label())
	var middle := VBoxContainer.new(); middle.size_flags_horizontal = SIZE_EXPAND_FILL; split.add_child(middle)
	canvas = Canvas.new(); canvas.size_flags_vertical = SIZE_EXPAND_FILL; middle.add_child(canvas)
	canvas.object_pressed.connect(_canvas_pressed)
	status = Label.new(); status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; middle.add_child(status)
	var right_scroll := ScrollContainer.new(); right_scroll.custom_minimum_size.x = 280; split.add_child(right_scroll)
	var right := VBoxContainer.new(); right.custom_minimum_size.x = 260; right_scroll.add_child(right)
	var list_title := Label.new(); list_title.text = "Objetos da peça · Ctrl para múltiplos"; right.add_child(list_title)
	objects = ItemList.new(); objects.select_mode = ItemList.SELECT_MULTI; objects.custom_minimum_size.y = 140; right.add_child(objects)
	objects.multi_selected.connect(func(_i: int,_selected: bool) -> void:
		selected_ids.clear()
		for i: int in objects.get_selected_items(): selected_ids.append(objects.get_item_metadata(i))
		_inspect_selection())
	details = Label.new(); details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; right.add_child(details)
	x = number(right,"Posição X",-8192,8192,200); z = number(right,"Posição Z",-8192,8192,200)
	snap = number(right,"Snap ·0 desliga",0,1024,8)
	button(right,"Colocar nas coordenadas",place_at_fields)
	button(right,"Mover seleção",move_at_fields)
	button(right,"Girar90°",func() -> void: apply_operation("rotate",{"ids":selected_ids,"degrees":90}))
	button(right,"Duplicar seleção",func() -> void: apply_operation("duplicate",{"ids":selected_ids,"delta_xz":[24,0]}))
	button(right,"Remover seleção",func() -> void: apply_operation("remove",{"ids":selected_ids}))
	group_name = LineEdit.new(); group_name.text = "Conjunto"; group_name.placeholder_text = "Nome do grupo"; right.add_child(group_name)
	button(right,"Agrupar seleção",func() -> void: apply_operation("group",{"ids":selected_ids,"group_id":Ops.new_id(source(),"group",{"ids":selected_ids}),"name":group_name.text}))
	button(right,"Desagrupar",func() -> void: apply_operation("ungroup",{"ids":selected_ids}))
	button(right,"Selecionar grupo",select_group)
	button(right,"Travar / destravar grupo",func() -> void: toggle_group("locked"))
	button(right,"Ocultar / mostrar grupo",func() -> void: toggle_group("hidden"))
	button(right,"Travar / destravar",func() -> void:
		if not selected_ids.is_empty(): apply_operation("lock",{"ids":selected_ids,"value":not Metadata.state(source(),selected_ids[0]).locked}))
	var visibility_button := button(right,"Ocultar / mostrar na autoria",func() -> void:
		if not selected_ids.is_empty(): apply_operation("hide",{"ids":selected_ids,"value":not Metadata.state(source(),selected_ids[0]).hidden}))
	visibility_button.tooltip_text = "A ocultação é da autoria. O objeto e seu bloqueio permanecem visíveis no mapa publicado."
	var scatter_title := Label.new(); scatter_title.text = "Distribuição · prévia antes de aplicar"; right.add_child(scatter_title)
	radius = number(right,"Raio de distribuição",1,8192,120); quantity = number(right,"Quantidade nova",1,1024,12); spacing = number(right,"Distância adicional",0,8192,12)
	seed_text = LineEdit.new(); seed_text.text = "0"; seed_text.placeholder_text = "Seed inteira"; right.add_child(seed_text)
	button(right,"Preparar scatter",prepare_scatter)
	button(right,"Aplicar prévia…",func() -> void:
		if not pending.is_empty(): _confirmation.popup_centered())
	button(right,"Descartar prévia",discard_preview)
	_confirmation = ConfirmationDialog.new(); _confirmation.dialog_text = "Aplicar a distribuição exibida? Os objetos atuais serão preservados; a ação pode ser desfeita."; add_child(_confirmation)
	_confirmation.confirmed.connect(apply_preview)
	for field: SpinBox in [x,z,snap,radius,quantity,spacing]: field.value_changed.connect(func(_v: float) -> void: invalidate_preview())
	seed_text.text_changed.connect(func(_v: String) -> void: invalidate_preview())
	refresh_palette()
	preload("res://scripts/map_authoring/preview/viewport_tools.gd").mount(canvas,"objects")
	objects.item_activated.connect(func(index: int) -> void: canvas._viewport_tools.focus_entity("object/"+str(objects.get_item_metadata(index))))
	preload("res://addons/ragrpg_map_editor/presentation.gd").mount(self,"objects",source)

func bind(value: RefCounted) -> void:
	session = value; session.changed.connect(refresh); refresh(); canvas.fit()

func source() -> Dictionary:
	return session.document().to_data() if session != null and session.document() != null else {}

func accept_inspection(completed: Dictionary) -> void:
	if not completed.get("ok",false): status.text = "A inspeção não está pronta. Confira o diagnóstico da compilação da peça."; return
	if completed.get("input_hash","") != Schema.semantic_hash(source()): return
	canvas.package = completed.package.duplicate(true); canvas.queue_redraw()
	status.text = "Peça compilada. Inspeção de corpo e linha de visão disponível."

func refresh_palette() -> void:
	if palette == null: return
	palette.clear(); var catalog := Catalog.load_catalog()
	if not catalog.ok:
		if status != null: status.text = "Catálogo de objetos indisponível."
		return
	var prefs := Preferences.read()
	if not prefs.ok:
		if status != null: status.text = "As preferências da biblioteca precisam de recuperação; nenhum dado foi substituído."
		return
	var entries := _palette_entries(catalog)
	for entry: Dictionary in Library.query(entries,search.text,str(category_filter.get_item_metadata(category_filter.selected)),favorites_only.button_pressed,prefs.data.favorites):
		var definition: Dictionary = catalog.definitions[entry.definition_id]
		var starred: bool = entry.id in prefs.data.favorites
		var i := palette.add_item(("★ " if starred else "")+definition.name,load(definition.sprite_path) as Texture2D)
		palette.set_item_metadata(i,entry.definition_id); palette.set_item_tooltip(i,definition.name+" · "+CATEGORIES.get(definition.category,definition.category)+"\nOrigem: geração integrada · licença de conteúdo gerado para o projeto")
		if entry.definition_id == selected_definition: palette.select(i)
	_favorite_label()
	_preferences_seen = prefs.hash

func _palette_entries(catalog: Dictionary) -> Array:
	var entries: Array = []; var ids: Array = catalog.definitions.keys(); ids.sort()
	for id: String in ids:
		var d: Dictionary = catalog.definitions[id]
		entries.append({"id":"prop:"+id,"definition_id":id,"name":d.name,"category":d.category,"tags":d.biome_ids})
	return entries

func _favorite_label() -> void:
	var prefs := Preferences.read()
	if is_instance_valid(favorite_button): favorite_button.text = "Remover dos favoritos" if prefs.ok and "prop:"+selected_definition in prefs.data.favorites else "Favoritar selecionado"

func favorite(id: String, enabled: bool) -> Dictionary:
	if not Catalog.definition(id).ok: return {"ok":false,"code":"object_definition_missing"}
	var result := Preferences.transact({"operation":"favorite","id":"prop:"+id,"enabled":enabled})
	if result.ok: refresh_palette()
	elif status != null: status.text = "Não foi possível atualizar os favoritos (%s)."%result.code
	return result

func toggle_favorite() -> void:
	var prefs := Preferences.read()
	if prefs.ok: favorite(selected_definition,"prop:"+selected_definition not in prefs.data.favorites)

func authoring_commands() -> Array:
	return [{"id":"objects/library/query","parameters":{"query":"string?","category":"string?","favorites_only":"bool?"}},{"id":"objects/library/favorite","parameters":{"definition_id":"string","enabled":"bool"}},{"id":"objects/library/select","parameters":{"definition_id":"string"}}]

func ax_command(id: String, parameters: Dictionary) -> Dictionary:
	if id == "objects/library/query":
		for key: Variant in parameters:
			if key not in ["query","category","favorites_only"]: return {"ok":false,"code":"arguments_invalid"}
		if not parameters.get("query","") is String or not parameters.get("category","") is String or parameters.get("category","") not in [""]+CATEGORIES.keys() or not parameters.get("favorites_only",false) is bool: return {"ok":false,"code":"arguments_invalid"}
		var catalog := Catalog.load_catalog(); var prefs := Preferences.read()
		if not catalog.ok: return catalog
		if not prefs.ok: return prefs
		return {"ok":true,"entries":Library.query(_palette_entries(catalog),parameters.get("query",""),parameters.get("category",""),parameters.get("favorites_only",false),prefs.data.favorites),"preferences_hash":prefs.hash}
	if id == "objects/library/favorite":
		if not Preferences._keys(parameters,["definition_id","enabled"]) or not parameters.definition_id is String or not parameters.enabled is bool: return {"ok":false,"code":"arguments_invalid"}
		return favorite(parameters.definition_id,parameters.enabled)
	if id == "objects/library/select":
		if not Preferences._keys(parameters,["definition_id"]) or not parameters.definition_id is String: return {"ok":false,"code":"arguments_invalid"}
		var found := Catalog.definition(parameters.definition_id)
		if not found.ok: return found
		invalidate_preview(); selected_definition = parameters.definition_id; mode.select(1); _sync_tool(); refresh_palette(); _describe_definition()
		return {"ok":true,"definition_id":selected_definition}
	return {"ok":false,"code":"action_missing"}

func refresh() -> void:
	if session == null or _refreshing: return
	_refreshing = true; pending = {}
	var data := source(); var previous := surface_id(); surfaces.clear()
	for layer: Dictionary in data.layers:
		surfaces.add_item(layer.name); surfaces.set_item_metadata(surfaces.item_count-1,layer.layer_id)
	for special: Dictionary in data.special_surfaces:
		surfaces.add_item("Piso especial · "+special.surface_id); surfaces.set_item_metadata(surfaces.item_count-1,special.surface_id)
	for i: int in surfaces.item_count:
		if surfaces.get_item_metadata(i) == previous: surfaces.select(i)
	objects.clear(); var surviving: Array[String] = []
	var catalog := Catalog.load_catalog()
	for placement: Dictionary in data.placements:
		var state := Metadata.state(data,placement.placement_id)
		var display_name: String = catalog.definitions.get(placement.definition_id,{}).get("name","Objeto indisponível") if catalog.ok else "Objeto indisponível"
		var i := objects.add_item(("Travado · " if state.locked else "")+("Oculto · " if state.hidden else "")+display_name)
		objects.set_item_metadata(i,placement.placement_id)
		objects.set_item_tooltip(i,display_name+"\nID: "+placement.placement_id+"\nPiso: "+placement.surface_id)
		if placement.placement_id in selected_ids: objects.select(i,false); surviving.append(placement.placement_id)
	selected_ids = surviving
	var first_layer: String = data.layers[0].layer_id if not data.layers.is_empty() else ""
	canvas.set_source(data,first_layer); _sync_tool(); _inspect_selection()
	_refreshing = false

func surface_id() -> String:
	return str(surfaces.get_item_metadata(surfaces.selected)) if surfaces != null and surfaces.item_count > 0 else ""

func _sync_tool() -> void:
	canvas.object_edit_mode = ["select","place","move"][mode.selected]
	canvas.object_surface_id = surface_id()
	canvas.selected_objects = selected_ids.duplicate(); canvas.queue_redraw()

func _describe_definition() -> void:
	var found := Catalog.definition(selected_definition)
	if not found.ok: status.text = "A definição ou sua imagem está ausente."; return
	var d: Dictionary = found.definition
	details.text = "%s\n%s · revisão%d\nCorpo:%s · ataque/visão:%s\nInclinação máxima:%.0f°"%[d.name,CATEGORIES.get(d.category,d.category),d.revision,"bloqueia" if d.capabilities.body else "livre","bloqueia" if d.capabilities.attack_los else "livre",d.max_slope_degrees]

func _inspect_selection() -> void:
	canvas.selected_objects = selected_ids.duplicate(); canvas.queue_redraw()
	if selected_ids.is_empty(): _describe_definition(); return
	var center := Vector2.ZERO
	for id: String in selected_ids:
		var p := Ops._find(source().placements,"placement_id",id)
		center += Vector2(p.position_xyz[0],p.position_xyz[2])
		if selected_ids.size() == 1:
			for i: int in surfaces.item_count:
				if surfaces.get_item_metadata(i) == p.surface_id: surfaces.select(i); canvas.object_surface_id = p.surface_id; break
	center /= selected_ids.size(); x.value = center.x; z.value = center.y
	details.text = "%d objeto(s) selecionado(s).\nPosição refere-se ao centro da seleção."%selected_ids.size()

func _canvas_pressed(hit: Dictionary) -> void:
	if mode.selected == 0:
		selected_ids.clear()
		if hit.get("placement_id","") != "": selected_ids.append(hit.placement_id)
		refresh(); return
	if not hit.get("ok",false): status.text = "Escolha um ponto no piso selecionado."; return
	x.value = hit.position.x; z.value = hit.position.z
	if mode.selected == 1: place_at_fields()
	else: move_at_fields()

func place_at_fields() -> Dictionary:
	return apply_operation("place",{"definition_id":selected_definition,"surface_id":surface_id(),"position_xz":[x.value,z.value],"snap":snap.value})

func move_at_fields() -> Dictionary:
	if selected_ids.size() == 1: return apply_operation("move",{"ids":selected_ids,"surface_id":surface_id(),"position_xz":[x.value,z.value],"snap":snap.value})
	var center := Vector2.ZERO
	for id: String in selected_ids:
		var p := Ops._find(source().placements,"placement_id",id); center += Vector2(p.position_xyz[0],p.position_xyz[2])
	if selected_ids.is_empty(): return {"ok":false,"code":"object_selection_invalid"}
	center /= selected_ids.size()
	return apply_operation("translate",{"ids":selected_ids,"delta_xz":[x.value-center.x,z.value-center.y],"snap":snap.value})

func apply_operation(operation: String, params: Dictionary) -> Dictionary:
	var proposal := Ops.propose(source(),operation,params)
	if not proposal.ok:
		status.text = proposal.get("diagnostics",[{}])[0].get("message","Operação recusada.") if not proposal.get("diagnostics",[]).is_empty() else "Operação recusada: "+proposal.get("code","")
		return proposal
	if proposal.no_op: return proposal
	var applied: Dictionary = session.apply(proposal.data)
	status.text = "Alteração aplicada; use Desfazer para reverter." if applied.ok else "A alteração foi recusada."
	return applied

func prepare_scatter() -> Dictionary:
	var params := {"definition_id":selected_definition,"surface_id":surface_id(),"center_xz":[x.value,z.value],"radius":radius.value,"count":int(quantity.value),"spacing":spacing.value,"seed_text":seed_text.text,"snap":snap.value,"exclusions":[]}
	var proposal := Ops.propose(source(),"scatter",params)
	if not proposal.ok:
		status.text = "A distribuição não cabe: faltam%d objeto(s). Nenhum objeto foi aplicado."%proposal.get("deficit",int(quantity.value)); return proposal
	pending = {"proposal":proposal,"params":params,"base_hash":Schema.semantic_hash(source())}
	canvas.set_source(proposal.data,canvas.selected_layer); _sync_tool()
	status.text = "Prévia com%d novos objetos. Confira a distribuição antes de aplicar."%int(quantity.value)
	return proposal

func apply_preview() -> Dictionary:
	if pending.is_empty(): return {"ok":false,"code":"object_preview_missing"}
	if pending.base_hash != Schema.semantic_hash(source()): discard_preview(); return {"ok":false,"code":"stale_source"}
	var repeated := Ops.propose(source(),"scatter",pending.params)
	if not repeated.ok or repeated.output_hash != pending.proposal.output_hash: discard_preview(); return {"ok":false,"code":"stale_source"}
	return apply_proposal(repeated)

func apply_proposal(proposal: Dictionary) -> Dictionary:
	pending = {}; return session.apply(proposal.data)

func discard_preview() -> void:
	pending = {}; refresh(); status.text = "Prévia descartada; autoria preservada."

func invalidate_preview() -> void:
	if pending.is_empty() or _refreshing: return
	pending = {}; canvas.set_source(source(),canvas.selected_layer); _sync_tool()
	status.text = "Os parâmetros mudaram. Prepare outra prévia para conferir o resultado."

func select_group() -> void:
	if selected_ids.is_empty(): return
	var group_id: String = Metadata.state(source(),selected_ids[0]).group_id
	if group_id == "": status.text = "Escolha um objeto de um grupo."; return
	selected_ids.clear()
	for state: Dictionary in source().objects.states:
		if state.group_id == group_id: selected_ids.append(state.placement_id)
	refresh()

func toggle_group(field: String) -> Dictionary:
	if selected_ids.is_empty(): return {"ok":false,"code":"object_group_invalid"}
	var group_id: String = Metadata.state(source(),selected_ids[0]).group_id
	var group := Ops._find(source().get("objects",{}).get("groups",[]),"group_id",group_id)
	if group.is_empty(): status.text = "Escolha um objeto de um grupo."; return {"ok":false,"code":"object_group_invalid"}
	var params := {"group_id":group_id}; params[field] = not group[field]
	return apply_operation("group_state",params)

static func button(parent: Node, text: String, action: Callable) -> Button:
	var control := Button.new(); control.text = text; control.pressed.connect(action); parent.add_child(control); return control

static func number(parent: Node, text: String, low: float, high: float, initial: float) -> SpinBox:
	var row := HBoxContainer.new(); parent.add_child(row)
	var label := Label.new(); label.text = text; label.size_flags_horizontal = SIZE_EXPAND_FILL; row.add_child(label)
	var control := SpinBox.new(); control.min_value = low; control.max_value = high; control.value = initial; row.add_child(control); return control
