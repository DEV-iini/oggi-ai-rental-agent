/**
 * Motor Determinístico: Parser de Saída do LLM + Gerador Pix EMVCo (BR Code)
 * Garante que cálculos financeiros e checksum CRC16 não dependam de geração probabilística.
 */

const entrada = $json;
let bruto = entrada.text || entrada.output || entrada.content || JSON.stringify(entrada);
const marcador = String.fromCharCode(96).repeat(3);

let limpo = String(bruto).split(marcador + "json").join("");
limpo = limpo.split(marcador).join("").trim();

let dados;
try {
  dados = JSON.parse(limpo);
} catch (err) {
  return [{ json: { erro_parse: true, texto_original: bruto } }];
}

function campoEMV(id, valor) {
  const str = String(valor);
  const tam = str.length.toString().padStart(2, "0");
  return id + tam + str;
}

function gerarPixCopiaECola(chave, nome, cidade, valorNum, txid) {
  const conta = campoEMV("00", "br.gov.bcb.pix") + campoEMV("01", chave);
  const valorFormatado = Number(valorNum || 0).toFixed(2);
  
  let payload = 
    campoEMV("00", "01") +
    campoEMV("26", conta) +
    campoEMV("52", "0000") +
    campoEMV("53", "986") +
    campoEMV("54", valorFormatado) +
    campoEMV("58", "BR") +
    campoEMV("59", nome.substring(0, 25)) +
    campoEMV("60", cidade.substring(0, 15)) +
    campoEMV("62", campoEMV("05", txid)) +
    "6304";

  // Cálculo polinomial CRC16-CCITT (0x1021) exigido pelo Banco Central
  let crc = 0xFFFF;
  for (let i = 0; i < payload.length; i++) {
    crc ^= payload.charCodeAt(i) << 8;
    for (let j = 0; j < 8; j++) {
      crc = (crc & 0x8000) !== 0 ? (crc << 1) ^ 0x1021 : crc << 1;
    }
  }
  const crcHex = (crc & 0xFFFF).toString(16).toUpperCase().padStart(4, "0");
  return payload + crcHex;
}

dados.pix_copia_e_cola = null;
if (dados.forma_pagamento_definida === "pix_antecipado" || dados.proximo_estado === "AGUARDAR_COMPROVANTE") {
  dados.pix_copia_e_cola = gerarPixCopiaECola(
    "38467951000148",
    "HEVON COMERCIO LTDA",
    "BARUERI",
    dados.valor_pedido,
    "RESERVA" + dados.reserva_id
  );
}

dados.deve_enviar_email = Boolean(
  dados.acionar_humano === true || 
  dados.proximo_estado === "RESERVA_CONCLUIDA" || 
  dados.proximo_estado === "AGUARDAR_COMPROVANTE"
);

return [{ json: dados }];