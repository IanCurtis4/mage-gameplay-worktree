# E08 P6 A3 — síntese sonora (entrega Terra)

Pacote `A3_terra_audio`. Entrega: 75 WAVs novos em `assets/audio/e08/p6/` (um por cue planejado
da lista do A1), 11 one-shots regenerados (`world_*`, `ui_*`) nos mesmos paths, produtor novo,
proveniência e receitas. Catálogo, serviço, testes e as duas camas de ambiente não foram alterados.

## Abordagem

Diagnóstico: o aspecto "bit-crushed" não vem de quantização (arquivos PCM16 44,1 kHz, importação
sem perdas) e sim da síntese P3: varredura de seno puro + harmônico 2,01x (timbre de chiptune),
ruído branco de banda cheia, um único sample por tipo de evento, sem filtro, camadas ou espaço.

Novo produtor `tools/prepare_e08_p6_audio.py` (Python 3 + numpy; `python tools/prepare_e08_p6_audio.py`):

- Determinístico: seed por id do cue (SHA-256), `RandomState` do numpy; DSP próprio (biquads RBJ
  passa-baixa/alta/banda, também varridos), sem scipy e sem amostras externas.
- Camadas por cue: transiente (clique) + corpo (parciais, FM, golpe grave com queda de altura) +
  granulação de ruído filtrado + whoosh/notas conforme a entrega.
- Família por elemento = timbre compartilhado; entrega = envelope compartilhado.
- Sala sintética leve (pré-atraso 8 ms, 4 combs, 2 all-pass, úmido filtrado em 4,8 kHz; 4–16 % por
  papel), passa-alta 28 Hz (sem DC), passa-baixa suave 9–12,5 kHz (sem chiado de banda cheia),
  fade-in 0,8 ms, fade-out 20 ms, primeira e última amostra exatamente zero, pico de amostra
  normalizado ao alvo.
- `tools/prepare_e08_pilot_audio.py` deixou de gerar os one-shots (código P3 removido; resta no
  histórico do Git) e gera só as duas camas de ambiente, byte a byte iguais (`ambience_stage`
  dbfcf1f6…, `ambience_forest` 0eb7bcbe…); suas entradas em `provenance.json` são idênticas.

## Receitas

| Elemento | Timbre |
|---|---|
| arcane | sino FM (razão inarmônica 1,414, índice decrescente), par desafinado, vibrato lento, banda de ar 3,2 kHz |
| blood | golpe de 75 Hz com queda de altura, ruído passa-baixa varrido (úmido), surdo e curto |
| fire | "woomph" grave + crepitar de impulsos esparsos (passa-banda 2,2 kHz) + chiado médio |
| geometry | parciais harmônicos limpos 1/2/3/5, sem vibrato, granulação mínima |
| ice | parciais inarmônicos 1/2,76/5,4/8,93 com par batendo, ruído ressonante 6,5 kHz e cliques |
| lightning | ruído agudo com portão irregular + ping ressonante 3,3 kHz + zumbido de serra 120 Hz filtrado |
| nature | madeira amortecida (1/3,9/9) + folhas tremulantes 3,3 kHz + terra grave |
| physical | baque de madeira com anel metálico discreto, ruído de couro passa-banda, seco |
| spirit | pad suave desafinado com vibrato, dois formantes de sopro (820/1750 Hz) |

