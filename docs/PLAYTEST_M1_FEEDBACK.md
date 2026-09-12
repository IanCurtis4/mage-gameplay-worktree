# Rodada de feedback de playtest — Marco 1

## Feedback recebido

O primeiro playtest técnico apontou três atritos:

- as skills deixavam de participar do combate depois que a mana acabava;
- a navegação por grade transmitia movimento rígido em áreas abertas;
- selecionar e perseguir inimigos exigia precisão frustrante do clique.

Esta rodada permanece dentro do Marco 1. Não inicia conteúdo, sistemas ou arte do
Marco 2 e ainda depende de um novo playtest do usuário para aceite de sensação.

## Correções aplicadas

- Regeneração base de mana centralizada em `RpgStats`: 6 mana/s, somente vivo e sem
  pausa, limitada ao máximo. Corte custa 15 e investida 20.
- HUD de skills com custos e estados `PRONTO`, `SEM MANA` e `RECARGA`; mana fracionária
  é exibida por piso para não sugerir que uma skill já pode ser usada.
- Caminhos abertos seguem direto ao ponto real. Desvios são simplificados por linha
  de visão e o movimento consome continuamente o orçamento entre waypoints.
- Os laços de movimento de jogador e inimigos encerram quando não há progresso e
  consomem o orçamento planejado após um passo válido, evitando resíduos subpixel.
- Seleção assistida em raio total de 68 unidades, com prioridade para clique direto
  no corpo, realces distintos de hover/seleção e cancelamento ao clicar no chão.
- Ataque básico alcança 50 unidades além das bordas dos atores e mantém 16 unidades
  extras depois do engajamento, sempre exigindo linha de visão.

## Evidências automatizadas

`tools/verify.ps1` executa importação, testes e smoke no Godot 4.7.2:

- Fundação: 12 checks;
- Marco 1: 63 checks;
- Fluxo da arena: 32 checks;
- Layout em 1280×720 e 1920×1080: 18 checks.

As regressões incluem esgotamento/retorno da mana, pausa e morte, clique assistido e
prioridade de alvo, estados do HUD, caminhos diretos/desvios seguros, cliques de 5 px,
alvo móvel, alcance com linha de visão e deslocamento em 30/60/144 Hz atravessando
patamares de precisão. Capturas pontuais validam visualmente o estado `SEM MANA` e o
anel de seleção.

## Reteste pendente

O aceite final requer jogar novamente e observar se as skills voltaram ao ciclo
natural, se trajetos abertos parecem contínuos e se seleção/perseguição ficaram
tolerantes sem escolher o inimigo errado. A suíte não mede FPS real nem substitui a
avaliação de sensação do usuário.
