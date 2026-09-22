# E04 — expansão do Mago em pacotes por habilidade

Direção aprovada no brainstorming de 22/09/2026. Usuário autorizou encaminhar
ao Sol, mantendo entregas pequenas e sequenciais para controlar tokens.
Base aceita: gameplay e menu em 034e86e; aceite registrado em 0adbed9.

## Regras de produto

- Fogo: dano puro, queimadura e combos de dano, sem adicionar controle.
- Gelo: slow garantido quando o golpe acerta; Parede de Gelo controla terreno.
- Raio: dano intermediário, preparação e chance de interrupção forte.
- Espírito: proteção, enfraquecimento e dano espiritual. Não criar um novo
  sistema de resistências elementais neste recorte; usar o pipeline canônico.
- Preservar cinco slots ativos, dois passivos, carteira de 19 pontos base,
  aprendizado desde R0, ranks R1–R5 e equipagem manual. Biblioteca não é loadout.
- Custos de dano seguem curva côncava entre pontas, arredondada na autoria.
  Ranks melhoram um eixo principal; não multiplicar quantidade e dano integral
  simultaneamente. Valores novos devem constar no design da própria entrega.
- Casts curtos de habilidades de impacto usam o contrato existente escalado por
  DES. Mira, custos, ranks e menu devem acompanhar o runtime e o catálogo.

## Eletrizado — contrato compartilhado

Relâmpago e Parede de Raios aplicam uma marca temporária, sem DoT, sem stun
na aplicação e sem stacks; reaplicação renova duração. Descarga Elétrica
consome a marca após um acerto válido, acrescenta dano garantido ao golpe e
faz uma única rolagem por alvo: 25% de stun por 0,6 s como tuning inicial.
A marca é consumida mesmo se a rolagem falhar. Sem marca, Descarga ainda causa
seu dano normal. Falha de acerto não deve consumir marca nem aplicar stun.

Não rolar stun por tick, por projétil adicional ou na aplicação da marca.
Ranks inicialmente aumentam dano, mantendo chance/duração de stun fixas.
Stun respeita imunidades, limites e orçamento de controle de boss existentes.
Stun interrompe ações conforme contrato explícito; não representar stun por
root, que só impede deslocamento. Reusar HardControlState sem duplicar regras.
Marca e controle são estado temporário, com pausa, expiração e limpeza.

## Sequência de entregas

| Pacote | Habilidade | Escopo delimitado |
|---|---|---|
| MG1 | Relâmpago | Alvo único, cast curto, dano mágico e aplicação de Eletrizado. Inclui apenas a primitiva mínima da marca; não implementar detonação ainda. |
| MG2 | Descarga Elétrica | Skillshot linear; dano, consumo da marca, bônus e rolagem única de stun. Inclui a integração mínima do stun e seus limites. |
| MG3 | Parede de Raios | Linha perpendicular à direção escolhida; passagem livre, dano e marca ao atravessar, intervalo por alvo contra múltiplos acertos instantâneos. Sem stun próprio. |
| MG4 | Impacto das Almas | Alvo único, sequência curta de impactos; dividir o dano total entre impactos e capturar parâmetros na emissão. |
| MG5 | Assombro | Cone de pouco dano, fear breve e redução temporária do dano causado pelo alvo. Fechar cancelamento, navegação e limites de boss sem duplicar o pipeline de controle. |
| MG6 | Barreira Fantasma | Terreno atravessável; intercepta projéteis inimigos com resistência limitada. Inimigos que atravessam recebem slow e redução de dano; jogador imune. |
| MG7 | Parede de Gelo | Pendência do E04 já previsto: obstáculo temporário que bloqueia ambos os lados. Fechar colocação segura, navegação e expiração; não prender atores em geometria inválida. |
| MGI | Fechamento do Mago | Duas builds distintas, menu/aprendizado/presets/save/reload/run, melee/ranged, limpeza e regressão das skills antigas. |

Sobrecarga e Incorporação Simples permanecem propostas reservadas, não liberadas
para implementação neste envio. A matriz de quatro funções por tema é direção
de design, não autorização para criar dezesseis skills nem completar todos os
temas agora. Não adicionar passivas ou skills extras silenciosamente.

## Execução econômica e gates

Sol mantém a tarefa E04 existente. Executar **somente MG1 na primeira resposta**,
entregar commit, design/tabela, testes e handoff curto e então parar. Cada comando
de continuidade executa o próximo pacote da sequência, nunca o kit inteiro em
uma resposta. A parada é um checkpoint de consumo, não novo pedido de design
para cada valor rotineiro. Registrar dúvidas reais sem inventar aprovação.

Sol responde por novos sistemas/contratos. Terra/Luna podem receber lotes de
UI/dados/testes independentes sobre contrato pronto, com dono único por arquivo;
não delegar só para multiplicar agentes. Astra revê contratos críticos (controle,
colisão dinâmica) e fechamento integrado, não cada commit ou tabela de conteúdo.

Cada skill inclui catálogo persistente e execução, nome visível, aprendizado,
equipagem, HUD/mira e efeitos provisórios legíveis. Testar R0/inválido, R1/R5,
SP insuficiente, isolamento da emissão, pausa/morte/limpeza e o invariante novo.
Executar tools/verify.ps1 antes de entregar; usar saves de teste isolados.
Não alterar master/playtest pelo implementador. Não iniciar Espadachim, E05,
arte final ou augments novos neste envio. Skills existentes de fogo/gelo e
Teleporte devem preservar comportamento, salvo ajuste explicitamente justificado.
