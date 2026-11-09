# E08 P6 A2 — VFX do mundo espacial (Terra)

Pacote A2 do [contrato P6](e08_p6_contract.md) ([posse](e08_p6_files.json)). Checkout
`.tools/map-editor-m5`, branch `codex/e08`, sem commit/push/merge, sem checkout habitual
nem save pessoal. Aprovação técnica não é aceite de produto: arte e timing seguem como
WIP para o usuário avaliar em jogo. Consome o [recibo A1](e08_p6_a1_delivery.md) e o
[catálogo de flipbooks B1](e08_p6_vfx_art_delivery.md).

## Achado do renderer real (importante)

Um `Control` aninhado no canvas do mundo **não pinta** seus próprios comandos de desenho
(testado: `Control` sob `Node2D`, sob a raiz, `top_level`, com `size` grande, filho da
view — nenhum aparece; `Node2D` sempre aparece). Por isso o feedback do piloto P3
(`E08PilotFeedback`) nunca foi visível no jogo real: os testes dele são lógicos/headless.
Solução adotada: o `Control` continua sendo o nó do contrato (filho da ponte, excluído do
snapshot, mesmo nome) e **possui um filho `Node2D` ("Canvas")** onde ocorre todo o desenho.
Quem observa o `draw` do `Control` continua recebendo o sinal (o `Control` ainda pede redesenho).

## O que mudou

| Arquivo | Mudança |
|---|---|
| `scripts/presentation/feedback_vfx_layer.gd` (novo) | `FeedbackVfxLayer`: evolui `E08PilotFeedback` com receitas por família × elemento, assinaturas por flipbook com fallback em código, limite de enxurrada de impactos. |
| `scripts/presentation/e08_pilot_feedback.gd` | Mesmo contrato; ganhou ganchos (`_accepts`, `_make_pulse`, `_on_stage_cleared`), vida por pulso (`life`) e o filho `Canvas` (`_paint`). Comportamento do piloto idêntico (os asserts originais do piloto passam sem alteração). |
| `scripts/presentation/world_projectile_art.gd` (novo) | `WorldProjectileArt`: `spec(node)` (dados puros) e `draw(canvas, spec, ...)` das silhuetas de projétil. |
| `scripts/world/expedition_geometry_view.gd` | `_draw_flights` desenha por receita; pulsos e arco do Elementalista no mundo (`show_elementalist_pulse`, `show_elementalist_arc_link`, `clear_world_pulses`). |
| `scripts/presentation/presentation_event_bridge.gd` | Só `payload.element`: `note_element()` (dica do mesmo frame para o impacto) e elemento do traço do Geômetra no `projectile_launch`. |
| `scripts/main.gd` | Instancia `FeedbackVfxLayer`; `_apply_elementalist_hit` declara a dica de elemento; pulsos e arco do Elementalista chamam a view quando `world_area != null`; correção do guia contextual (abaixo). Nenhuma mudança de dano, tempo, RNG, IA, colisão ou save. |
| `scripts/actors/mage_projectile.gd`, `sentinel_projectile.gd` | Uma linha: `if world_flight != null: return` em `_draw` (o desenhista 2D deixa de pintar um desenho solto na origem do nó quando o voo é espacial; os outros desenhistas já tinham essa guarda). Adicionados à posse do A2. |
| `tests/e08_feedback_vfx_test.gd` (novo), `tests/e08_pilot_test.gd` (+1 assert) | Ver Testes. |
| `tests/e05_sentinel_integration_test.gd` | Regressão pré-existente (item 4 abaixo). |
| `tools/e08_p6_vfx_probe.gd` (novo) | Capturas e custo no renderer real. |

### Regressão pré-existente: Sentinela (8 checagens, 2 por cenário)

1. **Atlas.** O teste fixava `/sentinel_weaponless.png`; o P4 (`fd32d346`) tornou a Sentinela
   direcional (`assets/art/animations/directional/sentinel/weaponless.png`). A checagem agora
   exige `.../directional/sentinel/weaponless.png` (identidade própria, não a do Arqueiro) com
   comentário de uma linha; intenção mantida.
2. **Guia substitui a ajuda genérica.** `main.gd` `_layout_stage_minimap` (commit `3c405e99`)
   atribuía `help_panel.visible` só pelo layout, anulando o `hide()` do onboarding da Sentinela.
   Agora `help_panel.visible = geometer_casting == null and not is_instance_valid(sentinel_onboarding) and <layout>`:
   guias contextuais (Geômetra/Sentinela) continuam escondendo a ajuda genérica e a correção de
   layout do 3c405e99 permanece. `ui_layout_test` 30/30.

