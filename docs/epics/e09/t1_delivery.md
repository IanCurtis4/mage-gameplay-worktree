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
