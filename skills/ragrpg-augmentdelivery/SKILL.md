---
name: ragrpg-augmentdelivery
description: Preparar ou entregar augments autorizados do RagRPG, com receita, elegibilidade por identidade, composição, oferta e prova de gameplay. Usar para novos efeitos ou lotes de conteúdo de augments, não para aprender skills permanentes.
---

# Entregar augments do RagRPG

Resolva a raiz Git do checkout informado/cwd e confirme `project.godot`.
Leia AGENTS.md, docs/WORKFLOW.md, docs/MVP.md, docs/ARCHITECTURE.md,
docs/epics/e06_contract.md e contrato/checkpoint autorizado. Caminhos são da
raiz do projeto; não da instalação. Abra contratos de rodada só por impacto.

## Contratar o efeito

Distinga preencher receita sobre handler existente de criar mecânica. Registre
ID, identidade/origem, habilidade/rank exigidos, efeito observável, stacks,
curva, limites, conflitos, trigger e resultado atual/próximo. Uma descrição
temática não é definição de handler. Se falta escolha de produto, apresente-a;
continue partes independentes, sem iniciar outro épico ou criar chats pela skill.

Augment modifica a build durante a run. Não persistir stack, ensinar habilidade
ou habilitar identidade futura. As dez identidades atuais têm opções próprias;
consulte o catálogo vigente em vez de fixar contagem como regra eterna. Requisitos
usam biblioteca/ranks e executores reais, não só origem ou posição na barra.
Passiva, auto e comando intrínseco exigem elegibilidade explícita.

Verifique `AugmentDefinition`, `BuildEffectCatalog`, `BuildEffectComposer`,
`SkillEffectResolver`, `EffectProcLedger`, `RunState` e `BuildPresentation`.
Catalogue consumidores de emissão, snapshot, mira, custo/recarga e tooltip antes
de novo handler. Conteúdo não insere código em strings nem fórmula em UI/ator.

## Compor sem perder identidade

Definições são imutáveis, fontes têm IDs únicos e recalcular não duplica bônus.
Preview e commit compartilham cálculo/geometria; emissão captura estado por valor.
Preserve ações/projéteis/campos já lançados e contratos locais das classes.
Compatibilidade com equipamentos, cartas e conjuntos passa pelo mesmo compositor;
conflito rejeita a mudança inteira, sem prioridade oculta da última fonte equipada.

Proteja claims por raiz/família/alvo antes dos callbacks; descendentes não criam
cascata por dano, timer ou cópia do pedido. O plano finito vigente de E06-TX
substitui o teto global histórico16; não inventar novo truncamento de efeitos
úteis nem remover budgets mundiais/por kit. Teste com outras fontes equipadas,
não apenas augment isolado. Pausa congela a simulação e preserva estados,
snapshots e recargas; morte, cancelamento e fim limpam somente os estados
previstos no contrato de cada efeito.

Transformação deve mudar decisão/execução observável; texto ou percentual sozinho
não prova rota de gameplay distinta. Use build legal e habilidade realmente
disponível. Lote de nomes/flavor pode ser Luna sobre mecânica congelada; sistema
novo é Sol. Dono exclusivo por arquivo, inclusive catálogos e runner.

## Oferta e entrega

Preserve coleta e escolhas por etapa; não transformar cada abate em oferta.
Escolha normal é manual fora de encontro, pausa a simulação e usa tokens/revisão.
Ofertas permanecem estáveis ao fechar/reabrir; preview não consome RNG.
Confirmar revalida oferta/ganho/conflito, aplica uma vez e consome uma pendência.
Pool com menos de3/vazio, fila acumulada e replay têm resultado explícito, sem
softlock ou reroll por troca de equipamentos. Exceção admin não vira fluxo normal.

Prove utilidade elegível, cap/stack, conflito, receita malformada, rank ausente,
identidade bloqueada, RNG/replay/pool vazio, composição reordenada, miss/zero/letal,
reentrada e snapshot tardio conforme o efeito. Use `tools/verify.ps1` por impacto
e docs/TESTING.md; confirme IDs com `-List`. Teste/presente no renderer com AI
real quando a entrega é gameplay/VFX; fixtures não provam diversão ou FPS.

Checkpoint reúne receita/consumidores, SHA, testes/logs, build demonstrada,
arte/texto atual→próximo e limitações. Luna supervisiona, Sol consolida; Astra
não é gate rotineiro. Documento apenas declara ausência de suíte de gameplay.
Playtest/merge e arquivamento seguem WORKFLOW, sem autorizações implícitas da skill.
