# E05 — checkpoint único do Defendente

## Fluxo aprovado pelo usuário em 26/09/2026

Entregas e commits continuam granulares. Não criar handoff nem gate Astra por
microtarefa. Atualizar este checkpoint curto no lugar de multiplicar documentos.
Sol conduz a classe e revisa contribuições Terra/Luna dentro dos contratos
aprovados. Astra recebe uma entrega consolidada somente ao fechar a classe.
Exceções: bloqueio real, conflito de contrato, mudança de design não aprovada
ou risco concreto para saves que exija decisão externa. Não escalar escolhas
rotineiras de implementação nem pedir aceite a cada habilidade.

Por passo: commit, comportamento concluído, testes pertinentes, pendência e
próximo passo em uma linha/tabela. Não anexar logs integrais ou repetir análise.
Rodar testes dirigidos no delta; verify.ps1 integral no fechamento da classe
ou antes quando alterações compartilhadas justificarem. Não repetir suíte
integral para documentação ou simples variação sobre contrato validado.

## Base revisada

SP1 ddba884 aprovado: identidade/biblioteca resolvida no catálogo, copiada ao
snapshot e filtrada pelo ator. Verificação independente já concluída no log
 e05_sp1_review: importação, 69 suítes/3117 checks e smoke passaram.
Lista vazia em snapshots sintéticos mantém compatibilidade dos testes antigos;
a fachada persistente sempre fornece biblioteca. Este fallback não deve ser
usado por novas fixtures de evolução. Sem novas skills ou migração no SP1.

## Progresso da classe

| Commit | Comportamento fechado e teste | Pendência / próximo passo |
|---|---|---|
| `9ea8bcf` | Catálogo 3 aceita catálogo 2 por migração aditiva, preservando schema 2, ruleset e backup; fixture isolada valida round-trip e rejeição de versão futura. | Registrar sete IDs do Defendente mantendo `content_ready=false`, depois integrar a guarda e as skills. |
| a registrar | Sete IDs, ranks e gates job do Defendente; biblioteca de produção ainda indisponível. Geometria de mira/VFX provisória, sem dano. Testes dirigidos de catálogo, identidade e indicadores passaram. | Integrar guarda/token, cinco ativas, duas passivas e consumidores. |

Decisão de versionamento: os IDs de skill exclusivos passarão a ser ranks
persistíveis, então `catalog_version` sobe de 2 para 3 antes do registro. O
codec só aceita o catálogo 2 com o ruleset atual; valida todos os campos no
catálogo novo antes de o store publicar a migração transacional. O original
fica no backup. Schema e ruleset não mudam, pois o formato e as fórmulas base
não mudam. Nenhum save real é usado como fixture ou regravado nesta tarefa.

## Escopo liberado até a próxima revisão: Defendente completo

Implementar cinco ativas e duas passivas de defender conforme
E05_S2_SP_KIT_CONTRACT.md e esclarecimentos REVIEW_E05_S2_SP0_ASTRA.md:
Contraforte, Vigília, Marco de Guarda, Trava de Linha, Resguardo,
Avanço de Muralha e Onda de Represália. Incluir as passivas explicitamente;
o SP3 antigo não as enumerava. Manter origem swordsman, carteira 19/20,
entrada R1 gratuita não equipada automaticamente e duas builds de referência.

Sol executa guarda/token, integração crítica e versionamento compatível;
Terra compõe skills sobre contratos prontos; Luna configura ranks/textos
fechados quando houver lote útil. Podem ser subagentes da tarefa E05 existente,
com dono único por arquivo e entregas locais ao condutor. Não enviar cada
subentrega para Astra. Não criar novas tarefas por habilidade.

Resolver e documentar versionamento antes de novos ranks persistíveis;
nenhum save real como fixture. content_ready permanece false até o fechamento
integrado local do Defendente; então pode habilitar SOMENTE defender na branch
candidata para revisão. Outras onze evoluções permanecem indisponíveis.
Nenhum kit Berserker neste ciclo: será a classe seguinte, após revisão/aceite.

Aceite integrado: menu→evoluir→comprar/equipar→save/reload→run; ranks R0/R1/R5,
duas builds legais, boss sem adds, frontal/flanco, consumo/deduplicação do token,
interações Parede/Perseverança/Fúria, pausa/morte/limpeza, preview/HUD/runtime,
regressões das três bases e preservação de saves. VFX provisório legível e
mira coerente com geometria; arte final fora do escopo. Informar limites visuais
e de balanceamento, não confundir teste headless com playtest.

Entrega única da classe: hash, resumo funcional, testes e roteiro de playtest
neste documento. Parar para revisão integrada Astra. Não atualizar master ou
playtest; integração e aceite do usuário continuam no fluxo habitual.
