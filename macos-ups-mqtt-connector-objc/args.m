//
//  args.m
//  macos-ups-mqtt-connector-objc
//
//  Created by Chris Dzombak on 10/3/24.
//

#import <Foundation/Foundation.h>

NSString *const reportIntervalKey = @"report-interval-s";
NSString *const nameKey = @"name-tag";
NSString *const mqttTopicKey = @"mqtt-topic";
NSString *const mqttHostKey = @"mqtt-host";
NSString *const mqttPortKey = @"mqtt-port";
NSString *const mqttUsernameKey = @"mqtt-user";
NSString *const mqttPasswordKey = @"mqtt-pass";

NSNumber *defaultMqttPort(void) {
    return @1883;
}

NSNumber *defaultReportIntervalS(void) {
    return @15.0;
}

NSString *defaultNameTag(void) {
    return [[NSProcessInfo processInfo] hostName];
}
