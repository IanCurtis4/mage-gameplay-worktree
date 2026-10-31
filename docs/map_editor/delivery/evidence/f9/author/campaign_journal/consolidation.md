# Checkpoint37 — rampa sob a saída final e diário de campanha (J1–J2)

31/10/2026, Sol/Astra (Claude Opus). Base bdb8657d.

## Rampa: atores e árvores sumindo

- Pedido humano: o personagem e a árvore ao lado sumiam sob a rampa logo abaixo
  da saída final e voltavam a aparecer alguns passos depois; a rota estava certa.
- Medido (render probe, mesma rota): 103 de 576 passos com ciclo nas restrições
  de ordem do canvas; `CanvasOrder.apply` recusava (`presentation_order_ambiguous`)
  e mantinha os z do quadro anterior. Ciclo: árvore de borda enraizada em y=12
  dentro da projeção da rampa (tampa ~55 ali) → rampa → jogador → árvore.
- Correção (`scripts/world/world_canvas_order.gd`): só conta como "sob a tampa"
  um corpo inteiro abaixo dela (ponte); corpo que atravessa a tampa não recebe
  veredito da tampa. `solve()` continua recusando ciclos por padrão; `apply()` (ao
  vivo) libera o nó de menor prioridade e sempre entrega ordem completa.
- Depois: 0 ordens recusadas e 0 malhas desenhadas sobre ator/prop que estão
  atrás deles. CanvasOrder46.

## Diário de campanha (J1–J2)

Ver [contrato](../../../../../contracts/f9_campaign_journal.md), seção
"Implementado no checkpoint37". Mortes do combate gravadas como uma entrada do
diário no mesmo host: pior quadro 433 ms (antes 11,5–13,3 s).

## Validação

`luna/campaign_journal/` e `author/campaign_journal/` (saídas 123–132).

- Rodada `_02` (job 130): estágios até FieldsNative válidos; os logs legados
  `_02` vazios são inválidos (entradas editadas durante a rodada: "staged inputs
  differ from source"); CampaignJournal `_02` falhou só pelo `ERROR:` do motor no
  caso de objeto codificado, trocado por um payload que não é dicionário.
- Rodada `_03` (job 132): CampaignJournal13, GameplayNative59 (pior quadro
  381,7 ms), CanvasOrder46 e os legados finais.
- `e07_f7_actions_test` esperava um host substituído após cada morte; agora
  espera a entrada do diário no mesmo host (job 134: 27 checks PASS, com
  e07_f5_fault, e06_tx_loot, E05 e E04; Espadachim 4/93 como antes).
- LibraryNative falha em 2 checks de contagem de comandos AX; o teste é de 28/10
  e o código da biblioteca não foi tocado aqui. A confirmar como anterior.
