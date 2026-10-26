# Supervisão Luna — bordas de bioma F9

## Identificação e proveniência

- Checkout `.tools/map-editor-m5`, branch `codex/map-editor-f9`.
- SHA congelado confirmado durante toda a execução: `d3c0e25854a2623020b6fb3f83b5b9483e2ea810`. Godot 4.7.2 standard, SHA256 `AB1824F85BFD8E0E4128182C000C4003A3E042245B2967848D089B2A04B22424`.
- Fixture única `.godot/verification/e07_f1/fixture_project`. Os seis manifests de importação (Borders, BordersNative, Ports, Cliff, Relief, Core) registram 1.927 inputs cada e zero divergências entre SHA de fonte e fixture.
- Depois do despacho, foram alterados somente `docs/map_editor/contracts/f9_contact_shadows.md` e `docs/map_editor/contracts/f9_ownership.json`, para registrar o adendo humano/pesquisa e reservar propriedade. Esses documentos não são inputs dos runners; HEAD e arquivos de runtime/testes/tools permaneceram em `d3c0e258...`. A árvore Git não ficou totalmente limpa por esses dois documentos e pelas evidências; a comparação de hashes dos inputs executados é a prova usada aqui.

## Execuções novas

| Etapa | Resultado |
|---|---:|
| Borders | PASS, 93/93 |
| BordersNative | PASS, 32/32 |
| Ports | PASS, 92/92 |
| Cliff | PASS, 61/61 |
| Relief | PASS, 58/58 |
| Core | PASS, 639/639 |
| Verify oficial | PASS, 30/30 selecionados |

Cada completion runner imprimiu o marcador final `F9 <Stage>: True`, terminou com exit0, `ok:true`, sem timeout. Core executou seus oito estágios (candidate53, document70, terrain102, composition63, population91, patrol58, generation89, exchange113), mais import; todos os nove registros passaram. Verify repetiu exatamente os 30 nomes de `cliffs/official/plan.json`, confirmou antes `30/299` e executou com `-F1Fixture -SkipEditorImport -CheckTimeoutSeconds 300`. APPDATA/LOCALAPPDATA foram direcionados ao perfil descartável `.godot/discardable_profile` dentro da fixture e restaurados ao final. Os 30 registros oficiais tiveram exit0, zero falhas, zero timeout; saída final `Selected checks passed (30/299 steps); unselected steps were not run.` Nenhum log dos seis estágios ou Verify contém `SCRIPT ERROR`, `Parse Error` ou `ERROR:`. Avisos do importador sobre `tools/map_editor_probe/hosting/project.godot` ignorado não alteraram os PASS.

Os checks dirigidos cobriram perfis ricos, massa/caps, canal/água, transições, aberturas, junções e miters; BordersNative verificou renderização/capturas, transações GUI, AX e CLI. Não fiz inspeção visual humana independente das capturas.

## Recibos autorais anteriores

Os recibos de autor pertencem ao SHA `6d7dc73f56c313419ca16b073083c0ee65d8f8a2`, anterior ao congelamento; não os atribuo a `d3c0e258...`. `borders_ports_01` passou 93 (runs SHA256 `7423EA430A36FC62C79CC5B3BA3D9E1A1D95882CE76DB66E36CD811A3A4001B1`). `borders_native_01` falhou antes dos checks (runs SHA256 `4083FA1274CBD83700CD501F32C5F916F7B8BBE5814A5F85A0265A9A505D873A`); `borders_native_02` passou 32 (runs SHA256 `D317D4DA652ECF93A05929702444B7AD7906F480AE2EEA48C32655A331F13493`). As falhas autorais são preservadas como histórico; os PASS Luna abaixo são reprodução nova no SHA congelado.

## Hashes das evidências Luna

- `borders/runs.json`: `D0F94182B5503088161C601C0DF9F757DCBC399CED31655A1F20AC7CB951F87D`; `borders/import/manifest.json`: `C8F303B075F7642EFE678F98FCA8C93F371B163720926CC3BEF159488FE71C50`.
-`native/runs.json`: `599328B3202A76756B790265D342162AFA48684F5CD35AB592386915E024AE35`;`native/import/manifest.json`: `E40061E09ECA6AB28E9B86E09A81B36F1B66723C6C5D3187286551C3FB22AC39`.
- `ports/runs.json`: `A504A00A3C3E51EF3426A8260DD0CE0CAABA14C41BD4BA67D3C6DB06503BBDF1`; `ports/import/manifest.json`: `9786C051D28A5E77D82D4000A15CC633CA41FDBFD6E346B4B0BAB1DEF4E6E747`.
- `cliffs/runs.json`: `8DCBEC28E061B3C8747C37562750AF678EFF282A15AECBFB27A883EDD8C84C29`; `cliffs/import/manifest.json`: `E9C21070402CBC264509B9DBC29F889B6E45E2EF18CDDE82750F38A7B9B6E011`.
- `relief/runs.json`: `604247948B4D293F3980D885EF4D4CB1D312A13C2E20A306D8B47F11EE5B86C4`; `relief/import/manifest.json`: `8C4805260ABB8A8CEF853C9B3882D84DD5799BE9A903E66C3A4504147C7D4346`.
- `core/runs.json`: `F21E554BC4B57375E97CF675965A1319BCF33E5881627799723C7A9870A672E5`; `core/manifest.json`: `048A59042E1120D5E5DBE6979223C764C79229802816EAA6F03705005A712F9D`.
- `official/plan.json`: `1C38B8EC1CE05CDDBBC70126008980C098328B0B6087468850B246B70A809486`; `official/checks.jsonl`: `50B5F9997DF7EE91A6C9BBE8AF291194B15FB4B87A913B3A21818EDB355034CD`.

## Limites

A seleção oficial cobre 30/299 etapas. Os testes nativos registam capturas e verificações automatizadas, mas não substituem inspeção visual independente. A supervisão confirma marcadores, conclusão, erros, timeouts e hashes; não é auditoria semântica, medição de FPS nem aprovação completa de F9. Projeção/sombras, transporte/export integral, requisitos restantes de F9 e aceite humano continuam fora desta evidência. A fixture foi liberada depois da execução e coleta dos hashes.
