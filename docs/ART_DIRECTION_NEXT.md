# Direção visual — piloto iniciado e próximos passos

Pedido: fantasia coreana de RPGs de 2000–2006, personagens 2D expressivos, chão com
profundidade, texturas simples/pixeladas, cores ricas e transições entre materiais.
Em 12/09/2026, o usuário autorizou iniciar os assets. O primeiro piloto está em
`docs/PLAYTEST_ART_PILOT.md`: três poses, três materiais e integração na arena 2D.
Os passos de animação, comparação adicional de resoluções e prova de chão 3D abaixo
continuam propostas futuras, a ajustar após o aceite visual deste piloto.

## Resolução e linguagem

Recomendo começar por uma célula de **64×64**, com personagem de aproximadamente
40–52 px de altura e pivô nos pés. Isso deixa espaço para cabelo, equipamentos e
silhueta sem tornar a animação cara demais. Comparar a mesma pose em 48×48, 64×64
e 80×80 antes de fixar. A resolução da célula não obriga a preencher todo seu espaço.

| Opção | Benefício | Compromisso |
|---|---|---|
| 48×48 | Menos trabalho e leitura simples | Pouco espaço para rosto/armadura |
| 64×64 — ponto inicial | Silhueta, rosto e equipamento distinguíveis | Exige escolher detalhes e limpar pixels |
| 80×80 | Mais personalidade e roupas | Mais desenho por frame e custo de consistência |

Armas compridas e efeitos podem usar camadas separadas ou células 96×96, mantendo
o mesmo tamanho aparente do corpo e pivô. Chefes podem ter atlas maiores. Não forçar
todo conteúdo em 64×64 nem redimensionar corpos por causa de uma animação de espada.

Proporções: cabeça expressiva, mãos/arma legíveis, volumes pintados em blocos de
cor, contorno seletivo em tons escuros coloridos. Paleta por material com 4–6 valores,
luz quente e sombras frias; começar com 24–40 cores úteis por personagem, permitindo
cores extras quando melhorarem a leitura. Estes são limites de produção sugeridos,
não requisitos técnicos nem reprodução de sprites existentes.

## Chão e profundidade

A arena atual é **2D com profundidade simulada por desenho**. Para atender ao chão
3D real, proponho um protótipo separado com malha simples, câmera ortográfica fixa
e sprites orientados para a câmera. Godot oferece Sprite3D/AnimatedSprite3D e
controle de escala do pixel, billboard e filtragem. [SpriteBase3D](https://docs.godotengine.org/en/stable/classes/class_spritebase3d.html)

A projeção ortográfica mantém a escala aparente com a distância; comparar inclinação
30–35° antes de escolher. Converter mouse para o plano do chão e manter uma única
coordenada lógica para dano, movimento, indicadores e pés. Não projetar duas vezes.
A câmera possui suporte a projeção ortográfica. [Camera3D](https://docs.godotengine.org/en/stable/classes/class_camera3d.html)

Texturas iniciais: módulos de 64×64 e 128×128, mesma densidade aparente, 3–4 materiais
(grama, terra, pedra e musgo). Criar bordas de transição, cantos internos/externos,
manchas e 3 variações por superfície para quebrar repetição. Mistura por máscaras
ou cores de vértice em shader simples, com bordas irregulares e variação de cor;
escolher após comparar a cena com tiles de transição. Paleta compartilhada evita
que uma textura pareça colada sobre a outra. Luz difusa simples, sombra de contato
curta e volumes baixos bastam para a primeira prova.

Testar nearest nos personagens e filtragem/mipmaps no terreno em movimento; decidir
por comparação, para preservar detalhe sem cintilação. Anti-aliasing leve deve tratar
principalmente bordas de geometria, sem borrar a imagem inteira. Comparar desligado
e MSAA 2×/4× na máquina do usuário; MSAA e filtragem resolvem problemas distintos.
Não presumir que AA de geometria resolve transparência de sprites ou texturas.
[Anti-aliasing 3D](https://docs.godotengine.org/en/stable/tutorials/3d/3d_antialiasing.html)

## Sequência de trabalho e aceite

1. **Prova de estilo estática:** mesmo Espadachim em três resoluções, arqueiro em uma,
   três amostras de piso e uma composição pequena. Aceitar proporção, paleta e escala.
2. **Prova técnica 2D/3D:** uma sala com chão 3D, um sprite, obstáculo e mira no chão.
   Validar oclusão, sombras, câmera, seleção e correspondência da mira com o combate.
   Registrar custo da migração antes de alterar a arena jogável.
3. **Uma animação completa:** começar por cinco direções desenhadas com espelhamento
   quando aceitável para cobrir oito vistas; armas assimétricas exigem revisão.
   Piloto: idle 4 frames, caminhada 6, auto 5, corte 6, investida 4, dano 2, morte 6.
   Aprovar timing e contato dos pés antes de multiplicar inimigos/classes.
4. **Um kit de ambiente:** os materiais/transições definidos, parede baixa, pedra,
   vegetação e objeto interativo. Montar a sala com leitura boa das áreas de combate.
5. **Integração incremental:** reaproveitar regras centrais; trocar apresentação,
   projeção do mouse e navegação apenas com testes equivalentes. Playtest antes do
   merge. Só então ampliar sprites, animações e tilesets do MVP.

Cada passo produz arquivos versionados, registro de parâmetros e um candidato
revisável. Não encomendar catálogo inteiro antes de aceitar os pilotos. Imagens
geradas podem auxiliar conceito; sprites finais precisam de limpeza, pivô consistente
e continuidade entre frames. Nenhum asset proprietário de Ragnarok será incorporado.

Aceite visual: corpo/arma claros no tamanho final, oito direções coerentes, ausência
de saltos do pivô, terreno sem emendas evidentes/cintilação, áreas de skill visíveis
em pisos claros e escuros, cobertura correta por obstáculos e 60 FPS a medir.
