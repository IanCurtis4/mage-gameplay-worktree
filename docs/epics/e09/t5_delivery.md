# E09 T5 — Recibo de entrega de Santuário e Graça (C2)

Executor: Sol (sessão de tarefa T5, Opus 5.5), 16/11/2026. Contrato curto com os números:
[t5_contract.md](t5_contract.md). API da costura usada: [t1_kit_seam_api.md](t1_kit_seam_api.md).

## Identificação

| Campo | Valor |
|---|---|
| Base (`git merge --ff-only`) | `337aa7dfd9673038e3fd162c3fd3ae2826b8d095`, ponta entregue da T1 em `claude/mystifying-moser-f04ddc`, com `771a314f` |
| Branch | `claude/pensive-wilson-bf9141` |
| Checkout real | `C:\Users\João Pedro\Documents\ChatGPT\RagRPG\.claude\worktrees\pensive-wilson-bf9141` |
| SHA entregue | o commit que introduz este recibo, filho direto da base, com código, testes e documentos. É a base de K1 e K2 |

Sem push, sem `master`, sem tocar no playtest habitual nem no save pessoal. Só perfis e saves
de fixture.

## Escopo entregue

Arquivos, todos dentro do dono exclusivo da T5:

- `scripts/systems/sanctuary/sanctuary_rules.gd` (`SanctuaryRules`): constantes, formas,
  elementos e regras como dados, com validação;
- `scripts/systems/sanctuary/sanctuary_zone.gd` (`SanctuaryZone`): zona, geometria e relógios;
- `scripts/systems/sanctuary/sanctuary_grace.gd` (`SanctuaryGrace`): cargas, teto, modo sem
  limite, decaimento, excedente e deduplicação;
- `scripts/systems/sanctuary/sanctuary_authority.gd` (`SanctuaryAuthority`): autoridade da
  família, com zonas por papel, Graça, Égide, Selo e os repasses dos ganchos;
- `scripts/systems/sanctuary/sanctuary_helpers.gd` (`SanctuaryHelpers`): Juízo, luz (A2),
  eventos e lista de inimigos, sem estado;
- `scripts/systems/sanctuary/snapshot_manifest.json`: fragmento dos cinco scripts;
- `scripts/systems/sanctuary/fixture/sanctuary_fixture_kit.gd` e o fragmento dele: kit de
  teste sobre o kit de fixture da T1, fora do registro de produção. Mostra o repasse dos
  ganchos que K1 e K2 vão copiar;
- `tests/systems/sanctuary/sanctuary_test.gd`: descoberto pelo `verify.ps1` (passo 330,
  `-Test 'sanctuary_test'`);
- `docs/epics/e09/t5_contract.md` e este recibo.

Nenhum arquivo compartilhado, ator, registro ou `docs/epics/e09.md` foi editado. O sistema
usa só os ganchos e ajudantes da T1. `player_actor.gd` não mudou, e o sistema não nomeia
`EnemyActor`: o empurrão usa `has_method`/`call`, como a T1 (A10).

## API para K1 e K2

### Montagem no kit

```gdscript
# scripts/classes/sp_ac/sp_ac_kit.gd (K1); o mesmo em mg_ac (K2)
var sanctuary := SanctuaryAuthority.new()   # entra em "fields" do fragmento do kit

func causal_families() -> Array[StringName]: return [&"paladin_grace"]   # opcional; ver "Famílias"
func on_attach(p: PlayerActor) -> void: sanctuary.configure(p, &"paladin_grace")
func on_tick(p: PlayerActor, d: float) -> void: sanctuary.tick(p, d)
func before_hit_mitigation(p: PlayerActor, hit: Dictionary) -> Dictionary: return sanctuary.before_hit(p, hit)   # depois do próprio cancelamento (Aparo etc.)
func on_shield_broken(p: PlayerActor, hit: Dictionary, r: Dictionary) -> void: sanctuary.on_shield_broken(p, hit, r)
func on_heal(p: PlayerActor, req: float, app: float, src: StringName) -> void: sanctuary.on_heal(p, req, app, src)
func on_death(p: PlayerActor) -> void: sanctuary.on_death(p)
func on_build_changed(p: PlayerActor) -> void: sanctuary.on_build_changed(p)
func snapshot_compact_blocker(_p: PlayerActor) -> String: return sanctuary.compact_blocker()
```

O exemplo completo e testado é o `sanctuary_fixture_kit.gd`.

