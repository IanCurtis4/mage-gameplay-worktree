# Playtest — pega e aparência dos equipamentos

Correção visual solicitada em 13/10/2026 sobre a Sentinela: arco lateral sem flecha permanente, armas girando pela empunhadura e acompanhando a mão nas poses preservadas. Sete SVGs refinados; corpo/atlas, dano, loot e save mantidos. Prévia usa nearest como o mapa.

Aplicado e verificado: runtime `eb3987e60d6251c0a625aa6284101da8236288da`, fonte codex/e06-inventory e destino codex/playtest. [Recibo](e06_equipment_alignment_delivery.json). Validação Sol e supervisão automatizada Luna concluídas. Abra o projeto habitual C:/Users/João Pedro/Documents/ChatGPT/RagRPG/project.godot; pare a partida anterior, aceite o reload do Godot e use F5.

1. Na Sentinela, abra Equipamentos com o arco inicial. Veja se a mão envolve a pega, o arco fica lateral ao rosto e não há flecha em repouso.
2. No mapa, caminhe nos dois sentidos e para cima/baixo. O item deve acompanhar a mão e inverter junto com o corpo.
3. Ataque: espada/machado acompanham a mão erguida e o golpe; cajado acompanha o gesto; arco exibe flecha apenas durante a ação. Observe também a reação a dano, sem corda sobre o rosto, e a queda/repouso do item em tamanho constante.
4. Confira espada e escudo, cajado, foco prismático na secundária e contas no pulso nas combinações legais que possuir. Trocar/desequipar deve continuar respeitando as regras e mostrar mãos vazias quando não há peça.

Aceite de produto e merge em master continuam pendentes. As poses corporais originais foram preservadas: a leitura completa de puxar a corda é limitada pelo atlas atual. Evidência estática e testes não substituem sua avaliação do movimento e do estilo durante o jogo.
