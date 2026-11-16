# E09 K1 — Recibo de entrega do kit do Paladino (`sp_ac`, C4)

Executor: Sol (sessão de tarefa K1, Opus 5.5, esforço médio), 16/11/2026. Contrato curto com os
números e as cinco perguntas: [k1_contract.md](k1_contract.md). APIs usadas: costura de T1/T1.1
([t1_kit_seam_api.md](t1_kit_seam_api.md)) e Santuário/Graça de T5 ([t5_delivery.md](t5_delivery.md)).

## Identificação

| Campo | Valor |
|---|---|
| Base (`git merge --ff-only`) | `d855cde9f8ab38151d5c4ae916945a96e848abc8`, ponta entregue da T5 em `claude/pensive-wilson-bf9141` (inclui T1, T1.1 `bd66d3c3` e `771a314f`) |
| Branch | `claude/gracious-elion-f4b158` |
| Checkout real | `C:\Users\João Pedro\Documents\ChatGPT\RagRPG\.claude\worktrees\gracious-elion-f4b158` |
| SHA entregue | o commit que introduz este recibo (a mensagem final da sessão traz o SHA) |

Sem push, sem `master`, sem tocar no playtest habitual nem no save pessoal. Só perfis de fixture
em memória.

## Escopo entregue

Todos os arquivos estão dentro do dono exclusivo da K1:

- `scripts/classes/sp_ac/sp_ac_kit.gd`: o módulo. Ele traz:
  - as 7 skills (`SkillDefinition` com `Handler.KIT`, elemento `light`) e as linhas de
    aprendizado;
  - a passiva de DEF (`passive_modifier_source`);
  - as receitas de feedback e os textos pt-BR (nome, efeito, interação, mecânica e uma linha
    de tooltip por rank em `skill_texts()[id]["ranks"]` e na `mechanics`);
  - os 8 desenhadores de efeito e todos os ganchos;
  - `ready_for_play() == true`, ligado depois dos testes abaixo.
- `scripts/classes/sp_ac/snapshot_manifest.json`, revisão 2: `sanctuary`, `impact_charges`,
  `hour_remaining`, `hour_opened_zone`, `faith_applied` e `base_cooldowns`.
- `scripts/classes/sp_ac/review_builds.json` (A11, `ragrpg_review_builds_v1`).
- `tests/classes/sp_ac/sp_ac_kit_test.gd` e `tests/classes/sp_ac/sp_ac_boss_combat_test.gd`.
- `docs/epics/e09/k1_contract.md` e este recibo.

Nenhum arquivo compartilhado, sistema, registro, ator ou `docs/epics/e09.md` foi editado. O kit
não nomeia `EnemyActor` (A10). O dano recebido e a DEF do gelo usam os ganchos da T1.1 (A12), por
repasse à `SanctuaryAuthority`.

## Números finais

Estão no [contrato](k1_contract.md), §2. Em resumo:

| Skill | Núcleo | R1 → R5 (ou R3) |
|---|---|---|
| Juramento | zona `oath` em cone (55°), frontal × menos dano, queima de luz por pulso de 1 s | 20→24 SP, rec. 14 s, 6→8 s, raio 150→170, × 0,82→0,74, queima 12→20% ATQ |
| Graça de Guarda | DEF física; excedente de cura por carga; golpe frontal na Parede rende Graça | +4/7/10%, 7/6/5% HP |
| Impacto Consagrado | coluna de luz (raio 55), gasta até 5 cargas, × (1 + 0,40 × cargas) | 22→26 SP, rec. 5 s, 110→170% ATQ |
| Égide do Juramento | escudo da fórmula da Perseverança, um pulso de luz que empurra | 24→28 SP, rec. 16 s, base 50→110, pulso 60→100% ATQ |
| Fé Inabalável | dentro do Juramento: resistência a controle e cura | +0,10/0,15/0,20, × 1,10/1,20/1,30 |
| Selo do Condenado | marca + `force_target`; luz no selado rende Graça = valor (1–3) | 18→22 SP, rec. 14 s, 5→7 s |
| Hora do Juramento | cone → círculo, Graça sem limite, Impacto sem SP e no círculo inteiro | 40→48 SP, rec. 60→48 s, 6→8 s |

Base Espadachim: Parede de Escudos e Perseverança dão +1 Graça por uso; Provocar com Selo ativo
soma +1 ao Selo (máx. 3).

## IDs de flipbook reservados (C4.4)

