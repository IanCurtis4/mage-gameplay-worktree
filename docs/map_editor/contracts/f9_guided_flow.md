# F9 — roteiro guiado entre as telas (P6a/P6b)

Checkpoint49. Pedido humano de 1/11: "Barra de etapas" em todas as telas, com o
estado de cada etapa e um botão "Próximo passo" que leva o documento adiante e abre
a tela certa. Publicar no jogo é a etapa final, com confirmação (P6b, checkpoint50).

## O que a pessoa vê

No topo das telas de terreno (peça), composição (mapa), encontros e patrulhas,
logo abaixo do modo de trabalho, a faixa **Roteiro do mapa**:

`1 Peça · 2 Mapa · 3 Encontros · 4 Patrulhas · 5 Teste · 6 Publicação`, cada uma com seu estado,
a etapa da tela atual marcada. Clicar numa etapa abre (ou traz à frente) a tela
dela. Abaixo, **Próximo passo:** com a ação seguinte, **Mostrar o problema**
quando uma etapa tem problema, **Cancelar atualização** durante uma atualização
em segundo plano e uma linha que explica o que falta.

| Estado | Quando |
| --- | --- |
| pronta | compilada para a revisão atual |
| a fazer | falta compilar, marcar, sortear ou testar |
| desatualizada | a etapa anterior mudou depois de entrar nesta |
| a revisar | uma atualização está pronta e espera confirmação |
| em andamento | compilação ou atualização em segundo plano |
| com problema | a última compilação ou atualização falhou; o problema é nomeado |
| aguarda a anterior | a etapa anterior ainda não está pronta |
| não aberta | a tela ainda não foi aberta |
| opcional | a peça não precisa ser compilada para seguir |

A faixa não entra nos menus da tela e fica visível nos modos UX e AX.

## Próximo passo

A primeira etapa que não está pronta decide a ação, sempre pelo produtor da
própria tela (os mesmos botões e funções de antes):

| Etapa | Ações |
| --- | --- |
| Peça | compilar a peça (só se a compilação falhou ou a pessoa quiser conferir) |
| Mapa | abrir a composição; começar o mapa com a peça aberta (mapa vazio); levar a peça atual ao mapa; compilar o mapa |
| Encontros | levar o mapa aos encontros; atualizar o mapa nos encontros; marcar a entrada e pintar encontros; preparar e aplicar a prévia do plano; compilar |
| Patrulhas | levar os encontros às patrulhas; atualizar os encontros nas patrulhas; validar |
| Teste | testar no jogo (o pacote validado na janela de jogo real, perfil descartável); fica pronta para essa revisão do pacote |
| Publicação | publicar no jogo, depois do teste da mesma revisão |

Nada é aplicado sem a pessoa: o plano de encontros usa a confirmação da tela, e
cada atualização entre etapas abre "Atualizar a etapa" com o resumo e **Aplicar
(um desfazer)** ou **Descartar**.

## Levar uma etapa adiante (`carry_forward.gd`)

Roda em segundo plano, numa cópia, e só vira proposta; aplicar é uma ação
desfazível na sessão de destino e só vale sobre a base em que foi feita
(`flow_stale_proposal` se a etapa mudou no meio).

- **Peça → mapa.** Todo snapshot da mesma peça (mesmo `document_id`) é trocado
  pela peça aberta; as posições que o usavam passam a usar o novo; o mapa é
  compilado com as emendas. A peça aberta de um arquivo tem o mesmo hash do
  snapshot que o mapa guarda: abrir não marca o mapa como desatualizado.
- **Mapa → encontros.** Entrada, pincéis, exclusões, interações e slots seguem a
  sua posição do mapa (movida ou girada) e a família da camada, e assentam no novo
  chão. Um plano já sorteado é reconferido com todos os slots, sem sortear novos
  (até 128 slots livres de uma vez; acima disso, `flow_plan_too_large` pede a
  prévia na tela de encontros). Os encontros resultantes são compilados.
- **Encontros → patrulhas.** As rotas mantêm seus slots; se o mapa mudou, os
  pontos seguem a posição do mapa como acima; as patrulhas são validadas.

