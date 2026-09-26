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
| `8f8b602` | Sete IDs, ranks e gates job do Defendente; biblioteca de produção ainda indisponível. Geometria de mira/VFX provisória, sem dano. Testes dirigidos de catálogo, identidade e indicadores passaram. | Integrar guarda/token, cinco ativas, duas passivas e consumidores. |
| `219dbfe` | Contraforte R1, janela frontal capturada, mitigação máxima (sem soma), token de 8 s, consumo no commit, interceptação e Resguardo equipável; fixture de ator cobre 11 invariantes. | Conectar input/HUD/controller, Marco, Trava, Avanço, Onda e Vigília. |
| `a5857da` | Cinco ativas e duas passivas conectadas ao ator/controller; Marco aplica/retira slow por posição, Trava usa CC canônico, Avanço/Onda empurram só normais após dano real. Teste dirigido 15 checks; `tools/verify.ps1` passou integralmente com `content_ready=false`. | Fechar invariantes de boss, duas builds e persistência/UI; só então habilitar Defendente e repetir verify. |
| `5315f4d` | Duas builds de 13/19 base e 16/20 ou 15/20 evolução compradas/equipadas, persistidas e carregadas em run; R0/R1/R5, boss sem adds, pausa, flanco, saída do Marco e procs secundários testados. Apenas Defendente recebe `content_ready=true`. `tools/verify.ps1` integral (75 suítes) e smoke headless passaram no Godot 4.7.2. | Checkpoint consolidado para revisão técnica Astra; depois rebase/branch de playtest, sem merge antes do aceite do usuário. |

## Roteiro de playtest após revisão Astra

1. No menu, evoluir um Espadachim elegível, confirmar o Contraforte R1 gratuito sem autoequipamento, comprar/equipar cada uma das duas builds da tabela do contrato e reiniciar o jogo para verificar o reload.
2. Na arena, observar mira de cone/faixa/Marco/Avanço, bônus de DEF e slow só dentro do Marco; testar Onda no Marco e fora dele, parede frontal/flanco, escudo de Perseverança, Fúria e SP de Resguardo.
3. Em boss sem adds, confirmar dano da Trava/Onda com CC dentro do orçamento e sem empurrão; testar pausa, morte, fim de encontro e volta ao menu para ausência de zona/token remanescente.

VFX e mira são provisórios, sem arte final. Os testes headless cobrem regras e fluxos de UI/persistência, mas não substituem percepção visual, jogabilidade nem balanceamento no Godot interativo. Nenhum save real foi usado nos testes. `master` e `codex/playtest` não foram alteradas.

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

## Revisão integrada Astra — rodada 1

Candidato a6eedf7: verify.ps1 independente passou integralmente, mas o gate
permanece aberto pelos achados abaixo. Não atualizar playtest/master.

1. P1, ProfileStore._guard_existing_backup: o novo migrated=true de catálogo 2
   causa retorno antecipado antes de comparar profile_id/revision do backup.
   Primary cat2 rev4 + backup cat2 rev9 (ou outro profile_id) pode migrar e
   sobrescrever o backup protegido. Separar migração de catálogo (identidade e
   revisão preservadas) de schema legado. Fixtures devem exigir preservação
   byte a byte dos dois arquivos e readonly/recovery_required nesses casos;
   migração normal com backup compatível continua funcionando.
2. P2, PlayerActor: Avanço ativa defender_advance_guard_active, mas Raiva
   Concentrada cancela _dash_active sem limpar guarda/alvos. Pode deixar 20%
   de mitigação frontal após o fim do movimento. Centralizar limpeza em toda
   interrupção/substituição do dash (incluindo Investida base), morte e fim.
   Testar Avanço -> Raiva, dano frontal após cancelamento, e troca por Investida.
3. P2, RunController._on_enemy_damage_resolved: whitelist de Vigília omite
   brutal_strike e concentrated_rage, ambos golpes melee diretos da base.
   Incluir os golpes corretos e testar ambos com passiva equipada, ausência
   da passiva, miss/escudo/secondary; não ampliar para DoT ou gritos por acidente.
4. Feedback necessário para playtest: token e janela frontal de Contraforte
   só existem em estado interno. Mostrar token disponível/consumo/expiração
   e frente da guarda por indicador simples/HUD, alimentados pelo runtime.
   Não produzir arte final nem alterar dano por animação.

Correção consolidada autorizada na tarefa E05; mesmo checkpoint, pequenos
commits, uma entrega final da classe. Testes dirigidos dos achados e verificação
integral final, pois há persistência/combate compartilhados. Sem novo kit.

## Correção consolidada — rodada 1

| Commit | Fechamento dirigido |
|---|---|
| `b521ae7` | Backup de catálogo 2 mais novo ou de outro perfil exige `recovery_required` somente leitura sem alterar nenhum dos dois arquivos; backup compatível migra. Schema 1 não tem identidade comparável: dois arquivos distintos ficam para recuperação explícita, mas a cópia byte a byte do backup para o primário segue migrando. Migração E05: 13 checks; persistência E01: 90 checks. |
| `1f918e4` | Uma rotina encerra deslocamento, guarda e alvos do Avanço em Raiva Concentrada, substituição por Investida, interrupção, morte e fim de encontro. Reproduções dirigidas: Avanço→Raiva, dano frontal sem mitigação residual, troca por Investida e limpeza. |
| `9eb7f4e` | Vigília inclui Golpe Brutal e Raiva Concentrada entre os golpes melee diretos; não se aplica sem passiva equipada, em erro, escudo integral, dano secundário ou grito. Teste novo: 7 checks. |
| `43656aa` | HUD indica token disponível, consumido e expirado; arco no personagem indica a frente da guarda do Contraforte/Avanço. Estado e prazos vêm do runtime e pausam com a simulação. Guarda: 17 checks. |

`tools/verify.ps1` passou integralmente após os quatro commits no Godot 4.7.2:
76 suítes, importação e smoke headless. Worktree limpo, sem saves reais como
fixture e sem alterações em `master` ou `codex/playtest`. O feedback visual é
provisório e requer conferência no playtest interativo; aprovação técnica Astra
e aceite do usuário continuam pendentes antes do fluxo de integração/merge.

## Revisão Astra — rodada 2

7937683: correções de Vigília, cancelamento do Avanço e feedback conferidas.
Proteção de backups cat2 também corrigida. verify.ps1 independente passou.
Gate permanece bloqueado por regressão introduzida no tratamento schema1:

ProfileStore._guard_existing_backup agora rejeita qualquer combinação que
contenha migration_kind=schema_v1, exceto dois arquivos schema1 idênticos.
Após migração normal, primary é schema2 e backup é o schema1 original; portanto
a próxima gravação retorna recovery_required. Reproduzido isoladamente em
.godot/verification/astra_schema1_followup.gd: MIGRATION_OK=true,
NEXT_COMMIT_OK=false ERROR=recovery_required. Reload isolado passa, por isso
os testes existentes não detectam o bloqueio da primeira mutação posterior.

Corrigir preservando a proteção de backups mais novos/de outro perfil. Não
remover genericamente a proteção de backup legado: reconhecer com segurança
o backup de origem da migração ou preservar o legado por estratégia explícita
compatível. Testar migração schema1 -> reload -> criar personagem/commit ->
reload, inclusive migração a partir de backup e pares legados conflitantes.
Manter o original recuperável e nenhum save real usado como fixture.
Uma entrega consolidada da correção com regressões de persistência e verificação
final. Playtest/master não atualizados até resolver este bloqueio.
