# E09 T6 — recibo de costas, ocultação própria e Sentença (C3)

Executor: Sol (sessão T6), 16/11/2026. Contrato curto com os números:
[t6_contract.md](t6_contract.md). Fonte: [e09_contract.md](../e09_contract.md) §4 (C3) e §5
(K3, K4). Única porta usada: a costura de T1 ([t1_kit_seam_api.md](t1_kit_seam_api.md)).

## Identificação

| Campo | Valor |
|---|---|
| Base (`--ff-only`) | `337aa7dfd9673038e3fd162c3fd3ae2826b8d095`: ponta entregue de T1, contém `771a314f` |
| Branch | `claude/reverent-wing-9d35b9` |
| Checkout real | `C:\Users\João Pedro\Documents\ChatGPT\RagRPG\.claude\worktrees\reverent-wing-9d35b9` |
| Commit de código | `da72fd0106df1e75624c772598be91ba24506442`: sistema, fixture, teste e contrato curto |
| Código validado | `da72fd01`: as rodadas abaixo usam exatamente estes arquivos |
| SHA entregue | o commit deste recibo, filho direto de `da72fd01`, só com documentação; base de K3 e K4 |

A base **não** contém a T1.1 (`bd66d3c3`, A12) nem a T1.2 (A13). O sistema não depende delas.
K3 e K4 fazem merge delas se precisarem; a K4 precisa da T1.2 para observar o Teleporte da base.

Sem push, sem `master`, sem tocar no playtest habitual nem no save pessoal. Só perfis de
fixture em memória; nenhum perfil ou save gravado.

## Arquivos (dono exclusivo)

| Arquivo | Papel |
|---|---|
| `scripts/systems/flank/flank_rules.gd` (`FlankRules`) | Constantes, lados, categoria, limiar; sem estado |
| `scripts/systems/flank/flank_authority.gd` (`FlankAuthority`) | Estado da família, guardado no kit |
| `scripts/systems/flank/snapshot_manifest.json` | Fragmento do sistema (C1.9) |
| `scripts/systems/flank/fixture/flank_fixture_kit.gd` + `snapshot_manifest.json` | Kit de fixture: repassa os ganchos como K3/K4 devem; fora do registro de produção |
| `tests/systems/flank/flank_test.gd` | Invariantes de C3 |
| `docs/epics/e09/t6_contract.md`, `t6_delivery.md` | Contrato curto e este recibo |

Nenhum arquivo compartilhado foi editado. `player_actor.gd` continua sem nomear `EnemyActor`
(A10), e os scripts do sistema também não o nomeiam: a categoria é lida por `get(&"occurrence")`.

## API para K3 e K4

### Ligação no kit

O kit guarda **uma** autoridade numa variável própria e a lista no `fields` do próprio
fragmento. Os tipos internos já estão no fragmento do sistema.

```gdscript
var flank := FlankAuthority.new()   # fragmento do kit: "fields": [..., "flank"]

func on_tick(player: PlayerActor, delta: float) -> void: flank.tick(player, delta)
func concealment_active(_player: PlayerActor) -> bool: return flank.concealment_active()
func on_reveal(player: PlayerActor, duration: float) -> void: flank.on_reveal(player, duration)
func on_death(player: PlayerActor) -> void: flank.on_death(player)
func compose_basic_attack(player: PlayerActor, target: CombatActor, request: DamageRequest) -> DamageRequest:
	return flank.mark_request(player, request, target)          # todo pedido do kit passa aqui
func on_damage_dealt(player: PlayerActor, result: Dictionary) -> void:
	flank.record_hit(player, result, {&"back": true, &"concealment": true, &"direct": true})
func on_kill_confirmed(player: PlayerActor, result: Dictionary) -> void:
	var kill := flank.on_kill_confirmed(player, result)
	if kill["first"] and kill["execution"]: pass               # devolve ocultação / SP / próximo aparo
func before_hit_mitigation(player: PlayerActor, hit: Dictionary) -> Dictionary:
	var parry := flank.try_parry(player, hit)                  # K3
	return {"cancel": true, "reason": parry["reason"]} if parry["parried"] else {}
```