| Entrega | Forma |
|---|---|
| cast (0,24 s) | ataque suave de 60 ms, altura subindo, corpo + granulação + clique tênue, baixo nível |
| projectile (0,26 s) | clique de saída, altura caindo (efeito Doppler), whoosh de ar |
| melee (0,22 s) | whoosh de ruído varrido em corcova, grunhido grave, sem som de acerto |
| impact (0,32 s) | clique + corpo + granulação + baque grave suave, cauda exponencial |
| dot (0,14 s) | tique curto e discreto |
| area (0,75 s) | crescendo + varredura para dentro, explosão aos 0,22 s, cauda filtrada |
| trap (0,38 s) | estalo mecânico (madeira + anel metálico) e explosão do elemento aos 35 ms |
| buff (0,55 s) | três notas ascendentes do corpo do elemento sobre sopro de ar |
| heal (0,50 s) | arpejo ascendente de quatro notas com brilho de granulação |
| movement (0,30 s) | whoosh de ar + dois passos rápidos e suaves |
| summon (1,0 s) | chamado grave + trompa formântica + folhas/rangido + baque tardio |
| charge (0,6 s) | rosnado formântico crescente + quatro passos pesados acelerando |
| teleport (0,5 s) | sucção passa-banda para dentro + queda, estalo, três notas cintilantes |

Assinaturas (21 `p6.sig.*`) combinam essas peças: bola de fogo (estouro + baque + crepitar longo),
corte (whoosh largo + brilho metálico), grito (serra aditiva por formantes móveis, tremor de 13 Hz),
chuva de flechas (12 assobios Doppler com pousos de madeira), contraforte (golpe de escudo + lâmina),
tri-nova (fogo, gelo e raio a 140 ms), arco voltaico (quatro estalos encadeados), dissipação
(acorde de quatro vozes subindo e sumindo), colapso (acorde descendente + implosão), triangulação
(três pulsos em arpejo), disparos de arco (estalo de corda), investida e invocação do Guardião.
A receita de cada arquivo está em `assets/audio/e08/provenance.json` (`recipe`).

## Níveis

Pico de amostra por papel (o limiter de −1 dBFS protege a soma; nenhum arquivo clipa): cast e dot
−12; projétil −10; movimento −10; buff e cura −9; golpe corpo a corpo −7; teletransporte −7; área −6;
impacto −5; armadilha −5; invocação e investida −5; assinaturas −4 a −10 (tiros leves −9/−10;
explosões, investida e invocação do Guardião −4); `ui_*` −9/−10; `world_*` seguem o papel equivalente
(cast −12, projétil −9, impacto −5, área −7, teleporte −7, fim de área −10, morte −6, revive −8).
Medido: pico entre −12,00 e −4,00 dBFS, |DC| ≤ 2e-4, primeira e última amostra 0, duração máxima
1,10 s (`sig_warden_summon`); cast 0,24 s, impactos 0,32 s, áreas 0,75 s. Os `p6.cast.*` são curtos
e baixos porque cast instantâneo de buff toca cast + buff no mesmo frame.

### Nível por cue

