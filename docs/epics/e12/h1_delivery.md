# E12 H1 — Recibo de entrega da costura de HUD (C1, C2)

Executor: Sol (Claude Opus 5.5, esforço alto), sessão de tarefa H1. Data: 17/11/2026.
API para os consumidores: [h1_hud_seam_api.md](h1_hud_seam_api.md). Contrato:
[e12_contract.md](../e12_contract.md), §2 e §3.

## Identificação

| Campo | Valor |
|---|---|
| Base | `602b6321606fcee57c6ceae7fed1c5ab0ebe5789` (docs(e12): open the combat HUD milestone…), ponta de `claude/trusting-golick-2854b4` |
| Branch | `claude/e12-h1-708c9b` |
| Checkout real | `C:\Users\João Pedro\Documents\ChatGPT\RagRPG\.claude\worktrees\e12-h1-708c9b` |
| Commit de código | `3e95b62fe59d47fe87681e5ce103c2fea20f80d2`: costura, fixture, teste, verificador e API |
| Código validado | `3e95b62f` (a regressão abaixo rodou sobre o mesmo conteúdo, antes do commit) |
| SHA entregue | o commit deste recibo, filho direto de `3e95b62f`, só com documentação |

Sem push, sem `master`, sem tocar no playtest habitual (`codex/playtest`) nem no save pessoal.

## Escopo entregue

Todos os arquivos estão na linha H1 de [e12.md](../e12.md).

| Item do brief | Arquivo | Entrega |
|---|---|---|
| 1 | `scripts/classes/class_kit.gd` | `ClassKit.hud_state(player) -> Dictionary`, puro, padrão `{}` |
| 2 | `scripts/classes/kit_hud_state.gd` (novo) | `KitHudState`: `SCHEMA`, `validate(state, kit)` com os dez códigos de §2.3, `checked`, `reported_warnings`, `reset_reports` e as constantes do formato |
| 3 | `scripts/actors/player_actor.gd` | `kit_hud_state()`: `{}` sem kit; DTO inválido vira `{}` com um aviso por kit e código |
| 4 | `combat_actor.gd`, `player_actor.gd`, `enemy_actor.gd` | `cast_progress()` virtual; jogador nos dois caminhos (`active_cast_*`); inimigo por `_mob_cast` só com `cast_time > 0`; `category` por `occurrence.category_id` e `hard_controls.boss` |
| 5 | `scripts/actors/combat_actor.gd` | `overhead_bar_y()`; `_draw` passa a chamar o método na mesma conta (sem mudança visual) |
| 6 | `scripts/classes/fixture/hud/` (novo) | `fixture_hud_kit.gd` (DTO completo e uma variante inválida por código) e o fragmento `snapshot_manifest.json` (`hud_variant`, revisão 1) |
| 7 | `tools/verify.ps1` | `tests/e12` acrescentado à lista de grupos descobertos |
| 8 | `tests/e12/hud_seam_test.gd` (novo) | 188 checks |
| 9 | `docs/epics/e12/h1_hud_seam_api.md`, este recibo | API publicada e recibo |

**Regras preservadas.**
- Nenhuma regra, fórmula, sinal de gameplay, campo de snapshot ou revisão de fragmento mudou.
- O fragmento do fixture do E09 (`scripts/classes/fixture/snapshot_manifest.json`) ficou
  intacto. O fixture de HUD tem pasta e fragmento próprios, como os fixtures de sistema do
  E09.
- Os 4 kits de produção não foram tocados. O log do teste registra
  `production kit <id> hud_state keys = []` para os quatro. O teste exige só que a resposta
  valide, para H2 não precisar editar este teste.
- `player_actor.gd` continua sem nomear `EnemyActor` (A10), e nenhum ator importa o sistema
  de flanco. Os dois pontos são verificados no teste.
- Formato de save: inalterado. Como em toda mudança de script, a revisão de fonte do snapshot
  exato muda; nenhuma revisão de `snapshot_manifest.json` mudou.

**Decisões dentro do contrato** (descritas na API, seção 2):
- O validador não confere se o `target_id` está vivo, só o tipo e o sinal. Uma vítima que
  morre no quadro não apaga o HUD inteiro; o overlay ignora IDs que não conhece.
