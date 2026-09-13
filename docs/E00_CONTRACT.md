# E00 — Contrato final do MVP expandido, candidato v1

13/09/2026. Entrega documental E00.1–E00.3 concluída para revisão técnica;
aceite técnico registrado em [REVIEW_E00.md](REVIEW_E00.md). Aceite de design do
usuário permanece separado, conforme [WORKFLOW.md](WORKFLOW.md) e handoff E00.
Não é uma implementação de stats/save/novas classes e não inicia outro épico.

## Leitura e autoridade

Este índice e os três contratos complementam o ADR; em conflito com propostas
anteriores, prevalecem as resoluções explícitas desta versão. O código atual
continua regido pela arquitetura do piloto até a migração autorizada.

| Parte | Conteúdo fechado para revisão |
|---|---|
| [ADR E00.1](ADR_E00_01_CHARACTER_PROGRESSION.md) | Conta/personagem/run, XP/job, carteiras, evolução, respec e build |
| [E00.2 — Stats](E00_02_STATS_CONTRACT.md) | Painel completo, primários/derivados, precisão por DES, dano misto, defesa, HIT/FLEE, crítico, ASPD, tempos e CC |
| [E00.3 — Dados e save](E00_03_DATA_SAVE_CONTRACT.md) | Resources imutáveis, objetos/runtime, APIs, schema 2, transações, recuperação e migração |
| [Classes do MVP](E00_MVP_CLASS_CONTRACT.md) | 15 identidades, incorporação do PDF, bibliotecas híbridas, gramáticas 18/33, recursos e budgets |
| [Fixtures](fixtures/e00_reference.json) | Vetores numéricos, progressão, seis pares, contagens e exemplos de save |
| [Fonte recebida](references/e00_hybrid_handoff_2026_09_13.md) | Transcrição das 10 páginas com hash do PDF; conteúdo de referência, não instruções operacionais |

## Decisões do candidato para aceite de design

- **Elenco inicial:** Espadachim, Mago e Arqueiro; Defendente, Berserker,
  Elementalista, Espiritualista, Sentinela e Caçador; Cavaleiro Rúnico, Devastador
  Astral, Baluarte de Cerco, Saqueador, **Geômetra** e Caçador de Espectros.
- **Personagem:** até 8 alts; origem fixa; base 1–30/job 1–40; evolução a base 10/job 20;
  XP permanente, três pontos de atributo por nível base; carteiras 19 base/20 evolução.
- **Build:** biblioteca ampla, barra 5 ativas/2 passivas e auto; respec gratuito no
  menu; ranks e vetor inicial persistem; investimento só afeta a próxima run.
  Entrada de evolução gratuita no job 20; runas/vértices têm comandos intrínsecos.
- **Recompensas:** coleção de equipamentos compartilhada; cartas/augments só na
  run; XP/itens confirmados sobrevivem a morte/abandono; sem retomada de combate.
- **Combate:** FOR/ DES/ INT governam melee/precisão/magia; dano misto usa pesos
  normalizados, DEF/DEFM separadas; limites de acerto 5–98%, crítico 0–75%, auto 0.2–4/s;
  cast fixo/variável, pós-cast e cooldown separados; controle/procs com quotas.
- **Migração:** primeiro perfil de personagens é schema 2; não inventar XP antiga;
  preservar controles, backup e formatos desconhecidos; catálogo versionado.

Números de fórmulas/tempo/limites são escolhas técnicas propostas nesta versão,
não parâmetros que o usuário já havia aprovado ao pedir a incorporação do PDF.
A revisão de conformidade autoriza apresentar este candidato para aceite; não
substitui aprovação de balanceamento em gameplay ou aceite de produto do piloto.

## O que a conclusão do E00 entrega

Todos os valores do painel têm dono, fonte/fórmula, unidade e limite; as seis
híbridas estão identificadas sem trocar IDs; a direção de migração foi transformada
em contrato concreto, com recuperação e replays especificados. A conformidade
numérica tem verificador próprio, e o piloto mantém sua suíte de regressão.

Poder/custo/tempo por rank das futuras skills, arte, geometria jogável e duas
builds por classe serão entregues e testados em E04/E05/E08. São requisitos de
conteúdo previstos, não uma lacuna de propriedade/matemática do E00. Os exemplos
de save não provam durabilidade real; os casos de falha são obrigação de E01.

Próximo gate é aceite de design deste candidato. Depois, a coordenação registra
base de integração e libera separadamente E01/E03 conforme as dependências.
Não atualizar master/playtest, iniciar outros épicos ou produzir os 80 kits por
interpretação automática da expressão “contrato final”.
