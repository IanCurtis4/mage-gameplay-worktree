# E09 T6 — contrato curto de costas, ocultação própria e Sentença (C3)

Executor: Sol (sessão T6), 16/11/2026. Fonte: [e09_contract.md](../e09_contract.md) §4 (C3) e
§5 (K3, K4); decisões A3, A4 e A5 de [e09.md](../e09.md); fichas do Assassino
([EXTENDED_CLASS_SPECS](../../EXTENDED_CLASS_SPECS.md)), do Duelista e da Lâmina Arcana
([HYBRIDS_56_V3](../../HYBRIDS_56_V3.md)). Única porta para atores e ameaça: a costura de T1
([t1_kit_seam_api.md](t1_kit_seam_api.md)).

Os números abaixo são **padrões do sistema**. K3 e K4 podem passar outros valores dentro das
faixas. São ajuste de playtest e não exigem decisão de arquitetura (preâmbulo de C3).

## 1. Peças

Pasta `scripts/systems/flank/`:

| Script | `class_name` | Papel |
|---|---|---|
| `flank_rules.gd` | `FlankRules` | Constantes, lados, categoria e limiar; geometria pura, sem estado |
| `flank_authority.gd` | `FlankAuthority` | Estado da família guardado no kit: ocultação, abertura, vítima, Sentença, aparo, execução, abate |

O kit (K3, K4) guarda **uma** `FlankAuthority` numa variável própria e repassa os ganchos de
T1 (lista no recibo). O sistema não guarda `Node`, `PlayerActor` nem ID de inimigo com papel
de entidade (§6).

## 2. Lados (A3)

- **Facing.** `gameplay_ground_facing()` do alvo: o mesmo que o sprite desenha. Com o giro
  ativo, vale a direção girada.
- **Plano do chão.** Posições no chão: no mundo, `world_point().position`; no mapa plano,
  `(x, 0, y)`. A altura (`y`) é ignorada: um atacante numa laje acima tem o mesmo lado que
  teria no chão.
- **Ângulo θ** entre o facing do alvo e o vetor alvo → atacante, no chão:

| Lado | ID | Faixa | Cosseno |
|---|---|---|---|
| Frente | `&"front"` | θ ≤ 60° | cos θ ≥ 0,5 |
| Flanco | `&"flank"` | 60° < θ < 120° | entre |
| Costas | `&"back"` | θ ≥ 120° | cos θ ≤ −0,5 |

- Os limites exatos contam para o lado mais forte: 60° é frente, 120° é costas. Tolerância
  numérica de 1e−4 no cosseno.
- Atacante sobreposto ao alvo (distância no chão < 0,001): frente. Nenhum golpe ganha costas
  por sobreposição.
- A mesma regra classifica um golpe recebido pelo dono, para o aparo (§5).

## 3. Girar e perder de vista

| Item | Padrão | Faixa | Regra |
|---|---|---|---|
| Giro forçado | 1,5 s | 0,8–2,5 s | Override de facing de T1, com dono `&"flank_turn"`. O alvo passa a olhar **para longe do dono**, e o dono fica exatamente nas costas. Um novo giro substitui o anterior. Expira no relógio de gameplay, congela na pausa e some na morte (T1). |
| Perder de vista | 1,2 s | 0,5–3,0 s | `kit_break_sight` de T1. O alvo não pode escolher o dono como alvo pela ameaça, e um force nele termina. No mundo, também não o adquire. |
| Chefe | × 0,6 nas duas durações | — | 0,9 s de giro e 0,72 s sem visão, com os padrões. |

Durante o giro, o facing próprio do inimigo (movimento, ataque) não vence o override. Quando o
giro expira, o sprite fica na direção girada até a IA do inimigo virar de novo, e a partir daí
vale o facing dele (semântica do override de T1).

Limitação herdada (T1, limitação 4): no mapa plano antigo, perder de vista age só sobre a
ameaça; a aquisição pela posição não conhece o observador.

## 4. Ocultação própria

