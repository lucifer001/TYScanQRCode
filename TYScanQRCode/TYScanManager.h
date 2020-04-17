//
//  TYScanManager.h
//  TYScanQRCode
//
//  Created by PEND_Q on 2020/4/16.
//  Copyright © 2020 轻舔指尖. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

typedef void(^ScanHandle)(BOOL isSuc, NSString *result);

@interface TYScanManager : NSObject

/// 初始化方法
/// @param view 根视图
/// @param scope 可扫描区域坐标（按正常理解的坐标传值,内部有进行转换）
/// @param handle 扫描结果回调（不用考虑循环引用问题）
- (instancetype)initWithView:(UIView *)view
                       scope:(CGRect)scope
                      handle:(ScanHandle)handle;

/// 开始扫描
- (void)startScan;

@end

NS_ASSUME_NONNULL_END
