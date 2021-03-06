# MainThreadRunloopMonitor
主线程Runloop状态检测的一个demo

# 原理
监控卡顿就是找到主线程都做了哪些事。线程的消息事件是依赖于 `NSRunLoop` 的。我们通过监听 `NSRunLoop` 的状态，能够发现调用方法是否执行事件过长，从而判断是否会出现卡顿。

如果`runloop`处理事件耗时过长，则`runloop`的状态可能一直处于`kCFRunLoopBeforeSources `,还有一种情况是runloop从休眠状态中被唤醒来处理事件，被唤醒后一直长时间处于该状态也可视为卡顿，该状态对应为`kCFRunLoopAfterWaiting`，因此，可以监控这两个状态:

* `kCFRunLoopBeforeSources `
* `kCFRunLoopAfterWaiting`

如果其中一个状态的更新耗时超过预设的阈值（例如，`runloop`状态切换到`kCFRunLoopBeforeSources `,但超过400ms仍然未更新到下一状态），则视为一次卡顿。

# 检测方式

* runloop observer
* 子线程
* 信号量

具体步骤:

1. 向主线程`runloop`添加一自定义`runloop observer`监听`runloop activity`
2. 在回调函数内部记录本次`runloop activity`，并发送信号量，目的是让子线程继续执行
3. 开启一子线程，配置一个循环，通过信号量来监测上述两个状态是否超时

````objc
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
                  	//检测到耗时操作，做一个回调通知外部
                    if (strSelf->_callbackWhenStandStill) {
                        strSelf->_callbackWhenStandStill();
                    }
                }
            }
        }
    });
}
````



