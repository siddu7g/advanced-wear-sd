//  DataReceiver.m
//  sdkdemo

// Purpose:
// Central BLE data router
//  Created by coolwear on 2022/9/21.
//
#import <UIKit/UIKit.h>
#import "DataReceiver.h"
#import "DeviceInfoModel.h"
#import "MotionRecord.h"
#import <BluetoothLibrary/BluetoothLibrary.h>
#import <CommonCrypto/CommonCrypto.h>
#import <BluetoothLibrary/CE_SendMotionCmd.h>

static const NSInteger DATA_TYPE_RAW250 = 250;

@interface DataReceiver ()

// Motion timing
@property (nonatomic, assign) NSTimeInterval motionSessionStartTs;
@property (nonatomic, assign) BOOL motionSessionActive;

// Motion batching
@property (nonatomic, strong) NSMutableArray<MotionRecord *> *motionBuffer;
@property (nonatomic, assign) NSTimeInterval lastFlushTs;


// Cloud / storage helpers
- (void)sendPayloadToCloud:(NSDictionary *)payload;

// Device identity
- (NSString *)hashedDeviceId;

// Sport control
- (void)stopSportMode;

@end



@implementation DataReceiver


+ (instancetype)shared{
    static DataReceiver *single = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        single = [[DataReceiver alloc] _init];
    });
    return single;
}


- (instancetype)_init {
    if (self = [super init]) {
        //BLE data + status
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(receiveBleData:) name:CEProductK6ReceiveDataNoticeKey object:nil];
        
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(bluetoothStatusChanged:) name:ProductStatusChangeNoticeKey object:nil];
        
        // App lifecycle (important for overnight capture)
                [[NSNotificationCenter defaultCenter] addObserver:self
                                                         selector:@selector(appWillResignActive)
                                                             name:UIApplicationWillResignActiveNotification
                                                           object:nil];

                [[NSNotificationCenter defaultCenter] addObserver:self
                                                         selector:@selector(appWillTerminate)
                                                             name:UIApplicationWillTerminateNotification
                                                           object:nil];
//        [self initSubject];
        self.motionBuffer = [NSMutableArray array];
        self.lastFlushTs = 0;
    }
    return self;
}

#pragma mark - Debug Helpers

- (void)logDataType:(NSInteger)type payload:(id)data label:(NSString *)label {
    NSLog(@"\n[%@]\nDataType=%ld\nClass=%@\nPayload=%@\n",
          label,
          (long)type,
          NSStringFromClass([data class]),
          data);
}

#pragma mark - Unified CSV helpers

- (NSString *)csvPathForType:(NSInteger)datatype {
    NSString *docs =
        NSSearchPathForDirectoriesInDomains(NSDocumentDirectory,
                                            NSUserDomainMask,
                                            YES).firstObject;

    switch (datatype) {
        case DATA_TYPE_MOTION_DATA:
            return [docs stringByAppendingPathComponent:@"motion_144.csv"];
        default:
            return nil;
    }
}

- (void)appendLine:(NSString *)line
        withHeader:(NSString *)header
        forType:(NSInteger)datatype {

    NSString *path = [self csvPathForType:datatype];
    if (!path) return;

    if (![[NSFileManager defaultManager] fileExistsAtPath:path]) {
        [header writeToFile:path
                 atomically:YES
                   encoding:NSUTF8StringEncoding
                      error:nil];
    }

    NSFileHandle *fh = [NSFileHandle fileHandleForWritingAtPath:path];
    if (!fh) return;

    [fh seekToEndOfFile];
    [fh writeData:[line dataUsingEncoding:NSUTF8StringEncoding]];
    [fh closeFile];
}

#pragma mark - Motion Forwarding (Stub)

- (void)sendPayloadToCloud:(NSDictionary *)payload {
    // will replace this with real networking
    NSLog(@"[CLOUD MOCK] %@", payload);
}

# pragma mark - Normalize Motion144
- (MotionRecord *)normalizeMotion144:(NSDictionary *)data {

    NSDictionary *motion = data[@"data"];
    if (![motion isKindOfClass:[NSDictionary class]]) {
        return nil;
    }

    MotionRecord *record = [[MotionRecord alloc] init];
    record.deviceId = [self hashedDeviceId];
    
    NSTimeInterval now = [[NSDate date] timeIntervalSince1970];
    record.timestamp = now;

    // Self-healing motion session start
    if (!self.motionSessionActive) {
        self.motionSessionStartTs = now;
        self.motionSessionActive = YES;
        record.deltaSeconds = 0;   // first packet anchor
    } else {
        record.deltaSeconds = now - self.motionSessionStartTs;
    }
    
    
    record.source = @"ios_sdk";
    record.datatype = 144;

    record.x = [motion[@"x"] integerValue];
    record.y = [motion[@"y"] integerValue];
    record.speedThrow = [motion[@"speed_throw"] integerValue];

    return record;
}