Exemplo completo e testado: `scripts/systems/flank/fixture/flank_fixture_kit.gd`.

### Métodos

| Método | Uso |
|---|---|
| `FlankRules.classify(alvo_chão, facing_chão, ponto_chão)`, `side_of(alvo, ponto_chão)`, `side_between(alvo, atacante)` | `{"side": front/flank/back, "cos", "overlap", "valid"}` pelo facing de gameplay do alvo (A3), no plano do chão |
| `FlankRules.category_of(ator)`, `execution_threshold(categoria)` | Categoria e limiar (−1 no chefe) |
| `FlankRules.victim_mark(ator)`, `see_through(ator)` | Flag de apresentação "visível através de obstáculos" |
| `FlankRules.flags_of(effect_snapshot)`, `result_flags(result)` | Flags `side`, `cos`, `from_concealment`, `hidden_seconds`, `execution`, `lethal`, `charges`, `category` |
| `turn_away(player, inimigo, duração = −1)`, `turn(inimigo, direção_chão, duração)` | Giro forçado (override de T1, dono `flank_turn`) |
| `break_sight(player, inimigo, duração = −1)` | Perder de vista (`kit_break_sight`) |
| `expose(player, inimigo)` | Giro + perda de visão |
| `enter_concealment(player, duração = −1)`, `end_concealment()`, `concealment_active()`, `opening_ready()` | Ocultação própria e abertura |
| `mark_request(player, pedido, alvo)` | Marca lado e abertura no commit; revela ao atacar. Chame em **todo** pedido do kit, inclusive os de `kit_make_request` |
| `open_parry(player, duração = −1, cargas = 1)`, `open_parry_mode(player, duração)`, `parry_open()`, `close_parry()`, `try_parry(player, hit, expor = true)` | Janela de aparo |
| `mark_victim(player, ator)`, `victim(player)`, `is_victim(player, ator)`, `clear_victim(player)`, `sentence(player, ator = null)` | Vítima única por dono |
| `record_hit(player, result, contadas = {})`, `gain(player, ator, fonte, chave)`, `event_key(result)` | Sentença: golpe (maior fonte habilitada) e evento do kit (`&"combo"`) |
| `execute(player, ator, skill_id, físico, mágico, opções = {})` | Execução: gasta tudo, escala, morte certa por categoria e emite por `kit_emit_hit`. Opções: `per_charge`, `can_crit`, `emit`, `accuracy_mode` |
| `on_kill_confirmed(player, result)` | `{"kill", "first", "execution", "victim"}`; só `first` age |
| `back_point(player, ator, folga = −1)`, `teleport_behind(player, ator, alcance, folga = −1)` | Ponto às costas validado pela geometria; teleporte pelo `WorldActorMotion.teleport` |

Códigos de erro: `invalid_owner`, `invalid_target`, `invalid_payload`, `already_executed`,
`mark_refused`, `invalid_facing`, `incompatible_target`, `back_point_blocked`, `invalid_range`,
`out_of_range` e os de `WorldActorMotion.teleport`/`ThreatService`. Razões de aparo:
`flank_parry`, `no_window`, `not_melee`, `no_attacker`, `not_front`.

### Receitas por skill (sugestão; o contrato do kit decide)

**K3 Duelista.**
- **Aparo:** `open_parry` no `resolve_cast`. Em `before_hit_mitigation`, chame `try_parry`. No
  sucesso, `mark_victim` no atacante e `gain(&"combo", "parry:%d" % ...)`, que é o aparo +2 da
  Leitura do Oponente.
