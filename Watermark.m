#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>

// ===== إعدادات قابلة للتعديل =====
static NSString *const kWatermarkText = @"@eur9fex";
static const CGFloat kStartX = 16;
static const CGFloat kStartY = 50;
// ==================================

@interface WatermarkOverlay : UIView
@property (nonatomic, strong) UILabel *nameLabel;
@property (nonatomic, strong) UILabel *fpsLabel;
@property (nonatomic, strong) CADisplayLink *displayLink;
@property (nonatomic, assign) NSInteger frameCount;
@property (nonatomic, assign) CFTimeInterval lastTimestamp;
@end

@implementation WatermarkOverlay

- (instancetype)init {
    self = [super initWithFrame:CGRectMake(kStartX, kStartY, 100, 46)];
    if (self) {
        self.backgroundColor = [UIColor colorWithWhite:0 alpha:0.35];
        self.layer.cornerRadius = 8;
        self.layer.zPosition = CGFLOAT_MAX;

        // اسم المطوّر — أبيض متوهج
        _nameLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 2, 100, 20)];
        _nameLabel.text = kWatermarkText;
        _nameLabel.font = [UIFont boldSystemFontOfSize:13];
        _nameLabel.textAlignment = NSTextAlignmentCenter;
        _nameLabel.textColor = [UIColor whiteColor];
        _nameLabel.layer.shadowColor = [UIColor whiteColor].CGColor;
        _nameLabel.layer.shadowRadius = 6.0;
        _nameLabel.layer.shadowOpacity = 1.0;
        _nameLabel.layer.shadowOffset = CGSizeZero;
        _nameLabel.layer.masksToBounds = NO;
        [self addSubview:_nameLabel];

        // عداد FPS
        _fpsLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 24, 100, 20)];
        _fpsLabel.text = @"FPS: --";
        _fpsLabel.font = [UIFont boldSystemFontOfSize:12];
        _fpsLabel.textAlignment = NSTextAlignmentCenter;
        _fpsLabel.textColor = [UIColor colorWithRed:0.4 green:1.0 blue:0.6 alpha:1.0];
        _fpsLabel.layer.shadowColor = [UIColor colorWithRed:0.4 green:1.0 blue:0.6 alpha:1.0].CGColor;
        _fpsLabel.layer.shadowRadius = 4.0;
        _fpsLabel.layer.shadowOpacity = 0.9;
        _fpsLabel.layer.shadowOffset = CGSizeZero;
        _fpsLabel.layer.masksToBounds = NO;
        [self addSubview:_fpsLabel];

        // سحب حر بالإصبع
        UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc]
            initWithTarget:self action:@selector(handlePan:)];
        [self addGestureRecognizer:pan];
        self.userInteractionEnabled = YES;

        // عداد FPS حقيقي عبر CADisplayLink (يقرأ معدل رسم الشاشة الفعلي)
        _displayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(tick:)];
        [_displayLink addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
        _lastTimestamp = 0;
        _frameCount = 0;
    }
    return self;
}

- (void)tick:(CADisplayLink *)link {
    if (_lastTimestamp == 0) {
        _lastTimestamp = link.timestamp;
        return;
    }
    _frameCount++;
    CFTimeInterval elapsed = link.timestamp - _lastTimestamp;
    if (elapsed >= 1.0) {
        NSInteger fps = (NSInteger)round(_frameCount / elapsed);
        self.fpsLabel.text = [NSString stringWithFormat:@"FPS: %ld", (long)fps];
        _frameCount = 0;
        _lastTimestamp = link.timestamp;
    }
}

- (void)handlePan:(UIPanGestureRecognizer *)gr {
    CGPoint translation = [gr translationInView:self.superview];
    self.center = CGPointMake(self.center.x + translation.x, self.center.y + translation.y);
    [gr setTranslation:CGPointZero inView:self.superview];
}

@end

static WatermarkOverlay *overlay;

static UIWindow *currentKeyWindow(void) {
    if (@available(iOS 13.0, *)) {
        for (UIScene *scene in [UIApplication sharedApplication].connectedScenes) {
            if ([scene isKindOfClass:[UIWindowScene class]] &&
                scene.activationState == UISceneActivationStateForegroundActive) {
                for (UIWindow *w in ((UIWindowScene *)scene).windows) {
                    if (w.isKeyWindow) return w;
                }
            }
        }
    }
    return [UIApplication sharedApplication].keyWindow;
}

static void ensureOverlay(void) {
    UIWindow *window = currentKeyWindow();
    if (!window) return;
    if (overlay.superview == window) return; // موجودة أصلاً وما تحتاج تكرار

    if (!overlay) {
        overlay = [[WatermarkOverlay alloc] init];
    }
    [window addSubview:overlay];
    [window bringSubviewToFront:overlay];
}

__attribute__((constructor))
static void watermark_entry(void) {
    dispatch_time_t delay = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC));
    dispatch_after(delay, dispatch_get_main_queue(), ^{
        ensureOverlay();
        [NSTimer scheduledTimerWithTimeInterval:3.0 repeats:YES block:^(NSTimer * _Nonnull timer) {
            ensureOverlay();
        }];
    });
}

