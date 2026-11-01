# F9 — matriz de fechamento (rastreabilidade)

31/10/2026, Sol/Astra (Claude Opus). Pedido humano: "Podemos continuar para a
matriz do editor. Pelo que eu sei já estava próximo de acabar, mas pode ver você
mesmo o que falta." Base 0ce15143. Fontes: [F9-01–12](contracts/f9_completion.md),
[requisitos em execução](f9_requirements.md), [validação](validation.md),
[síntese regional](contracts/f9_regional_synthesis.md),
[área de aceite](delivery/f9_area_design.md) e o código no checkout.

Leitura: origem → estado comprovado → falta → prova exigida. Os estados são:

- **comprovado**: implementado e com prova F9 identificada;
- **regressão**: implementado antes de F9 e só falta repassar as suítes;
- **parcial**: existe, mas falta parte do requisito;
- **falta**: não há implementação.

Nenhuma linha de [f9_requirements](f9_requirements.md) é removida; esta matriz
as agrupa pelo piso F9-01–12 e acrescenta o que a varredura do código achou.
A regressão de base desta matriz está em
`delivery/evidence/f9/luna/closure_baseline` (job 154).

## Regressão de base (P1, checkpoint41)

Base 0ce15143, Godot 4.7.2, fixture compartilhada.

- 58 etapas F9: 56 PASS. `LibraryNative` falhava em 2 checks que contavam os
  comandos AX com o número de antes do checkpoint23 (11 de objetos, 13 de
  terreno); o teste passou a comparar com os comandos que a tela declara e com a
  lista nova de terreno, e passa. `RoundedResume` precisa da sessão gravada pelo
  `RoundedNative` (`-ResumeSession`) e não roda isolado.
- Runners M2–M7 (terreno, composição, população, patrulha, geração, intercâmbio)
  e M8 Core: PASS.
- M1 (documento): a fixture isolada copiava só `scripts/map_authoring`, que agora
  depende do runtime compartilhado. Passou a copiar o runtime inteiro; PASS.
- M8 Release: o executável exportado recusava o pacote (`package_invalid`). Duas
  causas: o pacote representativo era de 25/10, compilado antes das revisões F9
  dos compiladores, e a validação de dependências lia os PNGs e `.import` crus,
  que o export não leva. O pacote foi recompilado das mesmas fontes (JSON
  idênticos) e a validação passou a usar o manifesto de assets em builds
  exportados. PASS.

## Resumo

O jogo do Bosque (F9-11/12 de gameplay, navegação, diário) avançou muito nos
checkpoints 30–40. O editor em si ainda não está perto do fim: a síntese regional
(F9-05), a reconciliação (F9-08/09), o transporte de assets e o export limpo
(F9-09/11), a responsividade do editor (F9-10) e o fluxo humano guiado (F9-07/12)
não têm implementação, ou a têm só em parte. São os pacotes P2–P7 abaixo.

## Movidos para F10 por decisão humana (1/11/2026)

Pedido humano: "Vamos deixando essas pendências menores registradas para F10 (já
que em teoria é um pente fino final + implementação da primeira fase completa)."
Não são omissões de F9: são limites medidos de itens já implementados, que o
pente-fino de F10 revisita. Nenhuma prova, guard, limite ou quota foi reduzido.

| Origem | Pendência | Estado em F9 | O que F10 revisita |
|---|---|---|---|
| F9-10 | `start()` de "Iniciar teste" no quadro principal | atrás da tela de carregamento: 8 s com pacote pronto, até ~30 s numa compilação nova | montar o mundo fora do quadro principal ou em fatias |
| F9-10 | cache regional dentro de uma peça | cache verificável por pacote (mapa, encontros), CompileCache10 | invalidar só as células tocadas |
| F9-11 | compactação do diário perto de 256 entradas | a compactação grava uma transação completa de uma vez | medir e, se preciso, dividir |
| F9-11 | coleta automática de vários drops | ~60–75 ms num quadro ao coletar 7 drops juntos | espalhar a coleta entre quadros |
| — | `RoundedResume` encadeado ao `RoundedNative` | precisa da sessão gravada (`-ResumeSession`) | tornar a etapa independente |

