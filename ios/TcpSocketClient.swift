import Foundation
import NIOSSL
import NIO

@objc public protocol SocketClientDelegate: NSObjectProtocol {
  func onConnect(_ client: TcpSocketClient)
  func onData(_ clientID: NSNumber, data: Data)
  func onClose(_ client: TcpSocketClient, withError error: Error?)
  func onError(_ client: TcpSocketClient, withError error: Error?)
  func onWrittenData(_ client: TcpSocketClient, msgId: NSNumber)
}

final class ErrorHandler: ChannelInboundHandler, Sendable {
  typealias InboundIn = ByteBuffer

  private weak var client: TcpSocketClient?
  private weak var delegate: SocketClientDelegate?

  init(client: TcpSocketClient, delegate: SocketClientDelegate?) {
    self.client = client
    self.delegate = delegate
  }

  func errorCaught(context: ChannelHandlerContext, error: Error) {
    // See https://forums.swift.org/t/niossl-spurious-uncleanshutdown-error/53031/2
    if let sslError = error as? NIOSSLError, sslError == .uncleanShutdown {
        return
    }

    print("Socker error:", error)
    delegate?.onError(client!, withError: error)
    context.close(promise: nil)
  }

  func channelRead(context: ChannelHandlerContext, data: NIOAny) {
    var byteBuffer = self.unwrapInboundIn(data)
    while byteBuffer.readableBytes > 0 {
      if let chunk = byteBuffer.readBytes(length: min(100, byteBuffer.readableBytes)) {
        delegate?.onData(client!.id, data: Data(chunk))
      }
    }
  }
}

@objc public class TcpSocketClient: NSObject {
  private static var group = MultiThreadedEventLoopGroup(numberOfThreads: 1)

  @objc public var id: NSNumber

  private weak var clientDelegate: SocketClientDelegate?
  private var channel: Channel?

  @objc public var localIP: String? {
    guard let address = channel?.localAddress else { return nil }
    return address.ipAddress
  }

  @objc public var localPort: Int {
    return channel?.localAddress?.port ?? 0
  }

  @objc public var remoteIP: String? {
    guard let address = channel?.remoteAddress else { return nil }
    return address.ipAddress
  }

  @objc public var remotePort: Int {
    return channel?.remoteAddress?.port ?? 0
  }

  @objc public var isIPv4: Bool {
    guard let family = channel?.remoteAddress?.protocol else { return false }
    return family == .inet
  }

  @objc public init(withId clientID: NSNumber, andConfig delegate: SocketClientDelegate) {
    id = clientID
    clientDelegate = delegate
    super.init()
  }

  @objc public func connect(toHost host: String, port: Int, options: [String: Any], tlsOptions: [String: Any]?) throws {
    guard channel == nil else {
      throw badInvocationError("this client's socket is already connected")
    }

    var configuration = TLSConfiguration.makeClientConfiguration()
    configuration.cipherSuiteValues = (tlsOptions?["pskCipherSuites"] as? [NSNumber] ?? []).map { NIOTLSCipher(rawValue: $0.uint16Value) }
    configuration.pskClientProvider = { context in
      return PSKClientIdentityResponse(
        key: NIOSSLSecureBytes(Data(base64Encoded: tlsOptions?["pskKey"] as? String ?? "")!),
        identity: tlsOptions?["pskIdentity"] as? String ?? ""
      )
    }
    configuration.certificateVerification = .none
    let sslContext = try NIOSSLContext(configuration: configuration)

    let client = ClientBootstrap(group: TcpSocketClient.group)
      .channelInitializer { channel in
        let handler = try! NIOSSLClientHandler(context: sslContext, serverHostname: nil)
        return channel.pipeline.addHandlers(handler, ErrorHandler(client: self, delegate: self.clientDelegate))
      }

    channel = try client.connect(to: SocketAddress(ipAddress: host, port: port)).wait()

    clientDelegate?.onConnect(self)
  }

  @objc public func writeData(_ data: Data, msgId: NSNumber) {
    var buffer = ByteBufferAllocator().buffer(capacity: data.count)
    buffer.writeBytes(data)

    let promise = TcpSocketClient.group.next().makePromise(of: Void.self)
    channel?.writeAndFlush(buffer, promise: promise)
    promise.futureResult.whenComplete() {
      switch ($0) {
      case .failure(let error):
        self.clientDelegate?.onError(self, withError: error)
        break
      case .success:
        self.clientDelegate?.onWrittenData(self, msgId: msgId)
      }
    }
  }

  @objc public func end() {
    do {
      try channel?.close(mode: .output).wait()
    } catch let error {
      clientDelegate?.onError(self, withError: error)
    }
  }

  @objc public func destroy() {
    do {
      try channel?.close(mode: .all).wait()
    } catch let error {
      clientDelegate?.onError(self, withError: error)
    }
  }

  @objc public func setNoDelay(_ noDelay: Bool) {
    do {
      try channel?.setOption(ChannelOptions.socketOption(.tcp_nodelay), value: noDelay ? 1 : 0).wait()
    } catch let error {
      clientDelegate?.onError(self, withError: error)
    }
  }

  @objc public func setKeepAlive(_ enable: Bool, initialDelay: Int) {
    do {
      try channel?.setOption(ChannelOptions.socketOption(.so_keepalive), value: enable ? 1 : 0).wait()
    } catch let error {
      clientDelegate?.onError(self, withError: error)
    }
  }

  private func badInvocationError(_ message: String) -> NSError {
    return NSError(domain: "RCTTCPErrorDomain", code: 1, userInfo: [
      NSLocalizedDescriptionKey: message
    ])
  }
}
