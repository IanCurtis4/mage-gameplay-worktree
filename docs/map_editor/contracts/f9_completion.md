# Editor F9 — completar o editor antes dos próximos épicos

25/10/2026. **EM EXECUÇÃO — autorizado pelo humano: “F8 terminou. Podemos começar F9.”**
Base/propriedade e sequência no [dispatch vigente](f9_dispatch.md);
[matriz de completude](../f9_requirements.md). A reserva abaixo é histórica.
Chat local criado: `01a1741f-bcf1-7bd2-9328-d7a91e514ee4`.
Pedido humano: criar F9 como implementador de todos os pendentes dos Fx anteriores
e F10 como pente-fino integrado; deixar o editor usável e robusto para os Ex
subsequentes. A criação dos chats não inicia os pacotes. Não abre outro épico,
não atribui número E08 nem renomeia retrospectivamente M0–M8.

## Base, fontes e precedência

Referência preparada: `477d257911f1edc33e5d01c5131caee39ea83962`,
branch `codex/map-editor-m8`; código certificado F8
`f90511be6aa65262f5b1943a1f518385963a4001`. A preparação documental posterior
não altera runtime. Na ativação, resolver o SHA completo atualizado; estas
referências históricas não substituem a base executável futura.

Único worktree atual: `C:/Users/João Pedro/Documents/ChatGPT/RagRPG/.tools/map-editor-m5`.
Reutilizar sequencialmente, conforme [STORAGE](../STORAGE.md), sem terceiro
checkout. Principal `codex/playtest`, com alterações locais e save pessoal,
permanece preservado. Não presumir aceite humano do F8 nem autorização de merge.

Ler AGENTS, [WORKFLOW](../../WORKFLOW.md), [MVP](../../MVP.md),
[ARCHITECTURE](../../ARCHITECTURE.md), [PRODUCT_DIRECTION](../../PRODUCT_DIRECTION.md),
[REVIEW_WORK_PACKAGES](../../REVIEW_WORK_PACKAGES.md), [índice](../README.md),
[arquitetura](../architecture.md), [execução](../execution.md),
[validação](../validation.md), [autoria dual/UX/AX](../authoring_modes.md),
[recibo F8](../delivery/m8.md), recibos F0–F7 e contratos abaixo.
Confrontar cada promessa com código/fluxo real, preservando a precedência das
decisões humanas. CLI de workflow ausente nesta base: não copiar tooling externo
nem tratar o diagnóstico como aprovação.

## Resultado de produto

Uma pessoa cria uma peça pequena ou do tamanho de um mapa, esculpe e pinta,
distribui objetos/vegetação, configura fronteiras e encontros, monta um mapa
manual ou usa peças soltas em geração por seed, testa o resultado real e exporta
conteúdo utilizável pelos próximos épicos, sem escrever código. Agentes podem
operar as mesmas autoridades por AX/headless e propor mudanças revisáveis.
Não encerrar como mais um protótipo técnico com requisitos do editor adiados.

## Matriz inicial obrigatória de fechamento

O inventário abaixo é piso. Na ativação, produzir rastreabilidade exaustiva dos
requisitos dos Fx: origem → estado comprovado → ação → prova → resultado.
Não remover uma pendência da lista apenas renomeando-a como opcional/futura.

