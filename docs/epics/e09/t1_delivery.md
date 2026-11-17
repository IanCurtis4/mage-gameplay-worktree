# E09 T1 — Recibo de entrega da costura de kits (C1)

Executor: Sol (sessão de tarefa T1). Data: 16/11/2026.
API para os consumidores: [t1_kit_seam_api.md](t1_kit_seam_api.md).

## Identificação

| Campo | Valor |
|---|---|
| Base (`--ff-only`) | `771a314f78c7a0cb5fda2f1f48d93bc6dc776b68` (docs(e09): match verifier flags to tools/verify.ps1) |
| Branch | `claude/mystifying-moser-f04ddc` |
| Checkout real | `C:\Users\João Pedro\Documents\ChatGPT\RagRPG\.claude\worktrees\mystifying-moser-f04ddc` |
| Commit de código 1 | `ca413828e4bec283f29b657dab2e9e78ddadf542`: registro, ganchos, marcas, primitivas de ameaça e fragmentos |
| Commit de código 2 | `b4145c8d9f1785772ae4a898f4e6aa2ab2e5f90d`: remove a referência de script `PlayerActor` → `EnemyActor` |
| Código validado | `b4145c8d` (a suíte completa abaixo roda sobre ele) |
| SHA entregue | o commit deste recibo, filho direto de `b4145c8d`, só com documentação |

Sem push, sem `master`, sem tocar no playtest habitual (`codex/playtest`) nem no save pessoal.

## Escopo entregue

As 13 obrigações de C1 de `e09_contract.md` estão implementadas nos arquivos da linha T1 de
`docs/epics/e09.md`. O mapa de arquivos e a API de cada obrigação estão em
`t1_kit_seam_api.md`, nas seções 1 a 10.

- Nenhum kit existente foi migrado.
- As 10 identidades jogáveis mantêm o comportamento.
- Nenhum teste existente mudou de expectativa.
- As quatro híbridas de kit (`sp_ac`, `mg_ac`, `sp_la`, `mg_la`) existem como módulos vazios, sem `ready_for_play`.
- O kit de fixture fica em `scripts/classes/fixture/`, fora do registro de produção.

**Formato de save: inalterado.** Os campos de kit entram pelos fragmentos de snapshot por kit (C1.9), sem novo campo no perfil e sem aumento de versão.

## Validação

O motor usado foi o Godot 4.7.2 standard. O caminho é
`C:\Users\João Pedro\Documents\ChatGPT\RagRPG\.tools\godot\Godot_v4.7.2-stable_win64.exe`,
chamado pelo PowerShell. O executável de console falha com o "ã" do caminho.

### Teste novo

`tests/e09/kit_seam_test.gd`, passo 329 do plano: **175 checks, 0 falhas**.
Saída: sha256 `45F637A085EF4FBA26D70B7A24A6A3BD7882EB0DE61FF85AA0C874B49C034E22`.
Usa só perfis e saves de fixture.

### Suíte completa (`tools/verify.ps1`, sem filtro `-Test`)

O plano tem 329 passos (`verify.ps1 -List`). Cada passo rodou numa chamada própria de
`verify.ps1 -FromStep N -ToStep N -CheckTimeoutSeconds 300`, com retomada. Quatro passos
de bootstrap rodaram sem fixture: `editor_import`, `e07_f0_import_test`,
`e07_f1_import_test` e `e07_f1_native_import`. Os demais rodaram com `-F1Fixture`.

**Rodada sobre `b4145c8d`** (`.godot/verification/t1_suite_b4145c8d/`):

- `summary.jsonl`: sha256 `632490EC89908EDE68F06D4CCDF9667B298CC3C2436DB935BBE4889026216897`. São 329 linhas, sem timeout, e 326 passos passaram.
- Falhas:
  - **255 `e07_f1_native_import`**: falha conhecida da base em worktree novo. A saída (sha256 `AB79025F6B8201D30245FD016889D79306A398E5D3D1C02D5CAF801D5E17831F`) mostra `Cannot get class 'GitPlugin'` e `Received a nullptr VCS extension instance`. Não depende de T1.
  - **324 `e07_f8_candidate_prepare`** e **325 `e07_f8_candidate_resume`**: deu `prepare requires fresh synthetic profile`. É estado antigo, não regressão. O diretório isolado do probe (`.godot/verification/e07_f1/fixture_project/.godot/verification/e07_f8/probe_headless`) guardava o perfil sintético criado pela rodada anterior, sobre `ca413828`, e o `verify.ps1` não limpa esse diretório entre execuções. Movi o diretório antigo para o scratchpad da sessão e rodei os dois passos de novo (`.godot/verification/t1_suite_b4145c8d_f8rerun/`):
    - 324 deu PASS com 16 checks e 0 falhas. Saída: `EF105D37EA5DDD57742C2BB4BCA4CB736637BC9532EB1AC451BACBF9F697223F`.
    - 325 deu PASS com 61 checks e 0 falhas. Saída: `CAB48B9A09224BD8DC0BCB529AE8CF99CF81AF3E4CEAFF576FC14BBF9530DDB6`.
