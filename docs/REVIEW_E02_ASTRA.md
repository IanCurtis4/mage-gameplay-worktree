# Revisão integrada E02 — Astra

Data: 14/09/2026. Candidato: `7bc3dd4818b5e91ce43906a4fcf693eb24549453`,
branch `codex/e02-character-menu`. Comparação de escopo com `docs/epics/e02.md`.
Alterações do usuário incorporadas de `codex/playtest` não são defeitos do épico.

## Resultado

**Aceite técnico pendente de correções de integração. E03 ainda não iniciado.**
Lista/criação de personagens, edição transacional de presets e entrada pelo menu
estão presentes. O fluxo completo ainda não satisfaz o critério de usar builds
distintas sem trocar classe silenciosamente ou perder o vínculo persistente.

## Achados por inspeção do candidato

1. **P1 — Reinício/troca de classe contornam persistência.** Em
   `scripts/main.gd`, `_ready` consome `pending_run_state`; `_restart_run`
   encerra a sessão e recarrega sem reservar outra. O fallback cria um estado
   legado com `selected_class_id` (Espadachim por padrão), sem personagem
   persistente. `_select_class` também recarrega diretamente. Encaminhar esses
   caminhos ao menu ou iniciar outra sessão pela fachada, preservando identidade.
2. **P1 — Falha ao encerrar não bloqueia navegação.** `_close_persistent_run`
   ignora o resultado de `end_run` e descarta a fachada. Preservar contexto e
   desfecho em erro; apresentar recuperação e navegar somente após sucesso.
3. **P1 — Escolhas de skills não chegam ao comportamento.**
   `PlayerActor.available_skill_ids` retorna o kit inteiro e `_with_passive`
   aplica a passiva por classe, independentemente do preset. A limitação está
   corretamente declarada pelo implementador, mas impede o aceite funcional
   da seleção de build. Integrar slots, ordem e passivas existentes; fórmulas
   novas, progressão/ranks e efeitos novos de equipamentos ficam em E03/E06.
4. **P2 — Teste não cobre a fronteira e não contabiliza falhas.** O teste E02
   exercita o menu, mas não atravessa início/arena/reinício/retorno. `_check`
   incrementa `checks`, porém não `failures`: saída direta pode ser zero após
   falha. O verificador externo captura erros, mas o teste deve falhar sozinho.

## Evidência e próximo gate

Verificação independente em Godot 4.7.2, com `tools/verify.ps1` e
`-SkipEditorImport`, concluída com código zero; E02 reportou 10 checks.
Isso não equivale a teste visual nem a reprodução dinâmica dos fluxos acima:
os achados são demonstrados pelos caminhos de código e pela limitação declarada
em `REVIEW_E02.md`. A importação de editor não foi repetida nesta execução.

Solicitadas correções ao Terra na tarefa existente E02, com testes integrados
de Mago/reinício, troca de personagem, encerramento com falha e retry e dois
presets distintos. Após entrega: revisar o delta e suas evidências, concluir
inspeção visual e preparar candidato de playtest se aprovado. Merge em master
continua condicionado ao aceite do usuário sobre o candidato testado.
