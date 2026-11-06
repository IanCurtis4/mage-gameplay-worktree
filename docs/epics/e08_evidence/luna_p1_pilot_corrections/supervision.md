# Supervisão Luna — P1 correções de atlas e UI

Resultado: **PASS na conferência de integridade e evidência de execução delimitada**.

- Candidato `55960be86ffe9e4b7ddec4570cd84abd1c184a15`, código `3c405e9903ae930b719020b402afe65fc62caa22`, base `b105dbc6884395edac9f7478b0afe200a4a0940d`; HEAD observado `aeeca2ca2c211c5f1491449c6965bb3f473f7318` contém registros posteriores. Branch `codex/e08`.
- Os **17** arquivos de `files_sha256` conferem com os bytes do checkout; os **114** caminhos/hashes preservados de P3 conferem individualmente com os arquivos locais e não intersectam caminhos do commit P1. Os dois hashes de dependências P2mix e os **4/4** backups também conferem. WIP P3 `7f04830e01db0f49acefd47899c271b45b65adaf` permanece incompleto; sua presença/hash preservados não certificam P3.
- `raw_evidence.zip` tem SHA256 `ea340a5c8e8dd70b585f65a7048b2a5c710075c0296a0b39af46b9db012feba0`; seus **29/29** membros conferem com `hashes.json`. As seis capturas nativas PNG conferem com seus hashes externos e `native_ui.json` normalizado LF confere com o hash declarado. O arquivo JSON e processo nativos também estão preservados no ZIP.
- O engine no caminho registrado confere: SHA256 `ab1824f85bfd8e0e4128182c000c4003a3e042245b2967848d089b2a04b22424`. `project.godot` da fixture confere (`33726afe86093a0d6f580114f803045e4f6624dc94528ecbebd61fb199a06517`). O manifesto confere (`a1ebf2f62c0502532df3c80f6bda79da7c776c99283a7eabc443621d71053f26`); seus **2.301** caminhos conferem individualmente entre origem e fixture. `tools/verify.ps1` está incluído nos 17 hashes de entrada.

## Execuções finais

Os **9/9** registros finais do runner têm nome/índice/output hash compatíveis com os bytes arquivados, exit 0, `failed=false`, sem timeout e conclusão positiva:

| Etapa | Checks | Resultado |
|---|---:|---|
| combat_animation_test | 39 | PASS |
| e08_presentation_test | 2.204 | PASS |
| e08_pilot_ui_test (headless) | 55 | PASS |
| e08_audio_test | 132 | PASS |
| battle_ui_test | 47 | PASS |
| ui_layout_test | 30 | PASS nesta execução final |
| action_bar_ui_test | 80 | PASS |
| e07_f7_presentation_test | 27 | PASS |
| e07_f3_lifecycle_test | 90 | PASS |

Nenhum output final contém `SCRIPT ERROR`, `Parse Error` ou `ERROR:`. Os **2.122** checks de apresentação anteriores são mantidos dentro dos 2.204; não os contei novamente como cobertura adicional.

## Evidência nativa de UI

`native/process.json` registra a mesma prova UI sem `--headless`, renderer Compatibility, exit 0, sem timeout; `native.output.log` e `native_ui.json` registram **61 checks, zero falhas**. Três registros cobrem viewport 1280×720, 1920×1080 e retorno a 1280×720, todos com escala efetiva `1.20000004768372`, viewport lógico 1280×720 e dois handlers de resize. No registro, painel `(28.8,264.0,468.0,165.6)`, rodapé `(28.8,444.0,1222.4,91.2)` e barra `(181.6,549.6,916.8,148.8)` estão dentro do viewport e não se intersectam; o resumo HUD/campanha está preenchido, há três ações e rolagem disponível (`max=288`, `page=118`).

A saída bem-sucedida dos 61 checks corresponde à prova que exercita rolagem por roda sem zoom da câmera, abertura do painel de ajustes em pausa, foco/rolagem até o controle final, fechamento por Escape e ciclo de resize/reabertura sem acúmulo de handlers. Esta é evidência automatizada de layout/interação; não constitui juízo artístico. O teste legado `ui_layout_test.gd` não mudou entre base e candidato. A falha histórica de help em 1280, registrada no checkpoint anterior, permanece apenas como histórico; não a reclassifico retroativamente. A execução final atual passa, e o teste legado não mudou entre base e candidato.

Esta supervisão verifica integridade da evidência e execução registrada; não é auditoria semântica independente, aceite artístico ou sonoro, nem certificação/aprovação do WIP P3. Não rerodei testes nem alterei runtime, teste, fixture, recibo alheio ou WIP.
