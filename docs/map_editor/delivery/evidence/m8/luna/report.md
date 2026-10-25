# Supervisão Luna — Editor F8/M8

## Escopo e resultado

Supervisionei os testes automatizados do candidato `be84558fa1c6041d4dd2d4f7911b5f3bd62ba2f4` e, depois, o delta nativo e release do candidato atualizado `b26830de07fe1ba3889be686f2b8d7b4a0e15469`, na branch `codex/map-editor-m8`. Usei a fixture existente `.godot/verification/e07_f1/fixture_project` e a engine Godot 4.7.2 standard em `C:/Users/João Pedro/Documents/ChatGPT/RagRPG/.tools/godot/Godot_v4.7.2-stable_win64.exe`, SHA256 `AB1824F85BFD8E0E4128182C000C4003A3E042245B2967848D089B2A04B22424`.

O Stage All no SHA `be84558` passou nos marcadores e contagens fechadas do runner: candidato 52, documento 70, terreno 102, composição 63, população 91, patrulha 58, geração 89, intercâmbio 113, UI nativa 48 e processo release 6. As etapas de importação e exportação release também terminaram com exit 0. Todos os IDs de checks eram únicos e `ok=true`; sem abortos ou timeouts.

A seleção oficial executou cinco IDs de `verify.ps1` e passou em todos: população F5 (40), quest F5 (21), geometria F1 (33), composição F1 (299) e apresentação F1 (37), total de 430 checks. O delta final `b26830d` passou em 49 checks nativos e, em execução separada, exportou e passou em seis checks release. O runner e os manifests confirmam 1.845 inputs fonte/fixture iguais, sem divergências, nos dois SHAs.

## Tentativas com restrição de certificados

A primeira execução do Stage All, em `candidate/`, parou na importação dentro do sandbox: Godot registrou `ERROR: Failed to read the root certificate store` (`get_system_ca_certificates`). Exit code `-1`, aborto registrado; nenhum resultado dessa tentativa foi contado como aprovação. A repetição autorizada com `require_escalated`, preservada em `candidate_retry01/`, passou integralmente.

A primeira seleção oficial, em `official/`, concluiu a etapa população com exit 0 e texto “40 checks, 0 failures”, mas o runner marcou o check como falho porque o log também continha o erro do repositório de certificados. A execução foi interrompida ali; os quatro IDs restantes não foram executados. Não tratei esse exit 0 como PASS. A repetição escalada em `official_retry01/` concluiu os cinco IDs sem erro de certificado, erro de script, erro de parse ou timeout.

## Stage All — SHA be84558

Comando usado na repetição escalada:

```powershell
./tools/map_editor_candidate/run.ps1 -GodotPath 'C:\Users\João Pedro\Documents\ChatGPT\RagRPG\.tools\godot\Godot_v4.7.2-stable_win64.exe' -EvidenceDirectory 'docs/map_editor/delivery/evidence/m8/luna/candidate_retry01' -Stage All
```

Execução: `2026-10-25T15:14:19Z`–`2026-10-25T15:18:32Z`. O runner emitiu `M8_SELECTED_PASS`. O marcador `M8_RESULT` teve 52/52 IDs únicos aprovados; os marcadores M1–M7 tiveram as contagens 70/70, 102/102, 63/63, 91/91, 58/58, 89/89 e 113/113; `M8_UI_RESULT` teve 48/48; `M8_RELEASE_RESULT` teve 6/6. Importação e exportação release passaram sem timeout. A varredura dos logs de saída e engine da repetição não encontrou `SCRIPT ERROR`, `Parse Error`, `ERROR` nem timeout.

O manifesto confirma HEAD antes/depois `be84558fa1c6041d4dd2d4f7911b5f3bd62ba2f4`, 1.845/1.845 hashes de input coincidentes e engine com o SHA acima. As diferenças do `project.godot` da fixture são as declaradas pelo runner para VCS, driver nativo e export isolado. SHA256 do `manifest.json`: `E84D40E43AD82F13AEEEEDF13838BBA264E8CAADF221892A77CC17427D42747E`; `runs.json`: `DFD1142E6D7B70C946B31CCA365B1403F7168524E7C45337D94F1CC863B0E04C`.

