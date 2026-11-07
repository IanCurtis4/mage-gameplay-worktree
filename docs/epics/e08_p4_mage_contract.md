# E08 P4 — Mago direcional preservando vistas aprovadas

7/11/2026. Continuação autorizada da produção de sprites definitivos P4.
Base executável a195c8de29ce436520548a44268d412df69f6b49, codex/e08,
C:/Users/João Pedro/Documents/ChatGPT/RagRPG/.tools/map-editor-m5.
Fonte de autoria genérica fechada em0ddad09ff0c6dd8d816863eb0018b3fb444a18fb.
Espiritualista está congelada para Luna; Elementalista em staging pertence a Sol.
Nenhum desses inputs ou a fixture será alterado pelo executor deste pacote.

[Arquivos exatos](e08_p4_mage_files.json), Terra6.1 médio. Apenas esses arquivos.
Aplicar ragrpg-art e imagegen integrado. Mago aprovado é preservado: cabelo
castanho, chapéu e traje violeta/marrom do piloto; não redesenhar como o estudioso
azul Elementalista nem como a ritualista prateada. Inspecionar fontes e PNG
weaponless atuais antes de gerar. Sem classe/skill/item/VFX/economia/áudio novos.

## Preservação e novas vistas

Copiar byte a byte os16quadros sul e16norte do mage_weaponless.png existente,
com remapeamento explícito por estado; não retintar/reduzir/reescalar esses pixels.
S:[0,1,2,3,4,5,6,7,8,9,10,11,24,25,28,29].
N:[16,17,18,19,12,13,14,15,20,21,22,23,26,27,30,31].
Gerar via imagegen apenas as fontes E/W4×4: idle4,walk4,action4,hurt2,death2.
Perfil direito/esquerdo realmente desenhados, sem espelhar. Manter chapéu,
proporção/roupas/luz; mãos vazias adequadas a anexos separados, inclusive dano,
sem membros extras e morte em sua vista. Preservar originais/prompts/hashes.

Consumir tools/prepare_e08_directional_art.py somente leitura. Recipe:
actor_kind mage; target_height50; views.south/north com source
res://assets/art/animations/mage_weaponless.png,native_cells:true,grid:[4,8],
indices nas listas acima; views.east/west com source local PNG4×4, overrides
opcionais por pose. O modo --atlas-only prepara para autoria; padrão exige
calibration.json com actor_kind, authored_rgba_sha256 e frames64 no schema
[produtor](e08_p4_directional_contract.md). Ambos os corpos são sem arma embutida,
em paths separados; arma do jogador continua vindo do equipamento real.

## Calibração e handback

Para S/N conservar as palmas/crops dos32frames originais em hand_rigs.json,
remapeados conforme índices. Respeitar a mão principal existente deste Mago
(não impor a convenção da Espiritualista quando o desenho3/4 é diferente).
Transpor a orientação/profundidade legada de equipamento com dados por pose;
não trocar os controles do piloto para encaixar numa nova mão. Head por pose,
coerente com o chapéu existente. E/W precisam56grips vivos autorados nas palmas
reais e suas cabeças, dedos/ângulos/depth/flip; conferir o conjunto64poses.
Não copiar coordenadas do exemplo espiritual sem conferir o raster.

Todas as poses/grips devem ser verificadas offline; pedir diagnóstico delimitado
se houver erro real, conservando trabalho. Sem editar ferramentas compartilhadas,
script runtime, testes, fixture ou outras identidades. Não importar, rodar Godot,
commitar, criar chat ou automação. Devolver unidade completa e propriedade
explicitamente a Sol para renderer, seleção técnica, promoção e validação.
Staging não é aceite artístico/P4 completo; P5/master/push fora de escopo.
