# F9 — bordas físicas dos quatro ambientes

Sol26/10. Engenharia no escopo F9-03/04/07/09/11, após a44cfb1 e7073d38.
Donos nominais antes de editar em f9_ownership.json. Implementa a direção
[composição/emendas](map_composition_and_seams.md) e [massa](f9_terrain_solids.md).
Não cria natação/salto, nova regra de ataque, bioma de spawn ou renderer.
Esta nota é contrato, não recibo nem certificação de implementação.

## Perfis e compatibilidade

Catálogo passivo local schema1/revisão1; definições/revisões imutáveis:
forest_rootbank_v1, desert_ridge_v1, meadow_stream_v1, ruin_rubble_v1 e transição
transition_terrace_v1. Floresta: obstáculo de terra/raízes e mata; deserto: monte
real e cactos/arenito; ruína: alvenaria/escombros; planície: canal/margens/água.
O perfil técnico ruin_envelope_v1 mantém sua realização anterior, IDs, envelope,
contagem e nove dependências de material. Não adicionar props/arquivos novos
sob esse ID antigo. O novo acabamento de ruína tem outro ID.

O estilo da borda não concede permissão de espécie/raridade/origem. Contexto
editorial e regras canônicas continuam explícitos e separados. UI em pt-BR;
IDs em inglês. Ausência de perfil/asset retorna diagnóstico; sem barreira invisível.

Composição compilada passa a formato5/map_composition_v5 ao integrar o consumidor.
Fonte de mapa v1 conserva o campo barrier_profile e permite borders opcional,
fechado: version1, instances, transitions, decorations. Instances contém
instance_id/profile_id únicos; transitions contém a_instance/b_instance/profile_id,
par não ordenado único e instâncias existentes. Decorations é bool global,
revisável/desfazível, para o acabamento derivado do perfil. Campos omitidos
preservam fonte e comportamento legados. Alteração de estilo usa mesma operação
em GUI/AX/CLI; não reescreve definições imutáveis. Regras por instância e transições
são removidas explicitamente na transação de exclusão da instância, com diff.

## Fronteira normalizada

Consumir somente boundaries caminháveis closure=profile. Fechamentos por massa
terrain permanecem reais, sem segunda parede. Subtrair a largura inteira de
cada abertura lógica realizada antes de emitir massa/decoração. Recortes N:M,
extremos e projeções usam as autoridades escalares existentes; sem relaxar EPS.

Normalizar trechos collineares e seus cortes antes de atribuir dono estável,
independente da ordem de arrays. Trecho compartilhado tem uma realização física
e visual. Perfis distintos exigem preset compatível ou escolha de transição
explícita; não decidir pela ordem de instâncias. Não estreitar o corredor por
copa, volume, decoração ou normalização. Pontas abertas não recebem acabamento
que invada a abertura. Cantos/junções precisam de massa e pele coerentes, sem
buraco físico, dupla camada visível ou props flutuantes.

## Geometria e leitura

Perfis ricos compõem primitivas canônicas existentes: prisma convexo com cap
real/plano e base abaixo, AABB de corpo dos props quando declarado e superfícies
visuais de água. Caps não planos são triangulados na mesma geometria consumida;
sem esconder o relevo numa caixa. Massa de borda tem support_surface_id vazio:
um topo plano de obstáculo não se torna piso de ator automaticamente.
Pele deriva da massa real e usa position/normal/weights em Materials.face_arrays,
sem renderer novo ou dupla transformação. Catálogo e dependências são locais,
passivos, fechados e conferidos por hash. IDs de asset coincidem com os usados
por ObjectCompiler; mesmo path/revisão/hash não duplica dependência.

Decorações se apoiam na massa real, com pivô/escala/footprint do catálogo e
margem de abertura. Tronco/pilar/rocha conserva corpo/ataque/LoS declarados;
folha não ganha collider. Disable decorations conserva a barreira visível,
nunca deixa só bloqueio invisível. Oclusão usa API compartilhada e deve receber
prova posterior com avatar real; teste de opacidade isolado não a certifica.

Planície não recebe parede exclusiva de água. Margem e canal ficam fora do
suporte autorado, com desnível legível; água não tem suporte nem collider.
Corpo para por ausência de apoio/margem real; raio acima da água fica livre.
Canal que invade chão comum na cota da margem exige autoria/transição, sem
apagar ou pintar esse chão silenciosamente. Ponte explícita pode cruzar por
cima se a água permanece abaixo da sua base real; overlapXZ não basta para
recusá-la. Conferir cotas, massa e tipo de suporte para evitar falso muro.

## Receptor, orçamento e prova

Receptor reconstrói trechos, escolha/dono, cap/base/pele/água/props/dependências,
compara massas e volumes efetivos no estágio e recusa adulteração mesmo com
hash recalculado. Nenhuma referência de borda entra como suporte fantasma.
Manifesto/WorldGeometry/assembler permanecem em suas revisões atuais: só usar
capacidades já validadas. Consumidor que não suporte o pacote novo recusa sua
revisão, sem descartar a massa nem alterar expedição/save existente.

Manter4MiB por pacote,1024 suportes e2048 massas por estágio. Contabilizar os
novos corpos, faces e decorações antes de publicar. Cancelamento/orçamento/stale
não deixam cauda parcial. Orçamentos são proteção técnica, não licença para
adiar funções ou prometer FPS.

Provas: quatro famílias com corpo/raio reais; legado idêntico; abertura80/N:M12,
altura/rotação/direção, fresta/canto/junção e dono único; transição ausente e
explícita; canal sem apoio/sem muro de ataque e ponte acima; asset ausente;
cap/base/água/prop adulterado com novo hash; reorder/roundtrip/undo e consumidor
manual/seed. Capturas nativas de perfis e envelopes, com passagem e ator legíveis.
Regressão por impacto/Luna após pacote substancial. F9-02 orgânico,05 regeneração,
06 biblioteca,07/09 AX/intercâmbio,10 responsividade,11/12 uso final continuam
obrigatórios; este contrato não fecha F9 nem autoriza F10.
