#import <UIKit/UIKit.h>
#import <mach/mach.h>
#import <mach-o/dyld.h>
#import <objc/runtime.h>

// ============================================================
// 1. الأوفستات (من dump.cs)
// ============================================================
#define FORCE_SEED_OFFSET           0x20
#define RVA_ON_PICKED_UP            0x1B5495C

// ============================================================
// 2. الحصول على النافذة النشطة (iOS 13+)
// ============================================================
UIWindow* getActiveWindow(void) {
    if (@available(iOS 13.0, *)) {
        for (UIScene *scene in [UIApplication sharedApplication].connectedScenes) {
            if ([scene isKindOfClass:[UIWindowScene class]] &&
                scene.activationState == UISceneActivationStateForegroundActive) {
                UIWindowScene *ws = (UIWindowScene *)scene;
                return ws.windows.firstObject;
            }
        }
    }
    // Fallback (مهمل لكن للتوافق مع الإصدارات القديمة)
    return [UIApplication sharedApplication].keyWindow;
}

// ============================================================
// 3. كتابة الذاكرة بأمان (باستخدام vm_region)
// ============================================================
BOOL safeWrite(uintptr_t address, void *data, size_t size) {
    if (!address || !data) return NO;
    
    mach_port_t task = mach_task_self();
    kern_return_t kr;
    
    // الحصول على الحماية الأصلية للصفحة
    vm_prot_t originalProtection = 0;
    vm_region_basic_info_data_64_t info;
    vm_size_t regionSize = size;
    vm_address_t regionAddress = (vm_address_t)address;
    mach_msg_type_number_t infoCount = VM_REGION_BASIC_INFO_COUNT_64;
    
    kr = vm_region(task, &regionAddress, &regionSize, VM_REGION_BASIC_INFO_64,
                   (vm_region_info_t)&info, &infoCount, NULL);
    
    if (kr == KERN_SUCCESS) {
        originalProtection = info.protection;
    } else {
        originalProtection = VM_PROT_READ | VM_PROT_WRITE;
    }
    
    // تغيير الحماية للكتابة
    kr = vm_protect(task, (vm_address_t)address, size, 0,
                    VM_PROT_READ | VM_PROT_WRITE | VM_PROT_COPY);
    if (kr != KERN_SUCCESS) return NO;
    
    // كتابة البيانات
    memcpy((void *)address, data, size);
    
    // إعادة الحماية الأصلية
    vm_protect(task, (vm_address_t)address, size, 0, originalProtection);
    return YES;
}

// ============================================================
// 4. البحث عن RouteConfig
// ============================================================
static uintptr_t routeConfigAddress = 0;

uintptr_t findRouteConfig(void) {
    if (routeConfigAddress != 0) return routeConfigAddress;
    
    // محاولة الحصول على الكلاس عبر Objective-C Runtime
    Class routeClass = objc_getClass("SYBO.Subway.RouteConfig");
    if (!routeClass) {
        routeClass = objc_getClass("RouteConfig");
    }
    
    if (routeClass) {
        // محاولة الحصول على الـ Singleton
        id instance = nil;
        NSArray *props = @[@"instance", @"sharedInstance", @"defaultInstance", @"Default"];
        for (NSString *prop in props) {
            @try {
                instance = [routeClass valueForKey:prop];
                if (instance) break;
            } @catch (NSException *e) {}
        }
        
        if (instance) {
            routeConfigAddress = (uintptr_t)instance;
            NSLog(@"✅ RouteConfig found via ObjC: 0x%lx", (unsigned long)routeConfigAddress);
            return routeConfigAddress;
        }
    }
    
    // البحث في الذاكرة عبر الـ isa pointer
    uintptr_t base = 0;
    uint32_t imageCount = _dyld_image_count();
    for (uint32_t i = 0; i < imageCount; i++) {
        const char *name = _dyld_get_image_name(i);
        if (name && strstr(name, "UnityFramework")) {
            const struct mach_header_64 *header = (const struct mach_header_64 *)_dyld_get_image_header(i);
            intptr_t slide = _dyld_get_image_vmaddr_slide(i);
            base = (uintptr_t)header + slide;
            break;
        }
    }
    
    if (base == 0) return 0;
    
    mach_port_t task = mach_task_self();
    for (uintptr_t addr = base + 0x1000000; addr < base + 0x3000000; addr += 8) {
        uintptr_t isa = 0;
        vm_read_overwrite(task, (vm_address_t)addr, sizeof(uintptr_t), (vm_address_t)&isa, NULL);
        if (isa == (uintptr_t)routeClass) {
            int enabled = 0, value = 0;
            vm_read_overwrite(task, (vm_address_t)(addr + 0x20), sizeof(int), (vm_address_t)&enabled, NULL);
            vm_read_overwrite(task, (vm_address_t)(addr + 0x24), sizeof(int), (vm_address_t)&value, NULL);
            if (enabled == 0 && value == 0) {
                routeConfigAddress = addr;
                NSLog(@"✅ RouteConfig found via memory scan: 0x%lx", (unsigned long)routeConfigAddress);
                return routeConfigAddress;
            }
        }
    }
    
    NSLog(@"❌ RouteConfig not found");
    return 0;
}

