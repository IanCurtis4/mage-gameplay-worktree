# E07-F0 — despacho delimitado

18/10/2026. Usuário pediu criar o próximo chat após I0. Modelo **gpt-6.1-sol /
high**. I0 validado/integrado e arquivado; Astra permanece para arquitetura.
Integração documental: `3d79d83294d6bf1cfa45d7edc9a4cdd2defa86da` (nove fontes
mais recibo), 91 links locais e 32 IDs de testes conferidos, sem gameplay.

## Base e isolamento

Checkout exclusivo reutilizado, inicialmente limpo:
`C:/Users/João Pedro/.codex/worktrees/content-delivery-docs/RagRPG`.
Branch `codex/e07-f0`, criada em `3d79d83294d6bf1cfa45d7edc9a4cdd2defa86da`.
Antes da criação do chat, avançar somente pelo commit deste despacho e registrar
seu SHA completo no prompt/índice. Essa atualização é documental; código-base não muda.
Projeto habitual permanece em codex/playtest, com alterações locais preservadas.
Não aplicar runtime F0 no playtest ou master por efeito deste despacho.

## Resultado e exclusões

Implementar F0 do [plano](../e07_tasks.md): montagem pura reproduzível de uma fase
fixture ramificada, partes/conectores/superfícies, população/objetivos alcançáveis,
caminhos testemunha e falha limitada. Mesmas entradas/versões geram manifesto/hash
iguais ou diagnóstico determinístico. Consumidor fixture consulta o manifesto
efetivo. Não basta esqueleto de classes ou teste que replique resultado esperado.

Fontes: [contrato v1](../e07_contract.md), [mundo](guides/world_geometry.md),
[validação](guides/validation.md), [I0](e07_runtime_inventory.md). Contrato técnico
é consumido; propostas D01–D07 não viram defaults aprovados. Fixture pode definir
policies explicitamente artificiais. Ausência de policy necessária retorna erro.
F0 não implementa renderer/combate 3D, movimentação de ator, UI, loot de produção,
perfil/save, migração, wallet, threat, revive, respawn ou captura/restauração.

## Propriedade exclusiva

Executor F0 possui apenas novos arquivos nestes diretórios exclusivos:

- `scripts/core/expedition/model/*.gd` e respectivos `.uid`;
- `scripts/core/expedition/generation/*.gd` e respectivos `.uid`;
- `scripts/data/expedition/*.gd` e respectivos `.uid`;
- `tests/e07_f0_*.gd` e respectivos `.uid`;
- `tests/fixtures/e07/f0/**` (dados/cenas de teste, sem assets de produção);
- `docs/epics/e07/f0_api.md` e `docs/epics/e07/delivery/f0.md`.

Arquivo existente transferido exclusivamente: `tools/verify.ps1`, somente para
registrar checks F0 e ajustes estritamente necessários ao seu registro. Não
remover/relaxar checks existentes ou mudar tratamento de falhas. Nenhum outro
executor possui o runner durante F0. Não editar atores, main, projeto, catálogos,
UI, profiles, contratos/guias Astra ou índices globais. Expansão de escopo exige
registro/transferência prévia; questão de produto retorna ao humano.

## Validação e entrega

Godot 4.7.2 standard disponível em
`C:/Users/João Pedro/Documents/ChatGPT/RagRPG/.tools/review-engine/Godot.exe`;
conferir versão antes de usar. Não copiar esse diretório ao Git. Conferir `-List`
e executar tools/verify.ps1 da própria worktree com seleção por impacto: import
e testes F0 registrados; regressões adicionais só se houver impacto demonstrado.
Sem save pessoal, export/playtest ou suíte integral automática.

Cobrir I01–I03: Resources imutáveis; entrada/candidatos ordenados; IDs duplicados;
objetivo/slot obrigatório inalcançável; conector invertido/estreito/incompatível;
raio/altura livre; seed adversa; orçamento de busca finito e caminho testemunha.
Validar revisões/hash/canonização, entrada inválida e policies ausentes. Exercitar
geração real e consultas do manifesto, incluindo superfície/conector, sem declarar
que isso prova navegação/renderer jogáveis (F1).

Sol implementa, corrige e valida contrato. Supervisão de execução por subagente
Luna delimitado, se disponível, somente logs/conclusão/erros/hashes; não cria chat
Luna de reserva nem auditoria Astra. Registrar papéis e indisponibilidade real.
Falhas voltam a Sol, sem esconder por mudar expectativas. Manter logs em .godot.

Entregar commit(s) só nos caminhos permitidos, SHA completo, API real estabilizada,
inputs/engine/runner/logs com hashes, limitações e próximo passo. Não integrar
sozinho no playtest, fazer push/merge em master ou autoarquivar. F0 só ficará
arquivável após coordenação validar/integrar a entrega. F1+ aguardam decisões e APIs.
