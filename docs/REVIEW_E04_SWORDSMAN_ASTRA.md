# E04 Espadachim SW1–SW10/SWI — revisão Astra

Entrega cac2299, base 22fab75. **APROVADO tecnicamente para playtest.**
Revisão do pacote completo e dos handoffs.

## Escopo e parecer

Biblioteca de dez ativas e três passivas, cinco slots ativos e dois passivos,
aprendizado R0, ranks e persistência mantidos. Conferidos postura/toggle,
cancelamento de ofensiva válida, movimento sem penalidade e orientação fixa;
Provocar impede fuga do arqueiro sem apagar ataques emitidos; cura por abate
verifica autoria e credita cada vítima uma vez antes da limpeza de encontro.

Debuffs, absorção de escudo e Fúria receberam leitura auxiliar delimitada de
Sol; fechamento e integração pertencem a Astra. Sem achados bloqueadores.

## Evidência

tools/verify.ps1 independente em Godot 4.7.2: importação, 64 suítes,
2.869 checks e smoke aprovados, saída 0. SWI cobre 78 checks.
Após fast-forward no diretório habitual, importação passou sem erro e SWI
passou novamente seus 78 checks. Candidato cac2299 em codex/playtest;
alterações locais preexistentes do editor foram preservadas.
O cenário integrado compra ranks e salva/reabre duas builds por perfil real,
usa HUD e controller, testa ações defensivas/ofensivas e encerra encontros.
Usa XP e reposição de SP como fixtures e dano controlado para finalizar;
isso não demonstra balanceamento da sustentação, dificuldade ou diversão.

## Playtest proposto

- Defendente: Corte, Parede de Escudos, Provocar, Perseverança, Grito
  Perfurante; Resistência e Vigor. Conferir movimento, toggle, proteção
  frontal versus flancos e cancelamento por ofensiva.
- Berserker: Investida, Fúria, Golpe Brutal, Raiva Concentrada, Grito
  Aterrorizante; Sede de Sangue e Vigor. Conferir preparo, risco da Fúria,
  enfraquecimento, cura por abate e manutenção de VIT.

Tuning, legibilidade dos VFX provisórios e desempenho aguardam teste humano.
MGI do Mago segue pendente. Este gate não encerra E04 nem libera E05;
master só avança após aceite explícito do candidato de playtest.