- Prefixos de `resources[].id`: o prefixo do kit, mais `sanctuary_` e `flank_`
  (`KitHudState.SYSTEM_PREFIXES`). Outro prefixo de sistema exige pedido à arquitetura.
- Campos em segundos ou distância aceitam `int` ou `float`. Contagens exigem `int`.
- `pips` só leva prazo com `unlimited`. `timer` não leva `value`/`max`. `badge` não leva
  `value`/`max`. `half_angle` só no cone, onde `facing` é obrigatório.
- O aviso de DTO inválido sai por `push_warning`, uma vez por par `"<kit_id>:<código>"` no
  processo.
- As skills válidas de cada script de kit ficam em cache, para não montar
  `skill_definitions()` a cada quadro.
- `label` do cast cai em `"Conjuração"` se a definição não tiver nome. Hoje isso não acontece.

## Validação

Motor: Godot 4.7.2 standard,
`C:\Users\João Pedro\Documents\ChatGPT\RagRPG\.tools\godot\Godot_v4.7.2-stable_win64.exe`,
chamado pelo PowerShell. O executável de console falha com `CreateProcess error 193`, como já
registrado no E09.

### Rodadas

1. **Importação e primeira execução.** `.godot/verification/e12_h1_seam/`, com `editor_import` e
   `hud_seam_test`, `-CheckTimeoutSeconds 300`. Com o limite padrão de 120 s, a importação
   estourou. Nesta rodada, `editor_import` passou e o teste novo deu 2 falhas, ambas do próprio
   teste:
   - um caso negativo usou uma chave `String` igual a uma `StringName` já presente, e o
     `Dictionary` do Godot sobrescreveu a entrada. O caso passou a usar uma skill ausente;
   - o mundo F1 exige `-F1Fixture`.

   Nenhuma expectativa de teste existente foi tocada.
2. **Fixture F1.** `.godot/verification/e12_h1_f1_import/`, `-Test e07_f1_import_test`, PASS.
   `checks.jsonl` sha256 `2073977e9920fb129195e47e0dff282e9bad4dc066ac7628a87bcbf5895a7401`.
3. **Regressão por impacto.** `.godot/verification/e12_h1_impact/`:

   ```
   tools/verify.ps1 -GodotPath <godot> -SkipEditorImport -F1Fixture -CheckTimeoutSeconds 300 `
     -VerificationDirectory .godot/verification/e12_h1_impact `
     -Test hud_seam_test,kit_seam_test,kit_seam_hooks_v2_test,kit_seam_hooks_v3_test,
           ui_evolution_test,flank_test,sanctuary_test,sp_ac_*,mg_ac_*,sp_la_*,mg_la_*,
           e06_tx_mob_test,e07_f1_consumer_test,e07_f6_runtime_test,e07_f3_continuation_test,
           e07_f1_cast_test,e07_f1_area_cast_test,e07_f3_snapshot_test,e07_f6_snapshot_test,
           e08_compact_checkpoint_test,e08_compact_coverage_test,actor_presentation_test,
           combat_animation_test,ground_shadow_cache_test,mage_gameplay_test
   ```

   Resultado: **"Selected checks passed (31/348 steps)"**. Exit 0 em todas as etapas, nenhum
   timeout, nenhuma linha `SCRIPT ERROR`. `checks.jsonl` sha256
   `5351339c2865c7c1a2e82387bebef31bdd4a8821c82562b384fef27534909ca1`.

