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
