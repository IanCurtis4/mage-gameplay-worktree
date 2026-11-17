# E09 K3 — contrato curto do kit do Duelista (`sp_la`)

Executor: Sol (sessão K3, Opus 5.5), 16/11/2026. Fontes: ficha do Duelista em
[HYBRIDS_56_V3](../../HYBRIDS_56_V3.md) (e a decisão de 14/11 sobre o aparo com janela de tempo),
a ficha do Assassino em [EXTENDED_CLASS_SPECS](../../EXTENDED_CLASS_SPECS.md),
[e09_contract.md](../e09_contract.md) §1, §4 (C3) e §5 (C4, K3), as decisões A4, A5, A9–A13 de
[e09.md](../e09.md), a costura de T1 com T1.1 e T1.2 ([t1_kit_seam_api.md](t1_kit_seam_api.md)) e a
autoridade de costas da T6 ([t6_contract.md](t6_contract.md), [t6_delivery.md](t6_delivery.md)).

O núcleo da ficha não muda: **o Duelista não some antes da luta; é o aparo que cria as costas e a
ocultação.** Um golpe corpo a corpo de frente aparado dentro da janela gira o atacante e o faz
perder o Duelista de vista; a decisão continua sendo executar (Riposte Fatal) ou sair (Recuo em
Guarda) para aparar de novo. Os números abaixo são ajuste de playtest (preâmbulo de C3/C4).

## 1. Cinco perguntas (C4.1)

| Pergunta | Resposta |
|---|---|
| Distância | Corpo a corpo. O ataque básico é o da origem (Espadachim), marcado pela autoridade de costas (lado no commit). |
| Recurso | Sentença (0–5) no último aparado, da autoridade da T6, e a janela de aparo (tempo). SP para as ativas. |
| Abertura e fechamento | Abre com o **Aparo**; fecha com o **Riposte Fatal** (execução) ou com o **Recuo em Guarda** (saída). |
| Contra o chefe | Aparar os golpes corpo a corpo do chefe no ritmo dele; cada aparo gira o chefe (0,9 s, regra de chefe da T6) e o Duelista bate pelas costas. O Riposte no chefe é só dano alto (A4). Sem adds e sem augment, o laço fecha sozinho (teste integrado). |
| Fraqueza | Projéteis e áreas nunca são aparados, nem golpes de flanco ou de costas. Errar o ritmo deixa o golpe passar inteiro. |

## 2. Regras gerais do kit

- **Último aparado = vítima.** Todo aparo bem-sucedido (manual, Finta, automático ou Duelo) marca o
  atacante como vítima (`mark_victim` da T6). Marcar outro inimigo zera a Sentença do anterior
  (vítima única por dono, regra da T6).
- **Exposição.** O aparo chama `try_parry` com exposição: giro de 1,5 s e perda de visão de 1,2 s
  (padrões da T6; chefe × 0,6 = 0,9 s e 0,72 s).
- **Pedidos do kit.** Ataque básico, Riposte e estocada do Duelo passam por `flank.mark_request`
  (lado e abertura no commit). Nenhum pedido do kit sai sem a marca.
- **"Atacar"** (para a Guarda Paciente): o ataque básico, todo commit pago de skill da base
  (`on_base_skill_committed`, T1.2: Investida, Corte, Parede, Perseverança, Provocar, Fúria…), o
  commit do Riposte Fatal e cada estocada do Duelo. Aparo, Finta, Recuo, Duelo, receber golpe e
  aparar **não** contam.
- **Elemento.** Todas as skills são `physical`; o dano parte do **ATQ corpo a corpo** do
  `stat_breakdown` e passa por `CombatMath` (sem fórmula própria).

## 3. Skills e números por rank

Prefixo `duelist_`, IDs de C1.

### Aparo — `duelist_parry` (job 20, ativa, entrada; R1 grátis; sem pré-requisito)

