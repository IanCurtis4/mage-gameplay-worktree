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
		var painted := "res://assets/art/skills/painted/%s.png" % id
		var path := painted if ResourceLoader.exists(painted) else "res://assets/art/skills/%s.svg" % id
		_icons[id] = load(path) as Texture2D if ResourceLoader.exists(path) else null
	return _icons[id]

## Short mechanic line: base table first, then the kit module text (E09 C1.2).
static func mechanics_of(id: StringName) -> String:
	if MECHANICS.has(id): return MECHANICS[id]
	var kit_text := String(ClassKitRegistry.skill_text(id).get("mechanics", ""))
	return kit_text if not kit_text.is_empty() else "Habilidade desta classe."

static func name_of(id: StringName) -> String:
	var definition := ClassCatalog.skill_definition(id)
	return definition.display_name if definition != null else "Habilidade indisponível"

static func job_name(id: StringName, base: StringName = &"") -> String:
	if id == &"items": return "Equipamentos"
	if id.is_empty():
		# E10a C1.2: a registered base names itself through its module.
		if ClassBaseRegistry.is_base(base): return ClassBaseRegistry.display_name(base)
		return {&"swordsman": "Espadachim", &"mage": "Mago", &"archer": "Arqueiro"}.get(base, "Classe base")
	var definition := ProfileCatalog.pilot().evolution_definition(id)
	if definition == null and ClassKitRegistry.is_kit(id): return ClassKitRegistry.display_name(id)
	return definition.display_name if definition != null else String(id)

