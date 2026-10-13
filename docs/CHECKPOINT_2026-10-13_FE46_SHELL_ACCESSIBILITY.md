# FE-46 — teclado e navegação mobile

Incremento em 2026-10-13. Shell fornece link Pular para o conteúdo e main focável. Menu tem aria-expanded/controls, navegação principal nomeada e link ativo aria-current. Menu fechado no mobile é inert e aria-hidden; não mantém links fora da tela no caminho do teclado. Abrir foca o primeiro link; Escape/backdrop fecham e devolvem foco ao botão; navegar fecha; voltar a desktop libera navegação.

Build/TypeScript PASS. QA SYNTHETIC `web/app/tests/fe46-shell-accessibility-preview.mjs`, desktop 1440/mobile 390: skip link, estados, foco, Escape, backdrop, rota, resize e ausência de overflow/pageerror. Screenshots em `web/app/fe46-shell-qa/`, artefato de CI. Inspeção visual FE-43 confirma Main/BP mobile separado e ações nativas.

Não é auditoria WCAG completa: leitor de tela, contraste global, zoom/dispositivos reais e todas as rotas continuam pendentes. Nenhuma mudança de dados/Auth. Rollback por revert do incremento e rebuild/CI.
