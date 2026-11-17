# E12 H2 — estado de HUD dos quatro kits (C4): recibo

Contrato: [e12_contract.md](../e12_contract.md) §5. API da costura: [h1_hud_seam_api.md](h1_hud_seam_api.md).
Índice: [e12.md](../e12.md).

## Base e checkout

- **Papel:** Sol (Claude Opus 5.5), sessão de tarefa despachada pela sessão de arquitetura do E12.
- **Base:** ponta da H1, `03c2c2db31010b4471e33fe40984d894c21cf5ee` (`claude/e12-h1-708c9b`).
- **Branch:** `claude/e12-h2-e4e790`.
- **Checkout:** `C:\Users\João Pedro\Documents\ChatGPT\RagRPG\.claude\worktrees\e12-h2-e4e790`.
- **Commit entregue:** o commit `feat(e12-h2)` desta branch; o SHA fica no commit de registro
  seguinte (`docs(e12-h2)`), como na H1.

## O que mudou

Nenhuma regra, fórmula, custo, recarga, sinal de gameplay ou campo de snapshot mudou. Nenhum
`snapshot_manifest.json` foi tocado (campos e revisões iguais; A5). Arquivos:

| Arquivo | Mudança |
|---|---|
| `scripts/systems/sanctuary/sanctuary_authority.gd` | `describe()` ganhou só chaves (`unlimited_remaining`, `aegis_capacity`, `seal_key`); as existentes não mudaram. Novos leitores puros: `hud_grace(unlimited_total)`, `hud_zones(player)`, `hud_aegis(id, total)`, `hud_seal_mark()` e a constante `HUD_LIGHT` (`&"light"`). |
| `scripts/systems/flank/flank_authority.gd` | Novo `describe(player)` (leitura): `victim_id`, `victim_serial`, `sentence`, `sentence_cap`, `concealment_armed`, `concealment_active`, `concealment_remaining`, `opening_remaining`, `parry_open`, `parry_remaining`, `parry_charges`. Novo `peek_victim(player)`: mesma resposta de `victim()` **sem** escrever a dica `_victim_hint`. Novo `static hud_victim_mark(described)`. |
| `scripts/classes/{sp_ac,mg_ac,sp_la,mg_la}/*_kit.gd` | `hud_state(player)` e o auxiliar `_hud_readiness(answer)`. A prontidão de cada skill listada é a resposta do próprio `can_cast` do kit (A6 por construção; a prova abaixo compara com o descritor real do jogador). |
| `tests/classes/<id>/<id>_hud_test.gd` (4 novos) | Provas de §5 (seção Testes). |

Pureza: `hud_state` não escreve em nenhum campo, nem em cache omitido do snapshot. Por isso o
Duelista e a Lâmina leem a vítima por `peek_victim` (sem tocar `_victim_hint`). A busca de
vítima, quando a dica não serve, percorre só os irmãos do jogador (o mesmo `_candidates` de
`victim()`), nunca a árvore inteira. A Lâmina percorre os irmãos para os reflexos só com
`specter_pending > 0`.

## Lista final por kit

Recursos marcados "sempre" estão em todo DTO. Os outros só aparecem enquanto o estado existe.
Prazos (`timer`) levam `remaining` da autoridade e `total` da ficha, nunca menor que `remaining`.

### Paladino `sp_ac`

| Seção | Entradas |
|---|---|
| `resources` | `sanctuary_grace` "Graça" (`pips`, `value = grace.charges`, `max = grace.cap`, `light`; sempre). Na Hora: `unlimited`, `remaining = grace.unlimited_remaining`, `total = HOUR_DURATION[rank]`. `paladin_oath` "Juramento" (`timer`, prazo da zona `oath`). `paladin_aegis` "Égide" (`timer`, `aegis_remaining` / 6 s). `paladin_hour` "Hora do Juramento" (`timer`, `hour_remaining` / `HOUR_DURATION[rank]`). |
| `skills` | `paladin_oath`: `ready = false`, `reason = paladin_hour_active` na Hora. |
| `zones` | Zona `oath`: cone (`half_angle` 55°, `facing` do Paladino) ou círculo na Hora; centro no Paladino; elemento da zona (`none`). |
| `target_marks` | `paladin_seal` (`badge`, `light`) sobre o inimigo selado vivo. |

### Taumaturgo `mg_ac`

