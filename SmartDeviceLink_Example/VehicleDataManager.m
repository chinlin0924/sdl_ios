//
//  VehicleDataManager.m
//  SmartDeviceLink-Example-ObjC
//
//  Created by Nicole on 4/23/18.
//  Copyright © 2018 smartdevicelink. All rights reserved.
//

#import "AlertManager.h"
#import "VehicleDataManager.h"
#import "AppConstants.h"
#import "SmartDeviceLink.h"

NS_ASSUME_NONNULL_BEGIN


@interface VehicleDataManager ()

@property (strong, nonatomic) SDLManager *sdlManager;
@property (copy, nonatomic, readwrite) NSString *vehicleOdometerData;
@property (copy, nonatomic, nullable) RefreshUIHandler refreshUIHandler;

@end

@implementation VehicleDataManager

#pragma mark - Lifecycle

- (instancetype)initWithManager:(SDLManager *)manager refreshUIHandler:(RefreshUIHandler)refreshUIHandler {
    self = [super init];
    if (!self) {
        return nil;
    }

    _sdlManager = manager;
    _refreshUIHandler = refreshUIHandler;
    _vehicleOdometerData = @"";

    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(vehicleDataNotification:) name:SDLDidReceiveVehicleDataNotification object:nil];
    [self sdlex_resetOdometer];

    return self;
}


#pragma mark - Subscribe Vehicle Data

/**
 *  Subscribes to odometer data. You must subscribe to a notification with name `SDLDidReceiveVehicleData` to get the new data when the odometer data changes.
 */
- (void)subscribeToVehicleOdometer {
    SDLLogD(@"Subscribing to odometer vehicle data");
    SDLSubscribeVehicleData *subscribeToVehicleOdometer = [[SDLSubscribeVehicleData alloc] init];
    subscribeToVehicleOdometer.odometer = @YES;
    [self.sdlManager sendRequest:subscribeToVehicleOdometer withResponseHandler:^(__kindof SDLRPCRequest * _Nullable request, __kindof SDLRPCResponse * _Nullable response, NSError * _Nullable error) {
        if (error || ![response isKindOfClass:SDLSubscribeVehicleDataResponse.class]) {
            SDLLogE(@"Error sending Get Vehicle Data RPC: %@", error);
        }

        SDLGetVehicleDataResponse* getVehicleDataResponse = (SDLGetVehicleDataResponse *)response;
        SDLResult resultCode = getVehicleDataResponse.resultCode;

        NSMutableString *message = [NSMutableString stringWithFormat:@"%@: ", VehicleDataOdometerName];
        if ([resultCode isEqualToEnum:SDLResultSuccess]) {
            SDLLogD(@"Subscribed to vehicle odometer data");
            [message appendString:@"Subscribed"];
        } else if ([resultCode isEqualToEnum:SDLResultDisallowed]) {
            SDLLogD(@"Access to vehicle data disallowed");
            [message appendString:@"Disallowed"];
        } else if ([resultCode isEqualToEnum:SDLResultUserDisallowed]) {
            SDLLogD(@"Vehicle user disabled access to vehicle data");
            [message appendString:@"Disabled"];
        } else if ([resultCode isEqualToEnum:SDLResultIgnored]) {
            SDLLogD(@"Already subscribed to odometer data");
            [message appendString:@"Subscribed"];
        } else if ([resultCode isEqualToEnum:SDLResultDataNotAvailable]) {
            SDLLogD(@"You have permission to access to vehicle data, but the vehicle you are connected to did not provide any data");
            [message appendString:@"Unknown"];
        } else {
            SDLLogE(@"Unknown reason for failure to get vehicle data: %@", error != nil ? error.localizedDescription : @"no error message");
            [message appendString:@"Unsubscribed"];
        }

        self.vehicleOdometerData = message;

        if (!self.refreshUIHandler) { return; }
        self.refreshUIHandler();
    }];
}

/**
 *  Unsubscribes to vehicle odometer data.
 */
- (void)unsubscribeToVehicleOdometer {
    SDLUnsubscribeVehicleData *unsubscribeToVehicleOdometer = [[SDLUnsubscribeVehicleData alloc] init];
    unsubscribeToVehicleOdometer.odometer = @YES;
    [self.sdlManager sendRequest:unsubscribeToVehicleOdometer withResponseHandler:^(__kindof SDLRPCRequest * _Nullable request, __kindof SDLRPCResponse * _Nullable response, NSError * _Nullable error) {
        if (!response.success.boolValue) { return; }
        [self sdlex_resetOdometer];
    }];
}

/**
 *  Notification containing the updated vehicle data.
 *
 *  @param notification A SDLOnVehicleData notification
 */
- (void)vehicleDataNotification:(SDLRPCNotificationNotification *)notification {
    if (![notification.notification isKindOfClass:SDLOnVehicleData.class]) {
        return;
    }

    SDLOnVehicleData *onVehicleData = (SDLOnVehicleData *)notification.notification;
    self.vehicleOdometerData = [NSString stringWithFormat:@"%@: %@ kph", VehicleDataOdometerName, onVehicleData.odometer];

    if (!self.refreshUIHandler) { return; }
    self.refreshUIHandler();
}

