//
//  args.h
//  macos-ups-mqtt-connector-objc
//
//  Created by Chris Dzombak on 10/3/24.
//

#import <Foundation/Foundation.h>

extern NSString *const reportIntervalKey;
extern NSString *const nameKey;
extern NSString *const mqttTopicKey;
extern NSString *const mqttHostKey;
extern NSString *const mqttPortKey;
extern NSString *const mqttUsernameKey;
extern NSString *const mqttPasswordKey;

NSNumber *defaultMqttPort(void);
NSNumber *defaultReportIntervalS(void);
NSString *defaultNameTag(void);
