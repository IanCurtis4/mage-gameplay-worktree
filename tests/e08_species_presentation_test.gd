extends SceneTree
## E08 P5 A1: immutable species presentation catalog, fallbacks, tint policy,
## embedded weapon, species switch and cold rebuild/restore by mob_base_id.
const D = preload("res://tests/fixtures/e08_directional/fixture.gd")
const VISUAL = preload("res://scripts/presentation/e08_pilot_visual.gd")
const SPECIES = preload("res://scripts/presentation/species_presentation_catalog.gd")
const FIXTURE := "res://tests/fixtures/e08_species/presentation.json"
const ABSENT := "res://tests/fixtures/e08_species/absent/presentation.json"
const ARCHER_UNARMED := "res://tests/fixtures/e08_directional/npc_archer_unarmed/presentation.json"
const WARDEN_STAGE := "res://assets/art/e08_enemies/directional/beast_master/presentation.json"
const MAGE_KIND := "res://tests/fixtures/e08_equipment_art/presentation.json"
const FOREST: Array[StringName] = [&"forest_ancient_warden",&"forest_boar",&"forest_canopy_archer",&"forest_stalker",&"forest_wolf"]
const VISUAL_IDS := {&"forest_wolf":&"e08_forest_wolf",&"forest_boar":&"e08_forest_boar",&"forest_stalker":&"e08_forest_stalker",&"forest_canopy_archer":&"e08_forest_canopy_archer",&"forest_ancient_warden":&"e08_forest_warden"}
# Exact palette of the pre-catalog E08PilotVisual.forest_tint (generic bodies).
const LEGACY_TINTS := {&"forest_stalker":Color(0.58, 0.70, 0.59),&"forest_canopy_archer":Color(0.77, 0.91, 0.73),&"forest_ancient_warden":Color(0.69, 0.85, 0.66)}
const GENERIC := [&"forest_stalker",&"forest_canopy_archer",&"forest_ancient_warden"]
var checks := 0
var failures := 0
var host: RunController
var catalog: MobCatalog

func _initialize() -> void: run.call_deferred()
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures+=1;push_error(label)

func spawn(id: StringName) -> MobOccurrence:
	var definition := catalog.get_definition(id)
	var occurrence := MobOccurrence.new();occurrence.occurrence_id="species_"+String(id)
	occurrence.mob_base_id=id;occurrence.category_id=definition.base_category
	occurrence.origin_id=definition.origin_levels.keys()[0] if not definition.origin_levels.is_empty() else &"demo_arena"
	return occurrence

func actor_for(id: StringName) -> EnemyActor:
	var actor := EnemyActor.new()
	check(actor.configure_occurrence(spawn(id),catalog,host.navigation,host.player).ok,"actual occurrence configures "+String(id))
	return actor

func override(id: StringName,path: String) -> void:
	VISUAL.set_manifest_override_for_tests(VISUAL_IDS[id],path)

func generic_path(id: StringName) -> String:
	var kind := catalog.get_definition(id).animation_kind
	return "res://assets/art/animations/directional/%s/%s.png" % [kind,"npc_body" if kind==&"archer" else "body"]

func run() -> void:
	RunController.selected_class_id=&"mage"
	host=RunController.new();root.add_child(host);host.set_process(false);host.player.set_process(false)
	for enemy: CombatActor in host.enemies:enemy.set_process(false)
	host.encounter_active=false
	catalog=BuildContentLoader.pilot().mob_catalog()
	catalog_contract()
	wolf_and_boar()
	generic_species()
	valid_units()
	real_units()
	invalid_units()
	species_switch()
	cold_rebuild()
	for id: StringName in FOREST:override(id,"")
	host.free();await process_frame
	print("E08 species presentation: %d checks, %d failures" % [checks,failures]);quit(1 if failures else 0)