- Saída zero não bastou. Procurei `SCRIPT ERROR`, `still in use`, `Parse Error`, `Compile Error` e `FAIL` nas saídas dos 326 passos que passaram e encontrei **0 ocorrências**. Nenhuma saída veio vazia.
- Testes do Mago E04, que eram as regressões da primeira rodada:
  - 89 `e04_mage_electric_discharge_rank_integration_test`: PASS, 71 checks.
  - 92 `e04_mage_haunt_rank_integration_test`: PASS, 84 checks.
  - O restante do bloco 61 e 88–95 também passou.

**Rodada anterior sobre `ca413828`** (`.godot/verification/t1_suite_ca413828/`), mantida como histórico:

- `summary.jsonl`: sha256 `77FEF791A9EA54AD726E4E02C9B2F0B267D0F28DDF951AB171736E728EF0CD6B`.
- Falhas:
  - 255, a falha conhecida acima.
  - 89 e 92: os dois testes do Mago passavam nos checks, mas o motor terminou com "N resources still in use at exit", e o verificador trata isso como falha.
- Causa: `player_actor.gd` passou a nomear `EnemyActor` (`as EnemyActor`). Isso fechou um ciclo de script `PlayerActor` ↔ `EnemyActor` que o Godot 4.7.2 não libera na saída quando um script com lambda tipada carrega os dois. Isolei a causa por bissecção hunk a hunk numa worktree descartável, já removida.
- Correção em `b4145c8d`:
  - O acesso ao livro de ameaça passa por `has_method`/`get`, sem nomear o tipo.
  - `kit_seam_test` ganhou checks dos ajudantes e uma guarda que impede a referência de voltar.

## Limitações

1. **`EffectDefinition.Kind.KIT_RULE`** (políticas de kit em itens) não entra pela costura. `BuildEffectComposer` lê `BuildEffectCatalog.KIT_POLICIES` direto, e esse arquivo não é de T1.
2. **`tests/e05_evolution_catalog_test.gd`** espera exatamente quatro destinos do Mago. Quando K2 ou K4 ligar `ready_for_play`, esse teste vai falhar por expectativa, e a atualização dele precisa de decisão da arquitetura.
3. **Exportação:** o `include_filter` de `export_presets.cfg` precisa incluir os `snapshot_manifest.json` dos kits e dos sistemas antes do candidato (T10). Sem isso, a captura falha no PCK com `unknown_runtime_kind`, sem perder dados.
4. **Mapa plano antigo:** `break_sight` só age sobre a ameaça. A aquisição pela posição (`can_be_acquired_by(position)`) não conhece o observador.
5. **Elemento da skill:** o campo usado é `SkillDefinition.element`, com valores em `ClassKitRegistry.KIT_ELEMENTS`. Não são `tags`, porque `tags` só aceita `EffectTags` de item.
6. **Ciclos de script no Godot 4.7.2:** `player_actor.gd` não pode nomear `EnemyActor`. Os módulos de kit podem, porque são carregados por caminho. Detalhes na seção 13 da API.
7. **Estado do probe F8:** rodar a suíte duas vezes no mesmo checkout exige limpar o diretório `probe_headless` do projeto de fixture. Corrigir `verify.ps1` ou o probe fica fora do escopo de T1. Registrado como follow-up.
8. **Escopo da supervisão:** o que foi verificado é execução, conclusão, erros e hashes dos testes, mais as invariantes do contrato. Não é auditoria semântica independente.

## Arquivos não commitados

Ficaram fora do commit, de propósito:

