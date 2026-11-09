# E08 P7-C1 — acabamento visual do feedback P6 (Terra)

Pacote C1 do [contrato P7](e08_p7_contract.md) ([posse](e08_p7_files.json)). Checkout
`.tools/map-editor-m5`, branch `codex/e08`, base `45b930ba`. Sem commit/push/merge, sem checkout
habitual nem save pessoal. Só desenho/parâmetros da camada de apresentação: nenhuma mudança em ponte,
catálogo de receitas, áudio, regras, tempo, colisão ou save. Aprovação técnica não é aceite de produto.
Pontos de partida: os pontos fracos do [A2](e08_p6_vfx_delivery.md).

## Arquivos

| Arquivo | Mudança |
|---|---|
| `scripts/presentation/feedback_vfx_layer.gd` | Itens 1-5 (abaixo). |
| `tests/e08_feedback_vfx_test.gd` | 390 para 448 checagens: `_polish_checks` novo + 1 valor fixado alterado (comentado). |
| `tools/e08_p6_vfx_probe.gd` | Modo `polish` (cenas por item sobre amostras de piso areia/terra/grama, zoom 50/100/160) e nota de escala do canvas. Sem mudança nas cenas antigas. |
| `world_projectile_art.gd` | Não precisou mudar (as faíscas físicas vivem na camada). |

## Mudanças por item

Capturas: renderer real (janela, `forest_terraces`, 1280x720, UI 120%), pisos planos de areia
(0,86/0,76/0,52), terra (0,74/0,60/0,42) e grama (0,36/0,52/0,22) desenhados em z 4060 sob a camada (4080),
mais o piso real do mapa na cena `pol_fps`. Antes = `C1_terra_polish_probe_c1_probe_before_polish` (código
`45b930ba`); depois = `..._after_polish_03` (final; `_01` e `_02` preservadas, eram iterações). Pasta
`.godot/verification/p7/<evidência>/probe/<cena>_<piso>_z<zoom>_t<ms>.png`. Folhas de contato antes/depois
(esquerda/direita) em `.godot/verification/p7/C1_sheets/` (`shockwave_t300/t600.png`, `thorns_t200/t500.png`,
`sparks_t150.png`, `charge_t400.png`, `fps_real.png`).

1. **Onda de choque (`ground_shockwave`: grito, onda de represália, colapso do Geômetra).** Contorno
   carimbado (8 cópias escuras a 2,2 px, alfa 0,6, cresce com o piso de zoom) no lugar da cópia única de 7%, mais
   um disco/anel escuro translúcido no chão (`_shock_underlay`, alfa 0,16/0,34, acompanha o raio do anel pelo
   quadro). Vida e translucidez mantidas. Capturas: `pol_shockwave_{sand,earth,grass}_z{50,100,160}_t{300,600,900}`.
   Antes some/pálido sobre areia e grama; depois lê com clareza nos três zooms e no piso real escuro.
2. **Espinhos (`nature_thorns`, armadilha de natureza).** Diâmetro 86 para 104 px, contorno carimbado escuro
   (1,5 px, alfa 0,72) e anel de chão verde-claro com halo escuro (`_thorn_ground_ring`, mais largo que a
   planta). Capturas `pol_thorns_*_t{200,500,900}`. Lê muito melhor (silhueta e anel); o acento ainda é uma
   planta pequena em 50%.
3. **Faíscas de impacto físico.** Núcleo quente (clarão amarelo-claro/laranja com borda escura), raios em três
   camadas (borda escura 4,4 px, brasa laranja 3 px, núcleo quente 1,5 px) e ponta brilhante, alcance +15%.
   Tetos de enxurrada intocados (`IMPACT_*`, `TARGET_GAP`, `PERIODIC_GAP`, CAP 48). Capturas `pol_sparks_*_t{60,150,280}`.
   Antes cinza-creme fino quase invisível na areia; depois leem claro em areia, terra e grama.
4. **Setas de investida.** Escala por piso de zoom: `chevron_scale = clamp(0,9 / zoom, 1, 2)` (tamanho, espaçamento
   e largura), lida de `get_global_transform_with_canvas()` (a sonda confirma escala do canvas = zoom da câmera).
   Em 50% = x1,8 (na tela chegam a 0,9 do tamanho de 100%); de 100% para cima x1,0 (nada muda em 160%).
   Borda escura extra (alfa 0,5) para ler sobre areia. Capturas `pol_charge_*_t{150,400,700}`.
5. **Velocidade dos flipbooks.** Todos os fatores em `SIGNATURE_ART`/`NATURE_TRAP_ART` agora 1,0 (fps do manifesto B1);
   vida = quadros / fps (slash/relâmpago 1,0 s, 12 fps 1,33 s, aviso/espinhos/portal 10 fps 1,6 s). Nenhum fator
   justificado foi necessário (<= 1,15 continua permitido; o cabeçalho e o teste exigem 1,0 a 1,15). A cena
   `pol_fps_real_z100` (t 150...1300 ms) mostra o corte (`slash_arc`) nítido até ~0,7 s, o `fire_burst` no pico a
   ~0,4 s e a onda no pico a ~0,6 s: ritmo mais lento que antes, ainda legível; a cauda final dos quadros é quase
   transparente.

## Testes

