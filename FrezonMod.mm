#import <UIKit/UIKit.h>
#import <mach/mach.h>
#import <mach-o/dyld.h>
#import <objc/runtime.h>

// ============================================================
// 1. الأوفستات (من dump.cs)
// ============================================================
#define FORCE_SEED_OFFSET           0x20
#define RVA_OVERRIDE_SEED           0x19B602C

// ============================================================
// 2. كتابة الذاكرة بأمان (safeWrite)
// ============================================================
BOOL safeWrite(uintptr_t address, void *data, size_t size) {
    if (!address || !data) return NO;
    
    mach_port_t task = mach_task_self();
    kern_return_t kr;
    
    // الحصول على الحماية الأصلية للصفحة
    vm_prot_t originalProtection = 0;
    vm_region_basic_info_data_64_t info;
    mach_vm_size_t regionSize = size;
    mach_vm_address_t regionAddress = address;
    mach_msg_type_number_t infoCount = VM_REGION_BASIC_INFO_COUNT_64;
    
    kr = mach_vm_region(task, &regionAddress, &regionSize, VM_REGION_BASIC_INFO_64,
                        (vm_region_info_t)&info, &infoCount, NULL);
    
    if (kr == KERN_SUCCESS) {
        originalProtection = info.protection;
    } else {
        originalProtection = VM_PROT_READ | VM_PROT_WRITE;
    }
    
    // تغيير الحماية للكتابة
    kr = vm_protect(task, (vm_address_t)address, size, 0,
                    VM_PROT_READ | VM_PROT_WRITE | VM_PROT_COPY);
    if (kr != KERN_SUCCESS) {
        NSLog(@"❌ Failed to change protection at 0x%lx", (unsigned long)address);
        return NO;
    }
    
    // كتابة البيانات
    memcpy((void *)address, data, size);
    
    // إعادة الحماية الأصلية
    kr = vm_protect(task, (vm_address_t)address, size, 0, originalProtection);
    if (kr != KERN_SUCCESS) {
        NSLog(@"⚠️ Failed to restore protection at 0x%lx", (unsigned long)address);
    }
    
    return YES;
}

