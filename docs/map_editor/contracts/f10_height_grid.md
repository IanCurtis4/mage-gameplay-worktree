# F10 — superfície de grade de altura (Q1)

2/11/2026. Contrato de Sol (Claude Opus, papel Astra para a arquitetura). Decisão
humana de 2/11, depois da medida do Q1: "Grade de altura" (opções e números em
[inserções](f10_insertions.md) e [estudo de escala](f10_field_scale_study.md)).

## Problema medido

- Hoje o terreno é um conjunto de superfícies planas convexas. A partição junta
  quadrados coplanares em retângulos e divide cada quadrado não plano em dois
  triângulos.
- Cada peça e cada estágio aceitam até 1.024 superfícies (`MAX_SUPPORTS`,
  `MAX_FACES` e o limite de estágio do `map_compiler.gd`).
- Num campo de ~10.000 unidades com espaçamento de 64 (161×161 amostras), um
  protótipo da mesma partição deu:
  - relevo orgânico: 7.004 retângulos e 16.612 triângulos;
  - terraços com degraus num só nível de grade: 1.039 retângulos e 2.068
    triângulos;
  - platôs planos com paredões verticais: 570–722 retângulos.
- A clareira ampliada para 5.120 unidades já é recusada com
  `terrain_limit_exceeded`.

## Decisão

Uma **superfície de grade de altura** é um trecho retangular de uma camada de
terreno, representado como uma superfície só:

- **Apoio:** exato pela mesma triangulação do desenho. Cada quadrado é dividido
  pela diagonal (x,z)→(x+1,z+1), nos triângulos (a,b,c) e (a,c,d), como em
  `terrain_compiler.gd` e `terrain_material.gd`.
- **Andabilidade:** por triângulo, com a regra de `Topology.is_walkable`
  (|normal.y| ≥ √½). Triângulos íngremes são buracos da superfície, nunca chão.
- **Corpo:** o disco do perfil inteiro sobre triângulos andáveis.
- **Navegação interna:** A* sobre a adjacência dos triângulos andáveis, depois
  funil (puxar o barbante) pelas arestas atravessadas, com os portais encolhidos
  pelo raio e a cápsula conferida no fim.

  A navegação entre superfícies continua pelo grafo de portais atual. Nas
  bordas do trecho, os portais são os vãos andáveis contínuos.

O relevo orgânico continua valendo; a escala de campo cabe em ~120 superfícies
(trechos de 16×16 quadrados, 1.024 unidades). A edição agêntica recompila só os
trechos tocados.

## Compatibilidade

- O modo é declarado na camada: `surface_mode` igual a `"exact_planes"` (padrão,
  comportamento de F9) ou `"height_grid"`. Não há limiar escondido por tamanho.
- Peças de F9, o Bosque e os pacotes publicados continuam iguais: nada é
  recompilado em silêncio.
- Superfícies poligonais (pontes, superfícies especiais, peças pequenas) convivem
  com as de grade no mesmo estágio.

## Passos

| Passo | Conteúdo | Prova |
| --- | --- | --- |
| H1 | Núcleo puro `scripts/core/expedition/spatial/world_height_grid.gd`: validação, triângulo de um ponto, apoio exato, andabilidade, disco do corpo, cápsula livre, caminho com funil, componentes andáveis, vãos nas bordas | `HeightGrid` (headless) |
| H2 | `WorldGeometry`: superfície de grade nos índices de apoio, consulta de posição, ocupantes, varredura de chão, linha de chão das skills, linha de visão | regressões E07 de apoio e skills |
| H3 | Navegação: aresta interna por caminho de grade, portais de borda, certificação por componente, rotas em segundo plano | navegação F9 e novo campo sintético |
| H4 | Compilador: `surface_mode` no esquema; trechos de grade no `terrain_compiler.gd` e no `map_compiler.gd`; índice espacial para sobreposição; tetos contados em superfícies reais | runners M1–M8 e Bosque idêntico |
| H5 | Desenho no jogo e no editor por trecho, com recorte pela câmera | nativos e medida de quadro |
| H6 | Campo sintético de ~10.000 u de ponta a ponta: compilar, certificar, navegar, desenhar, diário | orçamento medido |

Estado: H1–H6 entregues (checkpoints 1–6, [registro](../delivery/f10.md)).

Nenhum guard, teto ou quota é reduzido. Os tetos que contam superfícies passam a
contar superfícies reais (um trecho conta como uma), com o custo medido.

## H6 — orçamento medido

Campo sintético de 10.240 u (161×161 amostras, 100 trechos), etapa `GridField`;
números e política em [checkpoint6](../delivery/f10.md).

- **Compilar e certificar:** peça em 2,3 s; mapa em 21,9 s, com 13,2 s de
  navegação. Antes das otimizações, 65 s.
- **Navegar:** rota que cruza a crista e sobe a rampa em 5,3 s fria e 1,5 s
  quente. Em segundo plano, o quadro não espera (pump de 0,06 ms).
- **Desenhar:** quadro no vsync, com 860 chamadas de desenho para o campo
  inteiro.
- **Popular:** 55 monstros com plano em 73 s e compilação em 52 s (pendência:
  reaproveitar o certificado).
- **Sessão:** instantâneo de 1,05 MB, abaixo do limite de 4 MiB.
- **População depois do checkpoint7:** os lotes reaproveitam um fechamento de
  base por geometria, corpo e raiz. O mesmo campo popula em 47 s (plano 37 s,
  compilação 10 s) e a campanha começa em 2,4 s.

- **Recompilar depois de um traço (checkpoint8):** peça em 0,63 s e mapa em 8,2 s,
  reconstruindo só o trecho e o reticulado tocados; a certificação segue global.

Política de certificação em campo, só para estágios com trechos:

- costuras entre trechos usam os deslocamentos da abertura mais um a cada 256 u;
- com mais de 64 alvos, os pares diretos só são tentados para quem ficou sem
  alcance;
- aresta reta bloqueada por íngreme dentro do trecho é recusada sem os
  predicados exatos.

Nenhum guard, teto ou quota foi reduzido.
