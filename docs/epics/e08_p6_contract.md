# P6 — Feedback: receitas de VFX e áudio para os kits atuais

Autorização humana em 8/11/2026 ([aceite provisório P4/P5](e08_p4_p5_provisional_acceptance.md)).
Checkout `.tools/map-editor-m5`, branch `codex/e08`, base fd32d346 + árvore P5
validada tecnicamente (ainda sem commit). [Plano](e08_approved_plan.md),
[posse](e08_p6_files.json), [briefing Codex](e08_p6_imagegen_briefs.md).
Sem master/push/checkout habitual/save. Inventário de partida: levantamento
só de leitura de 8/11 (resumo na seção "Ponto de partida").

## Decisões do usuário (8/11)

1. **Cobertura:** uma receita por família de entrega × elemento cobrindo as 71
   habilidades ativas, os ataques básicos e os ataques inimigos da floresta, mais
   receitas próprias para 1–2 habilidades-assinatura por classe.
2. **VFX:** desenhados em código no estilo atual; flipbooks raster gerados pelo
   Codex só para as assinaturas, como WIP com briefing (sem substituto procedural
   apresentado como arte final; a versão em código fica como fallback).
3. **Som:** síntese local refeita (ruído filtrado e em camadas, transientes,
   famílias por elemento e entrega, pequena variação de altura/volume por evento).
   Sem amostras externas, sem música. Resolve a ressalva "bit-crushed" da P3, que
   vem de seno puro + ruído branco cru + um sample por tipo, não de quantização.

## Ponto de partida (8/11)

- No mundo espacial (floresta jogável) todo projétil é a mesma linha amarela de 18 u
  (`expedition_geometry_view.gd:198`); as silhuetas por habilidade só existem no
  caminho 2D legado. Pulsos do Elementalista não são desenhados no mundo espacial
  (`main.gd:1840`), e o arco de relâmpago também não.
- Áudio escolhe cue só por `kind` (13 cues, um WAV cada); `skill_id` ignorado.
- A ponte não emite eventos para golpe corpo a corpo, deslocamentos, buffs/gritos,
  curas, invocação/investida, gatilho vs expiração de armadilha; casts instantâneos
  saem com `skill_id` vazio. Impacto usa a âncora da vítima.
- Quase todo VFX é `draw_*`; arte raster de VFX só no Espiritualista e Soul Impact.
- Sem elemento como dado: está implícito no `skill_id` (e explícito no
  Elementalista/Geômetra).

## Arquitetura

- **Ponte (Sol):** novos kinds confirmados só onde falta informação, via `_publish`
  (dedup/época/pausa preservados), sem tocar dano, tempo, RNG, save ou ordem de
  simulação: `melee_swing` (golpe solicitado com direção; nunca implica acerto),
  `movement` (dash/salto/avanço/recuo, após o deslocamento canônico), `effect_start`
  (buff/grito/marca/postura instantâneos), `heal` (`HealthState.healed`), `summon`
  e `charge_start` (inimigos), `trap_trigger` (distinto da expiração; `area_end`
  passa a dizer o motivo). Casts instantâneos passam a levar `skill_id`. Mudança
  de payload documentada e testes ajustados com justificativa, nunca para ocultar
  falha.
- **Catálogo de receitas (Sol):** `scripts/presentation/feedback_recipe_catalog.gd`,
  constante e imutável (cópias), `skill_id` → `{family, element, signature,
  audio}`; famílias: cast, projectile, melee, impact, area, trap, buff, heal,
  movement, summon, charge, teleport, death/revive. Elementos: physical, fire, ice,
  lightning, arcane, spirit, nature, geometry, blood. Toda habilidade ativa de
  `profile_catalog.gd`, ataques básicos e ataques inimigos da floresta mapeiam;
  ids desconhecidos caem em receita genérica. Teste de cobertura exaustiva.
- **Áudio (Sol define, Terra sintetiza):** catálogo de cues por família × elemento
  com fallback para o cue atual por `kind`; ids e prioridades atuais preservados;
  variação determinística por `event_id` (altura ±4%, volume ±1,5 dB); limite de
  taxa para impactos repetidos (DOT/múltiplos alvos) antes do pool de vozes.
  Canais, 32 vozes, limiter, pausa, deduplicação e retomada sem replay preservados.
  WAVs 44,1 kHz mono PCM16 sem loop (ambiente à parte), com proveniência e receitas.
- **VFX (Terra):** consumidor de apresentação filho da ponte (Control ou tipo já
  excluído do snapshot), alimentado só por `event_confirmed`, determinístico por
  `event_id`, limitado, congelado na pausa, limpo na troca de estágio, ausente em
  staging passivo. Nunca cobre indicadores de perigo/alvo/área nem a UI. Funciona
  nos dois caminhos (mundo espacial e arena 2D legada).

## Assinaturas propostas (ajustáveis pelo usuário)

Mago fireball, teleport · Espadachim slash, terrifying_shout · Arqueiro arrow_rain,
explosive_trap · Defensor reprisal_wave, counterstroke · Berserker blood_rift,
wound_leap · Elementalista tri_nova, lightning_arc · Espiritualista (arte própria
existente preservada) dissipation · Geômetra collapse, triangulation · Sentinela
explosive_shot, headshot · Caçador freezing_trap, covering_shot · Guardião
(chefe) investida e invocação.

## Pacotes