| Cue / arquivo | Dur. (s) | Pico alvo | Pico medido | RMS dBFS |
|---|---:|---:|---:|---:|
| `world_cast_start` | 0.26 | -12 | -12.00 | -25.7 |
| `world_cast_cancel` | 0.20 | -12 | -12.00 | -27.6 |
| `world_projectile_launch` | 0.24 | -9 | -9.00 | -25.3 |
| `world_impact` | 0.30 | -5 | -5.00 | -25.7 |
| `world_area_start` | 0.72 | -7 | -7.00 | -24.3 |
| `world_area_end` | 0.40 | -10 | -10.00 | -25.5 |
| `world_teleport` | 0.46 | -7 | -7.00 | -23.1 |
| `world_death` | 0.80 | -6 | -6.00 | -24.1 |
| `world_revive` | 0.62 | -8 | -8.00 | -20.1 |
| `ui_confirm` | 0.14 | -9 | -9.00 | -20.5 |
| `ui_cancel` | 0.16 | -10 | -10.00 | -23.5 |
| `p6.cast.arcane` | 0.24 | -12 | -12.00 | -25.6 |
| `p6.cast.blood` | 0.24 | -12 | -12.00 | -22.5 |
| `p6.cast.fire` | 0.24 | -12 | -12.00 | -21.8 |
| `p6.cast.geometry` | 0.24 | -12 | -12.00 | -25.9 |
| `p6.cast.ice` | 0.24 | -12 | -12.00 | -26.4 |
| `p6.cast.lightning` | 0.24 | -12 | -12.00 | -31.8 |
| `p6.cast.nature` | 0.24 | -12 | -12.00 | -26.0 |
| `p6.cast.physical` | 0.24 | -12 | -12.00 | -26.2 |
| `p6.cast.spirit` | 0.24 | -12 | -12.00 | -24.7 |
| `p6.projectile.arcane` | 0.26 | -10 | -10.00 | -26.5 |
| `p6.projectile.fire` | 0.26 | -10 | -10.00 | -23.2 |
| `p6.projectile.geometry` | 0.26 | -10 | -10.00 | -25.7 |
| `p6.projectile.ice` | 0.26 | -10 | -10.00 | -29.4 |
| `p6.projectile.lightning` | 0.26 | -10 | -10.00 | -28.5 |
| `p6.projectile.nature` | 0.26 | -10 | -10.00 | -26.6 |
| `p6.projectile.physical` | 0.26 | -10 | -10.00 | -25.6 |
| `p6.melee.blood` | 0.22 | -7 | -7.00 | -20.3 |
| `p6.melee.physical` | 0.22 | -7 | -7.00 | -20.2 |
| `p6.impact.arcane` | 0.32 | -5 | -5.00 | -21.8 |
| `p6.impact.blood` | 0.32 | -5 | -5.00 | -21.3 |
| `p6.impact.fire` | 0.32 | -5 | -5.00 | -22.0 |
| `p6.impact.geometry` | 0.32 | -5 | -5.00 | -23.4 |
| `p6.impact.ice` | 0.32 | -5 | -5.00 | -26.3 |
| `p6.impact.lightning` | 0.32 | -5 | -5.00 | -25.5 |
| `p6.impact.nature` | 0.32 | -5 | -5.00 | -23.6 |
| `p6.impact.physical` | 0.32 | -5 | -5.00 | -22.6 |
| `p6.impact.spirit` | 0.32 | -5 | -5.00 | -20.7 |
| `p6.dot.blood` | 0.14 | -12 | -12.00 | -26.1 |
| `p6.dot.fire` | 0.14 | -12 | -12.00 | -27.1 |
| `p6.dot.geometry` | 0.14 | -12 | -12.00 | -28.0 |
| `p6.dot.nature` | 0.14 | -12 | -12.00 | -26.9 |
| `p6.area.arcane` | 0.75 | -6 | -6.00 | -23.9 |
| `p6.area.blood` | 0.75 | -6 | -6.00 | -24.6 |
| `p6.area.fire` | 0.75 | -6 | -6.00 | -22.4 |
| `p6.area.geometry` | 0.75 | -6 | -6.00 | -25.6 |
| `p6.area.ice` | 0.75 | -6 | -6.00 | -26.3 |
| `p6.area.lightning` | 0.75 | -6 | -6.00 | -28.9 |
| `p6.area.nature` | 0.75 | -6 | -6.00 | -26.0 |
| `p6.area.physical` | 0.75 | -6 | -6.00 | -26.6 |
| `p6.area.spirit` | 0.75 | -6 | -6.00 | -23.6 |
| `p6.trap.fire` | 0.38 | -5 | -5.00 | -21.1 |
| `p6.trap.ice` | 0.38 | -5 | -5.00 | -25.3 |
| `p6.trap.nature` | 0.38 | -5 | -5.00 | -25.9 |
| `p6.buff.blood` | 0.55 | -9 | -9.00 | -19.5 |
| `p6.buff.nature` | 0.55 | -9 | -9.00 | -21.0 |
| `p6.buff.physical` | 0.55 | -9 | -9.00 | -21.1 |
| `p6.heal.blood` | 0.50 | -9 | -9.00 | -20.5 |
| `p6.heal.spirit` | 0.50 | -9 | -9.00 | -21.3 |
| `p6.movement.blood` | 0.30 | -10 | -10.00 | -24.0 |
| `p6.movement.physical` | 0.30 | -10 | -10.00 | -24.3 |
| `p6.summon.nature` | 1.00 | -5 | -5.00 | -20.7 |
| `p6.charge.nature` | 0.60 | -5 | -5.00 | -20.7 |
| `p6.charge.physical` | 0.60 | -5 | -5.00 | -20.5 |
| `p6.teleport.arcane` | 0.50 | -7 | -7.00 | -23.6 |
| `p6.sig.mage_fireball` | 0.90 | -4 | -4.00 | -23.3 |
| `p6.sig.mage_teleport` | 0.50 | -6 | -6.00 | -20.6 |
| `p6.sig.swordsman_slash` | 0.30 | -5 | -5.00 | -18.9 |
| `p6.sig.swordsman_terrifying_shout` | 0.70 | -6 | -6.00 | -26.4 |
| `p6.sig.archer_arrow_rain` | 0.80 | -8 | -8.00 | -22.7 |
| `p6.sig.archer_explosive_trap` | 0.40 | -4 | -4.00 | -22.0 |
| `p6.sig.defender_reprisal_wave` | 0.60 | -5 | -5.00 | -21.8 |
| `p6.sig.defender_counterstroke` | 0.32 | -4 | -4.00 | -22.7 |
| `p6.sig.berserker_blood_rift` | 0.36 | -5 | -5.00 | -19.3 |
| `p6.sig.berserker_wound_leap` | 0.45 | -6 | -6.00 | -22.4 |
| `p6.sig.elementalist_tri_nova` | 0.75 | -5 | -5.00 | -26.3 |
| `p6.sig.elementalist_lightning_arc` | 0.55 | -6 | -6.00 | -23.3 |
| `p6.sig.spiritualist_dissipation` | 0.85 | -7 | -7.00 | -23.2 |
| `p6.sig.geometer_collapse` | 0.75 | -6 | -6.00 | -23.7 |
| `p6.sig.geometer_triangulation` | 0.38 | -10 | -10.00 | -25.9 |
| `p6.sig.sentinel_explosive_shot` | 0.45 | -4 | -4.00 | -21.5 |
| `p6.sig.sentinel_headshot` | 0.24 | -9 | -9.00 | -28.0 |
| `p6.sig.hunter_freezing_trap` | 0.45 | -5 | -5.00 | -25.4 |
| `p6.sig.hunter_covering_shot` | 0.30 | -10 | -10.00 | -26.4 |
| `p6.sig.warden_charge` | 0.72 | -4 | -4.00 | -18.4 |
| `p6.sig.warden_summon` | 1.10 | -4 | -4.00 | -21.8 |


