//
//  MotionRecord.m
//  sdkdemo
//
//
//

#import "MotionRecord.h"

@implementation MotionRecord

- (NSDictionary *)toJSON {
    return @{
        @"device_id": self.deviceId,
        @"timestamp": @(self.timestamp),          // phone time
        @"delta_seconds": @(self.deltaSeconds),   // device-relative
        @"source": self.source,
        @"datatype": @(self.datatype),
        @"motion": @{
            @"x": @(self.x),
            @"y": @(self.y),
            @"speed_throw": @(self.speedThrow)
        }
    };
}

- (NSString *)toCSV {
    return [NSString stringWithFormat:
        @"%@,%.6f,%.6f,%@,%ld,%ld,%ld,%ld\n",
        self.deviceId,
        self.timestamp,
        self.deltaSeconds,
        self.source,
        (long)self.datatype,
        (long)self.x,
        (long)self.y,
        (long)self.speedThrow
    ];
}

@end