Postura curtíssima: abre a janela de aparo da T6 com 1 carga. Um golpe corpo a corpo de frente
(±60°, regra da T6 aplicada ao Duelista) cujo impacto cai dentro da janela é cancelado inteiro.

| R | SP | Recarga | Janela |
|---|---|---|---|
| 1 | 4 | 1,2 s | 0,30 s |
| 2 | 4 | 1,1 s | 0,32 s |
| 3 | 4 | 1,0 s | 0,34 s |
| 4 | 3 | 0,9 s | 0,36 s |
| 5 | 3 | 0,8 s | 0,38 s |

- **O ritmo paga o Aparo:** um aparo pela janela aberta pelo próprio Aparo devolve o SP pago
  (`PlayerActor.recover_sp`). Janela que fecha sem aparo não devolve nada; Recuo, Duelo, Finta e o
  aparo automático não devolvem. Assim o spam custa SP e o aparo certo é de graça. (Ajuste do K3
  depois do combate integrado: com DES > AGI > FOR o `sp_regen` fica perto de 2,1/s, e um Aparo de
  8 SP por golpe do chefe secava o SP do Riposte.)

- Recusado durante o Duelo (`duelist_duel_active`): o Duelo já apara tudo de frente e uma janela
  curta o encurtaria.
- Golpe de projétil, de área, de flanco ou de costas não é aparado e não gasta a carga.

### Leitura do Oponente — `duelist_read_opponent` (job 23, passiva, R1–R3)

Liga as fontes de Sentença no último aparado (a vítima):

| Fonte | Cargas | Como |
|---|---|---|
| Aparo bem-sucedido | +2 | `gain(&"combo", "parry:<n>")`, uma vez por aparo |
| Golpe pelas costas | +2 | pedido do kit marcado `back`; golpe da base com o lado lido no resultado (abaixo) |
| Outro golpe direto | +1 | qualquer golpe direto com dano na vítima |

- Por golpe vale a maior fonte (regra da T6); a ocultação não é fonte do Duelista. Execução, DoT e
  golpe sem dano não geram. Retry do mesmo resultado não gera de novo (dedup da T6).
- **Golpes da base** (Corte, ativas de item) não passam por `mark_request`: o lado é lido no
  resultado confirmado, com o facing de gameplay do alvo naquele instante (para o Corte, o mesmo
  frame do commit). Costas dá +2; o resto, +1. Mesma chave de evento, mesmo dedup.
- O rank aumenta o dano dos pedidos do kit pelas costas **na vítima**: × 1,10 / 1,15 / 1,20
  (`damage_dealt_multiplier` do pedido, antes da mitigação do alvo).
- Sem a passiva, o aparo ainda marca a vítima, mas nenhuma fonte gera Sentença.

### Riposte Fatal — `duelist_fatal_riposte` (job 25, ativa, alvo único, ofensiva)

Execução de C3 (`flank.execute`): gasta toda a Sentença do alvo; dano = `ATQ × base × (1 + 0,40 ×
cargas)`. Com 5 cargas e HP do alvo no limiar da categoria (normal 30%, raro 24%, elite 18%,
raro-elite 12%), morte certa por `DamageRequest` de execução. **No chefe, nunca há morte certa:
só o dano escalado** (A4).

| R | SP | Recarga | Alcance | Base |
|---|---|---|---|---|
| 1 | 10 | 6 s | 90 | 150% |
| 2 | 11 | 6 s | 90 | 170% |
| 3 | 12 | 6 s | 90 | 190% |
| 4 | 13 | 6 s | 90 | 210% |
| 5 | 14 | 6 s | 90 | 230% |

- Pré-requisito: Leitura do Oponente R1.
- **Se matar** (abate confirmado com `first` e `execution`), o próximo Aparo é automático: por até
  8 s, o próximo golpe corpo a corpo de frente é aparado sem janela (abre a janela da T6 e chama
  `try_parry` no próprio golpe). Uma vez por abate; retry não arma de novo.
