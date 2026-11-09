# E08 P7-C4 — correções de custo da floresta parada

Terra (Sonnet), 9/11/2026. Base `79656308`. Apenas apresentação; saída visual idêntica; sem mudança de
regras, tempo, catálogo de áudio ou save. Origem: [e08_p7_measurements.md](e08_p7_measurements.md)
(floresta parada +14–18% contra a F10, causada por camadas E08 ativas sem combate).

## Mudanças

1. **Camada de feedback sem redesenho ocioso** (`e08_pilot_feedback.gd`). `_advance` só chama
   `_redraw()` quando há pulsos ou quando o último pulso acabou de expirar (um redesenho final de
   limpeza, controlado por `_clear_pending`). Sem pulsos e sem nada a limpar: nenhum `queue_redraw`.
   Eventos, `stage_enter/exit`, limpeza passiva e `dispose` continuam redesenhando. CAP, determinismo,
   pausa, oclusão e `dispose` inalterados. Contador de diagnóstico `redraw_requests`.
2. **Ambiente em 3 comandos** (`forest_ambience_layer.gd`). O desenho passou de ~40 primitivas
   (`draw_polygon`, `draw_texture_rect`, `draw_circle`) para três chamadas
   `RenderingServer.canvas_item_add_triangle_array`: feixes, névoa (textura suave) e
   motes+folhas. As fórmulas, a ordem de desenho, o limite de 30 Hz, a semente, a pausa e o z 4050 são os
   mesmos. Os círculos são os mesmos leques de 64 segmentos de `draw_circle`; os feixes usam
   `Geometry2D.triangulate_polygon`, a triangulação de `draw_polygon`. Buffers fixos, sem alocação por quadro
   (exceto o vetor de índices retornado pela triangulação dos 4 feixes).
   `particle_centers()` e `last_batch_count` expostos para teste.
3. **Pré-carga dos flipbooks** (`vfx_flipbook_catalog.gd`, `feedback_vfx_layer.gd`).
   `VfxFlipbookCatalog.preload_all()` carrega e valida as 9 folhas uma vez por processo e as mantém
   referenciadas; `FeedbackVfxLayer.configure` a chama. Folha ausente/inválida é ignorada e continua
   fail-closed (`texture()` retorna null; o código cai no desenho por código).

## Draw calls e custo (renderer real, GL Compatibility, janela 1280×720)

| Medida | Antes | Depois |
|---|---|---|
| Draw calls, floresta com camada (sonda de ambiente, mediana) | 509 | **477** |
| Draw calls, floresta sem camada | 474 | 474 |
| Draw calls adicionados pelo ambiente | **35** | **3** |
| Quadro, com camada (mediana / p95, ms; árvore pausada) | 2,48 / 3,13 | 2,40 / 3,19 |
| Quadro, sem camada (ms) | 2,30 / 2,81 | 2,38 / 3,09 |
| Diferença do ambiente na mediana | +0,18 ms | +0,02 ms (ruído) |

O custo de CPU do ambiente caiu para dentro do ruído desta sonda. O valor de referência da medição
(34 draw calls) é consistente com os 35 daqui. O ganho do desenho do feedback ocioso e do áudio não
aparece nesta sonda (árvore pausada); o efeito sobre a floresta em jogo deve ser medido no
próximo `Measure` do pacote.

Carga sintética P6 (`e08_p6_vfx_probe.gd forest_terraces cost`, 3 janelas de 4 s):

| Janela típica 0, com camada | Antes (C1 `cost_after`) | Depois |
|---|---|---|
| Mediana / p95 / máximo (ms) | 9,55 / 19,08 / **58,4** | 8,03 / 11,13 / **40,1** |
| Sem camada, mediana | 8,39 | 7,41 |
| Enxurrada 0, com camada | 9,68 / 15,85 / 19,2 | 9,67 / 15,39 / 21,3 |

As sessões diferem (ruído de máquina: o "sem camada" também mudou), então só o pico do primeiro
trecho é atribuído à pré-carga; a mediana não. Pico de ~63 ms medido antes → 40 ms. A janela ainda traz
pulsos code-drawn e outros custos de primeira vez.

## Equivalência visual

Mesma semente (42), `layer.elapsed = 23.0`, zoom 50/100/160, escala de UI 120%. Capturas em
`C4_terra_perf_probe_c4_amb_before/probe` (código antigo) e `C4_terra_perf_probe_c4_amb_after/probe`.
Diferença por pixel (RGB 0–255):

| Zoom | Pixels diferentes | Diferença máxima |
|---|---|---|
| 50 | 0 | 0 |
| 100 | 0 | 0 |
| 160 | 1 de 921 600 | 1 nível |

As capturas "sem camada" são idênticas bit a bit. O efeito da camada em si é de ~280 mil pixels
(máx. 65–84 níveis), então a igualdade não é de duas imagens vazias. Posições por semente também estão
cobertas por teste.

## Testes

Comando: `./tools/e08_p7_fixture.ps1 -Stage verify -Package C4_terra_perf -EvidenceName c4_verify_full_01`
com os 13 testes pedidos: 13/326 passos aprovados, 0 falhas. Evidência anterior parcial: `c4_verify_01`
(falhou por erro de tipagem em meu teste, mantida) e `c4_verify_02`.

| Teste | Resultado |
|---|---|
| `e08_feedback_vfx_test` | 470 checks (inclui os novos: ociosidade, limpeza única, pré-carga, fail-closed, estágio/passivo) |
| `e08_forest_ambience_test` | 65 checks (inclui os novos: 3 comandos, posições = fórmulas antigas, contagem, semente, 30 Hz) |
| `e08_pilot_test` | 342 |
| `e08_pilot_ui_test` | 55 |
| `e08_vfx_art_test` | 596 |
| `e08_presentation_test` | 2246 |
| `e08_audio_test` | 180 |
| `e07_f1_presentation_test` | 39 |
| `e07_f7_presentation_test` | 27 |
| `e07_f3_snapshot_test` | 52 |
| `e07_f3_continuation_test` | 2743 (30 cenários) |
| `e07_f3_lifecycle_test` | 90 |
| `ui_layout_test` | 30 |

Nenhuma verificação existente foi enfraquecida ou alterada. O limite do teste "ambiente limitado" (≤ 48
partículas, estado fixo) continua; o novo valor fixado é `DRAW_BATCHES <= 3`.

Sondas: `c4_amb_before`, `c4_amb_after`, `c4_vfx_cost_after`; sincronizações `c4_sync_00..02`.

## Limitações

- O custo de quadro do ambiente foi medido com árvore pausada (sonda existente). Não refiz a ablação
  completa do `Measure` do C3; a recuperação total da floresta parada precisa de nova rodada.
- Os círculos são idênticos em geometria; um pixel a 160% difere por um nível (arredondamento de
  interpolação). Não há fonte de aleatoriedade nova.
- Fora desta ordem de custo: cama de áudio/limitador (contrato A1) não tocada. Vitória barata possível
  do lado da apresentação: nenhuma identificada sem mexer no contrato.
- A pré-carga mantém 9 texturas residentes (≈ memória já retida após o primeiro uso) e adianta o
  custo de carga para a configuração da camada.
- Nada commitado; sem push nem merge; pastas de candidato e saves intocados.
