# F9 — densidade do snapshot no gameplay real

Bloqueio reproduzido em d0b878b8ac65d3d9db92bc18f06cd55aa13cf32a pelo
RoundedNative (native_corrected): fonte33x33/passo50, colina220/raio420,
Maps/Candidate/Launcher/App reais, perfil20/32. App.open PASS; App.start falha
snapshot_too_large antes de picking/movimento. Captura da colina válida; ainda
não é conteúdo jogável. Compile3.819s, mapa26.722s, abertura47.022s,
início78.422s nesta execução. Não são medições de fluidez/FPS.

Sol investiga a representação canônica de snapshot, mantendo4MiB, profundidade,
identidades, compartilhamento/ciclos, tipos de containers, RNG, sinais, tombstones,
retomada, protocolo de propriedade e rejeição de conteúdo incompatível. Nenhum
cap aumentado, nenhuma redução da amostra/corpo, nenhum bypass de persistência.
Não omitir geometria/estado autoral para obter PASS. A primeira mudança é apenas
diagnóstica: falha de bytes da captura retorna métricas de tamanho por tipo de
container e geometria passiva, sem exportar payload/profile. Ela não resolve
nem valida a colina no jogo. A evidência precisa localizar o estouro antes de
escolher compactação/restauração e testes de regressão pertinentes.

SnapshotRegistry/runtime_manifest já têm propriedade nominal Sol no manifesto
F9, recebida sequencialmente; nenhum outro escritor. Luna mantém o teste T01 e
corrigiu a prova GUI para usar o menu Criar visível em UX; falha no botão oculto
era oráculo inadequado, separado do bloqueio real. Demais requisitos F9 continuam.


## Diagnóstico real82cc23d — confirmado28/10

`native_diagnostic` alcançou13 checks PASS e falhou só no início da App; 14
emitidos de20 esperados, logo a etapa é FAIL. GUI pelo menuCriar foi corrigida
e comprovada. Nenhuma captura de gameplay, picking ou caminhada foi produzida.
Envelope10.308.936 bytes para limite4.194.304;634 objetos (registros747.616B),
22.405 containers (registros9.498.624B):11.083 arrays/2.488.224B e11.322
dicionários/6.472.672B. WorldGeometry guarda estágio passivo1.024.396B com536
suportes/828 conexões. A maior parcela é a representação do grafo em containers,
não o PNG do terreno. Estes números são tamanho serializado, não RSS/heap.
Prepare3.320s, mapa26.381s, App.open45.325s, App.start71.334s nesta reprodução.
Todos são preparo; não há amostra de frame/FPS. Sem erro genérico ou timeout.

Próximo trabalho Sol: representação compacta SEM perdas do mesmo grafo passivo,
com identidade de containers distinta de igualdade de conteúdo, ciclos, tipos,
referências/sinais/identidades e limite4MiB preservados. A economia só de omitir
metadados vazios não deve ser presumida suficiente diante dos10.3MB medidos.
Concretizar layout e limites antes dos consumidores; provar a mesma colina e
uma ida/retomada real. Não bypassar checkpoint nem apagar estado necessário.
Luna prepara rascunho de invariantes fora dos inputs em
.godot/f9_shadow_draft/luna_snapshot_density/test.gd; integração só após freeze.
Ampliar seleção oficial a snapshot/continuidade por impacto quando houver fix.


## Direção técnica a concretizar (ainda sem código)

Uma possibilidade concreta preserva o grafo semântico atual exposto por
SnapshotRegistry e cria encoding binário canônico compacto para seu transporte.
O layout pode usar tabela indexada para IDs de containers, referências por índice,
descriptors posicionais com metadata de tipos só quando necessária e pares de
dicionário planos. Nenhuma deduplicação por igualdade que transforme dois
containers mutáveis distintos em um; reconstrução deve manter todos os IDs,
tipos, ciclos e alias. Medir primeiro se o mesmo envelope real cabe nos4MiB.

Se adotado, medir/limitar o encoding compacto antes da compressão DEFLATE já
existente; não passar a contar só bytes comprimidos. O grafo semântico de trabalho
pode continuar no formato atual para os consumidores. Codec de checkpoint terá
versão explícita e leitura legada ou rejeição compatível antes de mutar perfil.
SnapshotRegistry.capture/validate e ExpeditionCheckpointCodec.pack/unpack devem
concordar no mesmo encoding e orçamento. Helpers/UIDs, ownership nominal e
invariantes serão registrados antes da edição. Não é uma correção já aprovada
por prova: validar layout/roundtrip, limites, payload malformado, F3/F6 pertinentes
e a App real33x33/20x32, mantendo relato de custos de abertura/início separados.
