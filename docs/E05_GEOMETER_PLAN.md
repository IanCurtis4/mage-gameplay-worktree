# E05 — Geômetra: contrato de execução por camadas

## Autorização e precedência — 02/10/2026

Usuário liberou Geômetra após entrega do Espiritualista e escolheu Sol6.1.
Base aceita:8df3a67. Este contrato substitui somente os pontos conflitantes da
Geômetra no E00: âncoras móveis agora são baseline; triângulo tem efeito apenas
na área, arestas delimitam. Não libera Sentinela/Caçador nem outros híbridos.
Identidade permanece mg_ar, origem mage, Elementalista + Sentinela conceitualmente;
não exige implementar a classe Sentinela para começar esta híbrida.

Sol6.1 conduz sistemas, integração e revisão interna de apoio. Astra mantém
direção visual e revisão integrada. Usar chat/worktree E05 existentes; nada de
handoff a cada camada/skill. Commits pequenos e checkpoint único retomável.
Não publicar candidato parcial como classe completa. Playtest após aceite
integrado; master somente após aceite humano, sem push automático.

## Decisões aprovadas

- Traçado Elemental é ativa especial, separada de autoattack. Fogo/Gelo/Raio
  selecionáveis diretamente por gramática intrínseca, sem ocupar três slots.
  Seleção persiste; ciclagem é conveniência opcional, não dependência do MVP.
- Usar comandos element_fire/ice/lightning e grammar_clear já previstos no E00;
  conferir bindings existentes antes de escolher teclas. UI clicável e modos de
  mira existentes. Selecionar elemento não dispara nem custa SP.
- Mira explícita de chão cria âncora estática; mira de inimigo cria dinâmica
  somente após impacto válido. Não usar autoattack para construir. Congelar
  elemento/intenção por disparo; ordenar vértices pela sequência dos comandos,
  não permitir que diferença de tempo de viagem troque a receita.
- Primeiro vértice prepara; segundo distinto forma parede; terceiro válido e
  desbloqueado transforma a figura em triângulo. Dois iguais são preparação
  tracejada, sem parede ativa, permitindo triângulos puros depois do desbloqueio.
  Não ativar por tempo sem disparar. Triângulo encerra efeitos da parede anterior.
- Esclarecimento G0 aprovado por Astra: Traçado dispara primeiro/segundo;
  Triangulação aprendida/equipada e explicitamente selecionada dispara terceiro,
  pagando somente seu custo/CD. Traçado não seleciona ou lança Triangulação.
  Terceiro impacto válido fecha a área automaticamente. Semânticas consolidadas
  em E05_GEOMETER_G0_PROPOSAL.md após retorno de design de02/10/2026.
- Até três vértices confirmados e uma figura ativa; sem munição/recarregador
  adicional. Custos por skills/SP/CD/duração. Quarta flecha não substitui ponto
  silenciosamente: edição por Translação/Reescrita, ou nova construção explícita.
- Proposta operacional para nova construção: comando grammar_clear remove
  figura confirmada sem Colapso; Esc só cancela intenção/edição. UI diferencia
  os dois. Falha de edição conserva figura anterior e não cobra custo.
- Misturar âncoras estáticas/dinâmicas é permitido. Inimigo não é puxado nem
  imobilizado pela âncora. Morte deposita âncora na última posição válida de chão,
  sem renovar duração. Invalidade temporária por distância/obstáculo/degeneração
  suspende efeitos, preserva relógios e retoma quando válida. Sem dano retroativo
  acumulado ou repetição gratuita de eventos ao retomar.
- Preservar limites E00: aresta<=600, separação>=24, área>=256; duração inicial
  dos vértices8s/figura6s, teto12s por ranks previstos. Geometria de regras e
  preview compartilham fonte única. Movimento não transforma região varrida em
  acertos extras; deduplicação/cadência por alvo e instância da construção.
- Seis paredes ordenadas de elementos distintos. Triângulos: fundação → regra
  interna → resolução, com27 receitas; R1 puros3, R3 total21, R5 total27.
  Manter 5 ativas/2 passivas, gates20/23/25/28/31/34/37, carteiras19/20 do E00.

## Camadas, dependências e critérios internos

