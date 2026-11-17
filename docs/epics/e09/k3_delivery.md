# E09 K3 — recibo do kit do Duelista (`sp_la`)

Executor: Sol (sessão K3, Claude Opus 5.5, esforço alto), 16/11/2026. Contrato com os números e
as cinco perguntas: [k3_contract.md](k3_contract.md). Costura: [t1_kit_seam_api.md](t1_kit_seam_api.md)
(T1, T1.1, T1.2). Família de costas: [t6_contract.md](t6_contract.md), [t6_delivery.md](t6_delivery.md).

## Base, branch e checkout

| Item | Valor |
|---|---|
| Passo 0.1 | `git merge --ff-only 9a49ed69cfef600027082b90cfecb37ae7dad618` (ponta da T6, recibo; contém T1 `337aa7df` e `771a314f`): ff sem conflito |
| Passo 0.2 | `git merge --no-ff 4fbfd9db26a1b753b53ba48cc21fa3fff74178c9` (ponta da T1 com T1.1, T1.2 e A14) → `7876fd834c17ebd54edd5a928a3c6fb779d234b1`, sem conflito |
| Branch | `claude/sharp-sanderson-ff7ed8` |
| Checkout | `C:\Users\João Pedro\Documents\ChatGPT\RagRPG\.claude\worktrees\sharp-sanderson-ff7ed8` |
| Commit entregue | `677f0045e089fb9845f16e14e80825cfe8130568` (conteúdo); este recibo com o SHA vem no commit seguinte |

## Arquivos (todos de dono exclusivo)

| Arquivo | Mudança |
|---|---|
| `scripts/classes/sp_la/sp_la_kit.gd` | Kit completo: 7 skills, aprendizado, textos pt-BR com tooltip por rank, receitas, 7 efeitos em código, ganchos; `ready_for_play = true` |
| `scripts/classes/sp_la/snapshot_manifest.json` | Revisão 2: `flank`, `patience`, `duel_remaining`, `auto_parry_remaining`, `parry_serial`, `parry_refund` |
| `scripts/classes/sp_la/review_builds.json` | `ragrpg_review_builds_v1`, duas builds |
| `tests/classes/sp_la/sp_la_kit_test.gd` | Invariantes do kit |
| `tests/classes/sp_la/sp_la_parry_ai_test.gd` | Aparo contra ataques reais de `EnemyActor` (critério extra do K3) |
| `tests/classes/sp_la/sp_la_boss_combat_test.gd` | Combate integrado contra chefe real, uma vez por build |
| `docs/epics/e09/k3_contract.md`, `docs/epics/e09/k3_delivery.md` | Contrato e este recibo |

Nenhum arquivo compartilhado foi tocado (A10). O kit nomeia `EnemyActor` só nos testes; o módulo
usa `CombatActor`. Sem `KIT_RULE` de item.

## Números (resumo; a fonte é o contrato)

| Skill | Tipo | Números de R1 → R5 (passivas R1 → R3) |
|---|---|---|
| Aparo `duelist_parry` | entrada, R1 grátis, sem pré-requisito | SP 4 → 3, devolvido ao aparar pela própria janela; recarga 1,2 → 0,8 s; janela 0,30 → 0,38 s, 1 carga |
| Leitura do Oponente `duelist_read_opponent` | passiva | aparo +2, costas +2, outros +1 no último aparado; golpes do kit pelas costas na vítima × 1,10 → 1,20 |
| Riposte Fatal `duelist_fatal_riposte` | ativa, alvo único, 90 px; pré-requisito Leitura 1 | SP 10 → 14; recarga 6 s; 150% → 230% do ATQ × (1 + 0,40 × cargas); morte certa pela T6 (30/24/18/12%), chefe nunca; matar arma o aparo automático (8 s) |
| Finta `duelist_feint` | ativa, alvo único, 220 px | SP 10 → 12; recarga 9 → 7 s; passo lateral 48 px; marca 2,5 → 3,5 s: o próximo golpe corpo a corpo do alvo conta como aparado, de qualquer lado |
| Guarda Paciente `duelist_patient_guard` | passiva | sem atacar por 3,0 / 2,5 / 2,0 s, janela +0,10 / +0,14 / +0,18 s (teto 0,60 s da T6) |
| Recuo em Guarda `duelist_guarded_retreat` | ativa, própria | SP 10 → 12; recarga 10 → 8 s; passo de 80 px para trás (2/3 e 1/3 se o chão não deixar); perda de visão 1,2 → 2,0 s num raio de 180; abre a janela do Aparo |
| Duelo `duelist_duel` | ativa, própria; pré-requisito Aparo 3 | SP 30 → 38; recarga 50 → 42 s; 4,0 → 6,0 s de aparos ilimitados de frente; estocada pelas costas 90% → 130% do ATQ por aparo |