// ============================================================
// 5. تطبيق التعديلات
// ============================================================
void applyRouteSeed(int seed) {
    uintptr_t addr = findRouteConfig();
    if (addr == 0) {
        NSLog(@"❌ RouteConfig not found");
        return;
    }
    
    // ToggleInt: { enabled (1), padding (3), value (4) } = 8 بايت
    uint8_t toggle[8] = {1, 0, 0, 0, 0, 0, 0, 0};
    memcpy(toggle + 4, &seed, sizeof(int));
    
    if (safeWrite(addr + FORCE_SEED_OFFSET, toggle, sizeof(toggle))) {
        NSLog(@"✅ Seed set to: %d", seed);
    }
}

void applyCoinPickup(BOOL disable) {
    uint32_t imageCount = _dyld_image_count();
    for (uint32_t i = 0; i < imageCount; i++) {
        const char *name = _dyld_get_image_name(i);
        if (name && strstr(name, "UnityFramework")) {
            const struct mach_header_64 *header = (const struct mach_header_64 *)_dyld_get_image_header(i);
            intptr_t slide = _dyld_get_image_vmaddr_slide(i);
            uintptr_t base = (uintptr_t)header + slide;
            if (disable) {
                uint32_t ret = 0xD65F03C0; // ARM64 RET
                safeWrite(base + RVA_ON_PICKED_UP, &ret, 4);
                NSLog(@"✅ CoinPickup disabled");
            }
            break;
        }
    }
}

// ============================================================
// 6. واجهة المستخدم (UIViewController)
// ============================================================
@interface ModMenuViewController : UIViewController
@property (nonatomic, strong) UITextField *seedField;
@property (nonatomic, strong) UISwitch *coinSwitch;
- (void)toggleMenu;
- (void)applySeed;
- (void)toggleCoinPickup:(UISwitch *)sender;
- (void)closeMenu;
@end

