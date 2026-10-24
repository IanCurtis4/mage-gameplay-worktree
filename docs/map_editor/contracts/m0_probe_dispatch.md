# M0 — dispatch nominal da prova de hospedagem

24/10/2026. Autorizado neste chat após retirada do gate E07 e aprovação D1/D3.
Sol/médio implementa; Luna/baixo supervisiona conclusão/erros/hashes.
Base explícita `fba777b3822356a10e7f6e050971e54ab1a9819b`, sem trazer as correções
F8 ou declará-las integradas. Checkout isolado criado pelo app:
`C:/Users/João Pedro/.codex/worktrees/map-editor-m0/RagRPG`.
Branch de trabalho efetiva `codex/map-editor-m0`, criada antes de executar.

O projeto mínimo sob `tools/map_editor_probe/hosting/` não carrega gameplay,
autoloads, perfil, catálogo ou renderer do jogo. Testa EditorPlugin real,
tela principal própria, dependência Resource `@tool`, ação de altura no
EditorUndoRedoManager, undo/redo, foco e limpeza/reabilitação do plugin.
Dois processos headless e um gráfico com captura, além de contraprova em
runtime sem editor. Não equivale a testar um editor funcional de mapas.

Propriedade exclusiva Sol, paths relativos ao checkout isolado:

- `tools/map_editor_probe/hosting/project.godot`
- `tools/map_editor_probe/hosting/runtime_guard.gd` e `.uid`
- `tools/map_editor_probe/hosting/addons/m0_subject/plugin.cfg`
- `tools/map_editor_probe/hosting/addons/m0_subject/plugin.gd` e `.uid`
- `tools/map_editor_probe/hosting/addons/m0_subject/probe_document.gd` e `.uid`
- `tools/map_editor_probe/hosting/addons/m0_driver/plugin.cfg`
- `tools/map_editor_probe/hosting/addons/m0_driver/plugin.gd` e `.uid`
- `tools/map_editor_probe/run_hosting.ps1`
- `tools/map_editor_probe/README.md`
- `tools/map_editor_probe/.gitattributes` — preservar bytes dos inputs no Git.

Propriedade documental Sol no checkout habitual e cópia de entrega isolada:
`docs/map_editor/{README.md,execution.md}`, `contracts/{m0_preparation.md,
m0_probe_dispatch.md}` e `delivery/m0.md`. Atualização sequencial somente desses
arquivos pelo autor F0; sem escritores paralelos solicitados.
Complemento nominal após requisito humano de emendas: Sol também possui
`docs/map_editor/contracts/map_composition_and_seams.md`. Os documentos originais
`architecture.md` e `validation.md` são copiados sem edição como dependências do
planejamento, com hashes preservados; a branch precisa ser legível pelo F1 sem
depender de arquivos untracked do projeto habitual.
Sol possui ainda `docs/map_editor/delivery/evidence/m0_hosting/.gitattributes`
para preservar os hashes dos artefatos no Git. Luna escreve somente
`docs/map_editor/delivery/evidence/m0_hosting/luna.md` no
checkout habitual. Logs/resultados/captura/manifesto da prova pertencem a Sol em
`docs/map_editor/delivery/evidence/m0_hosting/`, excluído o relatório Luna.

Engine: executável standard local do checkout habitual, somente leitura; obter
versão/hash antes de execução. Não usar wrapper console incompatível. Runner
temporário mantém APPDATA/LOCALAPPDATA em fixture e restaura ambiente no final.
Timeout por processo; erros, ausência de marcador ou conclusão incompleta falham.
Contraprova runtime deve confirmar ausência de plugin e autoloads.

Sem alteração em `project.godot` raiz, `tools/verify.ps1`, runtime, cenas ou dados
de jogo. `verify.ps1 -List` inventaria o runner atual; a prova independente é
executada pelo runner próprio, sem inventar ID de teste de gameplay. Não repetir
suíte E07 ou simular requisito de F8 integrada. Falha é corrigida nesta tarefa,
preservando logs anteriores. Nenhum merge/master/push/playtest nesta prova.