func catalog_contract() -> void:
	check(SPECIES.ENTRIES.is_read_only(),"catalog constant is read-only")
	check(SPECIES.ids()==FOREST,"exactly the five forest species")
	var ids := SPECIES.ids();ids.append(&"forest_fake");ids.clear()
	check(SPECIES.ids()==FOREST and not SPECIES.has(&"forest_fake"),"mutating returned ids cannot alter catalog")
	var copy := SPECIES.entry(&"forest_canopy_archer")
	copy["visual_id"]=&"hacked";copy["embedded_weapon"]=false;copy["fallback_tint"]=Color.RED;copy["extra"]=1
	var fresh := SPECIES.entry(&"forest_canopy_archer")
	check(fresh["visual_id"]==&"e08_forest_canopy_archer" and fresh["embedded_weapon"]==true and fresh["fallback_tint"]==LEGACY_TINTS[&"forest_canopy_archer"] and not fresh.has("extra"),"mutating returned entry cannot alter catalog")
	check(SPECIES.entry(&"absent").is_empty() and SPECIES.visual_id(&"absent")==&"" and SPECIES.legacy_atlas(&"absent")==null and SPECIES.fallback_tint(&"absent")==Color.WHITE and not SPECIES.embedded_weapon(&"absent"),"absent species has neutral answers")
	# Every catalog id is a real forest MobDefinition placed by the forest phase.
	var used: Dictionary = {}
	var phase: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/expedition/phases/forest_sanctuary.json"))
	check(phase is Dictionary and phase.get("maps") is Array,"forest phase registry readable")
	if phase is Dictionary:
		for map: Dictionary in phase.get("maps",[]):
			var population: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/map_authoring/%s.population.json" % map.package_id))
			check(population is Dictionary,"forest population readable "+String(map.package_id))
			if not population is Dictionary:continue
			for brush: Dictionary in population.get("brushes",[]):
				for species: Dictionary in brush.get("species",[]):used[StringName(species.species_id)]=true
	var used_ids: Array[StringName]=[];used_ids.assign(used.keys());used_ids.sort_custom(func(a: StringName,b: StringName) -> bool: return String(a)<String(b))
	check(used_ids==FOREST,"forest phase population uses exactly the catalog species")
	for id: StringName in FOREST:
		var definition := catalog.get_definition(id)
		check(definition!=null and definition.id==id and ResourceLoader.exists("res://resources/forest_phase/mob/%s.tres" % id),"real forest MobDefinition "+String(id))
		check(VISUAL.has_species_presentation(id),"has species presentation "+String(id))
		check(SPECIES.visual_id(id)==VISUAL_IDS[id],"reserved visual id "+String(id))
		check(SPECIES.embedded_weapon(id)==(id==&"forest_canopy_archer"),"embedded weapon only canopy archer "+String(id))
	for id: StringName in [&"forest_wolf",&"forest_boar"]:
		var legacy := SPECIES.legacy_atlas(id)
		check(legacy!=null and legacy.resource_path=="res://assets/art/animations/%s.png" % VISUAL_IDS[id] and SPECIES.fallback_tint(id)==Color.WHITE,"own complete V1 and white palette "+String(id))
	for id: StringName in GENERIC:
		check(SPECIES.legacy_atlas(id)==null and SPECIES.fallback_tint(id)==LEGACY_TINTS[id],"generic fallback keeps legacy palette "+String(id))
	for id: StringName in [&"demo_archer",&"demo_chaser",&"test_gel",&"test_beast_master",&"test_animal_companion",&"pilot_echo_species",&"",&"forest_fake"]:
		check(not VISUAL.has_species_presentation(id),"no species presentation "+String(id))

func wolf_and_boar() -> void:
	for id: StringName in [&"forest_wolf",&"forest_boar"]:
		var expected := DirectionalAnimationSet.default_path(VISUAL_IDS[id]).get_base_dir()+"/body.png"
		var actor := actor_for(id)
		check(actor.character_animation.atlas.resource_path==expected and actor.character_animation.render_descriptor().version==2,"specific V2 path unchanged "+String(id))
		check(actor.character_animation.equipment_visual.is_empty() and VISUAL.forest_tint(actor)==Color.WHITE,"unadorned and untinted "+String(id))
		var clock := actor.character_animation.state
		check(VISUAL.install_forest_atlas(actor) and actor.character_animation.atlas.resource_path==expected and actor.character_animation.state==clock,"reinstall idempotent keeps clock "+String(id))
		actor.free()
		var legacy := SPECIES.legacy_atlas(id)
		for path: String in [ABSENT,FIXTURE]:
			override(id,path)
			var fallback := actor_for(id)
			check(fallback.character_animation.atlas==legacy and fallback.character_animation.render_descriptor().version==1 and VISUAL.forest_tint(fallback)==Color.WHITE,"complete own V1 fallback "+String(id)+" "+path)
			fallback.free()
		override(id,"")

