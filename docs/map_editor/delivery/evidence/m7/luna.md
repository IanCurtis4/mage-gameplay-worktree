# Supervisão Luna — Editor F7 / M7

## Rodada corrigida

- Branch `codex/map-editor-m7`; HEAD antes e depois: `c2d6aea78ce45c974d96d688ce591e339dbbe383`.
- Engine Godot 4.7.2 standard, SHA256 `AB1824F85BFD8E0E4128182C000C4003A3E042245B2967848D089B2A04B22424`.
- Runner: [logs e manifest](luna_run/corrected/manifest.json). `project.godot` fonte SHA256 `ADF17C0941269918DEE0A0005329D874DA199778DDEFCE294CA00E655367857E`; `project.godot` da fixture SHA256 `B53FE90C336F6E1133E50A66296E2C152B7178ADDC30B6AECBF0399FADAE5B0E`. O manifesto registra os deltas VCS declarados “VCS startup disabled” e “UI driver only when Native”. Separadamente, compara os 1821 inputs do projeto: 1821 hashes fonte iguais aos hashes correspondentes na fixture, 0 divergentes.
- Dez estágios terminaram sem timeout/aborto: import; 113 checks exchange; CLI review A e B; CLI export e propose; rejeições CLI para export/propose/review de JSON com tipo inválido; UI nativa com 36 checks. Resultado do runner: `M7_ALL_PASS`. As rejeições tiveram exit 1 esperado, marcador `exchange_invalid_type`, `ok:false` e nenhum arquivo de saída.
- Os dois reviews CLI do pacote produziram output hash idêntico `39507046833ff82ba82840421bbe3cf133806611fdcdacb92368db5d5b1bd037`; igual ao hash do teste core. A UI registrou `gui_cli_authority_hash=true`.
- Complemento: review CLI do request/proposal criados pela UI na mesma rodada passou com exit 0, `ok:true`, output hash `dc4774b22241032984a35d4be4b930aca4ec1ee3e947a8ce2efb679da5b1a154` para “Proposta nativa”, igual ao hash exibido na captura da UI. Os três inputs foram preservados em [native_inputs](luna_run/corrected/native_inputs/): request `native_7f0950fd.rpx` SHA256 `F238811C4931022500A00F10D396BA8EE65DA6753415A607E8B9957C824E7030`; proposal `native_7f0950fd.rpx.proposal.rpx` SHA256 `5CC8D78297A782E0585A2E62713F6CE75C953B82C46F3E1971A2B60A1185831C`; fonte `map.json` SHA256 `2789F428521F29E28EE4B8788C844E127E2D79146749BDB6F91C94B9E8C86A29`. Saída/engine: [native CLI](luna_run/corrected/native_cli.output.log) e [log engine](luna_run/corrected/native_cli.engine.log).
- Verify oficial selecionado: import `editor_import` exit 0; E07 F5 população: 40 checks, 0 falhas; E07 F1 geometria: 33 checks, 0 falhas, seed 711 e manifest `1f17a2dee4e34e41a22f0be992265c440bae3c9db966655238c008f5c8db879c`. Resultado `Selected checks passed (3/299 steps)`; os outros 296 IDs foram intencionalmente omitidos conforme seleção aprovada. Logs: [verify oficial](luna_run/official/checks.jsonl).
- Não foram encontrados `SCRIPT ERROR`, `Parse Error`, `ERROR` ou timeouts nos logs da rodada corrigida e verify selecionado. A importação registrou apenas o aviso de que `tools/map_editor_probe/hosting` contém outro `project.godot` e será ignorado.

## Rodada anterior superada

A execução em `60ba8701632ed6d8b2eb31f1f85643061896c54a` terminou com `M7_ALL_PASS`, mas não foi certificada: Sol identificou a lacuna de saída silenciosa para JSON array na CLI. A rodada corrigida acima ocorreu em novo SHA após a correção e contém os três casos de rejeição de tipo inválido. A evidência bruta antiga permanece em `luna_run/exchange/` para histórico; ela não é usada como validação da rodada corrigida.

## Escopo e limites

Esta é supervisão de execução automatizada, não auditoria semântica independente. A seleção oficial cobriu 3 de 299 etapas; nenhuma afirmação é feita sobre as 296 etapas omitidas. O contrato reserva a validação de invariantes e o fechamento técnico a Sol. A fixture e seus artefatos locais estavam preservados no momento deste relatório; sua limpeza posterior será registrada por Sol.
