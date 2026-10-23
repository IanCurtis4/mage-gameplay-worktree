class_name ExpeditionPresentation
extends RefCounted
## Pure text projection of service DTOs. No eligibility or reward decisions.

static func stage_name(id: String) -> String:
	return {"entry": "Entrada", "left": "Ramo lateral", "right": "Caminho principal", "final": "Destino final"}.get(id, "Estágio %s" % id)

static func portal_text(view: Dictionary) -> String:
	if view.is_empty(): return "Portal indisponível"
	return "%s · %s" % [stage_name(view["to_stage"]), "Aberto" if view["open"] else "Fechado — conclua a limpeza"]

static func campaign_text(view: Dictionary) -> String:
	var lifecycle: String = view["lifecycle"]
	var state: String = {"active": "Em exploração", "suspended": "Suspensa", "recovering": "Aguardando retorno após morte", "completed": "Concluída"}.get(lifecycle, "Aguardando recuperação")
	return "%s · %s\nOnda %d · relógio da fase: %.0f s" % [stage_name(view["stage_id"]), state, int(view["wave_index"]), float(view["remaining"])]

static func threat_text(view: ThreatView) -> String:
	var lines: Array[String] = ["Ameaça do alvo selecionado", "Alvo atual: %s" % participant_name(view.current_id), "Limiar de troca: %.1f" % view.switch_threshold]
	if not view.forced_id.is_empty():
		lines.append("Provocado por %s · %.1f s" % [participant_name(view.forced_id), view.forced_remaining])
	for entry: Dictionary in view.entries:
		lines.append("%s: %.1f%s" % [participant_name(entry["id"]), float(entry["amount"]), " · fora de alcance/visão" if not entry["eligible"] else ""])
	return "\n".join(lines)

static func participant_name(id: String) -> String:
	return "Você" if id == "player" else ("Nenhum" if id.is_empty() else id)

static func error_text(code: StringName) -> String:
	match code:
		&"migration_required": return "Este perfil precisa de uma prévia de distribuição dos bens antes de continuar."
		&"result_uncertain", &"save_in_progress": return "A confirmação da gravação está pendente. Aguarde a recuperação antes de continuar."
		&"recovery_required": return "Há uma gravação pendente que precisa de recuperação. Os dados foram preservados."
		&"content_revision_unavailable", &"checkpoint_version_unavailable": return "Esta expedição precisa de uma versão de conteúdo indisponível. O checkpoint foi preservado."
		&"locked_by_expedition": return "Este personagem tem uma expedição pendente. Retome-a antes de alterar a preparação."
		&"portal_closed": return "Derrote todos os inimigos obrigatórios para abrir este portal."
		&"destination_unsafe": return "A chegada está ocupada. Aguarde e tente novamente."
		&"out_of_range": return "Aproxime-se do portal ou objetivo marcado no mapa."
		&"rewards_pending": return "Colete as recompensas pendentes antes de concluir a fase."
		&"completion_unmet": return "A saída exige a limpeza do estágio e a proximidade do marco final."
		&"save_failed": return "A gravação falhou. A operação não foi confirmada; tente novamente."
		&"invalid_payload", &"invalid_identity": return "A entrada não é válida. Confira a seed decimal e tente novamente."
		_: return "A operação não foi confirmada (%s)." % code