Evidências (`.godot/verification/p7/`): `C1_terra_polish_verify_c1_verify_01` (só `e08_feedback_vfx_test`, 448/0),
`..._verify_02` (lista completa, antes do ajuste final do anel de espinhos), `..._verify_03` (lista completa, final).
Todas passam; nenhuma falha a preservar.

| Teste | Resultado (verify_03) |
|---|---|
| e08_feedback_vfx_test | 448 checagens, 0 falhas (eram 390) |
| e08_vfx_art_test | 596 / 0 |
| e08_feedback_recipe_test | 997 / 0 |
| e08_presentation_test | 2246 / 0 |
| e08_pilot_test | 342 / 0 |
| e08_pilot_ui_test | 55 / 0 |
| ui_layout_test | 30 / 30 |
| e07_f1_presentation_test | 39 / 0 |
| e07_f7_presentation_test | 27 / 0 |
| e07_f3_lifecycle_test | 90 / 0 |
| e07_f3_snapshot_test | 52 / 0 |

Valor fixado alterado por design (1): "flipbook pulse expires with the sheet" avançava 30 x 0,03 s (0,9 s); o
`slash_arc` a 16 fps agora dura 1,0 s, então são 40 passos (comentado no teste). Novas checagens (`_polish_checks`):
fator de velocidade = 1,0 e dentro de [1,0, 1,15] para as 13 assinaturas e para o acento de natureza; vida do pulso =
quadros / (fps do manifesto x fator) e nunca lê além do último quadro; contorno carimbado presente, escuro e visível
(`OUTLINE_STAMP`/`OUTLINED`) para onda de choque e espinhos, 8 cópias em círculo e crescimento com o piso de zoom;
espinhos maiores que 86 px; camadas das faíscas (borda escura, núcleo quente, estreitando para dentro, some com o pulso);
`chevron_scale` em zoom 0,5/0,75/1,0/1,6/2,0 (>= 1,7 em 50%, 1,0 de 100% para cima, teto 2,0 em zoom extremo, tamanho
na tela >= min(zoom, piso)); segmentos escalam com k; fumaça de desenho de carga/impacto/onda/espinhos com zoom 0,5.
Não rodei a suíte completa de `tools/verify.ps1` (C2) nem alterei o registro do teste.

## Custo (sonda `cost`, cena de combate da floresta, mesmos 3 x 4 s por condição, vsync desligado)

`C1_terra_polish_probe_c1_probe_cost_before` (código base, restaurado temporariamente) e
`..._cost_after` (código C1; medido antes do último ajuste geométrico do anel de espinhos). Mediana das 3 janelas;
delta = com camada - sem camada:

| Carga | Antes: mediana / p95 / p99 | Depois: mediana / p95 / p99 |
|---|---|---|
| típica (com camada) | 8,92 / 12,97 / 16,97 | 8,88 / 12,71 / 16,12 |
| típica (sem camada) | 8,14 / 11,09 / 12,76 | 7,94 / 12,24 / 14,77 |
| típica, delta | +0,78 / +1,88 / +4,21 | +0,94 / +0,47 / +1,35 |
| enxurrada (com camada) | 10,51 / 17,33 / 20,54 | 9,62 / 15,55 / 17,90 |
| enxurrada (sem camada) | 8,44 / 12,43 / 13,87 | 7,77 / 11,79 / 13,42 |
| enxurrada, delta | +2,07 / +4,90 / +6,67 | +1,85 / +3,76 / +4,49 |

Dentro do ruído da máquina (as linhas "sem camada" variam até 1 ms entre rodadas): sem regressão mensurável,
mesmo com os flipbooks vivendo mais (pulsos vivos no fim da enxurrada 17-19 antes, 19-21 depois) e mais primitivas por
faísca/contorno. O pico inicial (primeira janela, até 164 ms antes e 58 ms depois) é o carregamento da textura, como
já registrado no A2.

## Fraquezas que restam (olhei as capturas)

- Contorno carimbado ressalta pixels de névoa quase transparentes da arte B1: aparece uma "sujeira" escura tênue ao
  redor de espinhos (zoom 160 sobre areia) e da onda de choque. É do alfa residual dos quadros, não do código;
  resolver na arte ou aceitar. O contorno da onda é grosso/quase preto em 160%: pode ser reduzido se o usuário achar pesado.
- Espinhos em 50% ainda pequenos (planta de ~50 px na tela); legíveis, não destacados.
- Setas de investida têm tom alaranjado de baixo contraste sobre areia (a borda ajuda, mas segue discreto), e em 50% duas
  investidas próximas se sobrepõem (cena sintética).
- Comparação antes/depois em quadros de fase diferente (a velocidade mudou): o "depois" no mesmo instante mostra um
  quadro mais cedo; use a cena `pol_fps` e os tempos para julgar o ritmo.
- Ritmo no manifesto (1,0-1,6 s) é mais longo que o do A2 (0,6-1,2 s): o impacto de fogo chega ao pico a ~0,4 s.
  Não avaliei sensação de jogo (só capturas estáticas); o usuário deve julgar. Se parecer lento, o ajuste é o fator
  em `SIGNATURE_ART` (até 1,15 por assinatura, documentado no cabeçalho).
- Piso real do mapa só em `pol_fps`; os demais itens foram vistos em amostras de cor plana (sem textura de relevo, sem
  indicadores de perigo de inimigos reais por baixo).
- Fora do escopo C1 e inalterado: ordem `melee_swing` x `impact`, dica de commit por quadro, Nova Tripla em 100%.
