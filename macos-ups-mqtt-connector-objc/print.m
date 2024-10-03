//
//  print.m
//  macos-ups-mqtt-connector-objc
//
//  Created by Chris Dzombak on 10/3/24.
//

#import <Foundation/Foundation.h>

// print to stdout
// https://stackoverflow.com/questions/2216266/printing-an-nsstring
void CDZPrint(NSString *format, ...) {
    va_list args;
    va_start(args, format);
    NSString *string = [[NSString alloc] initWithFormat:format arguments:args];
    va_end(args);
    fprintf(stdout, "%s\n", [string UTF8String]);
}

// print to stderr
// https://stackoverflow.com/questions/2216266/printing-an-nsstring
void CDZPrintErr(NSString *format, ...) {
    va_list args;
    va_start(args, format);
    NSString *string = [[NSString alloc] initWithFormat:format arguments:args];
    va_end(args);
    fprintf(stderr, "%s\n", [string UTF8String]);
}
