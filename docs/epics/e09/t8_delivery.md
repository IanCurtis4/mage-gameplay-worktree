# E09 T8 — armas novas como itens (contrato C7)

Papel: Terra (Claude Sonnet 5.5, esforço médio). Data: 16/11/2026. Estado proposto: **ENTREGUE
com uma pendência de arquitetura** (desenho na mão com a arte nova; ver "Limitações").
Branch: `claude/beautiful-chebyshev-a49585`. Sem push, sem merge em `master`.

## Base

1. `git merge --ff-only bd66d3c39ce9db036cfce6fe1e0a699a6b5a9698` (ponta de T1 com T1.1): ok.
2. `git merge --no-ff b5aac165fb0b6ca47b734a6a2a580549edb23414` (ponta de T4, com a T2 `68b76011`),
   mensagem `merge(e09): T4 art archive into T8 base`: commit de merge `27d8eb1b`.

## IDs, nomes e regras dos itens

Quatro itens normais, sem conjunto, só stat (+2 no eixo da categoria, como `shared_*`), 1 encaixe,
`origin_id demo_arena`. O ID de definição é o ID de arte, para o ícone pintado resolver por
`EquipmentPresentation.painted_icon(id)`; o arquivo tem prefixo `e09_`.

| ID | Nome pt-BR | Slot / tipo / mãos | Qualidade | Faixa de poder | Eixo | Quem pode usar (por categoria) |
|---|---|---|---|---|---|---|
| `halo_shield` | Escudo do Halo | off_hand / shield / none | rara | 11–15 | defesa física | as 14 identidades |
| `buckler` | Rodela de Aço Batido | off_hand / shield / none | comum | 2–5 | defesa física | as 14 identidades |
| `rapier` | Florete de Guarda Larga | main_hand / weapon / one_hand | incomum | 6–10 | ataque corpo a corpo | origem espadachim: swordsman, defender, berserker, `sp_ac`, `sp_la` |
| `prism_staff` | Cajado Prismático | main_hand / weapon / two_hands | rara | 6–10 | ataque mágico | origem mago: mage, elementalist, spiritualist, mg_ar, `mg_ac`, `mg_la` |

As faixas seguem as três já usadas no catálogo (2–5, 6–10, 11–15; os níveis de loot dos estágios são
2, 4, 6, 9, 12, 15). As qualidades seguem as dos itens de mesmo porte. A elegibilidade é a das
armas/escudos genéricos (`shared_shield`, `shared_sword`, `shared_wand`) mais as quatro híbridas do
E09, de modo que todas as classes atuais mantêm o acesso à categoria.

## Arquivos

- Definições: `resources/e06_inventory_content/equipment/e09_{halo_shield,buckler,rapier,prism_staff}.tres`.
  O catálogo e o loot varrem a pasta; os quatro entram sem lista nova.
- Arte: `assets/art/e09_equipment/` (`prepare_e09_equipment.py`, `manifest.json`, `props/<id>.png`)
  e ícones `assets/art/icons/equipment/painted/<id>.png` (128 px), todos com `.import`.
  Arte-fonte: as folhas da T4, sem `.import` novo. Objetos: H1 v2 nº 5 e nº 4, E1 v3 nº 1, H2 nº 1
  (n-ésima faixa de colunas com alfa > 16, da esquerda para a direita).
  Passos pós-geração (sem gerador novo): recorte do objeto, limpeza do véu de alfa ≤ 16, LANCZOS,
  margem de 2 px no prop, sangria de cor sob o alfa. Hashes e passos em `manifest.json`.
- Tamanhos (px nativos, lógico ×4): `halo_shield` 72×116, `buckler` 72×76, `rapier` 40×160,
  `prism_staff` 52×168. Ícones 128×128, lado maior 118.
- Grips: nova seção `props` em `assets/art/equipment/hand_rigs.json` (tamanho lógico, grip, ângulo,
  slot). `halo_shield` 18×29 grip (9,14); `buckler` 18×19 (9,10); `rapier` 10×40 (5,33) ângulo 0,2;
  `prism_staff` 13×42 (6,5; 30) ângulo 0,3. Leitura por `EquipmentArtCatalog.e09_prop_profile/_texture`.
- Catálogo: `scripts/presentation/equipment_art_catalog.gd` (`E09_PROP_IDS`, `e09_prop_ids`,
  `e09_prop_profile`, `e09_prop_texture`).
- `scripts/core/equipment_loot_profiles.gd`: **sem mudança**. Os pesos de produção são montados do
  catálogo e os quatro itens já entram, exceto lendários fora do chefe e iniciais.
- Teste: `tests/e09/equipment_items_test.gd` (197 verificações): catálogo (89 equipamentos),
  categoria/slot/mãos/qualidade/faixa, política de elegibilidade das 14 identidades contra o item
  gêmeo, composição real no Paladino (+2 de defesa), pesos de produção, 6 estágios × 5 categorias de
  rolagens reais sem queda fora da faixa, hashes de arte, tamanho, grip sobre pixel opaco, margem e
  ícone de 128 px.
- Validação das folhas-fonte (T2): `docs/epics/e09/t8_validation_weapons_{h1_v2,h2,e1_v3}.json`
  (contagem 8/8/2 certa; só o aviso `alpha_veil` das folhas, que o recorte limpa).
- Captura de grips: `docs/epics/e09/t8_grips_capture.png` e o script `t8_grips_capture.gd.txt`.

## Ajustes em testes legados (A15), cada um registrado

Todos são contagens de itens que crescem com os quatro itens; nenhuma expectativa foi afrouxada.