- arquivos `.import` reescritos pelo editor, só com troca de fim de linha;
- arquivos `.gd.uid` soltos em `docs/map_editor/delivery/evidence/**` e `tests/e08_compact_coverage_test.gd.uid`, gerados pela importação;
- saídas em `.godot/verification/`, que o Git ignora.

## T1.1 — Ganchos para as regras de C2 sobre o dono

Pedido da arquitetura, para a T5, feito em 16/11/2026 na mesma branch, a partir de `337aa7df`.
Arquivos: `scripts/classes/class_kit.gd`, `scripts/actors/player_actor.gd`,
`tests/e09/kit_seam_hooks_v2_test.gd` (novo) e esta documentação. A API está em
`t1_kit_seam_api.md`, nas seções 4, 4.2, 4.3 e 4.4.

- **Multiplicador de dano recebido.** `before_hit_mitigation` pode devolver a chave opcional
  `"damage_multiplier": float`.
  - `PlayerActor.apply_damage` testa `cancel` primeiro e só depois aplica `damage_dealt_multiplier *= m`
    numa cópia do pedido (`request.copy()`), antes de `_apply_damage_base`.
  - O valor é ignorado quando falta, não é número, não é finito ou é negativo; `1.0` segue o caminho
    sem cópia. `0.0` é aceito.
  - Quando `m != 1`, o resultado ganha `kit_damage_multiplier`. O `hit["request"]` que chega a
    `after_hit_mitigation` continua sendo o original.
- **Fontes de atributo temporárias.**
  - `ClassKit.temporary_stat_sources(player)` devolve vazio por padrão.
  - `PlayerActor.temporary_stat_sources()` soma o resultado no formato da fonte `defender_anchor`.
  - O novo `PlayerActor.refresh_kit_stats()` recompõe o breakdown pelo caminho de Fúria e do Marco
    (`_apply_derived_stats(_build_stat_breakdown())`). Ele é idempotente, não cura, não recarrega SP
    e não zera recarga.
- **A10:** `player_actor.gd` continua sem nomear `EnemyActor`. A guarda de `kit_seam_test` passou.
- **Sem mudança de save.** As duas extensões são estado derivado: o multiplicador vale por golpe e
  as fontes saem do estado do kit, que o fragmento dele já persiste.
- **Kit de fixture e testes da T1:** `kit_seam_test.gd` e `fixture_kit.gd` não foram tocados. O
  teste novo usa uma subclasse do kit de fixture declarada no próprio arquivo e não faz captura
  de snapshot com ela.

### Validação T1.1 (regressão por impacto, sem repetir a suíte inteira)

- **Execução.** Rodei os passos sobre a árvore de trabalho com base em `337aa7df`, já com o conteúdo
  deste commit, e com o novo plano de 330 passos (`kit_seam_hooks_v2_test` é o 329, `kit_seam_test`
  passou a 330).
  - Cada passo foi uma chamada `verify.ps1 -FromStep N -ToStep N -CheckTimeoutSeconds 300`.
  - O bootstrap (`editor_import`, `e07_f1_import_test`) rodou sem fixture; os demais com `-F1Fixture`.
  - Saídas em `.godot/verification/t1_1_impact/`. O `summary.jsonl` tem sha256
    `A206234D10F54A0E9CEF563C40C9277CE4E291D6F2A0BFC5ED5E5988524F6A67`: 26 passos, 0 falhas,
    0 timeouts.
- **Busca nas 26 saídas** por `SCRIPT ERROR`, `still in use`, `Parse Error`, `Compile Error` e `FAIL`:
  0 ocorrências. Nenhuma saída veio vazia.