## Prévia de audição

Pasta (fora de `assets/`, ignorada pelo Git):
`.godot/verification/p6/A3_terra_audio_listening_preview/`

- `e08_p6_a3_preview.wav` (50,8 s): por elemento a cadeia cast → projétil → impacto (blood e spirit só
  cast → impacto), melee leve/pesado, buffs, curas, armadilhas, movimento, teleporte, áreas, dot,
  investida, invocação, quatro assinaturas, morte/revive/UI novos e, no fim, antigo vs novo de
  `world_impact`, `world_projectile_launch`, `ui_confirm` e `world_death` (antigo logo antes do novo).
  Intervalos: 0,35 s dentro do grupo, 0,9 s entre grupos.
- `e08_p6_a3_preview_labels.json`: rótulo, início (s) e duração por item; abra o WAV num player e
  navegue pelos tempos do JSON.
- `old_oneshots/`: cópia dos 11 one-shots P3 originais, feita antes de regenerar.
- `e08_p6_a3_stress_24_voices_limited.wav` + `e08_p6_a3_stress_stats.json`: 24 vozes (impactos e
  casts) iniciadas em 0,35 s, somadas e passadas por limiter look-ahead de −1 dB (5 ms). Antes: pico
  +1,56 dBFS (19 amostras acima de 0 dBFS); depois: pico −1,00 dBFS, 0 amostras acima do teto, redução
  máxima 2,56 dB (média 0,92 dB onde atua; 5,4 % das amostras), RMS −19,0 dBFS. Sem sobrecarga
  numérica; a audição de artefatos é decisão do usuário.

