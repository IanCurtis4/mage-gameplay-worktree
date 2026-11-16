# E09 K2 — Recibo de entrega do kit do Taumaturgo (`mg_ac`, C4)

Executor: Sol (sessão de tarefa K2, Opus 5.5, esforço médio), 16/11/2026. Contrato curto com os
números e as cinco perguntas: [k2_contract.md](k2_contract.md). APIs usadas: costura de
T1/T1.1/T1.2 ([t1_kit_seam_api.md](t1_kit_seam_api.md)) e Santuário/Graça de T5
([t5_delivery.md](t5_delivery.md)). Referência: K1/K1.1 (`021bdc6a`, `6e37da52`), só leitura.

## Identificação

| Campo | Valor |
|---|---|
| Base (`git merge --ff-only`) | `d855cde9f8ab38151d5c4ae916945a96e848abc8`, ponta entregue da T5 em `claude/pensive-wilson-bf9141` (inclui T1, T1.1 `bd66d3c3` e `771a314f`) |
| Merge da T1.2 (`--no-ff`) | `4fbfd9db26a1b753b53ba48cc21fa3fff74178c9`, ponta da T1 em `claude/mystifying-moser-f04ddc` (T1.2 e A14); commit de merge `dc059e314659f4910faadd5f5482dee96133241e` |
| Branch | `claude/cranky-satoshi-2f273f` |
| Checkout real | `C:\Users\João Pedro\Documents\ChatGPT\RagRPG\.claude\worktrees\cranky-satoshi-2f273f` |
| SHA entregue | o commit que introduz este recibo (a mensagem final da sessão traz o SHA) |

Sem push, sem `master`, sem tocar no playtest habitual nem no save pessoal. Só perfis de fixture
em memória.

## Escopo entregue

Todos os arquivos estão dentro do dono exclusivo da K2:

- `scripts/classes/mg_ac/mg_ac_kit.gd`: o módulo, com:
  - as 7 skills (`Handler.KIT`, elemento `light`) e as linhas de aprendizado; a entrada do job 20
    sem `prerequisites`;
  - a passiva de ATQ mágico do Prisma (`passive_modifier_source`);
  - receitas de feedback (elemento `arcane`, porque `FeedbackRecipeCatalog.ELEMENTS` não tem
    `light`) e textos pt-BR (nome, efeito, interação, mecânica e uma linha de tooltip por rank em
    `skill_texts()[id]["ranks"]` e na `mechanics`);
  - os 9 desenhadores de efeito e todos os ganchos;
  - `skill_cost` (Aurora, metade do SP, leitura pura) e `on_base_skill_committed` (feitiços de
    fogo, gelo e raio da base), ambos da T1.2, sem reembolso e sem detecção por recarga;
  - `ready_for_play() == true`, ligado depois dos testes abaixo (A7).
- `scripts/classes/mg_ac/snapshot_manifest.json`, revisão 2.
- `scripts/classes/mg_ac/review_builds.json` (A11, `ragrpg_review_builds_v1`).
- `tests/classes/mg_ac/mg_ac_kit_test.gd` e `tests/classes/mg_ac/mg_ac_boss_combat_test.gd`.
- `docs/epics/e09/k2_contract.md` e este recibo.

Nenhum arquivo compartilhado, sistema, registro, ator, teste da T9 (A9) ou `docs/epics/e09.md` foi
editado. Nenhuma política `KIT_RULE` de item (A10). O kit não precisou nomear `EnemyActor`.

## Números finais

Estão no [contrato](k2_contract.md), §3. Em resumo:

| Skill | Núcleo | R1 → R5 (ou R3) |
|---|---|---|
| Círculo Votivo | zona `votive` em círculo no chão; o 1º feitiço de elemento dentro define o altar; queima de luz por pulso de 1 s | 18→22 SP, rec. 12 s, 8→12 s, raio 120→140, queima 10→18% ATQ mág., gelo +10→18% DEF, raio +0,40→0,80 SP |
| Prisma Votivo | ATQ mágico; alternância dentro do círculo rende Graça | +3/6/9%, 1/1/2 Graça |
| Refração Curativa | gasta até 5 cargas; cura limitada ao HP que falta; onda do elemento do círculo | 20→24 SP, rec. 8 s, cura 60→100%, onda 50→90% ATQ mág. |
| Mudança de Altar | fogo → gelo → raio; pulso do elemento antigo (`pulse_now` + choque) | 16→20 SP, rec. 10→8 s, choque 40→80% ATQ mág. |
| Coro dos Elementos | três elementos diferentes em sequência: tricolor | 3/4/5 s |
| Juízo Prismático | coluna de luz em três pulsos (fogo no commit ×1,25; gelo +0,3 s com lentidão; raio +0,6 s com SP) | 26→30 SP, rec. 9 s, alcance 320, 50→90% ATQ mág. por pulso |
| Aurora Convergente | círculo × 1,6 e tricolor, Graça sem limite, feitiços dentro pela metade do SP | 40→48 SP, rec. 60→48 s, 6→8 s |

