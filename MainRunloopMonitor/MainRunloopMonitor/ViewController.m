//
//  ViewController.m
//  MainRunloopMonitor
//
//  Created by jianqin_ruan on 2021/3/6.
//

#import "ViewController.h"

@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
}

- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    //模拟一个耗时操作，方法本身会触发runloop source0让runloop进入kCFRunLoopBeforeSources（即将处理source）状态
    sleep(1);
}


@end
