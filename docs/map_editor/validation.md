# Validação e aceite do editor

Atualização F8/M8 de25/10/2026: [autoria dual, UX/AX e revisão das lacunas](authoring_modes.md),
[candidato e evidências](delivery/m8.md). A matriz abaixo preserva metas originais;
props/doodads/biblioteca artística e usabilidade humana não ganham certificação
por existirem linhas planejadas. Tema dos raros é diretriz editorial; palco não
é gate para um raro manual. Regras técnicas explícitas de contexto são verificadas.

[Índice](README.md), [arquitetura](architecture.md), [pacotes](execution.md).
Testes abaixo são critérios planejados, não resultados executados ou IDs já
registrados em `tools/verify.ps1`.

## Matriz de prova

| Fronteira | Positivo | Negativo/adverso | Evidência |
|---|---|---|---|
| Fonte/IO | Salvar/reabrir, IDs estáveis, undo/redo e migração em cópia | Arquivo truncado, versão desconhecida, disco indisponível, edição externa | Roundtrip e recuperação da última fonte íntegra |
| Brush | Mesmo traço amostrado gera mesma alteração; trava de camada | FPS diferente, sair da janela no traço, cancelar, atingir conector protegido | Hash/resultado e inspeção de UX |
| Compilação | Fonte idêntica e dependências iguais produzem pacote idêntico | NaN, concavidade/não planaridade inválida, cache obsoleto, job cancelado | Diagnóstico localizado, sem publicação parcial |
| Geometria | Subida, platô e passagem sob ponte | Folga insuficiente, rampa sem conexão, spawn fora de suporte | Travessia real, clique/LoS/ataques em alturas distintas |
| Composição | Duas peças, mapa fixo, variantes e retorno | Conector invertido/estreito, overlap, pin incompatível, objetivo isolado | Testemunhas + prova jogável, seed/revisões |
| População | Dispersão/grupos reproduzíveis, slots fixos preservados | Quota sem espaço, mob grande sem rota, memorável inacessível | Plano canônico, contagens e limpeza no runtime |
| Patrulha | Loop/ida-volta/espera e aggro-retorno | Bloqueio temporário, morte, suspensão na espera, restart | Estado retomado, sem teleportar/duplicar recompensas |
| Geração | Corpus repetível, pins e regeneração regional | Contradição, zero candidatos, limite global, cancelamento | Término limitado e causa; sem fallback silencioso |
| Intercâmbio | GUI e headless equivalentes, diff importável | Base divergente, ID duplicado, asset ausente, traversal de caminho, script | Nenhuma mutação no erro, revisão e hash visíveis |
| Export/runtime | Pacote carrega em release limpo sem ferramenta | Referência só no editor, conteúdo remapeado ausente, revisão antiga | Processo novo, export real e compatibilidade explícita |
| Continuidade | Revisita/suspensão/respawn preservam estado | Publicar nova revisão com expedição antiga, grants repetidos | Versão antiga preservada ou falha explícita sem destruição |

O corpus inicial inclui seed zero, negativo e extremos signed64 textuais, catálogo
reordenado, duas variantes reais, pins conflitantes e caso impossível. Conservar
seeds que encontrarem regressões. Não afirmar prova para toda seed por amostragem.
Casos críticos têm resultado esperado independente do algoritmo sob teste.

Runtime usa Godot 4.7.2 standard e `tools/verify.ps1` por impacto, com `-List`
antes da seleção. Checks F0/F1 são candidatos quando geometria/montagem muda;
F3/F4/F5/F6 quando patrulha atinge captura/ciclo/ameaça. Seleção exata depende do
delta e inventário atual, não de uma lista congelada neste plano. Testes do
editor precisam de registro próprio pelo dono do runner. Reuso de evidência
exige SHA, inputs e fronteira compatíveis; não reexecutar toda E07 por hábito.

## Amostra de aceite humano

