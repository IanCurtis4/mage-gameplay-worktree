@tool
extends VBoxContainer
## Checkpoint46 (F9-05, P3d): receipts of the open root in the variation tools of
## the terrain, map, encounter and patrol screens. Lists the receipts, replays one
## on its stored base (never writing the document), exports a passive replay
## bundle (receipt + base) and replays from an imported bundle. AX goes through
## the owning section: <screen>/synthesis/{receipts,replay,replay_bundle,replay_import}.
const Receipts = preload("res://scripts/map_authoring/synthesis/receipts.gd")
var kind := "piece"
var root_getter: Callable
var receipts_list: ItemList
var replay_status: Label
var dialog: FileDialog
var _dialog_action := ""

func setup(root_kind: String, getter: Callable) -> void:
	kind = root_kind; root_getter = getter; name = "SynthesisReceipts"
	var title := Label.new(); title.text = "Recibos das variações aplicadas"; add_child(title)
	receipts_list = ItemList.new(); receipts_list.custom_minimum_size.y = 72; add_child(receipts_list)
	var row := HFlowContainer.new(); add_child(row)
	for entry: Array in [["Reproduzir recibo",func() -> void: replay_selected()],["Exportar recibo e base…",func() -> void: _choose("export")],["Reproduzir de um pacote…",func() -> void: _choose("import")]]:
		var button := Button.new(); button.text = entry[0]; button.pressed.connect(entry[1]); button.set_meta("authoring_keep_visible",true); row.add_child(button)
	replay_status = Label.new(); replay_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; add_child(replay_status)
	dialog = FileDialog.new(); dialog.access = FileDialog.ACCESS_FILESYSTEM; dialog.filters = PackedStringArray(["*.json ; Pacote de replay"]); dialog.file_selected.connect(_file_selected); add_child(dialog)

func refresh() -> void:
	if receipts_list == null or not root_getter.is_valid(): return
	var previous := receipts_list.get_selected_items()
	receipts_list.clear()
	for entry: Dictionary in Receipts.list(root_getter.call()):
		var counts: Dictionary = entry.summary
		var text := "#%d · seed %s · %s · relevo %d · material %d · objetos +%d/−%d" % [entry.index+1,entry.seed_text,str(entry.selection),counts.terrain_samples,counts.material_samples,counts.objects_added,counts.objects_removed]
		if counts.slots_added > 0 or counts.slots_removed > 0: text += " · encontros %d" % counts.slots_added
		if not entry.base_stored: text += " · base fora deste projeto"
		receipts_list.add_item(text)
	if not previous.is_empty() and previous[0] < receipts_list.item_count: receipts_list.select(previous[0])
	elif receipts_list.item_count > 0: receipts_list.select(receipts_list.item_count-1)

func selected() -> int:
	var items := receipts_list.get_selected_items()
	return items[0] if not items.is_empty() else -1

static func describe(result: Dictionary) -> String:
	if not result.get("ok",false):
		var diagnostics: Array = result.get("diagnostics",[])
		return diagnostics[0].get("message","Não foi possível reproduzir.") if not diagnostics.is_empty() else "Não foi possível reproduzir: "+str(result.get("code",""))
	var text := "Reproduz exatamente esta variação (mesma base, pedido, dependências e algoritmo)." if result.reproduced else "Não reproduz: o mesmo pedido sobre a mesma base deu outro resultado."
	if result.dependencies_changed: text += " Catálogos, assets ou compiladores mudaram desde a variação."
	if not result.current_is_result: text += " Depois dela o documento mudou; o recibo não refaz essas edições."
	return text

func replay_selected(index: int = -1, base: Dictionary = {}) -> Dictionary:
	var chosen := index if index >= 0 else selected()
	var result := Receipts.replay(kind,root_getter.call(),chosen,Callable(),base)
	replay_status.text = describe(result)
	return result

func _choose(action: String) -> void:
	_dialog_action = action
	dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE if action == "export" else FileDialog.FILE_MODE_OPEN_FILE
	dialog.popup_centered_ratio(0.6)

func _file_selected(path: String) -> void:
	if _dialog_action == "export": export_bundle(selected(),path)
	else: import_bundle(path)

func export_bundle(index: int, path: String) -> Dictionary:
	var made := Receipts.bundle(kind,root_getter.call(),index)
	if not made.ok: replay_status.text = describe(made); return made
	var saved := Receipts.save_new(path,made.bundle)
	replay_status.text = "Pacote de replay salvo (recibo e base, sem executar nada)." if saved.ok else describe(saved)
	return saved

## Replays the receipt of the open root that the bundle names, on the bundle's
## base; the base is kept in the ledger as a passive copy.
func import_bundle(path: String) -> Dictionary:
	var decoded := Receipts.StrictJSON.new().decode(FileAccess.get_file_as_bytes(path)) if FileAccess.file_exists(path) else {"ok":false}
	var read := Receipts.read_bundle(decoded.get("value"),kind) if decoded.ok else Receipts.fail("replay_bundle_invalid")
	if not read.ok: replay_status.text = describe(read); return read
	var receipts: Array = root_getter.call().get(Receipts.KEY,[])
	var index := -1
	for i: int in receipts.size():
		if Receipts.Schema.semantic_hash(receipts[i]) == Receipts.Schema.semantic_hash(read.receipt): index = i
	if index < 0:
		var missing := Receipts.fail("replay_receipt_missing","O pacote é de uma variação que este documento não registra.")
		replay_status.text = describe(missing); return missing
	Receipts.store(kind,read.base)
	var result := replay_selected(index,read.base)
	refresh()
	return result

func commands(screen: String) -> Array:
	return [{"id":screen+"/synthesis/receipts","parameters":{}},{"id":screen+"/synthesis/replay","parameters":{"index":"integer"}},{"id":screen+"/synthesis/replay_bundle","parameters":{"index":"integer","path":"string (new .json)"}},{"id":screen+"/synthesis/replay_import","parameters":{"path":"string"}}]

func command(suffix: String, parameters: Dictionary) -> Dictionary:
	match suffix:
		"receipts":
			if not parameters.is_empty(): return {"ok":false,"code":"arguments_invalid"}
			return {"ok":true,"receipts":Receipts.list(root_getter.call())}
		"replay":
			if parameters.size() != 1 or not (parameters.get("index") is int or parameters.get("index") is float): return {"ok":false,"code":"arguments_invalid"}
			return replay_selected(int(parameters.index))
		"replay_bundle":
			if parameters.size() != 2 or not (parameters.get("index") is int or parameters.get("index") is float) or not parameters.get("path") is String: return {"ok":false,"code":"arguments_invalid"}
			return export_bundle(int(parameters.index),parameters.path)
		"replay_import":
			if parameters.size() != 1 or not parameters.get("path") is String: return {"ok":false,"code":"arguments_invalid"}
			return import_bundle(parameters.path)
	return {"ok":false,"code":"action_missing"}
