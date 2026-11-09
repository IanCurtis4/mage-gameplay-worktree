# E08 P7-C5: correções do primeiro playtest (rastro de caminho, ataque básico)

Pacote `C5_terra_aa_path` (Terra). Candidato de origem: `ba2a4b18`. Somente apresentação e áudio; planejamento de caminho, movimento e alvo não foram tocados. Sem commit, push ou merge.

## 1. Rastro do caminho de movimento

**Causa.** `ExpeditionGeometryView.indicate(point, valid, points)` guardava a rota planejada em `route` e `_draw_effects` desenhava um segmento ciano por trecho (`draw_line`, 2 px) até o próximo `indicate`. Depois do movimento a rota ficava impressa (captura 1 do usuário: duas linhas antigas).

**Mudança.** `scripts/world/expedition_geometry_view.gd`: removidos o campo `route` e o desenho dos segmentos; `indicate` continua aceitando um terceiro argumento (`_path_points`, ignorado) para os chamadores antigos (fixtures E07). `scripts/main.gd`: `_apply_world_click` deixa de passar a lista de pontos. O marcador de destino (anel + cruz), `marker`, `marker_valid` e seu ciclo (limpo por `indicate(null,false)` e por superfície oculta) permanecem iguais. A pré-visualização de mira de habilidade (`attack_preview`) e os anéis de objetivo/geômetra não usavam `route` e continuam. Nada em `battle_indicators.gd` foi preciso alterar.

**Evidência.** Captura depois: `move_marker_z100_t050.png` mostra só o anel com cruz, sem linha, mesmo passando uma rota de três pontos ao `indicate`. Antes: captura 1 do usuário.

## 2. Várias flechas no ataque básico do Arqueiro

**Causa (reproduzida no renderizador real, `tools/e08_p6_vfx_probe.gd aa_before`).** Dois desenhos de `feedback_vfx_layer.gd` na receita `basic_attack`: (a) o lançamento (`_muzzle`: halo + três traços curtos saindo da ponta, além da flecha em voo); (b) o acerto, que para elemento físico desenhava `_physical_sparks`: 6 a 9 raios laranja com ponta e halo, lidos como "flechas" saindo do alvo. A arte da flecha em voo (`world_projectile_art.gd`, `_arrow`) é uma só e não mudou.

**Mudança.**
- Receita ganha o campo `basic_hit` (`FeedbackRecipeCatalog.BASIC_HIT_SKILLS`: `basic_attack` de todas as classes e `enemy_claw`).
- `projectile_launch` de ataque básico não gera mais pulso (sem rajada de lançamento); a flecha única em voo permanece. Outras habilidades de projétil mantêm o lançamento.
- Acerto de ataque básico (todas as classes, corpo a corpo e à distância) desenha `_basic_hit_burst`: 6 raios brancos curtos (longos e curtos alternados), uma linha de corte e um ponto central, todos com contorno escuro de 1 px, vida 0,18 s, determinístico (semente do `event_id`), tamanho segue `zoom_boost()` (legível a 50%/160%), mesma camada z 4080 (abaixo de marcadores 4090 e da UI), dentro do CAP de 48 pulsos e do limite de impactos. Assinaturas e demais habilidades mantêm a arte própria.
- Swing do Espadachim (arco de corte) não foi alterado.

**Capturas (arquivos em `.godot/verification/p7/`).** Antes: `C5_terra_aa_path_probe_pb_run_1/probe/` (`aa_archer_*`, `aa_melee_*`; o `enemy_claw` nessas capturas já mostra o novo efeito, pois só `basic_attack` foi revertido). Depois: `C5_terra_aa_path_probe_pa_run_2/probe/`, em grama chapada e no chão do mapa, zoom 100 e 160, tempos 40/90/150 ms. Olhei `aa_archer_grass_z160_t040`, `aa_melee_grass_z160_t040`, `aa_archer_real_z100_t040` e `move_marker_z100_t050`: sem rajada na saída, estrela branca nítida no alvo (Arqueiro, Mago, Espadachim, garra), sem sobreposição com a UI.

## 3. Som do ataque básico

**Causa.** O acerto usava `p6.impact.physical` (centroide 713 Hz, 64% da energia abaixo de 400 Hz, corpo tonal de madeira: lê como tambor) e o lançamento `p6.projectile.physical`.

**Mudança** (referência numérica do coordenador; nenhum áudio externo foi usado ou copiado; síntese original):