- **Leitura do Oponente:** `record_hit` com `{&"back": true, &"concealment": false, &"direct": true}`.
- **Riposte Fatal:** `execute`. No `on_kill_confirmed` com `first and execution`, o kit arma o
  próximo Aparo automático com `open_parry` no próximo golpe.
- **Finta:** o estado do kit diz que o próximo golpe do inimigo conta como aparado; o kit
  chama `expose` e devolve `cancel`.
- **Guarda Paciente:** `open_parry(player, maior)`, até 0,60 s.
- **Recuo em Guarda:** `break_sight`.
- **Duelo:** `open_parry_mode(player, duração)`.

**K4 Lâmina Arcana.**
- **Marca Refratada:** `mark_victim`.
- **Lâmina Encantada:** `compose_basic_attack` → `mark_request`. Os três elementos na vítima
  dão `gain(&"combo", chave_da_reação)`.
- **Refração:** `enter_concealment`.
- **Salto Prismático:**
  - `can_cast` exige `player.kit_concealed()`;
  - o `resolve_cast` faz `teleport_behind` e depois o golpe com `mark_request`, que sai de
    costas e da ocultação.
- **Fratura de Luz:** no `on_kill_confirmed` com `first and execution`, devolve a Refração e o SP.
- **Sentença Prismática:** `execute` com os montantes mágicos do kit.
- **Espectro de Prisma:** o kit decide. Cada reflexo usa `back_point` numa vítima diferente.
  `execute` aceita qualquer alvo, mas só a vítima tem cargas.

## Validação

Godot 4.7.2 standard,
`C:\Users\João Pedro\Documents\ChatGPT\RagRPG\.tools\godot\Godot_v4.7.2-stable_win64.exe`,
pelo PowerShell. Antes dos testes, a worktree nova foi importada com
`--headless --editor --import --quit`, porque o cache de classes globais faltava.

### Teste novo

`tests/systems/flank/flank_test.gd`, passo 330 do verificador: **205 checks, 0 falhas**.
Saída: sha256 `D23DC5D7B03B0FE0742A8C62D00F0A0F8438F0DC30F43DC1FD5CDE9D4244C02A`.
Antes, uma primeira execução isolada deu 203 checks e 1 falha. A expectativa estava errada:
depois que o giro expira, o sprite fica girado até a IA do inimigo virar de novo, que é a
semântica do override de T1. O teste passou a provar que, durante o giro, o facing próprio do
inimigo não vence e que, depois dele, volta a valer. O contrato §3 registra a regra.

Cobertura, conforme as invariantes de C3:
- matriz de lados com 15 ângulos, incluindo os limites de 60° e 120°, cada um em três alturas;
  sobreposição; facing nulo;
- lados entre atores, inimigo virado e giro: expira, congela na pausa, faixa e chefe × 0,6;
- categorias e limiares decrescentes, lidos de `occurrence` e do perfil de chefe;
- ocultação: entrada, renovação, relógio, pausa, revelação ao atacar, abertura única, janela
  de revelação, cancelamento, expiração e faixa;
- ocultação contra a aquisição e a ameaça, no mapa plano com `EnemyActor` real;
- vítima única e Sentença:
  - fontes: frente +1, flanco +1, costas +2, ocultação +2; costas + ocultação = +2;
  - teto 5, combo +2 por chave e retry deduplicado;
  - fontes escolhidas pelo kit; DoT sem ganho;
  - ataque básico marcado;
- execução pelo cast real (`use_kit_skill`):
  - morte certa com 800 de DEF;
  - causal, GEOMETRY e sem crítico;
  - morte pelo `HealthState`;
  - callback único, também em retry e em abate comum;
- execução recusada acima do limiar nas quatro categorias, com 4 cargas e no chefe a 1% de HP;
  gasto único por commit;
- janela de aparo:
  - frente corpo a corpo, aparado: o atacante é girado e perde de vista;
  - sem janela, projétil, costas e flanco: não aparado;
  - expiração, modo Duelo e faixa;
