# F10 — regras da fase (Q2)

2/11/2026. Contrato de Sol (Claude Opus, papel Astra para a arquitetura). Fontes:
[arquitetura de fase](f10_phase_architecture.md) e [inserções de 2/11](f10_insertions.md).
As decisões humanas já tomadas valem como estão; este contrato diz onde cada uma
fica no código e o que ainda depende de escolha humana.

## Estado medido

- **Portais** (`expedition_campaign_state.gd` `portal_view`): um portal abre se
  for local, se a aresta já foi percorrida na volta, ou se o estágio de origem
  foi limpo uma vez (`cleared_once`). Não existe noção de jogada seguinte.
- **Conclusão** (`expedition_service.gd` `_apply_campaign` "finish"): exige o
  estágio atual limpo. Ao concluir, grava `completed_<fase>` em
  `profile_unlocks`, que pertence ao **perfil**.
- **Expedições concluídas** ficam em `profile.expeditions` com `character_id`,
  `phase_id` e `lifecycle: completed`, e nunca são apagadas (`CharacterAssets`
  recusa a alteração de um registro concluído).
- **Objetivos** do manifesto têm só dois desfechos: `phase_completion` (saída
  final) e `early_exit` (refúgio). Não há objetivo de estágio que abra portal.
- **Guardião** não existe como conceito: a população tem categorias (`normal`,
  `rare`, `elite`, `rare_elite`, `boss`) e `trash` (respawn).
- **Inimigos** têm dois arquétipos: `chaser` e `archer`.

## Decisões de arquitetura (Sol)

1. **Primeira jogada concluída por personagem, sem campo novo.** Ela é derivada de
   `profile.expeditions`: existe um registro `completed` com o mesmo
   `character_id` e o mesmo `phase_id`. Isso não muda o esquema do perfil, vale
   para saves existentes e não pode divergir da história real. O
   `completed_<fase>` de `profile_unlocks` continua gravado como estatística do
   perfil, mas não decide nada.
2. **A jogada sabe se é repetição.** No `enter`, o serviço calcula `replay` pelo
   item 1 e o grava no estado da campanha (`ExpeditionCampaignState.replay`;
   revisão do manifesto de snapshot 1 → 2). O valor fica fixo durante a
   expedição, mesmo que outro personagem conclua a fase no meio.
3. **Portal numa repetição:** abre quando o objetivo do estágio está cumprido. Se
   o estágio tem guardião, ele precisa estar derrotado antes. Na primeira jogada
   a regra atual (limpeza total) não muda.
4. **Leash (entregue):** quem volta ao posto não recebe dano e, ao chegar,
   recupera todo o HP. Um retorno sem rota não fica imune, para que um mob
   preso não trave a limpeza. Controles (raiz, medo, atordoamento) continuam
   valendo durante o retorno. A recuperação gradual de 4 s vale só para o mob
   parado no posto.

## Escolhas humanas (2/11)

Respostas da pessoa às três perguntas:

- **G. Guardião: marca explícita.** O pincel declara `guardian: true` (ausente
  quer dizer falso, e documentos antigos e seus hashes não mudam). Cada slot
  desse pincel vai ao manifesto com `guardian: true`.
- **O. Objetivo do estágio: tipo novo.** A interação `stage_unlock` vira um
  objetivo com esse desfecho. Ele é acionado no ponto pelo comando de campanha
  `unlock`, que recusa com `guardian_pending` enquanto houver guardião vivo. Um
  estágio sem guardião e sem esse objetivo já chega com os portais abertos numa
  repetição.
- **K. Contra o kiting: os dois arquétipos.** `charger` ganha velocidade ×2,6
  por 0,6 s quando o alvo está entre 160 e 480 u, com recarga de 4 s. `flanker`
  busca um ponto a 120 u ao lado do alvo (o lado é fixo por ocorrência) até
  ficar a 150 u e então vai direto. O `archer` existente é quem atira. As
  espécies e a mistura entram no Q4.

## Provas previstas

- Leash: `e06_gameplay_ai_test` (imune no retorno, sem cura antes de chegar,
  cura total na chegada).
- Regras: teste puro de `ExpeditionCampaignState` e do serviço (primeira jogada
  e repetição por personagem; alt sem conclusão volta à limpeza; guardião antes
  do objetivo; restauração do snapshot), mais as regressões E07 de persistência.
