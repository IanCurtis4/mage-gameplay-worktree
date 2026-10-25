# Luna — supervisão automatizada M4

Execução independente da seleção congelada no checkout `codex/map-editor-m4`, HEAD `de38ac857de9ec0eb8bc9048fdfd193a3c76013f`. O runner foi executado do checkout congelado, com fixture e artefatos sob o diretório exclusivo de evidência. A fixture foi nova (`final/fixture`). Nenhuma expectativa ou fonte foi alterada. O runner confirmou HEAD igual antes/depois, hashes fonte/fixture iguais e ausência de abortos por erro.

Comando executado:

```powershell
& 'C:\Users\João Pedro\Documents\ChatGPT\RagRPG\.tools\map-editor-m4\tools\map_editor_population\run.ps1' -GodotPath 'C:\Users\João Pedro\Documents\ChatGPT\RagRPG\.tools\godot\Godot_v4.7.2-stable_win64.exe' -EvidenceDirectory 'C:\Users\João Pedro\Documents\ChatGPT\RagRPG\.tools\map-editor-m4\docs\map_editor\delivery\evidence\m4\luna_run\final' -Native
```

Engine: Godot 4.7.2.stable.official.ed1daf0bf; executável SHA256 `AB1824F85BFD8E0E4128182C000C4003A3E042245B2967848D089B2A04B22424`. Runner SHA256 `E596052D0F5F0727014FB0129431867535353F7FECAFBD9F61BCBE36862DF005`.

Todas as seis etapas passaram sem timeout/abort: `import` exit 0; `population` M4_RESULT 90/90; `cli_a` e `cli_b` com output_hash `78ba21208521b4abfb47788d06c91b6fa31d56f1b65a4b2e15f9aa153f2b343f`, igual ao package_hash; `document_regression` M1_RESULT 70/70; `native_ui` M4_UI_RESULT 29/29. `terrain.png` foi capturada (325227 bytes). Não houve `SCRIPT ERROR`, `Parse Error` ou `ERROR` nos logs de saída/engine; houve apenas warning de descoberta de outro `project.godot` sob `tools/map_editor_probe/hosting`, ignorado pelo Godot.

| Artefato | SHA256 |
|---|---|
| `runs.json` | `BDDFBE3C8F67D3FB549611297386B054C9232EDD65BE891BC95F1332DDFCDC66` |
| `manifest.json` | `5A1B7EF57EB22DAFAA92B438733A8735C37707311FEA4771D5D5E475022AE499` |
| `terrain.png` | `C6D795E9078F98CD1E41F65BD5C10A45FF6C6D2AC578A71BD58CC8DA24B5EE4F` |
| `import.engine.log` | `DD9533EEBD360B9C4B332CC133622B9E5B4734CD3FBF229D17D0080912BA64A8` |
| `population.engine.log` | `1B5991BB8792EB5DEAFB94063F118918E15590A4ABA3A68DB40C5FB2AC026215` |
| `cli_a.output.log` | `4C7E272FC4981032179017BE0F4BEA0D8CFB93C40CD40D05ED75ED3F744255CA` |
| `cli_b.output.log` | `4C7E272FC4981032179017BE0F4BEA0D8CFB93C40CD40D05ED75ED3F744255CA` |
| `document_regression.engine.log` | `B70F33FFD576B2CC417EBC37D3C574078A44AEF5DE301F6F2478382BB233389B` |
| `native_ui.engine.log` | `5AB17962A5666A2DDD41DF4A53D771CCA38F49A07872C3AAB85D83F67B07710C` |

Esta é supervisão automatizada de execução, marcadores, conclusão, erros, timeouts e hashes. Não é auditoria semântica independente, não substitui a validação técnica de Sol nem o aceite de produto/playtest humano.


## Rodada de correção — saídas terminais required (SHA `7a391431fad54e396194ec0c3ce8e6491fbe178e`)

