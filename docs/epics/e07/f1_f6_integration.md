# E07 F1–F6 — integração operacional

22/10/2026. Integração solicitada pelo usuário, validada tecnicamente e disponível para F7. Não representa aceite de gameplay E07.

## Composição

Base integrada: `f6ba5a9735846ca87fc735178df7bbe932539b6f`, branch `codex/e07-integration`. A cadeia já era cumulativa em F6; a composição incorporou também a coordenação do playtest sem conflitos. O delta contra F6 contém somente documentos, sem alteração de runtime, testes ou runner.

| Entrega | HEAD incorporado |
|---|---|
| F1 | `61c3828085f7c5f757f436379f67e4edbfdf414e` |
| F2 | `6a64d7ba3846a19a86a63fa25b66fb51e5d6ade7` |
| F3 | `6299e9a1f6540d6bbb21e6079808cbcaf8c9f229` |
| F4 | `ee76b442c336c5818ee90b8e9d7478cdd739d593` |
| F5 | `a93ea74f41e95fe11174e390b651c0ce1fe41c95` |
| F6 | `eca6f1bb76ce3e3654173763aefa3d006f4db82f` |

## Evidência

Luna supervisionou a execução; coordenação conferiu resultados e consolidou a integração. Todos os seis ZIPs finais tiveram SHA256 conferido contra os recibos de entrega, preservados em `delivery/f1.md` até `delivery/f6.md`. As coberturas anteriores são reutilizadas dentro de seus limites; não se afirma uma nova execução integral.

Na composição: **11 testes PASS, 470 checks**, exit 0, sem falhas ou timeouts: isolamento de perfil, F2 migration/integration, F4 restart (workers write/recover/confirm), F6 runtime/snapshot, F5 campaign/build, F3 snapshot, F1 geometry/actor integration.

Evidência local preservada em `C:/Users/João Pedro/.codex/worktrees/e07-integration/RagRPG/.godot/verification/e07_integration_2026_10_22/`.

- `final_01/checks.jsonl`: SHA256 `7f3ce72f6b42e75d54105c970fd62f28de264f8b074efa6d81e7c48996d069e2`.
- `final_01/plan.json`: SHA256 `7fae73ca9794721b9b532ffcce300f88b671852b7a981fc1032dc79e3037a87f`.
- Runner: `28e04b035d361b0aab2b945870ef27f378ea2e940c5ec9d308d09f48fa2c800b`.
- Godot 4.7.2 standard: `ab1824f85bfd8e0e4128182c000c4003a3e042245b2967848d089b2a04b22424`.

Reprodução: executar `tools/verify.ps1` com o Godot habitual em `.tools/review-engine/Godot.exe`, primeiro `-Test e07_f1_import_test`; depois `-F1Fixture -SkipEditorImport` e os 11 IDs acima, completos no `plan.json`, timeout 300 segundos por etapa.

Bootstrap customizado import_01 passou; import_03 confirmou o resultado. A tentativa adicional import_02 com editor_import comum falhou por GitPlugin indisponível, mesmo com exit 0: não é certificada como PASS. A cópia nativa desliga apenas autoload VCS; 1.649 fontes primárias conferidas. Cinco .uid de F6 diferem em CRLF/LF, com hashes normalizados equivalentes; não alegar identidade bruta desses cinco arquivos com a evidência antiga. Os 246 auxiliares gerados pelo import foram registrados e restaurados exclusivamente no checkout novo, previamente limpo. Registro `environment_cleanup_record.json`, SHA256 `c98de9aa35dab41d4e8a4260571a03cd4a6af6b62c48f9dcf47b46b25bc930d7`.

## Consumidor e limites

[Despacho F7](f7_dispatch.md) fornece checkout, branch, APIs e propriedade exclusiva. O usuário já autorizou F7 no próprio chat. As decisões aprovadas estão consolidadas no [índice](e07_decisions.md). F8 continua aguardando aval. Não foi enviada mensagem automática nem iniciada implementação F7 nesta integração.

Snapshot/perfil continuam limitados a 4 MiB, com revisões exatas e custos síncronos de captura/escrita. Interface de migração e seleção/retomada pertence a F7; escala, fluidez e avaliação completa não são demonstradas por estes checks. Não executar migração pessoal automaticamente. A integração não alterou master nem publicou commits remotos.

As 214 alterações pessoais do checkout habitual foram inventariadas por SHA256 em `.godot/verification/e07_integration_2026_10_22/preservation.json`; o avanço deve ser fast-forward e conferir os mesmos bytes. Logs e worktrees dos produtores permanecem preservados. CLI de workflow ausente; usadas conferência Git, contratos e runner existentes.

A atualização documental valida referências e precedência, sem repetir gameplay após os testes acima. O registro de liberação posterior informa o HEAD entregue a F7, aplicação no playtest e arquivamento efetivo.

## Liberação efetivada — 22/10/2026

Base documental entregue a F7: `a511584fbde36364b7b47cc9839bcf3c6b429e45`. Playtest e codex/e07-f7 avançaram por fast-forward para essa base; as 214 alterações locais foram conferidas e preservadas byte a byte. Chats F1–F6 arquivados com sucesso após integração e validação. Worktrees e evidências permanecem disponíveis. Este registro posterior altera somente documentação; ambos os destinos recebem também esse registro. F7 pode retomar pelo despacho, sem novo planejamento de arquitetura.
