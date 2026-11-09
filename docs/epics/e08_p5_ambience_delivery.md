# E08 P5 A2 — ambiente da floresta (entrega Terra)

Apresentação apenas: sem efeito em dano, alcance, colisão, RNG, save, tempo ou
IA. Outros biomas inalterados.

## O que mudou

- `scripts/presentation/forest_ambience_layer.gd` (novo): camada procedural
  desenhada em código (sem imagem nova; só um `GradientTexture2D` radial criado
  em memória). Folhas, partículas de pólen, feixes de luz filtrada e névoa leve.
- `scripts/main.gd`: `attach_expedition_view` lê o bioma uma vez, repassa-o a
  `_begin_presentation_stage(id, resumed, biome)` e chama
  `ForestAmbience.install(view, bioma, seed)` logo após `backdrop.configure`.
  A linha 255 (`has_species_presentation`) não foi tocada.
- Áudio: cue `ambience.forest` (canal `ambience`) em `audio_event_catalog.gd`,
  seleção por `Catalog.ambience_for_biome(biome)` em `audio_service.gd`
  (`set_stage_biome`/`stage_biome`). `forest` escolhe o cue novo; qualquer outro
  bioma, vazio ou arena legada mantém `ambience.stage`. O loop privado passou a
  valer para todo cue do canal de ambiente (antes só `ambience.stage`).
- `tools/prepare_e08_pilot_audio.py`: `ambience_forest()`; o argumento `forest`
  regenera só esse arquivo e mescla `provenance.json` (os 12 hashes antigos
  ficam intactos). `assets/audio/e08/ambience_forest.wav` + `.import`
  (`compress/mode=0`, igual aos demais), `recipes.md`, `provenance.json`.
- Testes: `tests/e08_forest_ambience_test.gd` (novo), `tests/e08_audio_test.gd`
  (só acrescentou `_test_forest_cue`; nenhuma asserção existente mudou).
- `tools/e08_forest_ambience_probe.gd`: prova nativa e custo.

## Camada visual: limites

- Estado fixo: 39 partículas (10 folhas, 20 partículas, 5 manchas de névoa,
  4 feixes), teto `STATE_CAP = 48` (bloco de 48 registros de 6 floats). Movimento
  analítico a partir do tempo decorrido: sem acúmulo, sem nós novos, sem alocação
  por quadro (arrays de polígono reutilizados). Redesenha a 30 Hz.
- Determinística: o estado vem de `RandomNumberGenerator` com
  `hash(seed_text + "|" + stage_id)`; mesma seed gera o mesmo estado e o mesmo
  tempo gera a mesma posição.
- Alfa baixo: `MAX_ALPHA = 0.5` (folhas e partículas pequenas, 4 a 7 px),
  feixes até 0,14 com fade nas bordas, névoa 0,10.
- Ordem: filha da view de expedição (`ExpeditionGeometryView`, já alvo de
  apresentação do snapshot, logo fora do save), `z_index = 4050` absoluto. Fica
  acima de todo sprite do mundo (até 4000) e abaixo do nó de efeitos/indicadores
  da view (4090) e dos `CanvasLayer` da HUD (50/200). Perigo, alvo e área nunca
  são cobertos; a camada fica sobre atores e props com alfa baixo (sacrifício
  assumido: uma folha pode passar na frente de um sprite). O nó anda com a câmera
  em espaço de tela: zoom e escala de UI não mudam o tamanho nem o deslocamento.
- Ciclo de vida: `process_mode = PAUSABLE` explícito (o host é ALWAYS), portanto
  congela com o mundo pausado. É removida ao trocar de bioma/estágio ou ao
  liberar a view; retomada de snapshot reconstrói a view e reinstala a camada do
  zero (tempo 0), sem estado salvo. `install` é idempotente.

## Receita de áudio

