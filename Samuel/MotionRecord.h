//
//  MotionRecord.h
//  sdkdemo
//
//  
//

#import <Foundation/Foundation.h>


NS_ASSUME_NONNULL_BEGIN

@interface MotionRecord : NSObject
@property (nonatomic, assign) NSTimeInterval deltaSeconds;

@property (nonatomic, copy) NSString *deviceId;
@property (nonatomic, assign) NSTimeInterval timestamp;
@property (nonatomic, copy) NSString *source;
@property (nonatomic, assign) NSInteger datatype;

@property (nonatomic, assign) NSInteger x;
@property (nonatomic, assign) NSInteger y;
@property (nonatomic, assign) NSInteger speedThrow;

- (NSDictionary *)toJSON;
- (NSString *)toCSV;

@end

NS_ASSUME_NONNULL_END
