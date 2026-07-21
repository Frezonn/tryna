#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#import <objc/runtime.h>
#import <dlfcn.h>

// ============================================================
// ===== 1. إعدادات المود =====
// ============================================================
static NSString *const kModVersion = @"Frezon Mod v0.1";
static const CGFloat kStartX = 20;
static const CGFloat kStartY = 100;

// ============================================================
// ===== 2. واجهة المود منيو (أسود وأبيض) =====
// ============================================================
@interface FrezonModOverlay : UIView
@property (nonatomic, strong) UIButton *menuButton;
@property (nonatomic, strong) UIView *menuView;
@property (nonatomic, strong) NSMutableDictionary *fieldsUI;
@property (nonatomic, assign) BOOL isMenuVisible;
@property (nonatomic, strong) UIScrollView *scrollView;
@property (nonatomic, strong) UIView *contentView;
@property (nonatomic, strong) UILabel *versionLabel;
@end

@implementation FrezonModOverlay

- (instancetype)init {
    self = [super initWithFrame:CGRectMake(kStartX, kStartY, 60, 60)];
    if (self) {
        self.backgroundColor = [UIColor clearColor];
        self.layer.zPosition = CGFLOAT_MAX;
        self.userInteractionEnabled = YES;
        self.fieldsUI = [NSMutableDictionary dictionary];
        
        // ===== زر المنيو الدائري =====
        [self setupMenuButton];
        
        // ===== نافذة المنيو =====
        [self setupMenuView];
        
        // ===== سحب الحر =====
        UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc]
            initWithTarget:self action:@selector(handlePan:)];
        [self addGestureRecognizer:pan];
        
        [self performSelector:@selector(initializeMod) withObject:nil afterDelay:2.0];
    }
    return self;
}

