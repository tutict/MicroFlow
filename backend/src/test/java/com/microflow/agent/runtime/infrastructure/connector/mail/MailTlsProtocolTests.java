package com.microflow.agent.runtime.infrastructure.connector.mail;

import static org.assertj.core.api.Assertions.assertThat;
import static org.junit.jupiter.api.Assertions.assertThrows;

import java.io.ByteArrayOutputStream;
import java.io.IOException;
import java.io.InputStream;
import java.net.InetAddress;
import java.net.ServerSocket;
import java.net.Socket;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.security.KeyStore;
import java.security.cert.X509Certificate;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.atomic.AtomicInteger;
import javax.net.ssl.KeyManagerFactory;
import javax.net.ssl.SSLContext;
import javax.net.ssl.SSLHandshakeException;
import javax.net.ssl.SSLSocket;
import javax.net.ssl.TrustManagerFactory;
import javax.net.ssl.X509TrustManager;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeAll;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.io.TempDir;
import org.junit.jupiter.api.parallel.ResourceLock;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.CsvSource;

/** Trusted loopback certificates exercise the real TLS handshake before SMTP/IMAP credentials. */
@ResourceLock("javax.net.ssl.SSLContext.default")
class MailTlsProtocolTests {
    @TempDir static Path directory;
    private static final char[] PASSWORD = "fixture-only".toCharArray();
    private static Material correct;
    private static Material wrong;
    private static SSLContext client;
    private SSLContext previous;

    record Material(SSLContext server, X509Certificate certificate) { }

    @BeforeAll static void certificates() throws Exception {
        correct = material("correct", "localhost");
        wrong = material("wrong", "wrong.example.invalid");
        var trust = KeyStore.getInstance("PKCS12");
        trust.load(null, PASSWORD);
        trust.setCertificateEntry("correct", correct.certificate);
        trust.setCertificateEntry("wrong", wrong.certificate);
        var managers = TrustManagerFactory.getInstance(TrustManagerFactory.getDefaultAlgorithm());
        managers.init(trust);
        // Both chains are trusted independently of endpoint identity. No trust-all manager is used.
        for (var manager : managers.getTrustManagers()) {
            if (manager instanceof X509TrustManager x509) {
                x509.checkServerTrusted(new X509Certificate[] {correct.certificate}, "RSA");
                x509.checkServerTrusted(new X509Certificate[] {wrong.certificate}, "RSA");
            }
        }
        client = SSLContext.getInstance("TLS");
        client.init(null, managers.getTrustManagers(), null);
    }

    @BeforeEach void trustFixtureOnly() throws Exception {
        previous = SSLContext.getDefault();
        SSLContext.setDefault(client);
    }

    @AfterEach void restoreDefaultContext() {
        SSLContext.setDefault(previous);
    }

    @ParameterizedTest(name = "trusted wrong SAN: implicit={0}, protocol={1}")
    @CsvSource({"true, SMTP", "false, SMTP", "true, IMAP", "false, IMAP"})
    void trustedWrongSanFailsBeforeAuthentication(boolean implicit, String protocol) throws Exception {
        try (var peer = new TlsPeer(wrong.server, implicit, protocol)) {
            var exception = assertThrows(IOException.class, () -> authenticate(peer, implicit, protocol));
            assertThat(exception).isInstanceOf(SSLHandshakeException.class);
            peer.awaitFinished();
            assertThat(peer.authentications.get()).as("wrong endpoint must receive no authentication command").isZero();
            assertThat(peer.connections.get()).isEqualTo(1);
        }
    }

    @ParameterizedTest(name = "trusted matching SAN: implicit={0}, protocol={1}")
    @CsvSource({"true, SMTP", "false, SMTP", "true, IMAP", "false, IMAP"})
    void trustedMatchingSanAuthenticatesSuccessfully(boolean implicit, String protocol) throws Exception {
        try (var peer = new TlsPeer(correct.server, implicit, protocol)) {
            authenticate(peer, implicit, protocol);
            peer.awaitFinished();
            assertThat(peer.authentications.get()).isEqualTo(1);
            assertThat(peer.connections.get()).isEqualTo(1);
            assertThat(peer.failure).isNull();
        }
    }

    private static void authenticate(TlsPeer peer, boolean implicit, String protocol) throws IOException {
        try (var connection = MailConnection.open("localhost", peer.port(), implicit)) {
            var smtp = protocol.equals("SMTP");
            assertThat(connection.readLine()).isEqualTo(smtp ? "220 localhost fixture" : "* OK localhost fixture");
            if (!implicit) {
                connection.write(smtp ? "STARTTLS" : "M1 STARTTLS");
                assertThat(connection.readLine()).isEqualTo(smtp ? "220 begin TLS" : "M1 OK begin TLS");
                connection.startTls();
            }
            connection.write(smtp ? "AUTH PLAIN Zml4dHVyZQ==" : "M2 LOGIN \"fixture\" \"test-only\"");
            assertThat(connection.readLine()).isEqualTo(smtp ? "235 authenticated" : "M2 OK authenticated");
        }
    }