O release de `be84558` criou `RagRPG-Map-Candidate.exe` SHA256 `4A9EADED8955EF789AB02651ED9D2DDE80328FBB342BD2A6DB4DB33E86305668` e `.pck` SHA256 `73B29BCF6E7A5F1FEDD42A1DE40626D246E0B2BCD25218799F3B309F79524D34`. O processo novo passou seis verificações: `new_release_process`, `immutable_package`, `seven_real_actors`, `patrol_bound`, `traverse_0.0` e `traverse_40.0`.

## `verify.ps1` — seleção por impacto

Primeiro executei `./tools/verify.ps1 -List`. Resultado: `Plan only: 299/299 steps selected; no checks executed.` A seleção seguinte reutilizou a fixture existente preparada e validada pelo runner M8; não repetiu bootstrap nem criou fixture.

```powershell
./tools/verify.ps1 -F1Fixture -Test 'e07_f1_geometry_test','e07_f1_composition_test','e07_f1_presentation_test','e07_f5_population_test','e07_f5_quest_test' -GodotPath 'C:\Users\João Pedro\Documents\ChatGPT\RagRPG\.tools\godot\Godot_v4.7.2-stable_win64.exe' -VerificationDirectory 'docs/map_editor/delivery/evidence/m8/luna/official_retry01'
```

Plano criado em `2026-10-25T15:19:41.6161439Z`; a última etapa gravou seus logs às `15:21:29Z`. O guard `-F1Fixture` passou e direcionou cada teste à fixture. `editor_import` ficou fora da seleção porque a mesma fixture já fora importada; o verify informou que recursos importados compatíveis eram necessários.

| Índice | ID | Resultado | SHA256 do output |
|---:|---|---:|---|
| 258 | `e07_f5_population_test` | 40/40 | `594087C5E4379BFE40E94245662EDE8E2711513B7B919E9F8CD4F2DE30D6B364` |
| 263 | `e07_f5_quest_test` | 21/21 | `D166D6629F14337BC98D539DA427EC5C217089ABDB8D4FDA6B5B42C71D1B7582` |
| 273 | `e07_f1_geometry_test` | 33/33 | `71628C66E650C01AEE64383E660745233CC8908C6C07CE436BD389457176DE81` |
| 295 | `e07_f1_composition_test` | 299/299 | `1C86C151BFED94B5F41279E95E87B08A1FF2A94968BC49EF6794D4ED93BBD4E9` |
| 297 | `e07_f1_presentation_test` | 37/37 | `BEBF132DC5433B71A8CF4626DF5B24C7E1A899B3C12AEFF5A2C81595456F7339` |

Os cinco checks tiveram exit 0, `failed=false` e `timed_out=false`; o verify informou `Selected checks passed (5/299 steps)`. Os outros 294 IDs não foram executados. SHA256 de `plan.json`: `4E1D92A73822554B76BEE71D7C620DF6AD74E883E560B24FA5F2D529E37569A8`; `checks.jsonl`: `7EA0782FC323C125E63749D946814FF9986435EE2883E98FAF3E0DF1ED3FE7D1`.

## Delta nativo e release — SHA b26830d

Após a alteração somente de apresentação indicada por Sol — IDs AX em inglês e restauração do seletor Manual/Receita quando a alteração é recusada — executei as etapas focais autorizadas. O delta também adicionou o check correspondente à recusa do seletor. As duas execuções abaixo foram feitas com `require_escalated`, conforme o erro de certificados registrado acima. Core e verify oficial não foram repetidos: os compiladores, dados e gameplay ficaram inalterados, conforme dispatch de retomada.

```powershell
./tools/map_editor_candidate/run.ps1 -GodotPath 'C:\Users\João Pedro\Documents\ChatGPT\RagRPG\.tools\godot\Godot_v4.7.2-stable_win64.exe' -EvidenceDirectory 'docs/map_editor/delivery/evidence/m8/luna/final_delta' -Stage Native
./tools/map_editor_candidate/run.ps1 -GodotPath 'C:\Users\João Pedro\Documents\ChatGPT\RagRPG\.tools\godot\Godot_v4.7.2-stable_win64.exe' -EvidenceDirectory 'docs/map_editor/delivery/evidence/m8/luna/final_release' -Stage Release
```

