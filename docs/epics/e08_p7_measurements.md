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
