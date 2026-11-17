# E09 K4 — recibo do kit da Lâmina Arcana (`mg_la`)

Executor: Sol (sessão K4, Opus 5.5, esforço alto), 17/11/2026. Contrato curto com os números e as
cinco perguntas: [k4_contract.md](k4_contract.md). Fontes: [e09_contract.md](../e09_contract.md) §1,
§4 (C3), §5 (C4, K4); decisões A2, A4, A5, A7, A9–A13 de [e09.md](../e09.md); costura T1/T1.1/T1.2
([t1_kit_seam_api.md](t1_kit_seam_api.md)); autoridade de costas da T6 ([t6_delivery.md](t6_delivery.md)).

## Identificação

| Campo | Valor |
|---|---|
| Base 1 (`--ff-only`) | `9a49ed69cfef600027082b90cfecb37ae7dad618`, ponta da T6 (`claude/reverent-wing-9d35b9`), contém a T1 e o `771a314f` |
| Base 2 (merge `--no-ff`) | `4fbfd9db26a1b753b53ba48cc21fa3fff74178c9`, ponta da T1 (`claude/mystifying-moser-f04ddc`): T1.1, T1.2 e A14 |
| Merge de base | `615cf2b6af7d4b8a808d4bb63495aa71dcc26229` (`merge(e09): T1.1/T1.2 seam hooks into K4 base`) |
| Branch | `claude/focused-moser-9107d8` |
| Checkout real | `C:\Users\João Pedro\Documents\ChatGPT\RagRPG\.claude\worktrees\focused-moser-9107d8` |
| Commit de conteúdo | `704cd4efd65420e7d29ccdd7aeb3b8a3cdbf36d6`: kit, fragmento, builds, testes e contrato. As rodadas abaixo usam exatamente estes arquivos |
| SHA entregue | o commit deste recibo, filho direto de `704cd4ef`, só com documentação |

Sem push, sem `master`, sem tocar no playtest habitual nem no save pessoal. Só perfis de fixture em
memória; nenhum perfil ou save gravado.

## Arquivos (dono exclusivo)

| Arquivo | Papel |
|---|---|
| `scripts/classes/mg_la/mg_la_kit.gd` | Kit: 7 skills, aprendizado, receitas, textos pt-BR com tooltip por rank, 11 efeitos em código, ganchos, `ready_for_play = true` |
| `scripts/classes/mg_la/snapshot_manifest.json` | Fragmento, revisão 2 (14 campos, nenhum omitido) |
| `scripts/classes/mg_la/review_builds.json` | Duas builds nomeadas (A11) |
| `tests/classes/mg_la/mg_la_kit_test.gd` | Invariantes do kit |
| `tests/classes/mg_la/mg_la_world_leap_test.gd` | Salto Prismático na geometria do mundo (fixture F1) |
| `tests/classes/mg_la/mg_la_boss_combat_test.gd` | Combate integrado curto contra um chefe, com as duas builds |
| `docs/epics/e09/k4_contract.md`, `k4_delivery.md` | Contrato curto e este recibo |

Nenhum arquivo compartilhado foi editado. `player_actor.gd` não foi tocado. O kit pode nomear
`EnemyActor` (A10), mas não precisou. Não há `KIT_RULE` de item.

## Números e regras (resumo; detalhes no contrato)