static func prerequisites(option: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for requirement: Dictionary in option["metadata"]["rank_requirements"].values():
		for raw: Variant in requirement["skill_ranks"]:
			var id := StringName(raw)
			result[id] = maxi(int(result.get(id, 0)), int(requirement["skill_ranks"][raw]))
	return result

static func emphasize(text: String) -> String:
	# Presentation only: values arrive from immutable catalog authorities.
	for term: String in ["dano físico", "dano mágico", "cargas", "feridas", "queimadura", "eletrificação", "SP", "Foco", "INT", "DES", "VIT", "ATQ", "ATQ mágico", "aprisionamento", "sangramento", "carga de guarda"]:
		text = text.replace(term, "[b]" + term + "[/b]")
	return text

static func _series(definition: SkillDefinition, field: StringName, suffix: String = "", multiplier: float = 1.0) -> String:
	var values: Array[String] = []
	for rank: SkillRankDefinition in definition.ranks:
		var value := float(rank.get(field)) * multiplier
		values.append(String.num(value, 2))
	var unique: Array[String] = []
	for value: String in values:
		if value not in unique: unique.append(value)
	return "[b]" + (values[0] + " (todos os ranks)" if unique.size() == 1 else " / ".join(values)) + "[/b] " + suffix

static func describe(option: Dictionary, summary: Dictionary = {}) -> String:
	var id := StringName(option["skill_id"])
	var definition := ClassCatalog.skill_definition(id)
	if definition == null: return "Habilidade indisponível."
	var rank := int(option["rank"])
	var maximum := int(option["maximum_rank"])
	var active := definition.category == SkillDefinition.Category.ACTIVE
	var copy := SkillCopy.text_for(id)
	var lines: Array[String] = ["[b]%s[/b]  ·  %s  ·  R%d/%d" % [name_of(id), "Ativa" if active else "Passiva automática", rank, maximum]]
	if not String(copy.get("flavor", "")).is_empty(): lines.append("[i]" + String(copy["flavor"]) + "[/i]")
	lines.append(emphasize(String(copy.get("effect", mechanics_of(id)))))
	if not String(copy.get("combo", "")).is_empty(): lines.append("[b]Interação[/b] · " + emphasize(String(copy["combo"])))
	var shown_rank := clampi(maxi(rank, int(option.get("item_rank", 0))), 1, maximum)
	var values := definition.rank_definition(shown_rank)
	if values != null:
		lines.append("")
		lines.append("[b]Escalas por rank (R1 → R%d)[/b]" % maximum)
		if id in HunterTuning.SKILL_IDS:
			lines.append(emphasize(ClassCatalog.hunter_description(id, shown_rank)))
		elif id in SentinelTuning.SKILL_IDS:
			lines.append(emphasize(ClassCatalog.sentinel_description(id, shown_rank).replace("Equipada:", "Aprendida (automática):")))
		elif id == &"piercing_shout": lines.append("Controle: " + _series(definition, &"power", "s") + ". O pulso de dano não usa essa duração como multiplicador.")
		elif id in [&"provoke", &"terrifying_shout", &"ice_wall", &"defender_anchor", &"foliage_shelter", &"slowing_arrow", &"spiritualist_spectral_veil"]: lines.append("Duração: " + _series(definition, &"power", "s"))
		elif id in [&"shield_wall", &"phantom_barrier"]: lines.append("Interceptações: " + _series(definition, &"power"))
		elif id == &"fury": lines.append("ATQ corpo a corpo: +" + _series(definition, &"power", "%", 100.0))
		elif id == &"extended_aim": lines.append("Bônus de alcance: " + _series(definition, &"power"))
		elif id == &"defender_retreat_guard": lines.append("Recuo: " + _series(definition, &"range") + "; [b]15% de redução frontal[/b] por [b]0,8s[/b].")
		elif id == &"berserker_deep_bleeding": lines.append("Duração extra de sangramento da Fenda: " + _series(definition, &"power", "s") + ". Cadência e dano por pulso permanecem iguais.")
		elif id == &"perseverance": lines.append("Escudo base: " + _series(definition, &"power") + "; [b]+%s × VIT + %s × INT efetivas[/b]." % [String.num(StatCalculator.PERSONAL_SHIELD_VIT_COEFFICIENT, 2), String.num(StatCalculator.PERSONAL_SHIELD_INT_COEFFICIENT, 2)])
		elif id not in [&"explosive_trap", &"geometer_trace", &"geometer_triangulation", &"geometer_collapse", &"geometer_translation", &"geometer_rewrite"]:
			if values.physical_weight > 0.0: lines.append("[b]Dano físico[/b]: " + _series(definition, &"power", "% do ATQ corpo a corpo", 100.0))
			elif values.precision_weight > 0.0: lines.append("[b]Dano físico[/b]: " + _series(definition, &"power", "% do ATQ de precisão", 100.0))
			elif values.magic_weight > 0.0: lines.append("[b]Dano mágico[/b]: " + _series(definition, &"power", "% do ATQ mágico", 100.0))
		var passive_axes := {
			&"swordsman_resistance": ["DEF física", "%", 100.0], &"vigor": ["Regeneração de HP fora de encontros", "%", 100.0],
			&"mage_mana_regeneration": ["Regeneração de SP", "%", 100.0], &"archer_precision": ["Precisão adicional", "pontos", 1.0],
			&"archer_cadence": ["Velocidade de ataque", "%", 100.0], &"trap_technique": ["Prazo armado extra", "s", 1.0],
			&"berserker_obstinacy": ["Dano melee direto com HP até50%", "%", 100.0], &"berserker_pursuit": ["SP recuperado por acerto elegível", "SP", 1.0],
			&"defender_watch": ["Redução de dano causado pelo alvo", "%", 100.0], &"defender_guard_return": ["SP por resposta elegível", "SP", 1.0],
			&"elementalist_prismatic_focus": ["SP por alternância elegível", "SP", 1.0], &"elementalist_prismatic_resonance": ["Terceiro elemento distinto", "%", 100.0],
			&"spiritualist_echo_recovery": ["SP por Eco elegível", "SP", 1.0], &"geometer_incidence": ["Bônus de interação efetiva", "%", 100.0],
			&"geometer_vector_memory": ["Prazo extra de novo vértice", "s", 1.0]
		}
		if passive_axes.has(id):
			var axis: Array = passive_axes[id]
			lines.append(String(axis[0]) + ": " + _series(definition, &"power", String(axis[1]), float(axis[2])))
		if id == &"blood_thirst":
			lines.append("ATQ corpo adicional por VIT investida: " + _series(definition, &"power"))
			var heals: Array[String] = []
			for r: int in range(1, maximum + 1): heals.append(String.num(ClassCatalog.blood_thirst_heal_fraction(r) * 100.0, 2))
			lines.append("Cura por abate: [b]" + " / ".join(heals) + "% do HP máximo[/b].")
		if id == &"spiritualist_echo_curse": lines.append("Onda de Eco: " + _series(definition, &"secondary_power", "% do ATQ mágico", 100.0))
		if id == &"geometer_vector_memory": lines.append("Prazo extra da figura: " + _series(definition, &"secondary_power", "s"))
		if id == &"slowing_arrow": lines.append("Dano físico fixo: [b]%s%% do ATQ de precisão[/b]." % String.num(definition.power * 100.0, 2))
		if id == &"double_shot": lines.append("Dano indicado por flecha; dois projéteis na execução base.")
		if id in [&"fire_wall", &"lightning_wall", &"berserker_blood_rift", &"elementalist_ember_path", &"elementalist_tri_nova"]: lines.append("Coeficiente indicado por impacto/pulso; duração e número de emissões seguem o efeito.")
		if id == &"berserker_pursuit_cut": lines.append("Contra alvo já ferido: [b]+30% do ATQ corpo a corpo[/b].")
		if id == &"berserker_rupture": lines.append("Detonação por carga: " + _series(definition, &"secondary_power", "% do ATQ corpo a corpo", 100.0))
		if id == &"berserker_execution": lines.append("Custo adicional: [b]3% do HP máximo[/b], não letal; [b]+20%[/b] contra alvo com até [b]35% HP[/b].")
		if id == &"defender_line_lock": lines.append("Aprisionamento: " + _series(definition, &"secondary_power", "s"))
		if id == &"berserker_breath_steal": lines.append("Cura em ferido sobrevivente: " + _series(definition, &"secondary_power", "% do dano aplicado", 100.0) + "; teto de [b]5% HP máximo[/b].")
		if active:
			lines.append("SP base: " + _series(definition, &"sp_cost"))
			lines.append("Recarga base: " + _series(definition, &"cooldown", "s"))
			if values.range > 0.0: lines.append("Alcance base: " + _series(definition, &"range"))
			if values.fixed_cast_time > 0.0 or values.variable_cast_time > 0.0:
				lines.append("Preparo: " + _series(definition, &"fixed_cast_time", "s fixos") + " + " + _series(definition, &"variable_cast_time", "s variáveis"))
			lines.append("Valores de catálogo: atributos, equipamento e augments podem modificar a execução. O dano aplicado considera a defesa do alvo.")
			lines.append("[b]Versões[/b] · escolha o rank nos detalhes antes de arrastar. As versões compartilham a recarga." if SkillCastRank.supports(id) else "Esta habilidade usa o maior rank disponível no atalho.")
	lines.append("")
	var wallet := "Base" if option["metadata"]["wallet"] == ProfileCatalog.BASE_WALLET else "Evolução"
	if option.get("item_only", false):
		lines.append("[b]Fonte: equipamento[/b]. Acesso enquanto equipado; sem investimento.")
	else:
		lines.append("Investimento: [b]1 ponto de %s por rank[/b] · %d pontos próprios restantes até o máximo." % [wallet, maxi(0, maximum - rank)])
	if int(option.get("item_rank", 0)) > 0: lines.append("Equipamento concede R%d; vale o maior rank entre aprendido e concedido." % int(option["item_rank"]))
	var requirement: Dictionary = option.get("next_rank_requirement", {})
	if not requirement.is_empty():
		var required: Array[String] = ["Job %d" % int(requirement.get("job_level", 1))]
		for prerequisite: Variant in requirement.get("skill_ranks", {}):
			required.append("%s R%d" % [name_of(StringName(prerequisite)), int(requirement["skill_ranks"][prerequisite])])
		lines.append("Próximo rank exige: [b]" + ", ".join(required) + "[/b].")
	if not option.get("next_rank_available", false) and option.get("next_rank") != null:
		lines.append("Sem pontos livres nesta carteira." if option.get("next_rank_error_code") == &"insufficient_points" else "Requisitos ainda não cumpridos.")
	return "\n".join(lines)

static func migration_notice(report: Dictionary, character_id: String) -> String:
	var current: Dictionary = report.get("all_skill_dependencies_migration", report)
	for entry: Dictionary in current.get("characters", []):
		if String(entry.get("character_id", "")) != character_id: continue
		var removed: Array[String] = []
		for skill: Dictionary in entry.get("removed", []):
			removed.append("%s (%d pontos de %s)" % [name_of(StringName(skill["skill_id"])), int(skill["purchased_ranks"]), "Base" if StringName(skill.get("wallet", &"")) == &"base" else "Evolução"])
		if entry.has("base_refund"):
			return "Na atualização da árvore, foram devolvidos %d pontos de Base e %d de Evolução. Skills retiradas: %s. Redistribua respeitando os requisitos." % [int(entry["base_refund"]), int(entry.get("evolution_refund", 0)), ", ".join(removed)]
		return "Na atualização da árvore, %d pontos de Evolução foram devolvidos. Skills retiradas: %s. Redistribua os pontos respeitando os novos requisitos." % [int(entry.get("evolution_refund", 0)), ", ".join(removed)]
	return ""

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
