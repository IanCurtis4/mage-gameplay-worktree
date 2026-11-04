# Skills de entrega de conteúdo

Criadas por pedido humano em17/10/2026. Fontes versionadas em `skills/`; cópias
de uso instaladas em `~/.codex/skills/`. Conferir a revisão antes de presumir
que uma cópia instalada é idêntica à fonte versionada. F9 e F10 Q5 atualizaram
a fonte de mapas; esta entrega não instala ou sobrescreve cópias pessoais.
Raiz do projeto é descoberta no checkout informado, nunca na pasta da instalação.

| Skill | Quando usar | Fonte |
|---|---|---|
| ragrpg-mapdelivery | Partes, montagem, navegação/elevação, portais e integração de mapas autorizados | [SKILL](../skills/ragrpg-mapdelivery/SKILL.md) |
| ragrpg-augmentdelivery | Receita/pool/transformação, elegibilidade, oferta e leitura de augments | [SKILL](../skills/ragrpg-augmentdelivery/SKILL.md) |
| ragrpg-equipmentdelivery | Equipamentos, conjuntos, cartas/encaixes e loot/inventário; contratos futuros de consumíveis/economia quando autorizados | [SKILL](../skills/ragrpg-equipmentdelivery/SKILL.md) |
| ragrpg-enemydelivery | Espécie/ocorrência, AI, população por bioma, progressão e loot de inimigos | [SKILL](../skills/ragrpg-enemydelivery/SKILL.md) |

As skills preparam/seguem contratos, verificam fronteiras do domínio e entregam
checkpoint. Não são autorização para iniciar épicos, fabricar decisões, criar
chats, publicar ou usar save pessoal. Consulta de arquitetura e validação seguem
[WORKFLOW](WORKFLOW.md); não criam gate Astra ou suíte integral obrigatória.

Exemplos: “Use $ragrpg-mapdelivery para preparar o contrato do próximo mapa”;
“Use $ragrpg-equipmentdelivery para entregar este lote de equipamentos aprovado”.
Autoria de nova mecânica difere de preencher receita sobre handler pronto;
não chamar dado de produção quando o consumidor ainda não existe.

Manutenção: editar a fonte versionada, validar com quick_validate.py da skill
skill-creator e conferir referências/decisões; quando a instalação fizer parte
do pedido, sincronizar somente as pastas autorizadas, preservando alterações
locais divergentes. `agents/openai.yaml`
mantém descoberta automática; nenhuma configuração global é alterada.