Base Mago: Bola de Fogo, Lança de Gelo e Relâmpago (e as demais de fogo, gelo e raio) definem o
altar, alternam e alimentam o Coro quando lançados dentro; fora, zeram a sequência. A Barreira
Fantasma protege, não conta como elemento e custa metade na Aurora.

## IDs de flipbook reservados (C4.4)

`thaumaturge_votive_circle`, `thaumaturge_votive_burn`, `thaumaturge_refraction_wave`,
`thaumaturge_refraction_hit`, `thaumaturge_altar_pulse`, `thaumaturge_altar_shock`,
`thaumaturge_judgment_mark`, `thaumaturge_judgment_column`, `thaumaturge_dawn_circle`. Os tipos de
evento estão no contrato, §5. Hoje todos são desenhados em código por `draw_vfx`; um flipbook em
`assets/art/e08_vfx/<id>/` substitui o desenho pelo mesmo ID.

## Builds nomeadas (C4.2, A11)

| ID | Nome | Base (19 pontos) | Evolução (20 pontos; ranks finais) |
|---|---|---|---|
| `thaumaturge_prism_altar` | Altar Prismático | Bola de Fogo 5, Lança de Gelo 5, Relâmpago 5, Barreira Fantasma 2, Regeneração de SP 2 | Círculo 5, Prisma 3, Refração 2, Altar 4, Coro 3, Juízo 3, Aurora 1 |
| `thaumaturge_dawn_choir` | Coro da Aurora | Bola de Fogo 4, Lança de Gelo 3, Relâmpago 3, Parede de Fogo 2, Barreira Fantasma 3, Regeneração de SP 3, Teleporte 1 | Círculo 3, Prisma 2, Refração 4, Altar 2, Coro 2, Juízo 3, Aurora 5 |

Os mapas trazem o **rank final**. O R1 do Círculo é grátis: soma dos ranks 21 para 20 pontos. O
teste confere os pontos com `skill_points_spent` e a legalidade com `validate_purchased_ranks`.

## Validação

Motor: Godot 4.7.2 standard,
`C:\Users\João Pedro\Documents\ChatGPT\RagRPG\.tools\godot\Godot_v4.7.2-stable_win64.exe`,
chamado pelo PowerShell. Antes, `--headless --editor --import --quit` (saída 0; acusou
`Cannot get class 'GitPlugin'`, a falha conhecida de worktree nova).

### Testes novos

**`mg_ac_kit_test`** (177 checks, 0 falhas). Invariantes:
- catálogo, prontidão (A7), entrada sem pré-requisito, textos por rank, 9 IDs de efeito, receitas;
- as duas builds: 19/20 pontos, soma 21 com a entrada grátis, legalidade, atalhos;
- Círculo: R1 e R5; Barreira Fantasma não define nem conta; o 1º feitiço (Bola de Fogo) define o
  altar e não é alternância; o mesmo elemento duas vezes não rende; alternância +2 (Prisma R3) e
  +1 (R1); **Graça sem duplicação em retry** (o mesmo commit repetido rende uma vez); sem Prisma,
  nada; **fraqueza**: feitiço fora do círculo não rende e zera a sequência;
- regras do elemento: queima só dentro, fogo × 1,5, gelo como DEF real no breakdown sem cura e com
  lentidão, saída do círculo tira a DEF, raio acelera o SP;
- Refração: gasto no commit, cura exata limitada ao HP que falta, sem Graça por excedente da
  própria cura, onda só dentro, raio devolve SP, cast recusado não gasta, onda sem círculo;
- Altar: recusa sem círculo, ciclo fogo → gelo → raio → fogo, um pulso de queima e um choque, conta
  como alternância;
- Coro: tricolor por 5 s com a DEF do gelo, pausa congela, volta ao altar, sem a passiva não aciona;
- Juízo: gasto no commit, três pulsos em 0/0,3/0,6 s, pausa congela os pendentes, lentidão no gelo,
  SP no raio, fogo mais forte, × 3 com 5 cargas, recusa sem gasto, alvo morto não recebe mais;
