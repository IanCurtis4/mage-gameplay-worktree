# Sentinela — revisão integrada de Astra

04/10/2026. Entrega Sol e791750 sobre e103162; correções isoladas na branch
codex/sentinel-review. Escopo conferido com E05_SENTINEL_PLAN.md: sete ativas,
duas passivas, slots 5+2, builds crítica/caster e apresentação própria.

## Achados reproduzidos e corrigidos

1. Rede/Explosivo percorriam a lista viva de inimigos enquanto callbacks de
   morte removiam elementos dela. Acertos letais podiam pular vítimas seguintes,
   inclusive o dano/root de sobreviventes. A resolução agora usa snapshot da
   lista, com a validação de existência/vida e deduplicação anteriores.
2. Abrir os menus de classe ou augments cancelava a munição Explosiva. Esses
   menus agora preservam a reserva como os demais modais de pausa. Esc e
   cancelamento explícito continuam liberando; fim/morte continuam limpando.

Regressão permanente e05_sentinel_review_test.gd usa EnemyActor real com callback
de remoção, três mortes seguidas e um sobrevivente em ambas as áreas; verifica
preservação ao abrir/fechar menus e cancelamento explícito. Antes: 16 checks,
8 falhas. Depois: 16 checks, zero falhas. Registrada em tools/verify.ps1.

## Evidências e alcance

Reprodução independente da suíte original: PASS. Prova gráfica independente
Compatibility/OpenGL: 286 checks, 30 capturas, zero falhas. Atlas e capturas
representativas inspecionados: solo, Rede em área, Concussão e reserva Explosiva,
pisos claro/escuro. Sem quadrado de fundo no personagem; HUD e slots legíveis.

Conferidos contratos de reset/custos/reserva, escalamento primário isolado,
CD local, geração/cap/pausa/limpeza de Foco, canais de CC, gates/carteiras e duas
builds legais. Revisões auxiliares foram interrompidas por limite de uso; seus
dois achados foram reproduzidos pelo condutor. Não são três pareceres completos.
O condutor concluiu a leitura integrada e as execuções descritas neste documento.

Suíte integral após correções: PASS, registrada em .godot/verification/astra_sentinel_final.log. Consolidação de 07/10/2026: nova execução integral vinculada ao commit final será exigida antes da publicação pelo workflow.

## Limites e aceite

Provas gráficas usam cenas controladas: não qualificam FPS, DPS sustentado nem
diversão. Cadência, economia de Foco/SP e equilíbrio entre builds dependem do
playtest humano. Sem alteração de schema ou save pessoal. Caçador não iniciado.

Revisão de código e apresentação: aprovada. Publicação condicionada ao PASS integral do commit consolidado, registrado na evidência local do workflow. O candidato pode avançar por FF de
codex/playtest, pois e103162 já é ancestral; não é necessário reescrever histórico.
Geômetra permanece incluída, sem inferir aceite humano dela ou da Sentinela.
Master e publicação remota aguardam autorização aplicável; não fazem parte
da preparação do playtest.