| Passo | Resultado | sha256 da saída |
|---|---|---|
| 329 `kit_seam_hooks_v2_test` | 38 checks, 0 falhas | `5182F32B62DE14BE5938AF67C615BFBC0CBB6BDF062A64EDB08131758CF6FA5A` |
| 330 `kit_seam_test` | 175 checks, 0 falhas (hash idêntico ao da T1) | `45F637A085EF4FBA26D70B7A24A6A3BD7882EB0DE61FF85AA0C874B49C034E22` |
| 9 `foundation_test` | PASS, 20 | `10C00F261A4572819C6B3293933D567298A2335AB50E19A710DBE5FA5445374B` |
| 10 `combat_animation_test` | PASS, 39 | `DF1D52002E18C5524FA60801186A018CDBC71C91E0248051E38F6565C154FB1E` |
| 28 `milestone_one_test` | PASS, 64 | `064BEAF0DAA82FE14CD8323E948F820032897B5E6CE9EDEC03BAD229090F4185` |
| 33 `mage_gameplay_test` | PASS, 52 | `02D14E4B0067A2FC483B56F165EC8534C00262007966F3D45930D287E2919C5C` |
| 43 `e03_stat_calculator_test` | PASS, 39 | `403C2A716927AD4067404B9AD8DE0AA024C7A9ECC9033DDBCF9B2149CFB3B90A` |
| 96 `e04_swordsman_shield_wall_rank_integration_test` | PASS, 88 | `A177365260FF37996E22544E992784664A4F68B00B2763E1EF3D71800E87DABD` |
| 100 `e04_swordsman_fury_rank_integration_test` | PASS, 29 | `C84F643793E20631B90F2D3AF14BFEAF671364D056B547F8C101833E856479D8` |
| 186 `e05_defender_catalog_test` | PASS, 92 | `0CC3FF660876BBC226671D7B9B96E6392C86B11C37A25700F08475EC9B7F052C` |
| 187 `e05_defender_indicators_test` | PASS, 11 | `FB1A35874F77B05561734CBCB6BC8373CF1FB420A29EFD52E37A6AEA9E57E52C` |
| 188 `e05_defender_guard_test` | PASS, 18 | `3593F6915E417D89309B6242D7A57394EA1CCB3CF49B601A7F3ABA9BF565F015` |
| 189 `e05_defender_skills_test` (Marco) | PASS, 32 | `E7D81B2C6E5ADFD0B7929A7B1E28B3EE5A195BFEB56B980F7E58BD06531E9AB9` |
| 190 `e05_defender_watch_test` | PASS, 7 | `253B0803066347F098D295740A049C98106D338FBE2AC1BA91B495F8BED69535` |
| 191 `e05_defender_builds_test` | PASS, 73 | `9A3AE53C622C97FDC1DD99695101E5521E4DB02FDBFBFC46322665EE0389AE05` |
| 192 `e05_defender_playtest_flow_test` | PASS, 18 | `8853528292FE9119FF47FA8046D3F1B49ACD4A8FDA1E2F3ED705A4A8FB2B1C03` |
| 310 `e07_f1_guard_travel_test` | 293 checks, 0 falhas | `0DD468D2FE6986F208C9B58766E3916BAE42F315A3B6483D1C5C8AD0CF229EE4` |
| 268 `e07_f6_threat_test` | 43 checks, 0 falhas | `C38ACB2F6A0A4F101776B095EE0A68791A65E72A12D77D5317B2EB793EFA2AD3` |
| 270 `e07_f6_snapshot_test` | 40 checks, 0 falhas | `2E091952F53115A75311BF2F4CFD595A18B2E8C64FA3076CBF6F844F4CC4EDC6` |
| 294 `e07_f3_snapshot_test` | 52 checks, 0 falhas | `9FC703C4AB2986DDAAB73ED386092F3B8AB71A5EA82C4A7C3C781D2F6F06C0CC` |
| 298 `e07_f3_mob_state_test` | 372 checks, 0 falhas | `A84CACBF8F2342C0644F9985DB703A0244FE421411DF868C5C53B6D24FDEB815` |
| 282 `e08_compact_checkpoint_test` | 48 checks, 0 falhas | `346B73697BFB3C1975A5B0B2196C99CC96AE95E389DFA441C3EDBDC5FFDCA1EC` |
| 283 `e08_compact_coverage_test` | 95 checks, 0 falhas | `3C65ADD205F98F2D063AFCF6DAD256C3F207D51AAE7376621D38801D89228796` |
| 290 `e07_f5_death_kits_test` | 191 checks, 0 falhas | `2DA02990DCFAE18C994ADDD224C583408B5995CE97C3F943C1E96D67D2E843AA` |
| 1 `editor_import` | PASS (bootstrap) | `DBA7392EC9D1D607F810BB46170108E71581239E3A56AB840F9C0FF30A7D016B` |
| 256 `e07_f1_import_test` | PASS (bootstrap), 3267 arquivos idênticos | `07BEA14C18FA37738778B69B43E5C9504079800BD50F410266EA14AD19DB192F` |

### Limitações T1.1

- A suíte inteira não foi repetida, conforme o pedido. Os passos fora da lista acima
  não rodaram com estas mudanças.
- O multiplicador entra antes das reduções existentes (frontal, guardas) e se multiplica com
  elas. Ele não substitui nem limita essas reduções.
