# E08 P7-C3 — medições frio/quente do candidato

Sol (Opus), 9/11/2026. Candidato `79656308a7e32cf6ee344d9b3eb179180fc3ab32` (P4 corpos
direcionais, P5 mundo, P6 feedback/áudio ligados). [Recibo](e08_p7_release.md),
[plano: Validação](e08_approved_plan.md), comparação anterior do piloto em
[e08_pilot_release.md](e08_pilot_release.md).

## Protocolo

- Mesmo computador da F10/P3: GTX 1080 / NVIDIA 582.66, GL Compatibility em janela,
  1280×720, vsync desligado, seed 42, Floresta do Santuário pelo menu normal.
- Engine standard 4.7.2 (`ab1824f8…b22424`) montando PCKs exatos com `--main-pack`:
  F10 `RagRPG-F10-Q5-Terreno.pck` (`136d35e0…dee3a`), piloto P3 `RagRPG-E08-Piloto1.pck`
  (`d91bc713…46e2`) e candidato `RagRPG-E08-Candidato.pck` (`a4f3d54a…f878`).
- Ferramenta: `tools/e08_p7_package.ps1 -Stage Measure`. Reutiliza os controles F10
  `tools/e08_crowd_compare.gd` (96 atores) e `tools/e08_terrain_compare.gd` (floresta),
  mais `tools/e08_p7_measure_probe.gd` (preparação e ablação) e o modo `cost` de
  `tools/e08_p6_vfx_probe.gd` (carga sintética P6). Um processo e um perfil APPDATA
  descartável por execução. A ordem dos pacotes alterna a cada rodada. RSS amostrado a cada
  250 ms enquanto o processo vive (`PeakWorkingSet64`/`PrivateMemorySize64`).
- **Frio/quente:** rodada 1 é a primeira abertura de cada PCK após a exportação. A
  rodada 2 vem depois, com cache de shaders/arquivos do sistema já quente; o cache do
  Windows não foi esvaziado, então isto não é boot frio da máquina. Na preparação, "frio" é a
  primeira chamada num processo novo e "quente" é a segunda chamada no mesmo processo.
- Janelas de 3 s. Tabelas = mediana das medianas por janela, mediana dos p95 por janela e
  máximo de quadro; não são percentis sobre quadros agrupados.
- Evidência: `.godot/verification/p7/C3_sol_release_measure_p7_01` (todas as sondas,
  2 rodadas) e `..._p7_02` (floresta + ablação, 2 rodadas, sessão mais calma), cada uma
  com `protocol.json`, `runs.json` e `summary.json`.
- **Execuções descartadas:** a ablação da `p7_01` em piloto/candidato registrou `ERROR: Index p_bus = 5
  is out of bounds`. A sonda guardava o índice do bus antes do descarte de staging, o mesmo
  erro da ablação P0. A correção, só na sonda, resolve o bus pelo nome a cada uso. Apenas a
  ablação `p7_02`, 12/12 sem erro, entra nas conclusões. As demais 22 execuções da `p7_01` e as
  12 da `p7_02` terminaram com saída 0 e sem erro.

## Quadros

| Controle | Janelas | Mediana F10 → P3 → E08 (ms) | p95 F10 → P3 → E08 (ms) | Máx. F10 → E08 (ms) | E08 vs F10 |
|---|---:|---|---|---|---|
| 96 atores, móveis (p7_01) | 6 | 9,10 → 9,38 → **8,63** | 13,49 → 14,82 → **12,44** | 33,1 → 24,8 | −5% / −8% |
| 96 atores, parados (p7_01) | 6 | 4,33 → 4,56 → **4,74** | 7,08 → 7,76 → **7,27** | 20,3 → 13,1 | +10% / +3% |
| Floresta natural, p7_01 r1 (frio) | 3 | 16,38 → 13,97 → 16,31 | 22,64 → 20,12 → 22,99 | 31,4 → 29,9 | 0% / +2% |
| Floresta natural, p7_01 r2 | 3 | 12,39 → 12,67 → 13,81 | 16,21 → 17,07 → 18,33 | 21,5 → 22,5 | +12% / +13% |
| Floresta natural, p7_02 r1 | 3 | 11,30 → 12,18 → 13,62 | 13,84 → 15,37 → 18,66 | 25,3 → 29,1 | +21% / +35% |
| Floresta natural, p7_02 r2 | 3 | 11,55 → 12,41 → 12,50 | 14,32 → 16,29 → 16,85 | 20,5 → 24,2 | +8% / +18% |
| **Floresta natural, 12 janelas** | 12 | 12,05 → 12,45 → **13,78** | 15,84 → 17,01 → **18,49** | 31,4 → 29,9 | **+14% / +17%** |
| Ablação, controle normal (p7_02) | 6 | 11,21 → 11,76 → **13,00** | 14,15 → 15,04 → **16,68** | 23,7 → 30,7 | **+16% / +18%** |