## Projéteis no mundo espacial

`_draw_flights` usa `WorldProjectileArt.spec(node)`: receita (família/elemento pela
`FeedbackRecipeCatalog`) + forma por habilidade, mantendo a identidade das silhuetas 2D:
bola (Bola de Fogo, ataque básico do Mago; cor do próprio nó), lança (Lança de Fogo/Gelo),
raio zigue-zague (Raio, Descarga), flecha (Arqueiro, Caçador, Flecha lenta em verde, flecha
inimiga com ponta vermelha), tiros da Sentinela (cinco formas próprias) e traço do Geômetra
(fogo/gelo/raio). Cada forma tem halo escuro translúcido para ler sobre piso claro. Posição,
colisor e dados de voo são os do `WorldProjectileMotion`; só desenho. A fase do brilho usa
`flight.travelled` (sem relógio de parede; congela na pausa).

## Pulsos e arco do Elementalista no mundo espacial

`ExpeditionGeometryView` hospeda uma instância de `BattleIndicators` (filha da camada de efeitos,
processo pausável) como pintor: mesma identidade fogo/gelo/raio da arena plana, alimentada com
coordenadas projetadas (raio de chão × 1,2 = meia-largura projetada) e oclusão por `point_visible`.
Cap 64 por fila (o da própria classe), limpa em `configure`, ignora staging passivo. O arco chama
`show_elementalist_arc_link` por salto (origem/alvo em altura de torso) e um pulso no alvo. O
`battle_indicators` da arena plana não é tocado.

`payload.element` (ponte): `note_element(alvo, elemento)` guarda uma dica (limite 32, expira no
frame) que o próximo `impact` do mesmo alvo e frame leva como `payload.element` (chamada em
`_apply_elementalist_hit`: chama, Explosão, Anel, Arco, Trilha, Nova); o traço do Geômetra leva o
elemento no `projectile_launch`. **Não preenchido** (elemento só conhecido fora do ponto de emissão
da ponte): impactos e `effect_start` do Geômetra (usam o elemento `geometry` da receita) e
`effect_start` do Elementalista (elemento da receita; a Nova desenha os três anéis).

## Camada de feedback por receita

`FeedbackVfxLayer` (nome `E08PilotFeedback`, `Control` filho da ponte): só `event_confirmed` +
`world_advanced`; CAP 48; limpa na troca de estágio; inativa em staging passivo ou pausado;
âncoras ocultas descartadas por `point_visible`; `dispose` idempotente. Cada pulso é função pura
do evento: `event_id` semeia o jitter por `sin`-hash (nunca RNG global nem relógio de parede) e a
idade vem do relógio visual da ponte.

### Receitas (resumo; fonte: `FeedbackRecipeCatalog` + `_draw_pulse`)

| Kind | Desenho (por elemento quando aplicável) | Vida |
|---|---|---|
| `impact` | faíscas por elemento: fogo = brasas + fagulhas ascendentes; gelo = estilhaços; raio = mini-raios; arcano = anel + estrela; espírito = fiapos; natureza = folhas; geometria = triângulo; sangue = gotas; físico = faíscas radiais | 0,38 s |
| `melee_swing` | arco de golpe orientado pela direção do payload (varredura 120°, afilado, halo); sangue deixa gotas | 0,26 s |
| `area_start` | anel elíptico no chão (raio do payload) com acentos por elemento na borda; Chuva de Flechas: salva de flechas | 0,55 s |
| `area_end` | só motivo `expire`: anel que se fecha (gatilho/limpeza não desenham) | 0,35 s |
| `trap_trigger` | anel + impacto ampliado; flipbook nas assinaturas e acento de espinhos nas armadilhas de natureza | 0,5 s |
| `cast_start` | anel de reunião (instantâneo menor, pois `effect_start` o acompanha) | 0,32 s |
| `projectile_launch` | clarão de boca na direção do disparo | 0,2 s |
| `effect_start` | buff = aura ascendente (anéis + divisas); área/impacto = anel de explosão; Nova = três anéis (fogo, gelo, raio) | 0,55 s |
| `heal` | cruzes verdes ascendentes | 0,75 s |
| `movement` | poeira atrás da direção (sangue: rastro) | 0,45 s |
| `charge_start` | três divisas de telégrafo pulsantes à frente | duração do evento (0,3–0,9 s) |
| `summon` | portal (anel duplo + partículas) | 0,85 s |
| `teleport`, `revive`, `death`, `cast_cancel` | anel arcano + riscos; anel + luz; fiapos cinza | 0,3–0,7 s |

### Assinaturas (21) e flipbooks B1

