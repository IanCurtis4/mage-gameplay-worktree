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


## F9-10 — seleção espacial de pares

Delta sequencial posterior ao checkpoint04a7dfc. Conservar _before, geometria,
ordenação topológica e desempate. Grade da projeção com buckets128, retângulos
fechados inclusive coordenadas negativas e bordas exatas. Até256 buckets/item;
retângulo maior ou distante usa conjunto de overflow limitado pelo orçamento
existente de8192 itens/8388608 pares. Não impor pré-limite quadrático a itens
esparsos que nunca se sobrepõem. Cacheversion2 é derivado, sem formato de save.

Registros alterados atualizam somente seus buckets, com cópia dos buckets
tocados; candidatos atuais incluem vizinhos de restrições anteriores, removendo
arestas obsoletas após separação. Erro/ciclo/orçamento não publica cache parcial.
Verificar contra grafo exaustivo independente da seleção espacial, incluindo
entrada/saída de vizinho, várias mudanças, reorder, limite, overflow e8mil itens
esparsos. Medir frio/quente/movimento com amostras repetidas em72/576/2176 itens;
isolar CPU e não inferir FPS ou latência de toda a interface. Trabalho de UI
assíncrona/cancelamento e busca densa canônica continua obrigatório em F9-10.

Se as restrições de pares e a ordem total de prioridade permanecem iguais,
reutilizar o resultado topológico. Verificar os vizinhos de prioridade de cada
registro alterado com coordenadas novas de todos os registros; inversão exige
reconstrução. Mesmo resultado com bindings iguais dispensa mover todos os
nodes/Z novamente. Geometria/posição novas ainda atualizam snapshots e índice.
Oráculos cobrem inversões múltiplas e restrições alteradas com mesmo resultado.
