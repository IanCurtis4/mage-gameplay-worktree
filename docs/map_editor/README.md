# Editor de mapas — proposta de arquitetura e execução

## Decisão humana vigente —24/10/2026

O usuário retirou o encerramento, aceite do teste e integração das correções E07
como pré-requisitos do editor: a amostra será suplantada pelos mapas autorados.
Editor F0 (M0) pode continuar sem essa espera. Isso não declara E07 aprovado nem
seus bugs corrigidos; as autoridades reaproveitadas serão verificadas por impacto
com fixtures do editor. Não abre F1/M1 automaticamente.

D1 aprovada: **dentro do Godot, em tela própria amigável**. D3 aprovada:
**grade por camada + pontes/rampas especiais**. D2 continua pendente antes do
bake visual M2; D4 antes do aceite M2. O status desta rodada está no
[recibo M0](delivery/m0.md) e no [contrato candidato](contracts/m0_preparation.md).
Os parágrafos datados de23/10 abaixo registram a proposta original; a dependência
de F8 integrada fica substituída por esta decisão.

23/10/2026. Entrega documental solicitada pelo usuário: consolidar o brief,
autoria manual de mapas/peças, geração assistida, brushes, navegação, patrulhas
e intercâmbio com skills; deixar chats de execução preparados. **Planejamento
entregue; implementação e chats ainda não iniciados.** Não atribui número de
épico nem abre E08. Correções de performance/rampa pertencem exclusivamente ao
chat F8, conforme orientação humana nesta conversa.

## Leitura e origem

- [Arquitetura, dados e ferramentas](architecture.md).
- [Pacotes, dependências e prompts de despacho](execution.md).
- [Validação, aceites e registro desta entrega](validation.md).
- [Composição manual/algorítmica e barreiras de bioma](contracts/map_composition_and_seams.md):
  direção humana de24/10, edição de mapas completos e emendas legíveis.
- Normas: [WORKFLOW](../WORKFLOW.md), [MVP](../MVP.md),
  [ARCHITECTURE](../ARCHITECTURE.md), [direção](../PRODUCT_DIRECTION.md),
  [skills](../DELIVERY_SKILLS.md) e [gate visual](../gates/low_poly_environments.md).

Brief lido diretamente no worktree F8:
`C:/Users/João Pedro/.codex/worktrees/e07-f8/RagRPG/docs/epics/e07/map_editor_brief.md`.
SHA256 `d2d392c1193c722f2ca85b2bb16a45a7295b35ef4129a16ba386d0dd57d5b3a7`.
Também foi lido `f8_performance_investigation.md` naquela pasta. Esses arquivos
não foram alterados nem copiados para disputar sua propriedade. Os requisitos
relevantes estão consolidados aqui; os relatos de diagnóstico continuam no F8.

Base inspecionada: `fba777b3822356a10e7f6e050971e54ab1a9819b`,
`codex/playtest`, `C:/Users/João Pedro/Documents/ChatGPT/RagRPG`.
Essa base documenta a análise; cada dispatch resolve SHA e checkout próprios.
A integração F8 deixou de ser pré-requisito pela decisão de24/10 acima.

## Resultado desejado

Uma pessoa cria uma clareira, esculpe um platô, desenha a subida, pinta materiais,
encaixa uma ponte, distribui vegetação e inimigos, define uma patrulha, testa
travessia/combate e salva uma peça reutilizável sem escrever GDScript. Pode
montar o mapa inteiro à mão, gerar variações respeitando regiões fixas ou deixar
uma receita escolher peças. O mesmo conteúdo pode ser proposto por uma skill,
revisado visualmente e validado pelo mesmo compilador.

Referências Age of Mythology/Warcraft 3 orientam a experiência de autoria:
paletas, pincéis, camadas, objetos e teste rápido. Não implicam copiar assets,
implementar RTS ou reproduzir todos os sistemas de triggers desses jogos.

## Escopo em entregas utilizáveis

| Entrega | O que a pessoa consegue fazer |
|---|---|
| Vertical inicial | Criar uma peça com altura, dois materiais, conector, salvar/reabrir, desfazer/refazer e testar em perfil descartável |
| Autoria manual completa | Editar terreno e bloqueios, camadas sobrepostas, props, emendas e mapa composto; diagnosticar acessibilidade |
| Encontros | Pintar populações dispersas/concentradas, fixar slots, marcar portais/objetivos existentes; depois testar patrulhas reais |
| Geração assistida | Fixar regiões, escolher variantes, comparar seeds e experimentar solver de restrições/WFC com diagnóstico |
| Pipeline para skills | Exportar brief e dados, importar proposta com diff, validar, testar e publicar versão imutável |

Undo/redo, recuperação de rascunho, seleção de camada, diagnóstico localizado,
controle de versões e teste isolado são fundações, não acabamento opcional.
Biblioteca pesquisável, miniaturas, presets de brush, favoritos e comparação
antes/depois reduzem o custo da autoria cotidiana. Minimap e visualização das
rotas ajudam a avaliar mapas maiores sem prometer escala ainda não medida.

Fora desta proposta: editor colaborativo online, marketplace, código arbitrário
em mapas, engine genérica de quests/cinemáticas, voxel, erosão hidráulica,
simulação de água, novos mobs/classes/economia e conversão integral para 3D.
NPCs podem ter marcadores de autoria; comportamento interativo novo exige
consumidor próprio. Uma ferramenta não torna uma mecânica existente por exibi-la.

## Decisões antes dos consumidores

As recomendações abaixo registram a proposta original. D1/D3 foram aprovadas
em24/10 conforme o registro acima; D2/D4 seguem seus prazos por consumidor,
assim como D5/D6. Alterações técnicas dentro da escolha aprovada ficam com Sol.

| ID | Recomendação | Alternativa / consequência | Momento |
|---|---|---|---|
| D1 — hospedagem | Plugin interno Godot com tela própria amigável, sem dependências externas | Aplicativo dedicado dispensa Godot na autoria, mas exige empacotamento e infraestrutura adicionais | Antes de M1 |
| D2 — apresentação | Prova comparativa pequena do renderer corrigido F8 e de cenário híbrido, se autorizado; decidir pela legibilidade/custo | Manter 2D pode limitar materiais/oclusão; híbrido amplia fronteira e exige aceite visual | Antes do bake visual M2 |
| D3 — terreno | Grade de alturas editável por camada + superfícies especiais para pontes/rampas; compilação para células válidas | Malha livre oferece liberdade, mas aumenta custo de edição/validação | Antes de M1/M2 |
| D4 — primeiras metas | Área pequena representativa: clareira, platô, passagem sob ponte, duas peças e um encontro | Fixar dimensões, resolução, hardware e budgets após medição M0, sem herdar quota F7 | Antes de aceitar M2 |
| D5 — patrulhas | Loop/ida e volta, espera, aggro interrompe, retorno a waypoint validado; home de leash fixo | Home móvel altera comportamento de combate e precisa de decisão distinta | Antes de M5 |
| D6 — geração | Composição manual + assembler existente primeiro; WFC opcional depois | Trocar o gerador de produção de imediato aumenta risco de reprodutibilidade | Antes de M6 |

Uma versão fixa de mapa continua passando pela geometria/validação canônica.
Não há obrigação de aleatoriedade. Primeira entrega não depende de WFC nem de
patrulhas. Os pacotes avançam por dependência e autorização; não por criação
antecipada de todos os chats.