Uma assinatura só vale no kind da própria habilidade (`signature_kind`). Treze usam flipbook; oito
são só código (Chuva de Flechas, Salto Cruento, Nova Tripla, Dissipação [arte própria preservada],
Triangulação, Tiro Certeiro, Tiro de Cobertura, Investida do Guardião).

| Assinatura | Flipbook | Diâmetro (px) | Velocidade |
|---|---|---:|---:|
| `mage_fireball`, `sentinel_explosive_shot` | `fire_burst` | 74 / 72 | 1,5× |
| `archer_explosive_trap` | `fire_burst` | 96 | 1,4× |
| `mage_teleport` | `arcane_warp` | 84 | 1,5× |
| `swordsman_slash`, `defender_counterstroke` | `slash_arc` (girado pela direção; contorno escuro) | 82 | 1,7× |
| `swordsman_terrifying_shout`, `defender_reprisal_wave`, `geometer_collapse` | `ground_shockwave` (contorno escuro; tons azul/dourado) | 120 / 132 / 116 | 1,4× |
| `berserker_blood_rift` | `blood_rift` | 104 | 1,4× |
| `elementalist_lightning_arc` | `lightning_burst` (contorno escuro) | 60 | 1,5× |
| `hunter_freezing_trap` | `ice_shatter` | 92 | 1,4× |
| `warden_summon` | `summon_portal` | 96 | 1,7× |
| armadilhas de natureza (acento, não assinatura) | `nature_thorns` | 86 | 1,4× |

Quadro = `floor(idade × fps_sugerido × velocidade)`; escala = diâmetro ÷ `world_diameter_hint`. O
contorno escuro é uma cópia do quadro, 7% maior, modulada em quase preto (para `slash_arc`,
`lightning_burst`, `ground_shockwave`, `arcane_warp`, pálidos sobre piso claro). Flipbook ausente
(`flipbook_provider` devolve `{}` ou textura nula) → o mesmo pulso é desenhado em código.

### Limites (documentados no cabeçalho do arquivo)

- CAP 48 pulsos vivos (mais antigo sai primeiro); vidas de 0,2 a 1,0 s (flipbooks até 0,9 s).
- Enxurrada de impactos: no máximo 3 por habilidade por janela de 0,06 s; 1 por habilidade+alvo a
  cada 0,10 s (0,40 s para receitas periódicas/DOT); memória ≤ 256 chaves, limpa na troca de estágio.
  Relógio = relógio visual da ponte (congelado na pausa).
- Ordem: `Canvas` com z absoluto 4080 no mundo espacial (acima de atores ≤ 4000 e da camada de
  ambiente 4050; abaixo da camada de marcador/rota/objetivo/vértices do Geômetra em 4090 e de todo
  `CanvasLayer` da UI) e 10 na arena plana (abaixo do texto de dano, z 20). `z_as_relative = false`.

## Testes

`tests/e08_feedback_vfx_test.gd` — **390 checagens, 0 falhas** (rodado por sonda: não registrado
em `tools/verify.ps1`, **o coordenador deve registrar**). Cobre: seleção receita → família/elemento
para todos os ids do catálogo e para cada elemento por `payload.element`; todos os kinds; assinaturas
(21, só no próprio kind, flipbook presente e fallback em código quando o provedor devolve `{}`);
determinismo por `event_id` e RNG global intocado; orientação do golpe (plano e projeção espacial);
enxurrada, janela, folga por alvo, DOT, CAP e memória; pausa (idade e relógio congelados), staging
passivo, troca de estágio, `dispose` idempotente; oclusão (âncora oculta não desenha, todos os kinds
novos); ordem z; silhuetas de projétil por receita (16 casos + traços do Geômetra) e guardas dos
desenhistas 2D; dica de elemento da ponte (mesmo frame, expiração, inválido, limite) e payload do
traço; pulsos/arco do Elementalista na view (oclusão, passivo, cap, pausa, limpeza, sem tocar o
`battle_indicators` plano); estado de jogo (HP/SP/posições/recargas/estado do RNG do controlador) e
RNG global inalterados. O desenho é exercitado pela notificação `NOTIFICATION_DRAW` do `Canvas`
(fumaça de desenho sem erros em headless; a aparência só se valida no renderer real, abaixo).

`tests/e08_pilot_test.gd`: +1 assert (a camada instalada deriva do contrato do piloto e tem filho
`Canvas`); os demais asserts do piloto ficaram intactos (a classe base mantém o comportamento).

### Regressão exigida (wrapper `tools/e08_p6_fixture.ps1`, pacote `A2_terra_vfx`)