A primeira rodada da `p7_01` ficou mais lenta para todos os pacotes, com F10 igual a E08. Isso
mostra ruído de sessão. As outras três rodadas pareadas e a ablação cruzam o limiar de triagem
de 10% no p95, e duas delas também na mediana. **A regressão da floresta parada é
reproduzível**: cerca de +1,2 ms de mediana e +2,5 ms de p95 contra a F10, e +0,3 a +1,2 ms
contra o piloto P3. A cena de 96 atores não regrediu: os corpos direcionais P4 não pesam mais
que os da F10 nesse controle.

## Ablação na floresta (p7_02, 6 janelas por modo, sem erros)

| Modo | F10 | P3 | E08 | E08 vs F10 |
|---|---|---|---|---|
| normal | 11,21 / 14,15 | 11,76 / 15,04 | **13,00 / 16,68** | +16% / +18% |
| sem camada de feedback P6 (ponte e camada sem processo, camada oculta) | 11,15 / 14,02 | 11,61 / 15,05 | 12,38 / 15,72 | +11% / +12% |
| sem ambiente de floresta P5 (oculto, sem processo) | 11,34 / 13,81 | 11,61 / 14,45 | 12,28 / 15,52 | +8% / +12% |
| sem áudio de mundo (pausado, limitador desligado) | 11,38 / 14,87 | 11,71 / 14,50 | 12,70 / 16,41 | +12% / +10% |
| **sem os três** | 11,37 / 14,12 | 11,49 / 14,28 | **11,93 / 15,25** | **+5% / +8%** |

Valores em mediana / p95, em ms. A F10 não tem nenhuma das três camadas, e o P3 não tem
ambiente; nesses pacotes as linhas são repetições do controle normal.

**Causa atribuída.** Cerca de dois terços do custo vêm das camadas de apresentação E08 sempre
ativas na floresta parada; o restante, cerca de +0,6 ms (+5%), vem do conteúdo P4/P5.
- **Ambiente P5** (`forest_ambience_layer.gd`): +34 draw calls por quadro, 648 contra 614 da
  F10, e voltam a 613 quando o ambiente é ocultado. Folhas, pólen, névoa e feixes são
  primitivas separadas.
- **Camada de feedback P6** (`e08_pilot_feedback.gd`/`feedback_vfx_layer.gd`): `_advance`
  chama `_redraw()` (dois `queue_redraw`) a cada `world_advanced`, mesmo com zero pulsos.
- **Áudio de mundo:** a cama de ambiente e o limitador ficam sempre ativos.

Cada uma dessas camadas, desligada sozinha, devolve 0,6–0,7 ms. Correções baratas possíveis,
todas dentro de arquivos de apresentação E08:
1. não redesenhar a camada de feedback quando `pulses` está vazio;
2. agrupar o desenho do ambiente em menos draw calls (malha/multimesh ou textura única);
3. pré-carregar as folhas P6 na configuração da camada.

**Não foram aplicadas.** Por decisão do coordenador, o SHA do candidato deve continuar válido:
mudanças de runtime voltam como pedido, e não entram neste pacote.

## Carga sintética P6 (candidato, `forest_terraces`, atores congelados)

