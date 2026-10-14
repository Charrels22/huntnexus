# Modelo de autenticação e recuperação do HuntNexus

**Tópico:** 5 do realinhamento. **Estado:** implementação e regressões locais concluídas; ativação real pendente de autorização específica. Este documento não afirma que o fluxo novo já está publicado.

## Decisão

O acesso privado usa dois fatores independentes:

1. e-mail e senha como primeiro fator;
2. TOTP em aplicativo autenticador como segundo fator obrigatório.

Magic Link deixa de ser a entrada da interface. Um link antigo ou emitido diretamente pelo provedor produz, no máximo, uma sessão `aal1`; a API do HuntNexus recusa essa sessão para Profile, personagens, inventário, builds e sessões até que um fator verificado eleve a sessão a `aal2`.

A conta representa o jogador. Personagens pertencem à conta e nunca são usados como credencial. Uma conta pode manter vários personagens conforme o modelo do Tópico 4.

## Por que o e-mail sozinho não basta

Recuperação por e-mail pode redefinir a senha, mas não remove o segundo fator. Assim, controlar a caixa de entrada não é suficiente para abrir os dados privados já vinculados. O usuário deve manter dois autenticadores TOTP verificados, preferencialmente em dispositivos distintos, para reduzir o risco de perda do aparelho principal.

O Supabase documenta TOTP e phone MFA, níveis `aal1`/`aal2` e enforcement na aplicação. A documentação oficial ainda informa que recovery codes não são suportados como fluxo estável. Por isso, o HuntNexus não apresenta códigos de recuperação como capacidade disponível e usa um segundo TOTP como fator reserva.

Referências oficiais:

- [Multi-Factor Authentication](https://supabase.com/docs/guides/auth/auth-mfa)
- [JavaScript MFA API](https://supabase.com/docs/reference/javascript/auth-mfa)
- [Password security](https://supabase.com/docs/guides/auth/password-security)
- [Password-based authentication](https://supabase.com/docs/guides/auth/passwords)
- [Sign out and scopes](https://supabase.com/docs/guides/auth/signout)
- [Sessions](https://supabase.com/docs/guides/auth/sessions)

## Controles implementados

### Navegador

- criar conta com e-mail e senha;
- entrar com senha;
- solicitar recuperação sem revelar se a conta existe;
- definir nova senha a partir do evento `PASSWORD_RECOVERY`;
- cadastrar e confirmar TOTP por QR code ou chave manual;
- bloquear sincronização enquanto a sessão estiver em `aal1`;
- desafiar um TOTP já verificado para elevar a sessão a `aal2`;
- cadastrar um segundo TOTP de reserva;
- impedir pela interface a remoção do último fator verificado;
- encerrar a sessão local, outras sessões ou todas as sessões;
- preservar o isolamento do perfil convidado anterior.

A política do cliente exige pelo menos 12 caracteres. A mesma exigência precisa ser ativada no Supabase Auth antes da publicação para impedir contorno por chamada direta à API do provedor.

### API

Para cada operação privada de um `client_id` vinculado e para as ações de conta, a API:

1. valida o access token com `auth.getUser`;
2. extrai `session_id` apenas depois da validação do token;
3. consulta o AAL do token;
4. chama `huntnexus_auth_session_gate` como `service_role`;
5. exige sessão ainda presente e não expirada em `auth.sessions`;
6. exige ao menos um fator verificado e `aal2`;
7. confirma que o usuário autenticado é o dono do binding.

Os erros são distintos: token inválido ou sessão inativa retorna 401; MFA não cadastrada ou desafio pendente retorna 403.

### Banco e RLS

`0164_topic05_auth_session_gate.sql` cria uma função `security definer` de leitura sobre `auth.sessions` e `auth.mfa_factors`. Apenas `service_role` pode executá-la. `anon` e `authenticated` não recebem acesso direto.

As tabelas `huntnexus_accounts` e `player_characters` continuam com RLS habilitada. `anon` e `authenticated` não possuem `SELECT` direto em contas ou bindings. O Worker é a fronteira de autorização e não confia em um `client_id` apresentado isoladamente quando esse escopo já está vinculado.

## Recuperação e incidentes

| Situação | Resultado esperado |
| --- | --- |
| E-mail comprometido, senha redefinida, sem TOTP | dados privados bloqueados em `aal1` |
| Senha vazada, sem TOTP | dados privados bloqueados em `aal1` |
| Perda de um autenticador, segundo TOTP disponível | entrar e confirmar pelo fator reserva |
| Perda de todos os fatores | recuperação assistida futura; nenhuma remoção automática por e-mail |
| Token revogado com JWT ainda dentro do `exp` | API recusa porque `auth.sessions` não contém sessão ativa |
| UUID de outro jogador com token A | API recusa por ownership do binding |

Uma recuperação assistida deverá ter política de verificação, trilha de auditoria, espera e notificação antes de existir em produção. Não há bypass administrativo implementado neste tópico.

## Migração das contas existentes

As duas contas usadas anteriormente por Magic Link preservam binding, conta e personagens. Depois da publicação do novo fluxo, cada titular deverá:

1. usar `Esqueci a senha` para definir a primeira senha;
2. entrar com e-mail e senha;
3. cadastrar e verificar o TOTP principal;
4. cadastrar um segundo TOTP de reserva;
5. testar uma segunda sessão/dispositivo e isolamento A/B.

Nenhuma migration altera linhas de `auth.users`, senhas ou fatores. Não existe merge automático de contas ou personagens.

## Ativação e rollback

A ativação real é uma operação conjunta e controlada:

1. aplicar `0164_topic05_auth_session_gate`;
2. configurar comprimento mínimo de senha de 12 no Auth e habilitar proteção contra senhas vazadas se o plano atual oferecer o recurso;
3. confirmar TOTP habilitado e manter confirmação de e-mail;
4. testar localmente contra produção com as duas contas consentidas;
5. publicar o Worker apenas após autorização de deploy e verificar a versão;
6. executar novamente os casos A/B, dois dispositivos, recuperação, sessão revogada e logout por escopo.

Rollback antes do deploy: remover a função pela migration de rollback. Rollback depois do deploy: restaurar a versão anterior do Worker antes de remover a função. Desabilitar MFA ou apagar fatores de usuários não faz parte do rollback.
