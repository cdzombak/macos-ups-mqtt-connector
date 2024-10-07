//
//  CDZUPSReporter.m
//  macos-ups-mqtt-connector-objc
//
//  Created by Chris Dzombak on 10/3/24.
//

#import <IOKit/ps/IOPowerSources.h>
#import "args.h"
#import "fatal.h"
#import "CDZUPSReporter.h"

@implementation CDZUPSReporter

- (id)init {
    self = [super init];
    if (!self) {
        return nil;
    }
    
    NSUserDefaults *standardDefaults = [NSUserDefaults standardUserDefaults];
    NSString *mqttHost = [standardDefaults stringForKey:mqttHostKey];
    NSInteger mqttPort = [standardDefaults integerForKey:mqttPortKey];
    NSString *mqttUser = [standardDefaults stringForKey:mqttUsernameKey];
    NSString *mqttPass = [standardDefaults stringForKey:mqttPasswordKey];
    
    MQTTCFSocketTransport *transport = [[MQTTCFSocketTransport alloc] init];
    transport.host = mqttHost;
    transport.port = (UInt32)mqttPort;
    self.mqttSession = [[MQTTSession alloc] init];
    if (mqttUser != nil) {
        self.mqttSession.userName = mqttUser;
    }
    if (mqttPass != nil) {
        self.mqttSession.password = mqttPass;
    }
    self.mqttSession.transport = transport;
    [self.mqttSession connectWithConnectHandler:^(NSError *error) {
        if (error != nil) {
            CDZFatal(@"MQTT error (%@:%d): %@", mqttHost, mqttPort, [error description]);
        }
    }];
    
    return self;
}

- (void)onTick:(NSTimer *)aTimer {
    NSString *nowFmt = [NSISO8601DateFormatter stringFromDate:[NSDate date]
                                                     timeZone:[NSTimeZone timeZoneWithAbbreviation:@"UTC"]
                                                formatOptions:NSISO8601DateFormatWithInternetDateTime];
    NSUserDefaults *standardDefaults = [NSUserDefaults standardUserDefaults];
    NSString *nameTag = [standardDefaults stringForKey:nameKey];
    NSMutableDictionary *systemStatusMessage = [@{
        @"at": nowFmt,
        @"tags": [@{
            @"device_name": nameTag,
        } mutableCopy],
        @"fields": [NSMutableDictionary new],
    } mutableCopy];
    
    NSTimeInterval timeRemaining = IOPSGetTimeRemainingEstimate();
    if (timeRemaining != kIOPSTimeRemainingUnknown && timeRemaining != kIOPSTimeRemainingUnlimited) {
        systemStatusMessage[@"fields"][@"time_remaining_sec"] = @(timeRemaining);
    }
    
    IOPSLowBatteryWarningLevel bWarningLevel = IOPSGetBatteryWarningLevel();
    switch (bWarningLevel) {
        case kIOPSLowBatteryWarningNone:
            break;
        case kIOPSLowBatteryWarningEarly:
        case kIOPSLowBatteryWarningFinal:
            systemStatusMessage[@"fields"][@"battery_warning_level"] = @(bWarningLevel);
            break;
        default:
            NSLog(@"warning: IOPSGetBatteryWarningLevel returned unknown battery warning level %d", bWarningLevel);
            break;
    }
    
    CFTypeRef psInfo = IOPSCopyPowerSourcesInfo();
    if (!psInfo) {
        NSLog(@"WARN: IOPSCopyPowerSourcesInfo returned NULL; skipping this tick");
        return;
    }
    CFArrayRef powerSources = IOPSCopyPowerSourcesList(psInfo);
    if (!powerSources) {
        NSLog(@"WARN: IOPSCopyPowerSourcesList returned NULL; skipping this tick");
        if (psInfo) {
            CFRelease(psInfo);
            psInfo = NULL;
        }
        return;
    }
    CFIndex i, c = CFArrayGetCount(powerSources);
    
    systemStatusMessage[@"fields"][@"power_source_count"] = @(c);
    systemStatusMessage[@"fields"][@"current_power_source"] = (__bridge NSString *)IOPSGetProvidingPowerSourceType(psInfo);
    // currentPowerSource is one of: CFSTR(kIOPMACPowerKey), CFSTR(kIOPMBatteryPowerKey), CFSTR(kIOPMUPSPowerKey)
    
    NSError *error;
    NSData *systemStatusData = [NSJSONSerialization dataWithJSONObject:systemStatusMessage options:0 error:&error];
    if (!systemStatusData){
        CDZFatal(@"failed to serialize systemStatusMessage to JSON: %@", error);
    }
    NSString *systemStatusTopic = [NSString stringWithFormat:@"%@/system_status", [standardDefaults stringForKey:mqttTopicKey]];
    [self.mqttSession publishData:systemStatusData onTopic:systemStatusTopic retain:NO qos:MQTTQosLevelAtMostOnce publishHandler:^(NSError *error) {
        if (error != nil) {
            NSLog(@"error publishing to MQTT topic %@: %@", systemStatusTopic, [error description]);
        }
    }];
    
    for (i=0; i<c; i++) {
        NSDictionary *ssi = (__bridge NSDictionary *)(IOPSGetPowerSourceDescription(psInfo, CFArrayGetValueAtIndex(powerSources, i)));
        if (!ssi) {
            NSLog(@"WARN: IOPSGetPowerSourceDescription returned NULL; skipping this source");
            continue;
        }
        [self reportSourceStatus:ssi
                     atTimestamp:nowFmt];
    }
    
    if (powerSources) {
        CFRelease(powerSources);
        powerSources = NULL;
    }
    if (psInfo) {
        CFRelease(psInfo);
        psInfo = NULL;
    }
}

