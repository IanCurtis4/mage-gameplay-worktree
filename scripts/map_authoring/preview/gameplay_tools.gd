@tool
extends HFlowContainer
## Human controls and AX provider over the same passive launcher API.
const Launcher = preload("res://scripts/map_authoring/preview/gameplay_launcher.gd")
const Protocol = preload("res://scripts/map_authoring/preview/gameplay_protocol.gd")
const Exchange = preload("res://scripts/map_authoring/exchange/exchange.gd")
const IO = preload("res://scripts/map_authoring/io/source_store.gd")
var screen_id := ""
var kind := ""
var source_getter: Callable
var package_getter: Callable
var hash_getter: Callable
var launcher := Launcher.new()
var class_choice: OptionButton
var message: Label
var _identity := ""
var _reference := ""
var _expected := ""
var _invalid_reference := false
var _elapsed := 0.0

static func mount(parent: Control, screen: String, package_kind: String, source: Callable, package: Callable, current_hash: Callable) -> Control:
	var panel := load("res://scripts/map_authoring/preview/gameplay_tools.gd").new() as Control
	panel.screen_id = screen; panel.kind = package_kind; panel.source_getter = source; panel.package_getter = package; panel.hash_getter = current_hash
	parent.add_child(panel); parent.move_child(panel,mini(2,parent.get_child_count()-1)); return panel

func _ready() -> void:
	name = "GameplayTools"; set_meta("authoring_command_provider",true)
	var title := Label.new(); title.text = "Teste no jogo"; add_child(title)
	class_choice = OptionButton.new(); add_child(class_choice)
	var names := {&"swordsman":"Espadachim",&"mage":"Mago",&"archer":"Arqueiro"}
	for id: StringName in IdentityIds.base_class_ids():
		class_choice.add_item(names[id]); class_choice.set_item_metadata(class_choice.item_count-1,String(id))
	# E10a C1.3: a registered base joins the list only once its module is ready.
	for id: StringName in IdentityIds.registered_base_ids():
		if ClassBaseRegistry.ready_for_play(id):
			class_choice.add_item(ClassBaseRegistry.display_name(id)); class_choice.set_item_metadata(class_choice.item_count-1,String(id))
	_button("Abrir jogo",func() -> void: launch())
	var resume_button := _button("Retomar teste",func() -> void: resume())
	resume_button.tooltip_text = "Retoma a última revisão testada; ela pode diferir do rascunho atual."
	_button("Suspender e fechar teste",func() -> void: stop())
	message = Label.new(); message.custom_minimum_size.x = 240; message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; add_child(message)
	_refresh_identity()

func _button(text: String, callback: Callable) -> Button:
	var button := Button.new(); button.text = text; button.set_meta("authoring_keep_visible",true); button.pressed.connect(callback); add_child(button); return button

func selected_class() -> String:
	return String(class_choice.get_item_metadata(class_choice.selected))

func set_class(id: String) -> Dictionary:
	for index: int in class_choice.item_count:
		if class_choice.get_item_metadata(index) == id: class_choice.select(index); return {"ok":true}
	return _result({"ok":false,"code":"arguments_invalid"})

func launch(class_id: String = "", headless: bool = false, hold_start: bool = false) -> Dictionary:
	_refresh_identity()
	if class_id.is_empty(): class_id = selected_class()
	if not IdentityIds.is_base_class(StringName(class_id)): return _result({"ok":false,"code":"arguments_invalid"})
	var package: Dictionary = package_getter.call()
	if package.is_empty(): return _result({"ok":false,"code":"compile_required"})
	var opened := launcher.launch(kind,package,String(hash_getter.call()),class_id,headless,hold_start)
	if opened.ok:
		var remembered := _remember()
		if not remembered.ok: opened["reference_warning"] = remembered.code
	return _result(opened)

func toggle() -> Dictionary:
	return stop() if launcher.running() else launch()

func resume(headless: bool = false, hold_start: bool = false) -> Dictionary:
	_refresh_identity()
	if launcher.window_path.is_empty(): return _result({"ok":false,"code":"preview_missing"})
	var result := launcher.request_action({"kind":"resume"}) if launcher.running() else launcher.resume_window("",headless,hold_start)
	if result.ok: _remember()
	return _result(result)

func stop() -> Dictionary:
	_refresh_identity()
	if launcher.window_path.is_empty(): return _result({"ok":false,"code":"preview_missing"})
	return _result(launcher.stop())

func inspect() -> Dictionary:
	_refresh_identity()
	if launcher.window_path.is_empty(): return {"ok":true,"state":{"state":"none"}}
	return launcher.state()

func _process(delta: float) -> void:
	_elapsed += delta
	if _elapsed < 0.5: return
	_elapsed = 0.0; _refresh_identity()
	if launcher.window_path.is_empty(): return
	var current := launcher.state()
	if not current.ok: return
	var label: String = {"starting":"Preparando…","ready":"Preparando personagem…","active":"Jogando","suspended":"Suspenso","closed":"Encerrado","completed":"Concluído","error":"Teste recusado","held":"Pronto · clique em Iniciar teste na janela"}.get(current.state.state,current.state.state)
	message.text = label+" · revisão "+String(current.state.candidate_hash).substr(0,10)

