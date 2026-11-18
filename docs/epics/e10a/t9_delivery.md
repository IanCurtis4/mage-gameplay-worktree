# E10a T9 — itens da família Acólito (contrato C6)

Papel: Terra (Claude Sonnet 5.5, esforço médio). Data: 18/11/2026. Estado proposto: **ENTREGUE**,
com uma falha pré-existente fora do escopo (`base_seam_test`, abaixo).
Branch `claude/musing-austin-58a118`, checkout `.claude/worktrees/musing-austin-58a118`. Sem push, nada em `master`.

## Base

`git merge --ff-only claude/e10a-candidato` levou a worktree de `7795f56d` a `58c0ea90` (T1, T2, T3, T4, T5, T6, T7).
`git log -1` na base: `58c0ea906183d6bddc5dfaf47363d33bf1f4c52c`. A branch de arquitetura não foi mesclada;
as decisões A12 e A13 vieram por mensagem da sessão de arquitetura.

## Decisão A13 (arquitetura, 18/11)

1. Posse de `scripts/core/build_effect_catalog.gd` só para trocar o literal de `_restrictions_valid`.
   Antes, linha 204: `if origin not in [&"swordsman", &"mage", &"archer"] or seen.has(origin):`.
   Depois: `if not IdentityIds.is_base_class(origin) or seen.has(origin):`.
   Sem esta troca o catálogo recusa `acolyte` como origem com `invalid_restrictions`.
   O teste de duplicata fica. Nenhum `class_name` do par ator é nomeado (A7).
2. Isenção do `prayer_book` do filtro de iniciais do loot (`STARTER_DROPS`): o livro é inicial e também cai.
3. As peças gerais são **9** (`shared_set_{low,mid,high}_{head,torso,feet}`), não 6. Não têm
   `allowed_origins` nem `allowed_identities`, então já aceitam a família; ficam sem mudança.

## IDs, nomes e regras

Três itens normais, sem conjunto, só stat (ataque mágico +2), 1 encaixe, `origin_id demo_arena`,
`main_hand` / `weapon` / `one_hand`, origem `acolyte`, `allowed_identities` `acolyte, priest, cultist`
(típico do Sacerdote e do Cultista é uso, não restrição). O ID de definição é o ID de arte.

| ID | Nome pt-BR | Qualidade | Faixa | Uso | Arquivo |
|---|---|---|---|---|---|
| `prayer_book` | Livro de Orações do Noviço | comum | 2–5 | **inicial do Acólito** (`starter = true`) e cai no loot | `e10a_prayer_book.tres` |
| `halo_scepter` | Cetro do Halo Dourado | rara | 6–10 | típico do Sacerdote | `e10a_halo_scepter.tres` |
| `eye_reliquary` | Relicário do Olho Atento | rara | 6–10 | típico do Cultista | `e10a_eye_reliquary.tres` |

## Arte e proveniência

- Fonte: `assets/art/e08_codex_1118/equipment/weapons_b1.png` (SHA256 `a4a088a4…fdfa`, versionada pela T2, sem `.import`).
  Conferência visual da folha: objeto 1 livro claro com sol e lua, 2 cetro com aro, 3 relicário com olho.
- Pipeline neutro, mesmo método da E09: `assets/art/e10a_equipment/prepare_e10a_equipment.py` (n-ésima faixa de colunas com alfa > 16;
  limpeza do véu de alfa ≤ 16, LANCZOS, margem de 2 px, sangria de cor). `manifest.json` guarda hashes e passos.
- Props (px nativos, lógico ×4): `prayer_book` 80×120, `halo_scepter` 60×168, `eye_reliquary` 56×152.
  Ícones 128×128, lado maior 118, em `assets/art/icons/equipment/painted/<id>.png` (a convenção de `EquipmentPresentation.painted_icon`;
  o escopo da tarefa citava `icons/equipment/<id>*`, a pasta `painted/` é a da convenção do E09).

| Arquivo | SHA256 |
|---|---|
| `props/prayer_book.png` | `5a9b433e9f48fa5c6fe5cb8a1a331d9d11083daad9e947c38f70eb7cd01de84e` |
| `props/halo_scepter.png` | `69da120c4169e480c9237a73fecb787c8ffc412a8fda17c4b6888c0c01a5d6ff` |
| `props/eye_reliquary.png` | `7c46ce27f74c194f5bbfe8b018858970c78aedd0281f711bfcd14f7fec1071b1` |
| `painted/prayer_book.png` | `350288bbd8412a68725f3288e17c3d3c619071a4986941b332c09fe1100afe3a` |
| `painted/halo_scepter.png` | `3f8d600859b5cb359558bc9e7a5c4b923fc5e7a0a0b1ae3881f23a860b960402` |
| `painted/eye_reliquary.png` | `6e0506c29629e8dee90a172aaf819dc6c428c307ddb2c489e2ce24a3f62d2f12` |

## Grips e perfis (provisórios, para a T8 calibrar as mãos, A12)

Seção `props` de `assets/art/equipment/hand_rigs.json` e `PROFILES` de `equipment_attachment_visual.gd` (só as três chaves em
`SUPPORTED` e `PROFILES`): `prayer_book` 20×30 grip (10,18) ângulo 0; `halo_scepter` 15×42 grip (7,5; 33) ângulo 0,2;
`eye_reliquary` 14×38 grip (7,7) ângulo 0 (pela corrente). O leitor é o `EquipmentArtCatalog.e09_prop_profile/_texture`,
agora aceitando também `E10A_PROP_IDS` (`e10a_prop_ids()`); `e09_prop_ids()` segue com 4.

## Armaduras (D9)

