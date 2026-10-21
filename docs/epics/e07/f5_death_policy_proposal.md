# E07-F5 — proposta de morte por identidade

21/10/2026. **APROVADA pelo usuário**: “Aprovar a tabela proposta”, complemento às regras gerais D04
aprovadas neste chat. Não é regra de suspensão/viagem. As dez identidades atuais
estão cobertas abaixo; nenhuma classe ou skill nova.

## Regra comum proposta

No evento de morte, cancelar deslocamento/cast/canal/preparos e ações ainda
pendentes emitidas pelo jogador (projéteis, sequências, ecos, armadilhas, paredes,
barreiras e áreas próprias), sem reembolsar custo. Remover controles/debuffs e
buffs temporários do jogador. Reviver recalcula pela mesma build, depois aplica
50% HP/25% SP. Cooldowns ativos e internos conservam o restante exato; morte
não chama clear de fim de run que zere recargas. Cancelamento não cancela toda
a EffectProcLedger: claims/tombstones e IDs monotônicos continuam para impedir
reentrada tardia ou duplicação. Não recriar RunState, summons ou cargas gastas.
Inimigos conservam HP/SP, posição e seus outros estados; loot e tickets continuam.

| Identidade | Estado temporário removido/cancelado | Conservado |
|---|---|---|
| Espadachim | postura de escudo, Perseverança, Fúria, dash/ataque pendente | recargas, build/augments e claims |
| Mago | cast/canal, projéteis/sequências, paredes/áreas/barreira próprias | recargas e claims, custos pagos |
| Arqueiro | Mira Estendida, abrigo e ataques/projéteis/armadilhas pendentes | recargas e claims, custos pagos |
| Defendente | ficha/guardas temporárias, Âncora, avanço/contra-ataque pendente e lentidão própria da Âncora | recargas incluindo Retorno da Guarda, claims |
| Berserker | feridas como recurso de combo próprio, salto/perseguição pendentes e buffs próprios | recarga interna de Perseguição, claims; dano já aplicado não volta |
| Elementalista | histórico temporário de foco/ressonância, sequências/áreas pendentes | recarga interna do foco, IDs/claims de reembolso já usado |
| Espiritualista | foco temporário, véu/canal/procissão e ecos futuros; marcas de Maldição próprias | recarga interna de recuperação, IDs/claims de reembolso; dano já aplicado não volta |
| Sentinela | Foco acumulado, estabilidade/postura, observação/cargas e preparo; reservas canceladas sem conceder recurso | recargas de habilidades e internas de observação/abertura/intrínseca, claims |
| Caçadora | marca, aberturas, passo/buff, abrigo e armadilhas próprias | recarga interna do passo, claims de ativações/emissões, IDs |
| Geômetra | construção/vértices/figura, disparos/reservas pendentes e reações futuras | elemento selecionado, IDs monotônicos de construção/disparo e claims, recargas |

Não remover efeitos de inimigos ou de outras fontes por uma limpeza global de
Nodes/grupos. Efeitos próprios já aplicados diretamente a um inimigo, como
queimadura/sangramento, conservam o estado capturado; não podem criar nova ação
do morto. Exceções próprias listadas acima (Âncora, feridas/recurso de combo,
Maldição) são removidas explicitamente, sem afetar HP ou outros debuffs do alvo.

Comparar morte real e retry/restauração nas dez identidades: mesmos cooldowns,
claims, recursos e próximo resultado; nenhuma ação cancelada ressuscita.