| Índice | Etapa | Resultado | sha256 da saída (16 primeiros) |
|---|---|---|---|
| 10 | `combat_animation_test` | PASS (39) | `df1d52002e18c552` |
| 33 | `mage_gameplay_test` | PASS (52) | `02d14e4b0067a2fc` |
| 206 | `e06_tx_mob_test` | 27, 0 falhas | `5d56f0cd5ff05747` |
| 269 | `e07_f6_runtime_test` | 33, 0 | `34e113625593bd4c` |
| 270 | `e07_f6_snapshot_test` | 40, 0 | `2e091952f53115a7` |
| 274 | `actor_presentation_test` | 15, 0 | `73e5573636f71073` |
| 277 | `ground_shadow_cache_test` | 18, 0 | `79efd26e099c032c` |
| 282 | `e08_compact_checkpoint_test` | 48, 0 | `346b73697bfb3c19` |
| 283 | `e08_compact_coverage_test` | 95, 0 | `3c65add205f98f2d` |
| 294 | `e07_f3_snapshot_test` | 52, 0 | `9fc703c4ab2986dd` |
| 295 | `e07_f3_continuation_test` | 2743, 0 | `363698e32e808dd4` |
| 303 | `e07_f1_consumer_test` | 133, 0 | `c6dcf2641cc14490` |
| 305 | `e07_f1_cast_test` | 113, 0 | `f2ea264cbe518eba` |
| 306 | `e07_f1_area_cast_test` | 59, 0 | `decc28a0310117ff` |
| 331 | `kit_seam_hooks_v2_test` | 38, 0 | `5182f32b62de14be` |
| 332 | `kit_seam_hooks_v3_test` | 63, 0 | `d1dfd323c350f8f6` |
| 333 | `kit_seam_test` | 268, 0 | `ed82d9547ea52435` |
| 334 | `ui_evolution_test` | 97, 0 | `df7b1619f114033b` |
| 335 | `flank_test` | 205, 0 | `d23dc5d7b03b0fe0` |
| 336 | `sanctuary_test` | 155, 0 | `01b74920641522d9` |
| 337 | `mg_ac_boss_combat_test` | 29, 0 | `66ac49c680cb0d1b` |
| 338 | `mg_ac_kit_test` | 177, 0 | `814d744c0a070565` |
| 339 | `mg_la_boss_combat_test` | 33, 0 | `6710c89ec58026ec` |
| 340 | `mg_la_kit_test` | 231, 0 | `b480859d5403b1e8` |
| 341 | `mg_la_world_leap_test` | 49, 0 | `f2e59ee4f7352d9c` |
| 342 | `sp_ac_boss_combat_test` | 25, 0 | `269571175ce4e29b` |
| 343 | `sp_ac_kit_test` | 170, 0 | `2229f2dcd6dd2b0f` |
| 344 | `sp_la_boss_combat_test` | 31, 0 | `4f9c0f3fb7b9919f` |
| 345 | `sp_la_kit_test` | 217, 0 | `d2dc91b266e2e5a5` |
| 346 | `sp_la_parry_ai_test` | 55, 0 | `4f0c254bd31c88e4` |
| 347 | `hud_seam_test` | **188, 0** | `b79a9762a8523f43` |

As saídas inteiras e os logs do motor estão nas pastas acima, que ficam em `.godot`, fora do
Git. O `hud_seam_test` registra no log um `WARNING: KitHudState: …` para cada um dos dez
códigos: são os avisos únicos que o teste provoca de propósito.

### O que `hud_seam_test` prova

- **Padrões.** `ClassKit.hud_state` devolve `{}`, e `{}` valida até sem kit. São 10 códigos.
  `CombatActor.cast_progress` devolve `{"active": false}`. Um jogador sem kit não tem estado
  de HUD nem cast.
- **Produção.** Cada um dos quatro kits:
  - liga ao jogador real da sua build;
  - devolve uma resposta válida, igual à de `kit_hud_state`;
  - mantém campos do fragmento e `kit_time` depois de 100 leituras.
- **Cobertura do formato.** O DTO do fixture valida e usa:
  - todas as chaves do topo, de `resources`, `skills`, `zones` e `target_marks`;
  - os três `kind` de recurso, ∞ com prazo, os dois `kind` de marcador;
  - os dois espaços e as três formas;
  - uma skill pronta e uma recusada.

  São 12 variantes.
- **Negativos.** Cada variante inválida falha com o próprio código. Mais 63 casos de borda
  (a maioria negativos, alguns positivos para fixar o que é aceito), entre eles:
  - tipos `String` × `StringName`, prefixo, chave desconhecida, rótulo vazio;
  - limites de `value`/`max`, `unlimited`, pares de prazo, `timer`/`badge` sem valor;
  - cone sem `half_angle`/`facing`, plano com `z ≠ 0`, par `(target_id, key)` repetido;
  - `NaN` em vetor, `-INF` em recarga.

  `validate` não altera o dicionário.
- **Leitura pelo jogador.** O DTO válido volta idêntico, e `{}` não gera aviso. Cada código
  inválido vira `{}` em cinco leituras seguidas, com exatamente um aviso por `sp_ac:<código>`.