Diagnósticos que nomeiam a entidade e a tela dona: `flow_instance_missing` (a
posição do mapa do marcador saiu), `flow_support_lost` (a camada ou o chão do
marcador sumiu), `flow_slot_missing` (a rota usa um slot que não existe mais),
além dos diagnósticos dos compiladores. **Mostrar o problema** abre a tela dona e
seleciona o item na lista de diagnósticos dela, que foca a entidade no viewport.

## Publicar no jogo (P6b)

Depois de um teste de jogo da revisão atual das patrulhas, **Publicar no jogo…**
abre "Publicar no jogo" na tela de patrulhas com o identificador (minúsculas,
dígitos, `_` ou `-`) e o nome visível. O identificador sugerido é o do mapa já
publicado a partir do mesmo arquivo de patrulhas; senão, o `document_id`. O texto
diz o que muda na lista de mapas do jogo:

- mapa novo: identificador, nome, pacote e a fonte que será gravada;
- nova revisão: pacote anterior → novo; o arquivo da revisão anterior continua em
  disco e a lista passa a apontar para o novo;
- o mesmo pacote já publicado: nada a fazer ("Publicar" desativado).

Ao confirmar, em segundo plano (`map_release.gd` `publish`): o pacote é validado,
gravado como `data/map_authoring/<id>.<hash12>.rpp` (nunca sobrescrito), a fonte em
`<id>.patrol.json` (só se mudou) e a entrada na `release_packages.json`, apenas se
a lista ainda é a revisada (`release_registry_changed` caso contrário). A etapa
fica pronta quando a lista fixa este pacote. Falhas (`release_entry_invalid`,
`release_stale_source`, `immutable_conflict`, `release_io`) aparecem na etapa, com
"Mostrar o problema" na tela de patrulhas.

## AX

Cada faixa é um provedor de comandos da sua tela (`piece`, `map`, `population`,
`patrol`), sobre o mesmo modelo da GUI:

| Comando | Parâmetros | Resultado |
| --- | --- | --- |
| `<tela>/workflow/state` | — | etapas com estado, ação e diagnóstico; próxima ação; atualização pendente |
| `<tela>/workflow/next` | `action` | executa a próxima ação; outra ação é `flow_action_unavailable` |
| `<tela>/workflow/apply` | `proposal_hash` | aplica a atualização pendente |
| `<tela>/workflow/discard` | — | descarta a atualização pendente |
| `<tela>/workflow/show` | `step` | abre a tela dona e foca o problema da etapa |
| `<tela>/workflow/open` | `step` | abre a tela da etapa |
| `<tela>/workflow/publish` | `package_id`, `name`, `registry_hash` | publica depois de `next` com a ação `publish` (que devolve o plano) |

## Provas

- `Workflow` 12/12 (headless): peça no mapa, âncoras que seguem e assentam, plano
  reconferido com os mesmos slots, rotas, determinismo, recusas localizadas, um
  desfazer sobre a base, peça aberta igual ao snapshot do Bosque.
- `WorkflowNative` 28/28 (editor real): da composição ao teste só com "Próximo
  passo"; teste no jogo real e publicação revisada numa lista de mapas de teste;
  peça alterada levada ao mapa, aos encontros e às patrulhas em segundo plano, cada
  uma revisada e aplicada; nova revisão testada e publicada mantendo o pacote
  anterior; recusa que abre a tela dona com o marcador focado; AX com o mesmo
  estado; faixa visível e fora dos menus.

## Limites

- Uma tela só existe depois de aberta; as etapas seguintes ficam "não aberta" até
  lá. Abrir pela faixa usa o mesmo caminho dos botões de antes.
- A peça entra no mapa pelo `document_id`; peças diferentes com o mesmo
  `document_id` num mapa são tratadas como a mesma peça.
- Atualizar uma etapa compila na hora (no Bosque, o mapa leva ~28 s por
  compilação, e a atualização de encontros compila o mapa antigo e o novo); roda
  em segundo plano e pode ser cancelada.
- A etapa de teste conta como feita quando o jogo abre com o pacote da revisão;
  o editor não sabe o que a pessoa conferiu na janela de jogo.
