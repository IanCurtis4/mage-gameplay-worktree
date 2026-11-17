extends "res://scripts/ui/classes/kit_onboarding_base.gd"
## E09 T9: read-only guide of the mg_la kit (text from docs/HYBRIDS_56_V3.md).

func identity_id() -> StringName:
	return &"mg_la"

func guide_title() -> String:
	return "PRISMA DA LÂMINA ARCANA"

func accent_color() -> Color:
	return Color("b9c4e6")

func status_text() -> String:
	return "Marca Refratada → Refração → Salto Prismático às costas → golpes alternando os três elementos."

func help_text() -> String:
	return "Marca Refratada (job 20): a vítima acumula Sentença e fica visível através de obstáculos.\nLâmina Encantada: golpes corpo a corpo alternam fogo, gelo e raio; os três dão +2 de Sentença.\nRefração: ocultação por luz dobrada; o primeiro golpe ao sair dá +2.\nSalto Prismático: só oculto, teleporte às costas da vítima marcada.\nFratura de Luz: a Sentença que mata devolve a Refração e SP.\nSentença Prismática: golpe tricolor; morte certa abaixo do limiar.\nEspectro de Prisma: três reflexos, cada um salta numa vítima.\nFraqueza: frágil exposta; sai pelo Teleporte."