- **Pureza.** O fragmento do fixture de HUD se funde sem erro e cobre todo o estado do kit
  (`SnapshotRegistry._fields` sem `checkpoint_incomplete`). Em 100 leituras:
  - a resposta é a mesma;
  - nenhum campo do fragmento muda (cadeia inteira até `ClassKit`);
  - `kit_time` não muda;
  - `resources_changed` e `presentation_action` não são emitidos.

  Com a árvore pausada, a leitura funciona e um tick pausado não avança nada.
- **Cast no mapa plano** (skill de preparo do fixture):
  - formato exato das sete chaves; `skill_id`, `label`, `kind`, `category = player`;
  - `total` igual a `skill_cast_time`;
  - início cheio, meio na metade, pausa mantém a leitura idêntica;
  - Esc (`cancel_active_cast`) e movimento (`move_to`) cancelam com `cast_cancel`;
  - o fim deixa a leitura inativa e emite `skill_cast_ready` uma vez.

  A skill instantânea nunca aparece ativa, nem dentro dos próprios sinais.
- **Cast no mundo** (fixture F1, skill de preparo do kit sobre `mg_ac`):
  - o mesmo formato, início, meio e pausa (`_process` pausado);
  - Esc cancela; o fim deixa a leitura inativa.

  O teleporte instantâneo nunca aparece ativo.
- **Cast de mob** (`fire_spear` real, ocorrência `elite`):
  - formato, `label` e `category`; início, meio, pausa;
  - categorias `rare_elite`, `boss` (ocorrência), `boss` (controles, com categoria
    desconhecida) e `normal`;
  - o cancelamento por `clear_statuses` emite `cast_cancel` e deixa a leitura inativa;
  - registros sem `cast_time` (0 ou ausente) nunca ficam ativos.
- **Altura e fronteiras.** `overhead_bar_y` vale −54 sem sprite, −108 com escala 2 e
  `-altura*2 - 8` com sprite. `_draw` usa o método. Nenhum ator nomeia `EnemyActor` em
  `player_actor.gd` nem importa o flanco.

## Plano do verificador

`tools/verify.ps1 -List` passa de 347 para 348 etapas.
- As etapas 1–346 mantêm os índices.
- `hud_seam_test` entra como etapa 347, último grupo descoberto.
- `art_pipeline_tests` passa de 347 para 348.

O índice de `art_pipeline_tests` já depende do número de testes descobertos: mudou a cada
teste que K1–K4 acrescentaram em `tests/classes`. Esta mudança é a mesma, prevista pela regra
"acrescentar `tests/e12` à lista de grupos".

## Limitações

1. A vida do `target_id` não é validada (decisão acima); H3/H4 ignoram IDs desconhecidos.
2. No mundo, o movimento chega ao ator pela mesma chamada do Esc (`main.gd` chama
   `cancel_active_cast` e depois adota a rota). O teste cobre essa chamada no ator. O
   movimento real do mundo pela UI é coberto por H4.
3. A pureza dos kits de produção foi comparada nos campos de primeiro nível do fragmento. Um
   objeto interno (por exemplo, `SanctuaryAuthority`) é comparado por referência. A comparação
   do snapshot exato antes e depois é de H2, quando os kits passarem a ter `hud_state`.
4. Sem parte visual: `overhead_bar_y` reproduz a conta antiga, e `_draw` só troca a expressão
   pela chamada. Por isso não há captura. As capturas são de H3 e H4.
5. A suíte completa não foi rodada; só a regressão por impacto acima. A suíte completa é de H5,
   e a supervisão Luna, de H6.
6. A importação do editor na worktree gerou ruído no checkout: `.import` de arte com fim de
   linha trocado, `.import` e `.uid` novos sob `assets/` e `docs/map_editor/`. Eles foram
   descartados antes do commit; nenhum entrou no Git.

## Próximo passo

H1 está **ENTREGUE** e libera a onda 2. Os dois executores partem da ponta desta branch e leem
a API.
- **H2** (Sol, kits): `hud_state` dos quatro kits e invariante A6.
- **H3** (Terra, componentes): usa o fixture de HUD (`valid_state` e as 12 variantes) e
  `cast_progress` de fixture.

Depois da entrega de H1, o dono de `combat_actor.gd` (chamada de `ActorCastBar` em `_draw`)
passa para H4, conforme o índice.
