# TYScanQRCode

使用系统 API 实现 扫描二维码功能

1.仿微信样式
2.摄像头缩进
3.简单调用

接口如下
```
/// 初始化方法
/// @param view 根视图
/// @param scope 可扫描区域坐标（按正常理解的坐标传值,内部有进行转换）
/// @param handle 扫描结果回调（不用考虑循环引用问题）
- (instancetype)initWithView:(UIView *)view
                       scope:(CGRect)scope
                      handle:(ScanHandle)handle;

/// 开始扫描
- (void)startScan;

```