`class_set_mage_{head,torso,feet}.tres`: `allowed_origins` (item e efeito) de `[mage]` para `[mage, acolyte]`, e
`allowed_identities` acrescido de `acolyte, priest, cultist`. Nenhuma outra propriedade mudou. As peças dos outros
conjuntos (`elementalist`, `spiritualist`, `mg_ar`) são de identidade específica e ficam como estão.

## Loot

`equipment_loot_profiles.gd`: `STARTER_DROPS = [&"prayer_book"]` isenta o livro do filtro de iniciais. Os iniciais legados
(`starter_blade`, `starter_staff`, `starter_bow`) seguem fora, provado no teste.

## Ajustes em testes legados (A15), cada um registrado

| Teste | Antes → depois |
|---|---|
| `e06_expanded_equipment_content_test.gd` | 89 → 92 equipamentos em runtime; pacote que varre a pasta 63 → 66 |
| `e06_export_content_test.gd` | equipamento 89 → 92 |
| `e06_gameplay_content_test.gd` | 89 → 92 |
| `e06_migration_test.gd` | 89 → 92 (receitas acrescentadas 50 → 53) |
| `e06_ui_menu_test.gd` | publicados 77 → 80; 89 → 92 no catálogo, na coleção do dono e nas instâncias |
| `tests/e09/equipment_items_test.gd` | 89 → 92 equipamentos |
| `tests/fixtures/e08_directional/content_fixture.gd` | `equipment_bottom` resolve o PNG dos três props em `e10a_equipment/props/` (como na A16 do E09) |

Nenhuma expectativa afrouxada; todos os números são exatos. `e08_equipment_art_test` não muda de contagem de ícones.

## Validação (Godot 4.7.2 standard, `tools/verify.ps1 -SkipEditorImport -Test <t>`, um por vez)

`editor_import` e `e07_f1_import_test` passaram antes (só o aviso conhecido de projeto duplicado). `-F1Fixture` não pôde ser usado
nas rodadas depois das edições: confere o hash dos arquivos-fonte e recusa qualquer arquivo editado (`F1 fixture source mismatch`).
A importação reescreveu `.import` rastreados e criou outros; foram restaurados ou removidos, e só os `.import` dos três props e
dos três ícones entram no commit. A folha `weapons_b1.png` fica sem `.import`.

| Teste | Resultado |
|---|---|
| `equipment_items_test` (E09 + E10a, nome compartilhado) | E09: 244 verificações, 0 falhas; **E10a: 301, 0 falhas** |
| `e08_equipment_art_test` | 83559, 0 |
| `e08_directional_units_test` | 77804, 0 |
| `e08_directional_content_test` | 6324, 0 |
| `e08_directional_rig_compatibility_test` | 83328, 0 |
| `equipment_hand_alignment_test` | 4593, 0 |
| `e06_expanded_equipment_content_test` | 2707, 0 |
| `e06_export_content_test` | 174, 0 |
| `e06_gameplay_content_test` | 232, 0 |
| `e06_migration_test` | 150, 0 |
| `e06_ui_menu_test` | 120, 0 |
| `e06_production_loot_test` | 54, 0 |
| `e06_power_progression_test` | 2439, 0 |
| `e06_publication_test` | 1162, 0 |
| `e06_content_pilot_test` | 481, 0 |
| `e06_fixes_performance_cache_test` | 0 falhas |

O novo teste cobre: três itens no catálogo (categoria, faixa, qualidade, origem, identidades, receita); elegibilidade só da família
nas 17 identidades; a regra A13 (acolyte aceito como origem de equipamento e de efeito, `rogue` recusado com `invalid_restrictions`,
duplicata recusada); armaduras de tecido do Mago e as 9 gerais abertas à família, outros conjuntos fechados; livro inicial do Acólito
e de nenhuma das três bases antigas; pesos de produção e 1200 rolagens reais por faixa; hashes, tamanho, grip sobre pixel opaco, ícone 128 px;
`describe`, `resolve_equipment` e textura na mão.

Testes que leem restrições (A13), todos com 0 falhas: `e06_content_authoring_test` 60, `e06_effects_composition_test` 70,
`e06_effects_runtime_test` 53, `e06_inventory_persistence_test` 14, `e06_review_boundaries_test` 7, `e06_review_identity_test` 4,
`e06_review_persistence_edges_test` 15, `e06_tx_composition_test` 60, `e06_tx_inventory_test` 24, `e06_tx_loot_test` 49, `e06_rewards_test` 51.
`e07_f1_composition_test` não rodou: exige `-F1Fixture` (`stale fixture`), inviável com arquivos editados; fica para a T13 em árvore limpa.

## Capturas

- Ícones: `docs/epics/e10a/t9_icons_capture.png`.
- Itens na mão (corpo do Mago, pois os corpos do Acólito são da T8; caminho real `resolve_equipment` + `PROFILES` + `prop_texture`):
  `docs/epics/e10a/t9_grips_capture.png`, script `t9_grips_capture.gd.txt`.

## Limitações e próximo passo

- `base_seam_test` **falha** em `tests/e10a/base_seam_test.gd:124` ("o Acólito oferece só o kit puro pronto de seu ramo: o Sacerdote; o esqueleto do
  Cultista fica de fora"). Não toca equipamento: a T7 deixou o Cultista pronto no candidato `58c0ea90` e a expectativa da A11 ficou velha.
  Não editei, por não ser desta tarefa; fica para a T13.
- Grips provisórios. O livro (20×30) cobre parte da cabeça do corpo do Mago na captura; a T8 calibra mãos e escala com os corpos do Acólito.
- Fixture F1: `-F1Fixture` não serve depois de editar arquivos (acima).
- Próximo passo: T8 parte do candidato com esta tarefa; a T13 compõe esta branch.
