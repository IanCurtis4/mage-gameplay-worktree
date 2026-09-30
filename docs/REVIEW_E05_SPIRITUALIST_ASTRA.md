# Espiritualista — revisão integrada Astra

30/09/2026. Candidato `f8c59f0`, base aceita `ce87065`.
**Parecer desta rodada: ajustes necessários antes do playtest.**
Não houve atualização de playtest/master nem liberação de classes do Arqueiro.

## Evidências

Inspecionados: migração aditiva catálogo5→6 e proteção de backup, gates e
carteiras, pedidos de dano copiados, marcas/ecos, limite de cura do canal,
procs secundários, fontes de enfraquecimento, sequência de aparições,
cancelamentos/limpeza, integração de atlas, VFX e menu→run.
Não identifiquei bloqueio de persistência ou matemática nesses deltas.

Execução independente de `tools/verify.ps1`, Godot4.7.2: exit0,
113 suítes com contagem e 4.212 checks PASS. Log local ignorado no projeto
habitual: `.tools/spiritualist_astra_verify.log`. Worktree permaneceu limpa
em f8c59f0 durante a execução. Nenhum save real foi fixture.

A prova adicional ignorada `.godot/verification/astra_channel_probe.gd`
reproduziu um caso ausente da suíte: 24 checks originais de Drenagem e uma
asserção de cancelamento da pose; esta última falhou. Ela inicia a pose do
canal, chama `move_to` e observa `character_animation.state.action_remaining`
ainda positivo embora o canal tenha sido cancelado.

## Correções solicitadas em um único pacote

1. **P2 — animação após cancelamento.** `RunController._cancel_spiritualist_drain`
   só encerra estado/tether. `PlayerActor.cancel_active_cast` retorna cedo
   porque o preparo já acabou; a pose de canal2s continua durante movimento.
   Encerrar apresentação quando um canal realmente ativo for interrompido,
   sem apagar a próxima ação. Testar movimento, dano/controle e retorno ao andar.
2. **P2 — pivô do halo.** `_draw_spiritualist_frame` centra todas as imagens
   em48,48; o contrato do halo usa48,63. Em135px, o centro do chão fica cerca
   de21px abaixo do ponto real. Aplicar pivô por asset e conferir no renderer.
3. **P2 — retorno visual da Drenagem.** Os eventos `drain`/`recovery` desenham
   wisp estático; falta a trajetória alvo→caster prevista na receita visual.
   Ligar aos ticks/restituições reais, com fila limitada e limpeza ao interromper.
   Usar os bitmaps existentes; não gerar arte nova.
4. **Cobertura integrada.** `_check_boss` só usa Maldição e deixa RNG contestado
   sem controle. Exercitar uma sequência legal com canal/foco/conversão/aparições
   e acertos determinísticos; misses continuam nas suítes específicas. Incluir
   evidência de renderer para a integração visual, não só existência de texturas.

Ao corrigir efeitos, observar também o redraw quando o último evento expira:
a condição atual verifica as filas após remoção. A sincronização a cada frame
do controlador pode mascarar resíduos do CanvasItem em uso isolado.

Sol recebeu os achados e o aviso de término da execução independente. Próximo
passo: corrigir dentro do mesmo escopo, atualizar checkpoint único, repetir
testes afetados e regressão integral, devolver o delta para revisão consolidada.
Esta revisão não atesta legibilidade em partida, FPS ou balanceamento.

## Reavaliação do delta — 30/09/2026

Após o pacote de correção `a4c34f3`, Astra aprovou tecnicamente a integração
do Espiritualista. O parecer de ajustes acima fica preservado como histórico;
os quatro achados estão resolvidos no delta. Foram inspecionados diff de
runtime/testes e as duas capturas do renderer real. Astra repetiu de modo
independente Drenagem (28 checks), visuais (23), Recolhimento (16) e fluxo
integrado (86): 153 checks PASS, sem ERROR. A suíte integral do delta passou
na execução do implementador, além da suíte independente do candidato anterior.
Sem bloqueio técnico remanescente para preparar `codex/playtest`.

Esta aprovação não substitui o playtest do usuário: sensação de combate,
legibilidade sob múltiplos efeitos, FPS e balanceamento ainda precisam de
avaliação na partida. `master` e as classes do Arqueiro continuam aguardando
aceite explícito do usuário.
