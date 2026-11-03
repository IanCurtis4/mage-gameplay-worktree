# F10 — inserções humanas de 2/11/2026

Registro de Sol (Claude Opus). Pedido humano, junto com a autorização de integrar F9
em master: "Para F10, temos algumas inserções: 1 - [...] quero tentar completar a
primeira fase completa. [...] precisamos repensar o tamanho das peças contíguas
de campo. [...] 2 - quero poder atacar alguns problemas que estão naquele
documento de jogabilidade que meu amigo ajudou a fazer. Em específico, alguns
problemas que já existem ali e que não precisam do feedback dele agora."

As inserções ampliam a [reserva F10](f10_final_review.md): o pente-fino continua,
e F10 também entrega a primeira fase completa e os problemas abaixo. F10 foi
ativada pela pessoa em 2/11 (decisões no fim).

## 1. Escala dos campos

[Estudo de escala](f10_field_scale_study.md) com oito campos do Ragnarok Online.

- **Conversão aprovada em 2/11:** a metade da área em telas de um campo do
  RO dá um mapa de campo de 9.000 a 11.000 unidades de lado (de 40 a 50 s em
  linha reta). A peça atual tem 1280.
- O formato já comporta isso numa peça só (até 257×257 amostras e 65.536 quads
  por camada).
- O trabalho está no desempenho por região e em segundo plano.

## 2. Documento de jogabilidade (síntese iancurtis4/etheriwan, 29/10)

Fonte: `RagRPG_sintese_e_parecer.docx`, anexado pela pessoa no chat de 2/11. As
seis perguntas do fim do documento continuam com o tester e não entram aqui.

| Item | Estado no código | Decisão humana (2/11) | Em F10 |
| --- | --- | --- | --- |
| Leash sem recuperação de HP | Confirmado: `enemy_actor.gd _begin_return()` limpa engajamento, rota e lançamentos e não restaura HP | **Cura total ao voltar** | sim |
| Limpeza obrigatória contra rush | [f10_phase_architecture](f10_phase_architecture.md): limpeza só na primeira jogada | Limpeza total na primeira jogada; **só o objetivo nas seguintes**, matando antes o chefe ou guardião do objetivo quando existir | sim |
| Arqueiro kita com facilidade | Não reproduzido ainda | **Pelos inimigos**: sem mexer no kit; a população da fase ganha quem fecha distância, quem ataca à distância e quem cerca. A cura no leash tira o desgaste seguro | sim |
| Cliques atravessando janelas | Não reproduzido ainda | Entra | sim |
| Confirmação sobreposta aos atalhos | Não reproduzido ainda | Entra | sim |
| Botão de equipar distante → duplo clique para equipar | Não reproduzido ainda | Entra | sim |
| Filtragem da mochila pouco clara → filtro explícito | Não reproduzido ainda | Entra | sim |
| Descrição de skill trocando durante a leitura → descrição fixável | Não reproduzido ainda | Entra | sim |
| Escala e tamanho das janelas | Não reproduzido ainda | Entra | sim |
| Manter o mouse na janela → captura opcional do cursor | Não reproduzido ainda | Entra | sim |
| Geômetra difícil sob pressão | Não reproduzido ainda | — (a síntese pede avaliar junto com a interface e o encontro) | reavaliar depois da interface, sem simplificar o kit por antecipação |
| Taxa de 0,01%, duração da run, hub, novas mecânicas, desafios | Intenções e propostas da conversa | — | não; seguem com o tester |

Cada problema de interface é reproduzido antes da correção; o que não se
reproduzir fica registrado como não reproduzido, com o procedimento usado.

## 3. Pacotes propostos para F10

Ordem pela prioridade humana: autoria agêntica fluida e sem lag primeiro; autoria
manual em segundo plano.

| Pacote | Conteúdo |
| --- | --- |
| Q0 | Branch `codex/map-editor-f10` a partir de master (`3c35f7f2`); base e manifesto nominal |
| Q1 | **Escala e fluidez agêntica.** Mapa sintético de campo (~10.000 u) como banco de medida; compilação e certificação por região com cache (pendência F9); `prepare()`/`start()` do teste em segundo plano (pendência F9); navegação, desenho no jogo e diário nessa escala (compactação perto de 256 entradas, coleta de vários drops); orçamento medido de quadro, compilação e memória; pincéis por tick; marcador de entrada que acompanha o relevo e `socket_invalid` que o nomeia |
| Q2 | **Regras da fase** (entregue no checkpoint9).  Primeira jogada concluída por personagem; portais por limpeza na primeira jogada e por objetivo (guardião antes) nas seguintes; leash com cura total; população contra o kiting (quem fecha distância, quem atira, quem cerca) |
| Q3 | **Interface do jogo.** Os sete itens da tabela acima, cada um reproduzido antes; reavaliar a Geômetra depois |
| Q4 | **Primeira fase completa.** Terra no modo AX: pelo menos dois mapas de campo na nova escala, com arquétipos de forma distintos (regras do estudo), e um mapa de boss; população de 40 a 70 por mapa a medir; publicação e jogo real |
| Q5 | **Pente-fino** da reserva F10 (itens 1–11) sobre o editor e a fase, com a autoria manual (tarefas 4–9 do aceite F9) em segundo plano |
| Q6 | **Entrega.** Candidato, roteiro humano curto, preparação do playtest; master só com aceite |

## Decisões de 2/11 (segunda rodada)

1. **Escala aprovada:** mapa de campo de 9.000 a 11.000 unidades de lado, com
   40 a 70 monstros (espécie dominante, 2–3 secundárias e guardião). Os números
   finais são medidos contra a duração da run.
2. **Retorno ao posto:** o inimigo fica **imune até chegar** e, ao chegar, cura
   tudo.
3. **Jogadas seguintes sem guardião:** o portal abre **ao chegar ao objetivo** do
   estágio (santuário, switch).
4. **F10 ativada**, começando pelo Q1 (escala e fluidez agêntica), na ordem dos
   pacotes acima.
