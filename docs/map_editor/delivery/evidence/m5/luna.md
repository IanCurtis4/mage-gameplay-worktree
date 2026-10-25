# Supervisão Luna — execução corrigida F5/M5

Data: 25/10/2026. Papel limitado à execução automatizada, conclusão, erros,
timeouts e hashes. Esta evidência não certifica semântica, revisão de contrato
ou aceite humano.

## Delimitação da execução

A tentativa anterior foi uma invocação incorreta do runner localizado dentro da
fixture. Ela falhou na importação (`ERROR: Plugin is not attached to debugger`),
não executou testes nem serve como evidência de aprovação. O checkout corrigido
foi congelado em `470904ea7f49ed5c8c0a60e182816c52f0ebde7a`; a tentativa válida
abaixo usou o runner da raiz do checkout. Não houve edição de runtime, testes,
runner, expectativas ou documentos de Sol durante esta supervisão.

Checkout: `C:/Users/João Pedro/Documents/ChatGPT/RagRPG/.tools/map-editor-m5`.
HEAD antes e depois: `470904ea7f49ed5c8c0a60e182816c52f0ebde7a`.
Fixture única: `.godot/m5_fixture`; fixture aninhada ausente antes da execução.
Engine: Godot `4.7.2.stable.official.ed1daf0bf`, SHA256
`AB1824F85BFD8E0E4128182C000C4003A3E042245B2967848D089B2A04B22424`.

## Runner F5/M5

Comando executado no CWD do checkout:

```powershell
& 'C:/Users/João Pedro/Documents/ChatGPT/RagRPG/.tools/map-editor-m5/tools/map_editor_patrol/run.ps1' -GodotPath 'C:/Users/João Pedro/Documents/ChatGPT/RagRPG/.tools/godot/Godot_v4.7.2-stable_win64.exe' -EvidenceDirectory 'C:/Users/João Pedro/Documents/ChatGPT/RagRPG/.tools/map-editor-m5/docs/map_editor/delivery/evidence/m5/luna_run/corrected' -Native
```

Runner SHA256: `D511025D6D66BAE48E5B3750D62FC48CC6A4304A047C9F628668FA69FEC05BA3`.
Execução registrada de 07:05:12Z a 07:09:39Z em `corrected/runs.json`.
Import, patrol (58 checks), restart prepare (33), restart resume (21), dois CLIs
e UI nativa (19) terminaram com `ok=true`, código 0 e sem timeout. Markers
observados: `import: True`, `patrol: True`, `restart_prepare: True`,
`restart_resume: True`, `cli_a: True`, `cli_b: True`, `native_ui: True` e
`M5_ALL_PASS`. O manifesto registra 1.788 inputs com SHA igual ao arquivo da
fixture em todas as entradas, a fixture usada, delta declarado de project.godot,
hash do projeto da fixture e `head_after` correspondente ao HEAD congelado.
Não foram encontrados `SCRIPT ERROR`, `ERROR:`, timeout ou falhas nos logs desta
execução. Logs, manifests e capturas estão em `luna_run/corrected/`.

## Seleção oficial aprovada

Executada em seguida na mesma fixture usando seu `tools/verify.ps1`, com
`APPDATA` e `LOCALAPPDATA` redirecionados para
`.godot/discardable_profile/AppData/{Roaming,Local}`. Foi usado
`-SkipEditorImport -CheckTimeoutSeconds 300`, sem `-F1Fixture`, com a seleção
exata aprovada: IDs 247, 251, 252, 258, 266, 268, 269 e 272. O plano registra
fonte `470904ea7f49ed5c8c0a60e182816c52f0ebde7a`, oito passos de 299 e a mesma
seleção. `checks.jsonl` registra todos com `exit_code=0`, `failed=false` e
`timed_out=false`; cada teste terminou com zero falhas:

| ID | Teste | Checks |
|---:|---|---:|
| 247 | e07_f4_durable_test | 28 |
| 251 | e07_f6_runtime_test | 33 |
| 252 | e07_f6_snapshot_test | 40 |
| 258 | e07_f5_population_test | 40 |
| 266 | e07_f5_waves_test | 37 |
| 268 | e07_f3_snapshot_test | 50 |
| 269 | e07_f3_continuation_test | 2743 (30 cenários) |
| 272 | e07_f3_mob_state_test | 372 (4 cenários) |

Resultado final do verify: `Selected checks passed (8/299 steps); unselected steps
were not run.` Os logs stdout/engine por teste, o plano e os hashes estão em
`luna_run/official/`; o conjunto cobre somente os oito passos aprovados.
Hash SHA256 do verify da fixture:
`D9F652BAB91C4BFAE98E254E8FB36148A17DE75E569DB9F0C3DC3814B69A4937`.

## Limites

Esta supervisão confirma término, contagens, ausência de erros/timeout nos logs
e correspondência de hashes. Não é auditoria semântica independente, não cobre
os 291 passos não selecionados, não certifica desempenho ou experiência de
produto e não representa aceite humano. A primeira invocação incorreta está
registrada apenas para distinguir sua falha de invocação; sua evidência não foi
misturada aos resultados aprovados desta execução corrigida.
