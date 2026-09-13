# Desenvolvimento, revisão e playtest

Fluxo autorizado pelo usuário em 11/09/2026. Substitui as restrições anteriores
que exigiam aceite entre rodadas de revisão e para preparar a versão de playtest.

## Responsabilidades

1. Usuário autoriza escopo e criação de uma tarefa com o modelo apropriado.
2. Implementador trabalha em branch/worktree isolada e entrega commit e validações.
3. Astra revisa código e valida as regras; solicita correções ao mesmo implementador
   até aprovação técnica. Esse ciclo é automático dentro do bloco autorizado.
4. Astra prepara rebase, resolve conflitos e repete verificações na composição final.
5. Usuário faz playtest no projeto fixo, relata ajustes ou aprova o candidato.
6. Somente com esse aceite Astra faz merge em master. Novos marcos precisam de autorização.

Astra: arquitetura, revisão, integração e direção de arte. Sol: gameplay e sistemas.
Terra: conteúdo e UI com contratos delimitados. Não criar tarefas duplicadas para
cada rodada de correção; continuar na tarefa original. Não ampliar o escopo durante revisão.

## Diretório fixo e branches

Projeto que o usuário abre no Godot:
`C:/Users/João Pedro/Documents/ChatGPT/RagRPG/project.godot`.

- `master`: última versão aceita pelo usuário.
- `codex/playtest`: branch mantida no diretório fixo; candidato para o usuário testar.
- `codex/<tarefa>`: implementação isolada, normalmente em uma worktree do Codex.

Rebase organiza o histórico; por si só não atualiza os arquivos do projeto aberto.
Por isso Astra também avança `codex/playtest` até o candidato revisado.
O usuário não precisa fazer checkout, rebase ou merge. Se o editor pedir para
recarregar arquivos alterados externamente, aceitar o reload e executar F5.
Parar uma partida em execução antes de testar o novo candidato.

## Preparar candidato

- Inspecionar status e trabalho em andamento em ambos os diretórios. Preservar
  alterações locais do editor/usuário; não usar reset --hard, clean ou stash cego.
- A branch da tarefa é rebaseada sobre a base de integração atual. No primeiro
  ciclo, `codex/playtest` contém master mais a documentação do fluxo e a formatação
  local do project.godot; usar essa base preserva ambas as contribuições.
- Não reescrever uma branch enquanto o implementador está trabalhando nela.
  Confirmar entrega concluída e worktree limpa antes do rebase; manter referência
  de backup do commit anterior ao rebase.
- Verificar o resultado rebased, então avançar playtest por fast-forward. Isso
  atualiza o projeto fixo sem integrar a funcionalidade em master.
- Registrar candidato, base, evidências e limitações em `docs/REVIEW_M1.md` ou no
  relatório correspondente. Comunicar o hash efetivo a testar.

## Após feedback do usuário

Reprovação/ajustes: encaminhar à tarefa original, revisar e preparar novo candidato.
Aprovação: confirmar que HEAD de playtest ainda corresponde ao candidato aprovado
e que não há modificações locais não revisadas; então fazer merge em master sem
trocar a branch do diretório aberto no Godot (worktree de integração temporária).
Preservar a branch da tarefa até confirmar a integração; não publicar/push automaticamente.

## Limites de automação

Revisão 13/09/2026: as conversas de LONG_TERM_EPICS.md são reservas, sem execução.
Quando o usuário liberar um épico, Astra aprova cada passo e conduz correções com
o implementador; usuário testa no fechamento do épico/subépico. E10 é separado por
família de classe e E11 por par direcional, cada qual com seu próprio playtest.
As reservas não autorizam iniciar código, delegar, agendar ou continuar marcos.
Estados/checkpoints e handoffs estão em LONG_TERM_EPICS.md e docs/epics/.

O ciclo de revisão é executado durante a tarefa ativa, usando envio de mensagens e
espera por conclusão. Não há monitor em segundo plano ou automação recorrente criada.
Aceite técnico não afirma aprovação visual, de diversão ou de FPS sem evidência.
O jogo permanece no mesmo caminho mesmo que a tarefa original esteja em outra worktree.
