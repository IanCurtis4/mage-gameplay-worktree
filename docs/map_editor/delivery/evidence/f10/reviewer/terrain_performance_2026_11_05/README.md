# Evidência — terreno e desempenho F10

Código `2ff1c00f923e3811b0aa7ebcbeddafe7731d640f`.
[Vínculo e fatias](candidate_binding.json), [comparações e limites](comparison.json),
[build final](build_final/build_manifest.json), [captura](build_final/forest_minimap_zoom.png),
[atalho](launcher.json). Logs brutos e histórico de falhas estão em validation.

16 IDs/712 checks distintos por impacto, com reutilização explícita; não é a
suíte inteira nem todos os testes repetidos no commit final. UI31, proofs23,
fase11, sombras28, terreno15 e pixels6. F3snapshot52 reaproveitado sem somar.
Limites4 positivos em verify04 não tornam a rodada falha de sombra um PASS.

PCK final: floresta15/15; engine standard e exe release têm provas separadas.
96 atores, três janelas ~3s: comparação final PCK contra PCK de movimento e
idle. O teste móvel fixa posições seguras para isolar apresentação, sem AI.
Floresta com AI foi medida separadamente; sua cauda não melhorou e existe pico
de 156 ms numa janela idle. Não há certificação de ausência de lag/combate massivo.

Preparação fria/quente final mantém manifesto e regras completos. Sonda inicial
de concorrência usou PCK antigo headless; final é nativa. Não misturar os modos.
Fonte/fixture 2.251 e completion 2.257 conferidos; fontes congeladas com engine.
Nenhum executável/PCK, perfil ou shadercache está nesta evidência Git.

O índice artifacts.json guarda tamanho/hash de todos os outros arquivos deste
diretório. Documento final valida links/diffs/hashes, sem repetir gameplay.
Q5 e aceite humano continuam abertos. Playtest habitual/backups/saves preservados.