@implementation ModMenuViewController {
    UIView *_menuView;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor clearColor];
    
    _menuView = [[UIView alloc] initWithFrame:CGRectMake(20, 120, 280, 200)];
    _menuView.backgroundColor = [UIColor colorWithWhite:0.08 alpha:0.95];
    _menuView.layer.cornerRadius = 16;
    _menuView.layer.borderColor = [UIColor grayColor].CGColor;
    _menuView.layer.borderWidth = 0.5;
    [self.view addSubview:_menuView];
    
    UILabel *title = [[UILabel alloc] initWithFrame:CGRectMake(10, 10, 260, 30)];
    title.text = @"Frezon Mod";
    title.textColor = [UIColor whiteColor];
    title.textAlignment = NSTextAlignmentCenter;
    title.font = [UIFont boldSystemFontOfSize:18];
    [_menuView addSubview:title];
    
    self.seedField = [[UITextField alloc] initWithFrame:CGRectMake(20, 50, 180, 40)];
    self.seedField.placeholder = @"Enter Seed";
    self.seedField.textColor = [UIColor whiteColor];
    self.seedField.backgroundColor = [UIColor colorWithWhite:0.2 alpha:1];
    self.seedField.layer.cornerRadius = 8;
    self.seedField.keyboardType = UIKeyboardTypeNumberPad;
    [_menuView addSubview:self.seedField];
    
    UIButton *applyBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    applyBtn.frame = CGRectMake(210, 50, 60, 40);
    applyBtn.backgroundColor = [UIColor colorWithRed:0.2 green:0.7 blue:0.2 alpha:1];
    applyBtn.layer.cornerRadius = 8;
    [applyBtn setTitle:@"Apply" forState:UIControlStateNormal];
    [applyBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    [applyBtn addTarget:self action:@selector(applySeed) forControlEvents:UIControlEventTouchUpInside];
    [_menuView addSubview:applyBtn];
    
    UIButton *closeBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    closeBtn.frame = CGRectMake(20, 110, 240, 35);
    [closeBtn setTitle:@"Close" forState:UIControlStateNormal];
    [closeBtn setTitleColor:[UIColor grayColor] forState:UIControlStateNormal];
    [closeBtn addTarget:self action:@selector(closeMenu) forControlEvents:UIControlEventTouchUpInside];
    [_menuView addSubview:closeBtn];
    
    // مفتاح CoinPickup
    UIView *coinView = [[UIView alloc] initWithFrame:CGRectMake(20, 155, 240, 30)];
    coinView.backgroundColor = [UIColor colorWithWhite:0.1 alpha:0.8];
    coinView.layer.cornerRadius = 8;
    [_menuView addSubview:coinView];
    
    UILabel *coinLabel = [[UILabel alloc] initWithFrame:CGRectMake(10, 0, 150, 30)];
    coinLabel.text = @"No Coin Pickup";
    coinLabel.textColor = [UIColor whiteColor];
    coinLabel.font = [UIFont systemFontOfSize:13];
    [coinView addSubview:coinLabel];
    
    self.coinSwitch = [[UISwitch alloc] initWithFrame:CGRectMake(180, 0, 50, 30)];
    self.coinSwitch.onTintColor = [UIColor greenColor];
    [self.coinSwitch addTarget:self action:@selector(toggleCoinPickup:) forControlEvents:UIControlEventValueChanged];
    [coinView addSubview:self.coinSwitch];
}

- (void)applySeed {
    int seed = [self.seedField.text intValue];
    if (seed >= 0) {
        applyRouteSeed(seed);
        [self showAlert:[NSString stringWithFormat:@"Seed set to: %d", seed]];
    }
}

- (void)toggleCoinPickup:(UISwitch *)sender {
    applyCoinPickup(sender.isOn);
}

- (void)toggleMenu {
    if (self.view.superview) {
        [self.view removeFromSuperview];
    } else {
        UIWindow *window = getActiveWindow();
        if (window) {
            [window addSubview:self.view];
            [window bringSubviewToFront:self.view];
        }
    }
}

- (void)closeMenu {
    [self.view removeFromSuperview];
}

- (void)showAlert:(NSString *)message {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"✅ Done"
                                                                   message:message
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

@end

// ============================================================
// 7. الكائنات العامة
// ============================================================
static ModMenuViewController *g_menuVC = nil;
static UIButton *g_floatingButton = nil;

// ============================================================
// 8. نقطة الدخول (بدون self)
// ============================================================
__attribute__((constructor))
static void frezonmod_entry(void) {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 3 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        UIWindow *window = getActiveWindow();
        if (!window) return;
        
        // إنشاء ViewController إذا لم يكن موجوداً
        if (!g_menuVC) {
            g_menuVC = [[ModMenuViewController alloc] init];
            g_menuVC.view.frame = window.bounds;
        }
        
        // إنشاء الزر العائم
        if (!g_floatingButton) {
            g_floatingButton = [UIButton buttonWithType:UIButtonTypeCustom];
            g_floatingButton.frame = CGRectMake(20, 100, 60, 60);
            g_floatingButton.layer.cornerRadius = 30;
            g_floatingButton.backgroundColor = [UIColor blackColor];
            g_floatingButton.layer.borderColor = [UIColor whiteColor].CGColor;
            g_floatingButton.layer.borderWidth = 2;
            [g_floatingButton setTitle:@"F" forState:UIControlStateNormal];
            [g_floatingButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
            g_floatingButton.titleLabel.font = [UIFont boldSystemFontOfSize:28];
            // الهدف هو g_menuVC (وليس self)
            [g_floatingButton addTarget:g_menuVC action:@selector(toggleMenu) forControlEvents:UIControlEventTouchUpInside];
            [window addSubview:g_floatingButton];
            [window bringSubviewToFront:g_floatingButton];
        }
        
        // البحث عن RouteConfig
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 1 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
            findRouteConfig();
        });
        
        NSLog(@"✅ Frezon Mod loaded successfully!");
    });
}
