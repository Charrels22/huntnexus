# HuntNexus — workspace principal em `/`

**Data:** 2026-11-01. **Status:** interface nova preparada na branch `codex/guia-visual`; build local aprovado. Banco remoto, login Twitch e recomendações reais ainda não homologados.

## Decisão de produto registrada

- O produto desta etapa é uma experiência única e independente na raiz `/`. Não reaproveitar o antigo dashboard como página principal nem colocar o novo fluxo dentro de `/guia`.
- `/guia` redireciona para `/`, preservando busca e fragmento da URL. `/characters` redireciona para `/#personagens`.
- A base factual de Tibia serve também RubinOT; conteúdo exclusivo do RubinOT, como RTC, deve continuar identificado como tal. Não pedir ao jogador jogo, servidor, versão ou patch na montagem da hunt.
- A resposta final deverá priorizar hunt, magias e equipamentos, com evidências para as recomendações.
- O jogador pode manter personagens e seus levels, vocação, atributos/skills e inventário. Main aparece como grade de peças clicáveis; Backpack aparece em lista.
- O formulário reúne hunt/criaturas, grupo, estilo de caça, prioridade e texto dos analisadores. Os dados da sessão são privados por padrão; contribuição anônima é opcional.
- A intenção de autenticação é Twitch como principal e e-mail como alternativa. O acesso Twitch permanece dependente da configuração OAuth no Supabase.

## Implementação local

- `web/app/src/routes/index.tsx`: nova experiência principal; cadastro/seleção de personagens, edição de ficha, Main/Backpack, busca no catálogo, contexto de hunt e entrada de analisadores.
- `web/app/src/routes/index.css`: identidade visual e layout responsivo próprios da raiz.
- `web/app/src/routes/guia.tsx` e `web/app/src/routes/characters.tsx`: compatibilidade por redirecionamento para a experiência única.
- `web/app/src/components/shell/app-shell.tsx`: a raiz não recebe a navegação lateral antiga nem as consultas de sessão do shell.
- `web/app/src/routes/api/huntnexus.ts` e `db/migrations/0162_player_character_library.sql`: operações e esquema para biblioteca privada de personagens e inventário.
- `web/app/src/routes/account.tsx` e `web/app/src/styles.css`: opção visual de entrada Twitch, controlada por `VITE_HUNTNEXUS_TWITCH_LOGIN_ENABLED`, com e-mail como alternativa.
- `web/app/src/routeTree.gen.ts` é gerado pelo TanStack Router e inclui as rotas compatíveis; `web/app/src/vite-env.d.ts` declara a variável de configuração do login Twitch.

## Evidência e limites

- `npm run build` em `web/app`: **PASS**, exit code 0, incluindo os builds client/server e TypeScript.
- `git diff --check`: **PASS**.
- A inspeção visual desta revisão não foi concluída pelo controle do navegador; não registrar screenshots nem QA visual como aprovados.
- `?preview=1` disponibiliza personagens/equipamentos sintéticos somente em desenvolvimento. Não são dados reais nem são salvos.
- O parser de analisadores lê o texto localmente. O checkbox de contribuição anônima ainda não envia nem persiste contribuição.
- O botão de montar plano organiza o contexto, mas o motor de recomendação de hunt, magias e equipamentos ainda não está conectado. Não apresentar esse estado como recomendação real.
- A migration `0162` não foi aplicada no Supabase; não houve escrita no banco, autenticação de usuário real, merge ou deploy nesta etapa.
- A persistência autenticada da biblioteca, OAuth Twitch, isolamento entre contas, contribuição anônima e recomendações com evidências continuam pendentes de homologação específica.
- Nenhuma suíte automatizada foi executada nesta etapa.

## Retomada sugerida

1. Abrir `http://127.0.0.1:5173/?preview=1` e revisar a experiência raiz em desktop e mobile; registrar screenshots após QA visual real.
2. Ajustar o visual e o fluxo com o usuário sem reintroduzir uma página Guia independente.
3. Implementar e validar a resposta baseada nos dados factuais atuais e nas evidências observadas, mantendo RubinOT/RTC como overlay exclusivo quando aplicável.
4. Antes de testar persistência, OAuth ou contribuição com serviços/banco reais, revisar configuração e autorização da operação específica. A migration `0162` continua pendente.
5. Manter a FE-40 do roadmap oficial como trabalho separado; esta interface não a substitui nem a declara concluída.