Exposição do aparo: os padrões da T6 (giro 1,5 s, perda de visão 1,2 s; chefe × 0,6).

**Ajuste feito durante a tarefa.** A primeira versão do contrato tinha Aparo de 6–8 SP e Riposte de
18–22 SP. O combate integrado mostrou que, com DES > AGI > FOR, o `sp_regen` fica perto de
2,1 SP/s. Aparar cada golpe do chefe secava o SP, e o Riposte quase não saía (2 em 90 s, com a
Sentença parada em 5). O contrato passou a ter os custos acima e a devolução do SP do Aparo no
aparo certo. O núcleo da ficha não mudou.

## IDs de flipbook reservados (C4.4)

| ID | Skill | Evento |
|---|---|---|
| `duelist_parry_flash` | Aparo | `effect_start` (commit do Aparo e cada aparo bem-sucedido) |
| `duelist_riposte_lunge` | Riposte Fatal | `effect_start` |
| `duelist_riposte_strike` | Riposte Fatal | `impact` |
| `duelist_feint_step` | Finta | `effect_start` |
| `duelist_retreat_step` | Recuo em Guarda | `effect_start` |
| `duelist_duel_ring` | Duelo | `effect_start` |
| `duelist_duel_thrust` | Duelo | `impact` |

Todos são desenhados em código por `draw_vfx`. Um flipbook em `assets/art/e08_vfx/<id>/` com o
mesmo ID substitui o desenho, sem mudar o kit.

## Builds nomeadas (A11)

`scripts/classes/sp_la/review_builds.json`, `ragrpg_review_builds_v1`, `identity_id: "sp_la"`.
Os mapas trazem o rank final; o Aparo tem R1 grátis.

| Build | Base (19 pontos) | Evolução (20 pontos; soma dos ranks 21) |
|---|---|---|
| `duelist_patient_blade` — Lâmina Paciente | Corte 5, Investida 5, Parede de Escudos 2, Perseverança 2, Resistência 3, Vigor 2 | Aparo 5, Leitura 3, Riposte 5, Finta 3, Guarda Paciente 3, Recuo 1, Duelo 1 |
| `duelist_arena` — Arena do Duelo | Corte 5, Investida 3, Fúria 3, Parede de Escudos 2, Sede de Sangue 3, Resistência 3 | Aparo 3, Leitura 2, Riposte 3, Finta 1, Guarda Paciente 2, Recuo 5, Duelo 5 |

O `sp_la_kit_test` confere os pontos com `skill_points_spent` (19 e 20) e a legalidade com
`validate_purchased_ranks` (job 40, pela A18). A primeira versão da Lâmina Paciente tinha
Perseverança sem a Parede de Escudos 2 que ela exige (`SkillDependencyRules`). O teste recusou, e
a build foi corrigida.

## Testes

Godot 4.7.2 standard (`Godot_v4.7.2-stable_win64.exe`, pelo PowerShell; o executável `_console`
falhou com `CreateProcess error 193` nesta máquina). A worktree foi importada antes com
`--headless --editor --import --quit`, só com o erro conhecido `Cannot get class 'GitPlugin'`.

### Novos, em `tests/classes/sp_la/`

| Teste | Passo | Resultado | Saída (sha256) |
|---|---|---|---|
| `sp_la_kit_test` | 334 | 217 checks, 0 falhas | `D2DC91B266E2E5A55FB39150B5059A8D34BBB2D46CA2B5BF7157F0614114F697` |
| `sp_la_parry_ai_test` | 335 | 55 checks, 0 falhas | `4F0C254BD31C88E4BBB9C1DCDFC19D4DD33AA71A5C6C7A27284F50E8353BDB19` |
| `sp_la_boss_combat_test` | 333 | 31 checks, 0 falhas | `4F9C0F3FB7B9919FBBF80D612971B572ACE39A23BBCFB2D361E14CA22AE698CE` |

`ready_for_play = true` só foi mantido depois que os três passaram (A7).

