# Sol — objetos, contexto e marcadores por AX: incremento integrado

Base8601af84; implementação525d2602, fixture corrigida4fde240a e diagnóstico
legado preservado52798508efb7f274fdc3a42959c7af9b2da31c1b. Branch/checkout habituais
codex/map-editor-f9 em .tools/map-editor-m5, fixture F1 única e Godot4.7.2 standard.

## Autoria e execução

Sol escreveu os produtores e integrou o cliente. Luna começou o roteiro de teste,
mas o limite de uso a interrompeu antes da prova nativa; o rascunho está preservado
em luna_initial_draft.gd.txt. Ownership dos dois testes foi transferido a Sol,
que completou os oráculos e executou as provas. Não há supervisão independente
Luna nesta fatia, nem carimbo de revisão semântica independente.

## Entrega do produtor

ObjectOperations fecha os parâmetros sem duplicar assentamento/colisão/catálogo.
ObjectPanel publica operações por ID, seleção editorial, grupos, scatter com hash
revisado/base e descarte. Resultados retornam IDs novos/removidos e posições da
prévia, sem aplicar fonte arbitrária. O cliente abre a janela real via AX e usa
a mesma DocumentSession; mostra snapshot/seleção/preview da tela de objetos.

ContextOperations propõe regras, áreas retangulares com reservas do catálogo e
marcadores. GUI e AX compartilham o operador. Locks origem/destino, região de outro
propósito, seleção inválida, geometria de marcador e erro de arquivo preservam o
documento. Mover área preserva referência de proteção na camada nova; remover
limpa a referência. Não implementa a máscara por canal/regeneração ainda exigida.

## Provas executadas

- Content28 PASS em4fde: GUI/AX/hashes/IDs; apoio superior; mover/girar/copiar/
  remover; grupos/travas/visibilidade apenas editorial; histórico/no-op;
  proteção; catálogo/regras/reservas/regiões/marcadores; preview/hash/stale/
  descarte; Store e reabertura. Primeira fixture usava rocha além do apoio:
  mantida como negativo e posição positiva corrigida, sem reduzir footprint38.
- ContentNative30 PASS em4fde: mesmos28 mais formulário real e imagem de objetos
  com terreno/prop renderizados. Imagem inspecionada por Sol.
- Objects53 regressão PASS em527, incluindo movimento/ataque/LoS e bundle passivo.
  Primeira passagem52/53 encontrou classificação de seleção mudada pela nova
  validação; produtor voltou a object_selection_invalid, sem trocar expectativa.
- Cliente headless/nativo12/12 e reabertura em outro processo PASS em527: fonte
  52c980cc6335d708b3dbb43e69120624521c1648c64b17cfc5f82eb6482bb9ea,
  compilação56ffa85eaf79bab0edf37820d99d73af212465c4d07441046ad600c01e16669d,
  disco060ca259a10d7948dd6cb89aae3c00b38a08d5f15b72d6b9ac97ae08108fa9c1.
  Janela/captura de objetos real inspecionada, logs sem erros genéricos.
- tools/verify.ps1 editor_import PASS1/299 em527, envs descartáveis explícitos.

Não foram repetidas suítes não afetadas nem inferida fluidez de duração de teste.
O único delta após28/30 é a classificação da entrada inválida da seleção, coberta
pela regressão53. Inputs/HEAD foram congelados em cada execução; manifests anexos.

## Consumo por Terra e integração

Terra concluiu A31/31 ações com24props e B30/30 com23props. Contexto floresta,
áreas e entradaA; somente ações sobre a sessão real, compilação antes do save,
Store com expectedHash/backup e reabertura em processos novos com hashes iguais.
Duas receitas B falharam por IDs repetidos antes de salvar; apenas IDs foram
corrigidos, sem deslocar props ou relaxar apoio/colisão. Recibos/capturas preservados
em ../../terra/area_content; Sol inspecionou as duas capturas finais. Conteúdo
integrado em `b14ea3dc9f46bd3f072f41a51cbba5e8053a725a`. Não foi criado novo asset/espécie/quest.

Consumidor Sol: duas peças ligadas em composição efêmera de TESTE, forest,
MapCompiler/Candidate/preparo20x32 PASS. Marcador exato preservado, corpo cabe,
path ida/volta PASS. O início provisório do candidato mapa é comportamento existente;
entrada explícita de população ainda precisa ser configurada pelo editor. Primeiro
diagnóstico presumiu seleção automática e foi preservado como falha de fixture;
segundo confere o socket e o corpo diretamente, sem alterar runtime.
[Relatório reproduzível](consumer_02/report.md) e manifest contêm limites/hashes.

Auditoria manifest_reuse_audit.json:28/30 usam4fde; diferenças atuais somente
ObjectOperations (classificação inválida corrigida527) e dois dados novos. Objects53
usa527 e só diverge nos dados. A regressão cobre a classificação; o novo consumidor
cobre os dados. Primários2028 atuais incluem dois backups e excluem imports;
10 metadados relevantes conferidos separadamente, sem diferença source/fixture.
Não declarar que os manifests históricos inteiros equivalem aos dados novos.

Mapa/preparo canônicos custaram26,056/23,557s; execução completa187,726s incluindo
consultas exatas da entrada e IO, sem tempos individuais dessas consultas. Não é
FPS; custo da navegação segue pendência real10, sem diminuir cobertura/obstáculos.

Composição/população/patrulha parametrizadas, síntese/reconciliação/assets,
recuperação/fluidez/release e área jogável integral continuam abertos. Sem App,
movimento de ator/combate ou gameplay integral novo; sem master/push/F10/playtest
pessoal. Documentação final só conferiu coerência/links, sem repetir suíte de gameplay.

Atributos Git -text limitados a author/ax_content e terra/area_content preservam
bytes exatos de logs/manifests/receitas neste incremento em checkouts novos.
Não normalizar artefatos assinados. A conferência de blob/index fica no recibo
staged_evidence_byte_audit.json. Inventário global de processos não foi obtido
por restrição do sistema; a terminalidade citada vem dos processos aguardados
pelos runners, com exit final, e dos handles de ferramenta encerrados.