| Seção | Entradas |
|---|---|
| `resources` | `sanctuary_grace` (sempre; ∞ com prazo da Aurora, `total = DAWN_DURATION[rank]`). `thaumaturge_votive_circle` "Círculo Votivo" (`timer`, prazo da zona `votive`, **`element` = elemento atual da zona**: `none`, `fire`, `ice`, `lightning` ou `tricolor`; fecha a limitação 1 da K2). `thaumaturge_elemental_choir` "Coro Elemental" (`timer`, `tricolor`). `thaumaturge_convergent_dawn` "Aurora Convergente" (`timer`, `light`). |
| `skills` | `thaumaturge_votive_circle`: `thaumaturge_dawn_active` na Aurora. `thaumaturge_altar_shift`: `thaumaturge_no_circle` sem círculo. |
| `zones` | Zona `votive`: círculo ou círculo ampliado na Aurora, no ponto ancorado, com o elemento atual da zona (sem `facing`). |
| `target_marks` | — (chave ausente). |

### Duelista `sp_la`

| Seção | Entradas |
|---|---|
| `resources` | `duelist_duel` "Duelo" (`timer`, `duel_remaining` / `DUEL_DURATION[rank]`). `duelist_auto_parry` "Aparo automático" (`timer`, / 8 s). `duelist_patient_guard` "Guarda Paciente" (`pips` 1/1, só quando pronta). Fora disso, `resources` fica vazio. |
| `skills` | `duelist_parry`: `duelist_duel_active` no Duelo. |
| `zones` | — (chave ausente). |
| `target_marks` | `flank_victim` (`pips`, `value` = Sentença da marca, `max` = 5) sobre a vítima viva. |

### Lâmina Arcana `mg_la`

| Seção | Entradas |
|---|---|
| `resources` | `arcane_blade_refraction` "Refração" (`charges`, `value = refraction_charges`, `max` = 1, `arcane`; sempre). Durante a recarga própria: `remaining = refraction_recharge`, `total = REFRACTION_RECHARGE[rank]`. `flank_concealment` "Ocultação" (`timer`, `concealment_remaining` / `REFRACTION_DURATION[rank]`, `arcane`). |
| `skills` | `arcane_blade_refraction`: `ready`, `reason` do `can_cast` (`arcane_blade_already_concealed` primeiro, depois `arcane_blade_refraction_recharging`, na ordem do kit), `charges`, `max_charges`, e `recharge_remaining`/`recharge_total` durante a recarga. Fecha a limitação 1 da K4. |
| `zones` | — (chave ausente). |
| `target_marks` | `flank_victim` (`pips` 0..5) na vítima viva. `arcane_blade_specter` (`badge`, elemento do reflexo) sobre cada inimigo vivo com reflexo pendente do Espectro atual. |

Observação sobre a Refração: o contrato pede `reason = arcane_blade_refraction_recharging`. Esse é
o código quando falta carga. Enquanto a Lâmina está oculta, `can_cast` recusa antes com
`arcane_blade_already_concealed`, e a A6 exige o mesmo código. O DTO segue o `can_cast`.

## Testes

Cada `*_hud_test.gd` roda o combate integrado da revisão do kit: as duas builds de
`review_builds.json`, o chefe real `forest_ancient_warden` e a rotação do `*_boss_combat_test`
correspondente. Em **todo tick**, o teste confere:

- `KitHudState.validate` aceita o DTO. `player.kit_hud_state()` devolve o mesmo dicionário.
- **A6.** Para toda skill em `skills`, `ready == false` se e só se
  `kit.can_cast(player, player._kit_cast_legacy(skill, ...))` recusa, com o mesmo `reason`.
  O descritor é o mesmo que o caminho plano real envia. O conjunto de skills listado é fixo.
- **Pureza.** Um percurso recursivo de **todas** as variáveis de script do grafo do kit
  (autoridade, zonas, Graça, protótipos, caches omitidos) é igual antes e depois de `hud_state`.
  É mais estrito que o fragmento de snapshot.
- Graça igual a `grace.charges`, `cap`, `is_unlimited()` e `unlimited_remaining`. Sentença igual
  ao `sentence` da marca `flank_victim` e a `flank.sentence()`. Zonas, prazos, Selo, ocultação,
  recarga e reflexos iguais às autoridades e ao kit.
- Só alvos vivos em `target_marks` (A7). Nenhum aviso de DTO inválido no processo.

Por kit, o teste também cobre:

