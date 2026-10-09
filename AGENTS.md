# RagRPG — instruções para colaboradores

> Norma vigente desde 08/10/2026, a partir de E06:
> [docs/WORKFLOW.md](docs/WORKFLOW.md) é a fonte única do fluxo.
> Cada épico autorizado terá um novo chat permanente Astra para arquitetura,
> contratos e guias. Execução, integração e revisão operacional usam tarefas
> temporárias separadas, com modelo proporcional ao risco.
> Esta norma substitui a reutilização obrigatória de um chat executor por épico
> e o papel de Astra permanente como gerente, implementador ou integrador.
> Preserva a regra de 26/09: nenhum gate Astra por microtarefa.
> E06 iniciado por autorização humana; contrato e retomada:
> [docs/epics/e06.md](docs/epics/e06.md). E07+ não liberados.

- Leia `docs/MVP.md`, `docs/ARCHITECTURE.md` e o contrato/checkpoint correspondente
  antes de editar. E00 e decisões posteriores explícitas prevalecem sobre o piloto.
- Usuário autoriza separadamente cada épico ou novo marco. Decisões de arquitetura
  que alterem escolhas de produto são apresentadas ao usuário antes dos consumidores.
  Correções dentro do contrato são automáticas na mesma tarefa.
- Astra permanente cuida de arquitetura/guias; Sol implementa sistemas novos e
  fronteiras críticas; Terra conduz UI/conteúdo sobre APIs estáveis; Luna executa
  lotes fechados. Leia `docs/REVIEW_WORK_PACKAGES.md`.
- Revisão técnica independente de persistência, matemática, causalidade e fechamento
  usa tarefa temporária separada quando necessária. Não passar tudo pelos quatro modelos.
- Paralelismo somente com dependências estáveis e dono exclusivo por arquivo.
  Subagentes delimitados no épico autorizado continuam possíveis; não dispensam
  o registro de propriedade. Não criar chats ou iniciar marcos por efeito de reserva.
- Arquivar um chat executor só após entrega registrada, validada e integrada com
  sucesso. Falha/decisão mantém pendente; correções reutilizam ou reabrem o mesmo chat.
- Após aprovação técnica do candidato, preparação/rebase e atualização do playtest
  estão autorizados ao executor operacional designado. O diretório habitual
  permanece em `codex/playtest`; preservar alterações locais e save pessoal.
- Merge em `master` somente após aceite explícito do usuário sobre o candidato
  testado. Aprovação técnica não é aprovação de produto. Sem push automático.
- Use Godot 4.7.2 standard e GDScript tipado; sem plugins externos nesta fundação.
- Não duplique fórmulas de atributos/dano em atores ou UI. Mudanças de contrato
  devem ser documentadas e justificadas para revisão independente.
- Recursos de catálogo são imutáveis; estado da run pertence a instâncias separadas.
- Textos visíveis em pt-BR. Código e IDs em inglês, caminhos em snake_case.
- Preserve arquivos do usuário. Não adicione `.tools`, `.godot` ou builds ao Git.
- Mudanças de runtime executam `tools/verify.ps1`; mudanças de regras acrescentam
  invariantes. Entrega exclusivamente documental valida coerência/referências e
  declara que não repetiu a suíte de gameplay.
- Encerre com mudanças, evidências de validação e limitações concretas.
