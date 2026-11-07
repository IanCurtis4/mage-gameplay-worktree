# E08 P4 — unidade Elementalista

7/11/2026. Continuação do pedido humano de produzir sprites definitivos.
A primeira unidade Espiritualista passou conteúdo3.293checks, renderer447/15PNGs,
inspeção Sol e custo; regressão ampla está em execução, com isolamento corrigido.
A API de apresentação é estável. Esta unidade artística em staging é independente
nos arquivos listados e não altera os inputs congelados da prova Espiritualista.

Base de produto/produtor28c5ebc777e72b96f4363d1bff2b48e666acd854, mesmo checkout
codex/e08 em C:/Users/João Pedro/Documents/ChatGPT/RagRPG/.tools/map-editor-m5.
O commit deste pacote de ferramenta/contrato será passado com SHA completo antes
do consumo. Alterações locais da Espiritualista pertencem a Sol; não tocar nelas.
[Propriedade exclusiva](e08_p4_elementalist_files.json). Terra6.1 médio.

Produzir Elementalista completo conforme personagem da LINHA SUPERIOR do estudo
e08_evidence/p4/elementalist_spiritualist_concept.png apreciado pelo usuário:
cabelo castanho, traje de estudioso angular azul-marinho/branco/metal discreto.
Preservar azul dominante existente; nenhum novo kit, efeito, arma embutida,
item ou VFX. Não reciclar a silhueta ritual prateada da Espiritualista.
Aplicar ragrpg-art e imagegen integrado, transparência real e fontes/prompts/hashes.

Quatro fontes4×4 (S/N/E/W),64poses: idle4,walk4,action4,hurt2,death2 por direção.
Anatomia e assimetria coerentes, ambas mãos vazias visíveis em cada pose viva,
sem membros extras; perfis desenhados próprios. Inspecionar fonte E/W e a morte,
sem aceitar giro frontal acidental. Resíduos RGB com alpha≤5 não são pixel opaco;
preparação mecânica aplica o limiar existente. Não regenerar por falso diagnóstico.

Consumir tools/prepare_e08_directional_art.py somente leitura. source_recipe.json:
actor_kind, target_height50, views com south/north/east/west:{source:nomePNG} e
overrides opcionais {indicePose:nomePNG} para selecionar correção localizada.
O modo --atlas-only prepara PNGs para autoria, sem manifesto; padrão exige
calibration.json com actor_kind, authored_rgba_sha256 e frames64 no schema
[produtor](e08_p4_directional_contract.md). Corpo/weaponless iguais intencionalmente,
sem arma embutida. Escala global/pivô32,58, células64×64, atlas256×1024.

Calibração É PARTE da unidade de conteúdo de Terra: escolher112grips vivos
pose a pose sobre palmas reais, crops de dedos,64head poses, profundidade/ângulo/
flip por vista. Usar calibração Espiritualista como EXEMPLO de schema, nunca
copiar coordenadas sem conferir seu raster. Pode analisar componentes de pele
para localizar candidatos, mas deve conferir anatomia em cada quadro; ponto
opaco qualquer não é mão. Corpo/mãos/dedos/armas devem estar coerentes.

Sem alterar script de runtime, ferramentas compartilhadas, outros assets, testes,
verify ou docs globais. Sem importação/Godot/fixture ou commit durante escrita
concorrente de Sol. Executar apenas geração/offline da própria unidade, devolver
posse explicitamente com atlas+manifesto+calibração/proveniência reproduzíveis.
Se surgir defeito real persistente, pedir diagnóstico delimitado a Sol conservando
as fontes; não encerrar automaticamente com todo o trabalho manual faltando.

Sol fará prova nativa, testes/integração/promoção depois do handback. Unidade
em staging não significa produto aceito nem P4 concluído. P5/master/push fora
escopo. Habitual, piloto e saves preservados.
