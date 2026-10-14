# HuntNexus — roadmap de realinhamento e execução

**Decisão vinculante:** [ADR-0001](docs/ADR_0001_PRODUCT_DOMAIN_AND_BRAIN.md). **Estado:** promoção congelada; executar um tópico por vez, fechar evidências e checkpoint antes de avançar. O trabalho FE-40–48 nos PRs #3/#4 é histórico técnico preservado e não define a ordem atual.

## Processo de cada tópico

1. Confirmar branch, HEAD, ambiente e pendências não commitadas.
2. Ler `AGENTS.md`, `CODEX_START_HERE.md`, `PROJECT_CONTEXT.md`, `CURRENT_STATUS.md`, este roteiro, ADR-0001 e os checkpoints relevantes.
3. Definir um resultado observável e não misturar o tópico seguinte.
4. Reutilizar código, dados e testes válidos; aplicar mudanças aditivas e reversíveis.
5. Separar evidência documental, build, fixture `SYNTHETIC`, API read-only, SQL, browser e gameplay real.
6. Atualizar `CURRENT_STATUS.md`, criar checkpoint, registrar SHA/runs e publicar branch/PR sem merge/deploy enquanto o congelamento estiver ativo.
7. Entregar `PASS / Pendente / Bloqueado`; avançar somente quando o critério de término do tópico estiver satisfeito.

## Sequência vinculante

| # | Tópico | Estado | Termina quando |
| ---: | --- | --- | --- |
| 1 | Congelar merge e deploy | **PASS** | branch, produção, banco, PRs, SHAs/versões e rollback registrados; promoção automática bloqueada |
| 2 | Registrar definição oficial do produto | **PASS** | ADR, contexto, arquitetura, instruções e roadmap usam os mesmos conceitos e critérios |
| 3 | Auditar o Brain completo | **PASS** | cada fonte tem estado mensurável de cadastro, acesso, coletor, ingestão, normalização, proveniência, atualização, termos, cobertura e lacunas |
| 4 | Corrigir modelo de conta e personagens | Próximo | uma conta gerencia vários personagens sem mistura, com migração aditiva dos dados existentes |
| 5 | Reconstruir autenticação e recuperação | Pendente | entrada forte, MFA/recuperação/sessões e isolamento A/B comprovados na API e RLS |
| 6 | Fechar segurança do Supabase e API | Pendente | matriz de acesso, funções/grants/RLS auditados, testes negativos/positivos, backup e restauração comprovados |
| 7 | Completar fontes Tier A e B | Pendente | fatos usados em cálculos têm fonte, URL, data, versão, validade e confiança |
| 8 | Reconciliar overlay RubinOT | Pendente | cada valor efetivo distingue base Tibia, alteração RubinOT, versão e evidência |
| 9 | Formalizar motor do Brain | Pendente | recomendações são determinísticas, versionadas, explicáveis e reproduzíveis |
| 10 | Construir experiência pública | Pendente | visitante descobre e analisa hunts sem cadastrar personagem |
| 11 | Conectar experiência pessoal | Pendente | personagem ativo troca todo contexto privado sem alterar catálogo global |
| 12 | Implementar aprendizado controlado | Pendente | divergências geram candidatos rastreáveis e promoção exige critérios explícitos |
| 13 | Realizar pilotos por vocação | Pendente | EK/RP/ED/MS/EM confrontados com exports consentidos e divergências registradas |
| 14 | Homologar produto inteiro | Pendente | segurança, desktop/mobile, acessibilidade, carga, operação, privacidade e rollback estão nos portões finais |
| 15 | Fazer release gradual | Pendente | interno → convidados → beta fechado → beta público → estável, com SHA, métricas e rollback testado |

## Critérios dos próximos blocos

### Tópico 3 — auditoria do Brain

- Inventariar todas as fontes informadas e as fontes realmente registradas.
- Provar conexão por artefato atual: configuração, coletor, snapshot, tabela/linha, job e data de observação.
- Medir cobertura por domínio sem transformar contagem em qualidade.
- Separar A/B/C/D e termos de uso.
- Publicar matriz versionada e visualização navegável baseada no mesmo snapshot.

### Tópico 4 — conta e personagens

- Desenhar `huntnexus_accounts` e `player_characters` com ownership e personagem ativo.
- Mapear toda FK/PK e RPC presa ao `client_id` antes da migration.
- Migrar aditivamente, preservar legado e fornecer rollback/verificação.
- Não alterar autenticação no mesmo tópico.

### Tópico 5 — autenticação

- Selecionar métodos suportados pela infraestrutura atual com base em documentação oficial.
- Exigir proteção reforçada para troca de e-mail, recuperação, remoção de MFA, exportação e exclusão.
- Testar contas e personagens distintos, sessões/dispositivos e caminhos negativos.

## Operações que exigem o usuário

- segredos por gestão segura do provedor;
- alterações destrutivas, custos, autenticação real e deploy;
- dados privados e participação de pilotos;
- aprovação do descongelamento, merge e cada fase do release.

## Histórico preservado

- FE-40 / PR #3 e FE-41–48 / PR #4 permanecem Draft.
- Seus testes e implementações podem ser reaproveitados após revisão contra ADR-0001.
- Nada no histórico autoriza chamar o Brain de completo ou o release de homologado.