/**
 *  Resets the odometer data
 */
- (void)sdlex_resetOdometer {
    self.vehicleOdometerData = [NSString stringWithFormat:@"%@: Unsubscribed", VehicleDataOdometerName];
}

#pragma mark - Get Vehicle Data

/**
 *  Retreives the current vehicle speed
 *
 *  @param manager The SDL manager
 */
+ (void)getVehicleSpeedWithManager:(SDLManager *)manager {
    SDLLogD(@"Checking if app has permission to access vehicle data...");
    if (![manager.permissionManager isRPCAllowed:@"GetVehicleData"]) {
        [manager sendRequest:[AlertManager alertWithMessageAndCloseButton:@"This app does not have the required permissions to access vehicle data" textField2:nil]];
        return;
    }

    SDLLogD(@"App has permission to access vehicle data. Requesting vehicle speed data...");
    SDLGetVehicleData *getVehicleSpeed = [[SDLGetVehicleData alloc] init];
    getVehicleSpeed.speed = @YES;
    [manager sendRequest:getVehicleSpeed withResponseHandler:^(__kindof SDLRPCRequest * _Nullable request, __kindof SDLRPCResponse * _Nullable response, NSError * _Nullable error) {
        if (error || ![response isKindOfClass:SDLGetVehicleDataResponse.class]) {
            [manager sendRequest:[AlertManager alertWithMessageAndCloseButton:@"Something went wrong while getting vehicle speed" textField2:nil]];
            return;
        }

        SDLGetVehicleDataResponse* getVehicleDataResponse = (SDLGetVehicleDataResponse *)response;
        SDLResult resultCode = getVehicleDataResponse.resultCode;

        NSMutableString *alertMessage = [NSMutableString stringWithFormat:@"%@: ", VehicleDataSpeedName];
        if ([resultCode isEqualToEnum:SDLResultRejected]) {
            SDLLogD(@"The request for vehicle speed was rejected");
            [alertMessage appendString:@"Rejected"];
        } else if ([resultCode isEqualToEnum:SDLResultDisallowed]) {
            SDLLogD(@"This app does not have the required permissions to access vehicle data.");
            [alertMessage appendString:@"Disallowed"];
        } else if ([resultCode isEqualToEnum:SDLResultSuccess]) {
            NSNumber *speed = getVehicleDataResponse.speed;
            if (speed) {
                SDLLogD(@"Request for vehicle speed successful: %f", speed.floatValue);
                [alertMessage appendString:[NSString stringWithFormat:@"%f kph", speed.floatValue]];
            } else {
                SDLLogD(@"Request for vehicle speed successful but no data returned.");
                [alertMessage appendString:@"Unknown"];
            }
        }

        [manager sendRequest:[AlertManager alertWithMessageAndCloseButton:alertMessage textField2:nil]];
    }];
}

#pragma mark - Phone Calls

/**
 *  Checks if the head unit has the ability and/or permissions to make a phone call. If it does, the phone number is dialed.
 *
 *  @param manager      The SDL manager
 *  @param phoneNumber  A phone number to dial
 */
+ (void)checkPhoneCallCapabilityWithManager:(SDLManager *)manager phoneNumber:(NSString *)phoneNumber {
    SDLLogD(@"Checking phone call capability");
    [manager.systemCapabilityManager updateCapabilityType:SDLSystemCapabilityTypePhoneCall completionHandler:^(NSError * _Nullable error, SDLSystemCapabilityManager * _Nonnull systemCapabilityManager) {
        if (!systemCapabilityManager.phoneCapability) {
            [manager sendRequest:[AlertManager alertWithMessageAndCloseButton:@"The head unit does not support the phone call  capability" textField2:nil]];
            return;
        }

        if (systemCapabilityManager.phoneCapability.dialNumberEnabled.boolValue) {
            SDLLogD(@"Dialing phone number %@", phoneNumber);
            [self sdlex_dialPhoneNumber:phoneNumber manager:manager];
        } else {
            [manager sendRequest:[AlertManager alertWithMessageAndCloseButton:@"The dial number feature is unavailable for this head unit" textField2:nil]];
        }
    }];
}

/**
 *  Dials a phone number.
 *
 *  @param phoneNumber  A phone number to dial
 *  @param manager      The SDL manager
 */
+ (void)sdlex_dialPhoneNumber:(NSString *)phoneNumber manager:(SDLManager *)manager {
    SDLDialNumber *dialNumber = [[SDLDialNumber alloc] initWithNumber:phoneNumber];
    [manager sendRequest:dialNumber withResponseHandler:^(__kindof SDLRPCRequest * _Nullable request, __kindof SDLRPCResponse * _Nullable response, NSError * _Nullable error) {
        if (!response.resultCode) { return; }
        SDLLogD(@"Sent dial number request: %@", response.resultCode == SDLResultSuccess ? @"successfully" : @"unsuccessfully");
    }];
}

@end

NS_ASSUME_NONNULL_END
