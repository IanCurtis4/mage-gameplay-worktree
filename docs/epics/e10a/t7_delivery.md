# E10a T7 — recibo: kit do Cultista (`cultist`, C3 e §4.3)

Executor: Sol (Opus 5.5, esforço médio), 18/11/2026. Contrato curto: [t7_contract.md](t7_contract.md).

## Base e checkout

- **Worktree:** `.claude/worktrees/laughing-mclean-ff1bbd`, nascida de `master` = `7795f56d`.
- **Base:** `git merge --ff-only e35525c7` até a ponta da T4 (branch
  `claude/wizardly-hermann-10d51a`), que já contém a T1 (`c8771d20`). Sem a T6.
- **Branch:** `claude/laughing-mclean-ff1bbd`. O commit entregue é o que introduz este recibo.
- **Contratos lidos** em `claude/e10a-arquitetura-a413a1` por `git show`, sem merge dessa branch.

## O que foi entregue

- **`scripts/classes/cultist/cultist_kit.gd`** substitui o esqueleto da T1. Tem as 7 skills, todas
  com elemento `shadow`, textos pt-BR com tooltip por rank, 9 efeitos desenhados em código, os
  ganchos e o estado da run. `ready_for_play = true`.
- **`snapshot_manifest.json`**, revisão 2, com 18 campos.
- **`review_builds.json`** com as builds Profeta e Vidente. As duas são legais com 19 + 20
  pontos (mais o R1 grátis do Olhar).
- **`scripts/classes/cultist/fixture/cultist_fixture_base.gd`**, com fragmento próprio: base de
  teste que substitui a base Acólito da T5 enquanto ela não está no ramo.
  - Guarda a `MadnessAuthority` no campo `madness` e repassa os ganchos como a API da T4 pede
    ao criador.
  - Selo Sombrio e Sussurro dão Loucura, Prece cura e Escudo Votivo dá escudo.
  - Nunca entra no registro.
- **O Cultista não cria autoridade.** Ele a lê da origem a cada uso e é o único que repassa os
  três ganchos do Êxtase.

## Testes (`tests/classes/cultist/`)

| Teste | O que prova |
|---|---|
| `cultist_kit_test` (215 checks) | Catálogo e prontidão; regra A7 (sem `class_name`, sem `EnemyActor`, sem campo `madness`); builds legais; autoridade única da origem; cone e tiques do Olhar com Loucura uma vez por evento, interrompido por movimento ou outra skill; Êxtase repassado uma vez (custo −5%/carga, +15% ATQ mágico, ônus ×1,08 com 3 cargas, teto 5 ×1,24, sem ônus abaixo de 3), compensado por Escudo Votivo e Prece; Ídolo 1 por dono, comuns o miram e o chefe não; contágio de um salto e pulso; teto 3 de Delírio, delirante nunca mira o jogador nem o chefe; Pupila ×1,20 com filtro de dono; Geometria (comum desorientado uma vez por figura, chefe só lento); Revelação (Desorientação forte sob imunidade, imunidade de 26 s, uma vez por Revelação, 60% dos golpes no lacaio, delirantes ×1,60); Selo e Sussurro somam com o Olhar; abate por Delírio creditado uma vez; morte e pausa; snapshot exato e compacto |
| `cultist_boss_combat_test` (50 checks) | 30 s contra o Guardião Antigo sem adds, uma luta por build. Depois, a Profeta contra o Guardião com o companheiro invocado pela IA dele e criado por `RunController._on_companion_requested`. O chefe tem duas janelas e imunidade, nunca troca de alvo e nunca entra em Delírio. Com o companheiro, 5 golpes do chefe caem no lacaio |
| `cultist_campaign_kill_test` (20 checks, A7.7) | Expedição real da F7 instalada na árvore. Um lobo em Delírio mata um mob normal da campanha com a autoria do Cultista. O crédito é único e o retry do golpe não credita de novo. O abate gera um evento de morte, o journal pelo `ExpeditionService` gera um ticket, e o replay e a repetição não geram outro. A coleta soma +10 de XP base uma vez, e a segunda coleta não soma nada |