Evidência `A2_terra_vfx_verify_reg02` (30/325 passos, todos passam; a rodada anterior `reg01`, antes da
troca do desenho para o filho `Canvas`, também passou e foi preservada). Sonda do teste novo:
`A2_terra_vfx_probe_p08` (390/0; `p02`..`p07` preservadas, com os erros do próprio teste corrigidos).

| Teste | Resultado |
|---|---|
| e08_feedback_vfx_test (sonda) | 390 checagens, 0 falhas |
| e08_feedback_recipe_test | 997 / 0 |
| e08_vfx_art_test | 596 / 0 |
| e08_presentation_test | 2246 / 0 |
| e08_pilot_test | 342 / 0 |
| e08_pilot_ui_test | 55 / 0 |
| ui_layout_test | 30 / 30 |
| e05_sentinel_integration_test | 341 / 0 (as 8 falhas pré-existentes resolvidas) |
| e05_elementalist_* (14 testes) | todos PASS (11, 99, 7, 8, 7, 13, 10, 16, 11, 16, 15, 11, 12, 41) |
| e05_geometer_playtest_flow_test | 28 |
| mage_gameplay_test | 52 |
| e07_f1_presentation_test | 39 / 0 |
| e07_f7_presentation_test | 27 / 0 |
| e07_f3_snapshot_test | 52 / 0 |
| e07_f3_continuation_test | 2743 / 0 (30 cenários) |
| e07_f3_lifecycle_test | 90 / 0 |
| e07_f3_action_matrix_test | 2004 / 0 (21 cenários) |
| combat_animation_test | 39 |

Não rodei a suíte completa de `tools/verify.ps1` (325 passos).

## Evidência visual (renderer real, não headless)

`tools/e08_p6_vfx_probe.gd` (sonda `-Stage probe`, mapa `forest_terraces`, preview real, UI 120%,
1280×720, atores congelados; a sonda aciona só apresentação: eventos confirmados da ponte,
voos de projétil reais ligados ao mundo e avançados à mão, pulsos do Elementalista).

Evidência `A2_terra_vfx_probe_vfx17` (capturas em `.godot/verification/p6/A2_terra_vfx_probe_vfx17/probe/`,
70 PNG; `p6_vfx_report.json` ao lado) e `A2_terra_vfx_probe_vfx19` (arena plana, 6 PNG). Cada cena
foi capturada em zoom 50%, 100% e 160% (as de traços/flechas em 100% e 160%; a Nova só em 100%):

| Cena (prefixo) | Conteúdo |
|---|---|
| `fireball_z{50,100,160}_t{100,220,400,700}` | Bolas de Fogo em voo (cauda + brilho) e impacto `fire_burst` (fase do flipbook) |
| `elements_projectiles_*` | lança de gelo, lança de fogo, raio, descarga, flecha dupla, tiro perfurante e explosivo da Sentinela em voo; impactos de gelo, raio, físico e `fire_burst` |
| `traces_arrows_*` | traços do Geômetra (fogo/gelo/raio), flecha inimiga e flecha do Arqueiro |
| `elementalist_world_*`, `tri_nova_*` | Explosão de Chamas, Anel Glacial, pulso e arco voltaico (dois saltos) no mundo espacial; Nova Tripla |
| `melee_*` | Golpe (`slash_arc`), Contragolpe (girado), Fenda de Sangue (`blood_rift`), Golpe Brutal (código) |
| `areas_arrow_rain_*` | `ArrowRain` real (indicador de perigo do jogo) com a salva da receita por cima; muralhas, abrigo, fenda |
| `traps_*` | armadilha explosiva (`fire_burst`), de gelo (`ice_shatter`), de espinhos (`nature_thorns`) |
| `support_*` | investida do Guardião (telégrafo), invocação (`summon_portal`), grito (`ground_shockwave`), escudo, cura, Salto Cruento, teleporte (`arcane_warp`) |
| `impact_flood_*` | 28 impactos simultâneos de 4 habilidades |
| `legacy_z{50,100,160}_t{120,300}` (vfx19) | os mesmos tipos na arena 2D plana |

**Revisão (olhei as capturas):**

- **Legível:** `slash_arc`/`blood_rift` com o contorno escuro leem bem sobre o piso verde e o
  terra; `fire_burst` e `ice_shatter` fortes; silhuetas de projétil distintas (bola laranja, lança
  azul/laranja, raio, flecha, tiro da Sentinela) e legíveis em 100% e 160% (em 50% ficam
  pequenas, mas distinguíveis); pulsos do Elementalista no mundo mantêm a identidade fogo/gelo/raio da
  arena plana e o arco voltaico segue os saltos.
