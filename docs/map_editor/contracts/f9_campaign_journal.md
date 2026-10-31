# F9 — gravação incremental da expedição (contrato proposto, Astra)

31/10/2026. Sol/Astra (Claude Opus). Proposta para aprovação humana; nenhum
código desta proposta foi escrito. Base 2262b8c3.

## Problema medido

Hoje cada transação da campanha grava o estado inteiro do mundo:

- captura do mundo vivo (2,4 s);
- restauração de uma cópia em staging (2,2 s) e aplicação do evento nela;
- nova captura da cópia (2,4 s) e pack do checkpoint (1,1 s, 256 KB);
- restauração final (2,2 s), gravação do perfil e troca do host.

Mesmo adiada para o fim do combate (checkpoint33), a gravação leva ~11 s no
Bosque. O snapshot do mundo tem 3,8 MB, quando o que muda numa morte é uma
linha de estado.

Pedido humano: não gravar duas vezes e gravar mudanças em vez do estado todo,
como ponte para assincronia e, no futuro, servidor e multiplayer.

## Proposta: checkpoint base + diário de eventos

O estado durável da expedição passa a ser:

1. **Checkpoint base**: o mesmo snapshot completo de hoje, gravado só em pontos
   seguros (entrada, portal/viagem, refúgio/suspensão, conclusão, compactação).
2. **Diário**: uma lista só de acréscimo com os eventos de campanha desde o base.
   Cada entrada tem sequência, `request_id`/fingerprint (o recibo de hoje), o
   evento (`mob_death`, `wave`, `player_death`, `revive`, `collect`…) e o hash
   da entrada anterior (cadeia), para detectar corte ou adulteração.

Gravar um evento passa a ser:

1. validar o evento contra o estado vivo usando só funções puras de dados
   (`ExpeditionCampaignState.record_death`, `admit_pending`…), sobre uma cópia
   do estado de dados, sem tocar em nós;
2. acrescentar a entrada ao perfil pela mesma escrita atômica de hoje
   (arquivo pendente + backup); são bytes, não megabytes;
3. só depois da escrita confirmada, aplicar o evento ao mundo vivo (lápide,
   tickets de loot, companheiros). Não há restauração nem troca de host.

Retomar ou recuperar passa a ser: restaurar o checkpoint base, reaplicar o
diário em ordem com as mesmas funções puras e religar os atores (mortos viram
lápides). Uma **compactação** grava um novo base e zera o diário quando o diário
passa de N entradas ou num ponto seguro.

## Invariante E07 F5 reescrita

Hoje: "nada é publicado (concessão, troca de cena) antes do escritor canônico
gravar o mundo em staging". Proposta: "nada é publicado antes de a entrada do
diário estar durável, e base + diário reaplicado é igual ao estado vivo
depois da aplicação". A segunda metade vira teste diferencial obrigatório.

## Consequências

- Cada morte volta a ser durável na hora, em milissegundos. O adiamento do
  checkpoint33 deixa de ser necessário e o risco de perder as mortes de uma luta
  some.
- Após uma queda, os inimigos vivos voltam à posição e vida do último base
  (só eventos de campanha são diário; movimento não). Hoje acontece o mesmo
  entre transações.
- Concessões derivadas de evento (ticket de loot) precisam de id determinístico
  a partir do `event_id`, para a reaplicação gerar o mesmo ticket.
- Ponte para servidor: uma entrada do diário é um comando autoritativo com
  sequência. O servidor valida com as mesmas funções puras e retransmite, e os
  clientes aplicam. A compactação pode virar tarefa em segundo plano quando o
  snapshot deixar de depender da árvore de nós (etapa futura, fora deste
  contrato).

## Fatias propostas

1. **J1 — modelo e redutores puros.** Formato do diário no perfil, cadeia de
   hash, reaplicação sobre o base. Teste diferencial: aplicar ao vivo == base +
   diário reaplicado, para mortes, ondas e respawn.
2. **J2 — `mob_death` pelo diário.** Gravação em ms, sem restauração; remover o
   adiamento. Medir no Bosque.
3. **J3 — demais eventos** (`wave`, `player_death`, `revive`, `collect`) e
   compactação em pontos seguros e por tamanho.
4. **J4 — recuperação e falhas.** Escrita incerta, reconcile, diário truncado
   ou adulterado; os testes E07 F5 (fault/recovery/death kits) continuam
   passando.

## Decisões humanas pedidas

- Aceitar que, após uma queda, os inimigos vivos voltem ao estado do último base.
- Gatilho da compactação: só pontos seguros, ou também a cada N eventos (sugestão: 32).
- Ordem: fazer o diário (J1–J2) antes ou depois do grafo de navegação reutilizável.