| Carga (4 s × 3 janelas) | Com camada | Sem camada | Diferença |
|---|---|---|---|
| Típica r1 (~8 eventos/s) | 10,89 / 19,20 / máx 64,4 | 10,22 / 14,97 / 34,4 | +7% mediana |
| Típica r2 | 8,39 / 11,98 / máx 62,8 | 7,86 / 10,70 / 19,5 | +7% mediana |
| Enxurrada r1 (~40 eventos/s) | 11,31 / 20,01 / 37,6 | 9,01 / 14,79 / 32,0 | +26% mediana |
| Enxurrada r2 | 10,11 / 15,76 / 27,3 | 8,11 / 12,22 / 19,4 | +25% mediana |

Valores em mediana / p95 / máximo, em ms. A camada não existia na F10, então este é o custo da
funcionalidade, não uma regressão. O pico de cerca de 63 ms aparece nas duas rodadas, na
primeira janela típica com camada. É a primeira carga de folha animada, já registrada na A2
(≈80 ms). A recomendação de pré-carga está no item 3 acima.

## Memória

| Medida (floresta) | F10 | P3 | E08 |
|---|---:|---:|---:|
| Estática Godot antes do estágio (MiB) | 140,4 | 141,3 | 143,6 |
| Estática Godot pico no estágio (MiB) | 360,1 | 367,5 | **378,0** (+17,9) |
| Estática após limpar o estágio (MiB) | 221,1 | 222,0 | 231,9 |
| Retido acima do pré-estágio (MiB) | 80,71 | 80,77 | **88,34** (+7,6) |
| RSS pico amostrado, 4 execuções (MiB) | 752,8–761,7 | 760,3–767,3 | **781,6–793,3** (+≈30, +4%) |
| Memória privada pico (MiB) | 866–879 | 875–897 | **955–969** (+≈90, +10%) |

O aumento retido de +7,6 MiB é idêntico em todas as execuções, até a terceira casa decimal,
e fica abaixo do limiar de triagem de 16 MiB. É consistente com caches de catálogo e texturas
novos (folhas, corpos, sons) mantidos após o estágio, e não com crescimento por execução. Isso
não prova ausência de vazamento em sessão longa. A estática é o alocador Godot, não VRAM.
96 atores: estática 133,7 → 138,1 MiB, RSS 394–411 MiB nos três pacotes.

## Carregamento e preparação

| Medida | F10 | P3 | E08 |
|---|---|---|---|
| Entrada na floresta pelo menu, p7_01 (s) | 54,7 / 52,4 | 54,8 / 51,0 | 55,6 / 53,6 |
| Entrada na floresta pelo menu, p7_02 (s) | 43,0 / 44,5 | 43,6 / 46,7 | 48,8 / 46,6 |
| Preparação frio, processo novo (s) | 18,9 / 17,5 | 15,8 / 17,0 | 17,6 / 18,2 |
| Preparação quente, mesmo processo (s) | 11,7 / 10,5 | 12,5 / 10,7 | 12,1 / 10,4 |
| Reconstrução do skin do mapa (ms, 2×) | 1021–1204 | 1037–1105 | 1108–1462 |

Valores por rodada 1 / 2. A preparação não mudou além do ruído. A entrada no E08 ficou 0 a
5 s mais lenta. O digest do manifesto mudou de `12271a4e…` para `6259b6e5…` porque a P5
republicou os mapas, e é estável entre as duas chamadas e as duas rodadas. O digest de
regras `369eaa4b…` é idêntico ao da F10. A sonda de release do candidato mediu entrada
50,7 s, suspensão 8,0 s e retomada 42,6 s. Carregamento, portais e picos continuam dívidas F10.

## Conclusão

- Atores: sem regressão.
- Memória: dentro da triagem.
- Preparação: inalterada.
- **Floresta parada: regressão reproduzível de +14–16% na mediana e +17–18% no p95 contra a
  F10**, atribuída às camadas de apresentação E08 ativas sem combate: ambiente P5, redesenho
  ocioso do feedback P6 e áudio.
- Sem as três camadas, a diferença cai para +5% / +8%.
- Neste hardware, a mediana fica em cerca de 13 ms, perto de 77 FPS.
- A correção cabe em arquivos de apresentação E08. Foi registrada para um pacote seguinte, sem
  alterar este candidato.

