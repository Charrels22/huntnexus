# Collectors

Um coletor por fonte.

Cada coletor deve:

1. respeitar termos/robots/rate limits;
2. preferir API ou exportação estruturada;
3. salvar primeiro um snapshot bruto;
4. gerar hash do conteúdo;
5. nunca escrever diretamente no modelo factual final;
6. deixar normalização para etapa separada.
