# F10 Q5 — rastreabilidade e revisão integrada

4–5/11/2026. Base `34bf16511019e88bf34ddfabfab624e533d7c20d`, contrato
[Q5](../contracts/f10_q5_review.md). Candidato deste incremento fixado no
[checkpoint16](f10.md)
e em seu vínculo de inputs; o incremento anterior é `8bbfb6c3ab39411fb27942d6d659ac94dc94aa6c`. Os incrementos
foram validados; não é aprovação técnica global de F10 nem aceite humano. As provas autorais e a reprodução anterior continuam
nos recibos [F0–F8](m8.md), [F9](f9.md) e [F10](f10.md).

## Promessas e operações

Esta tabela mantém todos os grupos da [matriz F9](../f9_closure_matrix.md),
incluindo os produtores F0–F8. Uma operação existente ou uma prova anterior não
é, sozinha, certificação de usabilidade. A seleção Q5 e os resultados medidos
estão no checkpoint e nos recibos do lote.

| Origem | Operações existentes a conferir | Prova autoral recebida / delta Q5 |
| --- | --- | --- |
| F0/M0 | schema, geometria canônica, isolamento do perfil, hospedagem Mapas | contratos de entrada/apoio/colisão; Q5 usa uma fixture e perfil descartável |
| F1/M1; F9-10 | criar, selecionar camada, undo/redo, salvar/reabrir, autosave/backup/pending, conflito externo | M1 document/native; reproduzir preservação e recusa sem alteração |
| F2/M2; F9-02 | subir/baixar, arredondar, suavizar, rampa, pintar, curvas, penhascos | Brush canônico e compilador; Q5 acrescenta aplicação temporal e chunks visuais locais, sem mudar AX |
| F3/M3; F9-03/04 | montagem manual, conectores, bordas/emendas por bioma, largura útil, altura, corpo e LoS | composição/Ports/Borders; grade Q1 preserva diagonal/apoio; conferir ponte e rota inferior |
| F4/M4; F9-08 | contexto de biomas/espécies, pesos/chances, raro fixo sem sorteio/palco, reservas, quest passiva, exceção por instância | população/contexto/encontros; quest sem consumidor continua referência passiva |
| F5/M5; F9-11 | patrulha, aggro/retorno, pausa, respawn, morte, loot e continuidade | M5 e diário J1–J3; Q5 corrige coleta presa no limite 256 e confere recuperação |
| F6/M6; F9-05 | mesma peça manual/seed, pins, contradição, geração parcial, variação interna por região | geração, RegionalSynthesis/RootSynthesis/SynthesisReceipts; proteção comum e um undo |
| F7/M7; F9-09 | exportar pedido, revisar/rejeitar/aplicar proposta, diff de três vias, assets passivos, dependências, proteção e rebase | Exchange/ExchangeMerge/ExchangeAssets; nenhuma execução transportada pela proposta |
| F8/M8; F9-12 | área temática com trilha, platô/rampa, ponte inferior, santuário, props, encontro e patrulha | Bosque autoral F9 e floresta Q4; avaliação visual e tarefas humanas 4–9 pendentes |
| F9-01 | catálogo/licença/hash, colocar/mover/rotacionar/duplicar/remover, grupo, camada/trava, snap/assentamento/inclinação, corpo/ataque/oclusão, scatter/exclusão, undo/roundtrip/export | Objects/Content/Occlusion/Assets; SocketFollow Q1 resolve marcador após relevo; tarefa humana da rocha precisa repetição |
| F9-06 | biblioteca/busca/miniatura/categoria/preset/favorito, minimapa, árvore/camada, overlays/foco/atalho/diagnóstico | Library/Viewport/Workflow; testar na janela real e registrar limites de descoberta |
| F9-07 | ações parametrizadas com IDs estáveis, estado/falhas/hash/confirmar, roteiro entre telas, alternar UX/AX | AX e Workflow; pincel temporal é entrada manual explícita, `Brush.stroke` mantém contrato congelado |
| F9-08/09 | identidades/revisões imutáveis, stale de fontes, preservar edição humana, reconciliação | revisão de pins/recibos e recusas; publicação nova não substitui revisão já consumida |
| F9-10 | progresso/cancelar/stale, cache/invalidação, pequeno/amplo/estresse, load/save/bake/generation | GridRegional Q1, worker/cache e medidas do checkpoint14; pausas de transição ainda existem |
| F9-11 | pacote imutável/API, prévia real, restart, release limpo, versão antiga, consumidor futuro | Q5 corrigiu vista técnica no lobby: referência visual por estágio e `AuthoredExpeditionView`; release atual 6/8/14 passou em perfil novo |