### Zonas

| Chamada | Uso |
|---|---|
| `open_zone(player, config) -> {ok, error_code, zone}` | Chamar em `resolve_cast`, porque o protótipo da queimadura herda a raiz causal do cast. `config`: `role`, `skill_id` (obrigatórios), `shape`, `anchor`, `point`, `radius`, `half_angle`, `wide_scale`, `duration`, `pulse_interval`, `element`, `rules`, `family_id` |
| `SanctuaryAuthority.cast_point(cast)` | Ponto do descritor de cast da T1 (`anchor` no mundo, `point` no mapa plano) |
| `zone(role)`, `has_active_zone()`, `end_zone(role)` | Consulta e fim |
| `set_zone_shape(role, &"circle" \| &"wide_circle", raio = 0)` | Hora do Juramento (cone → círculo) e Aurora (ampliado). Os relógios não reiniciam |
| `set_zone_element(role, elemento)` | Primeiro feitiço do Círculo Votivo, Coro (tricolor) |
| `pulse_now(player, role, elemento = &"")` | Mudança de Altar: pulso do elemento antigo |
| `owner_inside_any()`, `owner_damage_multiplier(hit)`, `heal_multiplier()` | Consultas puras, para tooltip, Fé Inabalável etc. |
| `SanctuaryZone.contains(player, ator)` | Pertença, com a geometria do mundo |

### Graça

| Chamada | Uso |
|---|---|
| `gain(evento, quantidade = 1) -> int` | Fontes do kit. `evento` = `SanctuaryHelpers.result_event(result)` (golpe frontal mitigado, luz no selado) ou `SanctuaryHelpers.cast_event(cast, player.kit_time)` (alternância de elemento) |
| `grace.can_spend(mínimo)` | Puro, para `can_cast` |
| `spend_for_cast(player, cast, mínimo = 1, máximo = -1) -> int` | **Só** em `on_cast_confirmed`. Devolve as cargas gastas; guarde-as para o `resolve_cast` |
| `begin_unlimited(segundos)` | Hora do Juramento e Aurora |
| `grace.charges`, `grace.cap`, `grace.is_unlimited()` | Leitura para HUD e tooltip |

A cura excedente é fonte própria do sistema e não pede nada ao kit além do repasse de `on_heal`.

### Ajudantes

| Chamada | Uso |
|---|---|
| `SanctuaryHelpers.judgment_request(player, vítima, skill, base, cargas)` | Juízo e Impacto Consagrado. `base` vem do `stat_breakdown` do kit |
| `SanctuaryHelpers.judgment_targets(player, atores, ponto, raio = 45, zona = null)` | Coluna vertical; com zona, todos dentro dela |
| `grant_aegis(player, capacidade, duração = 6, dano_do_pulso = 0, skill = &"", raio = 120)` | Égide |
| `seal(player, inimigo, &"paladin_seal", duração = 6, valor = 1)` | Selo, com `{"forced"}` |
| `add_to_seal(delta)`, `is_sealed(inimigo)`, `sealed_target()` | Provocar soma ao Selo; luz no selado |
| `SanctuaryHelpers.is_light_skill(skill)` / `is_light_result(result)` | A2: elemento `light` na `SkillDefinition` |

### Famílias causais

O tique de queimadura usa `context.family_id` = `config.family_id`, que por padrão é a
`skill_id` da zona. `HealthState` reivindica `família:alvo` por raiz, e o plano causal do
jogador já contém toda skill aprendida com rank > 0. O kit só precisa declarar uma família
própria (com o prefixo) se passar `family_id`. `grace_family` só nomeia as chaves de evento
da Graça e não precisa estar no plano.

### Snapshot do kit

O kit lista `sanctuary` em `fields` do próprio fragmento. Os tipos internos já estão no
fragmento do sistema. Com zona, Égide ou Selo ativos, `compact_blocker()` força o formato
exato (A5).

## Validação

Motor: Godot 4.7.2 standard,
`C:\Users\João Pedro\Documents\ChatGPT\RagRPG\.tools\godot\Godot_v4.7.2-stable_win64.exe`,
chamado pelo PowerShell. Antes, `--headless --editor --import --quit` para registrar as classes
novas no cache de classes globais. O passo `editor_import` do verificador acusou na saída
`Cannot get class 'GitPlugin'`, a mesma falha de worktree novo que a T1 registrou no passo
255. Ele não faz parte da regressão abaixo.

