extends "res://scripts/ui/classes/kit_onboarding_base.gd"
## E09 T9: read-only guide of the sp_la kit (text from docs/HYBRIDS_56_V3.md).

func identity_id() -> StringName:
	return &"sp_la"

func guide_title() -> String:
	return "GUARDA DO DUELISTA"

func accent_color() -> Color:
	return Color("d8a0a0")

func status_text() -> String:
	return "Aparo no golpe → o inimigo gira e perde você de vista → estocada pelas costas."

func help_text() -> String:
	return "Aparo (job 20): janela curta; só golpe corpo a corpo de frente é aparado.\nLeitura do Oponente: aparo +2 de Sentença, costas +2, outros golpes +1.\nRiposte Fatal: gasta a Sentença; se matar, o próximo Aparo é automático.\nFinta: o próximo golpe do inimigo conta como aparado.\nGuarda Paciente: sem atacar, a janela de aparo aumenta.\nRecuo em Guarda: a saída; o inimigo perde você de vista.\nDuelo: todo golpe de frente é aparado, e cada aparo devolve uma estocada.\nFraqueza: projéteis e áreas não podem ser aparados."