`paladin_oath_cone`, `paladin_oath_burn`, `paladin_grace_rings`, `paladin_impact_column`,
`paladin_aegis_halo`, `paladin_aegis_pulse`, `paladin_seal_ring`, `paladin_hour_circle`. Os
tipos de evento estão no contrato, §4. Hoje todos são desenhados em código por `draw_vfx`. Um
flipbook em `assets/art/e08_vfx/<id>/` substitui o desenho pelo mesmo ID.

## Builds nomeadas (C4.2, A11)

| ID | Nome | Base (19 pontos) | Evolução (20 pontos; ranks finais) |
|---|---|---|---|
| `paladin_bulwark` | Baluarte da Luz | Parede 5, Perseverança 5, Provocar 3, Corte 3, Resistência 3 | Juramento 5, Graça de Guarda 3, Impacto 3, Égide 4, Fé 3, Selo 2, Hora 1 |
| `paladin_hammer` | Martelo Consagrado | Corte 5, Parede 3, Perseverança 3, Provocar 1, Fúria 4, Resistência 3 | Juramento 3, Graça de Guarda 2, Impacto 5, Égide 2, Fé 1, Selo 3, Hora 5 |

Os mapas trazem o **rank final**. Na evolução, o R1 do Juramento é grátis, então a soma dos ranks
é 21 para 20 pontos. O teste confere os pontos com `skill_points_spent` e a legalidade com
`validate_purchased_ranks` no job 40.

## Validação

Motor: Godot 4.7.2 standard,
`C:\Users\João Pedro\Documents\ChatGPT\RagRPG\.tools\godot\Godot_v4.7.2-stable_win64.exe`,
chamado pelo PowerShell. Antes, `--headless --editor --import --quit` registrou as classes novas.
Esse passo acusou `Cannot get class 'GitPlugin'` e saiu com código de falha ao fechar, como na T1 e
na T5 (worktree novo). Os passos abaixo rodaram com `-SkipEditorImport`.

### Testes novos

- **`sp_ac_kit_test`** (passo 333): 162 checks, 0 falhas. Cobre:
  - catálogo: validação do registro, `ready_for_play`, `ProfileCatalog.is_valid()` com o Paladino
    pronto, 7 skills e ranks, textos e tooltip por rank, 8 efeitos com prefixo, receitas;
  - as duas builds: esquema, 19/20 pontos e legalidade no job 40;
  - Juramento: números de R1 e R5; o golpe frontal no cone sai × 0,74 e rende +1 Graça; o golpe
    pelas costas não é reduzido e não rende; a queima de luz sai por `DamageRequest`;
  - **Graça sem duplicação em retry:** o mesmo resultado repassado de novo não rende;
  - cura excedente (5% com Graça de Guarda R3, 8% sem ela); cura sem excedente não rende;
    Parede de Escudos com e sem a passiva;
  - Impacto: dano base com 0 cargas; gasta 5 no commit; no máximo 5 por cast, com sobra; cast
    recusado não gasta; custo de 26 SP fora da Hora;
  - Égide: capacidade pela fórmula da Perseverança; um único pulso de luz;
  - Fé: resistência a controle e cura × 1,30 dentro do Juramento; o atordoamento dura menos;
    tudo sai com a zona;
  - Selo e base: valor 1 → Graça 1; Provocar soma até 3; Graça 3 no Selo cheio; Parede e
    Perseverança +1 uma vez cada; baixar a Parede não rende;
  - Hora: cone → círculo sem reiniciar relógios; Graça acima de 5; Juramento recusado; golpe pelas
    costas reduzido; Impacto sem SP e no círculo inteiro; pausa congela; ao fim, volta ao teto;
    círculo próprio quando não há Juramento ou ele é curto; Juramento que sobrevive volta a cone;
  - **troca de build sem cura nem reset:** HP, SP, recarga, Graça e zona intactos; a pausa
    congela; a morte encerra tudo e zera a Graça;
  - **suspensão e retomada nos dois formatos:** o exato preserva círculo, Graça sem limite, Hora,
    Fé, vigia da base e Selo no inimigo restaurado; o compacto é inelegível com a Hora
    (`paladin_hour`) e com a zona; sem eles, preserva Graça, modo sem limite e vigia.
- **`sp_ac_boss_combat_test`** (passo 332): 25 checks, 0 falhas. É o **combate integrado curto contra
  o chefe** `forest_ancient_warden` (categoria boss, `trial_stage_4`), com IA própria e sem adds:
  o sinal de companheiro não está ligado, e o teste confere 1 inimigo no fim. Não há augment. Os
  atributos são uma distribuição legal de nível 30 (VIT > FOR > INT), e o HP do chefe é fixado em
  6000 para o combate durar. Resultado com cada build:

  | Build | Tempo | Chefe | Paladino | Casts | Graça |
  |---|---|---|---|---|---|
  | `paladin_bulwark` | 27,3 s | morto | 994/1012 | Juramento 2, Selo 2, Hora 1, Impacto 5, Perseverança 3, Provocar 2 | +29 (máx. 15), 19 gastas |
  | `paladin_hammer` | 24,7 s | morto | 998/1012 | Juramento 2, Selo 2, Hora 1, Impacto 5, Perseverança 2, Provocar 2 | +29 (máx. 15), 19 gastas |

  O teste confere que os golpes do próprio chefe renderam Graça (chaves de evento das raízes dele).