- ponto às costas e teleporte no mapa plano: alcance e bloqueio;
- morte do dono e pausa de todos os relógios;
- snapshot:
  - exato: vítima, Sentença, ocultação, aparo, memória e giro;
  - compacto elegível com uma vítima viva: o estado do dono fica, a vítima some;
- mundo (fixture F1):
  - lados no chão com laje acima e facing de chão;
  - ocultação e perda de visão contra `can_be_acquired_by_world`;
  - ponto às costas por `trace_ground`, teleporte legal, borda sem chão e alcance;
- guarda de fonte: nem `EnemyActor` como tipo, nem escrita direta de HP.

### Regressão por impacto

```
tools/verify.ps1 -GodotPath <godot> -SkipEditorImport -CheckTimeoutSeconds 300 `
  -VerificationDirectory .godot/verification/t6_impact `
  -Test flank_test,kit_seam_test,e07_f6_threat_test,e06_tx_mob_test,e06_rx_mob_ai_test,
        e07_f6_snapshot_test,e08_compact_checkpoint_test,e08_compact_coverage_test,
        e07_f3_snapshot_test,e07_f3_mob_state_test,e05_hunter_cover_integration_test
```

Rodada em `.godot/verification/t6_impact/` (fora do Git): **11/11 passos passaram**, todos com
saída 0. `checks.jsonl`: sha256 `C98B3D25E911A961A40BA6C68555177B8CC2D388990EB727DA0AB96BDDCC4992`.

| Passo | Teste | Resultado | Saída (sha256) |
|---|---|---|---|
| 72 | `e05_hunter_cover_integration_test` (ocultação da Caçadora) | 302 checks, 0 falhas | `ABA9521633BBE3723901FC6030B981CA31F23A95E284426EBD3CA1BC895D168C` |
| 206 | `e06_tx_mob_test` (tiers de mob) | 27, 0 | `5D56F0CD5FF057474655131DDF94EC101977F7AAB24FCB67EF806B1E4F99969A` |
| 209 | `e06_rx_mob_ai_test` | 4, 0 | `B9569774452019C5A7A2F3C085320FE2CF4B747A45ADF3BBBAC256FFC674109A` |
| 268 | `e07_f6_threat_test` (ameaça) | 43, 0 | `C38ACB2F6A0A4F101776B095EE0A68791A65E72A12D77D5317B2EB793EFA2AD3` |
| 270 | `e07_f6_snapshot_test` | 40, 0 | `2E091952F53115A75311BF2F4CFD595A18B2E8C64FA3076CBF6F844F4CC4EDC6` |
| 282 | `e08_compact_checkpoint_test` | 48, 0 | `346B73697BFB3C1975A5B0B2196C99CC96AE95E389DFA441C3EDBDC5FFDCA1EC` |
| 283 | `e08_compact_coverage_test` | 95, 0 | `3C65ADD205F98F2D063AFCF6DAD256C3F207D51AAE7376621D38801D89228796` |
| 294 | `e07_f3_snapshot_test` | 52, 0 | `9FC703C4AB2986DDAAB73ED386092F3B8AB71A5EA82C4A7C3C781D2F6F06C0CC` |
| 298 | `e07_f3_mob_state_test` | 372, 0 | `A84CACBF8F2342C0644F9985DB703A0244FE421411DF868C5C53B6D24FDEB815` |
| 329 | `kit_seam_test` | 175, 0 | `45F637A085EF4FBA26D70B7A24A6A3BD7882EB0DE61FF85AA0C874B49C034E22`, igual ao registrado por T1 |
| 330 | `flank_test` (novo) | 205, 0 | `D23DC5D7B03B0FE0742A8C62D00F0A0F8438F0DC30F43DC1FD5CDE9D4244C02A` |