Nada aqui promete FPS para a campanha inteira, outras placas ou sessões longas.

## Candidato `ba2a4b18` — depois das correções C4 (9/11/2026)

Candidato `ba2a4b18ef1005ac46446c1006a65ba14492fafe` (PCK `d3844a26…4f6b`), com as três
correções de [C4](e08_p7_perf_delivery.md):
- a camada de feedback não redesenha sem pulsos;
- o ambiente é desenhado em 3 comandos;
- as folhas animadas são pré-carregadas.

Mesmo protocolo, máquina, sondas e rodadas: F10, P3 e `ba2a4b18` alternados, 2 rodadas.
Evidência `.godot/verification/p7/C3_sol_release_measure_c4_01`: 26/26 execuções com saída 0,
sem nenhuma linha de erro. Esta sessão foi mais calma que a `p7_01`/`p7_02`, com F10 em
11,06 ms na floresta. Por isso a comparação válida é dentro da sessão; não se comparam
milissegundos absolutos com as tabelas acima. Os resultados de `79656308` acima ficam como
histórico.

| Controle | Janelas | Mediana F10 → P3 → E08 (ms) | p95 F10 → P3 → E08 (ms) | E08 vs F10 |
|---|---:|---|---|---|
| 96 atores, móveis | 6 | 7,63 → 7,43 → **7,02** | 9,16 → 9,08 → **8,39** | −8% / −8% |
| 96 atores, parados | 6 | 3,59 → 3,54 → **4,03** | 5,29 → 4,43 → **5,44** | +12% / +3% |
| Floresta natural r1 | 3 | 11,02 → 11,29 → 11,82 | 14,17 → 13,96 → 14,60 | +7% / +3% |
| Floresta natural r2 | 3 | 11,11 → 11,34 → 11,79 | 13,90 → 14,24 → 14,13 | +6% / +2% |
| **Floresta natural, 6 janelas** | 6 | 11,06 → 11,32 → **11,81** | 14,09 → 14,03 → **14,24** | **+7% / +1%** |
| **Ablação, controle normal** | 6 | 11,08 → 11,34 → **11,82** | 13,63 → 14,04 → **14,45** | **+7% / +6%** |
| Ablação, sem camada de feedback | 6 | 11,10 / 13,63 → 11,65 / 14,33 (E08) | | +5% / +5% |
| Ablação, sem ambiente | 6 | 11,07 / 13,70 → 11,70 / 14,27 (E08) | | +6% / +4% |
| Ablação, sem áudio de mundo | 6 | 11,10 / 13,68 → 11,83 / 14,54 (E08) | | +7% / +6% |
| Ablação, sem os três | 6 | 11,08 / 13,85 → 11,49 / 13,90 (E08) | | +4% / 0% |

**Floresta parada.**
- A diferença contra a F10 caiu de +14–16% / +17–18% (`79656308`) para **+7% / +1–6%**, abaixo
  do limiar de triagem de 10%. Contra o P3 ficou em +4% / +2–3%.
- Draw calls por quadro: 616 contra 614 da F10 (antes eram 648). Com o ambiente oculto, 613.
- Desligar cada camada agora devolve só 0,0–0,2 ms. O resíduo de cerca de +0,4 ms sem as três
  camadas é conteúdo P4/P5 (corpos, mapas republicados), como antes.

**96 atores parados.** +12% na mediana (+0,44 ms sobre 3,6 ms), com p95 de +3%. Na `p7_01`
foram +9,7% / +2,7%; o resultado se repete perto do limiar. A cena usa 96 atores `gel` com o
corpo direcional P4, e a mesma cena em movimento é 8% mais rápida que a F10. A causa provável é
o custo ocioso do corpo direcional P4, de ordem 0,4 ms em quadros de ~4 ms (~250 FPS).

Ficou registrado sem correção. Não há ganho de jogo claro e a cena é sintética. Uma correção
mexeria no runtime de animação P4, fora das camadas de apresentação C4.

**Carga P6 sintética** (`forest_terraces`, atores congelados):

