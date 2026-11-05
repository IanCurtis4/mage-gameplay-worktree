# F10 — roteiro de revisão Q5

Atualização em5/11: [encerramento de produto com ressalvas](../../epics/e07/e07_closure_2026_11_05.md).
Este roteiro permanece para as tarefas não reproduzidas; sua existência não
declara que todas foram executadas, e o texto de revisão abaixo é histórico.

4/11/2026. O candidato e as evidências ficam no [checkpoint](f10.md). Este
roteiro não registra aceite por execução de teste automático. Q5 permanece
aberto até as obrigações técnicas e a avaliação humana serem concluídas.

## Preparação

Depois de encerrar os testes, execute [Abrir revisão F10](open_f10_review.ps1)
(botão direito → Executar com PowerShell). O responsável precisa manter a
fixture atual preparada; não é necessário criar outra cópia. O script abre
somente a fixture com perfil descartável, desliga os drivers dos testes e
habilita a aba **Mapas**. Não abre o checkout habitual nem o save pessoal.
O modo `-Preview` apenas informa os caminhos, sem abrir ou alterar a fixture.

Use cópias com nomes próprios e salve em `res://.godot/manual_review_sources/`.
Guarde os arquivos que quiser preservar antes de o responsável voltar a
sincronizar a fixture. Não edite as fontes pessoais ou os quatro backups.

## Editor, sem editar código

**Mostrar dados da peça** abre nome, caminho e recuperação. **Mostrar roteiro
do mapa** abre a lista de etapas; o próximo passo continua visível quando essa
lista está recolhida. Os controles abaixo da prévia continuam acessíveis pela
rolagem, nos modos UX e AX.

Siga as [nove tarefas F9](f9_acceptance_script.md#tarefas), agora na fixture
atual, substituindo apenas o antigo local `.tools/f9_aceite`. A tarefa 1 já foi
aceita pela pessoa em 2/11; repeti-la ajuda a avaliar o percurso como um todo.

Na tarefa 2, mantenha o botão pressionado sem mover: o efeito deve acumular
sob o ponteiro. Mova, solte e desfaça uma vez. Repita cancelando por Escape,
saída da área e perda de foco: a fonte deve ficar intacta. Confira a força por
segundo. Rampa mantém dois extremos; AX continua sendo uma aplicação por traço.

Na tarefa 3, esculpa sob o marcador de entrada e depois mova uma rocha. O
marcador apoiado deve acompanhar o relevo; se continuar inválido, o diagnóstico
deve nomeá-lo e focá-lo. Confira objeto, trava, proteção e desfazer.

Nas tarefas 4–5, confira raro fixo com sorteio desabilitado, sem exigir palco;
corpo/espécie/catálogo continuam obrigatórios. Monte manualmente e por seed,
fixe uma região e regenere outra. Confira que a região protegida, os marcadores,
slots fixos e trechos de patrulha preservados não mudam.

Nas tarefas 6, 8 e 9, rejeite uma proposta e confira a fonte idêntica. Depois
aplique uma proposta revista em cópia, desfaça, simule edição externa/stale e
revise o conflito. Publique com um ID de teste: a revisão anterior deve ficar
preservada e a gravação deve exigir a revisão do plano.

## Jogo

Para testar sem abrir o editor, há uma [versão Windows com terreno e desempenho revisados](f10_terrain_performance.md).
Ele abre no menu normal e permite criar personagens, entrar na floresta,
suspender e retomar. O executável não substitui as tarefas de autoria acima.

No build atual, crie um personagem novo no perfil **RagRPG F10 Q5 Terreno**.
Confira o mapa inteiro no quadrado, bolinhas vermelhas e seta dourada que gira
com o jogador. Cace inimigos fora da câmera e confira que os mortos somem.
Compare cristas, rampas e obstáculos com o chão do jogo: verde é terreno
caminhável, cobre é íngreme e escuro é bloqueio. Observe grupos parados e
em movimento, inclusive perto de bordas, rampas e pontes, mantendo as sombras.
Use roda sobre o cenário e botões −/+; clique no percentual para voltar a 100%.
O HUD/minimapa devem conservar sua escala, e clicar no painel não deve mover
o jogador. Confira a preferência após suspender/retomar e o mapa ao viajar.
Checkpoints do executável anterior continuam sendo testados naquela versão.

Se optar pelo editor descartável, abra o jogo e crie um personagem de teste.
Em qualquer opção, no lobby, escolha **Floresta do Santuário**. Percorra Prado dos Terraços, Vales da
Mata e Covil do Guardião; confira arte e props, terreno/altura, navegação,
combate/retorno, objetivo do estágio, portais, suspensão e retomada. O teste
automático simula mortes e não substitui este combate. Confira também o Bosque
com rampa, ponte, passagem inferior, oclusão e LoS das tarefas 6–7.

Entrada/portais ainda têm pausas longas; os tempos atuais estão no checkpoint.
Não usar o valor antigo medido na vista técnica como prova de fluidez visual.
No editor amplo, a prévia do traço ficou barata, mas o commit ainda pode pausar.

## Registro e decisão

Para cada tarefa, anote tempo, erro, dificuldade, perda de trabalho e eventual
intervenção de código. Informe também se os nomes, a navegação entre telas e
a área visível da prévia são suficientes. Termine com **aceito**, **aceito com
ressalvas** ou **não aceito**, listando o que precisa mudar. Essa decisão não é
inferida dos testes técnicos e não é autorização automática de master/push.
