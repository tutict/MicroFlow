package com.microflow.bootstrap.pairing;

import jakarta.servlet.http.HttpServletRequest;
import jakarta.validation.Valid;
import java.nio.charset.StandardCharsets;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v1/bootstrap")
public class BootstrapController {

    private final PairingService pairingService;
    private final PairingQrCodeService pairingQrCodeService;
    private final PairingLocalAccessGuard pairingLocalAccessGuard;
    private final ServerEndpointResolver serverEndpointResolver;

    public BootstrapController(
            PairingService pairingService,
            PairingQrCodeService pairingQrCodeService,
            PairingLocalAccessGuard pairingLocalAccessGuard,
            ServerEndpointResolver serverEndpointResolver
    ) {
        this.pairingService = pairingService;
        this.pairingQrCodeService = pairingQrCodeService;
        this.pairingLocalAccessGuard = pairingLocalAccessGuard;
        this.serverEndpointResolver = serverEndpointResolver;
    }

    @PostMapping("/pair")
    public ResponseEntity<PairingResponse> pair(
            @Valid @RequestBody PairingRequest request,
            HttpServletRequest httpRequest
    ) {
        var exchange = pairingService.redeem(request.pairingCode());
        var endpoints = serverEndpointResolver.resolve(httpRequest);
        return ResponseEntity.ok(new PairingResponse(
                exchange.instanceName(),
                endpoints.serverOrigin(),
                endpoints.apiBaseUrl(),
                endpoints.wsBaseUrl(),
                exchange.pairedAt().toString()
        ));
    }

    @GetMapping("/challenge")
    public PairingChallengeResponse challenge(HttpServletRequest request) {
        pairingLocalAccessGuard.ensureLocalRequest(request);
        return buildChallengeResponse(request);
    }

    @GetMapping(value = "/qr", produces = MediaType.IMAGE_PNG_VALUE)
    public ResponseEntity<byte[]> qr(HttpServletRequest request) {
        pairingLocalAccessGuard.ensureLocalRequest(request);
        var response = buildChallengeResponse(request);
        var png = pairingQrCodeService.png(response.qrPayload(), 320);
        return ResponseEntity.ok()
                .header(HttpHeaders.CACHE_CONTROL, "no-store, max-age=0")
                .contentType(MediaType.IMAGE_PNG)
                .body(png);
    }

    @GetMapping(value = "/console", produces = MediaType.TEXT_HTML_VALUE)
    public ResponseEntity<byte[]> console(HttpServletRequest request) {
        pairingLocalAccessGuard.ensureLocalRequest(request);
        var response = buildChallengeResponse(request);
        var html = """
                <!doctype html>
                <html lang="en">
                <head>
                  <meta charset="utf-8">
                  <meta name="viewport" content="width=device-width, initial-scale=1">
                  <meta http-equiv="refresh" content="30">
                  <title>MicroFlow Pairing Console</title>
                  <style>
                    :root { color-scheme: light dark; }
                    body {
                      margin: 0;
                      font-family: "Segoe UI", Arial, sans-serif;
                      background: #eef3f3;
                      color: #112026;
                    }
                    main {
                      max-width: 920px;
                      margin: 32px auto;
                      padding: 0 20px;
                    }
                    .card {
                      background: rgba(255,255,255,0.86);
                      border: 1px solid #d1dcdf;
                      border-radius: 24px;
                      box-shadow: 0 18px 48px rgba(17,32,38,0.08);
                      padding: 28px;
                    }
                    .badge {
                      display: inline-block;
                      padding: 8px 12px;
                      border-radius: 999px;
                      background: rgba(31,111,92,0.12);
                      color: #1f6f5c;
                      font-weight: 700;
                      font-size: 13px;
                    }
                    h1 {
                      margin: 18px 0 8px;
                      font-size: 38px;
                      line-height: 1.05;
                    }
                    .code {
                      font-size: 42px;
                      letter-spacing: 4px;
                      font-weight: 800;
                      margin: 20px 0;
                      font-family: Consolas, "SFMono-Regular", monospace;
                    }
                    .grid {
                      display: grid;
                      grid-template-columns: 1.2fr 0.8fr;
                      gap: 24px;
                      align-items: start;
                    }
                    dl {
                      margin: 0;
                    }
                    dt {
                      margin-top: 14px;
                      font-size: 12px;
                      text-transform: uppercase;
                      letter-spacing: 0.08em;
                      color: #607078;
                      font-weight: 700;
                    }
                    dd {
                      margin: 6px 0 0;
                      font-size: 16px;
                      word-break: break-all;
                    }
                    img {
                      width: 100%%;
                      max-width: 320px;
                      border-radius: 18px;
                      border: 1px solid #d1dcdf;
                      background: white;
                    }
                    pre {
                      margin: 18px 0 0;
                      padding: 16px;
                      border-radius: 18px;
                      background: #102028;
                      color: #f4f8f8;
                      overflow: auto;
                      font-size: 13px;
                      line-height: 1.45;
                    }
                  </style>
                </head>
                <body>
                  <main>
                    <section class="card">
                      <span class="badge">Local pairing console</span>
                      <h1>%s</h1>
                      <p>Open the frontend, enter the server URL and pairing code, or scan the QR payload on this screen.</p>
                      <div class="grid">
                        <div>
                          <div class="code">%s</div>
                          <dl>
                            <dt>Expires At</dt>
                            <dd>%s</dd>
                            <dt>Server Origin</dt>
                            <dd>%s</dd>
                            <dt>API Base URL</dt>
                            <dd>%s</dd>
                            <dt>WebSocket Base URL</dt>
                            <dd>%s</dd>
                          </dl>
                          <pre>%s</pre>
                        </div>
                        <div>
                          <img alt="Pairing QR code" src="/api/v1/bootstrap/qr">
                        </div>
                      </div>
                    </section>
                  </main>
                </body>
                </html>
                """.formatted(
                escapeHtml(response.instanceName()),
                escapeHtml(response.pairingCode()),
                escapeHtml(response.expiresAt()),
                escapeHtml(response.serverOrigin()),
                escapeHtml(response.apiBaseUrl()),
                escapeHtml(response.wsBaseUrl()),
                escapeHtml(response.qrPayload())
        );
        return ResponseEntity.ok()
                .contentType(new MediaType("text", "html", StandardCharsets.UTF_8))
                .body(html.getBytes(StandardCharsets.UTF_8));
    }

    private PairingChallengeResponse buildChallengeResponse(HttpServletRequest request) {
        var challenge = pairingService.currentChallenge();
        var endpoints = serverEndpointResolver.resolve(request);
        var payload = new PairingQrPayload(
                pairingService.instanceName(),
                challenge.code(),
                endpoints.serverOrigin(),
                endpoints.apiBaseUrl(),
                endpoints.wsBaseUrl(),
                challenge.expiresAt().toString()
        );
        return new PairingChallengeResponse(
                pairingService.instanceName(),
                challenge.code(),
                challenge.expiresAt().toString(),
                endpoints.serverOrigin(),
                endpoints.apiBaseUrl(),
                endpoints.wsBaseUrl(),
                pairingQrCodeService.payloadJson(payload)
        );
    }

    private String escapeHtml(String value) {
        return value
                .replace("&", "&amp;")
                .replace("<", "&lt;")
                .replace(">", "&gt;")
                .replace("\"", "&quot;");
    }
}