| Carga | Com camada (mediana / p95 / máx.) | Sem camada | Diferença na mediana |
|---|---|---|---|
| Típica r1 | 7,89 / 10,51 / 39,4 | 7,45 / 9,63 / 16,0 | +6% |
| Típica r2 | 7,83 / 10,58 / 37,7 | 7,36 / 9,61 / 13,4 | +6% |
| Enxurrada r1 | 9,40 / 15,08 / 28,8 | 7,52 / 10,91 / 17,1 | +25% |
| Enxurrada r2 | 9,43 / 15,20 / 23,5 | 7,47 / 10,76 / 21,9 | +26% |

O pico da primeira janela típica caiu de cerca de 63 para cerca de 38 ms. A pré-carga elimina a
leitura do disco, mas um pico de primeiro uso continua, provavelmente o envio da textura à GPU no
primeiro desenho. A enxurrada (~40 eventos/s) custa o mesmo que antes: o custo dos pulsos ativos
não era alvo de C4.

**Memória e carregamento.**
- Estática Godot: pico 378,2 MiB (+0,2 contra `79656308`); retido após limpar 88,43 MiB
  (+0,09, ainda +7,7 contra a F10 e abaixo de 16).
- RSS pico 789,8–793,7 MiB (sem mudança). Memória privada pico 992–1009 MiB (+30–40 contra
  `79656308`), coerente com as 9 folhas mantidas carregadas pela pré-carga.
- Entrada na floresta 42,8 / 42,5 s contra F10 41,4 / 42,2 s (≤ +1,4 s).
- Preparação fria 14,6 / 14,6 s e quente 10,2 / 10,1 s, iguais à F10 (14,4–14,5 / 10,1–10,5).
  Digests iguais aos acima.

**Conclusão `ba2a4b18`.**
- Nenhuma regressão acima de 10% na floresta.
- 96 atores parados ficaram em +12% na mediana (~0,4 ms), registrados com causa provável.
- Memória dentro da triagem; preparação e entrada inalteradas.
- Continua sem promessa de FPS para campanha inteira, outras GPUs ou sessões longas.

## Candidato `261801de` — correções do primeiro playtest (C5/C6), rodada curta

Candidato `261801def65bb9022d7d5ffdd8c3b5bc82fd1246` (PCK `843d1ab7…fbc2`). Rodada curta pedida pelo
coordenador:
- só floresta natural e ablação, F10 contra candidato, 2 rodadas alternadas;
- mesma máquina e mesmas sondas;
- evidência `.godot/verification/p7/C3_sol_release_measure_c5c6_01`: 8/8 com saída 0, sem erro.

Sessão mais ruidosa que a `c4_01`: F10 em 12,0 ms, e uma janela da F10 com máximo de 88 ms.

| Controle | Janelas | F10 mediana / p95 | E08 mediana / p95 | E08 vs F10 |
|---|---:|---|---|---|
| Floresta natural r1 | 3 | 12,26 / 18,10 | 12,53 / 16,27 | +2% / −10% |
| Floresta natural r2 | 3 | 11,89 / 15,91 | 12,74 / 17,16 | +7% / +8% |
| **Floresta natural, 6 janelas** | 6 | 12,04 / 15,97 | **12,64 / 16,98** | **+5% / +6%** |
| **Ablação, normal** | 6 | 12,06 / 16,54 | **13,17 / 17,74** | **+9% / +7%** |
| Ablação, sem feedback | 6 | 12,49 / 17,56 | 13,08 / 17,80 | +5% / +1% |
| Ablação, sem ambiente | 6 | 12,05 / 16,97 | 12,86 / 17,90 | +7% / +6% |
| Ablação, sem áudio de mundo | 6 | 12,12 / 16,48 | 12,83 / 17,14 | +6% / +4% |
| Ablação, sem os três | 6 | 11,97 / 16,50 | 12,39 / 16,84 | +4% / +2% |

- Draw calls 616 contra 614, iguais a `ba2a4b18`.
- Estática Godot: pico 378,7 MiB, retido 88,42 MiB (igual a `ba2a4b18`).
- RSS pico 785–788 MiB; memória privada 978–999 MiB.
- Entrada 45,7–51,6 s contra F10 45,3–52,1 s.

