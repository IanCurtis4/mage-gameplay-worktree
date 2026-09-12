# Retomada — correções de mira e piloto de arte

Novo pedido do usuário em 12/09/2026, após testar a UI `c771d76`:
- cone parece lançar à esquerda quando cursor está além do alcance;
- auto contra inimigos melee parece falhar; comportamento não é intencional;
- criação de arte autorizada: personagens compactos, fantasia oriental cartunesca,
  guerreiro/arqueiro, pisos pedra/terra/grama; gelo e física própria em passo futuro.

Sequência atual: reproduzir/corrigir os dois relatos na branch de UI, validar e
atualizar playtest; criar primeiro piloto de sprites/texturas com imagegen nativo,
salvar arquivos e prompts no projeto, integrar apenas após conferir legibilidade.
Produção de todas as animações/direções e migração para chão 3D continuam posteriores.

Estado inicial: master aceito `e70e4d4`; playtest e worktree de UI `c771d76`.
O usuário adicionou `build/` e `export_presets.cfg`, além do GitPlugin local anterior;
preservar e não incluir esses arquivos nos commits desta tarefa.

## Correções concluídas

- Cone: direção e origem do efeito são capturadas no lançamento. Movimento e auto
  posteriores não podem virar o efeito; a geometria do dano continua compartilhada.
- Auto: arco agora chega à distância real do alvo; antes tinha raio fixo de 62 px,
  inferior ao alcance de contato permitido. Erros de precisão exibem `ERROU` e não
  fazem o alvo piscar como se tivesse recebido dano. Fórmulas e alcance preservados.
- Validação: `tools/verify.ps1` completo no worktree limpo passou 221 checks,
  incluindo clique além do cone com câmera, cast/auto em direções opostas, miss/acerto
  e melee real com RNG em 30/60/144 Hz e ambas as ordens de atualização.
- Não foi reproduzida falta de dano mecânica contra melee nesses testes; a correção
  aborda duas inconsistências visuais concretas. O próximo playtest confirma o relato.