- Aurora: círculo × 1,6 tricolor sem reiniciar relógios, Graça passa do teto, Círculo recusado,
  **`skill_cost` puro** (10 leituras sem mudar estado) com metade para kit e base, teleporte e a
  própria Aurora inteiros, débito real pela metade, fora do círculo custo cheio, pausa congela,
  volta ao normal, Aurora sem círculo abre e fecha o próprio;
- **troca de build sem cura nem reset** (HP, SP, Graça, altar, sequência, recargas e zona);
- morte zera Graça, Aurora, círculo, altar, sequência e pulsos;
- **snapshot nos dois formatos (A5)**: o exato preserva o círculo ampliado tricolor, a Graça sem
  limite, o relógio da Aurora, o altar, a sequência e os pulsos do Juízo religados ao inimigo
  restaurado; o compacto é inelegível com Aurora (`thaumaturge_dawn`), pulsos
  (`thaumaturge_judgment`) e zona (`sanctuary_zone:votive`); sem eles é aceito e preserva Graça,
  modo sem limite e altar.

**`mg_ac_boss_combat_test`** (29 checks, 0 falhas). Chefe real `forest_ancient_warden` (categoria
boss), sem adds e sem augment, uma luta por build, atributos legais de nível 30 (INT 50, VIT 36,
DES 20, AGI 5, FOR 5, só na fixture). Os feitiços da base saem por `RunController._execute_skill`
e projéteis reais, avançados pelo teste. Resultado:

| Build | Duração | Chefe | Taumaturgo | Graça +/− | Elementos vistos |
|---|---|---|---|---|---|
| Altar Prismático | 25,7 s | 0/24000 | 762/822 | +26 / −14 | none, fire, lightning, tricolor |
| Coro da Aurora | 28,3 s | 0/24000 | 747/822 | +22 / −18 | none, fire, ice, tricolor |

O chefe tem 24000 de HP (o K1 usou 6000): só o Mago da origem (ataque básico e Bola de Fogo) tira
6000 em ~5 s, antes de o laço do kit girar. A Aurora entra depois do primeiro Juízo.

### Regressão por impacto (`tools/verify.ps1 -SkipEditorImport -F1Fixture -Test …`)

Rodada `k2_impact_3` (`.godot/verification/k2_impact_3/`), uma só, depois de
`e07_f1_import_test` gerar a fixture F1. `checks.jsonl` sha256
`4B2855C79B55179FD8B46E214DCFF6A3DF7543E26CFD3E6E1634EF9D804867FC`. Todos os passos PASS.

