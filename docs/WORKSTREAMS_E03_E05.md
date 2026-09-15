# RagRPG — Workstreams operacionais E02→E05

> Base inspecionada: `codex/e02-character-menu` @ `7476698f6ab6ab8ebf8a4fc09a5bbf93d71f3f91`.
>
> Este arquivo é um handoff operacional. Em conflito, prevalecem `AGENTS.md`,
> `docs/WORKFLOW.md`, `docs/REVIEW_WORK_PACKAGES.md` e os contratos E00.

## 1. Lanes

- **SOL_HIGH**: arquitetura, matemática, APIs, persistência, runtime compartilhado, combate.
- **COPILOT_AUTO**: UI sobre API pronta, wiring, scenes, migração mecânica, testes repetitivos.
- **LUNA**: fixtures, tabelas, tooltips, textos, matrizes de casos, enumerações determinísticas.

### Segurança

Não executar Codex e Copilot simultaneamente no mesmo checkout/worktree.

Antes de trocar de executor:

```powershell
git status --short
git branch --show-current
git rev-parse HEAD
```

Revisar/commit-ar o pacote anterior e registrar o hash. Não refatorar trabalho do
executor anterior por preferência.

## 2. Protocolo automático de sessão

Antes de editar, qualquer agente deve:

1. Ler `AGENTS.md`, `docs/WORKFLOW.md`, `docs/REVIEW_WORK_PACKAGES.md`,
   `docs/E00_CONTRACT.md`, `docs/E00_02_STATS_CONTRACT.md`,
   `docs/E00_MVP_CLASS_CONTRACT.md`,
   `docs/ADR_E00_01_CHARACTER_PROGRESSION.md` e o `docs/epics/eXX.md` atual.
2. Registrar branch, HEAD, `git status --short` e diff pendente relevante.
3. Escolher **somente o primeiro pacote READY da sua lane**.
4. Declarar pacote, dependências, arquivos e testes.
5. Implementar apenas esse pacote.
6. Validar e terminar com: commit, arquivos alterados, testes, limitações e próximo pacote liberado.

Se o repo contradizer este documento, o repo vence. Não force um roteiro antigo.

### Stop conditions

LUNA/COPILOT_AUTO devem parar e escalar para SOL_HIGH se houver:

- mudança de schema/save;
- risco de perda/duplicação de XP;
- alteração semântica de `ProfileState`, `CharacterState`, `BuildSnapshot` ou `RunState`;
- fórmula nova de stats/dano;
- API pública compartilhada;
- novo comportamento compartilhado de cast/CC/guard/trap/stealth/projectile/navigation;
- duas correções focadas sem convergir;
- decisão de design ausente.

---

# 3. Fechamento de E02

## Estado

**Playtest/UI: aceito pelo usuário para o escopo MVP.**

Dívidas de UX/apresentação não bloqueiam E02.

O candidato já cobre criação/seleção de alts, dois presets, 5 ativas + 2 passivas,
filtragem legal, snapshot, menu→run→menu, hotkeys pela ordem do preset, passivas
equipadas e retry de fechamento de run.

Ranks alterando valores, atributos alterando combate e equipment modifiers são E03/E06.

## E02-CLOSE — READY

No projeto fixo:

```powershell
Set-Location 'C:\Users\João Pedro\Documents\ChatGPT\RagRPG'

git branch --show-current
git rev-parse HEAD
git status --short

Test-Path '.\.tools\review-engine\Godot.exe'

& .\tools\verify.ps1 `
  -GodotPath '.\.tools\review-engine\Godot.exe'
