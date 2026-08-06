#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>

static UIWindow *overlayWindow = nil;
static UIView *menuContainer = nil;
static BOOL isHackFolderReady = NO;

// دالة التهيئة (تُستدعى فور تحميل المكتبة)
__attribute__((constructor)) static void initFrezon() {
    // تشغيل Thread منفصل للتأخير دون تعطيل الخيط الرئيسي
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        // انتظار 10 ثواني كاملة
        [NSThread sleepForTimeInterval:10.0];
        
        // العودة إلى الخيط الرئيسي لبناء واجهة المستخدم
        dispatch_async(dispatch_get_main_queue(), ^{
            [self safeBuildInterface];
        });
    });
}

// دالة آمنة تتحقق من وجود المجلد قبل بناء الواجهة
+ (void)safeBuildInterface {
    NSString *hackPath = [self findHackFolder];
    if (!hackPath) {
        NSLog(@"[Frezon] مجلد hack غير موجود بعد 10 ثواني، تأكد من وجوده داخل الحزمة");
        [self showErrorAlert:@"مجلد hack غير موجود، المود لن يعمل"];
        return;
    }
    
    // التحقق من وجود الأيقونة وملفات seed
    NSString *iconPath = [hackPath stringByAppendingPathComponent:@"icon.png"];
    NSString *seedPath = [hackPath stringByAppendingPathComponent:@"seed"];
    BOOL isDir = NO;
    if (![[NSFileManager defaultManager] fileExistsAtPath:iconPath] ||
        ![[NSFileManager defaultManager] fileExistsAtPath:seedPath isDirectory:&isDir] || !isDir) {
        NSLog(@"[Frezon] الملفات ناقصة: icon.png أو مجلد seed غير موجود");
        [self showErrorAlert:@"ملفات المود ناقصة، تأكد من وجود icon.png ومجلد seed"];
        return;
    }
    
    // كل شيء جاهز، نبني الواجهة
    isHackFolderReady = YES;
    [self buildFrezonInterfaceWithHackPath:hackPath];
}

// دالة البحث عن مجلد hack في عدة مسارات
+ (NSString *)findHackFolder {
    NSArray *possiblePaths = @[
        // المسار الأساسي داخل حزمة التطبيق
        [[[NSBundle mainBundle] bundlePath] stringByAppendingPathComponent:@"hack"],
        // مسار احتياطي داخل Documents الخاص باللعبة
        [[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject] stringByAppendingPathComponent:@"hack"],
        // مسار عام على الجهاز (يتطلب صلاحيات)
        @"/var/mobile/hack"
    ];
    
    for (NSString *path in possiblePaths) {
        BOOL isDir = NO;
        if ([[NSFileManager defaultManager] fileExistsAtPath:path isDirectory:&isDir] && isDir) {
            return path;
        }
    }
    return nil;
}

// دالة بناء الواجهة
+ (void)buildFrezonInterfaceWithHackPath:(NSString *)hackPath {
    // إنشاء النافذة العائمة
    overlayWindow = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
    overlayWindow.windowLevel = UIWindowLevelAlert + 1;
    overlayWindow.backgroundColor = [UIColor clearColor];
    overlayWindow.userInteractionEnabled = YES;
    overlayWindow.hidden = NO;

    // حاوية المود
    CGFloat width = 300, height = 220;
    CGFloat x = (overlayWindow.bounds.size.width - width) / 2;
    CGFloat y = (overlayWindow.bounds.size.height - height) / 2 - 60;
    menuContainer = [[UIView alloc] initWithFrame:CGRectMake(x, y, width, height)];
    menuContainer.backgroundColor = [UIColor colorWithWhite:0.08 alpha:0.94];
    menuContainer.layer.cornerRadius = 18;
    menuContainer.layer.borderColor = [UIColor colorWithRed:0.0 green:0.8 blue:0.0 alpha:0.9].CGColor;
    menuContainer.layer.borderWidth = 2.5;
    menuContainer.clipsToBounds = YES;

    // العنوان الثابت
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

    // استدعاء الأيقونة من مسار hack
    NSString *iconPath = [hackPath stringByAppendingPathComponent:@"icon.png"];
    UIImage *iconImage = [UIImage imageWithContentsOfFile:iconPath];
    if (!iconImage) {
        iconPath = [hackPath stringByAppendingPathComponent:@"icon"];
        iconImage = [UIImage imageWithContentsOfFile:iconPath];
    }
    if (!iconImage) {
        // صورة افتراضية احتياطية
        UIGraphicsBeginImageContextWithOptions(CGSizeMake(60, 60), NO, 0);
        [[UIColor greenColor] setFill];
        UIRectFill(CGRectMake(0, 0, 60, 60));
        iconImage = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();
    }

    // زر التشغيل
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

    // زر إغلاق
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
    
    NSLog(@"[Frezon] تم بناء الواجهة بنجاح بعد 10 ثواني");
}

