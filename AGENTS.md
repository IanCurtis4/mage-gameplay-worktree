# RagRPG — instruções para colaboradores

- Leia `docs/MVP.md`, `docs/ARCHITECTURE.md` e o handoff correspondente antes de editar.
- O usuário autoriza separadamente o escopo de cada épico ou novo marco.
  Revisão proporcional ao risco aprovada em 14/09/2026: Luna executa lotes
  fechados, Terra conduz pacotes rotineiros, Sol implementa sistemas novos.
  Astra revisa contratos críticos e o fechamento integrado, não cada commit.
  Leia docs/REVIEW_WORK_PACKAGES.md e docs/WORKFLOW.md. Correções dentro do
  escopo são automáticas, sem solicitar aceite a cada rodada.
- Após aprovação técnica de Astra, rebase e preparação da branch de playtest estão
  autorizados. O diretório habitual do Godot permanece em `codex/playtest`.
- Merge em `master` somente após aceite explícito do usuário sobre o candidato testado.
  Não confundir aprovação técnica com aprovação do produto. Leia `docs/WORKFLOW.md`.
- Não crie novas conversas de épico nem inicie marcos seguintes sem aceite.
  Dentro de um épico liberado, subagentes Luna/Terra estão autorizados para
  pacotes delimitados, com trabalho independente útil e dono único por arquivo.
  Persistência/matemática crítica continuam com Sol e revisão de Astra.
- E01 mantém Sol na conversa principal. Conversas futuras podem trocar modelo
  por pacote antes da execução; reserva não é execução. Astra aprova padrões
  visuais; Terra integra arte/VFX e Luna configura receitas sobre contratos
  prontos. Não passar toda entrega pelos quatro modelos.
- Use Godot 4.7.2 standard e GDScript tipado; sem plugins externos nesta fundação.
- Não duplique fórmulas de atributos/dano em atores ou UI. Mudanças nos contratos
  devem ser documentadas e justificadas no resultado para revisão de Astra.
- Recursos de catálogo são imutáveis; estado da run pertence a instâncias separadas.
- Textos visíveis em pt-BR. Código e IDs em inglês, caminhos em snake_case.
- Preserve arquivos do usuário. Não adicione `.tools`, `.godot` ou builds ao Git.
- Execute `tools/verify.ps1`; acrescente testes de invariantes para mudanças em regras.
- Encerre com resumo de mudanças, evidências de validação e limitações concretas.