| Skill | ID | Regra | Rank 1 → 5 (ativas) / 1 → 3 (passivas) |
|---|---|---|---|
| Marca Refratada (20, entrada, sem pré-requisito) | `arcane_blade_refracted_mark` | `mark_victim`, `see_through`, defensiva (não revela) | 8→6 SP, 4,0→2,0 s, alcance 420→500, +5%→+13% nos pedidos do kit na vítima |
| Lâmina Encantada (23) | `arcane_blade_enchanted_edge` | básico corpo a corpo de cristal (alcance 50, `direct`), fogo → gelo → raio; os três na vítima: +2 (`gain(&"combo", "triad:<n>")`) e reação no tick seguinte | lâmina 100/110/120% ATQ mágico, reação 80/100/120% |
| Refração (25) | `arcane_blade_refraction` | `enter_concealment`; carga do kit (1) com recarga própria; recarga canônica 1,0 s | 14→12 SP, 3,0→5,0 s, carga volta em 14→10 s |
| Salto Prismático (28, pré: Refração 1) | `arcane_blade_prismatic_leap` | só oculta e só na vítima; `back_point` no `can_cast`; `teleport_behind`; golpe marcado (costas + abertura = +2); `pursue(vítima)` | 16→20 SP, 8,0→6,0 s, alcance 300→380, golpe 130→190% |
| Fratura de Luz (31) | `arcane_blade_light_fracture` | abate por execução (`first` e `execution`): devolve a carga da Refração e SP | 8/12/16% do SP máximo |
| Sentença Prismática (34, pré: Lâmina 1) | `arcane_blade_prismatic_sentence` | `flank.execute` mágico; limiares da T6; chefe só dano (A4) | 18→22 SP, 7 s, alcance 80, 160→240% × (1 + 0,40 × cargas) |
| Espectro de Prisma (37, pré: Salto 3) | `arcane_blade_prism_specter` | 3 reflexos (fogo, gelo, raio) em vítimas diferentes, vítima primeiro; marca `arcane_blade_specter`; um a cada 0,20 s; cada um é `flank.execute` com o lado do ponto do reflexo | 36→44 SP, 50→42 s, raio 320, 90→130% |

Elementos de regra (A2): `arcane` para Marca, Lâmina e Salto; `light` para Refração, Fratura,
Sentença e Espectro. Todas as receitas usam `arcane` (`FeedbackRecipeCatalog.ELEMENTS` não tem
`light`). Todo pedido do kit passa por `flank.mark_request` (direto em `_mark`, ou dentro de
`flank.execute`); o teste de fonte confere isso.

### Interações com a base Mago (C4.3)

- **Teleporte é a saída.** `on_base_skill_committed(player, &"teleport", context)` (T1.2, A13): todo
  inimigo vivo a até 220 da partida perde a Lâmina de vista (`flank.break_sight`, 1,2 s; chefe
  × 0,6). No mapa plano a partida é a posição no commit; no mundo, onde o teleporte já moveu o
  jogador antes do pagamento, é a posição do último tick (`last_ground`). Testado nos dois modos,
  inclusive que o inimigo perto da **chegada** não perde a visão.
- **Lança de Gelo segura a vítima de longe.** Lentidão própria; com a Lâmina Encantada, o acerto na
  vítima conta como o gelo da sequência; +1 de Sentença (direto).
- Os outros feitiços na vítima dão +1 (direto), mas não entram na sequência.

### Limitações 2 e 3 da T6 (registro pedido)

- **Limitação 2 (ocultação "na hora").** A Fratura de Luz devolve a Refração **como carga do kit**
  (zera a recarga da carga), e não como ocultação instantânea. O teste confere que nenhuma
  ocultação é forçada no abate. Como a costura não tem gancho de recarga, a recarga real da Refração
  é a carga do kit, e a recarga canônica da skill fica em 1,0 s.
- **Limitação 3 (rota privada após o teleporte).** No mapa plano, a rota pendente **continuaria**
  depois do `teleport_behind`. O kit resolve isso sem tocar no `player_actor.gd`: chama o comando
  público `player.pursue(vítima)` logo após o teleporte. O comando limpa o caminho e engaja a vítima
  com a lâmina. O teste prova que a Lâmina, que andava para a esquerda, fica colada na vítima e
  segue cortando. No mundo, `WorldActorMotion.teleport` já zera a rota (testado: `has_route()` falso).
  Como a correção ficou dentro do kit e não quebra o combate, não foi preciso perguntar à
  arquitetura.

## Efeitos em código e IDs de flipbook reservados (C4.4)

| ID reservado | Skill | Tipo |
|---|---|---|
| `arcane_blade_mark_prism` | Marca Refratada | `effect_start` |
| `arcane_blade_crystal_swing` | Lâmina Encantada | `effect_start` (cada golpe da lâmina, por `presentation_fact`) |
| `arcane_blade_triad_burst` | Lâmina Encantada | `impact` (reação) |
| `arcane_blade_refraction_veil` | Refração | `effect_start` |
| `arcane_blade_leap_flash` | Salto Prismático | `effect_start` |
| `arcane_blade_leap_strike` | Salto Prismático | `impact` |
| `arcane_blade_light_fracture` | Fratura de Luz | `effect_start` (no abate por execução) |
| `arcane_blade_sentence_gather` | Sentença Prismática | `effect_start` |
| `arcane_blade_sentence_tricolor` | Sentença Prismática | `impact` |
| `arcane_blade_specter_summon` | Espectro de Prisma | `effect_start` |
| `arcane_blade_specter_strike` | Espectro de Prisma | `impact` |

