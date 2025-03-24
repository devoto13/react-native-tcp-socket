package com.asterinet.react.tcpsocket;

import org.bouncycastle.tls.TlsPSKIdentity;

import javax.net.ssl.SSLSocketFactory;
import java.net.InetAddress;
import java.net.Socket;

public class PskSSLSocketFactory extends SSLSocketFactory {
    private final int[] cipherSuites;
    private final TlsPSKIdentity pskIdentity;

    public PskSSLSocketFactory(int[] cipherSuites, TlsPSKIdentity pskIdentity) {
        this.cipherSuites = cipherSuites;
        this.pskIdentity = pskIdentity;
    }

    @Override
    public Socket createSocket() {
        Socket socket = new Socket();
        return new PskSocket(socket, pskIdentity, cipherSuites);
    }

    @Override
    public Socket createSocket(String host, int port) {
        throw new UnsupportedOperationException();
    }

    @Override
    public Socket createSocket(String host, int port, InetAddress localHost, int localPort) {
        throw new UnsupportedOperationException();
    }

    @Override
    public Socket createSocket(InetAddress host, int port) {
        throw new UnsupportedOperationException();
    }

    @Override
    public Socket createSocket(InetAddress address, int port, InetAddress localAddress, int localPort) {
        throw new UnsupportedOperationException();
    }

    @Override
    public Socket createSocket(Socket s, String host, int port, boolean autoClose) {
        throw new UnsupportedOperationException();
    }

    @Override
    public String[] getDefaultCipherSuites() {
        return new String[0];
    }

    @Override
    public String[] getSupportedCipherSuites() {
        return new String[0];
    }
}
