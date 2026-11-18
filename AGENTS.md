# RagRPG — instruções para colaboradores

> Norma vigente atualizada por decisão humana em 12/10/2026:
> [docs/WORKFLOW.md](docs/WORKFLOW.md) é a fonte única do fluxo.
> Cada épico autorizado terá um novo chat permanente Astra para arquitetura,
> contratos, guias e planejamento de longo prazo. Luna acompanha testes
> automatizados; Sol corrige falhas e consolida validação técnica. Execução
> e integração usam tarefas delimitadas, com modelo proporcional ao risco.
> Sem revisão Astra completa obrigatória por capítulo. Astra só retorna
> fora de arquitetura para análise visual excepcional ou problema que Sol
> justifique como muito complexo. Norma substitui gates Astra de fechamento.
> Esta norma substitui a reutilização obrigatória de um chat executor por épico
> e o papel de Astra permanente como gerente, implementador ou integrador.
> Preserva a regra de 26/09: nenhum gate Astra por microtarefa.
> E06 iniciado por autorização humana; contrato e retomada:
> [docs/epics/e06.md](docs/epics/e06.md). Gameplay E06 aceito em18/10.
> E07/F10: [aceite de produto com ressalvas](docs/epics/e07/e07_closure_2026_11_05.md)
> em5/11; integração operacional separada. E08 abriu
> [preparação de arquitetura/inventário](docs/epics/e08_opening_2026_11_05.md)
> e foi aceito em 16/11. E09 autorizado em 16/11:
> [quatro híbridas e pipeline de arte neutro](docs/epics/e09.md), uma sessão
> por tarefa; aceito em 17/11 e integrado em `master`. Contratos antes dos
> consumidores; E10, E11 e a reserva antiga de integração/demo permanecem
> reservados. E12 autorizado em 17/11:
> [HUD de combate](docs/epics/e12.md) (recursos das híbridas e barras de cast),
> uma sessão por tarefa; multiplayer continua fora.

- Leia `docs/MVP.md`, `docs/ARCHITECTURE.md` e o contrato/checkpoint correspondente
  antes de editar. E00 e decisões posteriores explícitas prevalecem sobre o piloto.
- Direção futura de mapas/economia: `docs/PRODUCT_DIRECTION.md`; skills de conteúdo:
  `docs/DELIVERY_SKILLS.md`. Direção e skill não iniciam E07+ nem alteram runtime.
- Usuário autoriza separadamente cada épico ou novo marco. Decisões de arquitetura
  que alterem escolhas de produto são apresentadas ao usuário antes dos consumidores.
  Correções dentro do contrato são automáticas na mesma tarefa.
- Astra permanente cuida de arquitetura/guias; Sol implementa sistemas novos e
  fronteiras críticas; Terra conduz UI/conteúdo sobre APIs estáveis; Luna executa
  lotes fechados. Leia `docs/REVIEW_WORK_PACKAGES.md`.
- Luna verifica execução, conclusão, erros e hashes dos testes; falha vai a Sol,
  sem editar expectativas para ocultá-la. Sol valida contrato e invariantes e
  registra limitações. Essa supervisão não é auditoria semântica independente.
  Astra não é gate rotineiro, inclusive em persistência/matemática/causalidade;
  escalar arquitetura ou exceção concreta, conforme WORKFLOW. Não passar tudo pelos quatro modelos.
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
  devem ser documentadas e justificadas; escolhas de arquitetura/produto seguem WORKFLOW.
- Recursos de catálogo são imutáveis; estado da run pertence a instâncias separadas.
- Textos visíveis em pt-BR. Código e IDs em inglês, caminhos em snake_case.
- Preserve arquivos do usuário. Não adicione `.tools`, `.godot` ou builds ao Git.
- Mudanças de runtime executam `tools/verify.ps1`; mudanças de regras acrescentam
  invariantes. Entrega exclusivamente documental valida coerência/referências e
  declara que não repetiu a suíte de gameplay.
- Encerre com mudanças, evidências de validação e limitações concretas.
