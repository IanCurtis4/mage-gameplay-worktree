extends SceneTree
## Operator-only setup through existing domain APIs, strictly inside a new review folder.
## P7-C3: also used for the E08 candidate folder (.tools/playtest_e08/e08_<hash>), run with
## the standard engine and --main-pack on the exact candidate PCK, APPDATA=<root>/profiles/<group>/appdata.
const GROUPS := {
	"melee": [["swordsman","Espadachim"],["defender","Defendente"],["berserker","Berserker"]],
	"magic": [["mage","Mago"],["elementalist","Elementalista"],["spiritualist","Espiritualista"],["geometer","Geômetra"]],
	"ranged": [["archer","Arqueiro"],["sentinel","Sentinela"],["hunter","Caçadora"]],
}
const ORIGINS := {"swordsman":"swordsman","defender":"swordsman","berserker":"swordsman","mage":"mage","elementalist":"mage","spiritualist":"mage","geometer":"mage","archer":"archer","sentinel":"archer","hunter":"archer"}
const EXTRA_PROPS: Array[StringName] = [&"shared_sword",&"shared_axe",&"shared_wand",&"shared_bow",&"shared_shield",&"elementalist_prism",&"spiritualist_prayer_beads"]
var _request := 0

func _initialize() -> void:
	_run.call_deferred()

func _id() -> String:
	_request += 1
	return "p4_review_%d" % _request

func _require(result: Dictionary,label: String) -> bool:
	if result.get("ok",false):return true
	push_error("Review profile setup failed: %s (%s)" % [label,result.get("error_code","unknown")])
	quit(1)
	return false

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size()!=2 or not GROUPS.has(args[0]):
		push_error("Expected review group and absolute candidate root")
		quit(1);return
	var group: String=args[0]
	var approved_root: String=String(args[1]).replace("\\","/").simplify_path().trim_suffix("/")
	var user_root: String=OS.get_user_data_dir().replace("\\","/").simplify_path()
	if not approved_root.is_absolute_path() or not (approved_root.contains("/.tools/playtest_e08/p4_") or approved_root.contains("/.tools/playtest_e08/e08_")) or not user_root.begins_with(approved_root+"/profiles/"+group+"/"):
		push_error("Refusing setup outside the explicit isolated E08 review profile")
		quit(1);return
	var store := ProfileStore.new("user://")
	var facade := ProfileFacade.new(store,ProfileRewardResolver.pilot_progression())
	if not _require(facade.open_profile(),"open isolated store"):return
	if not facade.current_profile().characters.is_empty():
		push_error("Review profile is not empty; existing progress was preserved")
		quit(1);return
	var catalog := store.catalog_copy()
	var created: Array[Dictionary]=[]
	for entry: Array in GROUPS[group]:
		var kind: String=entry[0]
		var origin := StringName(ORIGINS[kind])
		var result := facade.create_character(_id(),facade.current_profile().revision,"E08 "+String(entry[1]),origin)
		if not _require(result,"create "+kind):return
		var character_id: String=result.character_id
		result=PlaytestProfileAdmin.grant(facade,_id(),facade.current_profile().revision,character_id,&"max_levels")
		if not _require(result,"levels "+kind):return
		if kind!=String(origin):
			var evolution := &"mg_ar" if kind=="geometer" else StringName(kind)
			if not _require(facade.change_evolution(_id(),facade.current_profile().revision,character_id,evolution),"evolve "+kind):return
			if not _require(PlaytestProfileAdmin.grant(facade,_id(),facade.current_profile().revision,character_id,&"max_levels"),"evolved levels"):return
		if not _require(PlaytestProfileAdmin.grant(facade,_id(),facade.current_profile().revision,character_id,&"unlock_skills"),"legal skills"):return
		var character := facade.current_profile().character_by_id(character_id)
		var definitions: Array[StringName]=EquipmentArtCatalog.head_ids()
		definitions.append_array(EXTRA_PROPS)
		var own_head := StringName("class_set_%s_head" % ("mg_ar" if kind=="geometer" else kind))
		var selected_head := &""
		for definition_id: StringName in definitions:
			if not catalog.knows_equipment(definition_id):continue
			var metadata := catalog.equipment_metadata(definition_id)
			var slot := StringName(metadata.get("slot",&""))
			if not catalog.equipment_is_allowed(definition_id,slot,character.base_class_id,character.evolution_id):continue
			result=PlaytestProfileAdmin.grant(facade,_id(),facade.current_profile().revision,character_id,&"equipment",definition_id)
			if not _require(result,"grant "+String(definition_id)):return
			if definition_id==own_head:selected_head=StringName(result.equipment_instance_id)
		if not selected_head.is_empty():
			var intent := {"request_id":_id(),"profile_revision":facade.current_profile().revision,"kind":&"equip","slot":&"head","equipment_instance_id":selected_head}
			var proposal := facade.preview_inventory_change(character_id,intent)
			if not _require(proposal,"head preview"):return
			if not _require(facade.commit_inventory_change(character_id,proposal.intent),"head commit"):return
		var options := facade.available_build_options(character_id)
		if not _require(options,"build options"):return
		var skills: Array=options.active_skills.duplicate();skills.sort()
		var slots: Array[Variant]=ActionBarLayout.empty()
		for index: int in mini(slots.size(),skills.size()):slots[index]=StringName(skills[index])
		if not _require(facade.update_action_slots(_id(),facade.current_profile().revision,character_id,slots),"legal action bar"):return
		created.append({"kind":kind,"character_id":character_id,"active_slots":mini(slots.size(),skills.size())})
	if not _require(facade.select_character(_id(),facade.current_profile().revision,String(created[0].character_id)),"select first"):return
	var report := {"group":group,"user_directory":user_root,"characters":created,"profile_revision":facade.current_profile().revision,"personal_profile_touched":false}
	var file := FileAccess.open("user://p4_review_setup.json",FileAccess.WRITE)
	if file==null:push_error("Cannot write review receipt");quit(1);return
	file.store_string(JSON.stringify(report,"\t")+"\n");file.close()
	print("P4 isolated review profile: %s, %d characters" % [group,created.size()])
	quit(0)