### Teste novo: `sanctuary_test` (passo 330), 144 checks, 0 falhas

Invariantes cobertas:

- **regras como dados:** padrões, faixas, chave desconhecida e elementos;
- **zonas:** pertença do círculo, do cone pelo facing de gameplay e do círculo ampliado; troca
  de forma sem reiniciar relógios; cone só preso ao dono; uma zona por papel; sair não desfaz;
- **mundo:** pertença `ground_connected`; **desnível conta** (alvo na laje acima do centro
  fica fora); pulso só em quem está dentro; cone pelo facing de chão; coluna vertical;
- **pausa congela** a duração, os pulsos, o modo sem limite e o decaimento da Graça;
- **pulso:** primeiro em 1 s; 4 pulsos numa zona de 4 s; queimadura por `DamageRequest`
  secundário reivindicado no ledger; nada depois do fim;
- **nenhuma regra duas vezes no mesmo tick:** duas zonas e um pulso imediato no mesmo tick
  queimam uma vez; o SP do raio entra uma vez com o maior valor; fogo × 1,5;
- **dano recebido do dono:** cone × 0,80 só de frente; círculo de todos os lados; o menor
  multiplicador entre zonas; gelo × 0,85 (plano B); tiques secundários fora;
- **cura medida:** sem excedente não gera Graça; 10% de excedente rende 1 carga e guarda 2%;
  teto 5; dentro da zona a cura rende × 1,25 por um bônus reportado e nunca multiplicado de
  novo; aplicado igual ao pedido não tem excedente;
- **Graça sem duplicar:** o mesmo golpe, um retry do mesmo resultado (`_on_enemy_damage_resolved`
  repetido) e um evento já consumido não rendem de novo; a chave é a identidade do ledger;
  memória limitada a 128;
- **modo sem limite** passa do teto e volta a 5 ao fim; decaimento depois de 8 s, −1 a cada
  2 s, segurado por zona ativa;
- **gasto atômico:** `can_spend` puro; o mesmo commit não gasta duas vezes; mínimo e gasto
  parcial; o cast real gasta 5 cargas em `on_cast_confirmed` e o Juízo triplica;
- **troca de build** não recarrega nem zera a Graça e não cura; morte zera a Graça e encerra
  zonas e Selo;
- **Égide:** escudo por `grant_shield`; um pulso ao quebrar, com dano de luz e empurrão real
  de `EnemyActor`; nenhum segundo pulso ao expirar; expiração limpa o halo e solta um pulso;
  um escudo maior de outra fonte fica;
- **Selo:** marca com dono; `force_target` num `EnemyActor`; um por dono; `add_to_seal`; luz
  no selado rende Graça uma vez, mesmo em retry; termina com a marca;
- **A2:** dano de luz igual a qualquer dano mágico do mesmo montante;
- **snapshot:**
  - os fragmentos se fundem sem erro;
  - o **formato exato** preserva a zona (relógios, elemento, centro, regras, protótipo), a
    Graça com a memória de eventos e o Selo religado ao inimigo restaurado;
  - o **compacto** é inelegível com zona (`sanctuary_zone:votive`) e com Selo
    (`sanctuary_seal`); sem eles é aceito, e a restauração compacta preserva a Graça e o
    modo sem limite.

### Regressão por impacto (`tools/verify.ps1 -Test …`)

Rodada 1: `.godot/verification/t5_impact_1/`, `checks.jsonl` sha256
`E3655400C4316DDA2B32AE24D1291F8C5EE57EE888E17A9150D343BA95D73CFF`.

| Passo | Nome | Resultado | sha256 da saída |
|---|---|---|---|
| 268 | `e07_f6_threat_test` | PASS, 43 checks | `C38ACB2F6A0A4F101776B095EE0A68791A65E72A12D77D5317B2EB793EFA2AD3` |
| 270 | `e07_f6_snapshot_test` | PASS, 40 checks | `2E091952F53115A75311BF2F4CFD595A18B2E8C64FA3076CBF6F844F4CC4EDC6` |
| 282 | `e08_compact_checkpoint_test` | PASS, 48 checks | `346B73697BFB3C1975A5B0B2196C99CC96AE95E389DFA441C3EDBDC5FFDCA1EC` |
| 283 | `e08_compact_coverage_test` | PASS, 95 checks | `3C65ADD205F98F2D063AFCF6DAD256C3F207D51AAE7376621D38801D89228796` |
| 294 | `e07_f3_snapshot_test` | PASS, 52 checks | `9FC703C4AB2986DDAAB73ED386092F3B8AB71A5EA82C4A7C3C781D2F6F06C0CC` |
| 329 | `kit_seam_test` | PASS, 175 checks | `45F637A085EF4FBA26D70B7A24A6A3BD7882EB0DE61FF85AA0C874B49C034E22`, idêntico ao da T1 |
| 330 | `sanctuary_test` | PASS, 144 checks | `875AAB8B8E1FC0119F2604CEB7B6AD9B18924ECA075FE915576F49101DF2A881` |

