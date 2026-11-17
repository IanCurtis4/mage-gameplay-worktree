# T11 — supervisão Luna do candidato E09 `3843d324` (17/11/2026)

**Candidato:** `3843d32439b17442dfa9261aafd24ac84769b16b`, branch `claude/e09-candidato`.
**Ponta de docs usada na leitura:** `beeb8cc5`. O `git diff 3843d324..beeb8cc5` toca só 3 arquivos em `docs/`.
**Escopo desta supervisão:** conclusão da rodada, falhas, timeouts, logs, hashes e sondas, a partir da evidência já gravada. Não é auditoria semântica.
**Não feito:** a suíte não foi rodada de novo, o Godot não foi aberto e nenhum arquivo do candidato foi alterado. Os únicos comandos no candidato foram leituras (`git log`, `git status`, `git diff --name-only`).

**Evidência lida**
- Rodada: `.godot/verification/t10_full_3843d324/` na worktree `e09-candidato` (fora do Git).
- Pacote: `.tools/playtest_e09/e09_3843d324/` na raiz do projeto.

## Veredito

**Aprovação técnica**, com as ressalvas de rastreabilidade da seção 4. Nenhuma delas é falha de teste, e nenhuma delas muda o código testado.

- Os 347 passos têm saída, registro e `source_commit` corretos. O único passo que falha é o 255, o erro conhecido, com a mesma saída da rodada anterior.
- Os 347 hashes de saída foram recalculados e batem com o `summary.jsonl`.
- Os hashes do `.exe`, do `.pck`, do `build_manifest.json`, do `profiles/index.json` e do `summary.jsonl` batem com o recibo da T10.
- As sondas no PCK exato passam (20/20 e 0 falhas de pacote).
- Os 8 perfis são válidos e não há escrita no save pessoal.

Isto não é aprovação de produto. O aceite de produto continua com o usuário, pelo roteiro de playtest.

## 1. Tabela de conferência

