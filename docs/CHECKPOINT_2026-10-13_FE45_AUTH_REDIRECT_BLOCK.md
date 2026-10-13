# FE-45 — URLs corrigidas, teste Auth bloqueado por envio

## Atualização: login desktop confirmado pelo usuário

Em 2026-10-13, o usuário forneceu duas capturas, uma por conta de teste, exibindo Conta autenticada, Dados/Sincronizados e Conta sincronizada. Relatou uso do navegador padrão e janela anônima. Resultado: PASS parcial para login real e resolução da conta exibida na UI. Evidência fornecida pelo usuário; não é inspeção automatizada do backend nem prova de isolamento de dados/RLS.

No celular, o usuário relatou apenas abertura da página; autenticação e leitura de dados não foram concluídas por limitação de envio. Abertura da página não comprova sincronização. PENDENTES: persistência/leitura de dados diferentes por conta A/B, negativos de acesso cruzado, mesma conta em dois dispositivos, logout/expiração e recuperação convidado. Nenhum perfil/sessão privada foi lido ou alterado pelo agente. Capturas e e-mails não são versionados.

Próximo teste manual: cadastrar marcadores de perfil claramente SYNTHETIC e diferentes nas duas contas de teste, recarregar cada contexto e verificar que cada uma conserva apenas seu marcador. Depois, autenticar a primeira conta no celular e verificar o mesmo marcador persistido no desktop. Isso testa comportamento visível; segurança/RLS completa exige testes negativos específicos autorizados.

## Registro anterior: bloqueio de envio

Data: 2026-10-13, antes das capturas acima. Resultado parcial naquela tentativa: configuração PASS; envio de novo Magic Link BLOQUEADO; login, dois dispositivos e isolamento A/B PENDENTES.

O usuário recebeu um link que terminou em localhost:3000 com otp_expired. Inspeção autenticada do painel confirmou Site URL localhost:3000 e zero Redirect URLs. Após o usuário salvar, nova leitura do painel confirmou Site URL `https://huntnexus.charr3ls22.workers.dev` e exatamente um retorno permitido: `https://huntnexus.charr3ls22.workers.dev/account`, com Save changes desabilitado.

Uma única solicitação pelo formulário publicado, autorizada para a primeira conta de teste, retornou `email rate limit exceeded`. Nenhum login/sincronização foi comprovado; não repetir automaticamente envios. O painel de Emails indica uso dos templates padrão e exige configurar SMTP para edição. A documentação oficial registra limite do provedor embutido de dois e-mails/hora por projeto, compartilhado pelos endpoints que enviam e-mail. Não foi determinado o instante de liberação da cota.

Próximo passo: aguardar a liberação da cota e solicitar apenas um link novo, abrir uma vez e verificar Account/Sincronizados. Alternativa para homologação sustentada/produção: preparar SMTP próprio com provedor/remetente aprovado e secrets no provedor, sujeito à aprovação de Auth/infra/custos. Não ampliar limites, criar tokens administrativos para substituir posse do e-mail nem declarar teste de Auth real concluído.

Nenhuma mudança de código/schema, configuração SMTP, limite de proteção ou dado privado foi feita pelo agente nesta verificação. Identidades das contas, links e tokens não são versionados. Capturas locais no diretório de visualizações do Codex, não no GitHub.

Referências: https://supabase.com/docs/guides/auth/redirect-urls e https://supabase.com/docs/guides/auth/rate-limits.
