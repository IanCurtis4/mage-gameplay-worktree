# Supervisão Luna — objetos F9

## Base e integridade

- Checkout: `.tools/map-editor-m5`, branch `codex/map-editor-f9`.
- HEAD antes e depois: `18fa57fc1cb21c47e88e6cf2d54d41ae2fd87e37`.
- Godot 4.7.2 standard, engine SHA256 `AB1824F85BFD8E0E4128182C000C4003A3E042245B2967848D089B2A04B22424`.
- Fixture única `.godot/verification/e07_f1/fixture_project`, reutilizada sequencialmente.

## Evidência autoral Sol conferida

`docs/map_editor/delivery/evidence/f9/author/objects_regression_02/manifest.json` registra `head_before/head_after=ce7bd5906accf71fffb60cc17c8c2f7ebffc2dd8`, enquanto o SHA congelado desta supervisão era `18fa57fc1cb21c47e88e6cf2d54d41ae2fd87e37`. Portanto, a execução Core autoral não é atribuída ao SHA congelado nem ao commit posterior: serve como evidência de conteúdo conferida por inputs, sujeita à distinção histórica do manifesto. O manifesto registra engine SHA correspondente e import, candidate 53, document 70, terrain 102, composition 63, population 91, patrol 58, generation 89 e exchange 113, todos `ok`, sem timeout/aborto (639 checks nos oito estágios). Comparei os 1.862 hashes de inputs com o checkout: só diverge `tools/map_editor_completion/run.ps1`, esperado `C65686E874A24335052CF174B05E21C7253BC7C3C4D7B77AF9D52DB00BE31BC3`, atual `7A22CACDFC369650C1F63BBCC89AFB0C75337E93F1FD407C4ADF6AB1DAAF7C77`. Conforme despacho, é alteração posterior declarada, limitada às contagens esperadas 53/25. Os oito UIDs declarados como cópias da fixture também estão no estado posterior; os demais inputs coincidem. Não atribuo a execução autoral a conteúdo de runner posterior.

## Supervisão Luna

1. `tools/map_editor_completion/run.ps1 -GodotPath <engine> -EvidenceDirectory <...>/luna/objects/authorities -Stage Objects`: importação passou; 53/53 checks passaram. `runs.json`: exit 0, sem timeout/aborto, `ok: true`, HEAD antes/depois igual ao congelado.
2. `tools/map_editor_completion/run.ps1 -GodotPath <engine> -EvidenceDirectory <...>/luna/objects/native -Stage ObjectsNative`: importação passou; 25/25 checks nativos passaram. Runner gerou `objects.png` e `objects_map.png`. `runs.json`: exit 0, sem timeout/aborto, `ok: true`, HEAD antes/depois igual.
3. A listagem confirmou índices 239 import, 274 atores e 297 apresentação. A tentativa inicial de executar os três juntos com `-F1Fixture` foi rejeitada pelo próprio runner antes de checks: bootstrap import não pode usar essa fixture. Sem modificar arquivos, dividi a seleção conforme a regra do runner: `e07_f1_import_test` com `-SkipEditorImport` e sem `-F1Fixture`, depois atores/apresentação com `-F1Fixture -SkipEditorImport`. O bootstrap passou: 1887 arquivos byte-identical, delta único VCS autoload true → false, `source_manifest_sha256=996338ab8a06fc27bc5b9d5029245c26fc5f8ce5bce284a7fad2abef75132246`. Atores: 193 checks, 0 falhas. Apresentação: 37 checks, 0 falhas. Dois passos oficiais compatíveis selecionados passaram (2/299), e o bootstrap passou separadamente (1/299).

## Logs e limitações

Evidence directories: `authorities/`, `native/` e `official/` (bootstrap em `official/bootstrap/`). `official/checks.jsonl` SHA256 `CD3C399D3A5CD71E2E0A57BDDA84787C17447B872EA3CAA86BBE9214C7DB5A51`; `official/plan.json` SHA256 `751DB9BCAC5E405B59350BA6625E5691C84916D1E3A191A3A3962051F7F940AC`; bootstrap `checks.jsonl` SHA256 `B16E181B5F282EE8880998AE89B62A10FC13C35096DC0AAE9DEE2A6C418E6136`. Logs individuais e manifests permanecem nos diretórios. Não foram encontrados `SCRIPT ERROR`, `Parse Error` nem `ERROR:` nos logs. O editor registrou somente o aviso conhecido de pasta com outro `project.godot` ignorada em `tools/map_editor_probe/hosting`.

Escopo: autoridades de objetos, UI nativa, importação isolada, integração de atores e apresentação selecionada. Não foi executado export, nem certificada toda a suíte F9 ou as outras 296 etapas oficiais. A supervisão confirma execução e integridade, sem auditoria semântica independente. Fixture liberada após as execuções.
