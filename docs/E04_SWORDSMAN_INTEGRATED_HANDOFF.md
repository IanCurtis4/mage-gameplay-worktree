# E04-SWI — fechamento integrado do Espadachim

Base `bddb478` (SW1 já entregue). Implementação granular:

| Pacote | Commit | Entrega |
|---|---|---|
| SW2 | `c5ce237` | Provocar e debuffs por fonte/atributo |
| SW3 | `c6e244f` | Perseverança e absorção antes do HP |
| SW4 | `74eba21` | Grito Perfurante, slow e ASPD |
| SW5 | `2a35e19` | Fúria como fonte temporária de stats |
| SW6 | `dce3859` | Golpe Brutal e ordem dano→DEF |
| SW7 | `c6084b4` | Raiva Concentrada em faixa, sem deslocamento |
| SW8 | `889b470` | Grito Aterrorizante com fear e dano recebido |
| SW9 | `45187b4` | Vigor fora de combate |
| SW10 | `6476a30` | Sede de Sangue, VIT investida e cura idempotente |

Biblioteca final: dez ativas (Corte, Investida e oito novas) e três passivas
(Resistência e duas novas), com cinco slots ativos e dois passivos. R0 e
equipagem manual preservados. Nenhum save/preset existente foi invalidado;
catálogo e recursos de rank permanecem imutáveis. Os handoffs SW1–SW10
registram tuning e limites individuais.

## Cenário integrado

`tests/e04_swordsman_integrated_closure_test.gd` passou com 78 checks usando
perfil isolado em `.godot/verification`: compra dos 13 IDs com 19 pontos,
dois presets completos, save/reload, seleção no menu e duas runs reais.

- Defendente: Corte, Parede de Escudos, Provocar, Perseverança e Grito
  Perfurante; Resistência e Vigor. Enfrenta melee/ranged, mantém a postura
  durante as ações defensivas e a encerra no pulso ofensivo. Escudo pessoal,
  debuffs e limpeza de encontro são observados no controller real.
- Berserker: Investida, Fúria, Golpe Brutal, Raiva Concentrada e Grito
  Aterrorizante; Sede de Sangue e Vigor. Confere buff de ATQ, preparo,
  abate/única cura, fear/amplificação e faixa sem deslocamento.

HUD, mira, ranks, snapshot e preview usam os mesmos dados da run. Ambos os
presets fecham encontro, registram recompensa e encerram run sem persistir
estados transitórios. A suíte `tools/verify.ps1` integral passou no Godot
4.7.2, incluindo regressões completas de Mago e Arqueiro. O SWI também
separou IDs de instâncias simultâneas da Barreira Fantasma para preservar
durações próprias no novo contrato de debuffs.

## Gates e limites

Revisão técnica de Astra ainda é necessária para os contratos de debuff,
absorção, cura por abate e fechamento integrado. Não há aprovação de produto
nem medição de FPS. Balanceamento e legibilidade dos VFX provisórios exigem
playtest. Esta branch não atualiza `codex/playtest` nem `master`; E05 não foi
iniciado.
