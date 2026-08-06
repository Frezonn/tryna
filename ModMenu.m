#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <QuartzCore/QuartzCore.h>

static UIWindow *overlayWindow = nil;
static UIView *menuContainer = nil;

__attribute__((constructor)) static void initFrezon() {
    dispatch_async(dispatch_get_main_queue(), ^{
        // Call the class method on FrezonMod (can't use `self` here)
        [FrezonMod buildFrezonInterface];
    });
}

@interface FrezonMod : NSObject

+ (void)buildFrezonInterface;
+ (void)executeSeedReplacement;
+ (void)showFeedback:(NSString *)msg;
+ (void)dragContainer:(UIPanGestureRecognizer *)gesture;
+ (void)closeOverlay;

@end

@implementation FrezonMod

+ (void)buildFrezonInterface {
    // النافذة العائمة
    overlayWindow = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
    overlayWindow.windowLevel = UIWindowLevelAlert + 1;
    overlayWindow.backgroundColor = [UIColor clearColor];
    overlayWindow.userInteractionEnabled = YES;
    overlayWindow.hidden = NO;

    // Ensure a rootViewController so touches/rotation work properly
    if (!overlayWindow.rootViewController) {
        UIViewController *vc = [UIViewController new];
        vc.view.backgroundColor = [UIColor clearColor];
        overlayWindow.rootViewController = vc;
    }

    // الحاوية الرئيسية للمود (وسط الشاشة)
    CGFloat width = 300, height = 220;
    CGFloat x = (overlayWindow.bounds.size.width - width) / 2;
    CGFloat y = (overlayWindow.bounds.size.height - height) / 2 - 60;
    menuContainer = [[UIView alloc] initWithFrame:CGRectMake(x, y, width, height)];
    menuContainer.backgroundColor = [UIColor colorWithWhite:0.08 alpha:0.94];
    menuContainer.layer.cornerRadius = 18;
    menuContainer.layer.borderColor = [UIColor colorWithRed:0.0 green:0.8 blue:0.0 alpha:0.9].CGColor;
    menuContainer.layer.borderWidth = 2.5;
    menuContainer.clipsToBounds = YES;

    // === العنوان الثابت "Frezon mod v0.1" ===
    UILabel *titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 10, width, 40)];
    titleLabel.text = @"Frezon mod v0.1";
    titleLabel.textColor = [UIColor colorWithRed:0.0 green:1.0 blue:0.0 alpha:1.0];
    titleLabel.textAlignment = NSTextAlignmentCenter;
    titleLabel.font = [UIFont boldSystemFontOfSize:22];
    titleLabel.backgroundColor = [UIColor colorWithWhite:0.2 alpha:0.4];
    [menuContainer addSubview:titleLabel];

    // خط فاصل
    UIView *sep = [[UIView alloc] initWithFrame:CGRectMake(10, 54, width - 20, 1.5)];
    sep.backgroundColor = [UIColor darkGrayColor];
    [menuContainer addSubview:sep];

    // === استدعاء أيقونة الزر من مجلد hack ===
    NSString *bundlePath = [[NSBundle mainBundle] bundlePath];
    NSString *hackFolder = [bundlePath stringByAppendingPathComponent:@"hack"];
    NSString *iconPath = [hackFolder stringByAppendingPathComponent:@"icon.png"];

    // إذا لم تكن الصورة موجودة، استخدم نصاً احتياطياً
    UIImage *iconImage = [UIImage imageWithContentsOfFile:iconPath];
    if (!iconImage) {
        // حاول بدون امتداد
        iconPath = [hackFolder stringByAppendingPathComponent:@"icon"];
        iconImage = [UIImage imageWithContentsOfFile:iconPath];
    }
    if (!iconImage) {
        // إنشاء صورة افتراضية خضراء كحل أخير
        UIGraphicsBeginImageContextWithOptions(CGSizeMake(60, 60), NO, 0);
        [[UIColor greenColor] setFill];
        UIRectFill(CGRectMake(0, 0, 60, 60));
        iconImage = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();
    }

    // زر التشغيل الأساسي (يستخدم الأيقونة المستدعاة)
    UIButton *actionBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    actionBtn.frame = CGRectMake((width - 180) / 2, 70, 180, 60);
    [actionBtn setImage:iconImage forState:UIControlStateNormal];
    [actionBtn setTitle:@" Unlimited Everything" forState:UIControlStateNormal];
    [actionBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    actionBtn.titleLabel.font = [UIFont boldSystemFontOfSize:18];
    actionBtn.backgroundColor = [UIColor colorWithRed:0.0 green:0.4 blue:0.0 alpha:0.85];
    actionBtn.layer.cornerRadius = 12;
    actionBtn.imageEdgeInsets = UIEdgeInsetsMake(5, 5, 5, 10);
    actionBtn.titleEdgeInsets = UIEdgeInsetsMake(0, 10, 0, 0);
    [actionBtn addTarget:self action:@selector(executeSeedReplacement) forControlEvents:UIControlEventTouchUpInside];
    [menuContainer addSubview:actionBtn];

    // زر إغلاق (اختياري)
    UIButton *closeBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    closeBtn.frame = CGRectMake(width - 45, 8, 35, 35);
    [closeBtn setTitle:@"✕" forState:UIControlStateNormal];
    [closeBtn setTitleColor:[UIColor redColor] forState:UIControlStateNormal];
    closeBtn.titleLabel.font = [UIFont boldSystemFontOfSize:20];
    [closeBtn addTarget:self action:@selector(closeOverlay) forControlEvents:UIControlEventTouchUpInside];
    [menuContainer addSubview:closeBtn];

    // إضافة سحب للحاوية
    UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(dragContainer:)];
    [menuContainer addGestureRecognizer:pan];

    [overlayWindow addSubview:menuContainer];
}

