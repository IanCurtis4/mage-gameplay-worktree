# Composição de mapas e emendas por bioma — direção aprovada

24/10/2026. Requisito humano acrescentado durante Editor F0/M0: tratar o mapa
como quebra-cabeça contíguo, editar peças e mapas completos, escolher conexões
e montagem manual ou algorítmica, e representar regiões impassáveis com barreiras
coerentes com o bioma. É direção de produto aprovada; os campos abaixo detalham
o contrato candidato a congelar pelos produtores. Não autoriza catálogo novo,
WFC obrigatório, mecânica de água ou implementação antecipada de M3/M6.

## Uma fronteira geométrica e sua apresentação

Cada trecho da borda de uma peça tem classificação editorial explícita:
passagem por conector, borda fechada ou transição decorativa sem passagem.
Uma borda livre durante autoria pode existir como rascunho, mas não se publica
como limite impassável sem geometria e apresentação correspondentes. O editor
mostra abertura sem destino, fresta involuntária, barreira sem bloqueio e
bloqueio sem representação visual como diagnósticos distintos.

Conector é abertura com superfície, posição, normal, largura e folga reais.
Vincular dois conectores exige coincidência compatível de transformação,
altura/suporte e perfil de travessia; não basta igualdade de tags. O link
produz uma única passagem, sem barreira atravessando sua largura útil.
Demais trechos da emenda e perímetro externo continuam fechados conforme
autoria, sem frestas que permitam sair do mapa por acidente.

As barreiras do bioma representam os trechos fechados. Seu envelope de bloqueio
de corpo deve concordar com a leitura visual, inclusive câmera/oclusão e escala
do ator. A decoração se assenta nesse envelope; não decide navegação por pixel.
Bloqueio de ataque/LoS e corpo são capacidades distintas: cacto, folha ou água
não bloqueiam tudo por inferência. A geometria canônica permanece a autoridade.
Folhagens de acabamento não recebem centenas de colliders individuais.

| Bioma / ambiente proposto pelo usuário | Linguagem de barreira | Condição de legibilidade |
|---|---|---|
| Deserto | Montes e cactos altos | Relevo e agrupamento devem justificar a faixa fechada, sem pequenas brechas visuais transitáveis |
| Floresta | Mata, árvores densas e cobertura de folhagens | Densidade/raízes/obstáculo mostram fechamento; copa não oculta uma passagem necessária ou o ator sem tratamento |
| Planície | Córregos | Margem, desnível ou obstáculo devem justificar a restrição; um fio de água raso não parece muro. Não introduz natação/salto automaticamente |
| Ruína | Escombros e ruínas largas | Volume/altura sustentam bloqueio; vãos aparentes precisam ser passagem real ou fechamento visível |

São famílias de autoria, não assets já entregues nem colliders determinados.
Transição entre biomas requer preset compatível ou autoria explícita da emenda;
não alternar abruptamente vegetação para esconder buraco. Variação visual pode
ser sorteada por seed/versão preservando passagem e envelope lógico aprovados.
Nenhum scatter fecha conector, rota protegida ou acesso de objetivo.

## Contrato editorial candidato para M2/M3

- Peça: identidade/revisão, conectores e trechos de fronteira identificáveis,
  classificação, perfil visual de bioma e referências de bloqueio reais.
  Trechos são spans/arestas estáveis, sem depender da ordem de triângulos do bake.
- Perfil de emenda/barreira: ID/revisão, biomas/pares permitidos, assets
  autorizados, envelopes, capacidades físicas, transformações e seed visual.
  Uma mesma fronteira tem dono único para não duplicar sólidos ou decoração.
- Vínculo: IDs das instâncias/conectores, transformação relativa, perfil de
  transição e exceções autoradas explícitas; nunca corrigir altura, largura,
  espelhamento ou escala silenciosamente.
- Composição: instâncias de versões imutáveis, transformações fixadas, vínculos,
  regiões protegidas, tratamento de bordas externas, seed/revisões e modo.
  Excluir/revisar peça mostra links e emendas afetados antes da aplicação.

O formato exato dos spans e a conversão para sólidos/células serão fechados com
o bake M2 e adaptador M3. Não adicionar campos editoriais ao schema fechado do
assembler E07; compilar para capacidades existentes ou propor delta versionado.
Uma emenda visual não pode compensar colisão ou conexão inválida.

## Edição de peça e edição de mapa completo

O editor deve oferecer dois contextos ligados: abrir/criar uma peça e montar
um mapa com instâncias dessas peças. Na composição, o usuário move/rotaciona
conforme capacidades permitidas, escolhe o que conecta aonde, vê emendas e
perímetro, inspeciona caminhos e testa a área completa. Alteração de definição
compartilhada versus ajuste da instância precisa ser explícita; não alterar
todas as peças iguais por acidente. Undo/redo e diff preservam os vínculos.

Modos do documento de composição:

| Modo | Autoridade da montagem |
|---|---|
| `manual` | Posições/rotações e vínculos definidos pelo usuário; compilar preserva tudo ou falha com diagnóstico |
| `algorithmic` | Receita/candidatos/restrições e seed produzem manifesto validado; algoritmo é versionado |
| `constrained` | Região/instância/vínculo fixado manualmente sobrevive à geração do restante; depende de suporte real do solver |

O terceiro modo detalha geração assistida já planejada, sem torná-la requisito
para entregar o modo manual. UI só habilita capacidades implementadas. Escolher
algorítmico não escolhe automaticamente WFC: M6 compara com o assembler atual.
WFC pode garantir compatibilidade local dentro de suas regras, mas não substitui
conectividade global, largura útil, suporte, ausência de overlap e acesso a
objetivos/inimigos. Mapa manual passa pela mesma validação global.

## Entregas e provas

M1 reserva a referência de composição e IDs sem implementar solver ou anunciar
montagem utilizável. M2 produz fronteiras/aberturas coerentes no bake da peça.
M3 entrega montagem manual de mapas completos, escolha explícita de vínculos,
fechamento de perímetro e emendas legíveis. M6 acrescenta geração respeitando
restrições fixadas; M7 preserva tudo no intercâmbio e M8 inclui roteiro humano.
Catálogo visual/arte usa entrega autorizada própria quando necessário.

Casos positivos: duas peças com emenda transitável, beco fechado legível,
perímetro contínuo e mapa manual reaberto sem mudança de placement/vínculos.
Adversos: passagem visual com collider, fresta transitável em borda fechada,
conector decorado/estreitado, peças sobrepostas, cota incompatível, vínculo
quebrado após revisão, biomas sem transição válida e caminho obrigatório fechado.
Na ausência de perfil/asset, falhar publicação ou solicitar autoria explícita,
sem colocar barreira invisível e chamar a emenda de concluída.

Prova visual humana verifica leitura antes de colidir; automatizada verifica
corpo/rota/LoS conforme capacidades, hash/reabertura e invariantes. Não exigir
aceite da velha amostra E07: usar mapas/fixtures produzidos pelo editor.
