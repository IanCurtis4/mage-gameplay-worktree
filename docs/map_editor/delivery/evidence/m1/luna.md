# Supervisão automatizada M1 — Luna

Data: 24/10/2026. Checkout/candidato: `codex/map-editor-m1`, `b4cb8c94021fd0b55fb26b66d20aa768a89008bd`.

Resultado: aprovado nos critérios automatizados do dispatch. Runner terminou com `M1_ALL_PASS`; 9 processos concluídos, 70 checks documentais e 41 checks de UI nativa, todos `ok=true`. Interrupção deliberada: processo encerrado após sinal, `deliberately_terminated=true`, sem timeout; duas recuperações após reinício passaram. Nenhum processo teve timeout. Hashes das fontes listadas no manifesto conferem com os arquivos atuais. Godot SHA-256: `AB1824F85BFD8E0E4128182C000C4003A3E042245B2967848D089B2A04B22424` (esperado idêntico). Nenhuma ocorrência de SCRIPT ERROR, Parse Error, ERROR ou timeout nos logs do runner.

Evidência suplementar autoral conferida, sem reexecução: `cli_apply_results.json` e logs registram base divergente com exit 1 e `code=base_diverged`, sem mutação (`input_hash` e `output_hash` vazios); aplicação válida com exit 0 via sessão, `ok=true`, `valid=true`, revisão 2 (resultado informado pelo autor). Hashes de saída dos dois logs registrados no JSON e resultados estruturados correspondentes. Esta evidência é autoral, separada da supervisão automatizada de Luna.

Evidência prévia da fixture oficial: `m1_full_fixture_final` registra PASS no `editor_import` E07 F1 (1711 arquivos idênticos; única diferença de projeto foi desativar VCS); `m1_fixture_editor_final` registra conclusão de editor/import com aviso de diretório hosting ignorado, sem erros. As execuções mantêm logs/captura/manifest/runs em `luna_run/`; fixture e `.godot` não foram copiados.

Limite: isto confirma execução e hashes, não é auditoria semântica do código nem aceite de produto. Artefatos `.import` locais preexistentes/gerados permanecem preservados.