func generic_species() -> void:
	for id: StringName in GENERIC:
		var paths: Array[String]=[ABSENT]
		# Today the reserved default unit is absent: the real path must also be generic.
		if not FileAccess.file_exists(DirectionalAnimationSet.default_path(VISUAL_IDS[id])):paths.append("")
		else:print("NOTE: default species unit installed for "+String(id))
		for path: String in paths:
			override(id,path)
			var actor := actor_for(id)
			var reference := CharacterAnimation.new();reference.configure(catalog.get_definition(id).animation_kind)
			check(actor.character_animation.atlas.resource_path==generic_path(id) and actor.character_animation.atlas==reference.atlas,"missing unit keeps exact generic body "+String(id)+" "+path)
			check(actor.character_animation.equipment_visual.is_empty() and actor.character_animation.render_descriptor().equipment.is_empty(),"generic NPC unadorned "+String(id))
			check(VISUAL.forest_tint(actor)==LEGACY_TINTS[id] and not VISUAL.owns_species_body(actor.character_animation,id),"missing unit keeps exact tint "+String(id))
			var clock := actor.character_animation.state;var atlas := actor.character_animation.atlas
			check(VISUAL.install_forest_atlas(actor) and actor.character_animation.state==clock and actor.character_animation.atlas==atlas,"missing unit install is a no-op "+String(id))
			actor.free()
		override(id,"")

func valid_units() -> void:
	check(DirectionalAnimationSet.load_manifest(FIXTURE).ok,"explicit species fixture is a valid V2 unit")
	# Stalker: fixture body, installed in place on an existing generic actor.
	override(&"forest_stalker",ABSENT)
	var stalker := actor_for(&"forest_stalker");var clock := stalker.character_animation.state
	override(&"forest_stalker",FIXTURE)
	check(VISUAL.install_forest_atlas(stalker) and stalker.character_animation.atlas.resource_path=="res://tests/fixtures/e08_species/body.png" and stalker.character_animation.state==clock,"valid unit installs in place keeping clock")
	check(stalker.character_animation.render_descriptor().version==2 and stalker.character_animation.equipment_visual.is_empty(),"valid unit complete V2 unadorned")
	check(VISUAL.owns_species_body(stalker.character_animation,&"forest_stalker") and VISUAL.forest_tint(stalker)==Color.WHITE,"own body never receives doubled tint")
	stalker.free()
	var configured := actor_for(&"forest_stalker")
	check(configured.character_animation.atlas.resource_path=="res://tests/fixtures/e08_species/body.png" and VISUAL.forest_tint(configured)==Color.WHITE,"configure_occurrence installs valid unit")
	configured.free()
	# Canopy archer: valid archer unit whose body would otherwise get a dynamic bow.
	override(&"forest_canopy_archer",ARCHER_UNARMED)
	var archer := actor_for(&"forest_canopy_archer")
	check(archer.character_animation.atlas.resource_path==ARCHER_UNARMED.get_base_dir()+"/npc_body.png","canopy archer installs own body")
	check(archer.character_animation.equipment_visual.is_empty() and archer.character_animation.render_descriptor().equipment.is_empty(),"embedded weapon gets no dynamic bow")
	archer.sync_npc_equipment_visual()
	check(archer.character_animation.equipment_visual.is_empty() and archer.character_animation.atlas.resource_path==ARCHER_UNARMED.get_base_dir()+"/npc_body.png","resync keeps embedded weapon without projection")
	check(VISUAL.has_embedded_weapon_body(archer) and VISUAL.forest_tint(archer)==Color.WHITE,"embedded own body untinted")
	# Control: the same body outside the catalog unit keeps the exact-path rule (dynamic bow).
	override(&"forest_canopy_archer","")
	archer.sync_npc_equipment_visual()
	check(archer.character_animation.equipment_visual.get("main_hand",&"")==&"bow" and not VISUAL.has_embedded_weapon_body(archer),"non-catalog homonymous body keeps dynamic bow")
	archer.free()
	# Warden: valid beast_master unit.
	override(&"forest_ancient_warden",WARDEN_STAGE)
	var warden := actor_for(&"forest_ancient_warden")
	check(warden.character_animation.atlas.resource_path==WARDEN_STAGE.get_base_dir()+"/body.png" and warden.character_animation.equipment_visual.is_empty() and VISUAL.forest_tint(warden)==Color.WHITE,"warden installs own valid unit untinted")
	warden.free()
	for id: StringName in GENERIC:override(id,"")

