//
//  TYScanManager.m
//  TYScanQRCode
//
//  Created by PEND_Q on 2020/4/16.
//  Copyright © 2020 轻舔指尖. All rights reserved.
//

#import "TYScanManager.h"
#import <AVFoundation/AVFoundation.h>

static NSString *const DEVICE_ERROR_MSG = @"当前设备为模拟器，不支持扫码功能";

@interface TYScanManager ()<AVCaptureMetadataOutputObjectsDelegate>
// 会话
@property (strong, nonatomic) AVCaptureSession *session;
// 输入设备
@property (strong, nonatomic) AVCaptureDeviceInput *deviceInput;
// 输出元数据
@property (strong, nonatomic) AVCaptureMetadataOutput *metadataOutput;
// 预览图层
@property (strong, nonatomic) AVCaptureVideoPreviewLayer *previewLayer;
// 会话图层
@property (strong, nonatomic) CALayer *drawLayer;
// 识别声音播放器
@property (strong, nonatomic) AVAudioPlayer *beepPlayer;

@property (assign, nonatomic) BOOL isScaning;
@property (weak, nonatomic) UIView *view;
@property (assign, nonatomic) CGRect scope;
@property (copy, nonatomic) ScanHandle scanHandle;

@end

@implementation TYScanManager

- (AVCaptureSession *)session
{
    if (!_session) {
        _session = [[AVCaptureSession alloc] init];
        if ([_session canSetSessionPreset:AVCaptureSessionPreset3840x2160]) {
            _session.sessionPreset = AVCaptureSessionPreset3840x2160;
        }
    }
    return _session;;
}

- (AVCaptureDeviceInput *)deviceInput
{
    if (!_deviceInput) {
        AVCaptureDevice *device = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
        _deviceInput = [[AVCaptureDeviceInput alloc] initWithDevice:device error:nil];
    }
    return _deviceInput;
}

- (AVCaptureMetadataOutput *)metadataOutput;
{
    if (!_metadataOutput) {
        _metadataOutput = [[AVCaptureMetadataOutput alloc] init];
    }
    return _metadataOutput;
}

- (AVCaptureVideoPreviewLayer *)previewLayer
{
    if (_previewLayer == nil) {
        _previewLayer = [[AVCaptureVideoPreviewLayer alloc] initWithSession:self.session];
        _previewLayer.videoGravity = AVLayerVideoGravityResizeAspectFill;
        _previewLayer.frame = UIScreen.mainScreen.bounds;
    }
    return _previewLayer;
}

- (CALayer *)drawLayer
{
    if (_drawLayer == nil) {
        _drawLayer = [[CALayer alloc] init];
        _drawLayer.frame = UIScreen.mainScreen.bounds;
    }
    return _drawLayer;
}

- (AVAudioPlayer *)beepPlayer
{
    if (_beepPlayer == nil) {
        NSString * wavPath = [[NSBundle mainBundle] pathForResource:@"Elastic_Done3" ofType:@"wav"];
        NSData* data = [[NSData alloc] initWithContentsOfFile:wavPath];
        _beepPlayer = [[AVAudioPlayer alloc] initWithData:data error:nil];
    }
    return _beepPlayer;
}

- (instancetype)initWithView:(UIView *)view
                       scope:(CGRect)scope
                      handle:(ScanHandle)handle
{
    if (self = [super init]) {
        self.view = view;
        if (CGRectEqualToRect(scope, CGRectZero)) {
            self.scope = UIScreen.mainScreen.bounds;
        } else {
            self.scope = scope;
        }
        self.scanHandle = handle;
    }
    return self;
}

- (void)startScan
{
    if (self.isScaning) {
        return;
    }
    
    if (TARGET_IPHONE_SIMULATOR) {
        self.scanHandle ? self.scanHandle(NO, DEVICE_ERROR_MSG) : nil;
        self.scanHandle = nil;
        return;
    }
    // 判断是否能够将输入添加到会话中
    if ([self.session canAddInput:self.deviceInput]) {
        [self.session addInput:self.deviceInput];
    }
    
    // 判断是否能够将输出添加到会话中
    if ([self.session canAddOutput:self.metadataOutput]) {
        
        [self.session addOutput:self.metadataOutput];
        
        // 设置输出能够解析的数据类型
        // 注意: 设置能够解析的数据类型, 一定要在输出对象添加到会话之后设置, 否则会报错
        self.metadataOutput.metadataObjectTypes = self.metadataOutput.availableMetadataObjectTypes;
        [self.metadataOutput setMetadataObjectsDelegate:self queue:dispatch_get_main_queue()];
        
        // self.metadataOutput.rectOfInterest = CGRectMake(0.0, 0.0, 1, 1);
        [self coverToMetadataOutputRectOfInterestForRect:self.scope];
    }
    
    // 添加预览图层
    [self.view.layer insertSublayer:self.previewLayer atIndex:0];
    
    // 添加绘制图层
    [self.previewLayer addSublayer:self.drawLayer];
    
    // 开始扫描
    [self.session startRunning];
    
    self.isScaning = YES;
}

