# RagRPG — instruções para colaboradores

- Leia `docs/MVP.md`, `docs/ARCHITECTURE.md` e o handoff correspondente antes de editar.
- O usuário autoriza separadamente a criação/escopo de cada tarefa ou novo marco.
  Dentro do bloco autorizado, o ciclo Astra → revisão → correções pelo mesmo agente
  → nova revisão é automático, sem solicitar aceite para cada correção.
- Após aprovação técnica de Astra, rebase e preparação da branch de playtest estão
  autorizados. O diretório habitual do Godot permanece em `codex/playtest`.
- Merge em `master` somente após aceite explícito do usuário sobre o candidato testado.
  Não confundir aprovação técnica com aprovação do produto. Leia `docs/WORKFLOW.md`.
- Não crie tarefas, delegue a novos agentes ou inicie marcos seguintes sem aceite.
- Modelos escolhidos pelo usuário: Astra coordena/revisa decisões críticas e arte;
  Sol implementa sistemas de gameplay; Terra recebe trabalho delimitado de conteúdo/UI.
- Use Godot 4.7.2 standard e GDScript tipado; sem plugins externos nesta fundação.
- Não duplique fórmulas de atributos/dano em atores ou UI. Mudanças nos contratos
  devem ser documentadas e justificadas no resultado para revisão de Astra.
- Recursos de catálogo são imutáveis; estado da run pertence a instâncias separadas.
- Textos visíveis em pt-BR. Código e IDs em inglês, caminhos em snake_case.
- Preserve arquivos do usuário. Não adicione `.tools`, `.godot` ou builds ao Git.
- Execute `tools/verify.ps1`; acrescente testes de invariantes para mudanças em regras.
- Encerre com resumo de mudanças, evidências de validação e limitações concretas.
