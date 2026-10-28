# Tópico 5 — runbook de ativação e aceite real

**Estado:** preparado; nenhuma etapa mutável executada. **Ambiente alvo:** Supabase `urbncbjapasnjqjqicjv`. **PR:** [#8](https://github.com/Charrels22/huntnexus/pull/8). **Migration:** `0164_topic05_auth_session_gate.sql`, SHA-256 `829b33132b0e9b10893a0ab9a28583a4ad7fba91d1dde602f2ec99f307090b16`.

Este roteiro evita gastar o limite de e-mail antes de a infraestrutura estar pronta e separa mudança de banco, configuração Auth, teste privado e deploy. Nenhuma senha, segredo TOTP, nonce ou token deve ser copiado para este arquivo, issue, PR ou log.

## Portões de autorização

| Operação | Autorização exigida | Estado |
| --- | --- | --- |
| Aplicar `0164` em produção | mencionar `0164` explicitamente | PENDENTE |
| Alterar política do Supabase Auth | senha, troca segura e alertas enumerados | PENDENTE |
| Configurar SMTP | provedor, credenciais seguras, domínio/remetente e eventual custo | PENDENTE |
| Testar as contas piloto | consentimento para os dois e-mails e envios reais | PENDENTE |
| Publicar o Worker | autorização de deploy separada | PENDENTE |

## Fase 0 — preservar baseline

1. Registrar HEAD da PR, migration remota mais recente e deployment/version ativos.
2. Confirmar que a produção ainda termina em `0163` e que `huntnexus_auth_session_gate` não existe.
3. Confirmar o SHA-256 de `0164` e a presença do rollback.
4. Exportar apenas metadados/configuração necessários; não exportar senhas, tokens ou segredos TOTP.
5. Não alterar o Worker enquanto o release estiver congelado.

## Fase 1 — banco

1. Aplicar somente `0164_topic05_auth_session_gate.sql`.
2. Executar [`2026-10-14-topic05-post-migration-verification.sql`](2026-10-14-topic05-post-migration-verification.sql).
3. Exigir `security definer`, `stable`, `search_path = ''`, referências qualificadas, execução apenas por `service_role` e retorno nulo para entradas nulas.
4. Confirmar que nenhuma linha de `auth.users`, `auth.sessions` ou `auth.mfa_factors` foi alterada pela migration.
5. Em falha antes do deploy, executar `0164_topic05_auth_session_gate_rollback.sql` e repetir a verificação de ausência.

## Fase 2 — Auth e e-mail

Executar em uma única janela controlada, antes de qualquer envio de teste:

1. manter confirmação de e-mail e TOTP habilitados;
2. definir senha mínima em 12 caracteres;
3. exigir minúscula, maiúscula, dígito e símbolo;
4. habilitar `Secure password change` e exigência da senha atual;
5. habilitar notificações de troca de senha/e-mail/telefone, vínculo/remoção de método de login e inclusão/remoção de MFA;
6. confirmar `Site URL` em `https://huntnexus.charr3ls22.workers.dev`;
7. confirmar allow list apenas com `https://huntnexus.charr3ls22.workers.dev/account` para a produção;
8. configurar SMTP operacional antes do release público e depois revisar os limites de envio;
9. enviar uma mensagem controlada e registrar entrega/erro sem armazenar conteúdo sensível.

O SMTP padrão serve apenas para exploração/testes restritos, não possui SLA e pode recusar destinatários fora da equipe. Um envio anterior bem-sucedido não substitui esse portão operacional.

## Fase 3 — aceite das contas piloto

As pessoas que controlam as caixas e os autenticadores digitam senhas, nonces e códigos TOTP diretamente no navegador. O operador registra apenas resultado, horário, navegador/dispositivo e identificador técnico não secreto.

| ID | Caso | Resultado esperado | Estado |
| --- | --- | --- | --- |
| A01 | conta A pede recuperação | resposta não revela existência da conta; link chega ao domínio correto | NÃO EXECUTADO |
| A02 | conta A redefine a senha | senha forte aceita; sessão continua `aal1` sem TOTP | NÃO EXECUTADO |
| A03 | conta A tenta dados privados sem TOTP | API recusa com 403 | NÃO EXECUTADO |
| A04 | conta A cadastra e verifica TOTP principal | sessão eleva a `aal2` | NÃO EXECUTADO |
| A05 | conta A cadastra TOTP reserva | dois fatores verificados permanecem ativos | NÃO EXECUTADO |
| A06 | conta B repete recuperação e dois TOTP | conta B chega a `aal2` sem alterar A | NÃO EXECUTADO |
| I01 | token A consulta binding/personagem B | API recusa por ownership | NÃO EXECUTADO |
| I02 | token B consulta binding/personagem A | API recusa por ownership | NÃO EXECUTADO |
| D01 | conta A entra em segundo dispositivo | mesmo conjunto de personagens; sessão distinta e viva | NÃO EXECUTADO |
| S01 | logout local no dispositivo 1 | dispositivo 1 encerra; dispositivo 2 permanece | NÃO EXECUTADO |
| S02 | logout de outras sessões | sessão atual permanece; segunda sessão é recusada | NÃO EXECUTADO |
| S03 | logout global | todas as sessões da conta são recusadas | NÃO EXECUTADO |
| R01 | JWT de sessão revogada ainda dentro de `exp` | API recusa por sessão ausente/inativa | NÃO EXECUTADO |
| M01 | tentativa de remover o último TOTP | interface bloqueia | NÃO EXECUTADO |
| M02 | remover um TOTP com código fresco do fator preservado | remoção aceita; sessão atualizada; um fator permanece | NÃO EXECUTADO |
| P01 | troca autenticada de senha em sessão `aal2` | exige senha atual; nonce quando solicitado pelo provedor | NÃO EXECUTADO |
| N01 | alertas de senha/MFA/método de login | mensagens correspondentes são entregues | NÃO EXECUTADO |

## Fase 4 — deploy separado

1. Confirmar autorização específica de deploy.
2. Publicar o mesmo SHA validado, sem habilitar Preview como efeito colateral.
3. Registrar deployment ID, version ID, horário e rollback alvo.
4. Repetir A03, I01, I02, D01, R01 e P01 no site publicado.
5. Em regressão, restaurar primeiro a versão anterior do Worker; só remover a função do banco depois de confirmar que a versão antiga está ativa.

## Critério de conclusão

O Tópico 5 termina apenas quando Fases 1–3 passarem com evidência real de A/B, dois dispositivos, recuperação, MFA, revogação e alertas. O deploy pertence ao gate final desta entrega e continua separado até autorização explícita.

## Referência oficial de SMTP

- [Supabase — Send emails with custom SMTP](https://supabase.com/docs/guides/auth/auth-smtp)
- [Supabase — Production Checklist](https://supabase.com/docs/guides/deployment/going-into-prod)