- `refresh_kit_stats()` precisa ser chamado pelo kit. O breakdown não sonda as fontes do
  kit a cada tick.
- O teste com dano zero verifica que `0.0` é aceito e registrado, mas não fixa o valor final
  do dano, que depende do piso de `HealthState`/`CombatMath`.

## T1.2 — Custo efetivo e commit das skills da origem (decisão A13)

Pedido da arquitetura em 16/11/2026, feito na mesma branch a partir de `bd66d3c3`.
Commit entregue: `ca27db8a` (código, testes e documentação). Este registro do SHA está num commit
de recibo à parte.

Arquivos alterados:

- `scripts/classes/class_kit.gd`
- `scripts/actors/player_actor.gd`
- `scripts/main.gd`
- `scripts/classes/fixture/{fixture_kit.gd,snapshot_manifest.json}`
- `scripts/core/expedition/snapshot/runtime_manifest.json`
- `tests/e09/kit_seam_hooks_v3_test.gd` (novo)
- `t1_kit_seam_api.md`, nas seções 2.1, 4, 4.3, 4.5 e 12

### `ClassKit.skill_cost(player, skill_id, base_cost) -> float`

- O padrão devolve `base_cost`.
- `PlayerActor.skill_cost()` passou a ser a fonte única do custo efetivo. Ela chama o kit sobre
  `base_skill_cost()`, que mantém a regra antiga: o custo vem do rank de runtime ou, na falta dele,
  de `definition.sp_cost`.
- Um valor não finito volta ao custo base, e o piso é `0`.
- Leem esse valor:
  - `_can_pay_skill`;
  - `_spend`;
  - a UI (card do HUD e tooltip);
  - a reserva da Sentinela.
- As linhas "SP base" continuam mostrando o custo base.
- A regra também vale para as skills do próprio kit.

### Reserva da Sentinela (`sentinel_explosive_shot`)

- A reserva trava o custo efetivo no momento da preparação.
- O lançamento debita exatamente o valor reservado com `_spend(id, reserved_sp)`, mesmo que o kit
  mude a regra no meio do caminho.

### `ClassKit.on_base_skill_committed(player, skill_id, context)`

- **Onde dispara:** em `_spend`, que é o ponto único de pagamento. A chamada vem depois do débito e
  do fato `skill_committed`, e antes da resolução.
- **Quando dispara:**
  - só para skills que não pertencem ao kit;
  - uma vez por commit pago. A guarda `first_commit` cobre o comando de mundo, que reentra em
    `_spend`.
- **Quando não dispara:**
  - em cast recusado, porque `_spend` não é alcançado;
  - no ataque básico, que não passa por `_spend`.
- **Contexto:** `target` (CombatActor vivo ou `null`), `point`, `world`, `rank` e `element`.
- **Origem do contexto, nesta ordem:**
  1. o comando de mundo em execução;
  2. a nota `note_base_commit()` deixada pelo chamador: `Main._execute_skill`, dash e teleporte nos
     dois caminhos, Sentinela e Geômetra;
  3. a posição do jogador.
- **Elemento:** vem de `SkillDefinition.element`, com a tabela `BASE_SKILL_ELEMENTS` como
  reserva. Não há aresta Registry → ClassCatalog nem leitura de FeedbackRecipeCatalog.
- **A nota é transitória:**
  - `_spend` sempre a consome, inclusive no retorno recusado do comando de mundo;
  - `Main._execute_skill` a limpa depois do despacho;
  - ela está declarada em `omitted` no `runtime_manifest.json`, com o motivo.

### Demais pontos

- **Exemplo da API:** a skill de entrada do job 20, no exemplo de `learning_entries`, não tem mais
  `prerequisites`. O pré-requisito `paladin_oath: 2` foi para uma linha do job 25.
- **A10:** `player_actor.gd` continua sem nomear `EnemyActor`, porque o contexto tipa `target`
  como `CombatActor`. A guarda de `kit_seam_test` passou.
- **Sem mudança de save.** Os dois ganchos produzem estado derivado.
  - `runtime_manifest.json` só ganhou a justificativa de `_base_commit_hint` em `omitted`. Não há
    campo novo capturado nem mudança de revisão.
  - O manifesto do kit de fixture ganhou `cost_scale`, `cost_offset` e `base_commits`. A revisão
    ficou em 1 porque o arquivo é só de fixture.
  - O save pessoal não foi tocado.