- **Pausa** aos 8 s: com a árvore pausada, 20 `_process` e leituras deixam DTO e grafo intactos.
- **Morte e retorno:** morte certa e DTO válido que segue a autoridade (Graça 0 sem ∞, sem
  zona, sem marca, sem prazo; a carga da Refração mantida). Depois, retorno por
  `health.reset` e `_process` (`on_return`), DTO válido de novo e o combate continua checado.
- **Snapshot exato:** `SnapshotRegistry.capture` de um estado rico, antes e depois de 100
  leituras, com `var_to_bytes` idêntico (limitação 3 da H1).
- **A6 no caminho real:** com SP e sem recarga canônica, `use_kit_skill` recusa o Aparo (Duelo)
  e a Refração (sem carga), que o DTO diz não prontos.
- **Mundo** (só `sp_ac` e `mg_ac`, com o F1): o cone do Juramento tem `space = world`, centro no
  ponto de chão do dono e `facing` no chão (`y = 0`). O círculo da Hora não tem `half_angle`.
  O Círculo Votivo fica sobre a âncora de chão (`area.anchor().position`).
- Também exige que cada recusa apareça em combate: `paladin_hour_active`,
  `thaumaturge_no_circle`, `thaumaturge_dawn_active`, `duelist_duel_active`,
  `arcane_blade_already_concealed` e `arcane_blade_refraction_recharging`.

Resultados: `sp_ac_hud_test` 57 checks; `mg_ac_hud_test` 60; `sp_la_hud_test` 49;
`mg_la_hud_test` 53. Todos com 0 falhas.

## Validação

Motor: Godot 4.7.2 standard,
`C:\Users\João Pedro\Documents\ChatGPT\RagRPG\.tools\godot\Godot_v4.7.2-stable_win64.exe`.

1. **Importação.** A primeira rodada (`.godot/verification/e12_h2_import/`) falhou só por
   `ERROR: Cannot get class 'GitPlugin'`. A GDExtension do plugin de VCS ainda não estava listada
   no worktree novo. A segunda rodada passou: `editor_import` e `e07_f1_import_test`, em
   `.godot/verification/e12_h2_import2/`. `checks.jsonl` sha256
   `451645f7a22d83e4643b0be5374429cbc85f92d0c5618f7673ea24b2378a98fe`.
2. **Erros dos próprios testes novos.** Inferência de `Variant` tratada como erro. Corrigido com
   tipo explícito. Depois de editar um teste que usa o F1, é preciso refazer
   `e07_f1_import_test`, porque a fixture fixa os hashes dos consumidores. Rodada
   `.godot/verification/e12_h2_f1b/`: PASS, sha256
   `0a59c972767b74fe5e4a1384587442ce362507cf56f4ef83c971a6843113e1cf`.
3. **Regressão por impacto.** Rodada em `.godot/verification/e12_h2_impact/`, sem mudar nenhuma
   expectativa:

   ```
   tools/verify.ps1 -GodotPath <godot> -SkipEditorImport -F1Fixture -CheckTimeoutSeconds 300 `
     -VerificationDirectory .godot/verification/e12_h2_impact `
     -Test hud_seam_test,kit_seam_test,kit_seam_hooks_v2_test,kit_seam_hooks_v3_test,
           ui_evolution_test,flank_test,sanctuary_test,sp_ac_*,mg_ac_*,sp_la_*,mg_la_*,
           e07_f3_snapshot_test,e07_f6_snapshot_test,e08_compact_checkpoint_test,
           e08_compact_coverage_test
   ```

   Resultado: **"Selected checks passed (25/352 steps)"**. Exit 0 em todas as etapas, nenhum
   timeout, nenhuma linha `SCRIPT ERROR`. `checks.jsonl` sha256
   `80dc9b0d828e98f35dc91a826a94e4e93d97ae06f7509164f9cee941cb639f79`.

