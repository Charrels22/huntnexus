# FE-45 — URLs corrigidas, teste Auth bloqueado por envio

Data: 2026-10-13. Resultado parcial: configuração PASS; envio de novo Magic Link BLOQUEADO; login, dois dispositivos e isolamento A/B PENDENTES.

O usuário recebeu um link que terminou em localhost:3000 com otp_expired. Inspeção autenticada do painel confirmou Site URL localhost:3000 e zero Redirect URLs. Após o usuário salvar, nova leitura do painel confirmou Site URL `https://huntnexus.charr3ls22.workers.dev` e exatamente um retorno permitido: `https://huntnexus.charr3ls22.workers.dev/account`, com Save changes desabilitado.

Uma única solicitação pelo formulário publicado, autorizada para a primeira conta de teste, retornou `email rate limit exceeded`. Nenhum login/sincronização foi comprovado; não repetir automaticamente envios. O painel de Emails indica uso dos templates padrão e exige configurar SMTP para edição. A documentação oficial registra limite do provedor embutido de dois e-mails/hora por projeto, compartilhado pelos endpoints que enviam e-mail. Não foi determinado o instante de liberação da cota.

Próximo passo: aguardar a liberação da cota e solicitar apenas um link novo, abrir uma vez e verificar Account/Sincronizados. Alternativa para homologação sustentada/produção: preparar SMTP próprio com provedor/remetente aprovado e secrets no provedor, sujeito à aprovação de Auth/infra/custos. Não ampliar limites, criar tokens administrativos para substituir posse do e-mail nem declarar teste de Auth real concluído.

Nenhuma mudança de código/schema, configuração SMTP, limite de proteção ou dado privado foi feita pelo agente nesta verificação. Identidades das contas, links e tokens não são versionados. Capturas locais no diretório de visualizações do Codex, não no GitHub.

Referências: https://supabase.com/docs/guides/auth/redirect-urls e https://supabase.com/docs/guides/auth/rate-limits.