Rodada 2: `.godot/verification/t5_impact_2/`.

| Passo | Nome | Resultado | sha256 da saída |
|---|---|---|---|
| 267 | `e07_f4_resume_staging_test` | PASS, 91 checks | `069915D17BA6A6494C42E41A2CC0EDA37AA7E06283B35CD16A66E4C42D048299` |

- Busca por `SCRIPT ERROR`, `still in use`, `Parse Error` e `Compile Error` nas saídas e
  nos logs do motor das duas rodadas: **0 ocorrências**. Nenhum timeout.
- O `WARNING: compact cut rehearsal failed` do passo 282 é o caminho de falha que o próprio
  teste exercita (`rehearsal_failed: 1` no tally).
- Passos rodados sem `-F1Fixture`. A suíte completa não foi repetida: a T5 não toca arquivos
  compartilhados.

## Limitações

1. **Ganchos pedidos à arquitetura, ainda sem resposta.** Perguntei em 16/11 à sessão
   `local_4643cd66` sobre (1) multiplicador de dano no passo 1 e (2) fonte temporária de
   atributo do kit. Vale o plano B de `t5_contract.md` §3.1:
   - o dano recebido na zona escala o próprio `hit.request`;
   - o gelo dá redução de dano equivalente, **não DEF real**: não aparece na ficha nem no
     `stat_breakdown`.

   As duas regras ficam numa única função (`_apply_owner_damage_rule` e
   `owner_damage_multiplier`). Trocar pelo gancho novo não muda a API dos kits.
2. **Multiplicador de cura:** só vale para curas que a costura reporta em `on_heal`
   (`heal_player`, `hp_regen`, `blood_thirst`). As curas diretas do Berserker e do
   Espiritualista não passam por lá, mas não pertencem às origens Espadachim e Mago.
3. **Deduplicação da Graça:** usa a identidade de evento do ledger
   (`root_event_id#event_id`), sem `claim_batch`; o motivo está em §4 do contrato. Depois de
   uma restauração, chaves antigas têm IDs de instância antigos. Elas não colidem com eventos
   novos.
4. **Coluna do Juízo:** é vertical por definição, raio x/z e faixa de altura de ±200. Ela
   atinge também um alvo numa laje acima do ponto. As zonas, ao contrário, respeitam o
   desnível.
5. **Apresentação:** o sistema não desenha a zona. O círculo e o cone no chão, as cargas
   sobre o elmo e a coluna são efeitos dos kits (`draw_vfx`, IDs reservados no recibo de cada
   kit). `describe()` dá forma, raio, elemento e relógios para isso.
6. **Mapa plano antigo:** a pertença usa posições da arena. O teste de desnível cobre só o
   mundo.
7. **Exportação:** o `include_filter` precisa de `scripts/systems/*/snapshot_manifest.json`
   (limitação 3 da T1). O fragmento da fixture fica em `scripts/systems/sanctuary/fixture/`,
   um nível abaixo; T10 pode excluí-lo do PCK.
8. **Escopo da supervisão:** execução, conclusão, erros, hashes e as invariantes de C2. Não é
   auditoria semântica independente.

## Arquivos não commitados

Ficaram fora do commit, como na T1:

- `.import` reescritos pelo editor (só fim de linha);
- `.gd.uid` soltos em `docs/map_editor/delivery/evidence/**` e
  `tests/e08_compact_coverage_test.gd.uid`;
- `.godot/`.

## Próximo passo

- K1 (Paladino) e K2 (Taumaturgo) partem do SHA entregue e seguem a seção "API para K1 e K2".
- A arquitetura responde às duas perguntas de gancho. Se houver gancho novo, a T5 troca o
  plano B na própria pasta.
