//
//  KKRunloopMonitor.h
//  MainRunloopMonitor
//
//  Created by jianqin_ruan on 2021/3/6.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface KKRunloopMonitor : NSObject

+ (instancetype)sharedInstance;

/// 超过多少毫秒为一次卡顿 400毫秒
@property (nonatomic, assign) int limitMillisecond;

/// 发生一次有效的卡顿回调函数
@property (nonatomic, copy) void (^callbackWhenStandStill)(void);

/**
 开始监听卡顿
 */
- (void)startMonitor;

/**
 结束监听卡顿
 */
- (void)endMonitor;

@end

NS_ASSUME_NONNULL_END
