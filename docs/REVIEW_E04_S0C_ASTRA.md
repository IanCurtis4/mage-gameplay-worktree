# E04-S0-C — revisão técnica Astra

21/09/2026. **APROVADO no escopo do piloto Corte.**

Entrega revisada: `a834941`, base `ea61e68`. Revisão retomada após
interrupção por créditos; nenhum encaminhamento ao Sol nesta rodada.

## Parecer

- Tabela R1–R5 corresponde à decisão: poder 1,45/1,65/1,85/2,05/2,25 e
  SP 15/17/18/19/20, preservando alcance 155, cooldown 4 s e cast zero.
- Ator captura uma cópia validada do rank do snapshot; dano e débito de SP
  usam essa definição. Rank inválido bloqueia execução sem fallback para R1.
- HUD, disponibilidade e geometria da mira consultam os valores efetivos.
  Dispatch do Corte usa handler_id; demais skills mantêm o caminho legado.
- Sem achados bloqueadores neste pacote. A antiga menção a R1 gratuito no
  design foi superada por E04_LEARNING_AND_ARCHER.md; não é requisito vigente.

## Evidência reproduzida

`tools/verify.ps1` executado com Godot 4.7.2: importação, 24 suítes
(1.054 checks) e smoke passaram, processo com saída 0.
A suíte específica do Corte passou seus 27 checks, incluindo R1/R5,
dano emitido, SP insuficiente, isolamento do snapshot, rank inválido, HUD e mira.

Execução na composição `e071fff` da worktree E04. O ator e o teste S0-C
permanecem iguais aos da entrega `a834941`. Essa composição contém também
o pacote posterior de aprendizado do zero; passar seus testes não representa
revisão ou aceite técnico desse pacote nesta rodada.

## Limites

Aceite técnico somente de S0-C, sem avaliação visual por playtest nesta rodada.
Balanceamento continua sujeito ao teste do usuário. Não houve integração em
playtest/master, liberação de outro pacote ou acionamento do implementador.
