# F9 — ordem de desenho coerente com o espaço

Correção Sol no contrato F9-01/02/11 e adendo de sombras26/10. Native shadows01
passou pisos planos, mas expôs objetos/sombras apagados pela altura média da
rampa. Barreira AABB era pintada no overlay4090, por cima de todos os sprites.
Capturas/falhas preservadas; não enfraquecer comparação por objeto/ator.

Conservar Node2D/MeshInstance2D, shader/material/fábrica de faces e projeção
existentes. Não introduzir renderer3D, iluminação global, depth buffer externo
ou física por pixel. O compositor ordena os drawables existentes a partir da
geometria real e do contato da sprite com o suporte. A ordem é apresentação,
nunca permissão de andar, subir, atacar ou enxergar.

Barreiras/volumes visíveis usam as próprias faces/AABBs no grupo de geometria,
com material existente; overlay fica para seleção/diagnóstico/interação.
Malha de terreno respeita regiões coplanares existentes e conserva todos os
samples de pintura/normais; não reduzir a máscara a quatro cantos de um piso.

Uma sprite apoiada numa face fica acima dela. Quando a superfície está acima
do pé em outra cota, ela participa da oclusão do andar inferior. Separação
espacial e retângulos projetados ordenam paredes/objetos na câmera isométrica;
empates usam chave estável. Não ordenar somente por altura média. Fonte, massa,
escala, pivô, assets e estado persistido permanecem iguais.

Ordenação compartilhada, cache verificável dos registros estáticos e atualização
de pares afetados por ator em movimento. Sem mutação parcial em erro/orçamento.
Ciclo/limite retorna diagnóstico explícito; não apagar item ou suporte para
forçar uma imagem. Contagens/custos não certificam FPS. Manter níveis positivos
até4000 e overlay4090; sombra derivada fica logo antes da própria sprite.

Provas: casos de ordem independentes (rampa/apoio, parede atrás e à frente,
ponte/ator inferior e superior, reorder e ciclo/entrada inválida); comparação
nativa por sombra/objeto/ator em Areia/Terra/rampa. Preservar os atributos de
mundo do shader, pintura interna, corpos, clique e navegação. Usar a mesma
autoridade nos consumidores do preview de jogo; esse fluxo completo continua11.
