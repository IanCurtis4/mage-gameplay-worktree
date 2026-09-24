# Gate Astra — E05-S0 e autorização S1A

23/09/2026. S0 `6c475a6` aprovado documentalmente contra os contratos E00/E03/E04
 e inspeção de IdentityIds, ProfileCatalog, ProfileCodec e ProfileFacade.
Delta: somente docs/E05_S0_HANDOFF.md. Sem runtime a validar; suíte integral
não repetida. Isto não aprova implementação de evolução nem candidato jogável.

## Decisões do gate

1. ProfileCatalog será o proprietário das definições EvolutionDefinition,
   seguindo seu ciclo de construção/validação/seal. Não criar outro catálogo
   global paralelo. Copiar profundamente entradas e saídas: Resource por si só
   não é imutável. IdentityIds continua autoridade dos IDs e do mapa de origem
   já usado pelo codec; derivar/validar origin_class_id por essa autoridade,
   sem manter um segundo mapa manual independente. Afinidade e branch_kind
   (2-1, 2-2, 2-3) pertencem à definição, não à interpretação do ID pela UI.
2. Registrar as 12 identidades E00 como metadados indisponíveis. Definições
   incompletas intencionais não invalidam todo o catálogo: referências vazias
   são permitidas apenas nesse estado; referências preenchidas erradas nunca.
   Destino pronto exige biblioteca exclusiva coerente, uma ativa de entrada
   gratuita R1 no job 20 e implementação mínima validada. Só haver uma skill
   cadastrada não prova prontidão do runtime. Não habilitar destinos em produção
   em S1A; fixtures isoladas podem simular prontidão sem prometer gameplay.
3. Consulta deve preservar separadamente is_current, requirements_met e
   content_ready, com razões de bloqueio. Um enum resumido pode ser derivado,
   mas current não pode esconder conteúdo indisponível. Consulta não escreve,
   não conserta save e não concede ranks. Perfil com evolução indisponível
   continua carregável; bloqueio de start_run é trabalho explícito de S1B,
   com testes e sem apagar identidade/progresso. Não endurecer codec em S1A.
4. Sem mudança de schema/ruleset/catalog_version neste passo. Primeiro kit
   persistível revisará versionamento e compatibilidade antes de habilitar.
5. Primeiro par de conteúdo previsto: Defendente/Berserker, após infraestrutura.
   Isso ordena o trabalho, não aprova tabelas ou kits ainda não desenhados.

## S1A autorizado — Sol

Implementar somente definição, registro/validação e consulta evolution_options
na fachada, com os estados acima e metadados pt-BR do elenco E00. Preservar
assinaturas e fixtures existentes quando possível. Nenhuma transação, UI,
start_run, skill, ator ou alteração de save neste pacote. Não instalar um
framework genérico de IdentityRuntime antecipadamente.

Testar as 12 identidades, origem direcional (inclusive mg_ar), tipos/afinidades,
duplicatas, entradas erradas, estados incompletos válidos, limites 10/20,
consulta sem escrita, catálogo/retornos isolados, personagem ausente e estado
não disponível da fachada. Cobrir evolução atual porém indisponível sem perder
as razões. Regressões persistent_state, profile_store e
 e03_progression_transactions; importação headless e nova suíte em verify.ps1.

Entrega: commit e docs/E05_S1A_HANDOFF.md com contrato concreto da API,
evidências e limitações. Parar no gate antes de S1B. Terra e Luna entram nos
pacotes seguintes sobre API/dados fechados; não delegar artificialmente este
contrato pequeno entre três modelos. Sem atualização de playtest/master.
