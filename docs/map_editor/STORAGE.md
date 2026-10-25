# Armazenamento — decisão humana25/10/2026

Manter somente o checkout principal do RagRPG e **um worktree de execução atual**.
O humano pediu remover testes/produções antigos e os demais worktrees por falta
de espaço. Esta regra vale para os próximos passos do editor e substitui a
acumulação de checkouts, fixtures e pacotes por tentativa/pacote.

- Antes de criar qualquer checkout/fixture/export, conferir espaço e inventário.
  Reutilizar o worktree corrente quando a tarefa anterior terminou; registrar
  branch/commit e propriedade. Não criar um terceiro checkout por conveniência.
- Durante a tarefa, usar no máximo uma fixture reutilizável e um cache de engine.
  Sincronizar somente arquivos alterados; não copiar assets/cache por rodada.
  Supervisão Luna usa a mesma fixture sequencialmente, com hashes conferidos.
- Ao fechar a validação, preservar apenas fontes versionadas, fixtures mínimas
  de reprodução, logs, hashes, relatório e capturas necessários ao recibo.
  Remover cópias integrais do projeto, imports, shader cache, staging, exports,
  perfis descartáveis e versões antigas de build assim que não forem necessários.
  Não colocar uma fixture inteira dentro de docs/evidence nem empilhá-la no Git.
- Antes de remover worktree antigo, conferir estado e preservar alterações locais
  em snapshot Git recuperável; manter branches/commits. Registrar caminho,
  HEAD e referência da preservação. Não arquivar conversas por efeito da limpeza.
- Saves pessoais e fontes de testes automatizados permanecem preservados.
  Artefatos de teste gerados não são os testes fonte. Não remover dados pessoais
  nem modificar o checkout principal para aplicar runtime sem autorização própria.
- Um bundle histórico cujo conteúdo já esteja preservado no repositório não
  justifica manter outra cópia pesada; conferir objetos/referências antes de apagar.
- Recibos futuros informam espaço liberado, dois checkouts mantidos, exceções
  temporárias e a limpeza final. Links históricos para diretórios removidos são
  referências de origem: recuperar pelo SHA/branch, sem recriar automaticamente.

Worktree corrente em25/10:
`C:/Users/João Pedro/Documents/ChatGPT/RagRPG/.tools/map-editor-m5`.
Principal: `C:/Users/João Pedro/Documents/ChatGPT/RagRPG`.
O estado entregue de F0–F4 segue no histórico Git e por ancestralidade no F5.
