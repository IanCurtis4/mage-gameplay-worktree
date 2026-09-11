# RagRPG — instruções para colaboradores

- Leia `docs/MVP.md`, `docs/ARCHITECTURE.md` e o handoff correspondente antes de editar.
- O usuário quer aceite separado para criar cada nova tarefa e liberar cada bloco
  de trabalho. Dentro de um bloco aprovado, execute arquivos e verificações necessárias.
- Não crie tarefas, delegue a outros agentes ou inicie marcos seguintes sem aceite.
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