- **Fraco:** `ground_shockwave` (grito, onda de represália) é o mais pálido e some rápido sobre piso claro
  mesmo com contorno; `nature_thorns` é discreto; as faíscas de impacto físico são cinza-claras e
  finas (reforcei brilho/alcance depois da primeira captura); anéis de área ficam propositalmente
  finos (não competir com o indicador); telégrafo de investida (três divisas) pequeno em 50%.
  Quadros finais de `fire_burst` viram fumaça acinzentada tênue (arte do Codex).
- **Camadas:** a camada (z 4080) fica acima dos atores e **de suas barras de vida** e do texto
  de piso, mas abaixo do marcador/rota/objetivos (4090) e de toda a UI (painéis nunca cobertos). O
  indicador do `ArrowRain` real continua visível sob a salva; os anéis não cobrem o contorno do
  indicador. Limite real: indicadores de perigo desenhados no próprio nó do ator/campo
  (z <= 4000) ficam **abaixo** da camada por construção (a camada precisa estar acima dos atores);
  por isso os efeitos são translúcidos e curtos. Não foi possível capturar telégrafos de inimigos
  reais (atores congelados).
- **Feio/pendente:** a Nova Tripla em 100% mostra principalmente o pulso de fogo (o anel de comprometimento
  pequeno fica sob ele); o pulso de relâmpago do Elementalista (raios radiais em círculo de tela) é
  mais alto que o chão elíptico, herdado do pintor 2D.

## Custo (cena de combate da floresta, 62 inimigos, sem vsync)

`A2_terra_vfx_probe_vfx18` (3 janelas de 4 s por condição; `with_layer` = camada ligada;
`without_layer` = `dispose()` da camada, mesmos eventos publicados pela ponte; vsync desligado;
mesmos projéteis e pulsos de view nas duas condições, só a camada varia):

| Carga | Condição | mediana (ms) | p95 (ms) | p99 (ms) | pulsos vivos |
|---|---|---:|---:|---:|---:|
| típica (~8 eventos/s) | com | 8,45-8,66 | 11,1-11,8 | 12,7-15,3 | 4 |
| típica | sem | 8,00-8,14 | 10,3-10,6 | 11,5-13,0 | 0 |
| enxurrada (~40 eventos/s) | com | 10,0-10,2 | 15,5-16,1 | 17,4-18,4 | 16-18 |
| enxurrada | sem | 8,07-8,25 | 12,2-12,7 | 14,3-15,3 | 0 |

Custo da camada: cerca de +0,3 ms (mediana) e +0,6 ms (p95) em carga típica; +2 ms (mediana) e
+3,5 ms (p95) em enxurrada extrema. A primeira janela mostrou um pico de 80 ms (carregamento da textura
do flipbook na primeira vez; a camada não pré-aquece). O custo é de desenho (muitas primitivas por
pulso); a rodada anterior `vfx17` (antes de reduzir anéis de 36 para 24 passos e o arco de 14 para
10 segmentos) mediu +2,2 ms de mediana na enxurrada, então a otimização rendeu pouco na mediana.

## Limitações e pendências

- **Controle em canvas de mundo:** o achado acima vale também para qualquer outro `Control` do
  projeto desenhado no mundo; o pintor `Node2D` filho é o contorno adotado. O usuário deve conferir em jogo.
- **Elemento:** `payload.element` não chega nos impactos/`effect_start` do Geômetra nem no
  `effect_start` do Elementalista (só o impacto do Elementalista, via dica, e o `projectile_launch` do
  traço do Geômetra); a Nova usa a receita arcana no comprometimento e os três elementos nos pulsos.
- **Tempo dos flipbooks:** reproduzidos 1,4-1,7x o fps sugerido pelo B1 (0,6-0,9 s) para não
  alongar o feedback de golpe; ajustável em `SIGNATURE_ART`. Arte WIP do Codex sem revisão de produto.
- **Direção em arena plana:** `direction_2d` já está em tela; no mundo espacial é o plano do chão (x, z),
  como a ponte emite. Eventos sem direção usam a direita.
- **Nada medido com inimigos reais atacando:** capturas e custo usam atores congelados e eventos
  sintéticos no formato da ponte; cenas de combate reais (telégrafos de inimigos) ficam para o playtest.
- **Registro:** `tests/e08_feedback_vfx_test.gd` precisa ser registrado em `tools/verify.ps1`.
- **Ordem no fixture:** a sincronização de outro pacote (A3) pode copiar arquivos do A2 em estado
  parcial; sempre re-sincronizar antes de rodar (o wrapper recusa divergência).