| # | Item | Esperado | Encontrado | Situação |
|---|---|---|---|---|
| 1a | Passos no `summary.jsonl` | 347 | 347 linhas, índices 1–347 sem repetição, sem nome duplicado | OK |
| 1b | Passos concluídos | todos | 347 com `output_sha256`; 0 com `note`; 0 `timed_out`; 347 pastas `step_NNN` | OK |
| 1c | `source_commit` em cada `plan.json` | `3843d324` | 347 de 347 com `3843d32439b17442dfa9261aafd24ac84769b16b` | OK |
| 1d | Árvore rastreada limpa | sem alterações | Passo 001 (`editor_import`) com 0 alterações. Passos 002–347 registram **617 entradas ` M` em `.import`**, todas `.import` | **Divergência**, ver seção 4 |
| 1e | Arquivos não rastreados nos `plan.json` | (não especificado) | 1391 entradas distintas, produtos da importação (`.import` de PNG, `.uid`, sondas de `docs/map_editor/`) | Registrado, esperado |
| 2 | Falhas | só o passo 255 | só o passo 255 `e07_f1_native_import` (`failed=true`); `driver_exit=1` nele e em nenhum outro | OK |
| 2b | Saída do passo 255 | SHA256 `AB79025F…831F` | `AB79025F6B8201D30245FD016889D79306A398E5D3D1C02D5CAF801D5E17831F`; log termina em `Godot verification failed (exit 0)` | OK |
| 3 | Timeouts | 0 | 0 | OK |
| 4 | `SCRIPT ERROR`, `Parse Error`, `ERROR:` em todos os logs | só o `GitPlugin` e o passo 255 | 6 ocorrências em 3 arquivos, todas no passo 255 (`255.engine.log`, `255.output.log`, `step_255.driver.log`): `Cannot get class 'GitPlugin'` e `nullptr VCS extension`, mais o `throw` do `verify.ps1:106` | OK |
| 4b | Demais logs | nenhuma | nenhuma ocorrência fora do passo 255 | OK |
| 5 | Hashes do `summary.jsonl` | `D7231C67…EE40` | `D7231C6778682CDEBDDFB88F18A9A04E3E93787C7849D41ECB4415DB178EEE40` | OK |
| 5b | Console do driver | `2C95221B…C6F2` | Não localizado. O `t10_run_full_suite.ps1` grava um `step_NNN.driver.log` por passo, e o `Write-Host` do resumo não é salvo. Nenhum arquivo da rodada tem esse hash (busca em todos os arquivos pequenos da pasta) | **Não verificável**, ver seção 4 |
| 5c | Saídas dos passos 26, 48, 108, 250, 333, 334, 347 | os 7 hashes do recibo | todos batem, ver seção 2 | OK |
| 5d | Recalculo de todas as 347 saídas contra o `summary.jsonl` | igual | 0 divergências | OK |
| 5e | `.exe` | `4A9EADED…5668` | `4A9EADED8955EF789AB02651ED9D2DDE80328FBB342BD2A6DB4DB33E86305668` | OK |
| 5f | `.pck` | `5AFE0CDC…A468` | `5AFE0CDC1D88F82F23871E544AB855B45C0BA2A59B4566785A6AC94831F1A468` | OK |
| 5g | `build_manifest.json` | `7BA5918B…732D` | `7BA5918B856ACFE0057186B6783A0BF36008A0019F56DB24CE2A3581432E732D` | OK |
| 5h | `profiles/index.json` | `21E44A75…3F41` | `21E44A756F98A8A273A9C03E2A5B1F7754E51E0285B512684E7F9D643A3E5F41` | OK |
| 6a | Sonda `inspect_pack_e09` | 20/20 | `count=20`, `ok=true`, 20 de 20 checks `ok=true`, `pack_entries=3760` | OK |
| 6b | `PACK_PROBE failures=0` | 0 | `PACK_PROBE failures=0` em `export_content` | OK |
| 6c | Equipamentos no pacote | 89 | `PACK_DEFINITIONS equipment 89` e `PACK_CATALOG_COUNT equipment 89` | OK |
| 6d | Sonda E08 (`inspect_pack_e08`) | sem regressão | `count=22`, `ok=true`, `missing=0` | OK |
| 6e | Perfis de revisão | 8 válidos, job 40 | `review_profiles.output.log`: `ok=true`, `invalid=[]`, `pending=[]`. `profiles/index.json` com 8 entradas. Cada perfil com `job_xp_total=17940` e 1 personagem, o que bate com o recibo da Sol. O número do job 40 não foi conferido diretamente no JSON | OK, com a ressalva do job |
| 6f | Perfis gravados no save pessoal | nenhum | `%APPDATA%\Godot\app_userdata\RagRPG\profile.json` e `profile.backup.json` com data de 16/10/2026, sem alteração na rodada. Não existe `RagRPG E09 Candidato` em `%APPDATA%`. Os 8 perfis estão só em `profiles/<chave>/appdata/…/RagRPG E09 Candidato/` | OK |

## 2. Hashes recalculados (`Get-FileHash -Algorithm SHA256`)

| Arquivo | Recalculado | Recibo T10 | |
|---|---|---|---|
| `summary.jsonl` | `D7231C6778682CDEBDDFB88F18A9A04E3E93787C7849D41ECB4415DB178EEE40` | `D7231C67…EE40` | OK |
| console do driver | não localizado | `2C95221B…C6F2` | não verificável |
| passo 026 `e08_feedback_recipe_test` | `B7782234F652C64DC20D4A9423EE714CFB090F2F161F63DFA4103CAE7493BBE9` | `B7782234…BBE9` | OK |
| passo 048 `e03_progression_transactions_test` | `3A00F5DA9D88D204D0A5BFABF4E711B0B07C69DC0A0986996B98211B971596DD` | `3A00F5DA…96DD` | OK |
| passo 108 `e05_evolution_catalog_test` | `6B7F3B5BBE61238BDDBAAA633CB0AF8DD4276D4F1E4B833DEBADC01062C87AB2` | `6B7F3B5B…7AB2` | OK |
| passo 250 `e06_export_content_test` | `4D20192C1E36ECFB836BC7099DAB6B5A37EB8CE56935817945ADEB86CD37081A` | `4D20192C…081A` | OK |
| passo 333 `kit_seam_test` | `ED82D9547EA5243594E331DF14F39B528F06410FAB0AD22D24576AF6EAE83E49` | `ED82D954…3E49` | OK |
| passo 334 `ui_evolution_test` | `DF7B1619F114033B0C05563E933F5A06170AC0D0EEF1A886AA5C45F28C7369EF` | `DF7B1619…69EF` | OK |
| passo 347 `art_pipeline_tests` | `C79F471DACD94E7FD7F02F4D8BF87967AAE61B376F0B210A902EC2CEFF8F0FB5` | `C79F471D…0FB5` | OK |
| passo 255 `e07_f1_native_import` | `AB79025F6B8201D30245FD016889D79306A398E5D3D1C02D5CAF801D5E17831F` | `AB79025F…831F` | OK (falha conhecida) |
| `RagRPG-E09-Candidato.exe` | `4A9EADED8955EF789AB02651ED9D2DDE80328FBB342BD2A6DB4DB33E86305668` | `4A9EADED…5668` | OK |
| `RagRPG-E09-Candidato.pck` | `5AFE0CDC1D88F82F23871E544AB855B45C0BA2A59B4566785A6AC94831F1A468` | `5AFE0CDC…A468` | OK |
| `build_manifest.json` | `7BA5918B856ACFE0057186B6783A0BF36008A0019F56DB24CE2A3581432E732D` | `7BA5918B…732D` | OK |
| `profiles/index.json` | `21E44A756F98A8A273A9C03E2A5B1F7754E51E0285B512684E7F9D643A3E5F41` | `21E44A75…3F41` | OK |

