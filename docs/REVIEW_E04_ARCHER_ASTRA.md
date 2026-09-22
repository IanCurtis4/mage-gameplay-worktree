# E04 — revisão do fechamento integrado do Arqueiro

22/09/2026. **Aceite técnico do recorte entregue**, sem achados bloqueadores.
O épico E04 completo permanece aberto; aceite de produto depende do playtest.

## Candidato e escopo

Entrega original `c2de0af`, rebaseada sobre `8bb0f63` como `0d5a5c9`.
Backup: `codex/backup-e04-c2de0af`. O rebase acrescentou somente o relatório
de revisão S0-C; código e testes permanecem idênticos à entrega inspecionada.

Revisão cobre o aprendizado do zero e sua compatibilidade (L0), a migração
de ranks das habilidades piloto de Espadachim/Mago e o Arqueiro B1–B13 com
fechamento integrado. Foram confrontados contratos, implementação e testes.

- Persistência: gratuitos antigos viram grants explícitos; compras, XP,
  presets e contadores são preservados, com backup e migração idempotente.
  Aprender R1 custa ponto, barra vazia é válida e respec restitui compras.
- Gameplay: parâmetros por rank alimentam emissão, custo, recarga e mira;
  passivas usam fontes canônicas. Projéteis compartilham colisão contínua,
  respeitam obstáculos, limite de impactos e valores capturados.
- Armadilhas: estados explícitos, limite FIFO, acionamento único e limpeza
  sem detonação. Root usa o contrato compartilhado de controle.
- Abrigo: aquisição depende da posição do observador e revelação; dano já
  emitido permanece válido. Encerramento remove fontes e instâncias.
- Integração: dois presets passam por compra, save/reload, menu, snapshot,
  combate e recompensa, sem depender de augments.

Leituras auxiliares delimitadas: Sol revisou persistência L0; Terra revisou
armadilhas, controle e ocultação. Astra conferiu a composição e reproduziu
a validação, sem iniciar trabalho novo na tarefa do implementador.

## Evidência

Na entrega original, `tools/verify.ps1` com Godot 4.7.2 passou importação,
46 suítes / 1.936 checks e smoke, sem ERROR/WARNING/FAIL no log.
A suíte de fechamento do Arqueiro passou 49 checks.
No diretório fixo após integração, a mesma verificação completa passou novamente:
46 suítes / 1.936 checks, importação e smoke, com saída 0.

## Limites e continuidade

O cenário integrado usa XP válido injetado para montar builds e dano controlado
para finalizar o encontro. Isso verifica contratos, não balanceamento, diversão,
legibilidade ou desempenho. Não foi realizado playtest visual nesta revisão.

O diretório habitual está em `codex/playtest` com o candidato acima. `master`
permanece no E03 aceito. A alteração local preexistente de `project.godot`
(sem diferença textual) foi preservada.

Próximo gate: usuário testar Arqueiro (arco e armadilhas), aprendizado/equipagem,
save/reload e regressão de Espadachim/Mago. Roteiro detalhado em
E04_ARCHER_INTEGRATED_HANDOFF.md. Depois do aceite de produto, integrar o
candidato em master e continuar os pacotes restantes do E04: kit ampliado
do Espadachim e Mago, com duas builds por base. Não liberar E05 por este aceite.
