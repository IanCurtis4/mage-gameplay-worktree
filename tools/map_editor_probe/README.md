# M0 — prova isolada de hospedagem

Projeto mínimo de EditorPlugin, não implementação do editor de mapas. Execute
`run_hosting.ps1 -GodotPath <Godot4.7.2standard> -EvidenceDirectory <pasta-absoluta>`.
Exige PowerShell7/Windows. Runner lança dois processos de editor headless, um
editor gráfico com captura e uma contraprova runtime. Perfis ficam sob
`hosting/.godot/m0_profile`; nenhum projeto ou save do jogo é carregado.

Cada editor habilita/desabilita o plugin duas vezes, monta tela principal própria,
verifica foco, Resource @tool, histórico global do EditorUndoRedoManager e
commit/undo/redo, escondimento e liberação de controles/plugin/histórico.
Dois processos provam reinicialização; não há promessa de hot reload de scripts.
São30 checks por headless,31 gráfico e1 runtime; ausência de marcador, erro,
timeout ou contagem incompleta falha mesmo com exit0. Todos os logs são preservados.

Não mede brush/bake/terreno inexistentes, escala do jogo ou usabilidade final.
O tempo de habilitação inclui três frames e não representa latência pura da API.
Captura verifica somente a presença visual da tela de prova; o aceite de UX é humano.
O projeto não é incluído no jogo nem habilitado em project.godot da raiz.
