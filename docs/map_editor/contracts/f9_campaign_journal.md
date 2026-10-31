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

- Aceitar que, após uma queda, os inimigos vivos voltem ao estado do último base:
  em aberto, levada pelo humano ao tester (31/10).
- Gatilho da compactação: respondida em 31/10 — só pontos seguros, até a
  gravação deixar de travar o jogo (assíncrona). O humano não se importa com
  gravações frequentes se elas não travarem o movimento.
- Ordem: respondida em 31/10 — grafo de navegação primeiro (checkpoint35,
  contracts/f9_navigation_graph.md), depois o diário.

## Implementado no checkpoint37 (J1 + J2)

31/10/2026, Sol/Astra (Claude Opus). Base bdb8657d.

- Formato: `ExpeditionAssetLock.journal`, oitavo campo do registro, presente só
  quando não vazio. Cada entrada tem `seq` (1, 2, …), `request_id`, `payload`
  (base64 de `var_to_bytes` sem objetos), `sha256` do payload e `prev` (o digest
  da entrada anterior; a primeira aponta para o `sha256` do checkpoint base).
  Limite de 256 entradas; cheio, a gravação volta ao caminho completo, que
  compacta. Codec: `scripts/core/expedition/persistence/expedition_journal_codec.gd`.
- O payload é o **efeito resolvido**, não um comando para rolar de novo: as
  mortes validadas, os tickets de loot emitidos, o estado do RNG e a sequência
  de tickets depois deles. Assim a reaplicação reproduz exatamente o loot que o
  jogador viu.
- Gravar (`ExpeditionService.journal_events`): valida as mortes numa cópia dos
  slots, rola os drops no livro de recompensas vivo e restaura livro e RNG; grava
  o perfil com a entrada nova (mesma escrita atômica, recibo `journal`); só
  depois aplica ao host vivo (morte no estado, remoção do mob e companheiros,
  tickets, RNG). Escrita incerta: o jogo fica congelado até a recuperação, como
  antes.
- Restaurar (`_restore`): base + reaplicação das entradas antes de ativar; os
  modos de processo registrados dos mobs removidos são atualizados para o
  registro não reativá-los.
- Toda gravação completa (entrar, viajar, reviver, concluir, suspender, coletar,
  equipamento) grava um base novo e zera o diário.
- Só mortes vão ao diário. Ondas e respawn continuam no caminho completo (J3).
- O adiamento para o fim do combate **continua**: com a escrita ainda síncrona
  (~0,4 s), gravar a cada morte travaria o combate. Sai quando a escrita for
  assíncrona.

Medido (GameplayNative, headless): pior quadro durante a gravação das mortes
433 ms, contra 11,5–13,3 s do caminho completo. O custo restante é a escrita do
perfil, que relê e valida o checkpoint inteiro (descompressão e hash de ~4 MB)
várias vezes por gravação.

Provas: CampaignJournal13 (cadeia, tipos, ida e volta JSON, adulteração, ordem,
limite) e GameplayNative59 (uma entrada por combate, mesmo host e mesma skin,
base + diário igual ao estado vivo de campanha/recompensas/RNG, ida e volta do
registro).

Próximo: escrita assíncrona do perfil (tirar os 0,4 s do quadro) ou cache da
validação do checkpoint inalterado; depois J3 (ondas/respawn).

## Implementado no checkpoint38 (escrita em segundo plano e coleta pelo diário)

31/10/2026, Sol/Astra (Claude Opus). Base 3a12a2a4. Pedido humano: "Grave o
perfil em segundo plano"; recompensas (drops e XP) devem chegar ao personagem
sozinhas, sem o botão que travava o jogo e coletava uma morte por vez.

- `ProfileFacade.commit_expedition_candidate_async`: a mesma escrita do
  `ProfileStore` roda numa tarefa do WorkerThreadPool sobre uma cópia isolada do
  candidato; a operação fica em andamento (qualquer outra recebe
  `save_in_progress`) até `poll_async_commit()` devolver o mesmo resultado público
  da chamada síncrona. Liberar o facade aguarda a tarefa.
- `ExpeditionService`: `journal_events`/`journal_collect` aceitam `background`;
  `poll_background()` publica o efeito só depois do resultado durável. Escrita
  incerta continua congelando o jogo até a recuperação.
- `main`: o efeito é resolvido sob a barreira (mesmo quadro), a barreira é
  liberada e o jogo segue enquanto a thread grava; `_process` consulta o
  resultado. Uma captura pedida nesse meio espera a gravação terminar. Headless e
  `RAGRPG_SYNC_SAVE=1` gravam de forma síncrona; `RAGRPG_BACKGROUND_SAVE=1` força
  a thread (teste).
- Coleta: novo tipo de entrada `collect` com os tickets entregues (e a instância
  de carta de cada um), a sessão de recompensas e o digest de posses depois das
  concessões. As concessões ficam no próprio perfil; a reaplicação só retira os
  tickets da fila e atualiza o estado da run a partir do perfil.
  - `ExpeditionAssetLock.effective_session()`/`effective_owner_digest()`: valem os
    da última coleta do diário, ou os do checkpoint.
  - `CharacterAssets`: XP e posses só avançam com um checkpoint material novo ou
    com exatamente uma entrada nova de coleta que nomeia o digest resultante.
  - `main._auto_collect`: fora de combate, sem oferta aberta, sem mortes
    pendentes e sem gravação em curso, todos os tickets de mob da fila vão numa
    entrada. Recusa: nova tentativa em 5 s; o botão do painel continua como via
    explícita.

Medido (GameplayNative, headless, thread forçada): pior quadro durante a
gravação das mortes 43,6 ms (382–433 ms síncrono; 11,5–13,3 s antes do diário).
Drop e XP coletados sozinhos numa segunda entrada; base + diário reaplicado
reproduz os tickets entregues.

Com a escrita fora do quadro, o próximo passo natural é gravar cada morte na
hora (fim do adiamento) e levar ondas/respawn ao diário (J3).
