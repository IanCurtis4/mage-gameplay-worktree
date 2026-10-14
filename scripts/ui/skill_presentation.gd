class_name SkillPresentation
extends RefCounted
## Shared immutable presentation; catalog ranks and requirements remain authoritative.
static var _icons: Dictionary = {}
const MECHANICS := {
	&"slash": "Golpe físico em cone à sua frente.", &"dash": "Avança na direção escolhida; reposicionamento rápido.",
	&"shield_wall": "Postura de defesa frontal; protege contra ataques vindos da frente.", &"provoke": "Atrai a atenção de um inimigo e enfraquece sua defesa.",
	&"perseverance": "Concede um escudo temporário ao personagem.", &"piercing_shout": "Grito em área que reduz movimento e velocidade de ataque.",
	&"fury": "Aumenta a pressão ofensiva com bônus e penalidades temporários.", &"brutal_strike": "Golpe próximo que reduz a defesa física depois de causar dano.",
	&"concentrated_rage": "Ataque físico em uma faixa estreita à sua frente.", &"terrifying_shout": "Grito que amedronta e aumenta o dano recebido pelos atingidos.",
	&"swordsman_resistance": "Melhora a defesa física enquanto aprendida.", &"vigor": "Melhora a regeneração de HP fora de encontros.", &"blood_thirst": "Recupera HP ao eliminar inimigos.",
	&"fireball": "Lança uma bola de fogo que explode em área.", &"fire_wall": "Cria uma parede de fogo no chão.", &"fire_spear": "Lanças de fogo atingem o inimigo escolhido.",
	&"ice_spear": "Lanças de gelo atingem o inimigo escolhido.", &"lightning": "Descarga de raio contra o alvo escolhido.", &"electric_discharge": "Descarga elétrica próxima ao personagem.",
	&"lightning_wall": "Estabelece uma faixa elétrica no chão.", &"soul_impact": "Impacto mágico contra um alvo.", &"haunt": "Efeito espectral aplicado ao inimigo escolhido.",
	&"phantom_barrier": "Proteção espectral temporária.", &"ice_wall": "Coloca um obstáculo temporário de gelo; bloqueia caminhos.", &"teleport": "Reposiciona o personagem no ponto escolhido.",
	&"mage_mana_regeneration": "Melhora a recuperação de SP enquanto aprendida.", &"double_shot": "Dispara duas flechas contra um alvo.", &"piercing_arrow": "Flecha atravessa uma faixa à frente.",
	&"arrow_rain": "Chuva de flechas na área escolhida.", &"extended_aim": "Prepara a mira para um disparo.", &"snare_trap": "Armadilha que prende inimigos.", &"explosive_trap": "Armadilha que explode quando acionada.",
	&"slowing_arrow": "Flecha que reduz o movimento do atingido.", &"foliage_shelter": "Cria cobertura no ponto escolhido.", &"archer_precision": "Melhora a precisão dos ataques.",
	&"archer_cadence": "Melhora a cadência de ataque.", &"trap_technique": "Especialização passiva em armadilhas.",
	&"defender_counterstroke": "Ataque frontal do Defensor.", &"defender_watch": "Especialização passiva de vigilância.", &"defender_anchor": "Firmar posição para defesa.",
	&"defender_line_lock": "Controle de um inimigo para sustentar a linha.", &"defender_guard_return": "Passiva de retorno de guarda.", &"defender_wall_advance": "Avanço defensivo em faixa.", &"defender_reprisal_wave": "Onda frontal de represália.",
	&"berserker_rupture": "Ataque frontal de ruptura.", &"berserker_obstinacy": "Passiva de persistência do Berserker.", &"berserker_wound_leap": "Salto ofensivo na direção escolhida.",
	&"berserker_execution": "Golpe próximo contra um alvo.", &"berserker_pursuit": "Especialização passiva de perseguição.", &"berserker_blood_rift": "Fenda ofensiva em faixa.", &"berserker_breath_steal": "Arranca o fôlego de um alvo próximo.",
	&"elementalist_flame_burst": "Explosão de fogo no ponto escolhido.", &"elementalist_prismatic_focus": "Especialização passiva em foco prismático.", &"elementalist_glacial_ring": "Anel de gelo ao redor do personagem.",
	&"elementalist_lightning_arc": "Arco elétrico contra um alvo.", &"elementalist_prismatic_resonance": "Especialização passiva em ressonância elemental.", &"elementalist_ember_path": "Trilha de fogo na direção escolhida.", &"elementalist_tri_nova": "Nova elemental ao redor do personagem.",
	&"spiritualist_echo_curse": "Marca alvo e vizinhos; skills diretas em marcados provocam uma onda de Eco.", &"spiritualist_echo_recovery": "Especialização passiva em recolhimento do Eco.",
	&"spiritualist_soul_drain": "Drenagem espiritual contra um alvo.", &"spiritualist_spectral_veil": "Véu protetor temporário.", &"spiritualist_channel_focus": "Especialização passiva em canalização.",
	&"spiritualist_procession": "Procissão espectral na direção escolhida.", &"spiritualist_dissipation": "Rito contra marcados; também ativa uma onda de Eco.",
	&"geometer_trace": "F1/F2/F3 escolhem Fogo/Gelo/Raio. Coloca vértices A/B; Triangulação libera C.", &"geometer_triangulation": "Permite fechar um triângulo. R1:3 receitas puras; R3:21; R5:27.",
	&"geometer_incidence": "Passiva que recompensa interação efetiva de parede.", &"geometer_translation": "Move o último vértice, preservando seu elemento.",
	&"geometer_vector_memory": "Passiva que prolonga novos vértices e figuras.", &"geometer_collapse": "Consome uma parede ou triângulo válido com poder próprio.", &"geometer_rewrite": "Substitui o vértice mais antigo pelo elemento selecionado, preservando o prazo da figura."
}