```

**Preferir sem `-SkipEditorImport`.** Esse modo primeiro faz um import headless limpo.

O script executa:

- import/editor headless;
- `foundation_test.gd`;
- `combat_animation_test.gd`;
- `milestone_one_test.gd`;
- `pursuit_momentum_test.gd`;
- `battle_ui_test.gd`;
- `arena_flow_test.gd`;
- `ui_layout_test.gd`;
- `mage_gameplay_test.gd`;
- `persistent_state_test.gd`;
- `profile_store_test.gd`;
- `profile_facade_test.gd`;
- `profile_run_facade_test.gd`;
- `e01_profile_diagnostic_test.gd`;
- `e02_character_menu_test.gd`;
- `e02_run_integration_test.gd`;
- smoke run do projeto por 5 s.

Falha em exit code != 0, `SCRIPT ERROR:`, `Parse Error:`, `ERROR:` ou timeout de 60 s.

### Aceite técnico suficiente de E02

- worktree sem alteração inesperada;
- `verify.ps1` termina com `All foundation and milestone-one checks passed.`;
- registrar hash/comando/resultado em `docs/REVIEW_E02.md`;
- registrar a dívida de UX como não bloqueante.

Depois: `E02 = DONE`.

---

# 4. Ownership

| Área | Dono |
|---|---|
| `ProfileFacade`, save/schema/migração | SOL_HIGH |
| `StatCalculator`, dano, HIT/FLEE, cast | SOL_HIGH |
| semântica de `BuildSnapshot`/runtime | SOL_HIGH |
| runtime compartilhado de skills | SOL_HIGH |
| guard/CC/trap/stealth/channel/navigation | SOL_HIGH |
| UI sobre API congelada | COPILOT_AUTO |
| scenes/wiring/testes mecânicos | COPILOT_AUTO |
| fixtures/tooltips/tabelas/casos | LUNA |
| receitas determinísticas | LUNA |
| catálogo após schema congelado | LUNA/COPILOT_AUTO |

---

# 5. E03 — Stats, job e skill levels

## Gate de entrada
E02-CLOSE concluído.

## E03-A — CORE STATS
**READY após E02-CLOSE — SOL_HIGH**

Criar autoridade canônica de stats (`StatCalculator`/`StatBreakdown`) conforme E00:

- primários, flat/increased/clamps;
- `melee_attack`, `precision_attack`, `magic_attack`;
- DEF/MDEF;
- HIT/FLEE;
- crit;
- ASPD;
- move speed;
- cast fixo/variável;
- after-cast/cooldown;
- HP/SP/regen;
- fixtures e testes.

Não redesenhar fórmulas E00.

### Libera
E03-L1, E03-C1, E03-B.

## E03-L1 — MATRIZ DE STATS
**BLOCKED por E03-A — LUNA**

Fixtures/casos de nível 1, caps, stats extremos, flat+increased e clamps.
Não criar fórmulas.

## E03-C1 — MIGRAÇÃO DOS CONSUMIDORES
**BLOCKED por E03-A — COPILOT_AUTO**

Migrar menu/HUD/ator para a API nova, sem copiar fórmulas.
Adicionar testes de igualdade preview/snapshot/runtime/HUD.

## E03-B — PROGRESSÃO E TRANSAÇÕES
**BLOCKED por E03-A — SOL_HIGH**

APIs transacionais para:

- saldos;
- atributos;
- carteiras base/evolução;
- comprar rank;
- requisitos;
- respec;
- snapshot efetivo;
- elegibilidade de evolução.

### Libera
E03-L2, E03-C2.

## E03-L2 — CASOS DE PROGRESSÃO
**BLOCKED por E03-B — LUNA**

XP 0, multi-level, cap, JL20 sem evolução, ranks gratuitos, falta de pontos,
requisitos, respec, reload.

## E03-C2 — PAINEL/ÁRVORE
**BLOCKED por E03-B + E03-C1 — COPILOT_AUTO**

XP base/job, pontos, seis atributos, ranks, requisitos e tooltips via APIs públicas.
UI não deriva fórmulas.

## E03-I — INTEGRAÇÃO
**BLOCKED pelos anteriores — SOL_HIGH**

Fechar quando menu/snapshot/HUD/combat concordarem numericamente e reload persistir tudo.

---

# 6. E04 — três classes base

## Gate
E03-I.

## E04-S0 — SKILL RUNTIME EXTENSÍVEL
**SOL_HIGH**

Eliminar o crescimento indefinido de `if skill_id == ...` no controller/ator.
Criar só a abstração necessária: rank definition, targeting, handler estável,
hooks de emissão/impacto e custos/tempos via definição.

Não criar engine universal.

## Espadachim

- **E04-SP-S / SOL_HIGH**: guard frontal, perfect guard, shield/impact, knockback controlado.
- **E04-SP-C / COPILOT_AUTO**: compor kit, catálogo, ranks, UI, duas builds e testes.
- **E04-SP-L / LUNA**: ranks/textos/fixtures já aprovados.

## Mago

- **E04-MG-S / SOL_HIGH**: Ice Wall sólida+navigation, Haunt/Fear, Ghost Barrier,
  lightning primitive e channeling.
- **E04-MG-C / COPILOT_AUTO**: integrar kit/catálogo/indicators/testes.
- **E04-MG-L / LUNA**: ranks/tooltips/casos normal-boss-cancelamento.

## Arqueiro

- **E04-AR-S / SOL_HIGH**: precision projectile pipeline, trap runtime,
  stealth/occlusion e targeting.
- **E04-AR-C / COPILOT_AUTO**: tiros, perfuração, traps, ocultação, catálogo e testes.
- **E04-AR-L / LUNA**: ranks/textos/fixtures.

## E04-I — integração
**SOL_HIGH**

Cada base conclui encontros, enfrenta melee/ranged, tem duas builds,
skill levels funcionam e nenhuma depende de augments.

---

# 7. E05 — evoluções e híbridas

## Gate
E04-I.

## E05-1S — TRANSAÇÃO DE EVOLUÇÃO
**SOL_HIGH**

Requisitos BL/JL, origem persistente, troca de evolução, carteira de evolução,
rank gratuito, limpeza de presets ilegais, atomicidade e snapshot.

## E05-1C — UI DE EVOLUÇÃO
**COPILOT_AUTO**, após E05-1S.

## E05-1L — MATRIZ DE EVOLUÇÃO
**LUNA**, após E05-1S.

Casos BL/JL insuficientes, origem errada, pura↔híbrida, presets, carteira, reload.

---

# 8. E05 — híbridas em ondas

Não implementar as seis simultaneamente.

## Onda 1

### Cavaleiro Rúnico
- **SOL_HIGH**: Carga Rúnica, gramática 3 tokens, guard hooks, formula runtime.
- **LUNA**: enumerar as 18 fórmulas `(a,b,c)` com `c != b`.
- **COPILOT_AUTO**: preview/UI/skills sobre runtime.

### Devastador Astral
- **SOL_HIGH**: Tensão, recorder de até 3 emissões melee, replay seguro de ecos.
- **LUNA**: casos de ordem/expiração.
- **COPILOT_AUTO**: skills/HUD/testes.

## Onda 2

### Baluarte de Cerco
- **SOL_HIGH**: linha/âncora, Pressão de Cerco, perfect guard→realocação.
- **LUNA**: crossing/flanco/boss/pressure.
- **COPILOT_AUTO**: Pavês, indicators e wiring.

### Saqueador
- **SOL_HIGH**: autoativação de trap, dash, Unstoppable, Ímpeto, bleed/rearme.
- **LUNA**: trap/rearme/bleed/cooldown/boss matrix.
- **COPILOT_AUTO**: três traps e skills compostas.

## Onda 3

### Geômetra
- **SOL_HIGH**: vertex runtime, validação geométrica, paredes/triângulos, hooks.
- **LUNA**: 6 paredes + 27 triângulos e fixtures geométricas.
- **COPILOT_AUTO**: editor/preview/Translação/Reescrita.

### Caçador de Espectros
- **SOL_HIGH**: soul trails, interseção tiro/rastro, spectral transform, banishment.
- **LUNA**: TTL/segmentos/marcas/boss/proc cases.
- **COPILOT_AUTO**: traps/indicators/wiring.

---

# 9. Prompts rápidos

## SOL_HIGH

Leia `docs/WORKSTREAMS_E03_E05.md`. Você é `SOL_HIGH`.
Inspecione branch/HEAD/status e execute somente o primeiro pacote READY de alto risco.
Antes de editar, declare pacote, dependências, arquivos e testes.
Congele uma API consumível ao terminar. Não inicie o pacote seguinte.

## COPILOT_AUTO

Leia `docs/WORKSTREAMS_E03_E05.md`. Você é `COPILOT_AUTO`.
Execute somente o primeiro pacote READY dessa lane.
Confirme que a API/primitiva dependente existe no HEAD.
Se faltar API, pare. Não altere fórmulas, persistência ou runtime compartilhado.

## LUNA

Leia `docs/WORKSTREAMS_E03_E05.md`. Você é `LUNA`.
Execute somente o primeiro pacote READY de baixo risco.
Trabalhe com fixtures/dados/textos/combinações já definidos.
Se algo estiver sem definição, marque OPEN; não invente.

---

# 10. Checkpoint

```text
E02-CLOSE:
  status: DONE
  verified_commit: 7476698f6ab6ab8ebf8a4fc09a5bbf93d71f3f91
  verify_result: PASS — tools/verify.ps1 completed; all checks passed
  verified_at: 2026-09-15
  verify_command: tools/verify.ps1 -GodotPath ./.tools/review-engine/Godot.exe
  user_playtest: ACCEPTED_MVP_SCOPE

