# E05 — checkpoint único do Berserker

## Autorização e base — 27/09/2026

Usuário testou Defendente, deu aceite e liberou Berserker, incluindo identidade
visual. Candidato do diretório habitual 1e05a65 integrado em master.
Correções posteriores 6f24322 e atlas 9ddf668 existem apenas na branch E05;
preservar, declarar separadamente e incluir na próxima revisão técnica.
Não afirmar que o playtest anterior validou esses dois deltas.

## Ritmo e observabilidade

Continuar na tarefa E05 existente, conduzida por Sol. Pequenos commits por
skill/comportamento, sem handoff separado por skill nem gate Astra por passo.
Atualizar somente tabela curta neste documento: passo, status, hash, testes,
próximo passo e impedimentos. Antes/depois de cada skill, mensagem concisa ao
usuário identificando o passo. Ao esgotar limite, retomar da primeira linha
pendente; commits concluídos não devem ser refeitos.

Registrar tokens/uso por skill apenas se houver medição atribuível disponível;
caso contrário, informar não disponível e registrar tempo/rodadas, sem estimar
percentual da franquia a partir de linhas, duração ou número de testes.
A autorização permite continuar automaticamente entre skills. Não esperar
aceite nem disparar nova tarefa a cada uma. Um pacote consolidado de aceite
no fechamento da classe; escalar antes somente bloqueio/alteração de contrato.

## Escopo

Implementar cinco ativas e duas passivas Berserker já contratadas em
E05_S2_SP_KIT_CONTRACT.md, com precedência dos esclarecimentos de
REVIEW_E05_S2_SP0_ASTRA.md. Ruptura, Obstinação, Salto Cruento, Execução,
Caça Persistente, Fenda Sangrenta e Arrancar Fôlego. Preservar carteiras,
entrada gratuita não autoequipada, regras de ferida/consumo/custo HP, cura,
procs secundários e interação Fúria/Sede. Não reabrir tuning aprovado sem
motivo concreto. Duas builds legais e boss sem adds no fechamento.

Sequência retomável sugerida: decisão de catálogo/compatibilidade; Ruptura e
ferida; Execução; Obstinação; Salto; Caça; Fenda; Arrancar Fôlego; integração
visual; fechamento. Agrupar testes compartilhados sem agrupar todas as skills
num turno gigante. Sol cuida de estado/custoHP/procs/persistência; Terra integra
composições/visual sobre contratos prontos; Luna configura dados fechados se
houver lote útil. Um dono de escrita por arquivo; sem cadeia obrigatória.

## Identidade visual incluída

Direção inicial: fantasia coreana cartunesca de proporções compactas, atlas
64x64 compatível com pivô de pés e animações existentes. Manter continuidade
do Espadachim por cabelo/traços; distinguir pela arma de duas mãos de lâmina
larga, postura inclinada/agressiva e armadura assimétrica leve de ferro escuro,
couro marrom e tecido vermelho. Sem escudo-pavês. Poucos detalhes grandes,
silhueta legível e sombra assentada; evitar aumento de hitbox por tamanho da arma.

VFX: cortes diagonais curtos e ferida com até três marcas legíveis; indicador
claro de cargas/expiração e da conversão, sem depender só de vermelho. Preview
usa geometria real. Sangramento estilizado discreto, sem gore. Reutilizar
ritmo de animação existente e separar apresentação da aplicação de dano.
Produzir arte original pelo fluxo imagegen quando necessário, lendo a skill;
preparação local de bitmaps está autorizada no histórico. Não copiar sprites
comerciais. Atlas/VFX provisórios completos para teste, não exigir arte final.
Astra revisa visual e integração no fechamento da classe, sem gate por asset.

## Critérios de entrega

R0/R1/R5, limites de cargas, expiração, miss/escudo, custoHP não letal e atômico,
sem cascatas, pause/morte/limpeza, duas builds, menu→evoluir→comprar/equipar→
reload→run→XP job além20. Provar os botões admin e seleção em foco no fluxo.
Migração compatível antes de novos ranks persistíveis, save real nunca fixture.
content_ready de berserker somente após fechamento local; manter demais kits
incompletos indisponíveis. Regressões Defendente e três bases; verify.ps1
integral no fechamento, testes dirigidos entre passos.

Entrega consolidada aqui: hash, síntese, evidências e roteiro curto de playtest,
com imagem do atlas se útil. Parar para revisão Astra; não atualizar playtest
ou master, não iniciar outra classe. Sem monitor/automação recorrente.

## Progresso retomável

| Passo | Status / commit | Testes e evidência | Próximo passo / impedimentos |
|---|---|---|---|
| Catálogo 3→4 | Concluído `23bb710` | Migração aditiva de catálogo 3, preservação de build/XP e backup byte a byte, bloqueio de backup mais novo/estranho; 10 checks dirigidos. `tools/verify.ps1` integral passou no Godot 4.7.2. | Registrar sete skills Berserker com `content_ready=false`; nenhum impedimento. |

Tokens por passo: medição atribuível não disponível; não inferir uso semanal.
O schema e o ruleset não mudam. Catálogos 1/2/3 migram ao 4 somente após
validação completa; a migração transacional guarda o original no backup.
Nenhum save real foi usado como fixture ou regravado.