| Item | Valor |
|---|---|
| Entrada | `enter_concealment(player, duração)`. O padrão é 4,0 s, na faixa 1,5–8,0 s. É recusada com o dono morto. Já oculto, o prazo é renovado pelo maior valor. |
| Efeito | A fonte de ocultação do kit (`concealment_active`). Ninguém adquire o dono, e a ameaça o perde no próximo passo de elegibilidade. Valem as regras de revelação da Caçadora (T1). |
| Janela de revelação | Entrar durante os 1,25 s de revelação da costura deixa a ocultação **armada**. Ela passa a valer quando a janela acaba, e o prazo corre igual. Atacar com a ocultação armada a cancela, sem abertura. |
| Saída por ataque | Todo pedido marcado pelo sistema (`mark_request`) revela pelo `reveal_from_offense` da costura. Atacar revela. |
| Saída por prazo | Prazo esgotado: a ocultação acaba **sem** abertura. |
| Outras saídas | Morte do dono e `end_concealment`. |
| Abertura | Depois da revelação por ataque, abre-se uma janela de 0,25 s. O **primeiro** pedido marcado nela leva `from_concealment = true` e `hidden_seconds` (tempo efetivamente oculto, para a Sombra Paciente). Um único pedido por ocultação. |

A ocultação é estado do dono e sobrevive à suspensão nos dois formatos.

## 5. Aparo (família do Defendente, consumido pela K3)

| Item | Padrão | Faixa |
|---|---|---|
| Janela | 0,35 s | 0,20–0,60 s |
| Cargas | 1 por janela, ou ilimitadas pela duração (`charges = -1`, para o Duelo) | — |

- Apara só golpe corpo a corpo (`hit.kind == &"melee"`). Projétil e área nunca são aparados.
- O atacante precisa estar na **frente** do dono, pela regra de §2 aplicada ao dono (±60°).
- Vale o relógio do kit. A janela precisa estar aberta no impacto. No corpo a corpo, impacto e
  commit são o mesmo instante (T1, 5.3).
- No sucesso, `try_parry` gasta uma carga e, por padrão, expõe o atacante (giro e perda de
  visão de §3). O kit devolve `{"cancel": true, "reason": ...}` em `before_hit_mitigation`.

## 6. Vítima

- A marca `&"flank_victim"` fica no `ActorMarks` do alvo, sem prazo. O dono é o jogador, e o
  valor é `{"sentence": 0..5, "serial": n, "see_through": true}`. `see_through` é a flag de
  apresentação ("visível através de obstáculos").
- **Uma vítima por dono.** Marcar outra remove a marca anterior.
- A vítima some com a morte dela (as marcas morrem com o inimigo), com a morte do dono e
  quando outra é marcada.
- **Sem referência de entidade no dono.** O dono guarda só o `serial` da marca vigente. A
  vítima é o ator cuja marca tem o dono e o serial atuais. Por isso:
  - no formato exato, inimigo e marca voltam juntos, e a vítima continua valendo;
  - no compacto, o inimigo volta à origem sem marcas (A5), e a vítima e a Sentença somem;
  - o corte compacto continua elegível; nenhum campo do sistema aponta para um inimigo vivo
    fora do escopo.

## 7. Sentença

| Fonte | Cargas | Quem decide |
|---|---|---|
| Golpe pelas costas (lado do pedido = costas) | +2 | o kit habilita em `record_hit` |
| Primeiro golpe saindo da ocultação (`from_concealment`) | +2 | idem |
| Outro golpe direto | +1 | idem |
| Combo do kit (aparo, três elementos, coquetel) | +2 | `gain(player, alvo, &"combo", chave)` |

- **Teto 5.** Só a vítima do dono acumula.
- **Por golpe, vale a maior fonte habilitada; as fontes não somam.** Uma Emboscada pelas
  costas saindo da ocultação dá +2, como no loop da ficha ("Emboscada pelas costas (+2)").
- O combo é um evento próprio, com chave explícita.
- **Dedup por evento.** A chave de um golpe é a identidade de aplicação do
  `EffectProcLedger`: `root_event_id`, `event_id` e alvo. Sem contexto causal, vale a
  `application_sequence` do alvo. Um resultado repetido nunca gera de novo. A memória guarda
  128 chaves.