Um flipbook em `assets/art/e08_vfx/<id>/` substitui o desenho pelo mesmo ID (C5). Básico:
`basic_attack_recipe() = [melee, arcane]`.

## Builds (A11, `ragrpg_review_builds_v1`)

Mapas com o rank final. Base: soma 19 (sem rank grátis). Evolução: R1 grátis na Marca, então os ranks
somam 21 para 20 pontos (`skill_points_spent` = 19/20; `validate_purchased_ranks` legal, no teste).

| Build | Base (19) | Evolução (20 pontos) |
|---|---|---|
| `arcane_blade_execution_chain` — Corrente de Execuções | Teleporte 5, Lança de Gelo 5, Bola de Fogo 3, Relâmpago 3, Barreira Fantasma 1, Regeneração de SP 2 | Marca 2, Lâmina 3, Refração 4, Salto 4, Fratura 2, Sentença 5, Espectro 1 |
| `arcane_blade_prism_specter` — Espectro Prismático | Teleporte 3, Lança de Gelo 4, Bola de Fogo 4, Relâmpago 4, Barreira Fantasma 1, Regeneração de SP 3 | Marca 1, Lâmina 2, Refração 3, Salto 3, Fratura 3, Sentença 4, Espectro 5 |

## Validação

Godot 4.7.2 standard, `C:\Users\João Pedro\Documents\ChatGPT\RagRPG\.tools\godot\Godot_v4.7.2-stable_win64.exe`,
pelo PowerShell (`Start-Process -Wait` e `tools/verify.ps1 -GodotPath`). Antes, a worktree foi
importada com `--headless --editor --import --quit` (saída 0; só o `Cannot get class 'GitPlugin'`
conhecido).

### Testes novos

| Teste | Resultado | Cobertura |
|---|---|---|
| `mg_la_kit_test` | 231 checks, 0 falhas | catálogo e prontidão (A7), elementos A2, receitas `arcane`, entrada sem pré-requisito, textos e tooltips pt-BR, 11 efeitos; builds legais 19/20; Marca (vítima, bônus, não revela); **ataque básico de cristal pelo laço real do jogador** (corpo a corpo, `direct`, alcance 50, fogo → gelo → raio → fogo, só dano mágico, sem projétil; com rank 0, o projétil do Mago marcado); tríade +2 e reação no tick seguinte, **retry sem duplicar** Sentença nem elemento, sequência recomeça com outra vítima, Lança de Gelo como gelo; Refração (carga, recarga, recusas, revelação e abertura +2); Salto (só oculta, só na vítima, costas, +2, Marca, **ponto bloqueado recusado antes do pagamento**, alcance); rota plana após o teleporte (limitação 3); Sentença (retry `already_executed` sem gastar de novo, limiares nas quatro categorias, chefe a 1% sem morte certa); Fratura (**callback de abate único**, abate comum e sem a passiva não devolvem); Espectro (três vítimas diferentes, vítima primeiro, raio, sequência de 0,2 s, pausa, costas, execução letal na vítima aciona a Fratura, alvo morto descartado, bloqueio do compacto); Teleporte da base como saída (perto/longe, recusado, outra skill da base não conta); **troca de build sem cura nem reset**; morte; pausa; **snapshot exato e compacto** (vítima, Sentença, ocultação, sequência, carga; compacto sem vítima; reflexo pendente recusa o compacto e volta no exato); guardas de fonte |
| `mg_la_world_leap_test` | 49 checks, 0 falhas | pipeline real do mundo (`request_world_skill` → `KitWorldSkillCast`): recusas antes da Marca e sem ocultação; **laje acima**: sob a ponte, pousa no chão de baixo atrás da vítima; vítima na laje logo acima fica fora do alcance pelo chão (recusado, nada pago); a partir do patamar, pousa na laje atrás dela; **borda sem chão** (`back_point_blocked`, nada pago, ocultação mantida); **alcance** (rank 1 recusado longe, aceito perto); sem rota depois do teleporte; Teleporte da base no mundo medido a partir do último tick |
| `mg_la_boss_combat_test` | 33 checks, 0 falhas | `forest_ancient_warden` (chefe), sem adds e sem augment, IA real; atributos legais de nível 30 (INT 50, DES 36, AGI 20, VIT 8 acima do inicial, só fixture). Corrente: chefe morto em 27,4 s, Lâmina 378/482 HP, 4 Sentenças (cargas 4, 5, 5, 5), 2 Saltos pelas costas, 39 golpes de lâmina (13 por elemento), 12 reações, 4 Teleportes de saída (todos tiram a visão do chefe). Espectro: 28,5 s, 378/482, 5 Sentenças, 3 Saltos. Nenhuma morte certa no chefe (A4) |

