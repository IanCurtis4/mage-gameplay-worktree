# Playtest E01 — diagnóstico manual de perfil

Esta cena é uma ferramenta delimitada para verificar a fachada real de perfil E01.
Ela não é menu do jogo, não inicia combate e não usa o save normal: grava somente em
`user://e01_manual_test/`. Não apague essa pasta durante o roteiro; ela é o objeto da
verificação. Para apagar dados de teste depois, faça isso manualmente fora do jogo.

## Como abrir

No editor Godot, abra `scenes/diagnostics/e01_profile_diagnostic.tscn` e pressione
F6. A cena não altera `project.godot` nem substitui a cena principal.

## Roteiro

1. Clique em **Criar alt Espadachim** e **Criar alt Mago**. A lista deve mostrar os
   dois alts, um selecionado, e XP base/job em zero.
2. Selecione o Espadachim e clique em **Iniciar SIMULAÇÃO DE TESTE**. O painel deve
   mostrar o `run_id`, níveis derivados do snapshot e declarar que não há combate real.
3. Clique em **Aplicar augment runtime**. O contador de Vitalidade deve subir apenas
   na run em memória. Ele não aparece como progresso persistente do alt.
4. Clique em **Conceder recompensa local de teste**. XP base/job e a revisão devem
   aumentar. Os valores vêm somente do resolver local da cena.
5. Clique em **Repetir última requisição literal**. A mensagem precisa dizer
   “no-op confirmado”; os mesmos XP e revisão permanecem inalterados. Isso repete
   exatamente request_id, expected_revision, run_id, sequence e reward_id originais.
6. Encerre por vitória, morte ou abandono. A sessão some. Se iniciar outra simulação,
   Vitalidade runtime volta a zero; selecionar o outro alt também não transfere XP.
7. Para testar recovery, inicie uma SIMULAÇÃO DE TESTE, conceda uma recompensa e
   feche o aplicativo sem encerrar. Reabra a mesma cena com F6. `open_profile()` real
   fecha a sessão abandonada, preserva a recompensa confirmada e não retoma combate;
   o log mostra explicitamente o `run_id` fechado na reabertura.

## Resultados esperados e limites

Erros da fachada aparecem no registro inferior com seu código, sem esconder a causa.
Depois que cada alt existe, seu botão de criação fica desabilitado; durante uma run,
ações incompatíveis também ficam desabilitadas. Esta ferramenta não testa combate,
encontros, pools, menu E02, evolução ou retomada de run; “encontro” e “recompensa”
são sempre SIMULAÇÃO DE TESTE.