func real_units() -> void:
	# B1: the REAL default manifests (no overrides) install each species' own V2 body.
	const KINDS := {&"forest_stalker":&"warrior",&"forest_canopy_archer":&"archer",&"forest_ancient_warden":&"beast_master"}
	for id: StringName in GENERIC:
		override(id,"")
		var path := DirectionalAnimationSet.default_path(VISUAL_IDS[id])
		var loaded := DirectionalAnimationSet.load_manifest(path)
		check(FileAccess.file_exists(path) and loaded.ok,"real default unit validates "+String(id)+" "+str(loaded.get("detail","")))
		if not loaded.ok:continue
		var bundle: DirectionalAnimationSet=loaded.bundle
		check(bundle.actor_kind()==KINDS[id] and bundle.actor_kind()==catalog.get_definition(id).animation_kind,"real unit kind matches the MobDefinition "+String(id))
		check(bundle.body(false).get_size()==Vector2(256,1024) and bundle.body(false).resource_path==path.get_base_dir()+"/body.png","real unit body 256x1024 inside its directory "+String(id))
		check(bundle.has_bare_head()==false and (bundle.body(true)!=bundle.body(false))==(id==&"forest_canopy_archer"),"weaponless only for the archer unit "+String(id))
		var grounded := true;var offsets := bundle.ground_offsets()
		for index: int in 64:
			var frame := bundle.frame(index)
			grounded=grounded and not frame.is_empty() and int(frame.ground_y)==57 and is_equal_approx(offsets[index],1.0)
		check(offsets.size()==64 and grounded,"real unit 64 poses (4 views x 16) share ground 57 "+String(id))
		var actor := actor_for(id)
		var animation := actor.character_animation
		check(animation.atlas.resource_path==path.get_base_dir()+"/body.png" and animation.render_descriptor().version==2 and animation.actor_kind==KINDS[id],"configure_occurrence installs own V2 body "+String(id))
		check(VISUAL.owns_species_body(animation,id) and VISUAL.forest_tint(actor)==Color.WHITE,"own body is white, not doubly tinted "+String(id))
		check(animation.equipment_visual.is_empty() and animation.render_descriptor().equipment.is_empty(),"real unit has no projected equipment "+String(id))
		actor.sync_npc_equipment_visual()
		check(animation.equipment_visual.is_empty() and animation.atlas.resource_path==path.get_base_dir()+"/body.png","resync keeps own body, no projection "+String(id))
		check(VISUAL.has_embedded_weapon_body(actor)==(id==&"forest_canopy_archer"),"embedded weapon policy "+String(id))
		var clock := animation.state
		check(VISUAL.install_forest_atlas(actor) and animation.state==clock and animation.atlas.resource_path==path.get_base_dir()+"/body.png","reinstall idempotent "+String(id))
		var bitmap: Image=animation.atlas.get_image()
		var drawn := true
		for direction: int in 4:
			for pose: int in 16:
				animation.state=D.state(direction,pose)
				var desc := animation.render_descriptor()
				var bounds := bitmap.get_region(Rect2i(desc.region)).get_used_rect()
				drawn=drawn and desc.version==2 and desc.frame==direction*16+pose and bounds.has_area() and bounds.size.x<=58 and bounds.size.y<=56 and desc.equipment.is_empty()
		check(drawn,"real unit 64 rendered poses non-empty within 58x56 "+String(id))
		actor.free()
	# Archer unit: weaponless carries real hand pixels (loader archer-kind rule) yet NPCs never project.
	var archer_unit := DirectionalAnimationSet.load_manifest(DirectionalAnimationSet.default_path(&"e08_forest_canopy_archer"))
	check(archer_unit.ok and archer_unit.bundle.body(true).resource_path.ends_with("/weaponless.png"),"archer unit ships weaponless in its own file")

func invalid_units() -> void:
	var cases := [[&"forest_ancient_warden",FIXTURE,"kind mismatch"],[&"forest_canopy_archer",MAGE_KIND,"kind mismatch"],[&"forest_stalker",FIXTURE,"forced invalid"]]
	var cached: Variant=DirectionalAnimationSet._manifests.get(FIXTURE)
	for raw: Array in cases:
		var id: StringName=raw[0];var path: String=raw[1]
		check(FileAccess.file_exists(path),"invalid case manifest exists "+String(id))
		if raw[2]=="forced invalid":DirectionalAnimationSet._manifests[FIXTURE]={"ok":false,"error_code":&"invalid_directional_presentation","detail":"forced negative fixture"}
		override(id,path)
		var actor := actor_for(id)
		check(actor.character_animation.atlas.resource_path==generic_path(id) and actor.character_animation.equipment_visual.is_empty(),"invalid unit keeps complete generic body "+String(id)+" "+String(raw[2]))
		check(VISUAL.forest_tint(actor)==LEGACY_TINTS[id] and not VISUAL.owns_species_body(actor.character_animation,id),"invalid unit keeps generic tint "+String(id))
		actor.free();override(id,"")
		if raw[2]=="forced invalid":
			if cached==null:DirectionalAnimationSet._manifests.erase(FIXTURE)
			else:DirectionalAnimationSet._manifests[FIXTURE]=cached
	check(DirectionalAnimationSet.load_manifest(FIXTURE).ok,"forced negative fixture restored")