`Stage Native`: `2026-10-25T17:03:04Z`–`17:03:55Z`; import passou e `M8_UI_RESULT` passou com 49/49 IDs únicos, incluindo `rejected_recipe_restores_selector`. `Stage Release`: `2026-10-25T17:04:21Z`–`17:05:00Z`; import e export release passaram, e `M8_RELEASE_RESULT` passou 6/6. Ambos emitiram `M8_SELECTED_PASS`, confirmaram HEAD antes/depois `b26830de07fe1ba3889be686f2b8d7b4a0e15469`, 1.845 inputs fonte/fixture iguais e zero `SCRIPT ERROR`, `Parse Error`, `ERROR`, aborto ou timeout.

O release final usa o mesmo template de export (SHA256 `D34D36F3BE1A6C49C56525AE86469B92E4F417DDF0B43CF00DD80C385C4B0562`), preset SHA256 `D34E84FF0E055ECAC934AF2D494F3F6C949E501293DC03C4ECCF02FFA8BB84E2`, EXE SHA256 `4A9EADED8955EF789AB02651ED9D2DDE80328FBB342BD2A6DB4DB33E86305668` e PCK SHA256 `363DD3052A9DA89196FEFBECC37A695330FA02CD6E92D432AAB186B4E8637C9B`. Reconfirmei que os hashes do EXE/PCK em `.godot/m8_release` coincidem com o manifesto final. Inputs específicos do delta: `presentation.gd` SHA256 `C9C992048791C7CABB57B35D4C1FEB2F61A8EFDFDC29C05F9F520283A486E2E1`, `map_panel.gd` `AEFD0D03FC3C83C5726E8AF2AFE1C72409EDDB6A0AB6F63878C604803814DEA4`, UI test `8E1355F81D694247241E1AE71BDD7C0BB04FEB922249804633544A83EC8920F2` e runner `E11ED66BDA3037639AD12BA904EC447A249AC82902A9A0FDF77286E9EBF5B1AF`.

## Evidências e limites

- Stage All do SHA `be84558`: [runs](candidate_retry01/runs.json), [manifesto fonte/fixture](candidate_retry01/manifest.json), [manifesto release](candidate_retry01/release_manifest.json).
- Seleção oficial: [plano](official_retry01/plan.json), [checks](official_retry01/checks.jsonl). A tentativa restrita falha permanece separada em `official/`.
- Delta final: [runs nativos](final_delta/runs.json), [manifesto](final_delta/manifest.json), [runs release](final_release/runs.json), [manifesto](final_release/manifest.json), [hashes do release](final_release/release_manifest.json). A primeira importação restrita permanece em `candidate/`; sua repetição válida está em `candidate_retry01/`.

A suíte oficial completa não foi executada: 294/299 IDs ficaram fora da seleção por impacto. A seleção oficial ocorreu no SHA `be84558`; para `b26830d`, a validação adicional foi deliberadamente limitada a Native49 e Release6 porque o delta foi somente de apresentação. As capturas automatizadas e o processo release não substituem inspeção/aceite humano do produto. O build final e a fixture foram preservados para reconferência de Sol e limpeza final. Luna não editou código, testes, expectativas, dados ou runner e não fez commit.

## Adendo — sorteio de raros, SHA f90511be

Em `2026-10-25`, Sol corrigiu uma distinção de regra: `allow_rare` limita o sorteio aleatório; não deve bloquear um raro fixo manual. Um raro manual pode ter `site_id` vazio (sem site de ambientação), enquanto `origin_id` continua obrigatório e canônico para progressão/recompensa. As demais regras de elegibilidade, catálogo, suporte, corpo e reserva permaneceram ativas.

Esta rodada reaproveita evidência anterior por dependência. A base funcional `be84558fa1c6041d4dd2d4f7911b5f3bd62ba2f4` já passou no Stage All e na seleção oficial de cinco IDs. O delta de interface `b26830de07fe1ba3889be686f2b8d7b4a0e15469` já passou Native49 e Release6. Comparando os manifests do release `b26830d` e desta rodada `f90511be`, os 1.845 inputs estão presentes em ambos; somente três hashes mudaram: `scripts/map_authoring/context/population_context.gd`, `tests/map_editor_candidate_test.gd` e `tools/map_editor_candidate/run.ps1`. Os outros 1.842 hashes coincidem. Por isso, não repeti Native49, verify oficial ou o Core inteiro.

### Stage Context — M8/f90511be

Comando executado na raiz absoluta `C:\Users\João Pedro\Documents\ChatGPT\RagRPG\.tools\map-editor-m5`, via `require_escalated` por causa da falha de certificados já registrada. O destino relativo da chamada resolve para o caminho absoluto abaixo:

```powershell
./tools/map_editor_candidate/run.ps1 -GodotPath 'C:\Users\João Pedro\Documents\ChatGPT\RagRPG\.tools\godot\Godot_v4.7.2-stable_win64.exe' -EvidenceDirectory 'docs/map_editor/delivery/evidence/m8/luna/rare_policy' -Stage Context
```

Evidência: `C:\Users\João Pedro\Documents\ChatGPT\RagRPG\.tools\map-editor-m5\docs\map_editor\delivery\evidence\m8\luna\rare_policy`. Execução `2026-10-25T17:14:08.0365870Z`–`2026-10-25T17:16:40.8372729Z`. Import exit 0; `M8_RESULT` 53/53, população 91/91, patrulha 58/58 e intercâmbio 113/113. Total 315 checks; IDs únicos em cada grupo e todos `ok=true`. O novo oráculo `manual_rare_ignores_random_permission` passou junto dos checks `manual_rare_without_theme_allowed`, `rare_policy_enforced` e `reservation_*`. Runner emitiu `M8_SELECTED_PASS`; logs limpos de `SCRIPT ERROR`, `Parse Error`, `ERROR`, timeout e aborto.

O manifesto confirma HEAD antes/depois `f90511be6aa65262f5b1943a1f518385963a4001`, engine SHA256 `AB1824F85BFD8E0E4128182C000C4003A3E042245B2967848D089B2A04B22424`, 1.845/1.845 inputs iguais entre fonte e fixture. O teste M8 tem SHA256 `3CFCF3EC9EA83B1C1B95B273C441C1D325DDE3282D87153B3FA33732F1212A47`; `population_context.gd`, `25A09B84C096E849CCED5EE229CB4C93518CD50A4DE63180DCDEDF7A012282E0`; runner, `52F3DE7A725D84C49600EF3D3007940BD3E83D13109740DFB32A005D3C845ABA`.

### Stage Release — M8/f90511be

Também executado com `require_escalated`, na mesma fixture e SHA, sem repetir Core/verify:

```powershell
./tools/map_editor_candidate/run.ps1 -GodotPath 'C:\Users\João Pedro\Documents\ChatGPT\RagRPG\.tools\godot\Godot_v4.7.2-stable_win64.exe' -EvidenceDirectory 'docs/map_editor/delivery/evidence/m8/luna/rare_release' -Stage Release
```

Evidência: `C:\Users\João Pedro\Documents\ChatGPT\RagRPG\.tools\map-editor-m5\docs\map_editor\delivery\evidence\m8\luna\rare_release`. Execução `2026-10-25T17:17:05.4091480Z`–`2026-10-25T17:17:45.8548367Z`. Import e export release terminaram com exit 0; processo standalone passou 6/6 IDs únicos: `new_release_process`, `immutable_package`, `seven_real_actors`, `patrol_bound`, `traverse_0.0`, `traverse_40.0`. Runner emitiu `M8_SELECTED_PASS`; scan de logs limpo. O manifesto registra o mesmo HEAD, engine e 1.845 inputs sem divergência.

O build final usa EXE SHA256 `4A9EADED8955EF789AB02651ED9D2DDE80328FBB342BD2A6DB4DB33E86305668` e PCK SHA256 `2737F73348810509D14FD5E2B130A046D144F7E1D65C9D996A8447A07914F3AE`; ambos coincidem com `rare_release/release_manifest.json`. O template permaneceu SHA256 `D34D36F3BE1A6C49C56525AE86469B92E4F417DDF0B43CF00DD80C385C4B0562`.

Hashes das evidências desta rodada: `rare_policy/runs.json` `17AA62CA6D8F31E7F307A21AC873895B39B8B7028E898909743EB29AA1FE50D0`; `rare_policy/manifest.json` `ABD2C6C062DD4CA5821AA040EC6115754AB4EFDED434865879AD19C67CFEA0E1`; `rare_release/runs.json` `8AB9B0E0F6D04B5D994C24AAA2CFA7AB512BD8B8CABDF4076CE3285AB34DC4A3`; `rare_release/manifest.json` `2CD5B5EA17643D212ED93CEBFC3B378E0BFA7B546DD71FB1B642F9879B54C261`; `rare_release/release_manifest.json` `568BB445B9274B4491CA0B293330B0A7AF8435DBD356F977835442FC9484F56F`.

A fixture e o build permanecem preservados para a limpeza de Sol. Não houve alteração nem commit por Luna.