**Aparo contra ataques reais (`sp_la_parry_ai_test`).** `EnemyActor` reais (`chaser` e `archer`)
rodam a própria IA e atacam por `RunController._on_enemy_attack_requested`, o caminho do jogo. O
Duelista só lança skills por `use_kit_skill`.
- Dentro e fora da janela:
  - o golpe que chega 0,30–0,35 s depois do Aparo R5 (janela de 0,38 s) é aparado;
  - o golpe 0,40–0,45 s depois acerta inteiro;
  - o golpe anterior ao Aparo acerta;
  - há uma carga por janela: com dois inimigos, o segundo acerta.
- Guarda Paciente R3: depois de 2 s sem atacar, o golpe 0,50–0,55 s depois do Aparo é aparado. O
  mesmo tempo sem a paciência acerta.
- Giro e perda de visão:
  - o atacante aparado fica 1,5 s girado (override de facing, que o sprite usa), mostra as costas e
    perde o Duelista de vista por 1,2 s;
  - o ataque básico seguinte sai pelas costas, com a Leitura (× 1,20) e +2;
  - a pausa congela o giro, e os dois relógios expiram no tempo de gameplay.
- Costas e os dois flancos: não aparados; a carga fica, e o atacante não gira.
- Projétil: a flecha real em voo não é aparada, nem no Duelo.
- Área: nenhum inimigo atual produz área (T1 5.3). O golpe real foi publicado como `area` por
  `_kit_publish_enemy_attack` e não foi aparado.
- Finta: o próximo golpe do inimigo fintado é aparado, mesmo pelas costas, uma única vez.
- Aparo automático depois de uma morte pelo Riposte: o próximo golpe de frente é aparado sem lançar
  o Aparo, uma única vez.
- Duelo contra três inimigos:
  - em 5,5 s os três atacam, 11 golpes ou mais;
  - todos são aparados, sem dano;
  - cada aparo devolve uma estocada que acerta pelas costas, e os três são respondidos;
  - depois do Duelo, os golpes voltam a acertar.

**Invariantes (`sp_la_kit_test`).**
- Catálogo:
  - validação, `ready_for_play` e oferta ao Espadachim com afinidade `rogue`;
  - nomes pt-BR, efeito e tooltip por rank, efeitos e receitas;
  - entrada sem `prerequisites`;
  - as duas builds.
- Pipeline do aparo:
  - cancelamento do golpe inteiro;
  - SP devolvido só no aparo certo;
  - projétil, área, costas e flanco recusados;
  - janela por rank e expiração.
- Leitura:
  - +2, +2 e +1, com teto 5;
  - **retry do mesmo resultado sem Sentença**, no golpe do kit e no Corte da base;
  - DoT sem ganho, só o último aparado acumula, e sem a passiva nada acumula.
- Riposte:
  - gasto das 5 cargas;
  - morte certa no limiar das quatro categorias e recusa acima dele;
  - **chefe a 1% com 5 cargas sem morte certa**;
  - **callback de abate único em retry**;
  - abate comum não arma o aparo automático.
- Finta, Guarda Paciente e Recuo:
  - a paciência zera pelo ataque básico, pelo Corte e pela Investida (gancho da T1.2) e pelo
    Riposte; uma Investida recusada não zera;
  - Recuo: passo, perda de visão no raio, chefe × 0,6, borda do mapa e a limitação 1 da T6;
  - Finta: com um lado bloqueado, o passo vai para o outro.
- Duelo, com a Leitura na estocada.
- Interações com a base (Corte e Investida).
- **Troca de build sem cura nem reset**; a pausa congela todos os relógios; morte.
- **Suspensão e retomada nos dois formatos:**
  - exato: vítima, Sentença, modo de aparo, Duelo, aparo automático, paciência e Finta, com o dono
    religado;
  - compacto: elegível; o estado do jogador fica, e a vítima some com o inimigo (A5).
- Guarda de fonte: sem escrita de HP, sem `KIT_RULE` e com todo pedido do kit marcado.

**Chefe (`sp_la_boss_combat_test`).**
- Chefe: `forest_ancient_warden` real (categoria chefe), sem adds e sem augment, com 20 000 de HP.
- Atributos: distribuição legal de nível 30 (DES 50, AGI 36, FOR 25, VIT 5), só na fixture.
- Robô: lê o `attack_cooldown` real do chefe para lançar o Aparo e erra de propósito um golpe em
  cada três.

| Build | Tempo | Chefe | Duelista | Golpes do chefe | Aparados | Acertaram | Ripostes (cargas) |
|---|---|---|---|---|---|---|---|
| Lâmina Paciente | 53,4 s | 0 / 20 000 | 452 / 482 | 41 | 29 | 6 | 9 (4 uma vez, 5 oito vezes) |
| Arena do Duelo | 53,9 s | 0 / 20 000 | 481 / 482 | 42 | 30 | 4 | 9 (4 uma vez, 5 oito vezes) |