- (void)setupMenuButton {
    _menuButton = [UIButton buttonWithType:UIButtonTypeCustom];
    _menuButton.frame = CGRectMake(0, 0, 60, 60);
    _menuButton.layer.cornerRadius = 30;
    _menuButton.clipsToBounds = YES;
    _menuButton.layer.shadowColor = [UIColor blackColor].CGColor;
    _menuButton.layer.shadowOffset = CGSizeMake(0, 4);
    _menuButton.layer.shadowRadius = 8;
    _menuButton.layer.shadowOpacity = 0.5;
    _menuButton.userInteractionEnabled = YES;
    
    // تصميم الزر (أسود وأبيض)
    _menuButton.backgroundColor = [UIColor colorWithWhite:0.1 alpha:1.0];
    _menuButton.layer.borderColor = [UIColor whiteColor].CGColor;
    _menuButton.layer.borderWidth = 1.5;
    
    // حرف "F" كشعار
    _menuButton.titleLabel.font = [UIFont fontWithName:@"HelveticaNeue-Bold" size:24];
    [_menuButton setTitle:@"F" forState:UIControlStateNormal];
    [_menuButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    
    [_menuButton addTarget:self action:@selector(toggleMenu) forControlEvents:UIControlEventTouchUpInside];
    [self addSubview:_menuButton];
}

- (void)setupMenuView {
    // ===== نافذة المنيو الرئيسية =====
    _menuView = [[UIView alloc] initWithFrame:CGRectMake(-20, -320, 280, 300)];
    _menuView.backgroundColor = [UIColor colorWithWhite:0.05 alpha:0.97];
    _menuView.layer.cornerRadius = 16;
    _menuView.layer.borderColor = [UIColor colorWithWhite:0.3 alpha:1].CGColor;
    _menuView.layer.borderWidth = 1;
    _menuView.hidden = YES;
    _menuView.clipsToBounds = YES;
    _menuView.userInteractionEnabled = YES;
    [self addSubview:_menuView];
    
    // ===== الهيدر =====
    UIView *headerView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 280, 50)];
    headerView.backgroundColor = [UIColor colorWithWhite:0.1 alpha:1];
    headerView.userInteractionEnabled = NO;
    [_menuView addSubview:headerView];
    
    // خط سفلي للهيدر
    UIView *headerLine = [[UIView alloc] initWithFrame:CGRectMake(0, 49, 280, 1)];
    headerLine.backgroundColor = [UIColor colorWithWhite:0.3 alpha:1];
    [headerView addSubview:headerLine];
    
    // عنوان "Frezon Mod"
    UILabel *titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(10, 5, 200, 30)];
    titleLabel.text = @"Frezon Mod";
    titleLabel.font = [UIFont fontWithName:@"HelveticaNeue-Bold" size:18];
    titleLabel.textColor = [UIColor whiteColor];
    titleLabel.textAlignment = NSTextAlignmentLeft;
    [headerView addSubview:titleLabel];
    
    // إصدار v0.1
    _versionLabel = [[UILabel alloc] initWithFrame:CGRectMake(10, 28, 200, 16)];
    _versionLabel.text = @"v0.1";
    _versionLabel.font = [UIFont fontWithName:@"HelveticaNeue-Light" size:11];
    _versionLabel.textColor = [UIColor colorWithWhite:0.5 alpha:1];
    _versionLabel.textAlignment = NSTextAlignmentLeft;
    [headerView addSubview:_versionLabel];
    
    // زر إغلاق (X)
    UIButton *closeBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    closeBtn.frame = CGRectMake(240, 10, 30, 30);
    closeBtn.backgroundColor = [UIColor colorWithWhite:0.2 alpha:0.8];
    closeBtn.layer.cornerRadius = 15;
    closeBtn.clipsToBounds = YES;
    [closeBtn setTitle:@"✕" forState:UIControlStateNormal];
    [closeBtn setTitleColor:[UIColor colorWithWhite:0.7 alpha:1] forState:UIControlStateNormal];
    closeBtn.titleLabel.font = [UIFont boldSystemFontOfSize:14];
    closeBtn.userInteractionEnabled = YES;
    [closeBtn addTarget:self action:@selector(toggleMenu) forControlEvents:UIControlEventTouchUpInside];
    [headerView addSubview:closeBtn];
    
    // ===== ScrollView للمحتوى =====
    _scrollView = [[UIScrollView alloc] initWithFrame:CGRectMake(5, 55, 270, 205)];
    _scrollView.backgroundColor = [UIColor clearColor];
    _scrollView.showsVerticalScrollIndicator = YES;
    _scrollView.alwaysBounceVertical = YES;
    _scrollView.userInteractionEnabled = YES;
    _scrollView.indicatorStyle = UIScrollViewIndicatorStyleWhite;
    [_menuView addSubview:_scrollView];
    
    _contentView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 260, 10)];
    _contentView.backgroundColor = [UIColor clearColor];
    _contentView.userInteractionEnabled = YES;
    [_scrollView addSubview:_contentView];
}

// ============================================================
// ===== 3. إضافة حقول المود =====
// ============================================================
- (void)initializeMod {
    [self addFieldToMenu:@"Jump Height" value:@"1.0" type:@"float"];
    [self addFieldToMenu:@"Speed" value:@"10.0" type:@"float"];
    [self addFieldToMenu:@"Gravity" value:@"-20.0" type:@"float"];
    [self addFieldToMenu:@"Max Health" value:@"100" type:@"int"];
    [self addFieldToMenu:@"Unlimited Coins" value:@"ON" type:@"toggle"];
    [self addFieldToMenu:@"Unlimited Keys" value:@"ON" type:@"toggle"];
    
    [self updateContentSize];
}

