//
//  ViewController.m
//  TYScanQRCode
//
//  Created by PEND_Q on 2020/4/16.
//  Copyright © 2020 轻舔指尖. All rights reserved.
//

#import "ViewController.h"
#import "TYScanManager.h"

@interface ViewController ()

@property (strong, nonatomic) TYScanManager *scanManager;

@end

@implementation ViewController

- (TYScanManager *)scanManager
{
    if (!_scanManager) {
        _scanManager = [[TYScanManager alloc] initWithView:self.view
                                                     scope:UIScreen.mainScreen.bounds
                                                    handle:^(BOOL isSuc, NSString * _Nonnull result) {
            if (isSuc) {
                [self showMessage:result];
            }
        }];
    }
    return _scanManager;
}

- (void)showMessage:(NSString *)msg
{
    NSLog(@"二维码内容：%@", msg);
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.view.backgroundColor = UIColor.whiteColor;
    [self.scanManager startScan];
}

- (void)touchesEnded:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event
{
    [self.scanManager startScan];
}

@end