Nas duas builds o Duelista vence sozinho. O giro do chefe dura no máximo 0,9 s, e nenhum Riposte
no chefe é letal (`lethal_total = 0`, A4). Finta e Duelo entram no laço.

### Regressão por impacto

```
tools/verify.ps1 -GodotPath <godot> -SkipEditorImport -CheckTimeoutSeconds 300 `
  -VerificationDirectory .godot/verification/k3_impact -Test <os 18 testes abaixo>
```

**18/18 passos passaram.** `checks.jsonl`: sha256
`B08EEDFCEA72114EC57A2F2B266756096109FDB9630F3BA81548E424F71D1778`.

| Passo | Teste | Resultado | Saída (sha256) |
|---|---|---|---|
| 53 | `e04_slash_rank_integration_test` | PASS, 27 | `DE4EA69A121B77BEDEC6F5A460731CE977D93F8DE83AB3E0BF13E550DD900DF6` |
| 54 | `e04_dash_rank_integration_test` | PASS, 28 | `261FEAAAD8B9496F94868EE479D1E8F7E7C62DC9BA0C569985E0F0C46115D49B` |
| 106 | `e04_swordsman_integrated_closure_test` | PASS, 94 | `F665A9A22AE1952881CE1C875A352CD947782AA7E988D05C7842F6132943DBD4` |
| 188 | `e05_defender_guard_test` | PASS, 18 | `3593F6915E417D89309B6242D7A57394EA1CCB3CF49B601A7F3ABA9BF565F015` |
| 189 | `e05_defender_skills_test` | PASS, 32 | `E7D81B2C6E5ADFD0B7929A7B1E28B3EE5A195BFEB56B980F7E58BD06531E9AB9` |
| 191 | `e05_defender_builds_test` | PASS, 73 | `9A3AE53C622C97FDC1DD99695101E5521E4DB02FDBFBFC46322665EE0389AE05` |
| 209 | `e06_rx_mob_ai_test` | 4, 0 | `B9569774452019C5A7A2F3C085320FE2CF4B747A45ADF3BBBAC256FFC674109A` |
| 244 | `e06_swordsman_cluster_test` | PASS, 227 | `8E2D07CE0755B724FAD6FFAB22CB9D3743A1C1EE661707CD0CA4C3BF8B53FF74` |
| 268 | `e07_f6_threat_test` | 43, 0 | `C38ACB2F6A0A4F101776B095EE0A68791A65E72A12D77D5317B2EB793EFA2AD3` |
| 270 | `e07_f6_snapshot_test` | 40, 0 | `2E091952F53115A75311BF2F4CFD595A18B2E8C64FA3076CBF6F844F4CC4EDC6` |
| 282 | `e08_compact_checkpoint_test` | 48, 0 | `346B73697BFB3C1975A5B0B2196C99CC96AE95E389DFA441C3EDBDC5FFDCA1EC` |
| 283 | `e08_compact_coverage_test` | 95, 0 | `3C65ADD205F98F2D063AFCF6DAD256C3F207D51AAE7376621D38801D89228796` |
| 294 | `e07_f3_snapshot_test` | 52, 0 | `9FC703C4AB2986DDAAB73ED386092F3B8AB71A5EA82C4A7C3C781D2F6F06C0CC` |
| 329 | `kit_seam_hooks_v2_test` | 38, 0 | `5182F32B62DE14BE5938AF67C615BFBC0CBB6BDF062A64EDB08131758CF6FA5A` |
| 332 | `flank_test` | 205, 0 | `D23DC5D7B03B0FE0742A8C62D00F0A0F8438F0DC30F43DC1FD5CDE9D4244C02A` |
| 333–335 | os três testes novos | acima | acima |

Os hashes de `flank_test`, `e06_rx_mob_ai`, `e07_f6_threat`, `e07_f6_snapshot`, `e08_compact_*` e
`e07_f3_snapshot` são iguais aos do recibo da T6.

O `kit_seam_hooks_v3_test` exige o projeto de fixture F1:
- primeiro `e07_f1_import_test` (passo 256), saída
  `3F340AD4352F3B4C8FE7C390610A3307690BFE5FDBA00DCE249F34106AC431C8`;
- depois o passo 330 com `-F1Fixture`: **63 checks, 0 falhas**, saída
  `D1DFD323C350F8F63140F3D8D86FE01FB566BAEE11ED3A93B953FBF99F78F449`.

### Falhas esperadas (A9 e A17, donos T9)

Com `ready_for_play`, só os testes de lista falham. Cada um foi rodado à parte, porque o verificador
para na primeira falha. Nenhum dos dois foi editado.

| Teste | Resultado | Motivo | Saída (sha256) |
|---|---|---|---|
| `e05_evolution_catalog_test` (passo 108) | 2 de 55; **1 `SCRIPT ERROR`, na linha 47** (`Invalid access to property or key 'sp_la'`) | listas exatas de destinos: "twelve accepted E00 identities" e "four destinations of the fixed origin" (A9) | `F26707F5072841BA9504E591510A78C1D26DC7DD7BEA850CACE8E64069474709` |
| `kit_seam_test` (passo 331) | 189 checks, 3 falhas | "sp_la skeleton is empty and not ready", "sp_la skeleton validates and stays unavailable" e "unready kits are not offered (C1.3)": checks de esqueleto de produção (A17) | `1CB57A67E52E8681C0DFCCE4FD748800555509E1E5A6510563A077A1F0D5558C` |

A T9 já entregou a troca desses checks (recibo `c252342e`). Na composição da T10, eles passam a
aceitar o `sp_la` pronto.

### Busca nas saídas

Busquei `SCRIPT ERROR` e `still in use` em todos os `.output.log` e `.engine.log` das cinco
rodadas:
- **um único `SCRIPT ERROR`**, o esperado da linha 47 do e05, no par output/engine do mesmo passo;
- **nenhum** `still in use`.

Antes do commit, restaurei ou apaguei o que a importação regerou fora das minhas pastas: os
`.import`, os `.gd.uid` e a DLL do GitPlugin. Os três `.gd.uid` dos testes novos ficaram, como na
K1.

A suíte completa não foi repetida. A K3 não toca arquivo compartilhado. O que ela acrescenta ao
caminho dos outros testes é o fragmento de snapshot do kit e o kit pronto no `ProfileCatalog`, e os
passos de snapshot, compacto e catálogo do Espadachim e do Defensor acima cobrem os dois.

## Limitações

1. **Recuo no mapa plano (limitação 1 da T6).**
   - Perder de vista age só sobre a ameaça. A aquisição pela posição não conhece o observador, então
     um inimigo perto continua atacando. Ali o Recuo vale pela distância e pela janela de guarda.
   - O teste prova as duas metades: a ameaça sem visão e `can_be_acquired_by` verdadeiro.
   - No mundo vale `can_be_acquired_by_world`. O Recuo **não foi testado no mundo**; a T6 provou a
     perda de visão no mundo com a fixture F1.
2. **Passos no mundo.** Finta e Recuo movem por `trace_ground` e `WorldActorMotion.teleport`, como o
   `teleport_behind` da T6, mas só o mapa plano tem teste. A intenção de viagem privada do jogador não
   é alcançável pela costura (limitação 3 da T6): no plano, um alvo de caminho pendente pode
   continuar.
3. **Área.** Nenhum inimigo atual produz `area`. A recusa foi testada republicando um golpe real como
   área pelo caminho do `RunController`.
4. **Lado dos golpes da base.** Corte e ativas de item não passam por `mark_request`, porque o pedido é
   montado pela base. O lado é lido no resultado confirmado; no Corte, é o mesmo frame do commit.
5. **Apresentação.**
   - O aparo bem-sucedido publica `presentation_fact(skill_committed, duelist_parry)` no jogador. O
     flash é o mesmo efeito do commit do Aparo.
   - O giro aparece no próprio sprite (override da T1). Não há efeito próprio de giro, nem da marca da
     Sentença fora do `duelist_riposte_strike`.
   - `see_through` não é desenhado (limitação 4 da T6).
   - Nenhum efeito foi conferido por captura. Ícones (T3) e corpo (T7) chegam na T10; nesta branch
     vale o corpo da origem.
6. **Robô do chefe.** O teste lê o `attack_cooldown` do chefe para cronometrar o Aparo. Ele prova que
   o laço fecha e que o kit vence, mas não mede a dificuldade humana do ritmo, que é aceite de
   playtest. O chefe de teste bate pouco: o Duelista termina com 452 e 481 de 482 de HP.
7. **Leitura no rank 0.** Sem a passiva, nenhuma fonte de Sentença conta. As duas builds têm a
   Leitura, e o Riposte exige Leitura 1.

## Próximo passo

A T10 compõe a branch: o fragmento `scripts/classes/sp_la/snapshot_manifest.json` entra no
`include_filter` (A10), com as listas da T9 já atualizadas.