Na luta, o dano de sombra do Olhar soma ~3 mil por luta, e o ataque básico da base de teste
continua sendo a maior fonte de dano. Isso é só registro, sem certificação de balanceamento.

## Validação

- **Engine:** `Godot_v4.7.2-stable_win64.exe` (`4.7.2.stable.official.ed1daf0bf`).
- **Preparação:**
  - `editor_import` duas vezes;
  - a primeira passada esgotou os 120 s e foi repetida com `-CheckTimeoutSeconds 300`;
  - `e07_f1_import_test` passou com 3520 arquivos idênticos e foi repetido depois de cada
    edição de fonte, porque o fixture F1 fixa os hashes.
- **Leva final:** `tools/verify.ps1 -SkipEditorImport -F1Fixture`, 23 de 23 passos, em
  `.godot/verification_t7c/`.
- **Logs:** nenhum tem `SCRIPT ERROR`, `resources still in use` nem `ObjectDB instances leaked`.

| Passo | Teste | Checks | SHA-256 da saída (16) |
|---|---|---|---|
| 26 | `e08_feedback_recipe_test` | 1309 PASS | `AA05DF9D217F6F82` |
| 108 | `e05_evolution_catalog_test` | 93 PASS | `6B7F3B5BBE61238B` |
| 331 | `kit_seam_hooks_v2_test` | 38/38 | `5182F32B62DE14BE` |
| 332 | `kit_seam_hooks_v3_test` | 63/63 | `D1DFD323C350F8F6` |
| 333 | `kit_seam_test` | 276/276 | `60643509690EB7E2` |
| 335 | `base_seam_test` | 171/171 | `83E3C22E78D21A6C` |
| 336 | `enemy_target_test` | 88/88 | `61C1F89F787761EA` |
| 337 | `flank_test` | 205/205 | `D23DC5D7B03B0FE0` |
| 338 | `madness_test` | 276/276 | `D4DAEAF51B039B14` |
| 339 | `sanctuary_test` | 155/155 | `01B74920641522D9` |
| 340 | **`cultist_boss_combat_test`** | 50/50 | `4DFDDBDF787F75B7` |
| 341 | **`cultist_campaign_kill_test`** | 20/20 | `212B00D3EAEF50D1` |
| 342 | **`cultist_kit_test`** | 215/215 | `215686C41CEFCF87` |
| 343–352 | kits do E09: `mg_ac` (29, 177), `mg_la` (33, 231, 49), `sp_ac` (25, 170), `sp_la` (31, 217, 55) | 0 falhas | `66AC49C6…`, `814D744C…`, `6710C89E…`, `B480859D…`, `F2E59EE4…`, `26957117…`, `2229F2DC…`, `4F9C0F3F…`, `D2DC91B2…`, `4F0C254B…` |

A suíte completa não foi rodada (fora do pedido; fica para a T13).

## Contas da A9 e da A10 (ramo com a T4 e sem a T6)

| Arquivo | Ajuste | Número neste ramo |
|---|---|---|
| `tests/e08_feedback_recipe_test.gd` | contagem de kits prontos `4 → 5` (E09 + Cultista); em `_expected_kit_skills()`, o filtro da T6 (`a2137f69`) que ignora kits puros cuja base não está disponível (A10.2) | prontos **5**; skills publicadas **20/8**, sem mudança, porque o Acólito é esqueleto |
| `tests/e10a/base_seam_test.gd` | check de esqueleto (l. 123): o `cultist` valida, está pronto e tem 7 skills, e o `priest` continua esqueleto. No bloco da fixture (l. 234–235): com o Cultista de produção pronto, as evoluções do Acólito são `priest` (fixture, 2-1) e `cultist` (2-2), na ordem do registro. Esse segundo ajuste é a mesma classe de check de esqueleto da A9, aplicado por mim e registrado aqui | 2 evoluções |
| `tests/e05_evolution_catalog_test.gd` | `&"cultist": ["Cultista", &"acolyte", &"2-2", &""]` no `KIT_METADATA` (A10.1) e, em `_ready_kit_ids()`, a linha de filtro da base indisponível (A10, item 4, `71674fe9`) | roteiro com 12 + 4 |