- **Kit de fixture:**
  - a regra de custo é `cost_scale * base + cost_offset`, que por padrão é a identidade;
  - `base_commits` registra cada commit das skills da origem, só com IDs de entidade;
  - o v3 cobre o kit sem os ganchos e o jogador sem kit, que se comportam como hoje;
  - `kit_seam_test.gd` não foi tocado.

### Validação T1.2 (regressão por impacto, sem repetir a suíte inteira)

**Como rodou**

- Os passos rodaram sobre a árvore de trabalho com base em `bd66d3c3`, já com o conteúdo deste
  commit.
- O plano tem 331 passos: `kit_seam_hooks_v3_test` é o 330 e `kit_seam_test` passou a ser o 331.
- Cada passo foi uma chamada `verify.ps1 -FromStep N -ToStep N -CheckTimeoutSeconds 300`.
- O bootstrap rodou sem fixture; os demais passos, com `-F1Fixture`.

**Primeira rodada** (`.godot/verification/t1_2_impact/`)

- Houve 9 falhas, todas com a mesma causa: o novo membro `_base_commit_hint` não estava
  classificado no esquema de snapshot (detalhe `checkpoint_incomplete`).
- Correção:
  - declarar o membro em `omitted`;
  - limpar a nota no retorno recusado de `_spend`.
- Nenhuma expectativa de teste mudou.

**Rodada final** (`.godot/verification/t1_2_impact_r2/`)

- O `summary.jsonl` tem sha256 `C4B20F1F65E23B5AEA6991326954DB8FA3FBA3E4EA5C15CADC1C92EEDE629881`.
- Foram 179 passos, com 0 falhas, 0 timeouts e nenhuma saída vazia.
- Passos incluídos:
  - o bootstrap;
  - os `e04_*`, que cobrem os ranks das origens Espadachim e Mago, com dash e teleporte;
  - os `e05_*` de Sentinela, Caçadora, Geômetra, Elementalista, Espiritualista, Defensor e
    Berserker;
  - `e07_f6*`, `e08_compact*`, `e07_f3_snapshot`, `e07_f5_death_kits` e `e07_f1_*`;
  - `mage_gameplay`, `foundation`, `milestone_one`, `combat_animation`, `battle_ui`, `ui_layout`,
    `arena_flow`, `e02_run_integration`, `e08_pilot` e `e08_presentation`;
  - `kit_seam`, v2 e v3.

**Busca nas 179 saídas**

- Procurei `SCRIPT ERROR`, `still in use`, `Parse Error`, `Compile Error`, `FAIL` e `ERROR:`,
  diferenciando maiúsculas e exigindo fronteira de palavra.
- Resultado: 0 ocorrências.

