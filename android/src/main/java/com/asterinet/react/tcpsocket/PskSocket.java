package com.asterinet.react.tcpsocket;

import org.bouncycastle.tls.PSKTlsClient;
import org.bouncycastle.tls.TlsClient;
import org.bouncycastle.tls.TlsClientProtocol;
import org.bouncycastle.tls.TlsPSKIdentity;
import org.bouncycastle.tls.crypto.TlsCrypto;
import org.bouncycastle.tls.crypto.impl.bc.BcTlsCrypto;

import java.io.IOException;
import java.io.InputStream;
import java.io.OutputStream;
import java.net.InetAddress;
import java.net.Socket;
import java.net.SocketAddress;
import java.net.SocketException;
import java.nio.channels.SocketChannel;
import java.security.SecureRandom;

public class PskSocket extends Socket {
    private final static TlsCrypto crypto = new BcTlsCrypto(new SecureRandom());

    private final Socket wrap;
    private final TlsClient client;
    private TlsClientProtocol tlsClientProtocol = null;

    public PskSocket(Socket socket, TlsPSKIdentity pskIdentity, int[] supportedCipherSuites) {
        this.wrap = socket;
        this.client = new PSKTlsClient(crypto, pskIdentity) {
            @Override
            public int[] getSupportedCipherSuites() {
                return supportedCipherSuites.length > 0 ? supportedCipherSuites : super.getSupportedCipherSuites();
            }
        };
    }

    public void startHandshake() throws IOException {
        if (tlsClientProtocol != null) {
            throw new UnsupportedOperationException("TLS handshake already completed");
        }

        tlsClientProtocol = new TlsClientProtocol(wrap.getInputStream(), wrap.getOutputStream());
        tlsClientProtocol.connect(client);
    }

    @Override
    public InputStream getInputStream() {
        if (tlsClientProtocol == null) {
            throw new UnsupportedOperationException("TLS handshake must be completed first");
        }

        return tlsClientProtocol.getInputStream();
    }

    @Override
    public OutputStream getOutputStream() {
        if (tlsClientProtocol == null) {
            throw new UnsupportedOperationException("TLS handshake must be completed first");
        }

        return tlsClientProtocol.getOutputStream();
    }

    @Override
    public void close() throws IOException {
        if (tlsClientProtocol == null) {
            this.wrap.close();
        } else {
            tlsClientProtocol.close();
        }
    }

    public void connect(SocketAddress endpoint) throws IOException {
        this.wrap.connect(endpoint);
    }

    public void connect(SocketAddress endpoint, int timeout) throws IOException {
        this.wrap.connect(endpoint, timeout);
    }

    public void bind(SocketAddress bindpoint) throws IOException {
        this.wrap.bind(bindpoint);
    }

    public InetAddress getInetAddress() {
        return this.wrap.getInetAddress();
    }

    public InetAddress getLocalAddress() {
        return this.wrap.getLocalAddress();
    }

    public int getPort() {
        return this.wrap.getPort();
    }

    public int getLocalPort() {
        return this.wrap.getLocalPort();
    }

    public SocketAddress getRemoteSocketAddress() {
        return this.wrap.getRemoteSocketAddress();
    }

    public SocketAddress getLocalSocketAddress() {
        return this.wrap.getLocalSocketAddress();
    }

    public SocketChannel getChannel() {
        return this.wrap.getChannel();
    }

    public void setTcpNoDelay(boolean on) throws SocketException {
        this.wrap.setTcpNoDelay(on);
    }

    public boolean getTcpNoDelay() throws SocketException {
        return this.wrap.getTcpNoDelay();
    }

    public void setSoLinger(boolean on, int linger) throws SocketException {
        this.wrap.setSoLinger(on, linger);
    }

    public int getSoLinger() throws SocketException {
        return this.wrap.getSoLinger();
    }

    public void sendUrgentData(int data) throws IOException {
        this.wrap.sendUrgentData(data);
    }

    public void setOOBInline(boolean on) throws SocketException {
        this.wrap.setOOBInline(on);
    }

    public boolean getOOBInline() throws SocketException {
        return this.wrap.getOOBInline();
    }

    public void setSoTimeout(int timeout) throws SocketException {
        this.wrap.setSoTimeout(timeout);
    }

    public int getSoTimeout() throws SocketException {
        return this.wrap.getSoTimeout();
    }

    public void setSendBufferSize(int size) throws SocketException {
        this.wrap.setSendBufferSize(size);
    }

    public int getSendBufferSize() throws SocketException {
        return this.wrap.getSendBufferSize();
    }

    public void setReceiveBufferSize(int size) throws SocketException {
        this.wrap.setReceiveBufferSize(size);
    }

    public int getReceiveBufferSize() throws SocketException {
        return this.wrap.getReceiveBufferSize();
    }

    public void setKeepAlive(boolean on) throws SocketException {
        this.wrap.setKeepAlive(on);
    }

    public boolean getKeepAlive() throws SocketException {
        return this.wrap.getKeepAlive();
    }

    public void setTrafficClass(int tc) throws SocketException {
        this.wrap.setTrafficClass(tc);
    }

    public int getTrafficClass() throws SocketException {
        return this.wrap.getTrafficClass();
    }

    public void setReuseAddress(boolean on) throws SocketException {
        this.wrap.setReuseAddress(on);
    }

    public boolean getReuseAddress() throws SocketException {
        return this.wrap.getReuseAddress();
    }

    public void shutdownInput() throws IOException {
        this.wrap.shutdownInput();
    }

    public void shutdownOutput() throws IOException {
        this.wrap.shutdownOutput();
    }

    public String toString() {
        return this.wrap.toString();
    }

    public boolean isConnected() {
        return this.wrap.isConnected();
    }

    public boolean isBound() {
        return this.wrap.isBound();
    }

    public boolean isClosed() {
        return this.wrap.isClosed();
    }

    public boolean isInputShutdown() {
        return this.wrap.isInputShutdown();
    }

    public boolean isOutputShutdown() {
        return this.wrap.isOutputShutdown();
    }

    public void setPerformancePreferences(int connectionTime, int latency, int bandwidth) {
        this.wrap.setPerformancePreferences(connectionTime, latency, bandwidth);
    }
}
