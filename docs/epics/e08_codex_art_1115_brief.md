# E08 — Briefing de arte para o Codex (15/11/2026): repintura de dois efeitos

Retorno do playtest de 15/11 sobre a entrega de 14/11
([e08_codex_art_1114_brief.md](e08_codex_art_1114_brief.md)). Duas folhas ficaram com
aparência de traço, e não de pintura:

- `spirit_dissipation`: anéis e fiapos de linha fina, sem volume nem brilho;
- `tri_nova`: o terço elétrico (violeta) é fino e pouco legível perto do fogo e do gelo.

O resto da entrega foi aceito. Valem as mesmas regras e o mesmo formato da seção A do
briefing de 14/11:
- 1254×1254 RGBA, grade 4×4, mesma escala e centro em todos os quadros;
- vista 3/4 com chão em elipse ~2:1;
- só imagegen;
- `provenance.json` com o prompt exato.

Destino: `assets/art/e08_codex_1115/vfx/`. Não sobrescrever a pasta de 14/11.

## Folhas

| # | id do arquivo | Habilidade | Onde aparece no jogo | Direção artística |
|---|---|---|---|---|
| R1 | `spirit_dissipation` | Rito de Dissipação (Espiritualista) | **centrado no ponto escolhido**, cobrindo uma área de chão de raio ~100 (cerca de 230 px de largura na tela) | **Prioridade.** Selo espectral pintado no chão: elipse de névoa branco-lavanda com volume e núcleo luminoso de 2–3 tons. Ondas concêntricas que se expandem e se desfazem em brumas, e almas em fiapos *pintados* subindo do centro. Deve ter o peso visual de `ground_shockwave`/`blood_rift`, não de contorno. Clima sereno, não assustador. |
| R2 | `tri_nova` | Nova Tríplice (Elementalista) | ao redor da personagem | Opcional. Mesmo anel de três terços, com o terço de **raio** no nível do fogo e do gelo: arcos elétricos grossos e ramificados, núcleo branco-violeta e faíscas saltando para fora do anel. Os três terços continuam com a mesma espessura e o mesmo brilho. |

## Depois da entrega (Claude)

Empacotar com `tools/prepare_e08_vfx_art.py`, apontando para a nova pasta, e conferir
16 quadros sem quadro vazio no meio. Depois, rever os tamanhos em `SIGNATURE_ART`, que
hoje são 230 px para a Dissipação e 140 px para a Tríplice, e repetir o playtest das
duas habilidades.

## Entrega e integração — 13/11/2026

O Codex entregou as duas folhas (R1 e o opcional R2) em `assets/art/e08_codex_1115/vfx/`,
com `provenance.json` e o prompt exato de cada uma; os SHA256 conferem. A pasta de 14/11
ficou intacta e continua registrando as versões anteriores.

`python tools/prepare_e08_vfx_art.py codex_1115` empacota só essas duas ids, que agora
são lidas da pasta nova. Resultado: 16 quadros cada, só o último vazio. A largura de pico
na célula é 156 px nas duas (antes 156 e 149,6). Por isso os tamanhos em jogo de
`SIGNATURE_ART` (230 px e 140 px) não mudaram. Na conferência visual, a Dissipação tem
duas faixas de nuvem com volume e plumas pintadas, e o terço elétrico da Tríplice tem
o mesmo peso do fogo e do gelo.

O cache de importação foi refeito no checkout (atalhos de jogo) e na fixture F1.
`e08_vfx_art_test` passou a conferir a origem e o prompt da repintura (1.238 checks).
Dirigidos `playtest1115_05`: arte 1.238, feedback visual 593, piloto 350, presentation
2.255, todos sem falha. A sonda de release `e08_p7_release_probe` não foi repetida.