`ready_for_play = true` foi ligado depois que os dois passaram. As rodadas finais já têm o valor ligado.

### Regressão por impacto (`tools/verify.ps1 -SkipEditorImport -Test …`)

Rodada `.godot/verification/k1_impact_2/`, `checks.jsonl` sha256
`5E4D920B05AB23D5AACDD94534753B5429CCFA96FD8428B4706193C5D3E998A3`. Plano de 333 passos; 18
selecionados; todos PASS. A rodada `k1_impact_1` parou no passo 96: o pré-requisito do
Juramento deixava o `ProfileCatalog` inválido (limitação 3). A correção está nesta entrega.

| Passo | Nome | sha256 da saída |
|---|---|---|
| 96 | `e04_swordsman_shield_wall_rank_integration_test` | `A177365260FF37996E22544E992784664A4F68B00B2763E1EF3D71800E87DABD` |
| 97 | `e04_swordsman_provoke_rank_integration_test` | `0A4606F1571D6BA169F5F5B69A37E2603FBDC259E38F9690F7339935FB3CB9A1` |
| 98 | `e04_swordsman_perseverance_rank_integration_test` | `2E7A612D23586A95F94128BC9F443CA075D292102C4F71CB6094486A032D4241` |
| 106 | `e04_swordsman_integrated_closure_test` | `F665A9A22AE1952881CE1C875A352CD947782AA7E988D05C7842F6132943DBD4` |
| 186 | `e05_defender_catalog_test` | `0CC3FF660876BBC226671D7B9B96E6392C86B11C37A25700F08475EC9B7F052C` |
| 188 | `e05_defender_guard_test` | `3593F6915E417D89309B6242D7A57394EA1CCB3CF49B601A7F3ABA9BF565F015` |
| 189 | `e05_defender_skills_test` | `E7D81B2C6E5ADFD0B7929A7B1E28B3EE5A195BFEB56B980F7E58BD06531E9AB9` |
| 191 | `e05_defender_builds_test` | `9A3AE53C622C97FDC1DD99695101E5521E4DB02FDBFBFC46322665EE0389AE05` |
| 244 | `e06_swordsman_cluster_test` | `8E2D07CE0755B724FAD6FFAB22CB9D3743A1C1EE661707CD0CA4C3BF8B53FF74` |
| 268 | `e07_f6_threat_test` | `C38ACB2F6A0A4F101776B095EE0A68791A65E72A12D77D5317B2EB793EFA2AD3` (igual ao da T5) |
| 270 | `e07_f6_snapshot_test` | `2E091952F53115A75311BF2F4CFD595A18B2E8C64FA3076CBF6F844F4CC4EDC6` (igual ao da T5) |
| 282 | `e08_compact_checkpoint_test` | `346B73697BFB3C1975A5B0B2196C99CC96AE95E389DFA441C3EDBDC5FFDCA1EC` (igual ao da T5) |
| 283 | `e08_compact_coverage_test` | `3C65ADD205F98F2D063AFCF6DAD256C3F207D51AAE7376621D38801D89228796` (igual ao da T5) |
| 294 | `e07_f3_snapshot_test` | `9FC703C4AB2986DDAAB73ED386092F3B8AB71A5EA82C4A7C3C781D2F6F06C0CC` (igual ao da T5) |
| 329 | `kit_seam_hooks_v2_test` | `5182F32B62DE14BE5938AF67C615BFBC0CBB6BDF062A64EDB08131758CF6FA5A` (igual ao da T1.1) |
| 331 | `sanctuary_test` | `01B74920641522D9B9004D6B7394D056DA28F6F8E2D352E04113B0B605F13A6F` (igual ao da T5) |
| 332 | `sp_ac_boss_combat_test` | `269571175CE4E29BCE0FFE76F032F348A6F9E9773BF33C82E3B7C81FA0719DA6` |
| 333 | `sp_ac_kit_test` | `9C58DE88EE9D2EC2BF4CB1DEA78A1F170E4A21153BA22540213E1BF1010A63B5` |

Busca por `SCRIPT ERROR`, `still in use`, `Parse Error` e `Compile Error` nas saídas e nos logs do
motor desta rodada: **0 ocorrências**.