| Passo | Resultado | sha256 da saída |
|---|---|---|
| 330 `kit_seam_hooks_v3_test` | 63 checks, 0 falhas | `D1DFD323C350F8F63140F3D8D86FE01FB566BAEE11ED3A93B953FBF99F78F449` |
| 329 `kit_seam_hooks_v2_test` | 38 checks, 0 falhas (hash idêntico ao da T1.1) | `5182F32B62DE14BE5938AF67C615BFBC0CBB6BDF062A64EDB08131758CF6FA5A` |
| 331 `kit_seam_test` | 175 checks, 0 falhas (hash idêntico ao da T1) | `45F637A085EF4FBA26D70B7A24A6A3BD7882EB0DE61FF85AA0C874B49C034E22` |
| 9 `foundation_test` | PASS, 20 | `10C00F261A4572819C6B3293933D567298A2335AB50E19A710DBE5FA5445374B` |
| 28 `milestone_one_test` | PASS, 64 | `064BEAF0DAA82FE14CD8323E948F820032897B5E6CE9EDEC03BAD229090F4185` |
| 33 `mage_gameplay_test` | PASS, 52 | `02D14E4B0067A2FC483B56F165EC8534C00262007966F3D45930D287E2919C5C` |
| 11 `e08_presentation_test` | 2255 checks, 0 falhas | `DF8A4BF3E4C4CFE9CF897EF65BE23D0CA416B02F33626DA96DC9A96216CCA12B` |
| 14 `e08_pilot_test` | 350 checks, 0 falhas | `B60FB21A6B5C9B5086AE9BCF8A460F67D313D7BC4EB6CF7DAB24666927D4E52D` |
| 268 `e07_f6_threat_test` | 43 checks, 0 falhas | `C38ACB2F6A0A4F101776B095EE0A68791A65E72A12D77D5317B2EB793EFA2AD3` |
| 269 `e07_f6_runtime_test` | 33 checks, 0 falhas | `34E113625593BD4C3EDF7E39D8B9B850F92143576E6D359A55E45841AB119FDA` |
| 270 `e07_f6_snapshot_test` | 40 checks, 0 falhas | `2E091952F53115A75311BF2F4CFD595A18B2E8C64FA3076CBF6F844F4CC4EDC6` |
| 282 `e08_compact_checkpoint_test` | 48 checks, 0 falhas | `346B73697BFB3C1975A5B0B2196C99CC96AE95E389DFA441C3EDBDC5FFDCA1EC` |
| 283 `e08_compact_coverage_test` | 95 checks, 0 falhas | `3C65ADD205F98F2D063AFCF6DAD256C3F207D51AAE7376621D38801D89228796` |
| 290 `e07_f5_death_kits_test` | 191 checks, 0 falhas | `2DA02990DCFAE18C994ADDD224C583408B5995CE97C3F943C1E96D67D2E843AA` |
| 294 `e07_f3_snapshot_test` | 52 checks, 0 falhas | `9FC703C4AB2986DDAAB73ED386092F3B8AB71A5EA82C4A7C3C781D2F6F06C0CC` |
| 310 `e07_f1_guard_travel_test` | 293 checks, 0 falhas | `0DD468D2FE6986F208C9B58766E3916BAE42F315A3B6483D1C5C8AD0CF229EE4` |
| 1 `editor_import` | PASS (bootstrap) | `D6A10F188CE4A32A185CFEEB67D99F82FFED174CB5E205DF87425A92CB34F093` |
| 256 `e07_f1_import_test` | PASS (bootstrap), 3269 arquivos idênticos | `3892BA63B513E9779C00B41A69FFBFC22179DB6CFA99277EB01FDAE3D53537E6` |

Os hashes dos outros 161 passos estão no `summary.jsonl` da rodada final.

### Limitações T1.2

- A suíte inteira não foi repetida, conforme o pedido. Os passos fora dos 179 desta
  regressão não rodaram com estas mudanças.
- Chamadas planas diretas que não passam por `RunController`/`Main._execute_skill` e não deixam
  nota recebem a posição do jogador como `point`. Isso só afeta testes e ferramentas, porque o
  jogo sempre passa pelo `Main`.
- A prévia do HUD para um rank ainda indisponível continua mostrando o custo base da prévia, e não
  o custo efetivo do kit.
- `skill_cost` é avaliado com muita frequência (no HUD, em `_can_pay_skill` e no débito), por isso
  precisa ser pura: sem efeito colateral e sem estado consumido a cada chamada.
- O commit da Sentinela debita o valor travado na reserva. Se o kit mudar a regra entre a
  preparação e o lançamento, vale o preço da reserva.

### Ajuste A14 — fallback de corpo provado em pasta de fixture (junto da T1.2)

O pedido veio da arquitetura, depois de `476c246a`. A decisão A14 substitui, só para estes
checks, a regra anterior de não tocar em `kit_seam_test.gd`. Commit entregue: `be4d6477`.

**Motivo.** A T7 (`claude/zealous-roentgen-c183e9`) traz arte de produção para `paladin`,
`thaumaturge`, `duelist` e `arcane_blade`. Cinco checks de `kit_seam_test` contavam com a
ausência dessa arte. O fallback continua certo; o que mudou é que agora a arte existe.

**Arquivos alterados**

- `scripts/classes/class_kit_registry.gd`:
  - novo `install_fixture_body(evolution, pasta)`, só para testes;
  - `body_folder`, `body_folders` e `body_origin` passam a ler o override;
  - `clear_fixtures()` também desfaz os corpos de fixture.
  - Em produção o override é vazio, então o comportamento não muda.
  - A instalação é recusada para identidade fora dos kits, nome vazio ou pasta que já pertence
    a uma identidade.
