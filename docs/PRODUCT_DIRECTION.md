# Direção de produto — exploração, estágios e economia

Decisões humanas de 17/10/2026, incluindo as duas respostas de esclarecimento
neste chat. Status: direção aprovada e documentação autorizada; implementação
destes sistemas futuros requer pacote/épico liberado. Não altera o runtime E06.
Produto existente: [MVP](MVP.md). Execução: [WORKFLOW](WORKFLOW.md).

## Loop de campanha

Lobby → selecionar fase → explorar estágio → obter loot e escolher augments
nos momentos permitidos → portal em ponto específico → próximo estágio.
O lobby também abrigará vendedores de equipamentos e consumíveis.

Para evitar ambiguidade nesta documentação, **fase** é a opção de campanha
selecionada no lobby, **estágio** é um avanço dessa fase, **mapa** é o espaço
explorável do estágio e **parte** é um módulo de autoria usado pelo gerador.
Esta nomenclatura não renomeia classes ou APIs existentes.

Cada portal representa avanço ao estágio seguinte. Não presumir viagem de volta,
fast travel, mundo aberto contínuo ou saída livre do combate. Condições de ativação,
objetivos, quantidade de estágios, encerramento, boss e retorno ao lobby devem ser
fechadas no contrato da fase. O princípio atual de augments por etapa continua;
cadência exata acompanha o contrato da campanha, sem transformar exploração em
obrigação de limpar todos os mobs de um mapa grande.

## Mapas modulares com elevação

Mapas grandes e labirínticos são montados algoritmicamente de partes conectáveis.
Não basta sortear spawns sobre o mesmo retângulo, nem é necessário gerar cada
pixel proceduralmente. Autoria define partes, conectores válidos, entradas,
saídas, bioma, rotas e restrições; montagem combina essas partes.

Elevação afeta rotas, rampas, pontes e acesso entre alturas, conforme resposta
humana. Não é apenas sombreado ou Y-sort. Antes de implementar, a arquitetura
deve fechar a representação de níveis/superfícies, conectores entre alturas e
os efeitos sobre navegação, clique, projéteis, alcance, área, dash e teleporte.
Linha de visão entre alturas exige contrato próprio; não inferir tiro através
de ponte, parede, piso ou outra superfície pela projeção 2D atual.

Critérios de entrega a concretizar em cada pacote:

- Seed + versão da receita/conjunto de partes reproduzem montagem e população.
- Entrada segura e caminho até saída/objetivos obrigatórios; conectores alinhados
  e transitáveis para os raios dos atores, sem frestas ou regiões obrigatórias isoladas.
- Caminho testemunha para objetivos, testes de seeds adversas e falhas de montagem
  limitadas; nunca retry infinito nem teleporte silencioso para mascarar desconexão.
- Sobreposição visual, colisão, seleção de superfície e caminho concordam;
  rampas/ponte têm leitura no jogo, não apenas teste do grafo.
- Área total, população do mapa e orçamento simultâneo de simulação são medidas
  diferentes. Definir carregamento/ativação e perfis de desempenho antes de alegar escala.

Não há tamanho, número de partes, seed fixa ou algoritmo final aprovado aqui.
A prova inicial pode ser pequena, mas deve exercitar conexão e altura reais.

## Populações e progressão de inimigos

Cada mapa tem concentrações e picos de espécies. Em mapas vizinhos do mesmo
bioma, a distribuição muda por gradiente: espécies se sobrepõem e os pesos se
deslocam conforme a exploração. Mudança de bioma permite ruptura temática.

Exemplo fornecido pelo usuário: mapa 1 com 100 géis e 50 “lunáticos”; mapa 2
com 60 géis e 80 “lunáticos”. É exemplo de concentração relativa, não um alvo
de 150 atores simultâneos, nomes finais ou números a copiar para o catálogo.
Não equivale a respawn infinito ou obrigação de matar todos para usar o portal.

Mapas mais avançados têm inimigos mais fortes, ainda coerentes com o bioma.
Manter nível/dificuldade por origem de campanha, sem escala automática pelo
nível do jogador. Espécie, ocorrência (normal/raro/elite/elite raro/chefe),
nível/origem, densidade e comportamento são eixos distintos.

O contrato de população deve expor pesos/quotas e distribuição espacial, vizinhança,
transições de bioma, áreas seguras, ameaças e orçamento ativo. Avaliar gradiente
em múltiplas seeds com distribuições, não exigir proporções idênticas por seed.
Respawn, persistência de mortes entre visitas e critérios de portal permanecem
abertos; não inferir MMORPG online a partir da referência Ragnarok.

## Consumíveis e estado de combate

Poções de HP/SP são futuras. Decisão humana: **após usar, ficam indisponíveis
até sair do combate; o CD longo também precisa terminar**. Portanto:

| Situação após o uso | Pode reutilizar? |
|---|---|
| CD terminou, mas ainda não saiu daquele combate | Não |
| Saiu do combate, mas CD ainda não terminou | Não |
| Saiu do combate e CD terminou | Sim, se as demais condições de uso forem válidas |

Sair de combate não zera o tempo restante. Não renovar acesso por abrir menu,
trocar item, morrer/ressuscitar, cruzar portal ou recriar UI sem contrato explícito.
No futuro, um estado canônico de combate deverá contemplar exploração/aggro/leash;
o fim de um encontro inteiro do piloto e alguns segundos sem dano não podem ser
assumidos como a definição final. Disengage não deve permitir spam por oscilação.

Antes do código, fechar duração, grupos compartilhados HP/SP, estoque/consumo,
relógio e pausa, reentrada em combate, morte/fim de run e autoridade do estado.
Consumo e efeito devem ser atômicos/idempotentes. Esta tabela especifica a
restrição aprovada; não fixa valores, esquema de save ou implementação.

## Trash/misc, gold e vendedores

Itens trash/misc podem servir a missões ou venda. Vendedores no lobby recebem
gold de vendas e vendem equipamentos/consumíveis. Isso substitui a exclusão
histórica genérica de lojas internas; não autoriza monetização ou loja online.

Ainda precisam de decisão antes dos consumidores: propriedade de gold e estoque
(perfil/personagem/run), persistência de consumíveis/misc e perda na morte,
stack/capacidade, itens de missão vendáveis ou protegidos, recompra, estoque e
preços dos NPCs, quais itens são vendáveis e se há gold por outras fontes.
Não inventar quests ou converter todo equipamento atual em item vendável.

Contrato técnico futuro deve usar as autoridades existentes de perfil/inventário,
com validação de saldo/quantidade, transação única de item+gold, intenção estável
em retry, reconciliação de gravação incerta e migração preservadora. Não criar
segundo writer de save ou fórmula de preço na UI. O pacote comercial depende de
decisões de propriedade/preços; não bloqueia a autoria documental de mapas.

## Substituições e sequência sugerida

O piloto de mapas fixos/seis escolhas continua executável para teste, mas deixa
de definir a arquitetura final de campanha. Restrições antigas a cartas efêmeras,
coleção sem cópias e três slots já foram substituídas pelos contratos E06; esta
direção não as restaura. Gate Astra automático foi removido em 12/10.

Sequência de planejamento, ainda sem dispatch: grafo de estágios/conectores e
altura → montagem de mapa com prova navegável → população por bioma/progressão →
integração de portais/recompensas; economia/consumíveis têm trilha própria após
fechar suas decisões. Catálogos independentes podem avançar em paralelo somente
com APIs estáveis e dono exclusivo, conforme WORKFLOW. Não atribuir novos números
de épico nem iniciar E07+ por efeito deste documento.
