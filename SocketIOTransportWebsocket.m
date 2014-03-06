//
//  SocketIOTransportWebsocket.m
//  v0.5 ARC
//
//  based on
//  socketio-cocoa https://github.com/fpotter/socketio-cocoa
//  by Fred Potter <fpotter@pieceable.com>
//
//  using
//  https://github.com/square/SocketRocket
//  https://github.com/stig/json-framework/
//
//  reusing some parts of
//  /socket.io/socket.io.js
//
//  Created by Philipp Kyeck http://beta-interactive.de
//
//  Updated by
//    samlown   https://github.com/samlown
//    kayleg    https://github.com/kayleg
//    taiyangc  https://github.com/taiyangc
//

#import "SocketIOTransportWebsocket.h"
#import "SocketIO.h"

#define DEBUG_LOGS 0

#if DEBUG_LOGS
#define DEBUGLOG(...) NSLog(__VA_ARGS__)
#else
#define DEBUGLOG(...)
#endif

static NSString* kInsecureSocketURL = @"ws://%@/socket.io/1/websocket/%@";
static NSString* kSecureSocketURL = @"wss://%@/socket.io/1/websocket/%@";
static NSString* kInsecureSocketPortURL = @"ws://%@:%d/socket.io/1/websocket/%@";
static NSString* kSecureSocketPortURL = @"wss://%@:%d/socket.io/1/websocket/%@";

@implementation SocketIOTransportWebsocket

@synthesize delegate;

- (id) initWithDelegate:(id<SocketIOTransportDelegate>)delegate_
{
    self = [super init];
    if (self) {
        self.delegate = delegate_;
    }
    return self;
}

- (BOOL) isReady
{
    return _webSocket.readyState == SR_OPEN;
}

- (void) open
{
    NSString *urlStr;
    NSString *format;
    if (delegate.port) {
        format = delegate.useSecure ? kSecureSocketPortURL : kInsecureSocketPortURL;
        urlStr = [NSString stringWithFormat:format, delegate.host, delegate.port, delegate.sid];
    }
    else {
        format = delegate.useSecure ? kSecureSocketURL : kInsecureSocketURL;
        urlStr = [NSString stringWithFormat:format, delegate.host, delegate.sid];
    }
    NSURL *url = [NSURL URLWithString:urlStr];

    // prepare a request and specify the pinned certificates to SocketRocket
    NSMutableURLRequest * urlRequest = [NSMutableURLRequest requestWithURL:url];
    
    // if there are pinned certificates for server verification
    NSArray * pinnedCertificates = [delegate pinnedCertificates];
    if (nil != pinnedCertificates && [pinnedCertificates count] > 0)
    {
        urlRequest.SR_SSLPinnedCertificates = [delegate pinnedCertificates];
    }
    
    // if there are client credentials specified
    NSArray * clientCertificates = [delegate clientCertificates];
    id clientIdentity = [delegate clientIdentity];
    if (clientIdentity != nil && clientCertificates != nil && [clientCertificates count] > 0)
    {
        // create a new array to pass to socketrocket where the first element is the identity followed by the client certificates
        NSMutableArray * clientCertArray = [NSMutableArray arrayWithObject:clientIdentity];
        [clientCertArray addObjectsFromArray:clientCertificates];
        
        urlRequest.SR_SSLClientCertificates = clientCertArray;
    }
    
    _webSocket = nil;
    
    _webSocket = [[SRWebSocket alloc] initWithURLRequest:urlRequest];
    _webSocket.delegate = self;
    DEBUGLOG(@"Opening %@", url);
    [_webSocket open];
}

- (void) dealloc
{
    [_webSocket setDelegate:nil];
}

- (void) close
{
    [_webSocket close];
}

- (void) send:(NSString*)request
{
    [_webSocket send:request];
}



# pragma mark -
# pragma mark WebSocket Delegate Methods

- (void) webSocket:(SRWebSocket *)webSocket didReceiveMessage:(id)message
{
    if([delegate respondsToSelector:@selector(onData:)]) {
        [delegate onData:message];
    }
}

- (void) webSocketDidOpen:(SRWebSocket *)webSocket
{
    DEBUGLOG(@"Socket opened.");
}

- (void) webSocket:(SRWebSocket *)webSocket didFailWithError:(NSError *)error
{
    DEBUGLOG(@"Socket failed with error ... %@", [error localizedDescription]);
    // Assuming this resulted in a disconnect
    if([delegate respondsToSelector:@selector(onDisconnect:)]) {
        [delegate onDisconnect:error];
    }
}

- (void) webSocket:(SRWebSocket *)webSocket
  didCloseWithCode:(NSInteger)code
            reason:(NSString *)reason
          wasClean:(BOOL)wasClean
{
    DEBUGLOG(@"Socket closed. %@", reason);
    if([delegate respondsToSelector:@selector(onDisconnect:)]) {
        [delegate onDisconnect:[NSError errorWithDomain:SocketIOError
                                                   code:SocketIOWebSocketClosed
                                               userInfo:nil]];
    }
}

@end
