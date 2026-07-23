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
// 2. كتابة الذاكرة بأمان
// ============================================================
BOOL safeWrite(uintptr_t address, void *data, size_t size) {
    if (!address || !data) return NO;
    
    mach_port_t task = mach_task_self();
    kern_return_t kr;
    
    // الحصول على الحماية الأصلية
    vm_prot_t originalProtection = 0;
    vm_region_basic_info_data_64_t info;
    mach_vm_size_t regionSize = size;
    mach_vm_address_t regionAddress = address;
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
// 3. البحث عن RouteConfig
// ============================================================
static uintptr_t routeConfigAddress = 0;

uintptr_t findRouteConfig() {
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
            NSLog(@"✅ RouteConfig found: 0x%lx", (unsigned long)routeConfigAddress);
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
// 4. تطبيق التعديلات
// ============================================================
void applyRouteSeed(int seed) {
    uintptr_t addr = findRouteConfig();
    if (addr == 0) {
        NSLog(@"❌ RouteConfig not found");
        return;
    }
    
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
                uint32_t ret = 0xD65F03C0;
                safeWrite(base + RVA_ON_PICKED_UP, &ret, 4);
                NSLog(@"✅ CoinPickup disabled");
            }
            break;
        }
    }
}

// ============================================================
// 5. واجهة المستخدم (Class حقيقي)
// ============================================================
@interface ModMenuViewController : UIViewController
@property (nonatomic, strong) UITextField *seedField;
@end

@implementation ModMenuViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor clearColor];
    
    UIView *menuView = [[UIView alloc] initWithFrame:CGRectMake(20, 120, 280, 180)];
    menuView.backgroundColor = [UIColor colorWithWhite:0.08 alpha:0.95];
    menuView.layer.cornerRadius = 16;
    menuView.layer.borderColor = [UIColor grayColor].CGColor;
    menuView.layer.borderWidth = 0.5;
    [self.view addSubview:menuView];
    
    UILabel *title = [[UILabel alloc] initWithFrame:CGRectMake(10, 10, 260, 30)];
    title.text = @"Frezon Mod";
    title.textColor = [UIColor whiteColor];
    title.textAlignment = NSTextAlignmentCenter;
    title.font = [UIFont boldSystemFontOfSize:18];
    [menuView addSubview:title];
    
    self.seedField = [[UITextField alloc] initWithFrame:CGRectMake(20, 50, 180, 40)];
    self.seedField.placeholder = @"Enter Seed";
    self.seedField.textColor = [UIColor whiteColor];
    self.seedField.backgroundColor = [UIColor colorWithWhite:0.2 alpha:1];
    self.seedField.layer.cornerRadius = 8;
    self.seedField.keyboardType = UIKeyboardTypeNumberPad;
    [menuView addSubview:self.seedField];
    
    UIButton *applyBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    applyBtn.frame = CGRectMake(210, 50, 60, 40);
    applyBtn.backgroundColor = [UIColor colorWithRed:0.2 green:0.7 blue:0.2 alpha:1];
    applyBtn.layer.cornerRadius = 8;
    [applyBtn setTitle:@"Apply" forState:UIControlStateNormal];
    [applyBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    [applyBtn addTarget:self action:@selector(applySeed) forControlEvents:UIControlEventTouchUpInside];
    [menuView addSubview:applyBtn];
    
    UIButton *closeBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    closeBtn.frame = CGRectMake(20, 110, 240, 35);
    [closeBtn setTitle:@"Close" forState:UIControlStateNormal];
    [closeBtn setTitleColor:[UIColor grayColor] forState:UIControlStateNormal];
    [closeBtn addTarget:self action:@selector(closeMenu) forControlEvents:UIControlEventTouchUpInside];
    [menuView addSubview:closeBtn];
    
    // مفتاح CoinPickup
    UIView *coinView = [[UIView alloc] initWithFrame:CGRectMake(20, 155, 240, 30)];
    coinView.backgroundColor = [UIColor colorWithWhite:0.1 alpha:0.8];
    coinView.layer.cornerRadius = 8;
    [menuView addSubview:coinView];
    
    UILabel *coinLabel = [[UILabel alloc] initWithFrame:CGRectMake(10, 0, 150, 30)];
    coinLabel.text = @"No Coin Pickup";
    coinLabel.textColor = [UIColor whiteColor];
    coinLabel.font = [UIFont systemFontOfSize:13];
    [coinView addSubview:coinLabel];
    
    UISwitch *coinSwitch = [[UISwitch alloc] initWithFrame:CGRectMake(180, 0, 50, 30)];
    coinSwitch.onTintColor = [UIColor greenColor];
    [coinSwitch addTarget:self action:@selector(toggleCoinPickup:) forControlEvents:UIControlEventValueChanged];
    [coinView addSubview:coinSwitch];
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
// 6. دوال التحكم في الواجهة
// ============================================================
static ModMenuViewController *menuVC = nil;
static UIButton *floatingButton = nil;

void toggleMenu() {
    UIWindow *window = getActiveWindow();
    if (!window) return;
    
    if (!menuVC) {
        menuVC = [[ModMenuViewController alloc] init];
        menuVC.view.frame = window.bounds;
        menuVC.view.userInteractionEnabled = YES;
    }
    
    if (menuVC.view.superview) {
        [menuVC.view removeFromSuperview];
    } else {
        [window addSubview:menuVC.view];
        [window bringSubviewToFront:menuVC.view];
    }
}

UIWindow* getActiveWindow() {
    if (@available(iOS 13.0, *)) {
        for (UIScene *scene in [UIApplication sharedApplication].connectedScenes) {
            if ([scene isKindOfClass:[UIWindowScene class]] && scene.activationState == UISceneActivationStateForegroundActive) {
                return ((UIWindowScene *)scene).windows.firstObject;
            }
        }
    }
    return [UIApplication sharedApplication].keyWindow;
}

// ============================================================
// 7. نقطة الدخول
// ============================================================
__attribute__((constructor))
static void frezonmod_entry() {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 3 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        UIWindow *window = getActiveWindow();
        if (!window) return;
        
        if (!floatingButton) {
            floatingButton = [UIButton buttonWithType:UIButtonTypeCustom];
            floatingButton.frame = CGRectMake(20, 100, 60, 60);
            floatingButton.layer.cornerRadius = 30;
            floatingButton.backgroundColor = [UIColor blackColor];
            floatingButton.layer.borderColor = [UIColor whiteColor].CGColor;
            floatingButton.layer.borderWidth = 2;
            [floatingButton setTitle:@"F" forState:UIControlStateNormal];
            [floatingButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
            floatingButton.titleLabel.font = [UIFont boldSystemFontOfSize:28];
            [floatingButton addTarget:self action:@selector(toggleMenu) forControlEvents:UIControlEventTouchUpInside];
            [window addSubview:floatingButton];
            [window bringSubviewToFront:floatingButton];
        }
        
        findRouteConfig();
        NSLog(@"✅ Frezon Mod loaded!");
    });
}