## Matriz

| ID | Item | Estado | Prova existente | Falta / prova exigida |
|---|---|---|---|---|
| F9-01 | catálogo, origem, licença, dependências | comprovado | 6 definições, PNGs, hashes; a44cfb1 30/23/53/25; manifesto de assets com origem/licença por arquivo (checkpoint41, AssetManifest7); o bundle de intercâmbio declara cada asset com hash, tipo, direitos e origem (ExchangeAssets12, checkpoint47) | — |
| F9-01 | colocar, mover, rotacionar, duplicar, remover | comprovado | Content28/Native30, Objects53, cliente AX 12/12 | — |
| F9-01 | seleção, inspector, grupo, camadas, travas | comprovado | checkpoint de objetos, Objects53 | — |
| F9-01 | snap, assentamento, inclinação | comprovado | Objects53 (ponte, piso travado) | — |
| F9-01 | decoração, corpo, ataque/LoS, oclusão | parcial | movimento/ataque; contato e ordem de desenho 04a7dfc; CanvasOrder46 | prova final de oclusão na área real (P6) |
| F9-01 | scatter, exclusões, undo, roundtrip, export | parcial | 53+25 checks | export no pipeline final (P5) |
| F9-02 | relevo suave, silhueta | comprovado tecnicamente | Gauss17/512, Organic15, Rounded19/20 | aceite visual humano (P7) |
| F9-02 | caminho, cobertura, encosta, pintura | comprovado tecnicamente | ef88996 35/20/46, Materials | aceite visual humano (P7) |
| F9-02 | penhasco, faces não caminháveis | comprovado | Cliff61, Ports92 | — |
| F9-03 | floresta, deserto, planície, ruína | comprovado | Borders93/Native32, MapBiome15/13 | aceite visual humano (P7) |
| F9-03 | transições, dono, abertura, frestas | comprovado | d3c0e25 | export final (P5) |
| F9-03 | ausência de perfil/asset | parcial | Borders93 (diagnóstico); no intercâmbio, asset ausente ou diferente é nomeado antes de compilar (checkpoint47) | release em ambiente limpo (P5) |
| F9-04 | largura útil M3-NAV-01, rampas 400/160 e 400/200 | comprovado | ce7bd59 46 checks | — |
| F9-04 | abertura larga, suporte contínuo, massa | comprovado | e6fdf43, 270ff3a, Ports92 | — |
| F9-04 | precisão, escala, corpo, folga | comprovado | 270ff3a/e6fdf43, SurfacePick24 | sem garantia universal de escala (limite declarado) |
| F9-04 | navegação no jogo (grafo, A*, segundo plano) | comprovado | NavigationAstar18, NavigationAsync18 | — |
| F9-05 | mesma peça, manual, seed, contexto | comprovado | entregue em F8; M6 PASS na regressão de base (job 154) | — |
| F9-05 | síntese/regeneração interna real por região | comprovado | dentro de uma peça: relevo, materiais e objetos; proposta compilada, uma aplicação, um undo; GUI/AX/CLI com o mesmo hash (RegionalSynthesis12, RegionalSynthesisNative14, checkpoint43); uma posição do mapa com snapshot próprio, com mapa, encontros ou patrulhas como raiz (RootSynthesis12, RootSynthesisNative10, checkpoint44); recibo na raiz e replay determinístico, com base no livro de revisões ou no pacote de replay (SynthesisReceipts11, checkpoint46) | — |
| F9-05 | proteção de terreno, props, encontros, patrulhas, pins | comprovado | pins de instância; na variação regional: regiões protegidas e preservadas, aberturas, objetos travados ou preservados e o footprint de quem fica (checkpoint43); entrada, saídas, slots e trechos de patrulha protegem o chão; slots fixos e de patrulha nunca são redistribuídos (checkpoint44) | — (documentos de geração por seed não são raiz da variação: levam o mapa inteiro, recibos inclusos, e os pins continuam regra do gerador) |
| F9-05 | diff e contradição antes do commit | comprovado | slots WFC; variação regional com diff por amostra e objeto e déficit de espalhamento (checkpoint43); suporte perdido ou alterado e déficit de encontros apontam a entidade (checkpoint44); conflitos do intercâmbio listados com base/atual/proposta antes de qualquer commit (checkpoint45) | — |
| F9-06 | biblioteca, busca, miniaturas, categorias, presets, favoritos | comprovado | Library50/Native53, 73b6ee8 | — |
| F9-06 | minimapa, árvore de objetos, camadas | comprovado | 6d72972 20/52/53/28 | — |
| F9-06 | overlays, foco, atalhos, diagnóstico localizado | parcial | Viewport20/Native52 | diagnóstico integrado ao fluxo final (P6) |
| F9-07 | AX: IDs, ações parametrizadas, estado | parcial | terreno, objetos, contexto, composição, encontros, patrulha (checkpoints 23–30); variação regional `terrain/synthesis/*` (checkpoint43) e `map`/`population`/`patrol` `/synthesis/*` (checkpoint44); intercâmbio `<tela>/exchange/{export,review,apply}` (checkpoint45) | UX guiada entre telas (P6) |
| F9-07 | UX coerente e guiada, fluxo humano inteiro | **falta** | menus e seletores por tela | roteiro guiado entre telas, sem código (P6) |
| F9-07 | histórico, hash, confirmação, modos | comprovado | entregue em F8; M1 PASS depois de corrigir a fixture do runner (job 155) | — |
| F9-08 | biomas, espécies, chances, pesos, reservas | parcial | Content28/Native30, EncounterAuthoring27/25 | conferir chances nos fluxos integrados (P7) |
| F9-08 | raro manual, exceção por instância, quest passiva | comprovado | entregue em F8; M4 PASS na regressão de base (job 154) | — |
| F9-08 | bioma no manifesto final | comprovado | 4e3a3788, MapBiome15/13 | — |
| F9-08 | stale entre revisões e reconciliação sem perda | comprovado | snapshots separados; a variação regional religa cada marcador pela família da camada e posição e reserva todo slot que fica (checkpoint44); o intercâmbio combina base/atual/proposta sem perder mudanças locais e reconfere o plano (checkpoint45) | — |
| F9-09 | GUI/AX/CLI equivalentes | parcial | composição, contexto, encontros, patrulhas, compilação, Store; variação regional na peça (checkpoint43) e na raiz de mapa, encontros e patrulhas (checkpoint44); intercâmbio de três vias com o mesmo hash (checkpoint45); bundle v2 com assets (checkpoint47) | — |
| F9-09 | diff, preview, undo, proteção espacial, rebase | comprovado | export/revisão/aplicação com diff; três vias por identidade, campo e amostra com a máscara comum; conflitos com escolha explícita; proteção atual prevalece (ExchangeMerge13, ExchangeMergeNative10, checkpoint45) | — |
| F9-09 | assets passivos, ambiente limpo, segurança | comprovado | manifesto de assets no build (checkpoint41); bundle v2 com manifesto passivo, área controlada, adulteração e ambiente diferente recusados, nenhum arquivo transportado (ExchangeAssets12, checkpoint47) | — |
| F9-09 | fontes de skills e guias | comprovado | `skills/ragrpg-mapdelivery` com a seção do editor F9; exchange.md e contrato de síntese atualizados (checkpoint47); nenhuma cópia instalada | — |
| F9-10 | autosave, backup, pending, conflito | comprovado | entregue em F1/F3; M1 PASS (job 155) | — |
| F9-10 | cancelamento, progresso, stale, atomicidade | parcial | threads em compiladores, população, patrulha, geração; intercâmbio compila a prévia da base e a aplicação fora da interface (checkpoint42) | "Iniciar teste" no quadro principal: movido para F10 por decisão humana (1/11) |
| F9-10 | cache e invalidação regional | parcial | cache verificável de mapa e encontros por pacote (CompileCache10, checkpoint42) | invalidação dentro de uma peça: movida para F10 por decisão humana (1/11) |
| F9-10 | medição pequeno/representativo/estresse | comprovado | representativa e Bosque, frio/quente, antes/depois ([responsividade](contracts/f9_editor_responsiveness.md)); NavigationDense5 para estresse | — |
| F9-11 | pacote imutável, revisão, consumo sem código | comprovado | 7f723ac 22/18/52/33/49 | — |
| F9-11 | preview real, apresentação de jogo | comprovado | GameplayNative63, checkpoints 30–40 | — |
| F9-11 | restart, continuidade, compatibilidade | comprovado | 581dae4, diário J1–J3 | — |
| F9-11 | export release limpo, dependências, API documentada | parcial | release M8 volta a passar (checkpoint41: pacote representativo recompilado e manifesto de assets) | release com o pacote do Bosque e ponto de consumo documentado para os próximos épicos (P5) |
| F9-12 | área temática (Bosque do Santuário) | parcial | 2 peças, trilha, colina, rampas, platôs, ponte e rota inferior, santuário, emenda, 47 props, população, patrulha; jogado pelo humano | conferir cada item da amostra no mapa final; geração com pins e intercâmbio em clone na área (P7) |
| F9-12 | fluxo humano completo sem código, aceite | **falta** | — | roteiro humano e aceite (P7) |
| — | teste histórico M3Native24 (preview retirado) | **falta** | baseline auditada no checkpoint25 | migrar o tooling (P6, junto da UX) |
| — | recibo final `delivery/f9.md`, limpeza da fixture | **falta** | — | P8 |