- Pode crítico fora da morte certa (regra da T6).

### Finta — `duelist_feint` (job 28, ativa, alvo único, defensiva)

Passo lateral de 48 px (para a esquerda do Duelista em relação ao alvo; se o chão não deixar, para a
direita; sem chão livre, a Finta ainda vale, sem passo). O alvo ganha a marca `duelist_feint`
(`ActorMarks`, dono = Duelista): **o próximo golpe corpo a corpo dele conta como aparado**, de
qualquer lado (o passo puxou o golpe para o lado). Projétil e área continuam fora. A marca some no
uso, no prazo ou com a morte do inimigo.

| R | SP | Recarga | Alcance | Duração da marca |
|---|---|---|---|---|
| 1 | 10 | 9,0 s | 220 | 2,50 s |
| 2 | 10 | 8,5 s | 220 | 2,75 s |
| 3 | 11 | 8,0 s | 220 | 3,00 s |
| 4 | 11 | 7,5 s | 220 | 3,25 s |
| 5 | 12 | 7,0 s | 220 | 3,50 s |

### Guarda Paciente — `duelist_patient_guard` (job 31, passiva, R1–R3)

Sem atacar (§2) por alguns segundos, em guarda (vivo), a janela de aparo aberta pelo Aparo e pelo
Recuo aumenta. O relógio corre em `on_tick` (congela na pausa) e não é consumido ao aparar.

| R | Sem atacar por | Janela |
|---|---|---|
| 1 | 3,0 s | +0,10 s |
| 2 | 2,5 s | +0,14 s |
| 3 | 2,0 s | +0,18 s |

A janela final respeita o teto da T6 (0,60 s): Aparo R5 + Guarda R3 = 0,56 s.

### Recuo em Guarda — `duelist_guarded_retreat` (job 34, ativa, própria, defensiva)

Passo de 80 px para trás (oposto ao facing; se o chão não deixar, 2/3 e depois 1/3 da distância;
sem chão livre, sem passo). Todo inimigo vivo a até 180 px do ponto de partida perde o Duelista de
vista (`break_sight` da T6). O Duelista mantém a guarda: abre a janela de aparo do rank atual do
Aparo (mais a Guarda Paciente), com 1 carga.

| R | SP | Recarga | Perda de visão |
|---|---|---|---|
| 1 | 10 | 10,0 s | 1,2 s |
| 2 | 10 | 9,5 s | 1,4 s |
| 3 | 11 | 9,0 s | 1,6 s |
| 4 | 11 | 8,5 s | 1,8 s |
| 5 | 12 | 8,0 s | 2,0 s |

- Chefe: perda de visão × 0,6 (T6).
- **Limitação 1 da T6, efeito no Recuo:** no mapa plano antigo, perder de vista age só sobre a
  ameaça; a aquisição pela posição não conhece o observador, então o inimigo que está perto continua
  atacando. Ali o Recuo vale pela distância e pela janela de guarda. No mundo da expedição o inimigo
  não adquire o Duelista enquanto dura a perda de visão (`can_be_acquired_by_world`).

### Duelo — `duelist_duel` (job 37, ativa, própria, defensiva)

Por alguns segundos, todo golpe corpo a corpo **de frente** é aparado automaticamente
(`open_parry_mode` da T6, cargas ilimitadas), e cada aparo devolve **uma estocada pelas costas** no
atacante que acabou de ser girado: `ATQ × força`, pedido do kit marcado (lado `back`), pelo
`kit_emit_hit`.

| R | SP | Recarga | Duração | Estocada |
|---|---|---|---|---|
| 1 | 30 | 50 s | 4,0 s | 90% |
| 2 | 32 | 48 s | 4,5 s | 100% |
| 3 | 34 | 46 s | 5,0 s | 110% |
| 4 | 36 | 44 s | 5,5 s | 120% |
| 5 | 38 | 42 s | 6,0 s | 130% |