static func icon(id: StringName) -> Texture2D:
	if id.is_empty(): return null
	if not _icons.has(id):
		var path := "res://assets/art/skills/%s.svg" % id
		_icons[id] = load(path) as Texture2D if ResourceLoader.exists(path) else null
	return _icons[id]

static func name_of(id: StringName) -> String:
	var definition := ClassCatalog.skill_definition(id)
	return definition.display_name if definition != null else "Habilidade indisponível"

static func job_name(id: StringName, base: StringName = &"") -> String:
	if id == &"items": return "Equipamentos"
	if id.is_empty():
		return {&"swordsman": "Espadachim", &"mage": "Mago", &"archer": "Arqueiro"}.get(base, "Classe base")
	var definition := ProfileCatalog.pilot().evolution_definition(id)
	return definition.display_name if definition != null else String(id)

static func prerequisites(option: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for requirement: Dictionary in option["metadata"]["rank_requirements"].values():
		for raw: Variant in requirement["skill_ranks"]:
			var id := StringName(raw)
			result[id] = maxi(int(result.get(id, 0)), int(requirement["skill_ranks"][raw]))
	return result

static func describe(option: Dictionary, summary: Dictionary = {}) -> String:
	var id := StringName(option["skill_id"])
	var definition := ClassCatalog.skill_definition(id)
	if definition == null: return "Habilidade indisponível."
	var rank := int(option["rank"])
	var maximum := int(option["maximum_rank"])
	var active := definition.category == SkillDefinition.Category.ACTIVE
	var lines: Array[String] = [name_of(id), "%s · Rank %d/%d" % ["Ativa" if active else "Passiva automática", rank, maximum]]
	var wallet := "Base" if option["metadata"]["wallet"] == ProfileCatalog.BASE_WALLET else "Evolução"
	if option.get("item_only", false):
		lines.append("Concedida pelo equipamento: acesso enquanto a peça estiver equipada; sem investimento de pontos.")
	else:
		lines.append("Carteira %s · 1 ponto por aumento · %d pontos próprios até o máximo" % [wallet, maxi(0, maximum - rank)])
	if int(option.get("item_rank", 0)) > 0:
		lines.append("Equipamento equipado concede R%d. Aprendizado e concessão usam o maior rank." % int(option["item_rank"]))
	if int(option["metadata"].get("free_rank", 0)) > 0: lines.append("Rank inicial gratuito: %d" % int(option["metadata"]["free_rank"]))
	var shown_rank := clampi(rank, 1, maximum)
	if id in HunterTuning.SKILL_IDS: lines.append(ClassCatalog.hunter_description(id, shown_rank))
	elif id in SentinelTuning.SKILL_IDS: lines.append(ClassCatalog.sentinel_description(id, shown_rank))
	else: lines.append(MECHANICS.get(id, "Habilidade desta classe."))
	if active:
		var preview_ranks: Array[int] = [shown_rank]
		if rank > 0 and rank < maximum: preview_ranks.append(rank + 1)
		for r: int in preview_ranks:
			var values := definition.rank_definition(r)
			if values != null:
				lines.append("R%d: SP %.0f · recarga %.1fs · preparo fixo %.2fs + variável %.2fs · alcance %.0f" % [r, values.sp_cost, values.cooldown, values.fixed_cast_time, values.variable_cast_time, values.range])
	var required_job := StringName(option["metadata"].get("required_evolution_id", &""))
	if not required_job.is_empty() and not option.get("available", false): lines.append("Exige job: %s" % job_name(required_job))
	for target: Variant in option["metadata"]["rank_requirements"]:
		if int(target) <= rank: continue
		var requirement: Dictionary = option["metadata"]["rank_requirements"][target]
		var requirements: Array[String] = []
		for prerequisite: Variant in requirement["skill_ranks"]:
			requirements.append("%s R%d" % [name_of(StringName(prerequisite)), int(requirement["skill_ranks"][prerequisite])])
		lines.append("R%d exige Job %d%s" % [int(target), int(requirement["job_level"]), " · " + ", ".join(requirements) if not requirements.is_empty() else ""])
	if not option.get("next_rank_available", false) and option.get("next_rank") != null:
		lines.append("Sem pontos livres nesta carteira." if option.get("next_rank_error_code") == &"insufficient_points" else "Requisitos ainda não cumpridos.")
	lines.append("Ativas confirmadas ficam na biblioteca; arraste para organizar atalhos. Passivas aprendidas são automáticas.")
	return "\n".join(lines)

static func run_preview(state: RunState, facade: RefCounted = null) -> Dictionary:
	var base := state.build_snapshot.base_class_id if state.build_snapshot != null else state.class_id
	var evolution := state.build_snapshot.evolution_id if state.build_snapshot != null else &""
	var catalog := state.build_snapshot._skill_catalog if state.build_snapshot != null else ProfileCatalog.pilot()
	if catalog == null: catalog = ProfileCatalog.pilot()
	var options: Array[Dictionary] = []
	var summary: Dictionary = {"base_skill_points_available": 0, "evolution_skill_points_available": 0, "job_level": state.build_snapshot.job_level if state.build_snapshot != null else 1}
	if facade != null and facade.current_profile() != null:
		var result: Dictionary = facade.skill_allocation_preview(state.character_id, facade.current_profile().revision, [])
		if result.get("ok", false):
			options.assign(result["skills"])
			summary = result["summary"]
	if options.is_empty():
		for id: StringName in catalog._skills:
			var metadata := catalog.skill_metadata(id)
			if base not in metadata["allowed_base_classes"] or ClassCatalog.skill_definition(id) == null: continue
			var rank := int(state.skill_levels.get(id, 0))
			var maximum := int(metadata["free_rank"]) + int(metadata["max_purchased_rank"])
			options.append({"skill_id": id, "metadata": metadata, "rank": rank, "maximum_rank": maximum, "available": catalog.skill_is_allowed(id, base, evolution), "next_rank": rank + 1 if rank < maximum else null, "next_rank_requirement": metadata["rank_requirements"].get(rank + 1, {}), "next_rank_available": false, "next_rank_error_code": &"run_active"})
	for id: StringName in ItemSkillAdapters.IDS:
		if not state.has_item_active(id): continue
		var found := false
		for option: Dictionary in options:
			if option["skill_id"] == id:
				option["item_rank"] = state.effective_skill_rank(id)
				found = true
		if found: continue
		var definition := ClassCatalog.skill_definition(id)
		var metadata := catalog.skill_metadata(id)
		if definition == null or metadata.is_empty(): continue
		metadata["wallet"] = &"items"
		metadata["required_evolution_id"] = &"items"
		metadata["rank_requirements"] = {}
		options.append({"skill_id": id, "metadata": metadata, "rank": state.effective_skill_rank(id), "maximum_rank": definition.ranks.size(), "available": true, "next_rank": null, "next_rank_requirement": {}, "next_rank_available": false, "item_only": true, "item_rank": state.effective_skill_rank(id)})
	return {"skills": options, "summary": summary, "base_class_id": base}
