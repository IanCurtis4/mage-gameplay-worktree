# Pendências concretas encontradas nesta integração

- Tooling: a fixture M3 Native24 ainda espera canvas.motion/testing e dois filhos
  de malha, anteriores ao App e MapPackageView atuais. Falha/timeout preservados;
  baseline auditado em composition_regression/legacy_native_audit.md. Atualizar ou
  retirar essa fixture do runner vigente antes do fechamento técnico de F9,
  preservando cobertura do comportamento atual, sem mudar expectativas para ocultar falha.
- Bioma de runtime: MapCompiler linha109 inicializa manifest.stages[0].biome em
  ruin mesmo quando authoring_context.biome_id é forest. PopulationCompiler copia
  esse manifesto e não o atualiza. Source/contexto elegível está correto; propagar
  o bioma não vazio ao consumidor final, mantendo o fallback legado quando vazio,
  e testar compatibilidade/invariantes em F9-08/11 antes de declarar floresta ponta a ponta. Não foi alterada nesta fatia.
- UX final: captures do modo AX mostram o mapa real, mas a lista alta do inspector
  pode cortar os últimos controles em janela1000px. O fluxo humano integral e
  layout/rolagem finais continuam exigidos; snapshots/ações AX não certificam UX final.
- Desempenho: custos canônicos de preparação e paths da área decorada ainda altos,
  conforme checkpoint24. Não confundir duração de teste com FPS; perfilar/corrigir
  latências reais antes do playtest. Geração regional/reconciliação/assets/release
  e população/patrulha parametrizadas continuam pendentes no escopo completo.
