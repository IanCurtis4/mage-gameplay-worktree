# F9 — três props para ambientes

Sol26/10, depois da fundação7073d38 no mesmo checkout/branch do dispatch.
Parte do escopo autorizado F9-01/03/11, sem produção de outro kit por inferência.
Donos nominais em f9_ownership.json antes da integração. Catálogo passa a revisão
agregada2; definições existentes oak_tree/moss_boulder/woodland_shrub continuam
exatamente iguais, incluindo revisão1, pivô, escala, física, origem e PNGs.

| Definição nova/rev1 | Nome | Pivô UV | Altura visual | Corpo XYZ/tamanho | Raio de assentamento | Declive |
|---|---|---|---:|---|---:|---:|
| desert_cactus | Cacto adulto | .507/.928 |150|−12,0,−12 /24,96,24|18|20°|
| broken_pillar | Pilar quebrado | .5/.806 |160|−25,0,−25 /50,96,50|36|10°|
| sandstone_boulder | Rocha de arenito | .5/.645 |110|−36,0,−32 /72,36,64|49|35°|

Rotação simétrica segue API atual de90°. Os corpos acima são envelopes explícitos,
com ataque/LoS/corpo habilitados e oclusão de câmera; pixel de folha/espinho não
cria collider. Assentamento, suporte, caminho, cabeça/folga, proteções e transações
continuam nas autoridades atuais. Categoria structures aparece como Estruturas.
Biomas editoriais: cacto deserto, pilar ruína/floresta, arenito deserto/planície.
Isso não altera elegibilidade ou recompensas das espécies nem cria spawn.

Os três PNGs/proveniência foram registrados em270ff3a, permanecem byte a byte.
A inspeção de RGB sugeriu névoa no arenito; a medição confirmou alpha0 nos pixels
externos. Tentativa de extração b9f21c37 foi descartada e não entrou no projeto.
Pivôs têm alpha249/253/253; cantos dos três assets são alpha0. Nenhum script
edita raster. Testes nativos ainda precisam comprovar escala/leitura/apoio em
piso claro/escuro e tratamento de oclusão. Não declarar aprovação por corners.

PropCatalog expõe a revisão agregada; dependência prop_catalog_json acompanha
essa revisão e o hash real. Só as imagens/imports das definições usadas entram
no pacote. A seleção de três props continua tendo16 arquivos (9 materiais,
catálogo1, PNG/imports6), sem duplicatas. Fontes existentes mantêm IDs e definições;
pacotes antigos cujo catálogo não coincide são recusados sem apagar arquivos.
A compatibilidade/export completo continua requisito próprio de F9-09/11.

Provas: snapshot independente das três definições antigas, hashes/origem/alpha,
colocar/assentar, corpo/raio, ator desviando, rotação, fonte/roundtrip/pacote,
revisão e dependências. No editor: miniaturas/busca em pt-BR, três sprites
reais, mipmaps, escala, alpha-pick, oclusão, fontes em piso claro/escuro e undo.
Regressão proporcional por impacto e supervisão Luna após congelamento.
Este contrato não entrega quatro perfis de borda, terreno orgânico final,
transporte limpo ou a área final de aceite. F9 continua em execução.
