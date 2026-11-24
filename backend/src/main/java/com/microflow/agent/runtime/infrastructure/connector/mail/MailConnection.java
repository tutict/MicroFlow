package com.microflow.agent.runtime.infrastructure.connector.mail;

import java.io.ByteArrayOutputStream;
import java.io.Closeable;
import java.io.IOException;
import java.io.InputStream;
import java.io.OutputStream;
import java.net.InetSocketAddress;
import java.net.Socket;
import java.nio.charset.StandardCharsets;
import javax.net.ssl.SSLSocket;
import javax.net.ssl.SSLSocketFactory;

/**
 * Line-oriented socket for SMTP and IMAP.
 *
 * <p>Reads bytes one at a time instead of wrapping the stream in a
 * {@code BufferedReader}. That is slower, but it is the difference between a
 * correct and a subtly broken STARTTLS upgrade: a buffered reader would happily
 * consume bytes past the end of the greeting line and then hand them to the
 * TLS layer as if they were encrypted.
 */
public final class MailConnection implements Closeable {

    private static final int CONNECT_TIMEOUT_MS = 10_000;
    private static final int READ_TIMEOUT_MS = 15_000;
    private static final int MAX_LINE_BYTES = 64 * 1024;

    private final String host;
    private final int port;
    private Socket socket;
    private InputStream input;
    private OutputStream output;

    private MailConnection(String host, int port, Socket socket) throws IOException {
        this.host = host;
        this.port = port;
        this.socket = socket;
        this.input = socket.getInputStream();
        this.output = socket.getOutputStream();
    }

    public static MailConnection open(String host, int port, boolean implicitTls) throws IOException {
        var plain = new Socket();
        try {
            plain.connect(new InetSocketAddress(host, port), CONNECT_TIMEOUT_MS);
            plain.setSoTimeout(READ_TIMEOUT_MS);
            var socket = implicitTls ? verifiedTls(plain, host, port) : plain;
            return new MailConnection(host, port, socket);
        } catch (IOException | RuntimeException exception) {
            try {
                plain.close();
            } catch (IOException ignored) {
                // Preserve the connection or handshake failure.
            }
            throw exception;
        }
    }

    /** Upgrades in place; callers must have consumed the whole previous reply. */
    public void startTls() throws IOException {
        var secure = verifiedTls(socket, host, port);
        socket = secure;
        input = secure.getInputStream();
        output = secure.getOutputStream();
    }

    private static SSLSocket verifiedTls(Socket plain, String host, int port) throws IOException {
        SSLSocket secure = null;
        try {
            var factory = (SSLSocketFactory) SSLSocketFactory.getDefault();
            secure = (SSLSocket) factory.createSocket(plain, host, port, true);
            secure.setSoTimeout(READ_TIMEOUT_MS);
            var parameters = secure.getSSLParameters();
            parameters.setEndpointIdentificationAlgorithm("HTTPS");
            secure.setSSLParameters(parameters);
            secure.startHandshake();
            return secure;
        } catch (IOException | RuntimeException exception) {
            try {
                if (secure != null) secure.close();
                else plain.close();
            } catch (IOException ignored) {
                // Preserve the TLS verification failure.
            }
            throw exception;
        }
    }

    public void write(String line) throws IOException {
        output.write((line + "\r\n").getBytes(StandardCharsets.UTF_8));
        output.flush();
    }

    /** Raw write for message bodies that already carry their own CRLF framing. */
    public void writeRaw(String payload) throws IOException {
        output.write(payload.getBytes(StandardCharsets.UTF_8));
        output.flush();
    }

    /** Reads one CRLF-terminated line; returns {@code null} at end of stream. */
    public String readLine() throws IOException {
        var buffer = new ByteArrayOutputStream(128);
        while (true) {
            var value = input.read();
            if (value == -1) {
                return buffer.size() == 0 ? null : buffer.toString(StandardCharsets.UTF_8);
            }
            if (value == '\n') {
                var line = buffer.toString(StandardCharsets.UTF_8);
                return line.endsWith("\r") ? line.substring(0, line.length() - 1) : line;
            }
            buffer.write(value);
            if (buffer.size() > MAX_LINE_BYTES) {
                throw new IOException("Mail server sent an oversized line");
            }
        }
    }

    /**
     * Reads a possibly multi-line SMTP reply and returns the terminating line.
     *
     * <p>Continuation lines carry a hyphen after the status code
     * ({@code 250-SIZE 1024}); the final line carries a space.
     */
    public String readReply() throws IOException {
        while (true) {
            var line = readLine();
            if (line == null) {
                return null;
            }
            if (line.length() < 4 || line.charAt(3) != '-') {
                return line;
            }
        }
    }

    /** Reads exactly {@code length} bytes; used for IMAP literals. */    public String readBytes(int length) throws IOException {
        var buffer = new byte[length];
        var read = 0;
        while (read < length) {
            var count = input.read(buffer, read, length - read);
            if (count == -1) {
                throw new IOException("Mail server closed the connection mid-literal");
            }
            read += count;
        }
        return new String(buffer, StandardCharsets.UTF_8);
    }

    @Override
    public void close() {
        try {
            if (socket != null) {
                socket.close();
            }
        } catch (IOException ignored) {
            // Closing a broken socket is not actionable.
        }
    }
}
