# F9 — sombras de contato e profundidade visual

Adendo humano26/10/2026 neste chat: acrescentar uma sombra simples, circular
ou coerente com a sprite, e avaliar possibilidades da engine para imersão.
Integra F9-01/02/11/12; não substitui a conclusão do editor já autorizada.

## Estado conferido e direção de implementação

CombatActor já desenha dois círculos achatados sob as solas, raios15/11 e
alpha0.14/0.26. CharacterAnimation mede o último pixel opaco por frame para
assentar o sprite. ObjectView desenha os props com pivô/escala do catálogo,
sem sombra de contato compartilhada. MapCanvas/PopulationCanvas/PatrolCanvas
ainda têm atores técnicos; isso não demonstra a apresentação de jogo exigida11.

Implementar uma sombra de contato suave como base comum de apresentação:
personagens/inimigos e props, ancorada no contato real com o chão. Tamanho
coerente com pé/base do objeto; transparência discreta; camada abaixo da sprite,
acima do piso. Reutilizar pivô, projeção e geometria canônicos. Em rampa ou
ponte, acompanhar a superfície correta e limitar a sombra ao suporte/massa
que a recebe; não projetar no piso inferior por mero overlapXZ. Sombra não
ganha colisão, ataque, LoS ou estado persistido e não altera definição imutável.
Ocultação/descarte da sprite também remove a apresentação derivada.

Reutilizar CanvasItem/mesh/projeção existentes, sem renderer novo ou kit raster.
Conferir piso claro/escuro, escala real, sprite espelhada, encosta e borda,
camadas sobrepostas, atores em movimento e vegetação. Prova nativa com imagem
e comparação ligada/desligada, mais invariantes geométricos relevantes; medir
custo representativo sem prometer FPS a partir da contagem de primitivas.

## Possibilidades avaliadas

1. Contato suave procedural: círculo/elipse ou mancha curta adaptada à base,
   adequado ao pipeline atual. É o primeiro consumidor autorizado pelo adendo.
2. Silhueta projetada a partir do alpha: pode dar direção a árvores/pilares,
   mas precisa conservar pivô/animação e tratar receptor/oclusão entre andares.
   É opção a comparar; ainda não certificada ou ativada globalmente.
3. Luzes pontuais e ambiente por cena: tochas/portais podem usar PointLight2D
   ou brilho aditivo. Materiais atuais usam canvas unshaded; uma mudança ampla
   de iluminação requer prova de leitura e custo no pipeline completo.
4. Direcional/LightOccluder2D e normal maps: disponíveis na engine, porém a
   sombra direcional nativa é infinita e sua altura não representa os andares
   canônicos do RPG. Não ativar sombras globais sem resolver essa discrepância.

Referências primárias conferidas26/10:
[luzes e sombras2D](https://docs.godotengine.org/en/stable/tutorials/2d/2d_lights_and_shadows.html)
e [CanvasItem/desenho](https://docs.godotengine.org/en/stable/classes/class_canvasitem.html).
Pesquisa não constitui evidência de integração ou desempenho.

Propriedade nominal ampliada para GroundShadow/CombatActor, testes e extração
pura da projeção compartilhada (GeometryView conserva suas assinaturas e
delega a mesma fórmula, evitando ciclo de classes). Consumidores aguardam
a liberação do lote congelado. Nenhuma alteração de ator durante um lote Luna congelado. Sem novo
épico, plugin, campanha, mecânica de água, mudança de save ou publicação.


Outras possibilidades levantadas pelo pedido de imersão: ondulação/brilho
suave no shader da água; pequena oscilação de copa com base fixa; partículas
ambientais limitadas; som por proximidade. São opções avaliadas, ainda sem
ativação ou kit novo de áudio/arte. Água/folhagem visuais conservam a geometria
canônica; som2D não infere a altura de andares. Comparar leitura/custo no renderer
Compatibility utilizado antes de incorporar cada recurso ao produto.
Referências: [partículas2D](https://docs.godotengine.org/en/stable/tutorials/2d/particle_systems_2d.html),
[áudio posicional2D](https://docs.godotengine.org/en/stable/classes/class_audiostreamplayer2d.html)
e [gradiente radial nativo](https://docs.godotengine.org/en/stable/classes/class_gradienttexture2d.html).