| cue | uso |
|---|---|
| `p6.aa.hit_body` | acerto padrão: Arqueiro, Mago, `enemy_claw` |
| `p6.aa.hit_blunt` | acerto do Espadachim (mais médio-grave) |
| `p6.aa.hit_sharp` | acerto crítico de ataque básico (`payload.critical`) |
| `p6.aa.bow_release` | lançamento do ataque básico do Arqueiro (Mago mantém o lançamento arcano; golpe do Espadachim mantém o whoosh) |

Seleção: `AudioEventCatalog.candidates` prepende o cue AA quando a receita tem `basic_hit`; a cadeia termina nos cues antigos (família, tipo). `FeedbackRecipeCatalog.for_event` marca `critical`. Síntese em `tools/prepare_e08_p6_audio.py` (`python tools/prepare_e08_p6_audio.py aa` gera só os 4 WAVs; `aa_preview DIR` o clipe). PCM16 mono 44,1 kHz, `.import` com `compress/mode=0`, provenance e `recipes.md` atualizados. Os demais WAVs não mudaram.

**Medidas dos WAVs finais** (fração da energia por banda; alvos = perfil do coordenador):

| | duração | pico | -20 dB após pico | <150 | 150-400 | 400-1k | 1-2,5k | 2,5-6k | >6k | centroide |
|---|---|---|---|---|---|---|---|---|---|---|
| alvo padrão | 0,17-0,23 s | 15-50 ms | 110-150 ms | 4-12% | 5-8% | 4-7% | 22-35% | 35-50% | 7-13% | 2,5-3,4 kHz |
| `hit_body` | 0,20 s | 25 ms | 99 ms | 4,9% | 4,9% | 8,6% | 26,8% | 40,7% | 14,1% | 3,25 kHz |
| `hit_blunt` | 0,20 s | 12 ms | 85 ms | 8,8% | 11,4% | 12,0% | 28,7% | 30,2% | 8,9% | 2,5 kHz |
| alvo agudo/crítico | 0,4-0,45 s | - | 0,3-0,4 s | - | - | - | - | - | 34-39% | ~4,7 kHz |
| `hit_sharp` | 0,42 s | 15 ms | 304 ms | 0% | 0,2% | 2,5% | 20,3% | 44,5% | 32,6% | 5,1 kHz |
| alvo arco | <=0,12 s | - | - | 0 | 0 | ~0 | 1,5-5 kHz dominante | | | - |
| `bow_release` | 0,12 s | 3 ms | 87 ms | 0% | 0% | 0,8% | 17,8% | 68,4% | 12,9% | 4,0 kHz |
| antigo `impact_physical` | 0,32 s | 8 ms | 61 ms | 16,4% | 48,1% | 8,8% | 21,4% | 4,4% | 1,0% | 0,71 kHz |
| antigo `projectile_physical` | 0,26 s | 15 ms | 127 ms | 1,4% | 31,6% | 10,2% | 40,2% | 15,0% | 1,4% | 1,45 kHz |

Desvios: `hit_body` decai a -20 dB em 99 ms (alvo 110-150) e tem 8,6% em 400-1 kHz (alvo 4-7%); `hit_sharp` tem centroide 5,1 kHz (alvo ~4,7) e `>6k` 32,6% (alvo 34-39%); `hit_blunt` fica em 8,8% abaixo de 150 Hz (limite 15%). Medidas numéricas não substituem audição.

**Clipe de audição (antigo x novo, 3 tomadas cada, pequena variação):** `C:\Users\João Pedro\Documents\ChatGPT\RagRPG\.tools\map-editor-m5\.godot\verification\p7\C5_terra_aa_path_evidence\e08_p7_c5_aa_old_vs_new.wav` (19 s; rótulos e instantes em `e08_p7_c5_aa_old_vs_new_labels.json` ao lado). Ordem: acerto antigo, acerto novo, acerto do Espadachim, acerto crítico, lançamento antigo, soltura de arco nova.

## Arquivos

Ver `docs/epics/e08_p7_files.json` (pacote `C5_terra_aa_path`). Código: `expedition_geometry_view.gd`, `main.gd` (uma linha), `feedback_vfx_layer.gd`, `feedback_recipe_catalog.gd`, `audio_event_catalog.gd`. Ferramentas: `tools/prepare_e08_p6_audio.py`, `tools/e08_p6_vfx_probe.gd` (modos `aa`, `aa_before`). Dados: 4 WAV + `.import` em `assets/audio/e08/p6/`, `provenance.json`, `recipes.md`. Testes: `e08_feedback_vfx_test` (sem lançamento, rajada branca, rastro removido), `e08_feedback_recipe_test` (flag `basic_hit`, cadeias), `e08_audio_test` (seleção AA, formato e ruído dos 4 WAVs). Nenhum valor fixado existente foi alterado.

## Validação

