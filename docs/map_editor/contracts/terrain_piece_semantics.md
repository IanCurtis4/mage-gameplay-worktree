# Peças/células, mapa e terreno — retificação humana

24/10/2026, posterior à aprovação inicial de D4. Registra a explicação explícita
do usuário neste chat e as quatro imagens anexadas, sem escolher implementação
nova ou iniciar outro pacote. Esta direção prevalece sobre a interpretação
anterior do F2 que confundiu peça com subdivisão geométrica pequena.

## Vocabulário e escala do produto

**Célula e peça são dois nomes para a mesma unidade de autoria/composição.**
Um mapa contém uma ou mais peças/células. Uma peça pode ser contígua e tão grande
quanto um mapa inteiro, ou pequena como uma sala. Formato, área e alturas variam;
não há grade uniforme de peças nem tamanho fixo de sala imposto por essa definição.
O conjunto atende ao tamanho idealizado do mapa final, geralmente grande.

Os quadrados da grade de altura, amostras, triângulos e polígonos de suporte são
detalhes internos de representação/compilação. Não são células/peças do produto.
Documentação que cite a API legada de geometria deve dizer **superfície de suporte**
ou **subdivisão técnica**, mantendo a distinção mesmo quando o identificador de
código existente contiver cell. Isso não exige renomear APIs neste registro.

Quantidade de peças e complexidade interna são escolhas de autoria. Um mapa
amplo pode usar uma única peça grande; um mapa labiríntico pode reunir várias
peças de tamanhos e alturas diferentes. Não impor a equivalência rígida
"mapa grande = muitas peças pequenas" nem tornar toda área aberta um mosaico
de módulos. Também não proibir uma peça internamente complexa.

## Terreno e objetos editáveis

O terreno é autorado como superfície contínua, com textura replicada e relevo
editável. A malha pode ter menor densidade que os objetos, mas deve ser suave
o suficiente para a leitura desejada; a referência humana rejeita a aparência
facetada grosseira comparada ao Star Fox original. Ragnarok Online e Age of
Mythology são referências de suficiência visual do terreno; Warcraft3/Age of
Mythology continuam referências de ferramenta e fluxo de autoria.

Construções, natureza, doodads e outros objetos terão a fidelidade visual
descrita pelo usuário, distinta da densidade da malha de terreno. Terreno,
elementos não interativos, objetos e pontos de conexão precisam ser editáveis;
a ferramenta não se limita a escolher um layout pronto de uma biblioteca.
Este registro não entrega catálogo, texturas ou modelos novos.

É proibido adotar como método de autoria do terreno o encaixe em sobreposição
de objetos poligonais pré-desenhados. Peças reutilizáveis representam áreas
autoradas de mapa, não esses polígonos. Triangulação gerada pelo compilador
continua sendo detalhe técnico de uma superfície, sem obrigar o autor a montar
triângulos/quads nem usá-los como módulos do mapa.

Sobreposição real entre pisos, ponte e passagem inferior continua necessária
quando autorada; não se confunde com sobrepor objetos de chão para montar o
terreno. Conexões e emendas entre peças devem produzir terreno coerente, com
passagem, altura e apresentação concordantes. A solução técnica será reconciliada
no contrato de arquitetura antes dos consumidores dependentes.

## Referências fornecidas pelo usuário

| Imagem | Leitura de intenção de autoria |
|---|---|
| [1 — Torghast](../delivery/evidence/m2/product_references/01_torghast.png) | Coleção de peças de formas, dimensões e layouts variados para compor dungeons |
| [2 — prt_fild08](../delivery/evidence/m2/product_references/02_prt_fild08.png) | Exemplo de mapa amplo que pode ser concebido como uma única peça grande |
| [3 — castelo](../delivery/evidence/m2/product_references/03_castle.png) | Exemplo que pode ser concebido como conjunto de blocos distintos no mesmo mapa |
| [4 — igreja](../delivery/evidence/m2/product_references/04_church.png) | Outro exemplo de composição de áreas/blocos de tamanhos e alturas variados |

São referências conceituais fornecidas pelo usuário. Não se afirma ter verificado
o pipeline real desses jogos, os IDs exatos dos mapas ou seus formatos proprietários.
Não se copiam layouts/assets para produção. Os originais anexados foram preservados
com hashes no [manifesto](../delivery/evidence/m2/product_references/manifest.json).

## Consequência para F2, D2 e D4

Os testes do candidato `69837145b7857bb630bcfecef0747bf525deeec8` continuam
evidência válida das operações e da geometria técnica que executaram. Não provam
terreno texturizado, objetos de alta fidelidade, peça do tamanho de um mapa ou
adequação da fundação a essa direção de produto.

O teto256 implementado conta superfícies de suporte geradas (e há tetos próprios
de grade/prévia), não256 peças/células do mapa. A aprovação inicial de D4 fica
preservada como aceite de limite de uma prova pequena. A retificação posterior
impede promovê-lo a definição de tamanho máximo das peças do produto. O limite
permanece no código atual; esta alteração documental não anuncia sua remoção.

D2 autorizou a projeção isométrica atual para a prova F2. Isso não escolhe como
representação final um conjunto de polígonos planos coloridos, nem fecha a
integração entre terreno texturizado, objetos detalhados e a apresentação do jogo.
Da mesma forma, o gate histórico low-poly não pode reduzir a fidelidade pedida
agora por inferência; sua reconciliação é assunto de arquitetura/direção de arte.

Estado: **PROVA TÉCNICA VALIDADA / REALINHAMENTO DA FUNDAÇÃO PENDENTE**.
Antes de apoiar consumidores nessa interpretação, o contrato de arquitetura deve
reconciliar escala de peça versus resolução interna, terreno texturizado e sua
apresentação, autoria de conexões e coerência geométrica das emendas. Não basta
renomear células ou aumentar256 sem tratar essas fronteiras. A escolha técnica
fica com o papel de arquitetura previsto em WORKFLOW; este registro já conserva
a decisão humana de produto, sem pedir que o usuário a aprove novamente.

Não inicia F3 ou outro marco, conversão de renderer, produção de assets ou
publicação. Registro e cópia de referências apenas: conferidos links, precedência,
hashes e diff. Código e evidências históricas preservados; suíte de gameplay
não repetida nesta rodada documental.