| Camada | Entrega | Evidência antes de avançar |
|---|---|---|
| G0 — contratos | Interfaces, máquina de estados, tabela das6 paredes/27 triângulos e decisões abertas | Cada efeito define alvo, gatilho, duração, boss, dano/controle, interação com projéteis e Colapso; diferenciar definição antiga de proposta nova |
| G1 — gramática e disparo | Seleção direta, mira chão/inimigo, flecha especial, ordem dos disparos, cancelar/recomeçar, preview | UI/foco/pausa não disparam, auto não coloca vértices, falha/impacto tardio não troca receita nem duplica cobrança |
| G2 — geometria estática | Vértices/linha/triângulo, limites, duração, formação/substituição atômica | Casos degenerados/obstáculos, 2 iguais, terceiro inválido preserva parede, expiração/cleanup, mesma área no desenho/hit-test |
| G3 — âncoras móveis | Seguir inimigo, misturas, morte, suspensão/retomada | Boss móvel, âncoras cruzando/trocando orientação, LoS, alvo inválido durante voo, sem resets de duração/procs |
| G4 — paredes | Primitivas de cruzamento/entrada/saída, seis receitas, Teorema de Incidência | Direção e evento real claros, intervalo por alvo/projétil, sem ricochete recursivo, boss solo; nenhuma parede bloqueia navegação física |
| G5 — campos | Fundação/regra/resolução e três triângulos puros; depois18 mistos e6 tricolores via dados | Toda receita faz o que descreve, sem bordas herdando efeitos de parede; dedup de fontes, telegraph e regras de boss |
| G6 — edição e progressão | Translação, Reescrita, Colapso, Memória Vetorial; menu/build/ranks/save | Definir preservação de vínculo em cada edição; falhas atômicas; duas builds legais; biblioteca completa apenas quando todas receitas estiverem prontas |
| G7 — apresentação e fechamento | Personagem/linguagem visual, onboarding, cenário denso e boss, regressão | Estado→efeito legível sem texto, sem cobrir atores/telegraphs, verify integral e pacote único para Astra |

G6 pode preparar APIs emG2/G3, mas validar comportamento completo apósG5.
G7 não significa deixar VFX para o fim: preview e sinais mínimos acompanham
cada camada. Só arte/polimento final e composição densa fecham emG7.

## Fechamento G0 e próximos passos

As decisões de direção, condução/desvio, resolução versus Colapso,27 receitas,
edição móvel e cobrança no voo foram agrupadas e aprovadas por Astra em02/10.
O contrato consolidado está em E05_GEOMETER_G0_PROPOSAL.md; o nome do arquivo
é preservado para manter referências existentes. Não criar uma sétima parede
para dois elementos iguais. Tuning inicial permanece sujeito a playtest.

A próxima unidade é validar geometria e reservas ordenadas com testes de
invariantes, antes de integrar disparos ao combate. A pedido do usuário, esta
rodada fecha apenas documentaçãoG0, em ritmo gradual; não conclui G1–G7.
Mudanças futuras na fantasia/gramática ou efeitos fora desse contrato devem
ser agrupadas para Astra. Não há novo gate por camada, nem corte de receitas.

## Direção visual Astra e orçamento

Cartógrafa/astrônoma, branco/navy/azul claro, ouro, cristal e arco instrumental.
Referência: docs/references/CODEX_HANDOFF_MVP_2026-09-14/art/hybrids/geometer_geometra.png.
Vértices: três silhuetas elementais, marcas discretas1/2/3 e distinção entre
base de chão e vínculo ao portador. Linhas: contorno fino/direção; destaque apenas
na interação. Triângulo: uma camada de terreno discreta sob atores, três bordas
delimitadoras e um efeito dominante na ativação. Sem três tempestades contínuas
ou grande explosão por inimigo. Suspensão tracejada, sem sugerir efeito ativo.
Fogo expande/fissura; Gelo segmenta/converge; Raio bifurca/percorre. Cor é apoio.
Não converter a área de regras em losango cosmético diferente da área atingida.

Sol implementa composição por código e reutiliza assets adequados; novos bitmaps
são coordenados com Astra. Primeiro provar estados/âncoras/figuras com apresentação
mínima funcional. Não gerar33 spritesheets independentes: receitas combinam
primitivas, com elementos visuais compatíveis com seus gatilhos reais.

## Delegação econômica e revisão

Sol6.1 é dono de G0–G6 sistêmicos, transações e geometria. Terra pode executar
UI/VFX sobre contratos fechados; Luna pode preencher receitas/tooltips/fixtures
já especificados. Subagentes são opcionais em lotes independentes com dono único
por arquivo, sem passar tudo pelos três. Não delegar decisões abertas a Luna.
Usar disponibilidade real das ferramentas; registrar limitações sem substituição
silenciosa. Medição por skill/camada só quando houver uso atribuível disponível.

Checkpoint:E05_GEOMETER_CHECKPOINT.md; anotar commit, testes, decisão e próximo
passo em poucas linhas. Regressão direcionada por camada; tools/verify.ps1 no
fechamento integrado. Testes de invariantes para regras novas. Nenhum handoff
por microtarefa. Se o uso acabar, retomar a primeira linha incompleta.
