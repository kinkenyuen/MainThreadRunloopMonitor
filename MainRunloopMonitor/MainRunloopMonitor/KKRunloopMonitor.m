//
//  KKRunloopMonitor.m
//  MainRunloopMonitor
//
//  Created by jianqin_ruan on 2021/3/6.
//

#import "KKRunloopMonitor.h"

@interface KKRunloopMonitor () {
    CFRunLoopObserverRef _observer;
    CFRunLoopActivity _activity;
}

@end

@implementation KKRunloopMonitor

// 最小阈值等待时间
static const NSInteger MXRMonitorRunloopMinOneStandstillMillisecond = 20;

// 默认阈值等待时间
static const NSInteger MXRMonitorRunloopOneStandstillMillisecond = 400;

// 信号量
static dispatch_semaphore_t semaphore;

+ (instancetype)sharedInstance {
    static KKRunloopMonitor *_instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _instance = [[self alloc] init];
        _instance.limitMillisecond = MXRMonitorRunloopOneStandstillMillisecond;
    });
    return _instance;
}

- (void)setLimitMillisecond:(int)limitMillisecond
{
    _limitMillisecond = limitMillisecond >= MXRMonitorRunloopMinOneStandstillMillisecond ? limitMillisecond : MXRMonitorRunloopMinOneStandstillMillisecond;
}

- (void)startMonitor
{
    [self registerObserver];
}

static void runLoopObserverCallBack(CFRunLoopObserverRef observer, CFRunLoopActivity activity, void *info)
{
    if (activity == kCFRunLoopBeforeSources) {
        NSLog(@"kk | runloop即将处理source");
    }
    KKRunloopMonitor *instance = [KKRunloopMonitor sharedInstance];
    // 记录runloop状态
    instance->_activity = activity;
    // 发送信号
    //假设runloop处理某次事件时，状态为kCFRunLoopBeforeSources，然后这时发生了卡顿
    //没有及时发生信号让子线程继续执行，则会导致子线程等待超时
    dispatch_semaphore_signal(semaphore);
}

// 注册一个Observer来监测Loop的状态,回调函数是runLoopObserverCallBack
- (void)registerObserver
{
    // 设置Runloop observer的运行环境
    CFRunLoopObserverContext context = {0, (__bridge void *)self, NULL, NULL};
    // 创建Runloop observer对象
    _observer = CFRunLoopObserverCreate(kCFAllocatorDefault,
                                        kCFRunLoopAllActivities,
                                        YES,
                                        0,
                                        &runLoopObserverCallBack,
                                        &context);
    // 将新建的observer加入到当前主线程的runloop
    CFRunLoopAddObserver(CFRunLoopGetMain(), _observer, kCFRunLoopCommonModes);
    // 创建信号
    semaphore = dispatch_semaphore_create(0);
    
    //创建一个子线程循环监测主线程runloop状态
    __weak KKRunloopMonitor *wSelf = self;
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        __strong KKRunloopMonitor *strSelf = wSelf;
        while (YES) {
            //dispatch_semaphore_wait作用
            //当信号量为0的时候，让线程等待，直到信号量大于1或等待时间超过预设阈值
            //如果发生超时，则函数返回非0，否则返回0
            long semaphoreWait = dispatch_semaphore_wait(semaphore, dispatch_time(DISPATCH_TIME_NOW, strSelf->_limitMillisecond * NSEC_PER_MSEC));
            if (semaphoreWait != 0) {
                if (!strSelf->_observer) {
                    return;
                }
                //BeforeSources 和 AfterWaiting 这两个状态能够检测到是否卡顿
                if (strSelf->_activity == kCFRunLoopBeforeSources || strSelf->_activity == kCFRunLoopAfterWaiting) {
                    if (strSelf->_callbackWhenStandStill) {
                        strSelf->_callbackWhenStandStill();
                    }
                }
            }
        }
    });
}

- (void)endMonitor {
    if(!_observer) return;
    CFRunLoopRemoveObserver(CFRunLoopGetMain(), _observer, kCFRunLoopCommonModes);
    CFRelease(_observer);
    _observer = NULL;
}

@end
