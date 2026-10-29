# Rascunhos de testes F9-04 — encontros e patrulhas

Arquivos sob propriedade de Luna nesta fatia:

- `tests/map_editor_encounter_authoring_test.gd`: 27 checks puros de propostas,
  validação, histórico, catálogo, compiladores e Store.
- `tests/map_editor_encounter_authoring_ui_test.gd`: 25 checks sobre Shells,
  apresentações e janelas reais, equivalência GUI/AX, documentos, workers e
  pacotes compilados.

Os testes ainda não foram executados. Não foram criadas fixtures nem UIDs pelo
engine. A execução, importação e geração de UIDs aguardam liberação explícita.

## Correções aplicadas na revisão pré-execução

- Undo e redo agora conferem cada hash intermediário; caminhos de Store usam um
  identificador aleatório por execução.
- Assinaturas usam `panel.proposal_hash()`. Hashes stale/adulterados têm formato
  SHA-256; dados e diff da proposta são adulterados internamente e restaurados
  após comprovar rejeição sem efeito em fonte/histórico.
- A remoção de pincel confere que os slots do outro pincel sobrevivem. O plano
  usa também um pincel duplicado sob ID próprio.
- Patrulha abre com a população realizada de `PatrolFixture.fixture()`, contendo
  o slot `guard`; o fluxo de UI compara os mesmos edits em ambos os painéis.
- Fluxo de documento salva limpo, torna dirty, preserva e compara o rascunho,
  testa confirmação, abre de verdade e provoca conflito no painel após editar o
  arquivo em disco com uma fonte válida.
- O pacote de encontros é conferido em `result.package` e `canvas.encounters`,
  incluindo o perfil canônico de raio20/altura32. As capturas população/patrulha
  são separadas, ambas em janela 1440×1000.
- Histórico confere o hash intermediário após undo e novamente após redo para
  população e patrulha. Workers verificam cancelamento de UI, invalidação da
  proposta no refresh sem exigir um código específico para o cancelamento
  esperado e `take()` stale de um snapshot imutável sem aplicar fonte.
- Captura verifica a visibilidade da janela de composição ancestral, do painel
  correspondente e das janelas reais em capturas separadas; shells ocupam toda
  a área raiz. Os diretórios temporários de Store recebem nonce por execução e
  são criados explicitamente pelo teste.
- A comparação de conflito registra path/hash/dirty/fonte no momento da falha,
  antes de reabrir a revisão externa; em seguida confere o novo byte hash aberto.
- Consulta de mapa confere `map_source_hash`, `map_package_hash`, bioma,
  `surfaces[].vertices_xyz` e `sockets[].position_xyz`, incluindo a rota AX de
  patrulha compartilhada.

## Diagnóstico nativo prévio e ajuste de fixture

A primeira execução nativa ficou em 24/25: somente
`real_patrol_controls_mode_wait_move_and_slot_assignment_match_ax` falhou.
Diagnóstico instrumentado preservou os mesmos 25 oráculos e mostrou chamadas,
rota, ordem, slots e modo corretos; o valor persistido foi 1.8, enquanto o teste
pedia 1.75 com `SpinBox` de passo 0.1. A fixture UI agora digita/confere 1.8. O
teste puro exige 1.75 em waypoint novo e edição fracionária de waypoint existente,
preservando a posição na ordem.

- SHA-256 do teste UI original: `DA98D5B251EA721BC49B5FAD614B89A3F7A2C55FA2F45D9F3FB848E9792BC5B9`.
- SHA-256 do manifesto de diagnóstico: `DCED7676ECA4B44432D47B2C9D705D75F8443C83419561C4FB1C149084EC87E6`.
- SHA-256 da cópia instrumentada: `DABA87A24ED22A3D3D4CA81CBD7EC73BF66B5F3B868AABEA0880E35824F480D0`.
- Diagnóstico e logs originais permanecem em `docs/map_editor/delivery/evidence/f9/author/encounter_authoring/native_diagnostic_01/`.

## Limite atual

Este registro descreve a cobertura pretendida; não constitui evidência de PASS,
validação semântica independente ou aprovação técnica de F9.