Via `tools/e08_p7_fixture.ps1 -Package C5_terra_aa_path` (sync, import, probe, verify). Resultado da verificação: ver seção final abaixo.

### Resultado

`verify` (evidência `.godot/verification/p7/C5_terra_aa_path_verify_c5_verify_v3` e `..._v4`), todos passam: `e08_feedback_vfx_test` (485 checks), `e08_feedback_recipe_test` (1023), `e08_audio_test` (192), `e08_pilot_test` (350), `e08_pilot_ui_test` (55), `e08_presentation_test` (2246), `e07_f1_presentation_test` (39, marcador), `e07_f7_presentation_test` (27), `e07_f3_snapshot_test` (52), `e07_f3_continuation_test` (2743), `e07_f3_lifecycle_test` (90), `ui_layout_test` (30), `mage_gameplay_test` (52), `e04_archer_integrated_closure_test` (87), mais `e07_f7_flow_test` e `e07_f7_actions_test` (usam o marcador de clique). Importação dos 4 WAVs novos feita pelo estágio `import` do wrapper.

Limitações: sem audição humana (só números e o clipe); a suíte completa não foi repetida; o antes do rastro é a captura do usuário, não uma captura própria; mudança de `indicate` mantém assinatura de três argumentos por compatibilidade com fixtures.

## Rodada 2 (pacote `C7_terra_round2`, candidato `261801de`)

Somente apresentação; planejamento de caminho, movimento, rejeição de cliques e dano não foram tocados. Sem commit, push ou merge.

### 1. Rastro vermelho do destino impossível

**Causa.** Não era o caminho de movimento (já removido em C5). Era a linha de pré-visualização de mira de habilidade: `Main.spatial_pointer_skill` grava `expedition_view.attack_preview = {from, to, valid}` (de onde o jogador estava até o alvo) e `ExpeditionGeometryView._draw_effects` desenhava um segmento de 3 px (vermelho `ff807d` quando `valid` é falso). Nada limpava `attack_preview`, então a linha de uma mira rejeitada ficava no chão, longe do personagem, depois que ele se movia (captura 8 do usuário).

**Mudança.** `scripts/world/expedition_geometry_view.gd`: a linha deixou de ser desenhada e `indicate()` zera `attack_preview` (campo mantido inerte por compatibilidade com o manifesto de snapshot e a sonda P5). Resta só o marcador de destino (anel + cruz, vermelho se inválido), com o ciclo de vida de antes (`indicate(null,false)` e superfície oculta o limpam). `main.gd` e `battle_indicators.gd` não precisaram de mudança.

**Evidência.** Antes (`.godot/verification/p7/C7_before/r2_invalid_z100_t1500.png`): segmento vermelho do personagem ao alvo ainda visível 1,5 s depois. Depois (`C7_terra_round2_probe_c7_probe_after5/probe/r2_invalid_z100_t1500.png`): só o anel vermelho do marcador.

### 2. Acerto branco para todas as classes

**Causas.** (a) Todo acerto físico que não fosse ataque básico (`brutal_strike`, `double_shot`, `slash`, flechas do Sentinela, `hunter_exploit`, ids genéricos etc.) caía em `_physical_sparks`: a rajada de raios laranja (capturas "antes" `C7_before/r2_skills_*`). Era o que o usuário via nas demais classes. (b) O ataque básico de todas as classes e evoluções já usa o id `basic_attack` (`PlayerActor._try_basic_attack`; a evolução não muda o `class_id`, que segue `swordsman`/`mage`/`archer`), mas o `enemy_arrow` não estava marcado como `basic_hit` e os ids de evolução não tinham variante.

**Mudança.**
- `feedback_vfx_layer.gd`: novo campo `white_hit` do pulso = impacto cujo elemento é físico e que não tem assinatura própria, ou receita `basic_hit`. Usa `_basic_hit_burst` (6 raios brancos curtos, linha de corte, ponto central, contorno escuro) com vida `BASIC_HIT_LIFE`. Impactos de elemento (fogo, gelo, raio, arcano, espírito, natureza, geometria, sangue) e assinaturas mantêm a própria arte. `_physical_sparks` só ficou como último ramo do `match`, hoje inalcançável.
- `feedback_recipe_catalog.gd`: `BASIC_HIT_SKILLS` ganha `enemy_arrow`; `VARIANTS[basic_attack]` ganha as sete evoluções; `BASIC_ATTACK_OWNERS` lista as dez classes; `for_event` deriva `basic_attack` quando um impacto ou lançamento de uma classe do jogador chega sem `skill_id` (somente nesses dois tipos; inimigos e outros tipos não são derivados).
- `audio_event_catalog.gd`: listas por arma `MELEE_BASIC_VARIANTS` (swordsman, defender, berserker: `hit_blunt`) e `BOW_BASIC_VARIANTS` (archer, sentinel, hunter: `bow_release` no lançamento). Nenhum cue ou WAV mudou.

