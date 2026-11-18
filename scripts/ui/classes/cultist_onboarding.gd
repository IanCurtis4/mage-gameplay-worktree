extends "res://scripts/ui/classes/kit_onboarding_base.gd"
## E10a T10: read-only guide of cultist (texts from docs/HYBRIDS_56_V3.md and e10a_contract.md).

func identity_id() -> StringName:
	return &"cultist"

func guide_title() -> String:
	return "ABISMO DO CULTISTA"

func accent_color() -> Color:
	return Color("b48ae6")

func status_text() -> String:
	return "Loucura leva ao Delírio e ao Êxtase → o Ídolo atrai os inimigos e o Olhar enlouquece o grupo."

func help_text() -> String:
	return "Olhar do Abismo (job 20): canalização em cone com dano mágico contínuo e Loucura.
Delírio: no limiar da Loucura o inimigo ataca os outros por alguns segundos (no máximo 3 por vez); o chefe sofre Desorientação em vez disso.
Êxtase: cada Delírio ou Desorientação dá uma carga (até 5) com mais MATK e menos custo de SP; a partir de 3 cargas você recebe mais dano.
Ídolo Impossível: isca única que atrai comuns e elites e enche a Loucura de quem a vê, até do chefe.
Delírio Compartilhado: a Loucura contagia os vizinhos, uma vez.
Pupila Aberta: inimigos em Delírio ou Desorientação recebem mais dano seu.
Geometria Impossível: desorienta os comuns e deixa o chefe lento.
Revelação: Loucura rápida em todos à vista e uma Desorientação forte no chefe.
Base: Sussurro e Selo Sombrio somam Loucura; Prece e Escudo Votivo compensam o Êxtase."
