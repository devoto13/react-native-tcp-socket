#import <React/RCTAssert.h>
#import <React/RCTConvert.h>
#import <React/RCTEventDispatcher.h>
#import <React/RCTLog.h>
#import <React/RCTEventEmitter.h>

#import <react_native_tcp_socket/react_native_tcp_socket-Swift.h>

// offset native ids by 5000
#define COUNTER_OFFSET 5000

@interface TcpSockets : RCTEventEmitter <SocketClientDelegate>

@end

@implementation TcpSockets {
    NSMutableDictionary<NSNumber *, TcpSocketClient *> *_clients;
    NSMutableDictionary<NSNumber *, NSDictionary *> *_pendingTLS;
    int _counter;
}

RCT_EXPORT_MODULE()

- (NSArray<NSString *> *)supportedEvents {
    return @[
        @"connect", @"data", @"close", @"error", @"written"
    ];
}

- (void)startObserving {
    // Does nothing
}

- (void)stopObserving {
    // Does nothing
}

- (void)dealloc {
    for (NSNumber *cId in _clients.allKeys) {
        [self destroyClient:cId];
    }
}

- (TcpSocketClient *)createSocket:(nonnull NSNumber *)cId {
    if (!cId) {
        RCTLogWarn(@"%@.createSocket called with nil id parameter.",
                   [self class]);
        return nil;
    }

    if (!_clients) {
        _clients = [NSMutableDictionary new];
    }

    if (_clients[cId]) {
        RCTLogWarn(@"%@.createSocket called twice with the same id.",
                   [self class]);
        return nil;
    }

    _clients[cId] = [[TcpSocketClient alloc] initWithId:cId andConfig:self];

    return _clients[cId];
}

RCT_EXPORT_METHOD(connect
                  : (nonnull NSNumber *)cId host
                  : (NSString *)host port
                  : (int)port withOptions
                  : (NSDictionary *)options) {
    TcpSocketClient *client = _clients[cId];
    if (!client) {
        client = [self createSocket:cId];
    }

    NSDictionary *tlsOptions = _pendingTLS[cId];

    NSError *error = nil;
    if (![client connectToHost:host port:port options:options tlsOptions:tlsOptions error:&error]) {
        [self onError:client withError:error];
        return;
    }
}

RCT_EXPORT_METHOD(write
                  : (nonnull NSNumber *)cId string
                  : (nonnull NSString *)base64String callback
                  : (nonnull NSNumber *)msgId) {
    TcpSocketClient *client = [self findClient:cId];
    if (!client)
        return;

    // iOS7+
    // TODO: use https://github.com/nicklockwood/Base64 for compatibility with
    // earlier iOS versions
    NSData *data = [[NSData alloc] initWithBase64EncodedString:base64String
                                                       options:0];
    [client writeData:data msgId:msgId];
}

RCT_EXPORT_METHOD(end : (nonnull NSNumber *)cId) { [self endClient:cId]; }

RCT_EXPORT_METHOD(destroy : (nonnull NSNumber *)cId) {
    [self destroyClient:cId];
}

RCT_EXPORT_METHOD(close : (nonnull NSNumber *)cId) { [self destroyClient:cId]; }

RCT_EXPORT_METHOD(startTLS
                  : (nonnull NSNumber *)cId tlsOptions
                  : (nonnull NSDictionary *)tlsOptions) {
    TcpSocketClient *client = _clients[cId];
    if (!client) {
        if (!_pendingTLS) {
            _pendingTLS = [NSMutableDictionary new];
        }
        _pendingTLS[cId] = tlsOptions;
    }
}

RCT_EXPORT_METHOD(setNoDelay
                  : (nonnull NSNumber *)cId noDelay
                  : (BOOL)noDelay) {
    TcpSocketClient *client = [self findClient:cId];
    if (!client)
        return;

    [client setNoDelay:noDelay];
}

RCT_EXPORT_METHOD(setKeepAlive
                  : (nonnull NSNumber *)cId enable
                  : (BOOL)enable initialDelay
                  : (int)initialDelay) {
    TcpSocketClient *client = [self findClient:cId];
    if (!client)
        return;

    [client setKeepAlive:enable initialDelay:initialDelay];
}

- (void)onWrittenData:(TcpSocketClient *)client msgId:(NSNumber *)msgId {
    [self sendEventWithName:@"written"
                       body:@{
                           @"id" : client.id,
                           @"msgId" : msgId,
                       }];
}

- (void)onConnect:(TcpSocketClient *)client {
    [self sendEventWithName:@"connect"
                       body:@{
                           @"id" : client.id,
                           @"connection" : @{
                               @"localAddress" : [client localIP],
                               @"localPort" : [NSNumber numberWithInt:[client localPort]],
                               @"remoteAddress" : [client remoteIP],
                               @"remotePort" : [NSNumber numberWithInt:[client remotePort]],
                               @"remoteFamily" : [client isIPv4] ? @"IPv4" : @"IPv6"
                           }
                       }];
}

- (void)onData:(NSNumber *)clientID data:(NSData *)data {
    NSString *base64String = [data base64EncodedStringWithOptions:0];
    [self sendEventWithName:@"data"
                       body:@{@"id" : clientID, @"data" : base64String}];
}

- (void)onClose:(NSNumber *)clientID withError:(NSError *)err {
    TcpSocketClient *client = [self findClient:clientID];
    if (!client) {
        RCTLogWarn(@"onClose: unrecognized client id %@", clientID);
    }

    if (err) {
        [self onError:client withError:err];
    }

    [self sendEventWithName:@"close"
                       body:@{
                           @"id" : clientID,
                           @"hadError" : err == nil ? @NO : @YES
                       }];

    [_clients removeObjectForKey:clientID];
}

- (void)onError:(TcpSocketClient *)client withError:(NSError *)err {
    NSString *msg = err.localizedDescription ?: err.localizedFailureReason;
    [self sendEventWithName:@"error" body:@{@"id" : client.id, @"error" : msg}];
}

- (TcpSocketClient *)findClient:(nonnull NSNumber *)cId {
    TcpSocketClient *client = _clients[cId];
    if (!client) {
        NSString *msg =
            [NSString stringWithFormat:@"no client found with id %@", cId];
        [self sendEventWithName:@"error" body:@{@"id" : cId, @"error" : msg}];

        return nil;
    }

    return client;
}

- (void)endClient:(nonnull NSNumber *)cId {
    TcpSocketClient *client = [self findClient:cId];
    if (!client)
        return;

    [client end];
}

- (void)destroyClient:(nonnull NSNumber *)cId {
    TcpSocketClient *client = [self findClient:cId];
    if (!client)
        return;

    [client destroy];
}

@end