func _refresh_identity() -> void:
	if not source_getter.is_valid(): return
	var source: Dictionary = source_getter.call()
	var id: String = String(source.get("document_id",""))
	if id == _identity: return
	_identity = id; _reference = ""; _expected = ""; _invalid_reference = false
	launcher = Launcher.new()
	if id.is_empty(): return
	var key := ExpeditionCanonical.digest({"kind":kind,"document_id":id})
	_reference = Launcher.normalized(Launcher.ROOTS[0]).path_join("references").path_join(key+".json")
	_expected = IO.disk_hash(_reference)
	if _expected.is_empty(): return
	var read := Protocol.read_json(_reference,4096)
	if not read.ok or read.data.size() != 4 or not read.data.has_all(["version","kind","document_id","window_path"]) or read.data.version != 1 or read.data.kind != kind or read.data.document_id != id or not read.data.window_path is String:
		_invalid_reference = true; return
	var header := Launcher.window_header(read.data.window_path)
	if not header.ok: _invalid_reference = true; return
	launcher.window_path = header.path

func _remember() -> Dictionary:
	if _invalid_reference: return {"ok":false,"code":"reference_invalid_preserved"}
	if _reference.is_empty(): return {"ok":false,"code":"reference_missing"}
	var directory := _reference.get_base_dir()
	if DirAccess.make_dir_recursive_absolute(directory) != OK: return {"ok":false,"code":"reference_io"}
	if not FileAccess.file_exists(_reference) and DirAccess.get_files_at(directory).size() >= 64: return {"ok":false,"code":"reference_limit"}
	var data := {"version":1,"kind":kind,"document_id":_identity,"window_path":launcher.window_path}
	var saved := Exchange.save_json(_reference,data,_expected)
	if saved.ok: _expected = IO.disk_hash(_reference)
	return saved

func _result(value: Dictionary) -> Dictionary:
	if message == null: return value
	if value.ok:
		message.text = "Pedido enviado ao teste." if value.get("pending",false) else "Teste aberto ou atualizado."
		if value.has("reference_warning"): message.text += " O atalho anterior foi preservado."
	else:
		message.text = {"compile_required":"Compile antes de abrir o jogo.","candidate_stale":"O rascunho mudou; compile novamente.","preview_missing":"Ainda não há teste salvo para este documento.","preview_busy":"O teste já está aberto.","arguments_invalid":"Revise os parâmetros do teste."}.get(value.get("code",""),value.get("message","O teste não pôde ser aberto: "+String(value.get("code","falha"))))
	return value

func authoring_commands() -> Array[Dictionary]:
	var prefix := screen_id+"/gameplay/"
	return [{"id":prefix+"launch","parameters":{"class_id":"base class?","headless":"boolean?","hold_start":"boolean?"}},{"id":prefix+"resume","parameters":{"headless":"boolean?","hold_start":"boolean?"}},{"id":prefix+"stop","parameters":{}},{"id":prefix+"inspect","parameters":{}},{"id":prefix+"select_class","parameters":{"class_id":"base class"}},{"id":prefix+"action","parameters":{"action":"closed gameplay action","session_id":"token?","request_id":"token?"}},{"id":prefix+"reply","parameters":{"request_id":"token","session_id":"token?","fingerprint":"hash?"}}]

func ax_command(id: String, args: Dictionary = {}) -> Dictionary:
	var prefix := screen_id+"/gameplay/"
	if not id.begins_with(prefix): return {"ok":false,"code":"action_missing"}
	var action := id.trim_prefix(prefix)
	if action == "launch":
		if not args.keys().all(func(key: Variant) -> bool: return key in ["class_id","headless","hold_start"]) or not args.get("class_id","") is String or not args.get("headless",false) is bool or not args.get("hold_start",false) is bool: return {"ok":false,"code":"arguments_invalid"}
		return launch(args.get("class_id",""),args.get("headless",false),args.get("hold_start",false))
	if action == "resume":
		if not args.keys().all(func(key: Variant) -> bool: return key in ["headless","hold_start"]) or not args.get("headless",false) is bool or not args.get("hold_start",false) is bool: return {"ok":false,"code":"arguments_invalid"}
		return resume(args.get("headless",false),args.get("hold_start",false))
	if action in ["stop","inspect"]:
		if not args.is_empty(): return {"ok":false,"code":"arguments_invalid"}
		return stop() if action == "stop" else inspect()
	if action == "select_class":
		if args.size() != 1 or not args.get("class_id") is String: return {"ok":false,"code":"arguments_invalid"}
		return set_class(args.class_id)
	if action == "action":
		if not args.keys().all(func(key: Variant) -> bool: return key in ["action","session_id","request_id"]) or not args.get("action") is Dictionary or not args.get("session_id","") is String or not args.get("request_id","") is String: return {"ok":false,"code":"arguments_invalid"}
		return launcher.request_action(args.action,args.get("session_id",""),args.get("request_id",""))
	if action == "reply":
		if not args.keys().all(func(key: Variant) -> bool: return key in ["request_id","session_id","fingerprint"]) or not args.get("request_id") is String or not args.get("session_id","") is String or not args.get("fingerprint","") is String: return {"ok":false,"code":"arguments_invalid"}
		return launcher.poll_reply(args.request_id,args.get("session_id",""),args.get("fingerprint",""))
	return {"ok":false,"code":"action_missing"}
