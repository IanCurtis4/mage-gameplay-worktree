# E04 — correção do menu após playtest

O playtest encontrou as habilidades do Arqueiro rotuladas como "Skill indisponível".
O catálogo de progressão já publicava oito ativas e três passivas funcionais,
mas CharacterMenu mantinha um mapa de nomes anterior ao Arqueiro. As compras
eram válidas; o rótulo não representava o estado de disponibilidade.

O menu agora usa display_name de ClassCatalog na árvore, pré-requisitos,
seletores, resumo e confirmação. Disponibilidade de compra continua vindo da
fachada, com requisitos, pontos e limite de rank. Não há mudança de IDs,
compras, saves ou habilidades. O aviso antigo de efeitos por rank indisponíveis
foi removido e substituído pela orientação de equipar após aprender.

O fechamento integrado passa a verificar os nomes das onze habilidades em R0,
compra os ranks pelo menu e confere os nomes nos seletores de ativas/passivas.
Isso cobre a lacuna da revisão anterior, cujos testes conferiam IDs e execução,
mas não os nomes apresentados ao jogador. O teste E02 foi atualizado para os
nomes canônicos e a orientação vigente.

Escopo do menu neste pacote: mostrar a biblioteca implementada, aprender e
equipar habilidades identificáveis, respeitando a progressão existente.
Comparação detalhada dos efeitos de rank e organização visual da árvore
continuam melhorias de apresentação futuras, sem bloquear esta correção.

Validação: tools/verify.ps1 passou importação, 46 suítes / 1.969 checks e smoke
com Godot 4.7.2. O cenário integrado passou 82 checks, incluindo os nomes visíveis.
Aceite do candidato corrigido depende do playtest;
o feedback positivo sobre combate/progressão não encerra a pendência do menu.