**A1 Sol/Opus — contrato executável.** Extensão da ponte, catálogo de receitas,
catálogo de áudio por família com fallback e variação, limite de impactos, lista
final de cues (nomes e paths) publicada no recibo para A3. Testes:
`e08_feedback_recipe_test.gd` (cobertura das 71 + básicos + inimigos, imutabilidade,
fallback), extensões de `e08_presentation_test`/`e08_audio_test` (novos kinds
confirmados só após o fato canônico; nada muda dano/RNG/HP/SP/tempo; pausa,
dedup, época, retomada sem replay). Regressão completa da seleção P5.

Depois de A1, em paralelo com donos exclusivos:

**A2 Terra/Sonnet — VFX do mundo espacial.** Projéteis por receita em
`_draw_flights` (forma/cor/rastro por família×elemento, mesma posição/colisão),
pulsos e arco do Elementalista no mundo espacial, consumidor de feedback por
receita (substitui o pulso genérico, mantendo CAP/limpeza/oclusão), assinaturas em
código. Capturas no renderer real: zoom 50/100/160, UI 120%, piso claro/escuro.
Custo: mediana/p95 com e sem, cena de combate.

**A3 Terra/Sonnet — síntese sonora.** Novo produtor em `tools/` (ou extensão do
atual) gerando os cues de A1 com ruído filtrado, camadas e transientes; regenera
os 11 one-shots atuais no mesmo estilo; proveniência/receitas; prévia de audição
(sequência rotulada) para o usuário. Testes de formato existentes preservados.

**B1 Terra/Sonnet — flipbooks das assinaturas** (após Codex): empacotar, integrar
como camada sobre a versão em código, fallback quando ausente.

## Validação e limites

Wrapper `tools/e08_p6_fixture.ps1` (cópia do P5 com posse P6; trava única),
evidência imutável, falhas preservadas, Luna/Haiku ao fim de cada fase. Sem
mudança de dano, alcance, LoS, colisão, cooldown, tempo de combate, IA, RNG,
recompensas, save/snapshot. Aprovação técnica não é aceite de produto; o usuário
ouve a prévia e avalia em jogo.

## Flipbooks do Codex recebidos 8/11

Nove folhas em `assets/art/e08_vfx/staging/` (1254² RGBA, 4×4). Inspeção da
coordenação sobre fundo verde-floresta e cinza: legíveis, nenhum conteúdo cruza
bordas de célula; último quadro vazio em fire_burst, ground_shockwave, ice_shatter e
slash_arc (o briefing permitia quase vazio). Sem `provenance.json` do Codex: vale a
política P5 (`prompt: null`). B1 Terra/Sonnet empacota em paralelo à A1 (arquivos
novos, sem ligar consumidor); A2 integra os flipbooks às assinaturas com fallback
em código.

## Resultado técnico 8–9/11

- **A1 Sol** ([recibo](e08_p6_a1_delivery.md)): kinds melee_swing, movement, effect_start,
  heal, summon, charge_start, trap_trigger; cast instantâneo com skill_id; motivo em
  area_end. FeedbackRecipeCatalog cobre 71 ativas, 3 básicos, ataques/investida/invocação
  da floresta; 21 assinaturas. 75 cues planejados com fallback, variação por event_id e
  limite de impactos. Teste de receitas 997/0.
- **B1 Terra** ([recibo](e08_p6_vfx_art_delivery.md)): 9 flipbooks 640² (4×4, 160 px),
  alinhados, com sangramento de alfa; VfxFlipbookCatalog; teste 596/0.
- **A2 Terra** ([recibo](e08_p6_vfx_delivery.md)): projéteis por receita no mundo
  espacial, pulsos/arco do Elementalista, camada de feedback por receita (13 assinaturas
  com flipbook, 8 em código, contorno escuro nos pálidos), limites 48/3 por 0,06 s.
  Descoberta: `Control` aninhado no mundo não pinta no renderer real — o pulso P3 nunca
  foi visível em jogo; a pintura passou a um `Node2D` filho, contrato mantido. Corrigiu
  a falha pré-existente do Sentinela (atlas direcional da P4 e regra de ajuda de
  3c405e99). Custo (eventos sintéticos, atores congelados): mediana ~8,0→8,5 ms típico,
  ~8,1→10,1 ms em enxurrada; pico de 80 ms na primeira carga de flipbook. Teste 390/0.
- **A3 Terra** ([recibo](e08_p6_audio_delivery.md)): 75 cues sintetizados e 11 one-shots
  refeitos (ambientes intactos), picos −12 a −4 dBFS por papel; estresse de 24 vozes
  limitado em −1 dB sem amostras acima do teto. Prévia de 50,8 s em
  `.godot/verification/p6/A3_terra_audio_listening_preview/`.
- **Coordenação:** testes novos registrados no verify; `e08_audio_test` deixou de supor
  WAVs ausentes: o cenário de fallback simula a ausência e há checks com os WAVs reais
  (180/0).
- **Luna/Haiku** (A2_terra_vfx_verify_luna_p6_verify1 e sondas luna_p6_*): 72/72 testes
  com saída 0, sem SCRIPT ERROR; phase_presentation 10, forest_phase 9, forest_play 20 em
  janela. O hash do manifesto da fixture mudou só pela sincronização do próprio lote.

Pendências de produto: audição da prévia e avaliação em jogo pelo usuário; onda de choque,
espinhos, faíscas físicas e setas de investida fracos em chão claro/zoom 50; flipbooks
1,4–1,7× mais rápidos que o sugerido. Limites: capturas e custo com eventos sintéticos;
testes nativos de UI do editor e exportação de release não repetidos.

Aceite humano 9/11: o usuário ouviu a prévia e aprovou os sons P6. Avaliação visual dos
efeitos em jogo segue no candidato P7 ([contrato P7](e08_p7_contract.md)).