// ============================================================
// 3. البحث عن RouteConfig (ديناميكياً)
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
            NSLog(@"✅ RouteConfig found via ObjC: 0x%lx", (unsigned long)routeConfigAddress);
            return routeConfigAddress;
        }
    }
    
    // إذا فشل ObjC، نبحث في الذاكرة باستخدام الـ GC (طريقة بديلة)
    // هذه الطريقة تستخدم نفس آلية الأداة التي استخدمتها
    // وهي تتطلب وجود دوال Unity الداخلية
    // سنستخدمها كحل أخير
    
    NSLog(@"⚠️ RouteConfig not found via ObjC, trying memory scan...");
    
    // البحث عن الكائن في الذاكرة باستخدام الـ isa pointer
    // هذه طريقة تقريبية ولكنها قد تنجح
    uintptr_t base = 0;
    uint32_t imageCount = _dyld_image_count();
    for (uint32_t i = 0; i < imageCount; i++) {
        const char *name = _dyld_get_image_name(i);
        if (name && strstr(name, "UnityFramework") != NULL) {
            const struct mach_header_64 *header = (const struct mach_header_64 *)_dyld_get_image_header(i);
            intptr_t slide = _dyld_get_image_vmaddr_slide(i);
            base = (uintptr_t)header + slide;
            break;
        }
    }
    
    if (base == 0) {
        NSLog(@"❌ UnityFramework base not found");
        return 0;
    }
    
    mach_port_t task = mach_task_self();
    uintptr_t start = base + 0x1000000;
    uintptr_t end = base + 0x3000000;
    
    for (uintptr_t addr = start; addr < end; addr += 8) {
        // قراءة الـ isa pointer
        uintptr_t isa = 0;
        vm_read_overwrite(task, (vm_address_t)addr, sizeof(uintptr_t), (vm_address_t)&isa, NULL);
        
        // التحقق مما إذا كان الـ isa يشير إلى RouteConfig class
        if (isa == (uintptr_t)routeClass) {
            // التحقق من وجود _forceSeed في 0x20
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
// 4. تطبيق Route Seed
// ============================================================
void applyRouteSeed(int seed) {
    uintptr_t addr = findRouteConfig();
    if (addr == 0) {
        NSLog(@"❌ RouteConfig not found, cannot apply seed");
        return;
    }
    
    uintptr_t seedAddress = addr + FORCE_SEED_OFFSET;
    // ToggleInt: { enabled (1 بايت), padding (3 بايت), value (4 بايت) }
    // نكتب 8 بايت كاملة: enabled=1, padding=0, value=seed
    uint8_t toggle[8] = {1, 0, 0, 0, 0, 0, 0, 0};
    memcpy(toggle + 4, &seed, sizeof(int));
    
    if (safeWrite(seedAddress, toggle, sizeof(toggle))) {
        NSLog(@"✅ Route Seed set to: %d", seed);
    } else {
        NSLog(@"❌ Failed to write seed");
    }
}

// ============================================================
// 5. تعطيل CoinPickup (اختياري)
// ============================================================
void applyCoinPickup(BOOL disable) {
    uintptr_t base = 0;
    uint32_t imageCount = _dyld_image_count();
    for (uint32_t i = 0; i < imageCount; i++) {
        const char *name = _dyld_get_image_name(i);
        if (name && strstr(name, "UnityFramework") != NULL) {
            const struct mach_header_64 *header = (const struct mach_header_64 *)_dyld_get_image_header(i);
            intptr_t slide = _dyld_get_image_vmaddr_slide(i);
            base = (uintptr_t)header + slide;
            break;
        }
    }
    
    if (base == 0) return;
    
    uintptr_t addr = base + 0x1B5495C; // RVA من dump.cs
    if (disable) {
        uint32_t ret = 0xD65F03C0; // ARM64 RET
        if (safeWrite(addr, &ret, 4)) {
            NSLog(@"✅ CoinPickup disabled");
        }
    }
}

// ============================================================
// 6. واجهة المستخدم
// ============================================================
static UIWindow *menuWindow = nil;
static BOOL isMenuVisible = NO;

void toggleMenu() {
    if (!menuWindow) {
        menuWindow = [[UIWindow alloc] initWithFrame:CGRectMake(20, 120, 280, 180)];
        menuWindow.backgroundColor = [UIColor colorWithWhite:0.08 alpha:0.95];
        menuWindow.layer.cornerRadius = 16;
        menuWindow.layer.borderColor = [UIColor grayColor].CGColor;
        menuWindow.layer.borderWidth = 0.5;
        menuWindow.windowLevel = UIWindowLevelAlert + 1;
        menuWindow.userInteractionEnabled = YES;
        
        UILabel *title = [[UILabel alloc] initWithFrame:CGRectMake(10, 10, 260, 30)];
        title.text = @"Frezon Mod";
        title.textColor = [UIColor whiteColor];
        title.textAlignment = NSTextAlignmentCenter;
        title.font = [UIFont boldSystemFontOfSize:18];
        [menuWindow addSubview:title];
        
        UITextField *seedField = [[UITextField alloc] initWithFrame:CGRectMake(20, 50, 180, 40)];
        seedField.placeholder = @"Enter Seed";
        seedField.textColor = [UIColor whiteColor];
        seedField.backgroundColor = [UIColor colorWithWhite:0.2 alpha:1];
        seedField.layer.cornerRadius = 8;
        seedField.keyboardType = UIKeyboardTypeNumberPad;
        seedField.tag = 100;
        [menuWindow addSubview:seedField];
        
        UIButton *applyBtn = [UIButton buttonWithType:UIButtonTypeSystem];
        applyBtn.frame = CGRectMake(210, 50, 60, 40);
        applyBtn.backgroundColor = [UIColor colorWithRed:0.2 green:0.7 blue:0.2 alpha:1];
        applyBtn.layer.cornerRadius = 8;
        [applyBtn setTitle:@"Apply" forState:UIControlStateNormal];
        [applyBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        [applyBtn addTarget:self action:@selector(applySeedAction) forControlEvents:UIControlEventTouchUpInside];
        [menuWindow addSubview:applyBtn];
        
        UIButton *closeBtn = [UIButton buttonWithType:UIButtonTypeSystem];
        closeBtn.frame = CGRectMake(20, 110, 240, 35);
        [closeBtn setTitle:@"Close" forState:UIControlStateNormal];
        [closeBtn setTitleColor:[UIColor grayColor] forState:UIControlStateNormal];
        [closeBtn addTarget:self action:@selector(closeMenu) forControlEvents:UIControlEventTouchUpInside];
        [menuWindow addSubview:closeBtn];
        
        [menuWindow makeKeyAndVisible];
    }
    
    isMenuVisible = !isMenuVisible;
    menuWindow.hidden = !isMenuVisible;
}

void closeMenu() {
    isMenuVisible = NO;
    menuWindow.hidden = YES;
}

void applySeedAction() {
    UITextField *field = (UITextField *)[menuWindow viewWithTag:100];
    if (!field || field.text.length == 0) return;
    
    int seed = [field.text intValue];
    if (seed >= 0) {
        applyRouteSeed(seed);
        
        // رسالة تأكيد
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"✅ Done"
                                                                       message:[NSString stringWithFormat:@"Seed set to: %d", seed]
                                                                preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
        
        UIViewController *rootVC = menuWindow.rootViewController;
        if (!rootVC) {
            UIViewController *tempVC = [[UIViewController alloc] init];
            menuWindow.rootViewController = tempVC;
            rootVC = tempVC;
        }
        [rootVC presentViewController:alert animated:YES completion:nil];
    }
}

// ============================================================
// 7. نقطة الدخول
// ============================================================
__attribute__((constructor))
static void frezonmod_entry() {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 3 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        UIWindow *window = [UIApplication sharedApplication].keyWindow;
        if (!window) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 1 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
                frezonmod_entry();
            });
            return;
        }
        
        // زر المنيو
        UIButton *menuBtn = [UIButton buttonWithType:UIButtonTypeCustom];
        menuBtn.frame = CGRectMake(20, 100, 60, 60);
        menuBtn.layer.cornerRadius = 30;
        menuBtn.clipsToBounds = YES;
        menuBtn.backgroundColor = [UIColor blackColor];
        menuBtn.layer.borderColor = [UIColor whiteColor].CGColor;
        menuBtn.layer.borderWidth = 2;
        [menuBtn setTitle:@"F" forState:UIControlStateNormal];
        [menuBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        menuBtn.titleLabel.font = [UIFont boldSystemFontOfSize:28];
        [menuBtn addTarget:self action:@selector(toggleMenu) forControlEvents:UIControlEventTouchUpInside];
        [window addSubview:menuBtn];
        [window bringSubviewToFront:menuBtn];
        
        // محاولة العثور على RouteConfig
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 1 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
            findRouteConfig();
        });
        
        NSLog(@"✅ Frezon Mod loaded!");
    });
}