// === الوظيفة الأساسية: استبدال الملفات من seed إلى Documents ===
+ (void)executeSeedReplacement {
    NSString *bundlePath = [[NSBundle mainBundle] bundlePath];
    NSString *seedFolder = [[bundlePath stringByAppendingPathComponent:@"hack"] stringByAppendingPathComponent:@"seed"];

    // التأكد من وجود مجلد seed
    BOOL isDir = NO;
    if (![[NSFileManager defaultManager] fileExistsAtPath:seedFolder isDirectory:&isDir] || !isDir) {
        [self showFeedback:@"خطأ: مجلد seed غير موجود"];
        return;
    }

    // مسار Documents حيث تتوقع اللعبة ملفاتها
    NSString *docPath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject];

    // قائمة الملفات المستهدفة
    NSArray *targetFiles = @[@"wallet.json", @"user_stats.json", @"characters_inventory.json", 
                             @"boards_inventory.json", @"upgrades.json"];

    BOOL anySuccess = NO;
    NSError *error = nil;
    NSFileManager *fm = [NSFileManager defaultManager];

    for (NSString *fileName in targetFiles) {
        NSString *sourcePath = [seedFolder stringByAppendingPathComponent:fileName];
        NSString *destPath = [docPath stringByAppendingPathComponent:fileName];

        // هل الملف المصدر موجود؟
        if ([fm fileExistsAtPath:sourcePath]) {
            // حذف الملف الهدف القديم (إن وجد) ثم نسخ الجديد
            if ([fm fileExistsAtPath:destPath]) {
                [fm removeItemAtPath:destPath error:nil];
            }
            if ([fm copyItemAtPath:sourcePath toPath:destPath error:&error]) {
                anySuccess = YES;
            } else {
                NSLog(@"[Frezon] فشل نسخ %@: %@", fileName, error.localizedDescription);
            }
        }
    }

    if (anySuccess) {
        [self showFeedback:@"تم استبدال جميع الملفات بنجاح!"];
        // تأكد من تحديث التطبيق للملفات (في الألعاب التي تخزنها في الذاكرة، قد تحتاج إلى إعادة تشغيل)
    } else {
        [self showFeedback:@"لم يتم العثور على ملفات في seed"];
    }
}

// === عرض رسائل داخل الواجهة ===
+ (void)showFeedback:(NSString *)msg {
    UILabel *fb = (UILabel *)[menuContainer viewWithTag:999];
    if (fb) [fb removeFromSuperview];

    fb = [[UILabel alloc] initWithFrame:CGRectMake(10, 150, menuContainer.bounds.size.width - 20, 40)];
    fb.text = msg;
    fb.textColor = [UIColor yellowColor];
    fb.textAlignment = NSTextAlignmentCenter;
    fb.font = [UIFont boldSystemFontOfSize:14];
    fb.numberOfLines = 2;
    fb.tag = 999;
    [menuContainer addSubview:fb];

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(4 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [fb removeFromSuperview];
    });
}

// === دوال السحب والإغلاق ===
+ (void)dragContainer:(UIPanGestureRecognizer *)gesture {
    CGPoint translation = [gesture translationInView:overlayWindow];
    gesture.view.center = CGPointMake(gesture.view.center.x + translation.x, gesture.view.center.y + translation.y);
    [gesture setTranslation:CGPointZero inView:overlayWindow];
}

+ (void)closeOverlay {
    overlayWindow.hidden = YES;
}

@end
