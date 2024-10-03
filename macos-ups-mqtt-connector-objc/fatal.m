//
//  fatal.m
//  macos-ups-mqtt-connector-objc
//
//  Created by Chris Dzombak on 10/3/24.
//

#import <Foundation/Foundation.h>

void CDZFatal(NSString *format, ...) {
    va_list vl;
    va_start(vl, format);
    NSLog(@"FATAL: %@", [[NSString alloc] initWithFormat:format arguments:vl]);
    va_end(vl);
    kill([[NSProcessInfo processInfo] processIdentifier], SIGABRT);
}
