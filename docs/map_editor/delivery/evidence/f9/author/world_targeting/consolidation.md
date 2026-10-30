# F9 checkpoint32 — mira de inimigos no mundo autorado

30/10/2026. Sol/Astra (Claude Opus). Reexecuções em `evidence/f9/luna/…` feitas pelo
executor de Sol; Luna não foi acionada nesta rodada.
Base 7452c2fc + checkpoint31 sem commit, mesma branch/checkout/fixture.

## Pedido humano

"É muito difícil dar target nos inimigos, mesmo clicando em cima deles." O
usuário pediu para comparar uma trava de alvo (aim assist) com só aumentar a
hitbox.

## Diagnóstico

- No modo plano, `BattleTargeting.pick` usa o corpo (raio + 4), assistência de
  68 px e trava de 80 px no alvo sob o cursor, ligadas pela opção "Trava
  inteligente" (`control_preferences.smart_lock`, padrão ligada).
- No mundo autorado (Bosque), `ExpeditionGeometryView.actor_at` era outro
  seletor: círculo fixo de 32 px em pé−24, sem assistência, sem trava e
  ignorando a opção. O sprite tem 52 px × escala (mobs até ~1,5×), então cabeça
  e lados ficavam de fora, e alvos em movimento escapavam do círculo.
- Probes no Bosque real: parados, 36/40 pontos do sprite acertavam e todos os
  7 inimigos eram visíveis. Em movimento, clicar no centro desenhado acertou
  1729/1729 amostras em 8 s, e clicar→primeiro dano levou 25 ms. Ou seja, o clique
  só funcionava com mira precisa. Nada indicava falha de visibilidade ou de
  perseguição.

## Decisão

Não aumentar `collision_radius`: ele define o corpo físico, o alcance e a
navegação, e mexer nele mudaria o combate. Também não criar um ímã novo. O que
foi feito:

1. A seleção usa o corpo desenhado (`CombatActor.pick_body_rect`, só para
   apresentação), com altura = sprite × escala, largura ≥ raio + 4 e folga de 6 px.
2. O mundo usa o mesmo contrato do modo plano: assistência de 68 px e trava de
   80 px, só para intenção de alvo único (clique básico e habilidades
   SINGLE_TARGET), respeitando "Trava inteligente". Traçados geométricos e áreas
   seguem sem assistência; Shift continua mirando o chão.
3. A visibilidade cai para a varredura de oclusão (`point_visible`) quando o pixel
   do pé resolve para a célula vizinha numa emenda. Atores ocultos não são
   selecionáveis.

Efeito colateral aceito: com a trava ligada, um clique de movimento a até 68 px
de um inimigo vira perseguição, como no modo plano. Quem preferir mover-se
livremente perto de inimigos pode desligar a opção.

## Evidência

- WorldTargeting16 (novo, fixture de patrulha com inimigo real): target_import_02
  PASS; luna worldtargeting_02 PASS.
- GameplayNative: o clique de chão em [120,0,200] caía na assistência do único
  inimigo e virava perseguição. O teste agora desliga a trava só nesse passo
  (intenção de movimento), e o resto do teste ficou como estava.
- RuntimeView12, SurfacePick24, CanvasOrder43, FieldsNative73,
  GameplayControls29, GameplayWindow33, GameplayGate24 PASS com a mudança (`*_01`);
  RoundedNative, Rounded e GameplayEditorNative22 PASS (`*_02`). RoundedResume
  não rodou: exige a sessão encadeada do RoundedNative.
- A tentativa `target_import_01`/`worldtargeting_01` falhou porque a fixture de
  população não tem inimigos. O teste passou a usar a
  fixture de patrulha (mesma do GameplayNative).
- Legados que tocam seleção: arena33, battle_ui47, E04 arqueiro87/mago106,
  geômetra 63/46/96, direções129 PASS. O E04 espadachim falha 4/93 em presets e
  arrays persistidos, idêntico com os três arquivos de HEAD na fixture
  (`legacy_e04_swordsman_head/change.log`).

## Pendente

Aceite humano da mira no Bosque e calibragem dos raios, se pedida. Os travamentos
de rotas longas (grafo reutilizável) continuam a afetar a sensação de combate.
