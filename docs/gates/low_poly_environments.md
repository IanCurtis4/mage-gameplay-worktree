# Gate futuro — ambientação 3D low-poly

Solicitado em 18/10/2026. Direção de arte aprovada para planejamento; implementação
e produção de assets aguardam pacote autorizado. Não inicia E07/E08 ou migração
integral do jogo para 3D. Fonte: [direção de produto](../PRODUCT_DIRECTION.md).

## Experiência desejada

Árvores, arbustos, monumentos, edificações e outros elementos tridimensionais
de baixa poligonização, inspirados na linguagem visual do Rag, com autoria
própria. Mapas têm lugares reconhecíveis, não somente textura e paredes.
Inimigos memoráveis ocupam lugares memoráveis compatíveis com seu tema, como
santuários e grutas. Quando presentes, também precisam morrer para abrir o
portal de avanço. Acesso à gruta não pode depender dessa mesma limpeza.

## Decisões antes da implementação

- Integração do cenário 3D com atores/câmera/apresentação atuais; avaliar solução
  híbrida e impacto sem assumir substituição de todo o renderer ou dos sprites.
- Escala, câmera, paleta, materiais, iluminação e leitura isométrica. Definir
  guia de autoria e orçamento medido, sem fixar contagem de polígonos arbitrária.
- Geometria coerente de chão/altura, colisão, navegação, alcance, LoS e seleção;
  oclusão visual do jogador versus bloqueio real de ataques são coisas distintas.
- Partes com pontos temáticos de encontro, regras de encaixe e áreas de acesso.
  Ausência de local compatível deve ter solução explícita na geração, nunca
  inimigo obrigatório inacessível ou spawn temático substituído por chão aleatório.
- Ciclo de importação/exportação, autoria/licenças e orçamento de simulação/render.

## Critério de saída

Arquitetura e guia documentados; amostra representativa com vegetação/construção
e encontro temático navegável, altura/LoS coerentes, jogador legível e desempenho
medido quando implementação for autorizada. Aceite visual humano. Não exigir
produção de catálogo inteiro para aprovar a fundação. Fluxo em [WORKFLOW](../WORKFLOW.md),
sem revisão Astra rotineira de código por asset.
