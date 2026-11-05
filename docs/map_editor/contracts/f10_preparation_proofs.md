# F10 Q5 — provas completas de preparação

5/11/2026. Autorização humana: “Vamos fazer as provas completas de preparação.”
Base `11c8c14e`, mesma branch/worktree/fixture. Implementa a primeira frente do
[estudo](../studies/f10_loading_options.md), sem abrir épico ou alterar save.

Provas passivas por pacote em arquivo auxiliar, verificadas pela geometria
canônica em mundos novos. Cobrir todos os batches reais de preparação:
admissão da população, superfícies, interações, homes por perfil e composição.
Sem prova válida/cobertura, usar busca existente. Não transformar miss em
inacessibilidade. Patrulhas/leash e menor caminho permanecem na autoridade atual.
Entrada, manifesto, RNG, políticas e primeira falha mantêm seus contratos.

Propriedade exclusiva: agente preparation_proofs escreve somente novo
`scripts/core/expedition/spatial/preparation_proof_cache.gd`; agente proof_tests
somente novo `tests/map_editor_preparation_proofs_test.gd`. Ambos sem engine.
Sol integra Batch, MapRelease, bake/runners/export, UIDs e documentação;
Luna supervisiona o lote congelado após transferência explícita. Uma engine
e uma fixture, sem escritores de inputs durante execução.

Bundle v1 limitado a 16 MiB brutos, decoder sem objetos, estrutura/tipos/rotas
limitados. Geometria completa, lajes, bloqueios temporários/segmentos, perfil,
entrada e destinos exatos; só namespace de estágio é normalizado. Sem cache
persistido de bool geométrico, mundo/ator/ocupação, RNG ou recompensas.
Memos do verificador nascem vazios; orçamento, revisão e assinatura continuam.
Consulta cancelável ou orçamento customizado pode preservar o caminho integral.
Save/RPP/lista de oito campos permanecem intactos. Bake explícito reproduzível
para os três pacotes; export transporta os arquivos auxiliares.

Validação: cobertura positiva por subset/ordem/duplicata/renomeação; corrupção,
perfil/raiz/destino/geometria diferentes, limites/ciclos e fallback. Comparar
manifesto composto anterior; medir preparação completa e release limpo, com
primeiros movimentos/AI e desvio/conector para revelar aquecimento transferido.
Registrar miss/hit/record e buscas de fallback. Sem merge/master/push ou aceite
humano inferido; Q5 segue aberta até cumprir suas demais obrigações.
