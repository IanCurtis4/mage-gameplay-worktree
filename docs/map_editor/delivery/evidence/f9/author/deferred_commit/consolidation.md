# F9 checkpoint33 — travamento em combate no Bosque

31/10/2026. Sol/Astra (Claude Opus). Reexecuções em `evidence/f9/luna/…` feitas
pelo executor de Sol; Luna não foi acionada. Base 006a42ca. Commits a416be84
(polling de recompensa, aviso de Augments, empate de alvos) e 686bc304 (gravação
adiada e reuso da pele).

## Pedido humano

Ficava impossível clicar quando os inimigos se amontoavam; ao abrir Augments o
jogo caía para ~0,1 FPS, sem abrir a tela nem pausar, e o personagem tomava dano.

## Diagnóstico medido

- Seleção: 2095 amostras de inimigos empilhados, 0 cliques perdidos; clicar no
  empilhado ataca o alvo. A mira não era a causa.
- Métricas da janela real do usuário: quadros de 5,1 s e 17,2 s antes da morte.
- Probes no Bosque: congelamento de 17–19 s a cada morte de inimigo. Cada morte
  executava uma transação completa da expedição: captura do mundo, restauração
  de cópia, nova captura, nova restauração, gravação do perfil e troca do host
  (que zera a seleção). Peças: captura 2,4 s; restauração 2,2 s; pack 1,1 s;
  `campaign_command` 9,6 s; reconstrução da pele autorada 5,8 s. Snapshot de 3,8 MB.
- Augments só abrem fora de combate (`run_state.can_open_choice`); antes não
  havia aviso. A recompensa no chão consultava um caminho completo por quadro.

## Decisão humana

"Adiar + aliviar": a morte vale na hora; a gravação durável acontece uma vez,
quando o combate termina, e fica mais leve.

## O que mudou

- Mortes ficam pendentes durante o combate (lápide já admitida por `valid()`;
  o snapshot carrega a fila) e são gravadas ao fim do combate, com aviso
  "Salvando a expedição…". Viagem, conclusão e revive aplicam mortes pendentes
  antes. Morte do jogador e ondas continuam gravando na hora.
- A gravação reaproveita a captura feita sob a barreira (−2,4 s) e o preview
  reaproveita a pele do host anterior (−~5,8 s).
- Pré-filtro exato por distância reta antes de consultas `ground_connected`
  (recompensa e áreas); sem polling da recompensa em combate.
- Aviso em pt-BR quando Augments são recusados em combate; empate exato de
  corpos empilhados resolve para o da frente.

## Evidência

- Bosque: 3 mortes numa luta sem quadro longo; uma gravação ao fim de 11,2 s
  (antes 17–19 s por morte).
- WorldRewardPoll10 (novo), GameplayNative53 (espera o fim do combate e confere
  o reuso da pele), GameplayGate24, Window33, Cli18, Controls29, EditorNative22,
  WorldTargeting16, CanvasOrder43, RuntimeView12, FieldsNative73 PASS.
- Legados: E07 F5 death kits 191, fault 20, population 40, recovery 33; E07 F1
  casts 113, consumers 133, echoes 271, sentinel areas 433; E06 rewards 51 e TX
  loot 49; E03 fluxo 17; E05 boss 17; E04 arqueiro/mago/escudo/folhagem/gelo
  PASS. E04 espadachim 4/93 é a falha conhecida de presets, igual em HEAD.

## Pendente

A gravação de fim de combate ainda leva ~11 s. O restante é o par
restauração em staging/restauração final do `ExpeditionService` (invariante
E07 F5: nada é publicado antes do escritor canônico) e as capturas. Reduzir
isso exige contrato Astra. Risco aceito: se o jogo fechar no meio de uma luta,
as mortes dela se perdem. Também pendentes: grafo de navegação reutilizável e
aceite humano.