**Ids de ataque automático por classe** (todos `basic_attack`; variante = id da classe/evolução):

| classe | id | acerto | lançamento |
|---|---|---|---|
| swordsman, defender, berserker | `basic_attack` | branco + `p6.aa.hit_blunt` | (golpe corpo a corpo: whoosh inalterado) |
| mage, elementalist, spiritualist, mg_ar (geômetra) | `basic_attack` | branco + `p6.aa.hit_body` | sem rajada; cue de lançamento arcano da própria classe |
| archer, sentinel, hunter | `basic_attack` | branco + `p6.aa.hit_body` | sem rajada; `p6.aa.bow_release` |
| inimigo corpo a corpo | `enemy_claw` | branco + `hit_body` | |
| inimigo à distância | `enemy_arrow` | branco + `hit_body` | sem rajada |

Ids derivados de habilidades físicas (`brutal_strike`, `double_shot`, `slash`/`cone_slash`, `piercing_arrow`, `defender_riposte`, `sentinel_piercing_shot`, `hunter_exploit`, desconhecidos) usam a mesma explosão branca sem cue AA (mantêm o cue de impacto físico). A explosão de `sentinel_explosive_shot` e `mage_fireball` (assinaturas de fogo) e os impactos de fogo/gelo/raio/sangue/natureza seguem iguais.

### Capturas (renderizador real, `tools/e08_p6_vfx_probe.gd round2`)

Antes: `.godot/verification/p7/C7_before/`. Depois: `.godot/verification/p7/C7_terra_round2_probe_c7_probe_after5/probe/` (`r2_aa0..3_{grass,real}_z{100,160}_t{040,090,150}`: as dez classes, garra, flecha inimiga e id vazio, em lotes de três por causa do limite de impactos por janela; `r2_skills_*`: sete habilidades físicas + cinco de elemento para contraste; `r2_invalid_*`). Olhei: `r2_skills_grass_z160_t090` antes (raios laranja) e depois (estrelas brancas; fogo/gelo/raio/sangue/natureza intactos), `r2_skills_real_z100_t040` depois, `r2_aa0_grass_z100_t040`, `r2_aa1_real_z100_t040`, `r2_aa2_grass_z100_t040`, `r2_aa3_real_z160_t040` (estrela branca nítida, sem raios laranja, legível no chão do mapa e na grama, sem sobreposição com a UI) e `r2_invalid_z100_t1500` antes/depois.

### Testes

`e08_feedback_recipe_test`: as dez classes mapeiam para `basic_hit` com cue por arma, derivação de id vazio (impacto/lançamento) e não derivação para outros tipos e inimigos; `enemy_arrow` passou da lista "não é basic_hit" para a lista "é basic_hit" (pino alterado, comentado no teste). `e08_feedback_vfx_test`: acerto branco para as dez classes com `basic_attack` e id vazio, `enemy_arrow` (acerto branco, sem lançamento), habilidades físicas brancas sem raios, elementos com arte própria, destino inválido deixa só o marcador sem `attack_preview` e o ciclo do marcador termina com `indicate(null)`. Nenhuma verificação foi enfraquecida.

### Validação da Rodada 2

`tools/e08_p7_fixture.ps1 -Package C7_terra_round2` (sync, probe `round2`, verify; evidência `.godot/verification/p7/C7_terra_round2_verify_c7_verify3`), 14/14 passam: `e08_feedback_vfx_test` (523 checks), `e08_feedback_recipe_test` (1076), `e08_audio_test` (192), `e08_pilot_test` (350), `e08_pilot_ui_test` (55), `e08_presentation_test` (2246), `e07_f1_presentation_test` (39), `e07_f7_presentation_test` (27), `e07_f7_flow_test` (23), `e07_f7_actions_test` (28), `e07_f3_snapshot_test` (52), `e07_f3_lifecycle_test` (90), `ui_layout_test` (30), `mage_gameplay_test` (52). Um pino de `e08_feedback_vfx_test` (seleção por receita lançava `projectile_launch` para `enemy_arrow`) foi ajustado para usar o impacto, porque o lançamento do ataque básico não tem rajada desde C5; comentado no teste.

Limitações: a linha de mira de habilidade deixou de aparecer também quando válida (era a mesma desenho); sem audição humana nova (nenhum áudio mudou); a suíte completa não foi repetida; as capturas de classe usam eventos confirmados sintéticos (como as de C5), não combate real de cada evolução.
