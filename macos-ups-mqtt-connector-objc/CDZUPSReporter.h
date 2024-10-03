//
//  CDZUPSReporter.h
//  macos-ups-mqtt-connector-objc
//
//  Created by Chris Dzombak on 10/3/24.
//

#import <Foundation/Foundation.h>
#import <MQTTClient/MQTTClient.h>

@interface CDZUPSReporter : NSObject

@property(nonatomic) MQTTSession *mqttSession;

- (id)init;
- (void)onTick:(NSTimer *)aTimer;

@end
