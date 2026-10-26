# Supervisão Luna — materiais, escala e profundidade visual F9

## Identificação e integridade

- Checkout `.tools/map-editor-m5`, branch `codex/map-editor-f9`.
- SHA congelado confirmado no início e fim: `ef88996651bc7783e51dc90cb63996de0b7399b1`; árvore limpa antes dos runners. Godot 4.7.2 standard, SHA256 `AB1824F85BFD8E0E4128182C000C4003A3E042245B2967848D089B2A04B22424`.
- Fixture única `.godot/verification/e07_f1/fixture_project`; todos os quatro manifests de importação e Core registram 1.897 inputs e zero divergências entre hashes da fonte e fixture. Sem nova fixture, bootstrap ou concorrência.
- A sequência nova (14:37:24–14:50 aprox.) executou Materials, MaterialsNative, Scale, ObjectsNative, Core e os dois checks oficiais. A fixture foi liberada depois de coletar evidências.

## Execuções neste SHA

| Etapa | Checks | Resultado |
|---|---:|---|
| Materials | 35 | PASS; 35/35 |
| MaterialsNative | 20 | PASS; 20/20 |
| Scale | 46 | PASS; 46/46 |
| ObjectsNative | 25 | PASS; 25/25 |
| Core | 639 | PASS; 639/639: candidate 53, document 70, terrain 102, composition 63, population 91, patrol 58, generation 89, exchange 113 |
| Verify oficial | 2 etapas | PASS; piloto 102 checks e apresentação 37 checks, 0 falhas |

Todos os runners registram exit 0, `ok:true`, sem timeout/aborto. Os logs destes diretórios não contêm `SCRIPT ERROR`, `Parse Error` ou `ERROR:`. Os runners nativos avisaram que `res://tools/map_editor_probe/hosting` contém outro `project.godot` e que a pasta será ignorada; os marcadores e resultados finais passaram.

A seleção oficial foi listada antes: `e07_f1_pilot_scene_test` e `e07_f1_presentation_test`, 2/299 etapas. Executada com `-F1Fixture -SkipEditorImport -CheckTimeoutSeconds 300`, import nativo ignorado e `APPDATA`/`LOCALAPPDATA` apontando para `.godot/discardable_profile` dentro da fixture; variáveis restauradas ao encerrar. `official/plan.json` identifica o SHA congelado, engine, seleção 2 e timeout 300. `checks.jsonl`: 2 registros, exit 0, sem falha ou timeout. Saída final: `Selected checks passed (2/299 steps); unselected steps were not run.`

## Proveniência e hashes

Os recibos autorais em `docs/map_editor/delivery/evidence/f9/author/` pertencem ao HEAD `215287a4f47b6c9af15444ddbca51b377dda9b1d`, não ao congelamento atual. Foram: `materials_final_01` 35 checks (runs SHA256 `E7F44BC348C17309AA204B65D7DBAFCD9EC637F25CBF32A4E8FAD24F8D3DA4F2`); `materials_native_03` 20 checks (runs SHA256 `42E2121689412BD93A7893E5B99CB6A1A89A4D926470C8882D58D60078EC237A`); `materials_scale_01` 46 checks, antes da correção final de depth (runs SHA256 `D4F362AE91A2CBF51F636B5E8FE0E09E6BFD1CB7496000AF1032491027CE85F3`). Não atribuo esses recibos históricos ao SHA `ef889...`.

Native01 estava quase edge-on. Native02 teve resultado autoral PASS, mas a captura ficou vazia por altura negativa e o critério de cor era fraco; não é usada como prova visual. Native03 corrigiu a ordem de desenho e fortaleceu a asserção para rejeitar fundo vazio; registro a inspeção visual de Sol como evidência autoral separada. A execução Native nova aqui é reprodução automatizada no SHA congelado.

Scale01 antecede a correção final de depth. A geometria e extensão, as 4.225 amostras, orçamentos e movimento permaneceram iguais. `terrain_scale` mudou o contrato de dependências (5 para 9) e os atributos de vértice (`COLOR` com quatro pesos e normal em `CUSTOM1`). O depth compartilhado novo manteve fundos em 0 e overlays em 4090, sem alterar alturas físicas. Esta distinção visual é explícita; Scale 46/46 foi reexecutado no SHA congelado.

Hashes das evidências novas:

- `authorities/runs.json`: `AB84F5DE5CB2022AF5916F4B7BD6CA38F6FD453C58384AFB0F1EEE91FBDA9727`; `authorities/import/manifest.json`: `8A81A1D82A80F65C9DCA87BE59643C737013030A034D8DFBF791C0574CDC8E70`.
-`native/runs.json`: `FEC09B464F83E94572610AA9F99A5A0699C150D8D953216E5839F00986A5B548`;`native/import/manifest.json`: `95CCBC9889532B58E27E3C8BB915AA7B70221C6BFA99828D595FA32122E6BA29`.
- `scale/runs.json`: `71A68E46D2B6AE17B594516F039ADE0720549AF1C217A3E9C59913B2AC67197C`; `scale/import/manifest.json`: `A0EC84B4958E2B2F9825DD706B71DFDEAD0B4D14EFBA517AC328FE72975B8F11`.
- `objects_native/runs.json`: `5F50A95B6588993A556F1FF981953817A7ACF7984B56E200D7A633A4D20ED0B0`; `objects_native/import/manifest.json`: `6786A4A2497B0B4CC44EC555CDC2235DB51DED1C7829D8C9A6FF6EA1109F24ED`.
- `core/runs.json`: `92B617477219F406ECFD67C9555CBA5D7F05BC0F399C8623C8591B0724D3FB56`; `core/manifest.json`: `D5DB654DEBCDB08CA8293FE33CA8136DA91E0BA7F7D348DAA4139E078C0C5BC3`.
- `official/plan.json`: `151493D15818D8CA5F91D3C22A82F350F22D58BCE1D064E07E809896B53D2D38`; `official/checks.jsonl`: `1238B9CAF36CABC7FC0B0724C24778B501D426D86A4075F9EB3F1ED22A87E3D0`.

## Limites

A suíte oficial executou apenas 2/299 etapas. As medições densas Scale medem compilação/amostras e traversal dos casos cobertos; não demonstram FPS, percepção em todas as resoluções nem qualidade de produto completa. Esta supervisão confirma execução, término, logs e hashes; não é auditoria semântica independente, não certifica F9 completo e não substitui aceite humano.