- `tests/e09/kit_seam_test.gd`:
  - `_install_fixtures()` instala as pastas `e09_fixture_body_{sp_ac,mg_ac,sp_la}`, que nunca têm
    arte, e ganhou dois checks: instalação e recusas.
  - Os cinco checks agora provam o fallback nessas pastas:
    - "without kit art the origin body is used": `sp_ac` com a pasta de fixture;
    - "evolution -> actor_kind falls back": `sp_ac` e `mg_ac`, que substitui o `mg_la` de
      produção;
    - "body folders follow section 1": `kit_body_path` da pasta de fixture vazio. O check
      `body_folder(&"mg_la") == &"arcane_blade"` foi mantido;
    - "a kit body without art configures the origin body": `configure` da pasta de `mg_ac`, que
      dá `mage`;
    - "portrait identity uses the same fallback": `sp_la` com a pasta de fixture.
  - As listas de destinos (T9, A9) não foram tocadas.
- `t1_kit_seam_api.md`: seção 7 ("Corpo de fixture").

**Validação**

- Rodada `.godot/verification/a14_plain/`, com bootstrap refeito. O `summary.jsonl` tem sha256
  `67CD2FAC9D427F5ED127592893E25625E390AEBD7B4C7A7335E5909E1740C8AA`. São 10 passos, com 0 falhas e
  0 ocorrências na busca estrita.

| Passo | Resultado | sha256 da saída |
|---|---|---|
| 331 `kit_seam_test` | 189 checks, 0 falhas (+14 = 2 checks × 7 chamadas de `_install_fixtures`) | `89D1D0E32ACB9F19CA0DB0F4865983A85D6B2E21E5B2FF12B5EE6192933A6D69` |
| 330 `kit_seam_hooks_v3_test` | 63 checks, 0 falhas (hash idêntico) | `D1DFD323C350F8F63140F3D8D86FE01FB566BAEE11ED3A93B953FBF99F78F449` |
| 329 `kit_seam_hooks_v2_test` | 38 checks, 0 falhas (hash idêntico) | `5182F32B62DE14BE5938AF67C615BFBC0CBB6BDF062A64EDB08131758CF6FA5A` |
| 10 `combat_animation_test` | PASS, 39 | `DF1D52002E18C5524FA60801186A018CDBC71C91E0248051E38F6565C154FB1E` |
| 11 `e08_presentation_test` | 2255 checks, 0 falhas | `DF8A4BF3E4C4CFE9CF897EF65BE23D0CA416B02F33626DA96DC9A96216CCA12B` |
| 30 `battle_ui_test` | PASS, 47 | `F8318896CA4F69C73DFEE75D000BE93183454816283638EE4C14279A62749D21` |
| 283 `e08_compact_coverage_test` | 95 checks, 0 falhas | `3C65ADD205F98F2D063AFCF6DAD256C3F207D51AAE7376621D38801D89228796` |
| 294 `e07_f3_snapshot_test` | 52 checks, 0 falhas | `9FC703C4AB2986DDAAB73ED386092F3B8AB71A5EA82C4A7C3C781D2F6F06C0CC` |
| 1 `editor_import` | PASS (bootstrap) | `4CC45DA0030D44CC7E6C1314A09B11C92C08359A6DC22542E89B62ADC23C1245` |
| 256 `e07_f1_import_test` | PASS (bootstrap), 3269 arquivos idênticos | `75BE35C945699C39C9235605D69B5EE76D10D7BCB6CC40A1EB437E2F6C56642A` |

**Simulação da arte da T7**

A arte da T7 ainda não está versionada na branch dela. Para simular, criei temporariamente
`assets/art/e08_characters/directional/{paladin,thaumaturge,duelist,arcane_blade}/presentation.json`,
copiado de `swordsman`, e removi tudo em seguida. Nada foi commitado.

- A versão nova de `kit_seam_test` teve 189 checks e 0 falhas. O log tem sha256
  `EDB12442307B4D95E08665B8B97CDA80946A002BB20C489CC77B33C08E1A5DC1`.
- Como controle, rodei a versão anterior (`476c246a`) no mesmo cenário. Ela teve 3 falhas:
  "actor_kind falls back", "body folders follow section 1" e "portrait identity".

**Limitações A14**

- No controle, os outros dois checks antigos passaram porque o manifesto copiado declara
  `kind: swordsman` e cai no fallback por divergência de tipo. Com a arte real da T7, os cinco
  falhariam. A versão nova não consulta pastas de produção.
- A regressão de 179 passos da T1.2 rodou antes do A14. Depois dele só rodaram os 10 passos
  acima, escolhidos porque leem as pastas de corpo ou o snapshot.
