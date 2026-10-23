# E07-F8 — roteiro de playtest humano

Usar `play_isolated.cmd` na distribuição Windows para criar um perfil de teste
na própria pasta. No Godot habitual, usar um perfil descartável para este roteiro.
A aprovação técnica não equivale a aceite de gameplay.
Migração do save pessoal não foi autorizada por F8; a interface sempre exige
prévia, destinos completos e confirmação humana do digest.

1. Selecionar um personagem e abrir Expedições. Iniciar Travessia das Ruínas com
   seed42; testar seed43 em outra expedição/personagem. São quatro estágios e
   cinco slots iniciais no total, com duas variantes de ponte; não é campanha extensa.
2. Escolher os dois augments iniciais fora de combate. Atacar sem admin/refill,
   conferir HP/SP, perseguição, ameaça e o primeiro abate por projétil. A partida
   deve voltar do checkpoint ao mundo utilizável, sem ficar pausada após o abate.
3. Explorar rampa, ponte e passagem inferior; conferir piso selecionado, marcador,
   alcance/oclusão e rota para o memorável do santuário. Altura não aumenta dano.
4. Limpar os dois inimigos obrigatórios da entrada, coletar os tickets fora de
   combate e viajar ao ramo lateral. Voltar à entrada; revisita não oferece outro
   augment de entrada. Depois seguir entrada → direita → final.
5. Suspender e retornar ao lobby. Reabrir processo e retomar: mesma seed/montagem,
   build, recursos, recargas e relógios. Outro alt permanece livre. Preparação do
   dono é bloqueada enquanto a expedição está reservada.
6. Morrer e reviver no último portal: mesma expedição/build,50%HP/25%SP e redução
   de120s no relógio; sem boss reaparecido. Após a primeira limpeza, pausa e
   suspensão congelam o relógio global de900s; viajar não o reinicia.
7. Conferir refúgio lateral: suspende sem bônus de conclusão. Retomar e alcançar
   a saída final; limpar/coletar antes de concluir. Bônus único100gold/300EXP Base/
   200EXP Job, sem equipamento garantido; preparação do dono é liberada.
8. Migração somente em cópia descartável de perfil legado: revisar exemplares,
   cartas que acompanham host, destinos/remoções e digest. Abrir prévia não grava;
   alterar destino exige nova confirmação. Não confirmar sugestões automaticamente.

Avaliar legibilidade, input, sensação de combate, pausas ao gravar e balanceamento.
O probe de conclusão usa mortes injetadas para validar transações; não prova que
um personagem consegue vencer toda a campanha nem substitui este roteiro.
Medições técnicas, hashes do candidato/build e custos concretos estão no
[recibo F8](delivery/f8.md). Checkpoints síncronos causam pausas de vários segundos;
registrar a experiência dessas pausas faz parte do aceite humano. Não há prova de60FPS.
Master e push dependem de autorização específica posterior ao aceite do candidato.
