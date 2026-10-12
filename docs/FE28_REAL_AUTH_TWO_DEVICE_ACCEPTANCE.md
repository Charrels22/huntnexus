# HuntNexus FE-28 — protocolo de autenticação real, sessão e recuperação entre dispositivos

**Estágio:** roteiro preparado para execução futura por participante consentido. **NÃO executado automaticamente**; não existe no repositório uma credencial real ou caixa de e-mail dedicada aprovada para QA.

## Objetivo do teste

Comprovar a camada que SQL sintético, tokens forjados e browser sem login **não conseguem** certificar: delivery de Magic Link, callback do Supabase Auth, token realmente assinado, refresh, sincronização do mesmo `client_id` canônico entre navegadores, logout/relogin e negativa de acesso ao sair.

## Pré-condições autorizadas

- Participante com acesso legítimo a uma conta de e-mail de testes, preferencialmente não pessoal.
- Dois navegadores/perfis isolados ou dois dispositivos. **Não enviar tokens, Magic Links ou URLs com query/hash de callback a terceiros ou logs**.
- Abrir somente o site publicado `https://huntnexus.charr3ls22.workers.dev/account`. Reduzir exposição de nomes de personagem e dados do jogador nas capturas.
- A validação não requer conceder acesso à caixa de e-mail nem fornecer senha/API key ao HuntNexus.

## Checklist de aceite A/B

| Caso | Procedimento | Resultado esperado |
|---|---|---|
| A1 | Navegador A, sem login: registrar perfil de teste, arma Main, item BP, escolha de hunt e 1 sessão real consentida (ou teste separado rotulado como sintético) | Dados só na identidade guest do A |
| A2 | A, abrir Account e solicitar Magic Link ao endereço autorizado, usar somente o link da caixa de e-mail | Entrar no mesmo domínio HTTPS, banner de conta autenticada; `account_resolve` associa a identidade A sem perder Profile/Main/BP/History |
| B1 | Navegador B limpo, solicitar outro Magic Link para a **mesma** conta | `account_resolve` retorna identidade canônica do A; dados privados A visíveis apenas enquanto B está autenticado |
| B2 | B: editar um dado não sensível de Profile ou Set, revisar no A após sincronização | O mesmo estado privado aparece nos dois navegadores; nenhum guest independente é mesclado silenciosamente |
| X1 | Browser B deslogado: tentar acessar antigo perfil canônico usando o UUID anteriormente conhecido | Worker retorna HTTP 401; interface inicia convidado novo, sem compartilhar Profile/Inventory |
| X2 | Outro login autêntico, com usuário diferente, tentar usar `client_id` canônico do A | HTTP 403; não ler nem atualizar dados da conta A |
| R1 | Renovação de token válida e evento `TOKEN_REFRESHED` enquanto Account sincroniza | Token novo não se perde; dados canônicos continuam acessíveis |
| R2 | Logout manual em um dos navegadores e sign-out remoto/entre abas | Nenhum navegador deve mostrar o `client_id` vinculado como se fosse identidade guest |
| R3 | Falha de rede ou rate-limit no `/auth/v1/otp` | Exibir erro; botão retorna a estado utilizável sem loop ou disparos repetidos |
| D1 | Tentar desvincular com Profile/Inventory/Sessions existentes | HTTP 409 `private_data_present_unbind_blocked`; binding continua ativo e dados intactos |
| D2 | Teste de unlink de conta realmente vazia (somente conta de teste, com consentimento expresso) | Operação permitida; não excluir silenciosamente dados de uma conta real |

## Evidências de homologação

Somente registrar: navegador usado, cenário, status PASS/FAIL, mensagens de interface com dados privados ocultos, horário aproximado e versão/build. Nunca persistir `access_token`, `refresh_token`, códigos OTP ou links mágicos completos em GitHub Issues, prints, comentários, logs ou planilhas públicas.

Marcar o caso como “bloqueado por ambiente” se entrega de e-mail ou redirect allowlist Supabase não estiver funcional. Nesse cenário **não inventar PASS**.

## Segurança: observações atuais

- O identificador de guest é um UUID armazenado em `localStorage`, que funciona como capacidade enquanto não vinculado. Adivinhação é dificultada por `crypto.randomUUID`, mas isso não equivale a Auth forte; seguir priorizando login antes da fase de testes externos.
- `account_unbind` com dados privados não é uma operação de logout: o FE-27 a bloqueia para não transformar um ID canônico em dado guest acessível.
- A UI passou a ocultar o UUID canônico do cartão visível no Account; não é preciso expô-lo ao usuário para sincronizar.
- Supabase Security Advisors FE-27: RLS sem policy em tabelas internas service-role-only é deliberado; `pg_net` no schema public e leaked-password protection desabilitada ainda devem ser avaliados em janela controlada. Não mudar extensão crítica somente para silenciar alerta. O login atual é Magic Link.