### Falhas esperadas pela A9 (listas de destinos, donas da T9)

Rodadas isoladas, porque o verificador para na primeira falha:

| Passo | Nome | Resultado | sha256 da saída |
|---|---|---|---|
| 108 | `e05_evolution_catalog_test` | FAIL 2 de 55 | `23F5CDB77407F60B801CCC20B56A4D9D289DA3A7E40E4E7A05B540824F9BD648` |
| 330 | `kit_seam_test` | 175 checks, 5 falhas | `5108BF7FCBF1091DF162695CA61653B78CF4882898B2A12BB6BFCBE2BDFE51CE` |

- `e05_evolution_catalog_test`: "doze identidades em ordem" (o roteiro de produção agora tem o
  `sp_ac`) e "quatro destinos da origem" (o Espadachim agora tem cinco). Na linha 47, o dicionário
  `expected` não tem a chave `sp_ac`, e o acesso gera **1 `SCRIPT ERROR`**, que interrompe
  `_check_production_roster` (as checagens seguintes dessa função não rodaram). É o mesmo motivo:
  a lista de destinos.
- `kit_seam_test`: "sp_ac skeleton is empty and not ready", "…validates and stays unavailable",
  "unready kits are not offered", "unready skeletons publish no skills" e "job name falls back…"
  (`evolution_definition(&"sp_ac") == null`). Todas esperam o esqueleto vazio da T1 ou a lista do
  Espadachim sem o Paladino. Nenhum `SCRIPT ERROR` nem `still in use`.
- Pela A9, esses arquivos são da T9, e a K1 não os editou. Ficam para a integração (T10), que
  pode fazer merge da T9. A T9 ainda não tinha entregue quando esta tarefa terminou.

## Limitações

1. **Base sem gancho.** A costura não avisa quando uma skill da base é usada. O kit percebe a
   Parede de Escudos, a Perseverança e o Provocar pelo **aumento da recarga canônica** no
   `on_tick`, o que tem duas consequências:
   - o efeito vale no primeiro tick depois do commit;
   - o alvo do Provocar não é conhecido, então "Provocar soma ao Selo" vale para qualquer
     Provocar com Selo ativo.
   Um gancho `on_base_skill_committed(player, skill_id, target)` na costura (T1) eliminaria as
   duas consequências.
2. **Impacto sem SP na Hora.** O SP é devolvido no próprio commit (custo líquido zero). Ainda é
   preciso **ter** o SP do rank para lançar, porque `_can_pay_skill` confere o custo antes do kit.
   Um gancho de custo na costura resolveria isso.
3. **Juramento sem pré-requisito.** O `ProfileCatalog` não aceita pré-requisito comprado no rank
   grátis da entrada. O exemplo da API de T1 (`{&"shield_wall": 2}` no Juramento) deixaria o
   catálogo inválido.
4. **Elemento de feedback.** `FeedbackRecipeCatalog.ELEMENTS` não tem `light`; as receitas usam
   `arcane`. A regra de dano usa `SkillDefinition.element = light`.
5. **Arte.** Os ícones das 7 skills vêm da T3 na integração; ausentes nesta branch, como esperado.
   O corpo do Paladino vem da T7; até lá vale o corpo da origem (Espadachim). Os efeitos são
   desenhados em código e não foram capturados em tela nesta tarefa.
6. **Combate integrado.** O chefe roda com HP fixado em 6000, e o sinal de companheiro fica
   desligado para não haver add. O cenário é no mapa plano: o mundo da expedição só foi coberto
   pelo caminho de código da T5 (`judgment_targets` com `ExpeditionWorldPoint`), sem teste próprio
   da K1. Também não há cobertura no build exportado (o `include_filter` é da T10, limitação 3
   da T1).
7. **Supervisão.** Execução, conclusão, erros, hashes e as invariantes de C4. Não é auditoria
   semântica independente nem certificação de equilíbrio. Os números são ajuste de playtest.
8. **Suíte completa** não repetida: a K1 não toca arquivos compartilhados.

## Arquivos não commitados

Como na T1 e na T5, ficam fora do commit:
- os `.import` reescritos pelo editor (só fim de linha);
- os `.gd.uid` soltos em `docs/map_editor/delivery/evidence/**` e
  `tests/e08_compact_coverage_test.gd.uid`;
- `.godot/`.

## Próximo passo

- T9 atualiza as listas de destinos (A9). T3 traz os ícones e T7 o corpo.
- T10 compõe e roda a suíte completa.
- Ganchos opcionais para a arquitetura avaliar: as limitações 1 e 2.
