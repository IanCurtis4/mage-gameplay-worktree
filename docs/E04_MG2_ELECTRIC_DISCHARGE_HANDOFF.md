# E04-MG2 — Descarga Elétrica

Base: `7d87204`. Escopo: somente Descarga Elétrica e consumo da marca de MG1,
conforme [sequência aprovada](E04_MAGE_EXPANSION_PACKAGES.md). Não inicia MG3.

## Design e tabela

Skillshot linear de um impacto, sem homing: direção fixa na emissão, bloqueio por
obstáculo e alcance máximo 560. Dano mágico contestado por HIT/FLEE, crítico
canônico, preparo variável de 0,30 s escalado por DES, velocidade 800 e recarga
base 5,0 s. O crescimento marginal de dano e SP decresce entre R1 e R5.

| Rank | Dano-base × ataque mágico | SP |
|---|---:|---:|
| R1 | 1,10 | 18 |
| R2 | 1,28 | 20 |
| R3 | 1,44 | 22 |
| R4 | 1,58 | 23 |
| R5 | 1,70 | 24 |

Se o alvo estiver Eletrizado no impacto, o projétil acrescenta `0,45 × ataque
mágico` capturado na emissão ao mesmo `DamageRequest`, antes da mitigação e do
crítico. É bônus garantido **ao golpe que acerta**, não um ataque secundário nem
um proc de dano. Falha geométrica, erro de HIT ou dano zero não consomem marca.
Após acerto marcado com dano positivo, a marca é consumida inclusive quando a
chance de stun falha. Há exatamente uma rolagem por impacto marcado válido:
25% de stun por 0,6 s. Um alvo sem marca recebe apenas o dano-base.

Stun é família própria de `HardControlState`, com resistência mágica a controle,
imunidade `unstoppable`, teto e orçamento de boss já existentes. Enquanto ativo,
inimigos não iniciam ataques nem deslocamento; root continua impedindo somente
deslocamento. Ações/projéteis já emitidos não são retroativamente cancelados.
Pausa congela o controle; morte e limpeza de status removem stun e marca.

## Integração, prova e limites

- `electric_discharge` entra na biblioteca persistente do Mago em R0; cinco
  slots ativos e dois passivos não mudam. Aprender não equipa automaticamente.
- Menu apresenta “Descarga Elétrica”; preset salvo/reaberto governa HUD, mira,
  cast e runtime. Projétil e marca têm sinais provisórios legíveis, sem arte final.
- `tests/e04_mage_electric_discharge_rank_integration_test.gd` cobre tabela,
  R0/inválido, R1/R5, SP, snapshot, menu/save/reload/run, interrupção de IA,
  boss/imunidade, pausa/morte, acerto com/sem marca, miss, proc/não-proc.
- Import headless do Godot 4.7.2 passou; `tools/verify.ps1` completo passou
  após a última correção, com `E04 MG2 Descarga Elétrica: PASS (69 checks)`.

O stun deste pacote atinge inimigos via projétil do jogador. Não cria ataque
inimigo que atordoe o jogador, não adiciona resistência elemental, augments ou
controle de área. Revisão independente do contrato de controle/cascata cabe a
Astra no gate proporcional; playtest e `codex/playtest` não são atualizados aqui.
Próximo checkpoint autorizado sob novo comando: MG3, Parede de Raios.