Loop de 12 s, 44,1 kHz, mono, PCM16, seed `e08:forest-ambience-v1`, sem música.
Ruído branco filtrado de forma circular (duas voltas, sem emenda), passa-alta
para o farfalhar mais corpo grave, modulado por rajadas de 1, 2 e 5 ciclos
inteiros; oito cantos curtos esparsos (130 ms, 2,9 a 4,1 kHz) com envelope que
zera nas pontas. Pico 0,056, RMS 0,0109 (`ambience.stage`: 0,065 / 0,0113);
diferença da emenda 722 (int16) contra passo comum até 1542. sha256
`0eb7bcbec28d0fd22cd99c72292b14095f25cef804121b746d92bca127b974b7` (ver
`provenance.json`). Teste numérico, não auditivo.

## Testes

Todos pelo wrapper `tools/e08_p5_fixture.ps1`, pacote `A2_terra_ambience`.

| Teste | Resultado |
|---|---|
| `e08_forest_ambience_test` | 58 checks, 0 falhas (`a2_verify5`) |
| `e08_audio_test` | PASS, 145 checks (`a2_verify3`) |
| `e08_pilot_ui_test` | 55 checks, 0 falhas (`a2_verify3`) |
| `e08_presentation_test` | 2204 checks, 0 falhas (`a2_verify3`) |
| `e07_f1_presentation_test` | 39 checks, 0 falhas (`a2_verify5`) |
| `e07_f3_snapshot_test` | 52 checks, 0 falhas (`a2_verify5`) |
| `e07_f3_continuation_test` | 2743 checks, 0 falhas, 30 cenários (`a2_verify5`) |
| `e07_f3_lifecycle_test` | 90 checks, 0 falhas (`a2_verify5`) |
| `e08_pilot_test` | 189 checks, 0 falhas pelo runner real, cerca de 25 s (`a2_verify6`); antes da correção 191/0 em 146 s (`a2_pilotrun1`) |

`e08_forest_ambience_test` cobre: camada só no bioma floresta, idempotência e
troca de seed, contagem limitada e estado de tamanho fixo após 10 s simulados,
determinismo por seed, congelamento sob pausa e retomada, camada reconstruída do
zero, ordem de desenho contra o nó de indicadores real e canvas do mundo (abaixo
da HUD), pai excluído do snapshot (`_presentation_target`, varredura sem visitar a
camada), liberação na troca de estágio, integração real em `attach_expedition_view`
(áudio e camada), seleção do cue por bioma e fallback, WAV (formato, 12 s, pico,
RMS contra `ambience.stage`, emenda, sha256 contra `provenance.json`).
`e08_audio_test` ganhou 13 checks (nova função `_test_forest_cue`): cue floresta com sample real, loop em cópia
privada, pausa, retomada sem replay, troca de estágio, fallback por bioma vazio e
limite de 4 vozes de ambiente.

Evidências em `.godot/verification/p5/` (todas com prefixo `A2_terra_ambience_`):
`sync_a2_sync1..11`, `import_a2_import1` (importação inicial; `compress/mode=2`
reprovado), `import_a2_import2` (mode 0), `verify_a2_verify1` (2 falhas, abaixo),
`verify_a2_verify2`, `verify_a2_verify3`, `verify_a2_verify5`,
`probe_a2_probe1..3`, `probe_a2_pilotrun1`, `sync_a2_sync12`, `verify_a2_verify6`.

## Prova nativa e custo

`probe_a2_probe3/probe/`: `forest_with_layer_{50,100,160}.png` e
`forest_without_layer_{50,100,160}.png` (1280x720, UI 120%, seed 42, Floresta do
Santuário, GL Compatibility), `ambience_cost.json`. Observado: o personagem, a
barra de vida e a HUD seguem legíveis nos três zooms; a camada é sutil (folhas
como pequenos pontos, feixe e névoa quase imperceptíveis), por escolha. Nenhum
inimigo estava próximo no spawn, então a captura não mostra marcador de alvo;
a garantia de ordem vem do teste de z (4050 contra 4090), não da imagem.

Custo (parado, V-sync desligado, dois rodadas A/B intercaladas de 3 s, só a
camada processa), `probe3`:

