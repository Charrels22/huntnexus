# HuntNexus — Checkpoint FE-15 / retomada (10/10/2026, America/Sao_Paulo)

## Fonte da verdade
- GitHub: `Charrels22/huntnexus` (`main`)
- Backend: Supabase `HuntNexus`, projeto `urbncbjapasnjqjqicjv` (sa-east-1)
- Web: TanStack Start / Cloudflare Worker `huntnexus`
- Produção: `https://huntnexus.charr3ls22.workers.dev`
- Lovable permanece legado/protótipo; não é a fonte canônica nem o deploy principal.

## Estado recuperado do checkpoint
- Migrations aplicadas até `0147_creature_explorer_read_contract`, incluindo o optimizer universal, perfil, equipamentos possuídos, importação privada de sessões, catálogo de proficiencies e auditoria de prontidão.
- Rotas presentes: Dashboard, Planner, Hunt Detail, Session Analyzer, histórico de sessões, Profile, Account, Creature Explorer, Boss Explorer, Loadout Explorer e Community Hunts.
- As regras de proveniência continuam obrigatórias: oficial/canônico, overlay RubinOT, comunidade e editorial não devem ser confundidos.
- Nunca fabricar atributos de jogo, compatibilidade, fórmula única de DPS ou vencedores de sets sem evidência.
- Builds finais de bosses ainda bloqueados quando faltam mecânicas atuais reconciliadas.

## Defeitos encontrados e corrigidos nesta retomada
1. `/creatures` chamava `search_creatures` e `creature_detail`, mas o contrato HTTP `web/app/src/routes/api/huntnexus.ts` não reconhecia essas ações. Adicionadas validações de entrada + RPC server-side.
   - Commit: `50abdb7d903341bfec242068c8652ad3dafcf442`
2. Adicionada regressão pública real das duas ações a `tests/public-api-smoke.mjs`.
   - Commit: `2720c5db674a0276e076e1a47252f529d4c7955a`
3. O link do `/loadouts` enviava `objective` e `party` para `/hunts/$huntKey`, apesar da rota aceitar somente `vocation`, `level` e `setObjective`. Corrigido.
   - Commit: `9f1cf29f5dca7b37abc27d784c708dd16dc14b2c`

## Verificações realizadas
- Supabase migration `0147` presente na lista aplicada.
- Consulta SQL `huntnexus_search_creatures('cobra',3)` retornou entidades canônicas (incluindo Cobra Assassin e Cobra Scout).
- GitHub Web CI `38099827565` (**success**) no commit `9f1cf29` após correção de TypeScript.
- Smoke de perfil, de sessões, de inventário e de múltiplas vocações: **success** no commit `50abdb7`.
- O smoke público `38099746942` falhou com 400 em `search_creatures` porque o Worker publicado ainda estava em versão anterior; isto aponta ausência de deploy das alterações, não falha da nova rotina SQL.
- Último deploy Cloudflare observado neste checkpoint: 2026-10-10 21:38 BRT (2026-10-11 00:38 UTC), anterior aos commits de correção; origem `wrangler`. Não tratar novo código como publicado até confirmar deploy e smoke verde.

## Próxima ordem de execução
1. **Deploy:** publicar a nova versão de `web/app` no Cloudflare Worker preservando secrets de runtime, a partir do GitHub canônico; confirmar versão/commit realmente aplicado.
2. **API pública:** reexecutar `tests/public-api-smoke.mjs`; exigir green para `search_creatures`, `creature_detail`, além do fluxo anterior.
3. **QA de navegação:** validar Dashboard, Planner, Hunt Detail, Profile, Sessions, Loadouts, Creatures, Bosses, Community e Account pelo frontend visual.
4. **Casos reais:** testar EK, RP, ED, MS e EM, variando nível, equipamento, armas de 1/2 mãos, offhand, munição/quiver, proficiencies, spells, imbuements e métricas de XP/profit/defesa.
5. **MS de regressão:** usar Charrels Elysian (MS 655, ML base 110), verificar semântica de ML efetivo (sem dupla contagem) e seleção de perks específicos por `item_key + perk_order`; confirmar visual fiel ao jogo.
6. **UX de perfil:** texto de primeiro cadastro deve desaparecer depois de existir personagem; strip resumida por nome/level/vocação/mundo e apresentação do personagem baseada no set principal.
7. **Qualidade de dados:** marcar explicitamente campos sem fonte como não disponíveis; conferir sprites oficiais, versões RubinOT e guardrails das recomendações.
8. **Piloto externo restrito por vocação:** só depois de QA real verde e controle de dados privados; coletar feedback rastreável, sem publicar dados privados de jogadores automaticamente.

## Gates antes de declarar produto operacional
- Web CI + smokes públicos verdes sobre o mesmo artefato publicado.
- Nenhuma ação da interface devolve 400 por ausência de contrato.
- RLS / escopo de conta privados preservados e acesso público limitado a RPCs seguras.
- Testes reais de cada vocação completos e validados visualmente.
- Dados não confirmados ou não reconciliados não são exibidos como recomendações finais.

## Ações para continuidade
O desenvolvimento parte de `9f1cf29`. Não confundir merge/commit, validação SQL, build CI e deploy Cloudflare: são quatro estados distintos.