- **Busca nas saídas.** Procurei `SCRIPT ERROR`, `still in use`, `Parse Error`, `Compile Error`
  e `FAIL:` nos 22 arquivos `.output.log`/`.engine.log`: **0 ocorrências**.
- **Aviso esperado.** O único aviso é o `WARNING: compact cut rehearsal failed` do
  `e08_compact_checkpoint_test`. É um cenário proposital do próprio teste, que aparece em
  `E08_COMPACT_TALLY` como `rehearsal_failed`.
- **Plano.** Passou de 329 para 330 passos. O `flank_test` foi descoberto pelo grupo
  `tests/systems` sem editar o verificador, e os índices antigos não mudaram.
- **Suíte completa não repetida.** T6 não toca arquivo compartilhado. O que ela acrescenta ao
  caminho dos outros testes é o fragmento de snapshot, e os passos de snapshot e compacto
  acima o cobrem.

## Limitações

1. **Mapa plano antigo:** perder de vista age só sobre a ameaça; a aquisição pela posição não
   conhece o observador. É a limitação 4 de T1. No mundo, `can_be_acquired_by_world` respeita
   a perda de visão, e o teste confirma. A ocultação própria bloqueia a aquisição nos dois
   modos.
2. **Ocultação "na hora" depois de um abate.** Todo ataque liga os 1,25 s de revelação da
   costura (`concealment_reveal_remaining`), e a autoridade não os encurta: mexer nesse campo
   seria escrever estado do jogador fora da costura. Uma ocultação devolvida pelo abate fica
   armada e passa a valer quando a janela acaba, em até 1,25 s.
   - No E09 isso basta, se a Fratura de Luz devolver a Refração como recarga ou carga.
   - Se K4, ou o Assassino depois, precisar da ocultação instantânea, é preciso um gancho da
     costura, por exemplo `ClassKit.reveal_duration`. O pedido vai à arquitetura.
3. **`teleport_behind`** move o dono pelo `WorldActorMotion.teleport`, que zera a rota do
   movimento. A intenção de viagem privada do jogador (`_stop_world_travel`, `_path`) não é
   alcançável pela costura:
   - no mundo, o cast de kit já resolve depois da aproximação;
   - no mapa plano, um alvo de caminho pendente pode continuar.
   - A K4 confere isso no combate integrado e, se faltar, pede o gancho (área da T1.2).
4. **Flag `see_through`.** É dado da marca. A camada de apresentação atual não desenha atores
   através de obstáculos. Quem desenha é o kit (`draw_vfx`) ou uma tarefa de apresentação.
5. **Busca da vítima depois da restauração.** O cache é reconstruído pelos irmãos e filhos do
   jogador, onde ficam os inimigos do `RunController`. Uma vítima em outro ramo da árvore não
   seria encontrada; não há esse caso hoje.
6. **Mob voltando ao posto (F10)** é imune. A execução não o fere e não é marcada como letal.
7. **Execução no chefe** é só dano escalado: pode matar se o dano comum bastar, mas nunca há
   elevação até o letal (A4: o chefe nunca morre pela morte certa).
8. **`e07_f1_hunter_cover_test`** (projeto de fixture F1) não foi rodado: nenhum arquivo da
   Caçadora mudou, e o passo do projeto principal (`e05_hunter_cover_integration_test`)
   passou.
9. **Escopo da supervisão:** execução, conclusão, erros e hashes dos testes, mais as
   invariantes do contrato. Não é auditoria semântica independente.

## Próximo passo

K3 e K4 partem do SHA entregue (o commit deste recibo na branch `claude/reverent-wing-9d35b9`),
com merge de T1.1/T1.2 quando precisarem. Saídas temporárias: o diretório
`.godot/verification/t6_impact/` fica fora do Git; a importação da worktree foi desfeita nos
arquivos rastreados (`.import` e a DLL temporária do plugin de Git restaurados, `.import` e
`.gd.uid` gerados fora das pastas de T6 removidos).
