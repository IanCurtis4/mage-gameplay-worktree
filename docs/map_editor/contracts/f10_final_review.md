# Editor F10 — pente-fino e fechamento integrado

25/10/2026. **RESERVADO — aguarda F9 consolidado e aval humano próprio.**
Pedido humano: segundo chat para pente-fino de todo o editor, retomando o papel
de integração/revisão originalmente previsto para F8, antes dos Ex seguintes.
Criar o chat não autoriza execução. Conclusão de F9 não o ativa automaticamente.

## Dependência e referência

Ler o [contrato F9](f9_completion.md), sua matriz/recibo finais e a autorização
humana de ativação. Referência histórica F8 de preparação
`477d257911f1edc33e5d01c5131caee39ea83962`, código F8
`f90511be6aa65262f5b1943a1f518385963a4001`. A base executável será o SHA completo
efetivo do F9 entregue/integrado, resolvido na ativação; não usar a base histórica.

Ler AGENTS, [WORKFLOW](../../WORKFLOW.md), [MVP](../../MVP.md),
[ARCHITECTURE](../../ARCHITECTURE.md), [PRODUCT_DIRECTION](../../PRODUCT_DIRECTION.md),
[REVIEW_WORK_PACKAGES](../../REVIEW_WORK_PACKAGES.md), [índice](../README.md),
[arquitetura](../architecture.md), [execução](../execution.md),
[validação](../validation.md), [UX/AX e autoria dual](../authoring_modes.md), todos
os contratos/recibos pertinentes F0–F9 e decisões humanas posteriores.

## Papel e resultado

Sol conduz revisão técnica e integração, com Luna na supervisão automatizada.
Astra não é gate rotineiro. Revisar código, contrato e experiência real, com
reprodução própria; não só reler o relatório F9 nem somar checks já aprovados.
Concluir um editor utilizável e robusto dentro do produto contratado, pronto
para consumir/produzir conteúdo dos próximos épicos. Não declarar ausência
absoluta de bugs; demonstrar fechamento do escopo e limites de uso medidos.

## Pente-fino obrigatório

1. Conferir todas as linhas F9-01–F9-12 e todo requisito F0–F8, decisões, correções
   e exclusões verdadeiras. Cada promessa precisa corresponder a uma operação
   existente. Não transformar requisito faltante em “opcional/futuro”.
2. Criar peça pequena e área ampla, terreno/curvas/penhasco/material, objetos,
   vegetação, barreiras e emendas; montar mapa manual e por seed, com regiões
   fixadas. Fazer o fluxo completo sem código, nas telas/janelas reais.
3. Verificar contexto de vários biomas, espécies/raros/reservas/quest passiva,
   exceções manuais por instância e ambientação editorial. Reproduzir raro fixo
   manual com sorteio desabilitado e sem palco; catálogo/espécie/corpo continuam
   obrigatórios. Avaliar líderes, solitários fortes e chefe com lacaios como
   composição temática, sem novo gate narrativo.
4. Inspecionar UX: descoberta, nomes, foco/teclado, agrupamento, seleção/camadas,
   minimap/biblioteca/miniaturas/presets/favoritos, inspector, overlays, diagnóstico,
   cliques e rolagem; comparar AX: ações parametrizadas, IDs estáveis, estado,
   falhas claras, automação e autoridade única. Alternância não modifica autoria.
5. Reproduzir navegação pela largura útil, rampas/altura/escala, ponte com passagem
   inferior, oclusão, clique, corpo e LoS. Conferir visual versus colisão/rota de
   objetos e barreiras, frestas, overlap e conectores. Não aceitar alteração da
   amostra para esconder uma falha nem duplicação da autoridade do runtime.
6. Conferir identidades/revisões, catálogo imutável, dependências, hashes,
   determinismo/ordenação/streams, pins/regeneração parcial e stale entre fontes.
   Editar/importar/atualizar versões sem reescrever conteúdo humano em silêncio.
7. Exercitar segurança e falhas: dados inválidos/adversos, tamper/versão/base,
   paths/assets/execução externa, proteção por região, cancelamento, recuperação,
   gravação interrompida, conflito externo e restart. Recusa não altera a fonte
   nem deixa publicação parcial; confirmação/undo preservados em UX e AX.
8. Validar população/patrulha, combate/aggro/retorno, pausa/respawn e continuidade,
   sem duplicar vivos/recompensas. Quest continua referência passiva onde não
   existir consumidor autorizado. Testes não usam save pessoal.
9. Reproduzir GUI/AX/headless, proposta de skills, bundle/asset/dependência,
   publicação local e consumo real em processo release/ambiente limpo. Confirmar
   fronteiras/APIs para os Ex seguintes e tratamento não destrutivo de revisão
   antiga. Não substituir essa prova por exit0 ou por um teste só no editor.
10. Medir responsividade/cancelamento/bake/import/generation/load/save e memória
    nos cenários contratados; justificar amostras/percentis, hardware e limites.
    Detectar travas da interface e custos que inviabilizem a criação cotidiana.
11. Consolidar docs, guias/skills, erros, recibos e roteiro humano final contra o
    comportamento existente. Conferir referências e remover instruções ativas
    obsoletas, preservando histórico/evidências. Fazer a limpeza de artefatos.

## Correções e transferência

Antes de qualquer escrita, confirmar F9 sem escritores ativos, resolver checkout/
branch/base e manifesto nominal, incluindo .uid/cenas/testes/runners/autoridades
compartilhadas. Reutilizar o único worktree corrente conforme [STORAGE](../STORAGE.md),
sem novo checkout. Preparar revisão de modo a não criar escritor simultâneo.

Corrigir falhas residuais de integração e regressões dentro do contrato, com
revalidação por impacto. Omissão funcional substancial pertence à implementação
F9 e precisa de devolução/transferência sequencial explícita, não de aprovação
com ressalva. Não enviar mensagens a outros chats sem autorização humana.
Não fechar F10 enquanto houver requisito contratado faltante, falha bloqueante
ou decisão ainda necessária para uma capacidade declarada pronta.

Escolha de produto nova deve ser apresentada antes do consumidor; correções
contratuais continuam automáticas. Não abrir outro épico, campanha, economia,
quest engine, multiplayer ou conversão de renderer por efeito deste pente-fino.

## Evidência e conclusão

Registrar revisão, achados/reprodução, correções/transferências, matriz de
completude e candidato exato em `docs/map_editor/delivery/f10.md`. Separar provas
autorais F9, reprodução própria F10, supervisão Luna e decisão técnica Sol.
Conservar SHA completo/inputs/engine/logs/hashes/capturas, testes executados e
omitidos, medidas e limites. Aproveitar evidência compatível explicitamente;
não repetir toda suíte por hábito. Seleção abrangente quando justificada pelo
fechamento integrado, com `tools/verify.ps1 -List`, invariantes e inspeção nativa.

Entregar roteiro humano que percorra toda a amostra final e modos manual/seed,
UX/AX, intercâmbio e export. Aceite de uso/visual/produto continua humano e não
é substituído por checklist. Preparação do playtest após aprovação técnica segue
WORKFLOW, preservando alterações locais; master exige aceite explícito sobre o
candidato testado. Sem push/publicação externa automática e sem tocar save pessoal.

A reserva não cria branches/worktrees/fixtures/subagentes, não executa testes,
não agenda retomadas e não arquiva chats anteriores. Após fechamento, preservar
fontes/reprodução mínima/evidências e remover builds/cache/fixture gerados.