Um mapa pequeno com clareira, caminho curvo, platô acessível por rampa, ponte
com rota inferior, bifurcação/beco, santuário e emenda entre duas peças. Duas
texturas/materiais autorizados, vegetação decorativa e rocha bloqueante. Uma
população dispersa, um grupo concentrado e uma patrulha se M5 estiver incluída.
Portal/objetivo usa mecânica existente, sem engine de quest nova.

O usuário deve conseguir, sem editar código:

1. Abrir a biblioteca, criar/duplicar peça e selecionar a camada correta.
2. Esculpir subida/platô, pintar material e proteger conector/caminho.
3. Mover um prop, desfazer/refazer e corrigir um erro clicando no diagnóstico.
4. Pintar população, fixar um slot e modificar uma patrulha quando disponível.
5. Montar duas peças manualmente; gerar variação preservando áreas fixas.
6. Salvar, fechar/reabrir, exportar e testar no jogo em perfil descartável.
7. Confirmar leitura do ator na rampa/ponte, navegação, combate e retorno.
8. Importar proposta de skill em clone, revisar diff e rejeitar sem perder trabalho.

Anotar tempo por tarefa, erros, ações difíceis e intervenções de código exigidas.
Aceite visual/usabilidade é humano; teste automatizado não certifica diversão,
aparência handmade ou clareza. O candidato precisa informar capacidades ausentes.

## Medição e limites

M0 fixa hardware/viewport e cenários pequeno, representativo e estresse. Registrar
área/resolução, células lógicas, triângulos visuais, conectores, props, população
total/ativa e tamanho de fonte/pacote/snapshot. Aumentar uma dimensão por vez.
Medir frio/quente, memória máxima, brush/preview, bake completo/incremental,
cancelamento, import/load, geração, consulta de rota, frame time e captura/save.
Relatar distribuição p50/p95/máximo quando houver amostras suficientes, número de
execuções e método; uma execução isolada não produz percentis úteis.

Hipótese de UX: preview no próximo frame útil e bake pesado com progresso e
cancelamento. Budgets numéricos serão acordados após prova; não anunciar 60FPS,
milhares de mobs ou mapas ilimitados. Separar gargalos de autoria dos do runtime.
Medir a integração com as correções entregues por F8, sem assumir sua tarefa.
O limite vigente de 4MiB é restrição de compatibilidade, não meta de tamanho
aceitável. Exceder limite falha antes de publicar; otimização de persistência
exige escopo nominal, não alteração silenciosa do teto.

## Registro de cada entrega

Recibo contém: autorização, contrato/revisão, modelo/papéis, base/checkout/branch,
arquivos exclusivos, SHA entregue e integrado, decisões, engine/hash, seleção de
testes, conclusão/erros, logs com hashes, seeds/inputs, capturas, medição, limitações
e próximo passo. Luna registra supervisão; Sol registra validação técnica.
Arquivamento e playtest seguem WORKFLOW. Master depende do aceite explícito do
candidato testado; aprovação técnica não o substitui.

## Evidência documental desta rodada —23/10/2026

Produzidos somente os quatro documentos de `docs/map_editor/` e um link no índice
E07. Conferidos brief F8, diagnóstico, normas, contratos F0/F7, modelo de entrada,
definição de parte, assembler/validador, consultas espaciais, planejador de população
e home/leash no ator. APIs novas estão identificadas como propostas.

Fontes externas primárias consultadas: documentação de plugins Godot e repositório
original WFC, vinculados em architecture.md. A documentação stable não substitui
verificação no executável 4.7.2. Nenhuma dependência externa foi instalada.

Validação desta entrega: existência de referências locais, coerência de escopo,
DAG sem ciclo, propriedade sequencial, decisões e diff. **Suíte de gameplay não
executada**, pois não houve runtime/cenas/dados de jogo alterados. Não foi testado
protótipo de editor. Arquivos locais de import/export preexistentes permanecem
fora do escopo. Nenhum chat, branch, merge, push, save ou correção F8 foi iniciado.