E03-A: VERIFY_PENDING
E03-L1: BLOCKED
E03-C1: BLOCKED
E03-B: BLOCKED
E03-L2: BLOCKED
E03-C2: BLOCKED
E03-I: BLOCKED

E04-S0: BLOCKED
E04-SP-S/C/L: BLOCKED
E04-MG-S/C/L: BLOCKED
E04-AR-S/C/L: BLOCKED
E04-I: BLOCKED

E05-1S/C/L: BLOCKED
E05-H1-S/L/C: BLOCKED
E05-H2-S/L/C: BLOCKED
E05-H3-S/L/C: BLOCKED
E05-H4-S/L/C: BLOCKED
E05-H5-S/L/C: BLOCKED
E05-H6-S/L/C: BLOCKED
```

## Dívida E02 não bloqueante

Não reabrir E02 só por:

- visual provisório do menu;
- hierarquia/UX ainda simples;
- conexão visual fraca entre preset, personagem e equipamento;
- preview de avatar/equipamento;
- estética final de MMORPG coreano;
- transições/animações.

Planejar isso em E08/E09 ou em pacote futuro de UX.

## Princípio final

`SOL_HIGH congela sistema/API`
→ `LUNA prepara dados/casos`
→ `COPILOT_AUTO integra/repite`
→ `SOL_HIGH fecha fronteiras`
→ próximo pacote.

A execução local é sequencial; paraleliza-se o planejamento, não a autoria concorrente.
