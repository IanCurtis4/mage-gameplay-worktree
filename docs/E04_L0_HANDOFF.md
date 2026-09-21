# E04 S0-D L0 — handoff de aprendizado e compatibilidade

## Escopo entregue

- personagens novos começam com skills base R0 e presets vazios;
- R1 e cada melhoria custam um ponto; aprender não equipa;
- barra vazia inicia run e produz snapshot válido;
- respec devolve somente ranks comprados;
- schema 2 permanece, com catálogo 2 / `e04_learn_from_zero_v1`;
- saves schema 2 do catálogo 1 migram as três skills gratuitas antigas para
  `granted_skill_ranks`, preservando identidade, XP, investimentos, presets,
  contadores e carteira. O arquivo anterior vira backup e a migração é idempotente.

Contrato de produto: [E04_LEARNING_AND_ARCHER.md](E04_LEARNING_AND_ARCHER.md).

## Validação

`tools/verify.ps1` inclui `e04_learn_from_zero_migration_test.gd`, cobrindo novo
personagem, cristal de 80 XP job/JL2, aprendizado R1, ausência de autoequip,
barra vazia, reload, snapshot, respec e migração de perfil antigo com revisão >0.

## Fora deste pacote

Arqueiro, novas tabelas numéricas, mudanças de E05/evoluções e campanha E07.
E04-S0-C (`a834941`) continua aguardando revisão técnica de Astra em separado.