func species_switch() -> void:
	override(&"forest_canopy_archer",ARCHER_UNARMED);override(&"forest_stalker",ABSENT)
	var actor := actor_for(&"forest_canopy_archer")
	check(VISUAL.has_embedded_weapon_body(actor),"switch starts from embedded own body")
	check(actor.configure_occurrence(spawn(&"forest_stalker"),catalog,host.navigation,host.player).ok,"switch to stalker")
	check(actor.character_animation.atlas.resource_path==generic_path(&"forest_stalker") and actor.character_animation.equipment_visual.is_empty() and VISUAL.forest_tint(actor)==LEGACY_TINTS[&"forest_stalker"] and not VISUAL.has_embedded_weapon_body(actor),"switch clears previous species body, weapon policy and tint")
	check(actor.configure_occurrence(spawn(&"demo_archer"),catalog,host.navigation,host.player).ok and actor.character_animation.atlas.resource_path==generic_path(&"demo_archer") and actor.character_animation.equipment_visual.is_empty() and VISUAL.forest_tint(actor)==Color.WHITE,"switch to non-catalog archer keeps exact generic rule")
	check(actor.configure_occurrence(spawn(&"forest_wolf"),catalog,host.navigation,host.player).ok and actor.character_animation.atlas.resource_path.contains("/e08_forest_wolf/") and VISUAL.forest_tint(actor)==Color.WHITE,"switch to wolf installs specific body")
	# The real default unit now exists: the generic fallback is forced by an absent manifest.
	override(&"forest_canopy_archer",ABSENT)
	check(actor.configure_occurrence(spawn(&"forest_canopy_archer"),catalog,host.navigation,host.player).ok and actor.character_animation.atlas.resource_path==generic_path(&"forest_canopy_archer") and actor.character_animation.equipment_visual.is_empty() and VISUAL.forest_tint(actor)==LEGACY_TINTS[&"forest_canopy_archer"],"switch back to generic canopy archer")
	actor.free();override(&"forest_stalker","");override(&"forest_canopy_archer","")

func cold_rebuild() -> void:
	override(&"forest_stalker",FIXTURE);override(&"forest_canopy_archer",ARCHER_UNARMED)
	var samples: Array[EnemyActor]=[]
	for id: StringName in FOREST:
		var actor := actor_for(id);host.add_child(actor);host.enemies.append(actor);actor.set_process(false)
		actor.character_animation.state=D.state(2,5);samples.append(actor)
	var descriptors: Array[Dictionary]=[];var tints: Array[Color]=[]
	for actor: EnemyActor in samples:
		descriptors.append(actor.character_animation.render_descriptor());tints.append(VISUAL.forest_tint(actor))
		# Fresh object, same mob_base_id: rebuilt only from the occurrence.
		var born := EnemyActor.new()
		check(born.configure_occurrence(actor.occurrence.copy_occurrence(),catalog,host.navigation,host.player).ok,"cold rebuild configures "+String(actor.occurrence.mob_base_id))
		born.character_animation.state=D.state(2,5)
		check(born.character_animation.render_descriptor()==descriptors[-1] and VISUAL.forest_tint(born)==tints[-1] and born.character_animation.equipment_visual==actor.character_animation.equipment_visual,"cold rebuild by mob_base_id exact "+String(actor.occurrence.mob_base_id))
		born.free()
	var barrier := SnapshotTickBarrier.new();paused=true;check(barrier.acquire(host).ok,"species snapshot barrier")
	var captured := SnapshotRegistry.new().capture(host,barrier);check(captured.ok,"capture with no new actor fields "+str(captured.get("detail","")))
	if captured.ok:
		DirectionalAnimationSet._textures.clear();DirectionalAnimationSet._manifests.clear()
		var restored := SnapshotRegistry.new().restore(captured.snapshot);check(restored.ok,"cold graph restore "+str(restored.get("detail","")))
		if restored.ok:
			var copy: RunController=restored.root
			for i: int in samples.size():
				var actor: EnemyActor=copy.enemies[host.enemies.find(samples[i])]
				check(actor.character_animation.render_descriptor()==descriptors[i] and VISUAL.forest_tint(actor)==tints[i],"cold restore body/tint exact "+String(FOREST[i]))
			copy.free()
	barrier.release();paused=false