- Não geram Sentença: golpe de execução, golpe secundário (DoT), golpe sem dano.
- Lado e abertura são capturados **no commit**, por `mark_request`, e viajam no
  `DamageRequest` (`effect_snapshot["flank"]`). O ganho acontece no resultado confirmado
  (`on_damage_dealt`), depois dos claims.

## 8. Execução (A4)

| Item | Valor |
|---|---|
| Gasto | Todas as cargas da vítima, uma vez por commit (chave `skill@kit_time`). A marca fica com 0. |
| Escala | O dano é multiplicado por `1 + 0,40 × cargas`; com 5 cargas, 3,0×. A faixa por carga é 0,25–0,60. O kit passa os montantes-base, a partir de `stat_breakdown`. |
| Morte certa | Exige cargas cheias (5), categoria diferente de chefe e HP atual / HP máximo **≤ limiar** no commit. |
| Limiar por categoria | normal **30%** · raro **24%** · elite **18%** · raro-elite **12%** · chefe **nunca** |
| Como mata | O pedido marcado `execution`/`lethal` tem acerto `GEOMETRY` e não crita. O montante sobe até que o próprio `CombatMath.resolve`, com as defesas do alvo, devolva dano ≥ HP + escudo. Sai por `kit_emit_hit` (claims, ledger, callbacks de morte). Nunca há escrita direta de HP nem fórmula duplicada. |
| Chefe | Sem morte certa: só o dano escalado. O golpe pode derrubar o chefe se o dano comum bastar, mas nunca há elevação até o letal. |
| Imunidade existente | Um mob voltando ao posto é imune (regra F10). A execução também não o fere. |
| Categoria | `occurrence.category_id` do inimigo. Sem ocorrência: `boss` se `hard_controls.boss`, senão `normal`. |

## 9. Abate

`on_kill_confirmed(player, result)` devolve `{"kill", "first", "execution", "victim"}`. A
costura já chama uma vez por vítima. O sistema deduplica de novo pelo alvo, com memória de 64,
e um retry devolve `first = false`. O kit só age com `first == true`: devolve a ocultação, o SP
ou o próximo aparo automático. Assim o callback é único.

## 10. Teleporte às costas (consumido pela K4)

- O destino é o ponto atrás da vítima, na direção oposta ao facing dela, a raio do alvo +
  raio do dono + 12 (faixa 4–40).
- No mundo, o ponto vem de `WorldGeometry.trace_ground` a partir da vítima, com o perfil do
  dono. A trilha precisa chegar até a soma dos raios.
- Tentativas, em ordem: 0°, +30° e −30°. Todas ficam dentro do arco de costas.
- O destino só vale se a classificação de §2 der **costas**.
- `teleport_behind` move o dono pelo `WorldActorMotion.teleport` (regra `teleport_legal` e
  alcance) e o vira para a vítima.
- No mapa plano, o ponto precisa ser `is_walkable` e o segmento a partir da vítima estar
  livre.

## 11. Pausa e snapshot (C1.9, A5)

- Os relógios do sistema (ocultação, abertura, aparo) avançam só em `tick`, chamado de
  `on_tick`, que não roda em pausa.
- O giro e a perda de visão são relógios do inimigo e da ameaça, e T1 os congela.
- O fragmento `scripts/systems/flank/snapshot_manifest.json` lista todos os campos:
  - o cache da vítima (`_victim_hint`) é omitido com motivo;
  - a memória de eventos e de abates é guardada por chave de texto, nunca por ID de entidade.
- Sem bloqueio de corte compacto: o sistema não cria zona nem entidade temporária.

## 12. Invariantes testadas

Em `tests/systems/flank/flank_test.gd`:
- matriz de lados, com os limites, alturas diferentes e inimigo girado;
- o giro expira e congela na pausa;
- limiar por categoria;
- nenhuma morte certa no chefe;
- execução recusada acima do limiar;
- abate contado uma vez, inclusive em retry;
- ganho deduplicado;
- ocultação contra a aquisição e a ameaça;
- snapshot exato preserva vítima, cargas e ocultação;
- o compacto mantém o estado do dono e perde a vítima.