Regerar: `python tools/prepare_e08_p6_audio.py` (cues) e
`python tools/prepare_e08_p6_audio.py preview <dir> <dir_dos_antigos>` (prévia e estresse).

## Importação e validação

`.import` dos 75 WAVs gerados pelo estágio `import` do wrapper e copiados de volta; o importador criou
`compress/mode=2` (QOA) e foi corrigido para `compress/mode=0`, sem 8 bits forçado, sem taxa máxima,
sem normalizar, sem loop (mesmos parâmetros dos `.import` existentes); a reimportação mantém os valores.
Validação somente por `tools/e08_p6_fixture.ps1 -Package A3_terra_audio` (evidências em
`.godot/verification/p6/A3_terra_audio_*`, imutáveis; falhas mantidas):

- `sync`: a3_sync_01 (109 entradas), a3_sync_02 (75, `.import`), a3_sync_03 (1), a3_sync_04 (2).
- `import`: a3_import_01 e a3_import_02. A reimportação dos WAVs concluiu (86 passos) e gerou os `.import`,
  mas o wrapper marcou falha porque o `main.gd` do A2, sincronizado em paralelo, pré-carrega
  `feedback_vfx_layer.gd`, ainda inexistente no fixture (erro de script fora do A3). Evidências mantidas.
- `verify` a3_verify_01 e a3_verify_03 (`e08_audio_test`, `e08_presentation_test`):
  `e08_presentation_test` 2246 checks, 0 falhas; `e08_audio_test` FALHA: 177 checks, 6 falhas, todas em
  `_test_p6_selection` (ver abaixo). O wrapper para na primeira falha, por isso os outros três testes
  rodaram à parte.
- `verify` a3_verify_02 e a3_verify_05 (`e08_pilot_test`, `e08_forest_ambience_test`,
  `e08_feedback_recipe_test`): 341 checks / 0 falhas (todo WAV de `Catalog.ids()` com 44,1 kHz, mono,
  16 bits, sem loop, 0 < pico < 32767), 58 / 0 e 997 / 0.
- Tentativa a3_verify_04 abortou antes do motor (fixture defasada por mudança concorrente de outro pacote);
  nome preservado, repetida como a3_verify_05 após `sync`.

### Pendência do coordenador: expectativas do A1 pré-A3 em `e08_audio_test`

As 6 falhas são asserções escritas para o estado sem WAVs ("fallback quando o WAV planejado falta",
"kinds novos sem cue ficam em silêncio", "sinal ausente", "trap sem WAV cai em `world.area_end`",
`select_cue` de `elementalist_tri_nova` esperando `world.impact`). Com os cues reais presentes o
serviço seleciona corretamente os cues planejados (`p6.impact.ice`, `p6.trap.fire`, `p6.movement.*`),
então as expectativas precisam ser atualizadas (por exemplo, instalando só os streams do fixture em
vez de usar os WAVs reais). Não editei o teste, conforme a restrição do pacote.

## Limitações

- Sem audição certificada: números (pico, RMS, duração, espectro) e o limiter de estresse não provam
  que o resultado soa bem; o usuário ouve a prévia e decide. Receitas e níveis são ajustáveis no produtor.
- Pico de amostra igual não implica sonoridade igual: cues muito transientes (gelo, raio) têm RMS menor.
- Sem medição de true peak, sem teste em caixas ou fones.
- Cast, dot e trap compartilham receita por elemento; a variação entre disparos fica a cargo da
  variação de altura/volume do serviço do A1.