| | mediana | p95 | chamadas de desenho (mediana) |
|---|---|---|---|
| com camada | 2,37 ms | 4,32 ms | 509 |
| sem camada | 2,18 ms | 3,19 ms | 474 |

Acréscimo cerca de 0,2 ms de mediana e 35 chamadas de desenho. `probe2`:
2,30 contra 2,17 ms mediana, p95 3,49 contra 3,85; `probe1` (antes de reduzir
para 30 Hz): 3,02 contra 2,32 ms. O p95 varia entre rodadas; o ruído da máquina
é da ordem do acréscimo. `script_ms` (Performance `TIME_PROCESS`) ficou nos
arquivos mas não é confiável: o p95 "com" aparece em centenas de ms em todas as
rodadas, incompatível com o tempo de parede de quadro; não usar.

## Falhas e correções

- `var stage_seed` colidia com `static func stage_seed`: erro de parse silencioso
  ("Could not preload"); a variável virou `layer_seed`.
- `.import` inicial gerado com `compress/mode=2` (QOA com perda): trocado para 0 e
  reimportado (`a2_verify1` acusou o formato).
- Nível visual inicial quase invisível (probe1): alfas e tamanhos aumentados;
  redesenho a 30 Hz e partículas sem `draw_set_transform` reduziram o custo.
- Regressão de tempo de `e08_pilot_test` (de cerca de 26 s para 146 s; estouro dos
  120 s do `verify.ps1` em `a2_verify3`/`a2_verify4`). Causa: o teste percorre cada
  WAV de `Catalog.ids()` amostra a amostra lendo `wav.data`, que copia o buffer
  inteiro a cada acesso (O(n²)); o loop de 12 s (529 200 amostras, 1,06 MB) custou
  cerca de 120 s a mais. Não era a cópia de loop do serviço (feita uma vez por
  stream e guardada em `_streams`), nem a camada (não roda no teste). Correção:
  `ambience.forest` saiu de `EVENTS`/`ids()` para `BIOME_AMBIENCE` em
  `audio_event_catalog.gd` (escolhido por bioma, nunca por tipo de evento);
  `definition()` continua resolvendo-o e há `ambience_ids()`. Efeito: o teste
  piloto não varre mais o WAV novo (189 checks em vez de 191: somem os 2 checks por
  WAV do arquivo da floresta, cobertos por `e08_forest_ambience_test`). Antes/depois:
  146 s (`a2_pilotrun1`) contra cerca de 25 s (logs `013`→`014` de `a2_verify6`,
  12:16:26 a 12:16:51), passando 189/0 pelo runner real
  (`-Stage verify -Test e08_pilot_test,e08_forest_ambience_test,e08_audio_test`,
  `a2_verify6`; forest 58/0, audio 145 PASS). Nenhum timeout alterado, nenhuma
  asserção enfraquecida (o check do forest no teste de catálogo passou a exigir
  `ambience_ids()` e ausência em `ids()`).

## Limitações

- Aceite visual é humano: o efeito é deliberadamente discreto; a captura não
  traz indicador de perigo/alvo/área.
- Camada acima dos sprites do mundo (necessário para aparecer sobre o piso
  opaco): folhas e partículas podem cruzar atores com alfa baixo.
- Sem câmera ativa a camada fica na origem do mundo (não ocorre na expedição).
- Áudio validado numericamente; sem audição nem mixagem simultânea real com
  driver nativo (`--audio-mix-native` não executado).
- Custo medido em um único hardware, GL Compatibility, cena parada.

## Correção da coordenação — 8/11

A solução acima (tirar `ambience.forest` de `EVENTS`/`ids()`) foi revertida: ela
fazia o e08_pilot_test e partes do e08_audio_test deixarem de cobrir o WAV de
floresta. O cue voltou a `EVENTS`; `BIOME_AMBIENCE` virou só a lista de leitos por
bioma (`ambience_ids()`). A causa O(n²) foi corrigida no próprio teste, que lê
`wav.data` uma vez, sem mudar asserções. Conferência Luna `luna_phaseA1`: 45
etapas/115.096 checks PASS, e08_pilot_test 191/0 em ~13 s.