**Conclusão `261801de`.** Nenhuma regressão nova. A floresta parada continua abaixo do limiar de
10% contra a F10. O controle normal da ablação ficou em +9% numa sessão ruidosa, dentro da faixa
de `ba2a4b18`. As correções C5/C6 só agem em combate e no desenho da cabeça, e não têm custo
mensurável na floresta parada.

Não se repetiram 96 atores, preparação nem carga P6 sintética. Ficam valendo os resultados de
`ba2a4b18`, porque C5 mudou só o desenho e o som do ataque básico e C6 só o encaixe da cabeça.

## Candidato final P7 `6b42b305` (C7)

Candidato `6b42b305abc24eec774bd20acb73cee15174b71d` (PCK `6529da02…191c`). O coordenador pediu
só uma rodada curta de floresta natural, F10 contra candidato. A primeira rodada saiu fora do
esperado, então acrescentei duas verificações na mesma sessão, usando `261801de` como
referência (`-ReferencePack`).

| Evidência | Pacotes | F10 | `261801de` | `6b42b305` | Final vs F10 | Final vs 261801de |
|---|---|---|---|---|---|---|
| `measure_c7_01`, floresta, 6 janelas | F10, final | 12,39 / 16,79 | — | 14,45 / 19,95 | +17% / +19% | — |
| `measure_c7_02`, floresta, 6 janelas | F10, ref., final | 11,66 / 14,59 | 12,19 / 15,46 | 12,56 / 16,20 | +8% / +11% | +3% / +5% |
| `measure_c7_03`, ablação normal | F10, ref., final | 10,99 / 14,31 | 11,97 / 14,87 | 12,31 / 15,28 | +12% / +7% | +3% / +3% |
| ablação sem feedback | | 11,13 / 13,93 | 11,91 / 15,18 | 12,14 / 15,19 | +9% / +9% | +2% / 0% |
| ablação sem ambiente | | 11,00 / 14,66 | 12,06 / 15,13 | 12,01 / 15,01 | +9% / +2% | 0% / −1% |
| ablação sem áudio de mundo | | 10,95 / 14,22 | 11,88 / 15,00 | 12,23 / 15,10 | +12% / +6% | +3% / +1% |
| ablação sem os três | | 11,04 / 14,46 | 11,93 / 14,73 | 11,97 / 15,07 | +8% / +4% | 0% / +2% |

Valores em mediana / p95, em ms.

- **`c7_01` não entra na conclusão.** Rodou com o computador em uso: navegador e outro aplicativo
  somando cerca de 2 núcleos, e a entrada na floresta chegou a 62,6 s. Fica só registrada.
- **`c7_02` e `c7_03`:** 12/12 com saída 0, sem erro. Draw calls 616 nos dois candidatos e 614 na
  F10. Memória: retido 88,45 MiB e RSS cerca de 784 MiB nos dois candidatos.
- **Final contra `261801de`:** a diferença varia entre 0% e +3%, sem padrão entre as ablações. Com o
  ambiente desligado ou com tudo desligado, empata. O código C7 só age ao receber impacto ou mira:
  a ponte e a camada não recebem eventos na floresta parada, e a única mudança na vista é zerar um
  campo dentro de `indicate()`. **Não há custo atribuível a C7;** a diferença está dentro do ruído
  entre processos.
- **Contra a F10, nesta sessão:** os dois candidatos ficaram de +8% a +12% na mediana e de +4% a +11%
  no p95. Mesmo sem as três camadas E08 ficaram em +8% / +2–4%, acima dos +4–5% medidos para
  `ba2a4b18` numa sessão calma. A distância para a F10 oscila com a sessão, entre +5% e +12%. O
  resíduo vem do conteúdo P4/P5, com corpos direcionais e mapas republicados (ver `ba2a4b18`).
- **Conclusão:** limítrofe ao limiar de 10%, sem regressão nova desde as correções C4.

Não se repetiram 96 atores, preparação nem carga P6; valem os resultados de `ba2a4b18`/`261801de`.
Nada aqui promete FPS para a campanha inteira, outras GPUs ou sessões longas.