- Pré-requisito: Aparo R3.
- Flanco, costas, projétil e área continuam acertando no Duelo.
- Com a Leitura, cada aparo no Duelo dá +2 (aparo) e a estocada +2 (costas) no último aparado.

### Interações com a base Espadachim (C4.3)

| Skill da base | No Duelista |
|---|---|
| Investida (`dash`) | "Para entrar": fecha a distância até o alcance do Riposte. O commit é "atacar" para a Guarda Paciente (T1.2). |
| Corte (`slash`) | "Em cone quando cercado": atinge os inimigos girados pelos aparos; na vítima rende +2 pelas costas (lado lido no resultado) ou +1. O commit é "atacar" para a Guarda Paciente. |
| Demais skills da base | Commit pago zera a Guarda Paciente; golpe direto na vítima rende +1 (ou +2 pelas costas). |

## 4. Estado, snapshot e pausa

- Variáveis do kit (fragmento `scripts/classes/sp_la/snapshot_manifest.json`, revisão 2): `flank`
  (autoridade da T6), `patience`, `duel_remaining`, `auto_parry_remaining`, `parry_serial`,
  `parry_refund`.
  Nenhuma referência de entidade: a vítima e a Finta vivem em marcas do inimigo (`flank_victim`,
  `duelist_feint`).
- Exato: tudo volta, inclusive janela, Duelo, aparo automático, vítima e Sentença com o inimigo.
  Compacto: elegível (o kit não cria zona nem entidade); o estado do jogador fica, as marcas do
  inimigo somem com ele (A5).
- Todos os relógios do kit avançam só em `on_tick` (congela na pausa); giro e perda de visão são
  relógios do inimigo e da ameaça (T1).
- Morte: janela, Duelo, aparo automático, devolução pendente e paciência acabam; a vítima perde a marca; as Fintas do
  dono são removidas. Troca de build: nada recarrega, nada cura, nada zera.

## 5. Efeitos em código e IDs de flipbook reservados (C4.4)

| ID | Skill | Tipo do evento |
|---|---|---|
| `duelist_parry_flash` | Aparo | `effect_start` (no commit do Aparo e a cada aparo bem-sucedido) |
| `duelist_riposte_lunge` | Riposte Fatal | `effect_start` |
| `duelist_riposte_strike` | Riposte Fatal | `impact` |
| `duelist_feint_step` | Finta | `effect_start` |
| `duelist_retreat_step` | Recuo em Guarda | `effect_start` |
| `duelist_duel_ring` | Duelo | `effect_start` |
| `duelist_duel_thrust` | Duelo | `impact` |

Receitas: família `buff` (defensivas e passivas), `impact` (Riposte) e `melee` (Duelo), elemento
`physical`, sem assinatura. O aparo bem-sucedido publica `presentation_fact(skill_committed,
duelist_parry)` no jogador (só apresentação). O giro aparece no próprio sprite do inimigo (override
de facing da T1).

## 6. Builds nomeadas (C4.2, A11)

`scripts/classes/sp_la/review_builds.json`, esquema `ragrpg_review_builds_v1`, com o rank final. Na
base não há rank grátis (soma 19); na evolução o Aparo tem R1 grátis (pontos 20, soma dos ranks 21).

| Build | Base (19) | Evolução (20 pontos) |
|---|---|---|
| `duelist_patient_blade` — Lâmina Paciente | Corte 5, Investida 5, Parede de Escudos 2, Perseverança 2, Resistência 3, Vigor 2 | Aparo 5, Leitura 3, Riposte 5, Finta 3, Guarda Paciente 3, Recuo 1, Duelo 1 |
| `duelist_arena` — Arena do Duelo | Corte 5, Investida 3, Fúria 3, Parede de Escudos 2, Sede de Sangue 3, Resistência 3 | Aparo 3, Leitura 2, Riposte 3, Finta 1, Guarda Paciente 2, Recuo 5, Duelo 5 |