- (void)stopScan
{
    if ([self.session isRunning]) {
        [self.session stopRunning];
        self.isScaning = NO;
    }
}


#pragma mark - AVCaptureMetadataOutputObjectsDelegate

- (void)captureOutput:(AVCaptureOutput *)output didOutputMetadataObjects:(NSArray<__kindof AVMetadataObject *> *)metadataObjects fromConnection:(AVCaptureConnection *)connection
{
    [self clearCorners];
    
    if (metadataObjects.count == 0 || metadataObjects == nil) {
        return;
    }
    
    if (metadataObjects != nil &&
        metadataObjects.count > 0) {
        
        AVMetadataObject *lastObject = [metadataObjects lastObject];
        if ([lastObject isKindOfClass:[AVMetadataMachineReadableCodeObject class]]) {
            AVMetadataMachineReadableCodeObject *codeObject = (AVMetadataMachineReadableCodeObject *)[self.previewLayer transformedMetadataObjectForMetadataObject:lastObject];
            // 绘制图形
            [self drawCircular:codeObject];
            // 摄像头缩放 (此处代码执行很快，可能看不出来缩放效果，可以注释掉 [self stopScan] 代码查看)
            [self scaleCorners:codeObject];
        }
        
        if ([lastObject.type isEqualToString:AVMetadataObjectTypeQRCode]) {
            
            [self.beepPlayer play];
            [self stopScan];
            
            // 扫描结果
            NSString *resultStr = [metadataObjects.lastObject stringValue];
            [self resultHandleWithStr:resultStr];
        }
    }
}

- (void)resultHandleWithStr:(NSString *)str
{
    self.scanHandle ? self.scanHandle(YES, str) : nil;
    self.scanHandle = nil;
}

#pragma draw action
// 绘制方形
- (void)drawCorners:(AVMetadataMachineReadableCodeObject *)codeObject
{
    if (codeObject.corners.count == 0) {
        return;
    }
    
    CAShapeLayer *layer = [[CAShapeLayer alloc] init];
    layer.lineWidth = 4;
    layer.strokeColor = [UIColor redColor].CGColor;
    layer.fillColor = [UIColor clearColor].CGColor;
    
    UIBezierPath *path = [[UIBezierPath alloc] init];
    CGPoint point = CGPointZero;
    NSInteger index = 0;
    
    CGPointMakeWithDictionaryRepresentation((CFDictionaryRef)codeObject.corners[index++], &point);
    [path moveToPoint:point];
    
    while (index < codeObject.corners.count) {
        CGPointMakeWithDictionaryRepresentation((CFDictionaryRef)codeObject.corners[index++], &point);
        [path addLineToPoint:point];
    }
    [path closePath];
    
    layer.path = path.CGPath;
    [self.drawLayer addSublayer:layer];
}

// 绘制圆形（仿微信样式）
- (void)drawCircular:(AVMetadataMachineReadableCodeObject *)codeObject
{
    if (codeObject.corners.count == 0) {
        return;
    }
    CGPoint point = CGPointZero;
    CGPoint point2 = CGPointZero;
    CGPointMakeWithDictionaryRepresentation((CFDictionaryRef)codeObject.corners[0], &point);
    CGPointMakeWithDictionaryRepresentation((CFDictionaryRef)codeObject.corners[2], &point2);
    CGPoint center = CGPointMake((point.x + point2.x) / 2, (point.y + point2.y) / 2);
    
    UIColor *fillColor = [UIColor colorWithRed:41.0/255.0 green:220.0/255.0 blue:113.0/255.0 alpha:1];
    UIColor *sColor = [UIColor whiteColor];
    
    CAShapeLayer *layer = [[CAShapeLayer alloc] init];
    layer.lineWidth = 4;
    layer.strokeColor = sColor.CGColor;
    layer.fillColor = fillColor.CGColor;
    
    UIBezierPath *path = [UIBezierPath bezierPathWithOvalInRect:CGRectMake(center.x, center.y, 30, 30)];
    layer.path = path.CGPath;
    [self.drawLayer addSublayer:layer];
}

// 清除绘制图层
- (void)clearCorners
{
    if (self.drawLayer.sublayers == nil ||
        self.drawLayer.sublayers.count == 0) {
        return;
    }
    
    for (int i = 0; i < self.drawLayer.sublayers.count; i++) {
        CALayer *subLayer = self.drawLayer.sublayers[i];
        [subLayer removeFromSuperlayer];
    }
}

#pragma mark - zoom action
// 摄像头缩放
- (void)scaleCorners:(AVMetadataMachineReadableCodeObject *)codeObject
{
    if (codeObject.corners.count == 0) {
        return;
    }
    
    CGPoint point = CGPointZero;
    CGPoint point2 = CGPointZero;
    CGPointMakeWithDictionaryRepresentation((CFDictionaryRef)codeObject.corners[0], &point);
    CGPointMakeWithDictionaryRepresentation((CFDictionaryRef)codeObject.corners[2], &point2);
    CGFloat scale = UIScreen.mainScreen.bounds.size.width / (point2.x - point.x);

    if (scale > 1) {
        if ([self.deviceInput.device lockForConfiguration:nil]) {
            if (scale > 2.5) {
                scale = 2.5;
            }
            [self.deviceInput.device rampToVideoZoomFactor:scale withRate:10];
            [self.deviceInput.device unlockForConfiguration];
        }
    }
}

