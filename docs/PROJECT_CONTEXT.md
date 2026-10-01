# HuntNexus — Contexto do Projeto

## Objetivo

Construir uma plataforma capaz de analisar hunts, criaturas, equipamentos, dano, charms, Wheel, RTC e builds usando dados rastreáveis e atualizados.

A prioridade atual não é o frontend. É a qualidade da informação.

## Modelo mental

```text
Tibia factual
        +
RubinOT versionado
        +
logs reais de players
        +
referências editoriais separadas
        ↓
HuntNexus Brain
```

## Fase atual

1. mapear fontes;
2. definir schema;
3. importar dados oficiais;
4. reconciliar diferenças RubinOT;
5. importar sessões comunitárias;
6. normalizar estatísticas;
7. construir motor analítico;
8. somente depois construir o site final.

## Resultado esperado

A Brain deve conseguir responder, com fonte:

- quais monstros existem em uma hunt;
- HP/XP e resistências;
- quais tipos de dano eles causam;
- composição de dano recebido;
- quais itens protegem melhor;
- quais equipamentos estão disponíveis por level/vocação;
- se o RubinOT alterou algum valor;
- qual desempenho real players semelhantes obtiveram;
- qual recomendação é suportada pelos dados.
