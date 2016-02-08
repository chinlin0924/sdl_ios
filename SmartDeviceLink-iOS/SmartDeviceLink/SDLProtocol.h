//  SDLSmartDeviceLinkProtocol.h
//

#import "SDLAbstractProtocol.h"
@class SDLProtocolHeader;
@class SDLProtocolRecievedMessageRouter;


@interface SDLProtocol : SDLAbstractProtocol <SDLProtocolListener>

// Sending
- (void)sendStartSessionWithType:(SDLServiceType)serviceType;
- (void)sendStartSessionWithType:(SDLServiceType)serviceType encryption:(BOOL)encryption;
- (void)sendEndSessionWithType:(SDLServiceType)serviceType;
- (void)sendRPC:(SDLRPCMessage *)message;
- (void)sendRPCRequest:(SDLRPCRequest *)rpcRequest __deprecated_msg(("Use sendRPC: instead"));
- (void)sendRawData:(NSData *)data withServiceType:(SDLServiceType)serviceType;

// Recieving
- (void)handleBytesFromTransport:(NSData *)receivedData;

@end
