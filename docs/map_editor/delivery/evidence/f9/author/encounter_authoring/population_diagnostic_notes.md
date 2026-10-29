# Diagnóstico Sol —29/10/2026

Base `bc52103eee28072d70243b42a002056bc0bf90fa`; fixture única, engine4.7.2
SHA256 `ab1824f85bfd8e0e4128182c000c4003a3e042245b2967848d089b2a04b22424`.
Sem edição do produto durante as sondas, HEAD igual antes/depois.

Terra preservou o rascunho AX em `../../terra/area_encounters/population_draft_01.json`,
SHA256 `4d64d6ffbce706a2917b2a1ad436decfd362b96575a7a4b4bbd001ededdb7cb1`.
A tentativa AX completa anterior atingiu300s, guard externo360s; não é PASS.

`population_diagnostic_01`: erro da sonda Sol, ao ler JSON pelo parser normal,
perdendo a representação numérica exigida pelos hashes de peças. Retornou
piece_hash_mismatch antes do mapa. Não mede o caso de produção. Preservados
recibo/logs e cópias exatas dos scripts `.gd.txt` como evidência passiva.

`population_diagnostic_02`: leitura por PopulationStore/StrictJSON, mesmo
rascunho exato e compilador copiado com marcadores. Mapa iniciou5279ms e
concluiu33592ms,28,313s. Busca individual entrada→santuário iniciou38372ms,
sem retorno quando o guard diagnóstico120s encerrou o processo. Exit null,
timed_out=true; não é PASS nem medição do tempo completo. A sonda usa os
mesmos predicados/corpo/pontos; apenas coleta trace/prints. Fixture liberada.

Próxima implementação usa a prova de existência canônica em lote, conforme
contrato `f9_population_reachability.md`. Manter fonte real integral, quotas,
engine e limites; novo intento terá outro diretório. Nenhuma medição aqui
certifica FPS, gameplay ou conclusão de F9.