| Passo | Nome | Checks | sha256 da saída |
|---|---|---|---|
| 33 | `mage_gameplay_test` | 52 | `02D14E4B0067A2FC483B56F165EC8534C00262007966F3D45930D287E2919C5C` |
| 56 | `e04_fireball_rank_integration_test` | 35 | `9326670E30CF39122AA845B633136815F158E458ABE3CF9F00FFE58A1F7BEAF5` |
| 58 | `e04_fire_spear_rank_integration_test` | 39 | `3EEF726FC0EBD1D7189F6CCF9D1E31237D929A40D78C457FB6EDC7D7AA5E04A6` |
| 59 | `e04_ice_spear_rank_integration_test` | 39 | `FFCA099282678509933D23DE73AB769C725A96023C96A48A24919D71ECC0C520` |
| 61 | `e04_mage_sp_regeneration_rank_integration_test` | 27 | `659126513A0D526F45380C06DDD459B6F3F22650012FD21D9A80B52F7C4B5BCF` |
| 88 | `e04_mage_lightning_rank_integration_test` | 66 | `E2157F7DA8B77E51583AB01A8A6D7B05DE070F730FBC35FDB3B53353E28F87A8` |
| 89 | `e04_mage_electric_discharge_rank_integration_test` | 71 | `A9CE5F6D1E4D39D695A573C7D49DAD58D26FC8E478885642B5840558B1162E08` |
| 90 | `e04_mage_lightning_wall_rank_integration_test` | 73 | `BD46420AC0BB2A65C2B6967850B46F0A6320D210C9EF3634BD2F93BB14651475` |
| 91 | `e04_mage_soul_impact_rank_integration_test` | 64 | `C751CFDD91EA6267BE27022FDF58C16334919B5E407D2121B0B46168E234A091` |
| 92 | `e04_mage_haunt_rank_integration_test` | 84 | `D7EA8FD4C215C75E808676A18C22F16678F428EB4D2A1F06FDC26A4DE765E886` |
| 93 | `e04_mage_phantom_barrier_rank_integration_test` | 78 | `C125F85DDB1E378F8953234045EC06233D81C98109F31702CA551CB4192833F1` |
| 94 | `e04_mage_ice_wall_rank_integration_test` | 78 | `4DCAF3B16BA063735CB2674540B7C4769E7E4D8D0F7082F25172F0C92568DD46` |
| 95 | `e04_mage_integrated_closure_test` | 106 | `0A72FA1BB32A0B5B87B6DF1801371598E8D0400468A8EAA11FC00A29CB3A61E4` |
| 115 | `e05_elementalist_catalog_migration_test` | 11 | `A6D1A2D19B9B09B462855E797127F70E12B4C84B85C397C0E4B510B55E3E5DD5` |
| 163 | `e05_elementalist_catalog_test` | 99 | `C450AA9D5A3BB66D916777011949B003A117C5088BF49FB8A1999137FBEF0905` |
| 164 | `e05_elementalist_animation_test` | 7 | `7052D244DF3253350A7211DE5AE2DF14FC43A08C03E0B717635F92BED82E0816` |
| 165 | `e05_elementalist_visuals_test` | 8 | `7802A119488B1BF36E643F06572003268F16FEAB28B2A361180DFDC43B9D0A9B` |
| 166 | `e05_elementalist_visual_integration_test` | 7 | `6FC87453528A49625999DC8B3650B0F1C139CFA647C371D4E26D321D899C526A` |
| 167 | `e05_elementalist_indicators_test` | 13 | `2D3A9F87A208444E2A1C59427D8C20D9D1A462AA77FAE12BACFFC17D6F852C35` |
| 168 | `e05_elementalist_flame_burst_test` | 10 | `C11B92638571489CF7CD29739B105F36D0A70D13767689ECD218885CB4438203` |
| 169 | `e05_elementalist_prismatic_focus_test` | 16 | `8BA67248556398B9CEF4D33067FD172DB9839F7BFCFCFE57300A3CA4AC988FD2` |
| 170 | `e05_elementalist_glacial_ring_test` | 11 | `0B86D58F19545FE0BF07CFB42088E4E4E81F635B0D7F4EC44E9CFA45C555F6B9` |
| 171 | `e05_elementalist_lightning_arc_test` | 16 | `7718F760D59EC6DC725F1B17DBE2F4C983EB0CB1B1D8C81B33AC39EC902FE197` |
| 172 | `e05_elementalist_prismatic_resonance_test` | 15 | `2AC6818F17F54BDCD997B4BDB5D8BA0A4E86F6A40D72A7A0EDDA98F32A232873` |
| 173 | `e05_elementalist_ember_path_test` | 11 | `31E72DF3091738F1937ACA6F82297265C78A36E3219C286273EBDBB5F70DF20B` |
| 174 | `e05_elementalist_tri_nova_test` | 12 | `3B37EC5DFE5B738EC03C122ACC0BC2E8F66BFAE1884BB24EA39B2A019EB37AC6` |
| 175 | `e05_elementalist_integrated_closure_test` | 41 | `C636C58979311C7EB480B3BA6074BC86B8B0A34961BF9E64456253B81BCE284B` |
| 268 | `e07_f6_threat_test` | 43 | `C38ACB2F6A0A4F101776B095EE0A68791A65E72A12D77D5317B2EB793EFA2AD3` (= T5) |
| 270 | `e07_f6_snapshot_test` | 40 | `2E091952F53115A75311BF2F4CFD595A18B2E8C64FA3076CBF6F844F4CC4EDC6` (= T5) |
| 282 | `e08_compact_checkpoint_test` | 48 | `346B73697BFB3C1975A5B0B2196C99CC96AE95E389DFA441C3EDBDC5FFDCA1EC` (= T5) |
| 283 | `e08_compact_coverage_test` | 95 | `3C65ADD205F98F2D063AFCF6DAD256C3F207D51AAE7376621D38801D89228796` (= T5) |
| 294 | `e07_f3_snapshot_test` | 52 | `9FC703C4AB2986DDAAB73ED386092F3B8AB71A5EA82C4A7C3C781D2F6F06C0CC` (= T5) |
| 329 | `kit_seam_hooks_v2_test` | 38 | `5182F32B62DE14BE5938AF67C615BFBC0CBB6BDF062A64EDB08131758CF6FA5A` (= T1.1) |
| 330 | `kit_seam_hooks_v3_test` | 63 | `D1DFD323C350F8F63140F3D8D86FE01FB566BAEE11ED3A93B953FBF99F78F449` |
| 332 | `sanctuary_test` | 155 | `01B74920641522D9B9004D6B7394D056DA28F6F8E2D352E04113B0B605F13A6F` (= T5) |
| 333 | `mg_ac_boss_combat_test` | 29 | `66AC49C680CB0D1B0D3010F43033B57F4F4256DCB7215D1DBA5A250CADF8C0FF` |
| 334 | `mg_ac_kit_test` | 177 | `814D744C0A070565A8852188C85964CDC1B45BC5093AE152BC3E794C3EE152B5` |