**Soma para a T13:** com a T6, os prontos ficam **6** (E09 + Sacerdote + Cultista). No
`base_seam_test`, os dois kits puros ficam prontos. Com a T5, o 20/8 sobe e o Acólito passa a
oferecer as duas evoluções reais. O bloco da fixture da linha 234 deve conflitar com a T6; a T13
compõe as duas versões.

## IDs de flipbook reservados

`cultist_abyss_gaze_cone`, `cultist_abyss_gaze_hit`, `cultist_impossible_idol` (o corpo do Ídolo
é o desenhador `madness_idol` da T4), `cultist_shared_delirium_mark`,
`cultist_shared_delirium_spread`, `cultist_impossible_geometry`,
`cultist_impossible_geometry_slip`, `cultist_revelation_eye`, `cultist_revelation_gaze`.

## Arquivos editados

- **Novos:**
  - `docs/epics/e10a/t7_contract.md` e `t7_delivery.md`;
  - `scripts/classes/cultist/review_builds.json`;
  - `scripts/classes/cultist/fixture/cultist_fixture_base.gd`, com `.uid` e `snapshot_manifest.json`;
  - `tests/classes/cultist/cultist_kit_test.gd`, `cultist_boss_combat_test.gd` e
    `cultist_campaign_kill_test.gd`, com os `.uid`.
- **Alterados:**
  - `scripts/classes/cultist/cultist_kit.gd` e `snapshot_manifest.json`;
  - os três testes da tabela A9/A10, só nos checks citados.
- **Fora do commit:** os ~1988 `.import` reescritos pela importação e os `.gd.uid` de
  `docs/map_editor/**`.

## Limitações

1. **Base de teste, não a T5.** Os testes do Cultista rodam sobre a base de teste.
   - O teste de luta usa a base de produção quando ela está pronta e tem `madness`, então a T13
     o roda sobre a T5 sem editar nada.
   - O teste de invariantes e o de campanha instalam sempre a base de teste.
   - A integração real com o Sussurro, o Selo, a Prece e o Escudo da T5 só se prova na composição.
   - As builds usam os pré-requisitos propostos no §1; se a T5 mudar algum, `review_builds.json`
     pode precisar de ajuste.
2. **Canalização.** A costura não tem um estado de canal: o Olhar é um relógio do kit.
   - Mover mais de 24 ou confirmar outra skill (do kit ou da base) interrompe o canal.
   - O ataque básico não interrompe, e o jogador não fica impedido de andar.
   - Os tiques depois do primeiro são secundários do mesmo protótipo (raiz causal do cast).
3. **Figura da Geometria e olho da Revelação** só aparecem no efeito do commit
   (`effect_start`). Não há nó persistente desenhado durante os 4–7 s. Ambos bloqueiam o
   formato compacto.
4. **Prova de campanha.** Os módulos foram ligados diretamente num personagem Mago da fixture
   F2, e o lobo em Delírio foi criado ao lado da vítima, fora da população da campanha. Ele é
   removido antes do journal. A coleta exigiu o fim do combate (`combat_participation`, 5 s),
   como no jogo.
5. **Pupila e Revelação** valem também nos golpes entre delirantes, porque o golpe relayado tem
   `source_id` = dono (T1). Isso é intencional e está no contrato.
6. A suíte completa não foi rodada.

## Próximo passo

A T13 compõe esta branch com a T5 e a T6, soma as contagens acima, roda a suíte completa e roda
os três testes do Cultista sobre a base real da T5. A T11 (augments) pode usar os IDs e os números
do contrato.