| ID | Fechamento exigido e prova de uso |
|---|---|
| F9-01 | Props/doodads/vegetação: catálogo com origem/licença, colocar/mover/rotacionar/duplicar/agrupar/remover, seleção e inspector, snap/assentamento, camadas/travas, undo/redo, scatter e exclusões. Decoração, corpo, ataque/LoS e oclusão têm capacidades explícitas; sem collider por folha ou bloqueio invisível. Salvar, reabrir, compilar, importar e exportar preservam tudo. |
| F9-02 | Terreno orgânico e materiais: curvas/silhuetas realmente suavizadas e transições caminho/cobertura/encosta, mantendo suporte/clique/navegação coerentes. Tratar faces não caminháveis/penhascos e limites de inclinação conforme contrato, sem apenas trocar textura ou aumentar tetos. Referência: [semântica da peça e relevo](terrain_piece_semantics.md). |
| F9-03 | Biomas, bordas e emendas: famílias floresta/deserto/planície/ruína e transições previstas, com perfis/arte/envelopes legíveis, dono único e passagens preservadas. Ausência de asset/perfil é falha clara. Sem natação/salto ou outra mecânica implícita. Referência: [composição e emendas](map_composition_and_seams.md). |
| F9-04 | Navegação e precisão: fechar M3-NAV-01, percorrendo a largura útil de conectores quando livre; manter corpo/folga/sentido/colisão. Reproduzir e corrigir os casos F8 de rampa400/altura160 e altura200, com oráculos de escala/altura e erro numérico justificado; não adaptar a amostra para esconder falhas nem relaxar tolerância cegamente. Autoridade canônica compartilhada por editor/jogo. |
| F9-05 | Autoria manual e por seed: mesma peça e contexto, montagem completa manual, geração assistida/variações com regiões internas protegidas e regeneração parcial real. Preservar pins, terreno, objetos, encontros e patrulhas conforme seleção; mostrar diff/diagnóstico/contradição antes de aplicar. WFC permanece opção, não obrigação ou substituição automática do gerador. Não chamar mera troca de peça em slot de síntese regional. |
| F9-06 | Biblioteca e navegação de autoria: busca, miniaturas, categorias, presets de brush, favoritos, minimap, camadas/objetos e diagnóstico localizado. Overlays de altura/suporte, bloqueio, LoS/folga, conectores, encontros e rotas úteis e acionáveis; foco/atalhos, seleção e operações comuns sem ruído excessivo. |
| F9-07 | UX/AX completos: UX guiada/coerente entre as telas; AX com IDs semânticos estáveis em inglês, ações parametrizáveis, inspeção de estado, diagnósticos e operações especializadas de teste/geração sobre as mesmas APIs. Não limitar AX a exibir mais botões. Alternância preserva fonte/histórico/hash; confirmações e invariantes continuam válidas. |
| F9-08 | Encontros e contexto: vários biomas, espécies elegíveis, chance/pesos de raros, reservas e referências passivas de quest. Exceções manuais por instância/regra/motivo com aviso e roundtrip. Raro fixo manual não depende da permissão de sorteio nem de palco obrigatório; ambientação crível é diretriz editorial. Origens/recompensas continuam canônicas. Verificar stale entre revisões de mapa/encontros/patrulhas e reconciliação explícita, sem perder autoria. |
| F9-09 | Intercâmbio e assets: equivalência GUI/AX/CLI, importação revisável com diff/preview/undo, máscaras de proteção por região e reconciliação de base. Completar transporte/referências de assets permitidos e dependências para conteúdo reprodutível em ambiente limpo, preservando segurança do bundle passivo; sem executar scripts/cenas do remetente. Atualizar fontes das skills e guias sem sobrescrever instalações por inferência. |
| F9-10 | Recuperação e responsividade: autosave/backup/pending/conflito externo, falha/cancelamento sem mutação parcial, progresso e descarte de retorno obsoleto, cache verificável e invalidação regional. Tratar os trechos síncronos do F7 que podem bloquear a UI; medir cenários pequeno/representativo/estresse, frio/quente e custos relevantes, com amostragem suficiente e limites honestos. |
| F9-11 | Pipeline de uso real: publicação/revisão imutável, preview do pacote real com apresentação de jogo legível e perfil descartável, restart/continuidade, export release limpo, revisão antiga preservada ou rejeitada sem destruição. Entregar APIs, formato/dependências e ponto de consumo documentados para os Ex seguintes, sem exigir edição manual de scripts a cada mapa. Não confundir isso com criar campanha/quest/economia nova. |
| F9-12 | Área final de aceite: cumprir a [amostra de validação](../validation.md), incluindo clareira, caminho curvo, platô/rampa, ponte e rota inferior, bifurcação/beco, santuário, emenda, vegetação, rocha bloqueante, população dispersa/grupo/patrulha e interação existente. Ambiente temático crível e fluxo humano completo sem código; não só marcadores/protótipos cinzentos. |

Ler também as limitações completas de F1–F8: uma falha antiga que impeça esses
fluxos entra no inventário, mesmo antes rotulada fora do escopo de um produtor.
Cap/budget necessário, exclusão explícita de produto e requisito faltante são
categorias distintas; não prometer escala ilimitada ou ausência universal de bugs.

## Preparação e propriedade na ativação

Responsabilidade operacional Sol; Luna supervisiona lotes congelados por impacto.
Astra só para arquitetura/decisão de produto ou exceção justificada, sem gate
rotineiro. Esforço proporcional; não criar outros chats ou subagentes na reserva.

Antes de editar, conferir dependências/estado local, encerrar escrita F8 e registrar
branch/base completas, contrato e lista nominal de arquivos (inclusive .uid,
testes, cenas, catálogos, shaders e runner). Receber UI/compiladores de F8 por
transferência sequencial. Runtime compartilhado de geometria/navegação precisa
de propriedade nominal conferida com os trabalhos E07; não duplicar autoridade
para evitar essa transferência. Só então implementar. Uma lista de diretórios
neste brief não é manifesto de escrita.

Escolhas de arquitetura que mudem produto devem ser apresentadas ao humano antes
do consumidor. Resolver o restante dentro do contrato sem pedir aprovação por
microtarefa. Se surgir dependência de produto realmente nova, registrar a decisão
concreta; não chamar a funcionalidade de concluída enquanto ela estiver bloqueada.

## Critério de entrega

Zero requisitos do editor incluídos neste fechamento sem conclusão comprovada;
cada linha tem demonstração humana possível, testes pertinentes e evidência.
Corrigir as lacunas identificadas até cumprir o comportamento, sem trocar por
planos ou empurrar implementação esperada para F10. Preservar recibos históricos.
Registrar entrega em `docs/map_editor/delivery/f9.md` e matriz final de fechamento.

Godot4.7.2 standard, GDScript tipado, textos pt-BR, IDs/código em inglês; sem plugins
externos. `tools/verify.ps1 -List`, invariantes e seleção por impacto com Luna;
inspeção nativa, fluxo real, ambiente/export limpo e medição. Logs/erros/timeouts/
hashes e cobertura omitida explícitos. Mesma fixture sequencial e limpeza final.
Aceite humano é separado de aprovação técnica. Sem merge master/push, publicação
externa, save pessoal ou início de E08+ por inferência.

F10 só começa com entrega F9 consolidada, dependências satisfeitas, transferência
de propriedade e aval humano próprio. Este chat F9 permanece disponível para
correções substanciais encontradas na revisão final.