O `WARNING: compact cut rehearsal failed` do passo 282 é o caminho de falha que o próprio teste
exercita. A rodada `k2_impact_1`, sem `-F1Fixture`, parou no passo 330 por falta da fixture F1
(`F1 world fixture is current`); não é defeito e ficou como histórico.

### Falhas esperadas (A9)

Rodadas separadas (`.godot/verification/k2_a9_<teste>/`), com `ready_for_play` ligado. Os dois
arquivos são da T9 (A9) e não foram editados.

| Passo | Teste | Resultado | sha256 da saída |
|---|---|---|---|
| 108 | `e05_evolution_catalog_test` | FAIL, 1 de 55; 1 `SCRIPT ERROR` na linha 47 (`_check_production_roster`: chave `mg_ac` ausente no `expected`) | `11F2D61E22AE4B2494D716496D3900B656774F6C4A39F407F8EB10B663A66036` |
| 331 | `kit_seam_test` | 189 checks, 5 falhas | `226313E529DFFA7C65F8EEB671340E1958AF9BB0E1924A5A4C8B951A995B3219` |

As 5 falhas do `kit_seam_test` vêm todas de o `mg_ac` deixar de ser esqueleto, a mesma classe que
o K1 registrou para o `sp_ac`:
- "mg_ac skeleton is empty and not ready" e "mg_ac skeleton validates and stays unavailable";
- "unready kits are not offered (C1.3)" e "other origin unchanged": a lista e a contagem de
  destinos do Mago;
- "forcing an empty skeleton ready is refused": o teste usa o `mg_ac` como o esqueleto vazio. A T9
  precisa trocar esse sujeito por um kit ainda não pronto (`sp_la` ou `mg_la`) quando atualizar as
  listas.

Busca por `SCRIPT ERROR` e `still in use` nas saídas e logs do motor da regressão: **0 ocorrências** na rodada `k2_impact_3`, sem timeout. Os únicos `SCRIPT ERROR` são o esperado do e05, acima.

## Limitações

1. **Cor do círculo no chão.** `draw_vfx` é chamado por evento e o módulo de catálogo não lê o
   estado da run. O círculo aparece tricolor (vitral) no cast, os pulsos de queima e a onda são
   desenhados nos alvos, mas a cor **persistente** do círculo não segue o elemento. Pede um gancho
   de apresentação com estado (por exemplo, `pulse.element` vindo do kit), fora do dono da K2.
2. **Refração nunca usada no combate integrado:** o chefe não baixou o HP abaixo de 60%. Ela é
   coberta pelo `mg_ac_kit_test`.
3. **Juízo:** os pulsos 2 e 3 são tiques agendados secundários; um alvo morto cancela os
   restantes, e a coluna acompanha a posição atual do alvo.
4. **Barreira Fantasma** no teste de chefe não tem o produtor ligado (o sinal
   `phantom_barrier_requested` não é conectado na fixture); só o custo e a não contagem são
   provados.
5. **Arte:** sem ícones (T3) e com o corpo da origem (T7 entra na integração).
6. **Mundo da expedição:** os testes do kit usam o mapa plano; a pertença do círculo no mundo é a
   de T5 (`WorldEffectArea`), já testada em `sanctuary_test`.
7. **Escopo da supervisão:** execução, conclusão, erros, hashes e as invariantes do contrato. Não é
   auditoria semântica independente.

## Arquivos não commitados

`.import` reescritos pelo editor (fim de linha), a DLL `~libgit_plugin…` apagada pela importação
(restaurada), `.gd.uid` gerados fora das pastas da K2 e `.godot/`.

## Próximo passo

- T10 compõe a K2 em `claude/e09-candidato` (ícones da T3, corpo da T7, `include_filter` com o
  fragmento `scripts/classes/mg_ac/snapshot_manifest.json`).
- T9 atualiza as listas de destinos do Mago (A9), que hoje falham só por expectativa.
