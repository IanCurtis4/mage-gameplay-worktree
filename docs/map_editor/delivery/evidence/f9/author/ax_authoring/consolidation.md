# Sol — integração da autoria AX de peça e terreno

Código final `17516a20f959fabdecf0af76777824d379d98f42`, branch
`codex/map-editor-f9`, checkout `.tools/map-editor-m5`. Engine Godot4.7.2 standard,
SHA256 `AB1824F85BFD8E0E4128182C000C4003A3E042245B2967848D089B2A04B22424`.

## Resultado delimitado

GUI e AX compartilham TerrainOperations e DocumentSession para grades, pontes,
conectores, locks e referência às proteções de região existentes. Validação
fechada/finita e limites do formulário, IDs explícitos, seleção sem revisão,
no-op sem undo e locks na origem/destino do conector. A compilação continua
canônica; propostas de documento não autorizam geometria inválida para o jogo.

Shell expõe novo/nome/abrir/salvar/desfazer/refazer. Abrir/novo sujo exigem
confirmação e preservação do rascunho. Salvar/preservar com nome ainda em edição
primeiro grava; falha mantém fonte/histórico. O Store conserva conflito externo,
backup/pending e writer. Não existe substituição genérica da fonte pelo cliente.

O cliente SceneTree monta o Shell real em modo AX e recebe somente ações
passivas. Aguarda o worker ao compilar; falha encerra o lote. Retorna IDs,
hashes, diagnósticos, estado e snapshot final, sem duplicar fonte por ação.
Contexto/Intercâmbio começam fechados e abrem explicitamente. O host de captura
usa escala nativa, revela o canvas e amplia somente esse viewport para440px;
o mínimo global do Canvas continua300px. A apresentação UX completa segue F9-07.

## Evidência e papéis

Luna escreveu/supervisionou os testes; Sol conferiu contrato, depurou as falhas,
fechou a integração e inspecionou as imagens. Não é auditoria independente.

| Prova | Resultado e origem |
|---|---|
| Authoring |30/30 PASS em da0e620, `luna/ax_authoring/model_03`; operadores e teste headless permanecem iguais |
| Native |15/15 PASS em17516a20, `native_04`; fonte GUI/AX, compilação completa, rejeição de grade isolada, abertura/fechamento das janelas e captura |
| Cliente |10/10 ações headless e nativas, novo processo de abertura/compilação; fonte87abe837…a89c99a e compilação169c09d1…fc1875b iguais |
| Negativos |Envelope desconhecido sem montar editor; falha interrompe lote; destino de resultado existente não é sobrescrito |
| Verify |editor_import PASS1/299 em17516a20, ambientes descartáveis, logs em verify_editor_import_04 |

Sol rehashou os2024 inputs de Native15: source=fixture=manifest, zero diferenças,
HEAD antes/depois17516a20, exit0, sem timeout/Script/Parse/ERROR. Inspecionou as
capturas nativa e CLI: terreno inteiro visível, sem janelas sobrepostas. Demais
provas são reaproveitadas por impacto; não afirmar nova execução de gameplay.
O relatório Luna registra bases/hashes por etapa e todos os erros preservados.

## Consumo real por Terra

Terra autorou as duas fontes sanctuary_woods_*.source.json usando o editor AX,
sem preencher fonte pronta. Replay limpo8/8 e27/27 ações; Store escreveu bytes
idênticos aos originais, e outros processos reabriram/compilaram com hashes iguais.
Clareira:15.116B, SHA65a26754…55ced5, fonte93a5d99c…07ba38,
compilação aa762ada7df22b49c8ece77f95c9104791e8fc8138adecbdadd545651838bc12.
Passagem:8.142B, SHAd0071096…95d7e, fonted0d0f5ba…ed94a,
compilação dd2da0720ecc3757d42378e5be0e97865fba979d637517f1513bf666ee490a88.
Receitas, argv/env/exit, snapshots, logs e capturas no recibo Terra clean_replay.
Sol comparou os bytes e inspecionou ambas as imagens: trilha/colina e dois níveis
com ponte presentes. Isso prova autoria/compilação, sem certificar travessia.

A primeira autoria Terra apontou --path para o checkout não importado e registrou
erros de classe SnapshotGraphEncoding; não foi aprovada, mesmo com exit0.
Não se alterou runtime para contornar a invocação. O replay usa a fixture correta.
Os primeiros pacotes compilados não são referência aprovada; logs/hashes antigos
permanecem para diagnóstico. As fontes idênticas passaram roundtrip limpo.

## Limites e continuidade

Peças ainda sem props, composição, encontros/patrulhas/interação ou movimento real
20x32. Próximo: comandos AX desses produtores e prova de acesso de todos os apoios
antes de preencher conteúdo. F9 integral continua aberto, incluindo síntese/
regeneração/reconciliação, assets, recuperação/fluidez/release e área jogável.
Nenhuma medição nova de desempenho in-game; o código do jogo não mudou nesta fatia.
As provas anteriores de T01/retomada continuam somente no seu escopo.

Há uma limitação concreta a resolver em assets/intercâmbio: grass_tile.png.import
e earth_tile.png.import têm bytes diferentes no source e na fixture. O compilador
inclui esses arquivos no digest das dependências; isso explica a diferença entre
pacotes dos dois projetos. Eles ficam fora do manifesto principal legado do runner.
Import09 sincroniza as novas fontes, não corrige essa política de imports. Não
alegar equivalência de pacote/ambiente limpo nem fechar F9-09/11 por esta entrega.

Falhas preservadas e corrigidas: tipagem dos testes; comparação de arrays int/float
no produtor; fixture positiva desconectada (agora também negativo); argv/points do
harness; captura dimensionada pelo projeto de jogo; janelas inicialmente abertas.
Nenhum oráculo de geometria/corpo/folga, cap de snapshot ou expectativa de sucesso
foi reduzido para ocultar falha. Testes de outros domínios não foram repetidos.

Sem master/push/aceite humano/F10 ou atualização do playtest/save pessoal.