# pragma mark - BLE Receive Entry Point
- (void)receiveBleData:(NSNotification *)noti {

    NSDictionary *receiveData = noti.userInfo;
    if (!receiveData) return;

    K6_DataFuncType dataFuncType =
        (K6_DataFuncType)[receiveData[@"DataType"] integerValue];

    id data = receiveData[@"Data"];
    if (!data) return;

    switch (dataFuncType){

        case DATA_TYPE_MOTION_DATA: {
            if (![data isKindOfClass:[NSDictionary class]]) break;

            NSDictionary *motion = data[@"data"];
            if (![motion isKindOfClass:[NSDictionary class]]) break;

            NSLog(@"[MOTION144] x=%@ y=%@ speed_throw=%@",
                  motion[@"x"],
                  motion[@"y"],
                  motion[@"speed_throw"]);

            MotionRecord *record = [self normalizeMotion144:data];
            if (!record) break;

            [self.motionBuffer addObject:record];

            NSTimeInterval now = [[NSDate date] timeIntervalSince1970];
            if (self.lastFlushTs == 0) {
                self.lastFlushTs = now;
            }

            if (now - self.lastFlushTs >= 2.0) {   // batch window (2s)
                [self flushMotionBatch];
                self.lastFlushTs = now;
            }
             break;
        }

        case DATA_TYPE_RAW250: {
            if (![data isKindOfClass:[NSDictionary class]]) break;

            NSData *payload = data[@"UnknownBody"];
            if (![payload isKindOfClass:[NSData class]]) break;

            NSLog(@"[RAW250] len=%lu hex=%@",
                  (unsigned long)payload.length,
                  [self hexStringFromData:payload]);
            break;
        }

        case DATA_TYPE_REAL_SPORT:
        case DATA_TYPE_HISTORY_SPORT:
            // explicitly ignore sport stream
            break;

        default:
            break;
    }

    [NSNotificationCenter.defaultCenter postNotificationName:@"DataReceivceFinish" object:nil];
}

# pragma mark - Batch flush method
- (void)flushMotionBatch {
    if (self.motionBuffer.count == 0) return;
    
    NSTimeInterval now = [[NSDate date] timeIntervalSince1970];
    NSLog(@"[BATCH] Flushing %lu motion records (%.2fs window)",
         (unsigned long)self.motionBuffer.count,
         now - self.lastFlushTs);

    // ---- Cloud payload (array) ----
    NSMutableArray *jsonArray = [NSMutableArray arrayWithCapacity:self.motionBuffer.count];
    for (MotionRecord *r in self.motionBuffer) {
        [jsonArray addObject:[r toJSON]];
    }

    [self sendPayloadToCloud:@{
        @"records": jsonArray,
        @"count": @(jsonArray.count)
    }];

    // ---- CSV write (append all lines) ----
    NSMutableString *csvBlock = [NSMutableString string];
    for (MotionRecord *r in self.motionBuffer) {
        [csvBlock appendString:[r toCSV]];
    }

    NSString *header =
    @"device_id,timestamp,delta_seconds,source,datatype,x,y,speed_throw\n";

    [self appendLine:csvBlock
          withHeader:header
              forType:DATA_TYPE_MOTION_DATA];

    // Clear buffer
    [self.motionBuffer removeAllObjects];
}
#pragma mark - Sport Control

- (void)stopSportMode {
    YD_SyncSportCmd *stop = [[YD_SyncSportCmd alloc] init];
    stop.status = SPORT_STATUS_STOP;
    stop.type = 0;
    stop.time = 0;
    stop.distance = 0;

    [[CEProductK6 shareInstance] sendCmdToDevice:stop
                                       complete:^(NSError *error) {
        if (error) {
            NSLog(@"[SPORT] Stop failed: %@", error);
        } else {
            NSLog(@"[SPORT] Sport stopped — REAL_SPORT disabled");
        }
    }];
}

#pragma mark - App Lifecycle

- (void)appWillResignActive {
    NSLog(@"[APP] Will resign active — flushing motion buffer");
    [self flushMotionBatch];
}