    private static Material material(String name, String san) throws Exception {
        var storePath = directory.resolve(name + ".p12");
        var keytool = Path.of(System.getProperty("java.home"), "bin",
                System.getProperty("os.name").startsWith("Windows") ? "keytool.exe" : "keytool");
        var process = new ProcessBuilder(keytool.toString(), "-genkeypair", "-alias", "fixture",
                "-keyalg", "RSA", "-keysize", "2048", "-validity", "2",
                "-dname", "CN=fixture", "-ext", "SAN=dns:" + san,
                "-keystore", storePath.toString(), "-storetype", "PKCS12",
                "-storepass", String.valueOf(PASSWORD), "-keypass", String.valueOf(PASSWORD), "-noprompt")
                .redirectErrorStream(true).redirectOutput(directory.resolve(name + ".log").toFile()).start();
        if (!process.waitFor(30, TimeUnit.SECONDS)) {
            process.destroyForcibly();
            throw new AssertionError("Test keytool timed out");
        }
        assertThat(process.exitValue()).as("temporary test certificate generation").isZero();
        var store = KeyStore.getInstance("PKCS12");
        try (var input = Files.newInputStream(storePath)) { store.load(input, PASSWORD); }
        var keys = KeyManagerFactory.getInstance(KeyManagerFactory.getDefaultAlgorithm());
        keys.init(store, PASSWORD);
        var context = SSLContext.getInstance("TLS");
        context.init(keys.getKeyManagers(), null, null);
        return new Material(context, (X509Certificate) store.getCertificate("fixture"));
    }

    private static final class TlsPeer implements AutoCloseable {
        private final ServerSocket listener = new ServerSocket(0, 1, InetAddress.getLoopbackAddress());
        private final Thread thread;
        private final SSLContext context;
        private final boolean implicit;
        private final boolean smtp;
        private volatile Socket active;
        private volatile Throwable failure;
        final AtomicInteger connections = new AtomicInteger();
        final AtomicInteger authentications = new AtomicInteger();

        TlsPeer(SSLContext context, boolean implicit, String protocol) throws IOException {
            this.context = context;
            this.implicit = implicit;
            this.smtp = protocol.equals("SMTP");
            thread = new Thread(this::serve, "mail-tls-protocol-peer");
            thread.setDaemon(true);
            thread.start();
        }

        int port() { return listener.getLocalPort(); }

        private void serve() {
            try (var plain = listener.accept()) {
                connections.incrementAndGet();
                active = plain;
                plain.setSoTimeout(5000);
                if (!implicit) {
                    reply(plain, smtp ? "220 localhost fixture" : "* OK localhost fixture");
                    var command = line(plain.getInputStream());
                    if (!(smtp ? "STARTTLS" : "M1 STARTTLS").equals(command)) {
                        throw new AssertionError("Expected STARTTLS before credentials, got " + command);
                    }
                    reply(plain, smtp ? "220 begin TLS" : "M1 OK begin TLS");
                }
                try (var secure = (SSLSocket) context.getSocketFactory().createSocket(plain, "localhost", port(), true)) {
                    active = secure;
                    secure.setUseClientMode(false);
                    secure.setSoTimeout(5000);
                    secure.startHandshake();
                    if (implicit) reply(secure, smtp ? "220 localhost fixture" : "* OK localhost fixture");
                    var authentication = line(secure.getInputStream());
                    if (authentication != null && authentication.startsWith(smtp ? "AUTH PLAIN " : "M2 LOGIN ")) {
                        authentications.incrementAndGet();
                        reply(secure, smtp ? "235 authenticated" : "M2 OK authenticated");
                    } else if (authentication != null) {
                        throw new AssertionError("Unexpected post-TLS command: " + authentication);
                    }
                }
            } catch (SSLHandshakeException expectedClientRejection) {
                // A client refusing the wrong endpoint is the tested outcome.
            } catch (Throwable exception) {
                failure = exception;
            }
        }

        private static void reply(Socket socket, String value) throws IOException {
            socket.getOutputStream().write((value + "\r\n").getBytes(StandardCharsets.US_ASCII));
            socket.getOutputStream().flush();
        }

        private static String line(InputStream input) throws IOException {
            var bytes = new ByteArrayOutputStream();
            int value;
            while ((value = input.read()) != -1) {
                if (value == '\n') return bytes.toString(StandardCharsets.US_ASCII).replaceFirst("\\r$", "");
                bytes.write(value);
                if (bytes.size() > 65536) throw new IOException("Oversized TLS fixture command");
            }
            return bytes.size() == 0 ? null : bytes.toString(StandardCharsets.US_ASCII);
        }

        void awaitFinished() throws InterruptedException {
            thread.join(6000);
            assertThat(thread.isAlive()).as("TLS peer must finish without hanging").isFalse();
        }

        @Override public void close() throws Exception {
            listener.close();
            if (active != null) active.close();
            awaitFinished();
        }
    }
}