- (void)addFieldToMenu:(NSString *)label value:(NSString *)defaultValue type:(NSString *)type {
    CGFloat yPos = self.contentView.subviews.count * 46;
    
    // ===== خلفية العنصر =====
    UIView *itemView = [[UIView alloc] initWithFrame:CGRectMake(5, yPos, 250, 40)];
    itemView.backgroundColor = [UIColor colorWithWhite:0.12 alpha:0.9];
    itemView.layer.cornerRadius = 8;
    itemView.layer.borderColor = [UIColor colorWithWhite:0.2 alpha:1].CGColor;
    itemView.layer.borderWidth = 0.5;
    itemView.userInteractionEnabled = YES;
    [self.contentView addSubview:itemView];
    
    // ===== اسم الحقل =====
    UILabel *nameLabel = [[UILabel alloc] initWithFrame:CGRectMake(10, 5, 100, 30)];
    nameLabel.text = label;
    nameLabel.font = [UIFont fontWithName:@"HelveticaNeue" size:13];
    nameLabel.textColor = [UIColor colorWithWhite:0.8 alpha:1];
    nameLabel.userInteractionEnabled = NO;
    [itemView addSubview:nameLabel];
    
    if ([type isEqualToString:@"toggle"]) {
        // ===== مفتاح تبديل (Toggle) =====
        UISwitch *toggle = [[UISwitch alloc] initWithFrame:CGRectMake(190, 5, 50, 30)];
        toggle.onTintColor = [UIColor whiteColor];
        toggle.tintColor = [UIColor colorWithWhite:0.3 alpha:1];
        toggle.thumbTintColor = [UIColor colorWithWhite:0.1 alpha:1];
        toggle.on = [defaultValue isEqualToString:@"ON"];
        toggle.tag = self.fieldsUI.count;
        [toggle addTarget:self action:@selector(toggleChanged:) forControlEvents:UIControlEventValueChanged];
        [itemView addSubview:toggle];
    } else {
        // ===== حقل الإدخال =====
        UITextField *inputField = [[UITextField alloc] initWithFrame:CGRectMake(120, 5, 80, 30)];
        inputField.text = defaultValue;
        inputField.textColor = [UIColor whiteColor];
        inputField.backgroundColor = [UIColor colorWithWhite:0.2 alpha:0.8];
        inputField.layer.cornerRadius = 5;
        inputField.layer.borderColor = [UIColor colorWithWhite:0.3 alpha:1].CGColor;
        inputField.layer.borderWidth = 0.5;
        inputField.font = [UIFont fontWithName:@"HelveticaNeue" size:13];
        inputField.keyboardType = UIKeyboardTypeDecimalPad;
        inputField.userInteractionEnabled = YES;
        inputField.tag = 100;
        inputField.textAlignment = NSTextAlignmentCenter;
        [itemView addSubview:inputField];
        
        // ===== زر التطبيق =====
        UIButton *applyBtn = [UIButton buttonWithType:UIButtonTypeSystem];
        applyBtn.frame = CGRectMake(205, 5, 40, 30);
        applyBtn.backgroundColor = [UIColor colorWithWhite:0.2 alpha:0.8];
        applyBtn.layer.cornerRadius = 5;
        applyBtn.clipsToBounds = YES;
        [applyBtn setTitle:@"Set" forState:UIControlStateNormal];
        [applyBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        applyBtn.titleLabel.font = [UIFont fontWithName:@"HelveticaNeue-Bold" size:11];
        applyBtn.userInteractionEnabled = YES;
        applyBtn.tag = 101;
        [applyBtn addTarget:self action:@selector(applyFieldValue:) forControlEvents:UIControlEventTouchUpInside];
        [itemView addSubview:applyBtn];
    }
    
    // تخزين البيانات
    NSDictionary *fieldData = @{
        @"label": label,
        @"type": type,
        @"itemView": itemView
    };
    self.fieldsUI[label] = fieldData;
}

// ===== معالجة التبديل (Toggle) =====
- (void)toggleChanged:(UISwitch *)sender {
    // البحث عن العنصر الأب
    UIView *itemView = sender.superview;
    if (!itemView) return;
    
    // البحث عن الـ label
    UILabel *label = nil;
    for (UIView *subview in itemView.subviews) {
        if ([subview isKindOfClass:[UILabel class]]) {
            label = (UILabel *)subview;
            break;
        }
    }
    
    if (!label) return;
    
    NSString *status = sender.isOn ? @"ON" : @"OFF";
    NSLog(@"✅ Toggle: %@ = %@", label.text, status);
}

// ===== معالجة زر التطبيق =====
- (void)applyFieldValue:(UIButton *)sender {
    UIView *itemView = sender.superview;
    if (!itemView) return;
    
    UITextField *inputField = nil;
    for (UIView *subview in itemView.subviews) {
        if ([subview isKindOfClass:[UITextField class]]) {
            inputField = (UITextField *)subview;
            break;
        }
    }
    
    if (!inputField) return;
    
    UILabel *label = nil;
    for (UIView *subview in itemView.subviews) {
        if ([subview isKindOfClass:[UILabel class]]) {
            label = (UILabel *)subview;
            break;
        }
    }
    
    if (!label) return;
    
    NSString *fieldName = label.text;
    NSString *newValue = inputField.text;
    
    NSLog(@"✅ Apply: %@ = %@", fieldName, newValue);
    
    // رسالة تأكيد
    [self showFeedback:[NSString stringWithFormat:@"%@ set to %@", fieldName, newValue]];
}

- (void)showFeedback:(NSString *)message {
    // رسالة داخل المينو
    for (UIView *view in self.menuView.subviews) {
        if ([view isKindOfClass:[UILabel class]] && view.tag == 999) {
            [view removeFromSuperview];
        }
    }
    
    UILabel *feedbackLabel = [[UILabel alloc] initWithFrame:CGRectMake(10, 265, 260, 20)];
    feedbackLabel.text = message;
    feedbackLabel.font = [UIFont fontWithName:@"HelveticaNeue" size:11];
    feedbackLabel.textColor = [UIColor colorWithWhite:0.6 alpha:1];
    feedbackLabel.textAlignment = NSTextAlignmentCenter;
    feedbackLabel.tag = 999;
    [_menuView addSubview:feedbackLabel];
    
    [self performSelector:@selector(clearFeedback) withObject:nil afterDelay:2.5];
}

- (void)clearFeedback {
    for (UIView *view in self.menuView.subviews) {
        if ([view isKindOfClass:[UILabel class]] && view.tag == 999) {
            [view removeFromSuperview];
        }
    }
}

- (void)updateContentSize {
    CGFloat totalHeight = self.contentView.subviews.count * 46 + 10;
    CGRect frame = self.contentView.frame;
    frame.size.height = totalHeight;
    self.contentView.frame = frame;
    self.scrollView.contentSize = CGSizeMake(260, totalHeight);
}

// ============================================================
// ===== 4. دوال التحكم في المينو =====
// ============================================================
- (void)toggleMenu {
    _isMenuVisible = !_isMenuVisible;
    _menuView.hidden = !_isMenuVisible;
    if (_isMenuVisible) {
        [self.superview bringSubviewToFront:self];
    }
}

- (void)handlePan:(UIPanGestureRecognizer *)gr {
    CGPoint translation = [gr translationInView:self.superview];
    self.center = CGPointMake(self.center.x + translation.x, self.center.y + translation.y);
    [gr setTranslation:CGPointZero inView:self.superview];
}

@end

// ============================================================
// ===== 5. دوال الحقن (Injection) =====
// ============================================================
static FrezonModOverlay *overlay;

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
    if (overlay.superview == window) return;
    
    if (!overlay) {
        overlay = [[FrezonModOverlay alloc] init];
    }
    [window addSubview:overlay];
    [window bringSubviewToFront:overlay];
}

__attribute__((constructor))
static void frezonmod_entry(void) {
    dispatch_time_t delay = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC));
    dispatch_after(delay, dispatch_get_main_queue(), ^{
        ensureOverlay();
        [NSTimer scheduledTimerWithTimeInterval:3.0 repeats:YES block:^(NSTimer * _Nonnull timer) {
            ensureOverlay();
        }];
    });
}
