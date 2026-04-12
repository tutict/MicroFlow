package com.microflow.bootstrap.pairing;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.google.zxing.BarcodeFormat;
import com.google.zxing.client.j2se.MatrixToImageWriter;
import com.google.zxing.common.BitMatrix;
import com.google.zxing.qrcode.QRCodeWriter;
import java.io.ByteArrayOutputStream;
import org.springframework.stereotype.Component;

@Component
public class PairingQrCodeService {

    private final ObjectMapper objectMapper;

    public PairingQrCodeService(ObjectMapper objectMapper) {
        this.objectMapper = objectMapper;
    }

    public String payloadJson(PairingQrPayload payload) {
        try {
            return objectMapper.writeValueAsString(payload);
        } catch (Exception ex) {
            throw new IllegalStateException("Unable to serialize pairing QR payload", ex);
        }
    }

    public byte[] png(String content, int size) {
        try {
            BitMatrix bitMatrix = new QRCodeWriter().encode(content, BarcodeFormat.QR_CODE, size, size);
            var output = new ByteArrayOutputStream();
            MatrixToImageWriter.writeToStream(bitMatrix, "PNG", output);
            return output.toByteArray();
        } catch (Exception ex) {
            throw new IllegalStateException("Unable to generate pairing QR code", ex);
        }
    }
}
