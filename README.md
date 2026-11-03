# AI Rental Triage & Checkout Agent (FSM + Deterministic Guardrails)

Agente de autoatendimento e triagem operacional baseado em **Máquina de Estados Finita (FSM)** orquestrado via **n8n** e **Google Gemini**. Desenvolvido para automatizar uma operação real de locação de carrinhos de sorvete para eventos (Oggi Sorvetes Barueri).

![Workflow n8n](./assets/n8n_workflow_execution.png)

## Problema de Negócio

No processo de locação de equipamentos térmicos para eventos, o atendimento humano sofria com gargalos repetitivos: validação de capacidade por carrinho (limite de 200 picolés), explicação de regras de comodato (R$ 2.500/equipamento), dúvidas sobre autonomia térmica (6h) e emissão manual de cobranças Pix.

## Arquitetura e Decisões de Engenharia de IA

O sistema foi desenhado separando **raciocínio probabilístico (LLM)** de **regras financeiras determinísticas (Código)**:

1. **Orquestração por Máquina de Estados (FSM):** Em vez de um chatbot aberto sujeito a desvios de contexto, o LLM opera como um classificador e roteador de estados (`CONFIRMAR_DADOS` $\to$ `DEFINIR_LOGISTICA` $\to$ `DEFINIR_PAGAMENTO` $\to$ `AGUARDAR_COMPROVANTE` / `RESERVA_CONCLUIDA` / `TRANSBORDO_HUMANO`).
2. **Prevenção de Alucinação Financeira (Zero-Hallucination Pix Engine):** LLMs não devem gerar payloads criptográficos ou linhas digitáveis bancárias. Quando a IA identifica intenção de pagamento antecipado (`pix_antecipado`), um nó JavaScript dedicado ([`src/pix_emv_engine.js`](./src/pix_emv_engine.js)) assume o cálculo do padrão **EMVCo BR Code** com verificação polinomial **CRC16-CCITT** oficial do Banco Central.
3. **Loop de Retenção Contextual (FAQ in-funnel):** Se o cliente faz perguntas técnicas no meio do funil (ex: se o carrinho cabe em um veículo hatch ou quanto tempo dura o gelo), o agente responde com base na base de conhecimento, **mantém o estado atual** sem disparar alertas falsos e reconduz o usuário à decisão pendente.
4. **Human-in-the-Loop (Transbordo Inteligente):** Solicitações fora da alçada da automação (pedidos de desconto corporativo, isenção de taxas ou condições atípicas) acionam automaticamente a flag `acionar_humano: true`, pausando o autoatendimento e enviando um dossiê operacional via SMTP ao gerente.

## Fluxo de Execução no n8n

1. **Webhook (POST):** Recebe o estado atual da sessão, metadados da reserva vindos do backend Django e a mensagem do cliente.
2. **Google Gemini (Decision Engine):** Processa a entrada contra o [`prompts/system_prompt.md`](./prompts/system_prompt.md) e retorna estritamente um contrato JSON tipado.
3. **Code in JavaScript:** Sanitiza o payload, executa o motor de geração Pix EMV (`CRC16`) e avalia regras de disparo de notificação.
4. **Respond to Webhook:** Devolve a resposta estruturada em tempo real com baixa latência.
5. **If & Send Email (SMTP):** Filtra conversas intermediárias e notifica a gerência apenas em fechamentos de pedido ou necessidades de transbordo humano.

## Casos de Teste Validados

Os scripts de simulação encontram-se em [`tests/run_scenarios.ps1`](./tests/run_scenarios.ps1):

| Cenário | Entrada Simulada | Comportamento do Agente | Notifica Gerente? |
| :--- | :--- | :--- | :---: |
| **1. Checkout Pix** | Escolha de retirada na loja + pagamento Pix imediato (110 un). | Avança para `AGUARDAR_COMPROVANTE` e gera payload Pix EMV válido. | Sim (`true`) |
| **2. Dúvida no Funil** | Pergunta sobre duração de 5h de festa e transporte em HB20. | Responde regra de 6h e rebatimento de banco; retém em `DEFINIR_LOGISTICA`. | Não (`false`) |
| **3. Edge Case / Desconto** | Pedido de 450 un solicitando 15% de desconto e frete grátis. | Calcula 3 carrinhos (R$ 7.500 comodato) e rota para `TRANSBORDO_HUMANO`. | Sim (`true`) |

## Tecnologias Utilizadas

* **Orquestração:** n8n
* **LLM:** Google Gemini 3.8 Flash
* **Runtime Customizado:** JavaScript (ES6) para parsing e cálculo EMV/CRC16
* **Integração & Testes:** REST Webhooks, SMTP, PowerShell