- (void)appWillTerminate {
    NSLog(@"[APP] Will terminate — flushing motion buffer");
    [self flushMotionBatch];
}
#pragma mark - Bluetooth Status

- (void)bluetoothStatusChanged:(NSNotification *)noti {

    NSInteger status = [noti.object intValue];

    if (status == ProductStatus_completed) {
        NSLog(@"[BLE] Connected — starting sync");
        [self syncData];
    }

    if (status == ProductStatus_disconnected ||
        status == ProductStatus_powerOff) {
        [self flushMotionBatch]; // don't lose data
        self.motionSessionActive = NO;
        self.motionSessionStartTs = 0;
        self.lastFlushTs = 0;
    }
}

- (void)syncData {

    CE_SyncHybridCmd *cmd = [[CE_SyncHybridCmd alloc] init];

    CE_SensorCmd *sensorCmd = [[CE_SensorCmd alloc] init];
    sensorCmd.onoff = 1;

    CE_SyncPairOKCmd *pairOkCmd = [[CE_SyncPairOKCmd alloc] init];
    pairOkCmd.firstPairStatus = 0;

    cmd.infoItems = @[
        [self userInfoCmd],
        [self goalCmd],
        [[YD_SyncLanguageCmd alloc] initWithLanguage:0],
        [self timeCmd],
        sensorCmd,
        pairOkCmd
    ];

    NSLog(@"[SYNC] Sending hybrid sync");

    [[CEProductK6 shareInstance] sendCmdToDevice:cmd
                                       complete:^(NSError *error) {

        if (error) {
            NSLog(@"[SYNC] Error %@", error);
            return;
        }

        NSLog(@"[SYNC] Completed");

        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 2 * NSEC_PER_SEC),
                       dispatch_get_main_queue(), ^{

            CE_SendMotionCmd *motion = [[CE_SendMotionCmd alloc] init];
            motion.onoff = 1;
            [[CEProductK6 shareInstance] sendCmdToDevice:motion complete:nil];
            // Start motion session clock
            self.motionSessionStartTs = [[NSDate date] timeIntervalSince1970];
            self.motionSessionActive = YES;

            [self stopSportMode];
        });
    }];
}
#pragma mark - Utilities
- (NSString *)hexStringFromData:(NSData *)data {
    const uint8_t *bytes = data.bytes;
    NSMutableString *s = [NSMutableString string];
    for (NSUInteger i = 0; i < data.length; i++) {
        [s appendFormat:@"%02X ", bytes[i]];
    }
    return s;
}

#pragma mark - Command builders
- (CE_SyncUserInfoCmd *)userInfoCmd {
    CE_SyncUserInfoCmd *cmd = [[CE_SyncUserInfoCmd alloc] init];
    cmd.userId = 0;
    cmd.sex = 0;
    cmd.age = 18;
    cmd.height = 170;
    cmd.weight = 60;
    cmd.lrHand = 1;
    return cmd;
}

- (CE_SyncGoalCmd *)goalCmd {
    CE_SyncGoalCmd *cmd = [[CE_SyncGoalCmd alloc] init];
    cmd.sleep = 480;
    cmd.step = 2000;
    cmd.distance = 5000;
    cmd.calories = 1200;
    cmd.sportTime = 30;
    return cmd;
}

- (CE_SyncTimeCmd *)timeCmd {
    CE_SyncTimeCmd *timeCmd = [[CE_SyncTimeCmd alloc] init];
    timeCmd.absTime = [[NSDate date] timeIntervalSince1970];
    timeCmd.offsetTime = (uint32_t)[NSTimeZone defaultTimeZone].secondsFromGMT;
    timeCmd.format = 1;
    timeCmd.mdFormat = 1;
    return timeCmd;
}

- (NSString *)hashedDeviceId {
    // Option 1
    NSString *raw = @"R7-smart-ring";

    // Later @"R7-smart-ring" can be replaced with:
    // CEProductK6.shareInstance.pid or serial if available

    NSData *data = [raw dataUsingEncoding:NSUTF8StringEncoding];
    uint8_t digest[CC_SHA256_DIGEST_LENGTH];
    CC_SHA256(data.bytes, (CC_LONG)data.length, digest);

    NSMutableString *hash = [NSMutableString string];
    for (int i = 0; i < 6; i++) { // truncate
        [hash appendFormat:@"%02x", (unsigned int)digest[i]];
    }

    return [NSString stringWithFormat:@"R7-%@", hash];
}

@end