- (void)reportSourceStatus:(NSDictionary *)info atTimestamp:(NSString *)nowFmt {
    NSUserDefaults *standardDefaults = [NSUserDefaults standardUserDefaults];
    NSString *nameTag = [standardDefaults stringForKey:nameKey];
    NSMutableDictionary *sourceStatusMessage = [@{
        @"at": nowFmt,
        @"tags": [@{
            @"device_name": nameTag,
        } mutableCopy],
        @"fields": [NSMutableDictionary new],
    } mutableCopy];
    
    // note: to the extent possible, tag and field names should match
    // https://github.com/cdzombak/nut_influx_connector?tab=readme-ov-file#nut_influx_connector
    
    sourceStatusMessage[@"tags"][@"ups_name"] = [NSString stringWithFormat:@"%@ %@", [info[@kIOPSNameKey] stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet], [info[@"Accessory Identifier"] stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet]];
    if (info[@kIOPSProductIDKey]) {
        sourceStatusMessage[@"tags"][@"product_id"] = info[@kIOPSProductIDKey];
    }
    if (info[@kIOPSVendorIDKey]) {
        sourceStatusMessage[@"tags"][@"vendor_id"] = info[@kIOPSVendorIDKey];
    }
    if (info[@kIOPSTypeKey]) {
        sourceStatusMessage[@"tags"][@"source_type"] = info[@kIOPSTypeKey];
        // Valid types are kIOPSUPSType or kIOPSInternalBatteryType.
    }
    
    if (info[@kIOPSPowerSourceStateKey]) {
        // Type CFString; value is <code>@link kIOPSACPowerValue@/link</code>, <code>@link kIOPSBatteryPowerValue@/link</code>, or <code>@link kIOPSOffLineValue@/link</code>.
        sourceStatusMessage[@"fields"][@"power_source"] = info[@kIOPSPowerSourceStateKey];
        if ([info[@kIOPSPowerSourceStateKey] isEqual:@(kIOPSACPowerValue)]) {
            sourceStatusMessage[@"fields"][@"power_source_is_ac"] = @(YES);
        } else {
            sourceStatusMessage[@"fields"][@"power_source_is_ac"] = @(NO);
        }
        if ([info[@kIOPSPowerSourceStateKey] isEqual:@(kIOPSBatteryPowerValue)]) {
            sourceStatusMessage[@"fields"][@"power_source_is_batt"] = @(YES);
        } else {
            sourceStatusMessage[@"fields"][@"power_source_is_batt"] = @(NO);
        }
        if ([info[@kIOPSPowerSourceStateKey] isEqual:@(kIOPSOffLineValue)]) {
            sourceStatusMessage[@"fields"][@"online"] = @(NO);
        } else {
            sourceStatusMessage[@"fields"][@"online"] = @(YES);
        }
    }
    if (info[@(kIOPSIsChargingKey)]) {
        sourceStatusMessage[@"fields"][@"charging"] = @([info[@(kIOPSIsChargingKey)] boolValue]);
    }
    if (info[@(kIOPSIsPresentKey)]) {
        sourceStatusMessage[@"fields"][@"present"] = @([info[@(kIOPSIsPresentKey)] boolValue]);
    }
    if (info[@(kIOPSVoltageKey)]) {
        // seems to be exactly 120000 mV on my UPS, so I guess this is output voltage
        sourceStatusMessage[@"fields"][@"output_voltage"] = @([info[@(kIOPSVoltageKey)] doubleValue]/1000.0);
    }
    if (info[@(kIOPSCurrentKey)]) {
        sourceStatusMessage[@"fields"][@"output_current"] = @([info[@(kIOPSCurrentKey)] doubleValue]/1000.0);
    }
    if (sourceStatusMessage[@"fields"][@"output_voltage"] && sourceStatusMessage[@"fields"][@"output_current"]) {
        double outW = [sourceStatusMessage[@"fields"][@"output_voltage"] doubleValue] * [sourceStatusMessage[@"fields"][@"output_current"] doubleValue];
        sourceStatusMessage[@"fields"][@"power"] = @(outW);
        sourceStatusMessage[@"fields"][@"watts"] = @(outW);
    }
    if (info[@(kIOPSCurrentCapacityKey)]) {
        sourceStatusMessage[@"fields"][@"battery_charge_percent"] = @([info[@(kIOPSCurrentCapacityKey)] doubleValue]);
    }
//    if (info[@(kIOPSMaxCapacityKey)]) {
//        NSLog(@"max capacity: %.1f %%", [info[@(kIOPSMaxCapacityKey)] doubleValue]);
//    }
    if (info[@(kIOPSInternalFailureKey)]) {
        sourceStatusMessage[@"fields"][@"internal_failure"] = @([info[@(kIOPSInternalFailureKey)] boolValue]);
    }
    if (info[@(kIOPSTemperatureKey)]) {
        sourceStatusMessage[@"fields"][@"battery_temperature_c"] = @([info[@(kIOPSTemperatureKey)] doubleValue]);
        sourceStatusMessage[@"fields"][@"battery_temperature_f"] = @([info[@(kIOPSTemperatureKey)] doubleValue] * 1.8 + 32);
    }
    if (info[@kIOPSTimeToEmptyKey] && [info[@kIOPSTimeToEmptyKey] intValue] != -1) {
        // Type CFNumber kCFNumberIntType (signed integer), units are minutes
        // A value of -1 indicates "Still Calculating the Time", otherwise estimated minutes left on the battery.
        sourceStatusMessage[@"fields"][@"battery_runtime_s"] = @([info[@kIOPSTimeToEmptyKey] doubleValue] * 60.0);
    }
    if (info[@kIOPSTimeToFullChargeKey] && [info[@kIOPSTimeToFullChargeKey] intValue] != -1) {
        // Type CFNumber kCFNumberIntType (signed integer), units are minutes
        // A value of -1 indicates "Still Calculating the Time", otherwise estimated minutes left on the battery.
        sourceStatusMessage[@"fields"][@"battery_charge_time_s"] = @([info[@kIOPSTimeToFullChargeKey] doubleValue] * 60.0);
    }
    
    NSError *error;
    NSData *sourceStatusData = [NSJSONSerialization dataWithJSONObject:sourceStatusMessage options:0 error:&error];
    if (!sourceStatusData){
        CDZFatal(@"failed to serialize sourceStatusMessage to JSON: %@", error);
    }
    NSString *sourceStatusTopic = [NSString stringWithFormat:@"%@/source_status", [standardDefaults stringForKey:mqttTopicKey]];
    [self.mqttSession publishData:sourceStatusData onTopic:sourceStatusTopic retain:NO qos:MQTTQosLevelAtMostOnce publishHandler:^(NSError *error) {
        if (error != nil) {
            NSLog(@"error publishing to MQTT topic %@: %@", sourceStatusTopic, [error description]);
        }
    }];
}

@end
