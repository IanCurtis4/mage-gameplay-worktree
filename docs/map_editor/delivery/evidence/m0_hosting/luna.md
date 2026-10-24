# Supervisão Luna — prova de hospedagem M0

Data: 24/10/2026  
Escopo: conferência de execução, conclusão, erros e hashes dos artefatos de `attempt_02`. Nenhum processo Godot ou teste foi executado por esta supervisão.

## Conclusão

`attempt_02` concluiu com sucesso os quatro processos: `headless_01` (30 checks), `headless_02` (30), `native_01` (31) e `runtime_guard` (1), totalizando 92 checks aprovados e nenhum check reprovado. Todos retornaram código 0, sem timeout, com exatamente um marcador `M0_RESULT`; as conclusões registradas indicam `ok: true`. Não encontrei `SCRIPT ERROR`, `Parse Error` ou `ERROR:` nos logs dessa tentativa.

Os dois editores headless e o editor Windows registraram Godot `4.7.2-stable (official)`. A contraprova confirmou `editor_plugins_absent_in_runtime`. A captura `hosting.png` existe (84.888 bytes) e o check `native_capture_saved` passou. Isso comprova a prova de hospedagem do `EditorPlugin` no projeto mínimo descrito pelo contrato; não comprova um editor funcional de mapas nem execução integrada ao jogo.

## Integridade dos artefatos

- Os quatro `output_sha256` de `runs.json` conferem com os respectivos `*.output.log`.
- O SHA-256 do executável indicado no manifesto confere: `AB1824F85BFD8E0E4128182C000C4003A3E042245B2967848D089B2A04B22424`.
- Todos os 13 hashes de fontes listados em `manifest.json` conferem com os arquivos da prova no worktree isolado.
- `manifest.json` contém os mesmos quatro resultados aprovados de `runs.json`.

Evidências detalhadas e logs estão em [`attempt_02`](attempt_02/). O runner registrou o executável standard local Godot 4.7.2.

## Tentativa anterior preservada

`attempt_01` permanece intacta e separada. Seu único processo iniciado, `headless_01`, terminou com código 1 e quatro falhas em 30 checks: `external_document_history_0`, `history_cleanup_0`, `external_document_history_1` e `history_cleanup_1`. O log contém os erros `M0` correspondentes. A falha foi real e não foi ocultada; conforme o registro de execução, Sol corrigiu a identidade do recurso externo com `take_over_path` em `m0_subject/plugin.gd`, sem alterar as expectativas, antes de `attempt_02`.

O erro `CreateProcess 193` do wrapper usado na consulta preliminar de versão foi um problema de seleção do executável, anterior à prova. O runner foi então apontado ao binário standard, cujo caminho e hash estão registrados no manifesto; não foi contado como resultado de processo M0.

## Limite da supervisão

Esta é conferência operacional dos resultados, marcadores, logs, contagens e hashes. Não constitui auditoria semântica independente da implementação nem validação de integração com o runtime do jogo. A prova mínima não carrega gameplay, autoloads, perfil, catálogo ou renderer do jogo.
