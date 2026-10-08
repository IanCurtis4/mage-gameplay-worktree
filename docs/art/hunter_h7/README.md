# Caçadora H7 — prova nativa com IA ativa

08/10/2026, Godot4.7.2standard, Compatibility/OpenGL, GTX1080.
Cena explícita `res://scenes/diagnostics/hunter_h7_probe.tscn`; jamais lançar
este probe com `--script` sobre a entrada gráfica padrão.

Comando por execução (substituir Godot.exe pelo engine registrado no checkpoint):

```text
Godot.exe --path . res://scenes/diagnostics/hunter_h7_probe.tscn -- hz=30
Godot.exe --path . res://scenes/diagnostics/hunter_h7_probe.tscn -- hz=60
Godot.exe --path . res://scenes/diagnostics/hunter_h7_probe.tscn -- hz=144
```

Cada execução: PASS236 checks/12 capturas, zero falhas/erros. Total708/36.
Logs ignorados `.godot/verification/hunter_h7_native_<hz>.out/.err`.
Preparadora/Emboscadora compradas legalmente19base/20evol; Emboscadora não aprende
Espinhos. Sem facades/stores/perfil pessoal; controles explicitamente isolados.

Boss de treino50.000HP e dano0,18 canônicos. Jogador tem HP/SP provenientes da
build, sem refill, HP artificial ou reset de CD durante combate. Defesa adiciona
três inimigos normais, sujeitos a dano/morte reais. Duração curta exclui reforços
agendados8s; a suíte headless de combate testa também essa onda real.

Só input humano é desligado. Jogador, IA, navegação e projéteis processam
automaticamente. Cada boss anda mais de340px; há ataques hostis, ativação da
Congelante, abertura e consumo por Tiro de Cobertura real, Passo e Cobertura
Total pagos. HUD, piso e três obstáculos permanecem existentes e visíveis.
Capturas01 mostram mecanismo preparando,02 abertura/Marca e03 Passo/cobertura.
Os caps30/60/144 são solicitados ao engine, não taxas medidas nem promessa de
FPS. Capturas não substituem um vídeo, avaliação independente ou partida humana.

Inspeção representativa de todos os caps e das duas builds: sprite próprio com
pés estáveis, marcador de prioridade combinado com entalhes, estados de chão
distintos; HUD não foi ocultado. Os testes verificam as36 gravações, mas não
transformam todas as imagens em aceite de legibilidade. Pisos claro/escuro,
atlas32 células e cenas densas controladas estão em [H6](../hunter_h6/README.md).
Ícones exclusivos preparados em H6 continuam fora da integração global.

A primeira rodada60 teve erro no contador da fixture e revelou acesso tipado
a uma presa já removida no Piche. Não é prova aprovada. Contador usa agora
`hunter_exploit`; runtime revalida antes de converter referências, com regressão
H3 PASS186. Capturas60 foram regeneradas após a correção;30/144 também passaram.
Nenhuma inferência de DPS, equilíbrio, vitória, diversão ou performance global.
