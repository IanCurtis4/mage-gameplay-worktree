# Proposta de delegação — kit jogável inicial do Mago

Escopo do produto e delegação explicitamente autorizados pelo usuário em 12/09/2026.
Modelo proposto: Sol (gpt-5.6-sol, high). Astra trabalha na arte/animação em paralelo
e revisa os contratos/interações. Não criar outros agentes nem tarefas.

Leia AGENTS.md, docs/MVP.md, ARCHITECTURE.md, WORKFLOW.md e MAGE_ANIMATION_PLAN.md.
Implemente o kit e UI necessários do plano, em worktree própria sobre d76e7d3.
Este plano substitui o kit antigo de explosão/nova previsto no MVP para este bloco.
Não implementar Parede de Gelo, Assombro, Barreira Fantasma nem outras partes do M2.

Use catálogo de classes/skills imutável, class_id na run, níveis/contagem de lanças
separados das definições e cooldown/mana no runtime. Evitar framework genérico de
efeitos; queimadura/slow tipados bastam, com extensão futura por IDs documentada.
Manter a matemática de dano central; crítico garantido exige contrato explícito,
respeitando can_crit e landed, sem manipular o RNG para furar limites.

Cobertura: seleção de classe com início/reset claro, barra Q/W/A/S/D para o Mago e
Q/W do Espadachim, mira coerente e smart lock nas lanças, todas as habilidades do
plano, projétil básico do Mago, passiva de mana, augment de +1 lança, dash visível.
Compatibilidade com testes existentes: atualizar apenas expectativas alteradas
deliberadamente (ex.: dash agora leva tempo); não enfraquecer invariantes antigas.

Você pode editar gameplay, dados, UI, main e testes. Não editar assets nem scripts
novos de animação de Astra. Use sprite provisório existente para o Mago; Astra
adicionará seu sprite e hooks visuais depois da revisão. Evite refatorar o desenho
base de CombatActor além do necessário para status; isso reduz conflito na integração.

Registrar escolhas numéricas em dados e contratos no relatório. Executar verify.ps1
com o engine local informado pela coordenação. Entregar commits locais, testes,
limitações e roteiro de playtest. Sem push, merge em master ou atualização da branch
playtest. Ciclo de correções com Astra automático dentro do escopo autorizado.