### Regressão por impacto

```
tools/verify.ps1 -GodotPath <godot> -SkipEditorImport -CheckTimeoutSeconds 300 `
  -VerificationDirectory .godot/verification/k4_f1_import -Test e07_f1_import_test
tools/verify.ps1 -GodotPath <godot> -SkipEditorImport -F1Fixture -CheckTimeoutSeconds 300 `
  -VerificationDirectory .godot/verification/k4_impact `
  -Test mg_la_*,flank_test,kit_seam_hooks_v2_test,kit_seam_hooks_v3_test,mage_gameplay_test,
        e04_teleport_rank_integration_test,e04_mage_*,e05_elementalist_catalog_test,
        e05_geometer_g7_test,e05_geometer_builds_test,e07_f6_threat_test,e07_f6_snapshot_test,
        e07_f1_guard_travel_test,e08_compact_checkpoint_test,e08_compact_coverage_test,
        e07_f3_snapshot_test
```

`e07_f1_import_test` (passo 256): PASS, 3283 arquivos idênticos, saída `281364E4…147377`;
`checks.jsonl` `06F952A6E84157E82F2399F934BD74554EE6DAC8B2AEA02A3232F729F6788E45`.

Rodada de impacto: **26/26 passos passaram**, todos com saída 0. `checks.jsonl`:
`7206BF52A6187C6272546FB401EF7C6DF8295FEE3879727FB8989F9534E7C4A3`.

| Passo | Teste | Resultado | Saída (sha256) |
|---|---|---|---|
| 33 | `mage_gameplay_test` | PASS (52) | `02D14E4B0067A2FC483B56F165EC8534C00262007966F3D45930D287E2919C5C` |
| 60 | `e04_teleport_rank_integration_test` | PASS (29) | `09A9DF630C4CE22000062EA5B4CCCB31C63FBDEF89B12A539F9E77D6FF97D9AC` |
| 61 | `e04_mage_sp_regeneration_rank_integration_test` | PASS (27) | `659126513A0D526F45380C06DDD459B6F3F22650012FD21D9A80B52F7C4B5BCF` |
| 88 | `e04_mage_lightning_rank_integration_test` | PASS (66) | `E2157F7DA8B77E51583AB01A8A6D7B05DE070F730FBC35FDB3B53353E28F87A8` |
| 89 | `e04_mage_electric_discharge_rank_integration_test` | PASS (71) | `A9CE5F6D1E4D39D695A573C7D49DAD58D26FC8E478885642B5840558B1162E08` |
| 90 | `e04_mage_lightning_wall_rank_integration_test` | PASS (73) | `BD46420AC0BB2A65C2B6967850B46F0A6320D210C9EF3634BD2F93BB14651475` |
| 91 | `e04_mage_soul_impact_rank_integration_test` | PASS (64) | `C751CFDD91EA6267BE27022FDF58C16334919B5E407D2121B0B46168E234A091` |
| 92 | `e04_mage_haunt_rank_integration_test` | PASS (84) | `D7EA8FD4C215C75E808676A18C22F16678F428EB4D2A1F06FDC26A4DE765E886` |
| 93 | `e04_mage_phantom_barrier_rank_integration_test` | PASS (78) | `C125F85DDB1E378F8953234045EC06233D81C98109F31702CA551CB4192833F1` |
| 94 | `e04_mage_ice_wall_rank_integration_test` | PASS (78) | `4DCAF3B16BA063735CB2674540B7C4769E7E4D8D0F7082F25172F0C92568DD46` |
| 95 | `e04_mage_integrated_closure_test` | PASS (106) | `0A72FA1BB32A0B5B87B6DF1801371598E8D0400468A8EAA11FC00A29CB3A61E4` |
| 138 | `e05_geometer_builds_test` | PASS (376) | `D7C99B6A26F64640F5C5376ACAB25C3363C3854BCDE09A3AD5C487B297B4315D` |
| 141 | `e05_geometer_g7_test` | 497, 0 | `44B011806ED1482C14E797F4AD95C3471236547E62340666B03A52BC323187A2` |
| 163 | `e05_elementalist_catalog_test` | PASS (99) | `C450AA9D5A3BB66D916777011949B003A117C5088BF49FB8A1999137FBEF0905` |
| 268 | `e07_f6_threat_test` | 43, 0 | `C38ACB2F6A0A4F101776B095EE0A68791A65E72A12D77D5317B2EB793EFA2AD3` (igual à T6) |
| 270 | `e07_f6_snapshot_test` | 40, 0 | `2E091952F53115A75311BF2F4CFD595A18B2E8C64FA3076CBF6F844F4CC4EDC6` (igual à T6) |
| 282 | `e08_compact_checkpoint_test` | 48, 0 | `346B73697BFB3C1975A5B0B2196C99CC96AE95E389DFA441C3EDBDC5FFDCA1EC` (igual à T6) |
| 283 | `e08_compact_coverage_test` | 95, 0 | `3C65ADD205F98F2D063AFCF6DAD256C3F207D51AAE7376621D38801D89228796` (igual à T6) |
| 294 | `e07_f3_snapshot_test` | 52, 0 | `9FC703C4AB2986DDAAB73ED386092F3B8AB71A5EA82C4A7C3C781D2F6F06C0CC` (igual à T6) |
| 310 | `e07_f1_guard_travel_test` | 293, 0 | `0DD468D2FE6986F208C9B58766E3916BAE42F315A3B6483D1C5C8AD0CF229EE4` |
| 329 | `kit_seam_hooks_v2_test` | 38, 0 | `5182F32B62DE14BE5938AF67C615BFBC0CBB6BDF062A64EDB08131758CF6FA5A` |
| 330 | `kit_seam_hooks_v3_test` | 63, 0 | `D1DFD323C350F8F63140F3D8D86FE01FB566BAEE11ED3A93B953FBF99F78F449` |
| 332 | `flank_test` | 205, 0 | `D23DC5D7B03B0FE0742A8C62D00F0A0F8438F0DC30F43DC1FD5CDE9D4244C02A` (igual à T6) |
| 333 | `mg_la_boss_combat_test` (novo) | 33, 0 | `6710C89EC58026EC2087DACAE4E531374CC5B5EB4EBCBD8181C5ADAC0684F98D` |
| 334 | `mg_la_kit_test` (novo) | 231, 0 | `B480859D5403B1E855CD3190E92F1D4227967A9F3594A99B0EB38E7E93BEF95D` |
| 335 | `mg_la_world_leap_test` (novo) | 49, 0 | `F2E59EE4F7352D9C788D6E6A34284A72EFE63B17A3F459845389696B615A2DE0` |

- **Busca nas saídas.** `SCRIPT ERROR`, `still in use`, `Parse Error` e `Compile Error` nos
  `.output.log`/`.engine.log` das duas rodadas: **0 ocorrências**. O aviso
  `compact cut rehearsal failed` do `e08_compact_checkpoint_test` é o cenário proposital do próprio
  teste.
- **Plano.** 335 passos (era 332 na base); os três testes novos foram descobertos pelo grupo
  `tests/classes` sem editar o verificador.

### Falhas esperadas (A9/A17, dono T9)

Rodadas à parte, porque o verificador para na primeira falha.

| Teste | Resultado | Saída (sha256) |
|---|---|---|
| `e05_evolution_catalog_test` (passo 108) | FAIL 1 de 55: "production catalog registers the twelve accepted E00 identities…"; **1 `SCRIPT ERROR` na linha 47** (chave `mg_la` na lista exata de destinos do Mago) | `D5BB93EEFC256605D87BE3C924C7B384B67C81ABEC1DDB8518532111BB47C30B` |
| `kit_seam_test` (passo 331) | 189 checks, 4 falhas, 0 `SCRIPT ERROR`: "mg_la skeleton is empty and not ready", "mg_la skeleton validates and stays unavailable", "unready kits are not offered (C1.3)", "other origin unchanged" — todos checks de esqueleto de produção (A17) | `A27BBFC7B980634FD54BDA13B1B001793ABA9BBC63ECC68F5780183F84851660` |

São expectativas que a A9/A17 passa à T9 (listas de destinos e esqueletos de produção). Nenhuma foi
editada aqui.

### Limpeza

A importação reescreveu 573 arquivos rastreados (`.import` só com fim de linha e a DLL temporária
do plugin de Git), restaurados de `HEAD`, e criou 1348 `.import`/`.gd.uid` não rastreados fora das
minhas pastas, removidos. Os diretórios `.godot/verification/k4_*` ficam fora do Git.

## Limitações

1. **Recarga da Refração fora do HUD.** A carga e a recarga da Refração são estado do kit; o HUD só
   mostra a recarga canônica de 1,0 s. Sem carga, o atalho parece pronto e o cast é recusado com
   `arcane_blade_refraction_recharging`. Mostrar isso precisa de um gancho de recarga do kit na
   costura ou do onboarding da T9.
2. **Cor da lâmina.** `draw_vfx` é puro e não vê o estado do kit: o golpe de cristal é desenhado
   tricolor, sem a cor do elemento do golpe (o mesmo limite registrado pela K2). O elemento está no
   pedido (`effect_snapshot["arcane_blade_element"]`), para uma camada de apresentação futura.
3. **Receita do básico.** `basic_attack_recipe` é fixa (`melee`, `arcane`). Nos jobs 20–22, antes da
   Lâmina Encantada, o projétil do Mago aparece com a receita corpo a corpo.
4. **Mapa plano antigo (limitação 1 da T6).** A saída pelo Teleporte e a ocultação agem sobre a
   ameaça; a aquisição pela posição não conhece o observador. No mundo, a perda de visão também
   bloqueia a aquisição (testado).
5. **`pursue` depois do Salto.** É decisão de jogo do kit: depois do salto, a Lâmina engaja a vítima
   com a lâmina (o alvo do jogador passa a ser a vítima). É o que resolve a limitação 3 sem tocar no
   jogador.
6. **Reflexos.** São marcas no inimigo (`arcane_blade_specter`) e não nós desenhados: aparecem pelo
   efeito de invocação e pelo golpe no alvo. Enquanto existe um reflexo pendente (até 0,4 s), o
   corte compacto é inelegível e o save usa o formato exato.
7. **Laje acima pelo chão.** O alvo único do mundo exige alcance pelo chão (`world_can_reach`). Uma
   vítima numa laje logo acima, mas com rota longa, fica fora do Salto. É regra da geometria, não do
   kit.
8. **Chefe de teste.** O `forest_ancient_warden` acerta pouco a Lâmina (HP mínimo 378/482). O teste
   mostra que ela vence sozinha e usa a saída, mas não estressa a fragilidade exposta. O spawn do
   chefe é fixado antes do `configure_occurrence`; com o spawn na origem, o Salto tirava a Lâmina da
   coleira e o chefe voltava ao posto, imune (regra F10). É efeito da fixture, mas mostra que um
   Salto para fora da coleira reinicia o chefe.
9. **Arte.** Ícones (T3) e corpo (T7) chegam na integração; nesta branch vale o corpo da origem.
   Os `.gd.uid` dos três testes novos não foram gerados (a importação foi feita antes de eles
   existirem); a próxima importação do editor os cria.
10. **Escopo da supervisão:** execução, conclusão, erros e hashes dos testes, mais as invariantes do
    contrato. Não é auditoria semântica independente.

## Próximo passo

T9 atualiza as listas de destinos e os checks de esqueleto (A9/A17) com `mg_la` pronto. T10 compõe o
SHA entregue com T3/T7, inclui `scripts/classes/mg_la/snapshot_manifest.json` no `include_filter`
(A10) e roda a suíte completa.