// دالة عرض خطأ بدلاً من الكراش
+ (void)showErrorAlert:(NSString *)message {
    dispatch_async(dispatch_get_main_queue(), ^{
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Frezon Mod Error"
                                                                       message:message
                                                                preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
        UIViewController *rootVC = [UIApplication sharedApplication].keyWindow.rootViewController;
        if (rootVC) {
            [rootVC presentViewController:alert animated:YES completion:nil];
        } else {
            NSLog(@"[Frezon] لا يوجد Root View Controller لعرض التنبيه");
        }
    });
}

// دالة استبدال الملفات
+ (void)executeSeedReplacement {
    if (!isHackFolderReady) {
        [self showFeedback:@"المود غير جاهز، تأكد من وجود مجلد hack"];
        return;
    }
    
    NSString *hackPath = [self findHackFolder];
    if (!hackPath) {
        [self showFeedback:@"مجلد hack غير موجود"];
        return;
    }
    
    NSString *seedPath = [hackPath stringByAppendingPathComponent:@"seed"];
    BOOL isDir = NO;
    if (![[NSFileManager defaultManager] fileExistsAtPath:seedPath isDirectory:&isDir] || !isDir) {
        [self showFeedback:@"مجلد seed غير موجود داخل hack"];
        return;
    }

    NSString *docPath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject];
    NSArray *targetFiles = @[@"wallet.json", @"user_stats.json", @"characters_inventory.json", 
                             @"boards_inventory.json", @"upgrades.json"];
    
    BOOL anySuccess = NO;
    NSError *error = nil;
    NSFileManager *fm = [NSFileManager defaultManager];

    for (NSString *fileName in targetFiles) {
        NSString *sourcePath = [seedPath stringByAppendingPathComponent:fileName];
        NSString *destPath = [docPath stringByAppendingPathComponent:fileName];
        
        if ([fm fileExistsAtPath:sourcePath]) {
            if ([fm fileExistsAtPath:destPath]) {
                [fm removeItemAtPath:destPath error:nil];
            }
            if ([fm copyItemAtPath:sourcePath toPath:destPath error:&error]) {
                anySuccess = YES;
                NSLog(@"[Frezon] تم نسخ %@ بنجاح", fileName);
            } else {
                NSLog(@"[Frezon] فشل نسخ %@: %@", fileName, error.localizedDescription);
            }
        }
    }

    if (anySuccess) {
        [self showFeedback:@"تم استبدال جميع الملفات بنجاح!"];
    } else {
        [self showFeedback:@"لم يتم العثور على ملفات في seed"];
    }
}

// دوال مساعدة
+ (void)dragContainer:(UIPanGestureRecognizer *)gesture {
    CGPoint translation = [gesture translationInView:overlayWindow];
    gesture.view.center = CGPointMake(gesture.view.center.x + translation.x, gesture.view.center.y + translation.y);
    [gesture setTranslation:CGPointZero inView:overlayWindow];
}

+ (void)closeOverlay {
    overlayWindow.hidden = YES;
}

+ (void)showFeedback:(NSString *)msg {
    dispatch_async(dispatch_get_main_queue(), ^{
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
    });
}