| Índice | Etapa | Checks | sha256 da saída (16 primeiros) |
|---|---|---|---|
| 270 | `e07_f6_snapshot_test` | 40 | `2e091952f53115a7` |
| 282 | `e08_compact_checkpoint_test` | 48 | `346b73697bfb3c19` |
| 283 | `e08_compact_coverage_test` | 95 | `3c65add205f98f2d` |
| 294 | `e07_f3_snapshot_test` | 52 | `9fc703c4ab2986dd` |
| 331 | `kit_seam_hooks_v2_test` | 38 | `5182f32b62de14be` |
| 332 | `kit_seam_hooks_v3_test` | 63 | `d1dfd323c350f8f6` |
| 333 | `kit_seam_test` | 268 | `ed82d9547ea52435` |
| 334 | `ui_evolution_test` | 97 | `df7b1619f114033b` |
| 335 | `flank_test` | 205 | `d23dc5d7b03b0fe0` |
| 336 | `sanctuary_test` | 155 | `01b74920641522d9` |
| 337 | `mg_ac_boss_combat_test` | 29 | `66ac49c680cb0d1b` |
| 338 | `mg_ac_hud_test` (novo) | 60 | `000bb13b9b857a3c` |
| 339 | `mg_ac_kit_test` | 177 | `814d744c0a070565` |
| 340 | `mg_la_boss_combat_test` | 33 | `6710c89ec58026ec` |
| 341 | `mg_la_hud_test` (novo) | 53 | `13cb6b25c90c9834` |
| 342 | `mg_la_kit_test` | 231 | `b480859d5403b1e8` |
| 343 | `mg_la_world_leap_test` | 49 | `f2e59ee4f7352d9c` |
| 344 | `sp_ac_boss_combat_test` | 25 | `269571175ce4e29b` |
| 345 | `sp_ac_hud_test` (novo) | 57 | `11a7268ded50108a` |
| 346 | `sp_ac_kit_test` | 170 | `2229f2dcd6dd2b0f` |
| 347 | `sp_la_boss_combat_test` | 31 | `4f9c0f3fb7b9919f` |
| 348 | `sp_la_hud_test` (novo) | 49 | `d74b43a78b597682` |
| 349 | `sp_la_kit_test` | 217 | `d2dc91b266e2e5a5` |
| 350 | `sp_la_parry_ai_test` | 55 | `4f0c254bd31c88e4` |
| 351 | `hud_seam_test` | 188 | `319b453dd0b59fef` |

As saídas de `kit_seam_*`, `ui_evolution_test`, `flank_test` e dos testes de snapshot têm o
mesmo hash da rodada de impacto da H1. O `hud_seam_test` agora registra, no log de base, as
chaves dos DTOs dos quatro kits de produção. Os avisos `KitHudState` no log dele vêm das
variantes inválidas do kit de fixture, como na H1.

Os `.import` de arte reescritos pela importação no worktree e os `.uid` de evidências de outras
pastas não entram no commit. Entram só os arquivos acima e os `.uid` dos quatro testes novos.

## Limitações

1. **Prazos com total da ficha.** O `total` de Hora, Aurora, Coro, Duelo, ocultação e
   recarga da Refração sai da ficha pelo rank atual, porque as autoridades não guardam o total.
   Se o rank mudar no meio do prazo, o total mostrado vira `max(ficha, remaining)`. Para a
   Égide, o total é a duração fixa do kit (6 s).
2. **Skills listadas.** Entram só as recusas de `can_cast` que não dependem de alvo:
   `paladin_oath`, `thaumaturge_votive_circle`, `thaumaturge_altar_shift`, `duelist_parry` e
   `arcane_blade_refraction`. As recusas do Salto e do Espectro dependem do alvo ou da geometria
   e ficam fora de `skills`, e a A6 vale para o que está listado. Sem SP e recarga canônica
   continuam sendo lidos da autoridade atual (contrato §2.2).
3. **Reflexos do Espectro em combate.** No combate integrado o reflexo pendente dura um tick,
   então o contador de ticks com reflexo deu 0. O badge é provado no estado rico do snapshot
   exato da `mg_la` (reflexo pendente, `badge` presente e válido).
4. **Aparo automático em combate.** Contra o chefe, a Riposta nunca executa
   (A4: chefe sem morte certa), então o prazo do aparo automático não aparece em combate. O teste
   do snapshot exato do `sp_la` cobre a entrada.
5. **Mundo.** A geometria das zonas no mundo foi provada com cast resolvido diretamente pelo kit
   (`resolve_cast`) no F1. O caminho de cast de mundo do jogador continua coberto pelos testes do
   E09 e da H1. Duelista e Lâmina não desenham zona, e suas marcas não dependem do espaço.
6. **Morte do teste.** Para Duelista e Lâmina, a morte é aplicada direto no `HealthState`, porque
   uma janela de aparo aberta cancelaria o golpe. O kit recebe a morte normalmente por `on_death`.

## Próximo passo

H4 (ligação no HUD) pode consumir `player.kit_hud_state()` dos quatro kits: base = esta branch
com o merge da H3. Para o atalho, `skills[id].ready == false` traz o `reason` do kit (traduzir em
pt-BR) e, na Refração, `charges` e a recarga própria.