#pragma mark - rect convert action

// 将扫描区域坐标转换为 rectOfInterest
// 具体原理参考 https://www.jianshu.com/p/8bb3d8cb224e
- (void)coverToMetadataOutputRectOfInterestForRect:(CGRect)cropRect
{
    CGSize size = self.previewLayer.bounds.size;
    CGFloat p1 = size.height/size.width;
    CGFloat p2 = 0.0;

    if ([self.session.sessionPreset isEqualToString:AVCaptureSessionPreset1920x1080]) {
        p2 = 1920./1080.;
    }
    else if ([self.session.sessionPreset isEqualToString:AVCaptureSessionPreset352x288]) {
        p2 = 352./288.;
    }
    else if ([self.session.sessionPreset isEqualToString:AVCaptureSessionPreset1280x720]) {
        p2 = 1280./720.;
    }
    else if ([self.session.sessionPreset isEqualToString:AVCaptureSessionPresetiFrame960x540]) {
        p2 = 960./540.;
    }
    else if ([self.session.sessionPreset isEqualToString:AVCaptureSessionPresetiFrame1280x720]) {
        p2 = 1280./720.;
    }
    else if ([self.session.sessionPreset isEqualToString:AVCaptureSessionPresetHigh]) {
        p2 = 1920./1080.;
    }
    else if ([self.session.sessionPreset isEqualToString:AVCaptureSessionPresetMedium]) {
        p2 = 480./360.;
    }
    else if ([self.session.sessionPreset isEqualToString:AVCaptureSessionPresetLow]) {
        p2 = 192./144.;
    }
    else if ([self.session.sessionPreset isEqualToString:AVCaptureSessionPresetPhoto]) { // 暂时未查到具体分辨率，但是可以推导出分辨率的比例为4/3
         p2 = 4./3.;
    }
    else if ([self.session.sessionPreset isEqualToString:AVCaptureSessionPresetInputPriority]) {
        p2 = 1920./1080.;
    }
    else if (@available(iOS 9.0, *)) {
        if ([self.session.sessionPreset isEqualToString:AVCaptureSessionPreset3840x2160]) {
            p2 = 3840./2160.;
        }
    } else {
        
    }
    if ([self.previewLayer.videoGravity isEqualToString:AVLayerVideoGravityResize]) {
        self.metadataOutput.rectOfInterest = CGRectMake((cropRect.origin.y)/size.height,(size.width-(cropRect.size.width+cropRect.origin.x))/size.width, cropRect.size.height/size.height,cropRect.size.width/size.width);
    } else if ([self.previewLayer.videoGravity isEqualToString:AVLayerVideoGravityResizeAspectFill]) {
        if (p1 < p2) {
            CGFloat fixHeight = size.width * p2;
            CGFloat fixPadding = (fixHeight - size.height)/2;
            self.metadataOutput.rectOfInterest = CGRectMake((cropRect.origin.y + fixPadding)/fixHeight,
                                                        (size.width-(cropRect.size.width+cropRect.origin.x))/size.width,
                                                        cropRect.size.height/fixHeight,
                                                        cropRect.size.width/size.width);
        } else {
            CGFloat fixWidth = size.height * (1/p2);
            CGFloat fixPadding = (fixWidth - size.width)/2;
            self.metadataOutput.rectOfInterest = CGRectMake(cropRect.origin.y/size.height,
                                                        (size.width-(cropRect.size.width+cropRect.origin.x)+fixPadding)/fixWidth,
                                                        cropRect.size.height/size.height,
                                                        cropRect.size.width/fixWidth);
        }
    } else if ([_previewLayer.videoGravity isEqualToString:AVLayerVideoGravityResizeAspect]) {
        if (p1 > p2) {
            CGFloat fixHeight = size.width * p2;
            CGFloat fixPadding = (fixHeight - size.height)/2;
            self.metadataOutput.rectOfInterest = CGRectMake((cropRect.origin.y + fixPadding)/fixHeight,
                                                        (size.width-(cropRect.size.width+cropRect.origin.x))/size.width,
                                                        cropRect.size.height/fixHeight,
                                                        cropRect.size.width/size.width);
        } else {
            CGFloat fixWidth = size.height * (1/p2);
            CGFloat fixPadding = (fixWidth - size.width)/2;
            self.metadataOutput.rectOfInterest = CGRectMake(cropRect.origin.y/size.height,
                                                        (size.width-(cropRect.size.width+cropRect.origin.x)+fixPadding)/fixWidth,
                                                        cropRect.size.height/size.height,
                                                        cropRect.size.width/fixWidth);
        }
    }
}

@end