Os 8 `profile_sha256` do `profiles/index.json` batem com os prefixos e sufixos do recibo (`f19bb68d…cb71`, `58651525…9b4f`, `138f5e47…bc5d`, `50d55169…de94`, `bfdbe502…2ccd`, `0fda77d4…9872`, `ca91e9e2…928d`, `7ca1ca8a…0e6c`). Os hashes dos arquivos `profile.json` em si não foram recalculados.

## 3. Estado do candidato agora

- `claude/e09-candidato` está em `beeb8cc5`, com 0 alterações rastreadas.
- Entre `3843d324` e `beeb8cc5` há só 3 arquivos em `docs/`.

## 4. Ressalvas (não são falhas de teste)

1. **Árvore suja a partir do passo 002 (item 1d).** O passo 001 é o `editor_import`, que faz parte da suíte. Ao rodar, reescreveu 617 `.import` (`core.autocrlf`). Os passos 002–347 registram essas 617 entradas. O recibo da T10 (limitação 3) afirma que a diferença é só de fim de linha, e que a T10 reverteu tudo antes do commit e da exportação. Eu **não consegui confirmar** que é só fim de linha: as diferenças não foram guardadas e o candidato já está limpo. Que o `.import` mude no próprio passo 001 é o comportamento esperado do contrato, então não é divergência de procedimento.
2. **Console do driver não localizado (item 5b).** O hash `2C95221B…C6F2` não corresponde a nenhum arquivo da rodada. A T10 precisa dizer onde o console foi salvo, ou registrar que ele não foi guardado. Não afeta a evidência por passo, que foi toda conferida.
3. **Executável diferente do contrato.** O §9 do contrato cita `Godot_v4.7.2-stable_win64_console.exe`. A rodada usou `.tools/godot/Godot_v4.7.2-stable_win64.exe` (o recibo da T10 declara isso). É a mesma versão 4.7.2, e os logs são coerentes. A Sol deve registrar o desvio no contrato ou no recibo.
4. **Save pessoal com escrita do engine.** Durante a rodada, a pasta `%APPDATA%\Godot\app_userdata\RagRPG` recebeu logs do engine e as pastas de fixture `e08_audio_fixture` e `e08_audio_mix_fixture` (13:19 local). Não houve escrita em `profile.json`.
5. **Job 40.** Os 8 perfis têm `job_xp_total=17940`, mas o mapeamento para o job 40 não foi conferido no JSON.
6. **Nome sem prefixo.** O perfil `Corrente de Execuções` não tem o prefixo `E09 `, como já registrado pela Sol.

## 5. Evidência não versionada

- Rodada: `.godot/verification/t10_full_3843d324/` na worktree `e09-candidato` (`summary.jsonl`, 347 pastas de passo, `probe_cleanup.txt`, `probe_headless_stale_20261117161416`).
- Pacote: `.tools/playtest_e09/e09_3843d324/` (`.exe`, `.pck`, `build_manifest.json`, `validation/`, `profiles/`, atalhos, `measure_crowd01/`, `review_profiles_raw/`).
