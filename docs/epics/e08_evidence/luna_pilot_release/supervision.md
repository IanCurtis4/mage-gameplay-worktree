# Supervisão Luna — release piloto E08

**Resultado: PASS de integridade da evidência e execução arquivada.** Candidato `ad09b99d5e70385d4532b478931c85629f5de849`; runtime P3 `3ea5e9086da11c51d81d5a85b8f29d464b04c3d8`; HEAD congelado `aed3caf5e2eb55623f56437b0d845787d9e546f2`.

O ZIP confere pelo SHA registrado e seus 93 membros foram verificados. O export contém 2.322 fontes: 2.320 bytes compartilhados com a fixture e dois blobs de ferramentas do candidato. A fixture atual tem 2.323 fontes e confere com a origem. Foram conferidos engine, configuração, quatro backups e os 21 arquivos locais de entrega; o atalho aponta para o EXE entregue.

Os cinco processos de build passaram; o pacote passou 20 verificações no engine standard e o manifesto de assets passou sete. O boot automatizado do EXE por 120 frames não prova interação. A automação nativa de UI não executou por indisponibilidade do kernel; a tentativa encerrada com código −1 não conta como PASS. O teste legado de export E06 falhou em 2/162 por diferença de contagem 11→16, reproduzida no histórico F10.

As dez execuções válidas de comparação terminaram sem erro ou timeout. No conjunto primário de seis, mediana/p95 agregados mudaram de 11,6635/16,5625 ms para 12,4845/17,4295 ms. A repetição florestal mostrou aumento de 12,0%/28,2%; a ablação v2 normal, de 1,2%/4,2%, sem custo persistente isolado. A memória estática retida após limpeza aumentou 63.470 bytes (~0,061 MiB). PeakWorkingSet não estava disponível: zero no wrapper testado foi corrigido para `null` na versão atual.

As ablações inválidas anteriores foram excluídas. Os dados sustentam a ressalva de variação e não uma garantia universal de 60 FPS. Esta supervisão confere execução e integridade, não é auditoria semântica independente, avaliação visual/auditiva ou aceite do produto. Não houve rerun nem commit; aceite humano permanece pendente.