## Onze itens obrigatórios do contrato F10

| Item | Prova técnica desta rodada | Pendência que impede fechamento integral |
| --- | --- | --- |
| 1 · todas as promessas | grupos acima e matriz F9 confrontados; Core 641 checks/8 produtores e 11 etapas dirigidas/234 checks passaram | completar percurso manual e avaliar os limites identificados |
| 2 · peça pequena/área ampla e fluxo sem código | ManualBrush 20, nativo atualizado 20, TerrainNative 45, WorkflowNative 28 | percurso completo por um operador sem código |
| 3 · contexto e raros | população 91 no Core, EncounterAuthoringNative 25; provas F9 de raro fixo e reservas reaproveitadas sobre APIs sem delta | leitura editorial/temática humana; não criar gate de palco para raro manual |
| 4 · UX/AX | Q5UsabilityNative 12: 323 px úteis UX/304 AX em 1440×1000, dobras/foco/hash; F7 presentation 19 corrige nomes a partir do pin publicado; demais provas compatíveis do checkpoint15 | descoberta/usabilidade humana e outras resoluções ainda precisam avaliação; prévia curta e nomes técnicos foram corrigidos nesta amostra |
| 5 · navegação/altura/ponte/corpo/LoS | TerrainNative 45, OcclusionNative 12 e provas F9 de Ports/Navigation/SurfacePick sobre geometria sem delta Q5 | inspeção visual de ator/rampa/ponte/passagem inferior |
| 6 · identidade/revisão/determinismo/pins/stale | PhasePresentation 10, ReleaseApi 11, geração 89, RootSynthesisNative 11, ExchangeMergeNative 10 e hashes fonte/fixture | candidato fixado no checkpoint; provas limitadas aos casos/corpus executados |
| 7 · dados adversos/recuperação/conflito | documento 70, intercâmbio 113, journal_capacity 53, F5 fault/recovery 20/33, F7 flow 23 | sem falha técnica identificada nesses cenários; percurso manual completo permanece pendente |
| 8 · população/patrulha/combate/continuidade | patrulha 60, 16 IDs oficiais F3/F4/F5, ForestPlay 19 com arte até conclusão, diário sem duplicação | combate/legibilidade humanos; ForestPlay simula mortes e não prova diversão ou combate real |
| 9 · GUI/AX/headless/skills/release limpo | provas compatíveis do checkpoint15; release atualizado 6/6, Bosque 8/8, floresta 14/14, nomes conferidos na captura; fonte da skill validada | percurso manual por operador ainda indisponível; instrução longa de limpeza segue truncada no botão |
| 10 · tempos/memória/limites | checkpoint17: provas completas, preparação 178,986→43,774 s com 14 hits/zero buscas, entrada release 171,07→63,799 s; manifesto igual; tentativas antigas sem ganho continuam descartadas | resíduo síncrono/portais/retomada e rota extrema ainda lentos; sem certificação universal de fluidez/escala |
| 11 · guias/recibos/roteiro/limpeza | cabeçalhos históricos, consumo/arquitetura/skill corrigidos; roteiro e abertura isolada preparados | recibo/hashes/limpeza concluídos; uma fixture retida temporariamente para o roteiro humano |

## Limites de reprodução e retomada

As APIs de controle de computador falharam antes de inicializar (`failed to
write kernel assets`, erro de caminho 3). Foram usados testes nativos do Godot
e capturas da própria aplicação; isso não equivale a um operador percorrendo as
nove tarefas sem código. O aceite humano continua separado e Q5 não pode ser
declarado fechado enquanto essas obrigações estiverem pendentes.

A skill instalada `ragrpg-resume` foi aplicada: raiz/projeto/branch/contrato e
checkpoint conferidos. O CLI e `docs/WORKFLOW_TOOLING.md` indicados pela skill
não existem nem neste checkout nem no checkout principal informado. Não se
inventou nem copiou tooling para substituir esse diagnóstico.

O [roteiro humano](f10_acceptance_script.md) e sua abertura isolada estão preparados.
A fonte da skill de mapas teve a precedência de portais corrigida e passou no
validador oficial; cópias instaladas foram preservadas. O recibo fixa hashes dos
inputs e das evidências, inclusive da reprodução anterior corrigida.
