# Receitas AX — conteúdo do Bosque

Estado: receitas executadas após liberação técnica; resultado e ajustes registrados abaixo. `clearing_content_actions.json`: 31 ações, 24 props, contexto de floresta, área da clareira e entrada `woods_entry`. `overpass_content_actions.json`: 30 ações, 23 props, contexto de floresta e áreas oeste/santuário. Não há espécies, reservas, boss ou quest inventados. Abrir a fonte existente, usar a janela real `piece/open_objects`, compilar antes do save e deixar Store conferir conflito/backup. Nenhuma escrita de fonte manual.

As posições seguem o desenho F9: carvalho raio 26/inclinação máxima 20°, arbusto decorativo raio 4/45°, rocha raio 38/35°, pilar raio 36/10°; rotações omitidas usam 0, permitido pelos quatro catálogos. São alvos de autoria, não garantia de assentamento, corredor ou acesso: validar apoios, objetos, 160 de corredor efetivo e corpos na compilação/navegação, e corrigir apenas por AX se houver diagnóstico. Os IDs são explícitos e exclusivos por peça. Áreas são retângulos sobre as respectivas camadas, sem proteção do pincel ou reserva implícita.

Fontes lidas na preparação: clareira SHA256 `65a26754c437695d7e7d60e93980c187371fddeec4fb71f78323104dbb55ced5`, passagem `d0071096addfefcefad1f1df849c3977064a741b4ed1446ffaf50a3f25a95d7e`; conferir estado novamente antes da execução. A futura execução deve usar `--path C:/Users/João Pedro/Documents/ChatGPT/RagRPG/.tools/map-editor-m5/.godot/verification/e07_f1/fixture_project`, não o checkout. A extensão de transporte `screen=objects` e os comandos desta fatia ainda estão em implementação; não presumir disponibilidade nem semântica final antes dos testes. Falha de ação encerra o lote, sem pressupor atomicidade total do lote. Composição, população, patrulha, interação e jogabilidade continuam pendentes; nenhuma execução Godot ou suíte foi feita durante a preparação inicial.

## Execução de conteúdo — concluída em AX

Em `52798508efb7f274fdc3a42959c7af9b2da31c1b`, fixture e engine indicados nos `*_execution.json`: clareira 31/31, passagem 30/30 na receita `overpass_content_actions_retry2.json`. Ambos compilaram antes do save, com exit 0 e logs finais sem SCRIPT ERROR/Parse Error/ERROR. Reabertura de cada fonte em novo processo reproduziu os hashes de fonte, compilação e bytes em disco; os registros contêm argv, ambiente, resultados e capturas nativas.

| Peça | Bytes | SHA256 arquivo | Hash semântico | Hash compilado |
|---|---:|---|---|---|
| Clareira | 21393 | `150509026fddc323396d20fdd015fee47c1dacb47685c1f326842b77260484ab` | `e2172d1928ad5f83188fdba6e89b445bdf37e207af10f4e639a6b1ba44f8ad4f` | `0d4756a1176e63776a2bf1cf2014a54855ac71b63ed3ef0ec0ea198a8dc8f597` |
| Passagem | 14605 | `1501a98d8e201ce10017c0f410d137da5bad0c21fbd97039c9e52a9d693341c9` | `1cae62332c2fbb490982dc6cbcda7d13f4f12a39f77303b6e4056c7382255fb4` | `34a235bcd4f410059b945a3ae90bfb2773e45c57d313fcc63bcb028b9178718d` |

A primeira tentativa B parou na ação 22 por ID duplicado de pilar; a segunda na ação 25 por ID duplicado de arbusto. A fonte em disco permaneceu intacta nas duas; receitas, resultados e logs foram preservados. A terceira renomeou apenas IDs duplicados e concluiu; `Counter` confirmou unicidade global de 24/23 props, 1/2 áreas e 1/0 sockets. Nenhuma posição foi ajustada. Os arquivos foram salvos pelo Store com hash anterior esperado e backup; sem alteração manual de fonte.

O mapa consumidor deve ter bioma `forest`, já que ambas as peças agora restringem o contexto a floresta. Persistem composição, população, patrulha, interação, avaliação visual e prova de travessia dos novos obstáculos com raio 20/altura 32; não há certificação de gameplay ou FPS nesta entrega.
