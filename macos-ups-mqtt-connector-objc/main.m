//
//  main.m
//  macos-ups-mqtt-connector-objc
//
//  Created by Chris Dzombak on 10/3/24.
//

#import <Foundation/Foundation.h>
#import "CDZUPSReporter.h"
#include "args.h"
#include "fatal.h"
#include "print.h"

volatile BOOL g_run = YES;
volatile BOOL g_fail = NO;

static void signal_handler(const int signum) {
    NSLog(@"caught signal %d", signum);
    if (g_run) {
        if (signum == SIGABRT) {
            g_fail = YES;
        }
        // attempt to exit gracefully:
        g_run = NO;
    } else {
        // duplicate signal; exit without any cleanup:
        exit(1);
    }
}

NSString *program_version = @"<dev>";

void printHelp(void) {
    CDZPrint(@"macos-ups-mqtt-connector version %@", program_version);
    CDZPrint(@"");
    CDZPrint(@"Usage: macos-ups-mqtt-connector OPTIONS");
    CDZPrint(@"");
    CDZPrint(@"Options:");
    CDZPrint(@"\t-mqtt-host: MQTT host to publish to. Required.");
    CDZPrint(@"\t-mqtt-pass: Password for MQTT auth.");
    CDZPrint(@"\t-mqtt-port: MQTT port to publish to (default: %@).", defaultMqttPort());
    CDZPrint(@"\t-mqtt-topic: Base MQTT topic. Messages will be pushed to <yourtopic>/system_status and <yourtopic>/source_status. Required.");
    CDZPrint(@"\t-mqtt-user: Username for MQTT auth.");
    CDZPrint(@"\t-name-tag: Value for the tag/device_name field in each message (default: system hostname).");
    CDZPrint(@"\t-report-interval-s: Interval at which to report to MQTT, in seconds (default %@).", defaultReportIntervalS());
    CDZPrint(@"");
    CDZPrint(@"macos-ups-mqtt-connector is licensed under the MIT license.");
    CDZPrint(@"https://www.github.com/cdzombak/macos-ups-mqtt-connector");
}

int main(int argc, const char * argv[]) {
    signal(SIGINT, signal_handler);
    signal(SIGQUIT, signal_handler);
    signal(SIGABRT, signal_handler);
    signal(SIGTERM, signal_handler);
    
    @autoreleasepool {
        NSArray *args = [[NSProcessInfo processInfo] arguments];
        if ([args containsObject:@"-h"] || [args containsObject:@"-help"] || [args containsObject:@"--help"]) {
            printHelp();
            exit(0);
        }
        if ([args containsObject:@"-v"] || [args containsObject:@"-version"]) {
            CDZPrint(@"macos-ups-mqtt-connector version %@", program_version);
            exit(0);
        }
        
        NSUserDefaults *standardDefaults = [NSUserDefaults standardUserDefaults];
        [standardDefaults registerDefaults:@{
            nameKey: defaultNameTag(),
            reportIntervalKey: defaultReportIntervalS(),
            mqttPortKey: defaultMqttPort(),
        }];
        NSTimeInterval reportInterval = [standardDefaults floatForKey:reportIntervalKey];
        NSString *mqttTopic = [standardDefaults stringForKey:mqttTopicKey];
        NSString *mqttHost = [standardDefaults stringForKey:mqttHostKey];
        NSInteger mqttPort = [standardDefaults integerForKey:mqttPortKey];
        
        if (reportInterval < 1.0) {
            CDZPrintErr(@"-report-interval must be at least 1 second");
            exit(2);
        }
        if (mqttPort < 1 || mqttPort > 65536) {
            CDZPrintErr(@"invalid -mqtt-port");
            exit(2);
        }
        if (mqttTopic == nil || [mqttTopic isEqual:@""]) {
            CDZPrintErr(@"-mqtt-topic is required");
            exit(2);
        }
        if (mqttHost == nil || [mqttHost isEqual:@""]) {
            CDZPrintErr(@"-mqtt-host is required");
            exit(2);
        }
        
        CDZUPSReporter *upsReporter = [[CDZUPSReporter alloc] init];
        NSTimer *reportTimer = [NSTimer scheduledTimerWithTimeInterval:reportInterval
                                                                target:upsReporter
                                                              selector:@selector(onTick:)
                                                              userInfo:nil
                                                              repeats:YES];

        NSRunLoop *runLoop = [NSRunLoop currentRunLoop];
        [runLoop addTimer:reportTimer forMode:NSDefaultRunLoopMode];
        while (g_run && [runLoop runMode:NSDefaultRunLoopMode beforeDate:[NSDate distantFuture]]);
        
        // cleanup/shutdown:
        [reportTimer invalidate];
        [upsReporter.mqttSession closeWithDisconnectHandler:nil];
    }
    
    if (g_fail) {
        return 1;
    }
    return 0;
}