## Pacotes propostos, em ordem

1. **P1 — regressão integral.** (feito no checkpoint41) Todas as etapas F9 e os runners M1–M8 (job 154).
   Fecha as linhas "regressão" que passarem; migra o M3Native24.
2. **P2 — responsividade do editor e do teste (F9-10).** (checkpoint42: memo nos lotes de conectividade, cache verificável, intercâmbio fora da interface; `start()` do teste e cache regional movidos para F10 em 1/11) Tirar `start()` do
   quadro principal, prévia e commit em segundo plano com cancelamento e progresso,
   cache regional verificável, campanha de medição.
3. **P3 — síntese regional e reconciliação (F9-05/07/08/09).** (checkpoint43: P3a, variação dentro de uma peça; checkpoint44: P3b, mapa/encontros/patrulhas; checkpoint45: P3c, intercâmbio de três vias; checkpoint46: P3d, recibos e replay. P3 fechado) Implementar o
   contrato já preparado: proposta regional sobre a fonte, máscara comum, uma
   aplicação atômica, undo único, diff de três vias no intercâmbio, reconciliação
   de encontros e patrulhas. É o maior pacote.
4. **P4 — assets e fontes de skills (F9-01/03/09).** (checkpoint47: bundle v2 com manifesto de assets, revisões reais, fonte da skill de mapas) Manifesto de assets no bundle,
   ambiente limpo, rejeição de adulteração; atualizar `skills/ragrpg-mapdelivery`
   e os guias.
5. **P5 — export release (F9-11).** Release limpo com os pacotes F9 e API de
   consumo documentada.
6. **P6 — UX guiada e oclusão (F9-01/06/07).** Fluxo entre telas, diagnóstico
   localizado no fluxo, prova de oclusão.
7. **P7 — área final e aceite (F9-12).** Conferir a amostra no Bosque, geração com
   pins e intercâmbio na área, roteiro humano, aceite.
8. **P8 — entrega.** Recibo final, matriz comprovada, limpeza.