Nova supervisão Luna, em fixture independente `luna_run/terminal_exit_fix/fixture`, usando o runner do checkout congelado e a mesma engine (Godot 4.7.2; SHA256 `AB1824F85BFD8E0E4128182C000C4003A3E042245B2967848D089B2A04B22424`). HEAD antes/depois: `7a391431fad54e396194ec0c3ce8e6491fbe178e`. Import passou; população M4 91/91; `cli_a` e `cli_b` passaram e ambos produziram `78ba21208521b4abfb47788d06c91b6fa31d56f1b65a4b2e15f9aa153f2b343f`, igual ao `package_hash`; regressão M1 70/70; UI nativa 29/29; captura `terrain.png` presente (325227 bytes). Sem timeout/aborto ou `SCRIPT ERROR`, `Parse Error` ou `ERROR` nos logs. O único warning foi o scan do projeto aninhado ignorado, também registrado na rodada anterior.

| Artefato novo | SHA256 |
|---|---|
| `terminal_exit_fix/runs.json` | `E60698939A8695527DDD2DB5409BCF1795FB9C83C69672F0D59BAADB6925E7A3` |
| `terminal_exit_fix/manifest.json` | `D609A153BF32B3002FE55E78376A3F4C25B5DA1222E8C9C70C2FDED0FAA0575A` |
| `terminal_exit_fix/terrain.png` | `C6D795E9078F98CD1E41F65BD5C10A45FF6C6D2AC578A71BD58CC8DA24B5EE4F` |
| `terminal_exit_fix/population.engine.log` | `701BF89E4C0116A699AB158CF0733BC5851823C3ACC233B9DE55213858239C2C` |
| `terminal_exit_fix/population.output.log` | `81C8E085C9C49CF71A4D14FF9FF823CBA987C8D9B33B853B07D60B4AEC59D2B4` |
| `terminal_exit_fix/native_ui.engine.log` | `5AB17962A5666A2DDD41DF4A53D771CCA38F49A07872C3AAB85D83F67B07710C` |
| `terminal_exit_fix/native_ui.output.log` | `EB2CA7828696D021944A2265BDBC13AF8B029881DBDDC72E678110A9E6760CAA` |

### Conferência posterior dos registros oficiais executados por Sol

Esta é uma leitura dos artefatos oficiais já produzidos por Sol; Luna não executou novamente esses testes, e eles não são uma execução oficial no SHA `7a39143`. As duas `plan.json` registram a mesma engine SHA acima. `inputs.json` registra 1611 entradas de fonte/fixture com hashes iguais. `compatibility.json` compara base/teste `de38ac857de9ec0eb8bc9048fdfd193a3c76013f` com o checkout atual `7a391431fad54e396194ec0c3ce8e6491fbe178e`: 1609 entradas inalteradas e exatamente duas diferenças, `population_compiler.gd` e `map_editor_population_test.gd`. Os metadados registram que E07/runtime, geometria, dados, seleção e runner oficial ficaram intactos; a validação semântica do delta cabe a Sol.

A seleção oficial tem sete nomes únicos: import e seis testes E07. `run/checks.jsonl` registra import (exit 0), população (40 checks), campanha (28) e a primeira tentativa de conclusão (timeout em 120 s, exit -1). Essa falha de timeout foi preservada. `tail_300/checks.jsonl` registra a retomada de conclusão (39 checks), quest (21), recompensas (6) e ondas (37), todas exit 0. As seis execuções de teste somam 171 checks e zero falhas. Os logs correspondentes não contêm `SCRIPT ERROR`, `Parse Error` nem `ERROR`; a tentativa de conclusão em 120 s continua marcada como timeout, não aprovada.

Hashes dos registros oficiais conferidos:

| Registro | SHA256 |
|---|---|
| `official/run/checks.jsonl` | `B1043295392339CD58D7294A192206939233AFE0880139B9CB6EEB68A78C7E6A` |
| `official/tail_300/checks.jsonl` | `081AC82AE154D1D689831BBB32AF29ED357C569105B33705FE0CBB4635F437CD` |
| `official/inputs.json` | `901745E885E451EA782FCE0037D1A1F47C852BB164B8F43655FE0075342290C8` |
| `official/compatibility.json` | `F2015E762E3F670AE64CACFBCE61276F2C41C7794B73DDB3799E43EE8529F85F` |
| `official/run/plan.json` | `6B23E5B0BD8CFA0CB6356628199A0E071568DDC6E14DF38A8E4AAFCA8D348548` |
| `official/tail_300/plan.json` | `57D4DC843B82198232E74C6BCCE040FB55769AEF577F8F1A6D34A7478ADC1B90` |

A evidência Luna continua limitada à supervisão de execução e integridade dos registros; a compatibilidade semântica do delta é decisão técnica de Sol.
