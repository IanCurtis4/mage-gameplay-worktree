# F9 — terreno misto e massa exposta

Engenharia Sol26/10 no escopo F9-02/03/11, após materiais
`ef88996651bc7783e51dc90cb63996de0b7399b1`, HEAD documental
`db0557fdada60b57ae420ff2233393748e14c72b`. Branch/checkout no dispatch F9;
propriedade nominal em f9_ownership.json. Implementa o contrato vigente
[massa/relevo](f9_terrain_solids.md), sem nova escolha de produto, renderer ou
alteração do teto caminhável45°. Esta nota não é prova de implementação.

## Representação e versões

Fonte v1 conserva alturas e IDs autorais. Terreno compilado passa a formato5,
`map_terrain_v5`; composição a formato4, `map_composition_v4`. Pacotes antigos
mantêm revisão imutável e são recusados explicitamente pelo receptor novo se
não houver fonte para recompilar. Não reescrever expedição realizada/cache antigo.
Assembler `f0_convex_parts_v2` já transporta massas com support_surface_id vazio;
nenhuma nova primitiva ou revisão de manifesto de runtime é necessária.

Toda face gerada permanece na geometria e apresentação, inclusive acima de45°.
`part.surfaces` contém somente suportes caminháveis. `part.solid_prisms` contém
as massas de todas as faces. A massa de face não caminhável usa ID de suporte
vazio, já validado por WorldGeometry; nunca criar suporte virtual para ela.
Peça totalmente íngreme é recusada. Platô plano isolado continua sendo suporte
e produz diagnóstico de conectividade até receber rampa/ponte; não ocultá-lo.

`visuals` descreve faces, com identidade `face_id`, `source_id`, `vertices`,
`headroom`, `walkable`, `special`, pesos de material por vértice e limite inferior
`bottom_y` ou `thickness_y`. `surface_id` é face_id quando caminhável e vazio
caso contrário. O receptor revalida o declive, plano, massa e vínculo geométrico;
hash recalculado não legitima flag/referência adulterada.

## Topologia e fechamento

Operador puro compartilhado pelo produtor e receptor, sem mutação da fonte:

- walking/walking: endpoints e conexão física interna;
- walking/cliff: fronteira fechada pela massa de terreno, sem conexão;
- cliff/cliff: sem conexão caminhável nem parede interna duplicada;
- borda externa caminhável: fechamento por perfil do bioma, salvo abertura;
- borda externa de penhasco: fechamento pela massa real de terreno.

Boundary contém span_id, face_id, surface_id opcional, source_id, a,b,outward,
kind, closure (`profile`/`terrain`), adjacent_face_id opcional e openings.
Portas autorais só selecionam bordas caminháveis externas com closure=profile.
Composição preserva closure e não acrescenta parede de bioma sobre fechamento
já explicado pela massa. Abertura80/N:M12 mantém o contrato próprio inalterado.

Recortes de aresta usam projeção escalar e orçamento de arredondamento existente;
reutilizam vértices da fonte. Ordenação por identidade e cortes canônicos, sem
fundir gaps reais ou aumentar EPS. Cancelamento e falha não publicam cauda parcial.

## Pele visível do volume

`exposed_sides` contém side_id, face_id, span_id, vertices, outward e material_id.
Lados externos mostram o intervalo real entre topo e base da massa. Duas faces
com topo/base iguais não têm parede interna. Se o topo coincide mas bases diferem
(terreno junto de ponte), somente a faixa inferior não sobreposta fica exposta.
Se as bases lineares cruzam, dividir nesse ponto e atribuir cada faixa ao dono
correto; sem lacuna nem dupla pele. Área/altura/cortes têm oráculos independentes.

Mesma fábrica de material transporta posição/normal mundiais e pesos para topo,
superfície especial e lado, transformados uma vez em composição. Textura de lado
inclui altura. Pele visual não decide colisão nem reduz o volume físico. Ordem
visual positiva do checkpoint de materiais permanece, sem alterar WorldPoint.

## Orçamento e prova

Manter1024 faces geradas por peça e1024 suportes como limites distintos,2048
massas por estágio já existentes e4096 peles por peça. Contabilizar face antes
de filtrar suporte: o sentinela parcial >1024 de Partition nunca vira sucesso
por descartar penhascos. Pacote continua limitado a4MiB. Excesso é falha inteira
explícita, não definição do tamanho do produto nem licença para truncamento.

Provas: volume/side-area analíticos, bases cruzadas, piso/ponte, rampa, face
íngreme real, raios/LoS/corpo, fronteira terreno/perfil, pacote adulterado com hash
novo, reordenação, rotação, fonte/undo/roundtrip e transporte pelo assembler.
Capturas nativas mostram a face/lado real, distinguindo fundo vazio de material.
Regressão por impacto, supervisão Luna e consolidação Sol; aceite de produto
continua humano. Biomas, área final e desempenho permanecem requisitos próprios.