| Teste | Antes → depois |
|---|---|
| `e06_expanded_equipment_content_test.gd` | 85 → 89 equipamentos em runtime; pacote `inventory_fixes_bundle` (varre a pasta) 59 → 63 |
| `e06_gameplay_content_test.gd` | 85 → 89 equipamentos |
| `e06_migration_test.gd` | 85 → 89 equipamentos (de 46 para 50 receitas acrescentadas) |
| `e06_ui_menu_test.gd` | publicados 73 → 77; 85 → 89 no catálogo, na coleção do dono e nas instâncias |

Sem mudança (conferidos): `e08_equipment_art_test.gd` mantém **44** ícones, porque os quatro novos
têm manifesto próprio (`e09_equipment/manifest.json`) e a linha 29 também exige que o item não seja
`main_hand`, o que o florete e o cajado são; `equipment_hand_alignment_test.gd` e
`e08_directional_units_test.gd` não enumeram itens. `head_fit_checks` e `kit_seam_test.gd` intocados.

## Validação (Godot 4.7.2 standard, `tools/verify.ps1 -SkipEditorImport -Test <t>`, um por vez)

Importação completa antes (`--headless --editor --import --quit`; só o erro conhecido `GitPlugin`).
Nenhum `SCRIPT ERROR` nem `still in use` em nenhuma saída abaixo.

| Teste | Resultado |
|---|---|
| `equipment_items_test` | 197 verificações, 0 falhas |
| `e06_expanded_equipment_content_test` | 2614, 0 |
| `e06_gameplay_content_test` | 232, 0 |
| `e06_migration_test` | 147, 0 |
| `e06_ui_menu_test` | 117, 0 |
| `e06_production_loot_test` | 54, 0 |
| `e06_power_progression_test` | 2439, 0 |
| `e06_publication_test` | 1162, 0 |
| `e06_content_pilot_test` | 481, 0 |
| `e06_fixes_performance_cache_test` | 0 falhas |
| `e08_equipment_art_test` | 60459, 0 |
| `equipment_hand_alignment_test` | 4593, 0 |
| `e08_directional_units_test` | 47494, 0 |

SHA256 dos arquivos de teste tocados ou criados: `equipment_items_test.gd`
`66d3f31faebdfbad5a974bd58764c6e55310874d10b85f6460e21ec18e1a345b` (versão final, com a rodela e o
escudo do halo nas medidas finais; os outros testes rodaram com os arquivos abaixo, que não mudaram
depois):
`e06_expanded_equipment_content_test.gd` `5821b68bb6e880fdf06ea4104dbc381b6518b2d646668c7539db57f70017b03e`,
`e06_gameplay_content_test.gd` `e2f27e2728172e07a1640f173b5a231b41816a741d97db15b37ab9efb1881a82`,
`e06_migration_test.gd` `b2e093203d69d6b09d610248330ac2257576ec9a1602eaa103c83f2a01987273`,
`e06_ui_menu_test.gd` `d7bfbfd4a482d9481e93e42447cc26aae9091316fd94d539dee751a40d9691bf`,
`e08_equipment_art_test.gd` `08687937693b94641ef13e91934d9d7d3fa4727cfdcc93405632560ebf193cf5`,
`equipment_hand_alignment_test.gd` `112d66eb1c88aa2f1ac8e05f6c04975f18b61c41be5c13e5dc9a694542bacc3c`.

Antes do commit foram desfeitos os `.import` modificados e removidos os `.import` novos de arte-fonte
e os `.gd.uid` gerados pela importação fora das pastas desta tarefa.

## Conferência visual dos grips (captura nativa)

`docs/epics/e09/t8_grips_capture.png`: o executável do Godot (não headless, GPU) desenha o quadro 0
parado dos 10 corpos atuais com o Escudo do Halo na mão secundária e, na principal, o florete nas três
espadachins e o cajado nas três magos, usando os grips de `hand_rigs.json` e a mesma matemática de
`EquipmentAttachmentVisual.piece_transform`. As empunhaduras caem na mão em todos; o escudo do halo
foi reduzido de 20×32 para 18×29 depois da primeira captura porque cobria o rosto. Só o quadro 0 foi
visto; ataque, morte e as quatro direções não.

## Limitações

- **Desenho na mão com a arte nova: pendente de arquitetura.** O render em jogo escolhe o desenho por
  `visual_key`, e as chaves aceitas (`SUPPORTED`/`PROFILES`) ficam em
  `scripts/actors/equipment_attachment_visual.gd`, que não está na minha lista. Perguntei à sessão de
  arquitetura se posso acrescentar as quatro chaves; até a resposta, os itens usam as chaves genéricas
  (`shield`, `sword`, `staff`) na mão e a arte nova aparece como **ícone** (inventário, loot). O
  catálogo, os grips e a captura já estão prontos; ligar é acrescentar quatro linhas a `PROFILES`
  lendo `EquipmentArtCatalog.e09_prop_profile` e trocar o `visual_key` das quatro definições. Os
  testes legados de mão não cobrem esses quatro até lá.
- Só o quadro 0 foi conferido visualmente; o resto das 32 poses e das direções usa os mesmos pontos de
  mão dos corpos.
- Não foi feita a suíte integral nem jogada uma partida com os itens; as rolagens de loot são do
  resolvedor real com uniformes fixos, não de uma run.
- Sem `.import` nas folhas-fonte (regra de `db7f9252`); o `.import` dos props e ícones foi gerado
  pelo editor desta worktree.
