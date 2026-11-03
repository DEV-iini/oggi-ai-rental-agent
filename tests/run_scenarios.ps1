# ==============================================================================
# SUÍTE DE TESTES: AI RENTAL TRIAGE AGENT (OGGI BARUERI)
# Pré-requisito: Workflow ativo em modo de escuta no n8n (localhost:5678)
# ==============================================================================

$endpoint = "http://localhost:5678/webhook-test/novo-aluguel"

Write-Host "--------------------------------------------------" -ForegroundColor Cyan
Write-Host "CENÁRIO 1: Conversão direta com pagamento via Pix" -ForegroundColor Yellow
Write-Host "Expectativa: Estado AGUARDAR_COMPROVANTE + Pix EMV gerado + Notificação True" -ForegroundColor Gray
Write-Host "--------------------------------------------------" -ForegroundColor Cyan

$cenario1 = @'
{
  "reserva_id": 51,
  "cliente": "Vinicius",
  "data_evento": "2026-11-18",
  "valor_pedido": 185.50,
  "total_sorvetes": 110,
  "endereco": "Rua Campos Sales, Centro, Barueri",
  "estado_atual": "DEFINIR_PAGAMENTO",
  "mensagem_cliente": "Vou retirar na loja com meu carro. Quero deixar pago agora no Pix."
}
'@

Invoke-RestMethod -Uri $endpoint -Method Post -Body $cenario1 -ContentType "application/json; charset=utf-8" | ConvertTo-Json -Depth 5


Write-Host "`n--------------------------------------------------" -ForegroundColor Cyan
Write-Host "CENÁRIO 2: FAQ in-funnel (Dúvida técnica / Looping)" -ForegroundColor Yellow
Write-Host "Expectativa: Mantém DEFINIR_LOGISTICA + Notificação False" -ForegroundColor Gray
Write-Host "--------------------------------------------------" -ForegroundColor Cyan

$cenario2 = @'
{
  "reserva_id": 52,
  "cliente": "Mariana",
  "data_evento": "2026-11-22",
  "valor_pedido": 350.00,
  "total_sorvetes": 200,
  "endereco": "Alameda Rio Negro, Alphaville, Barueri",
  "estado_atual": "DEFINIR_LOGISTICA",
  "mensagem_cliente": "A festa vai durar 5 horas, aguenta sem derreter? E cabe num HB20 hatch?"
}
'@

Invoke-RestMethod -Uri $endpoint -Method Post -Body $cenario2 -ContentType "application/json; charset=utf-8" | ConvertTo-Json -Depth 5


Write-Host "`n--------------------------------------------------" -ForegroundColor Cyan
Write-Host "CENÁRIO 3: Exceção comercial e transbordo humano" -ForegroundColor Yellow
Write-Host "Expectativa: 3 carrinhos + R$ 7.500 comodato + Estado TRANSBORDO_HUMANO + Notificação True" -ForegroundColor Gray
Write-Host "--------------------------------------------------" -ForegroundColor Cyan

$cenario3 = @'
{
  "reserva_id": 53,
  "cliente": "Carlos Eduardo",
  "data_evento": "2026-11-25",
  "valor_pedido": 720.00,
  "total_sorvetes": 450,
  "endereco": "Av. Anápolis, Bethaville, Barueri",
  "estado_atual": "CONFIRMAR_DADOS",
  "mensagem_cliente": "Estou pegando 450 picolés para a empresa. Consegue 15% de desconto e frete grátis?"
}
'@

Invoke-RestMethod -Uri $endpoint -Method Post -Body $cenario3 -ContentType "application/json; charset=utf-8" | ConvertTo-Json -Depth 5