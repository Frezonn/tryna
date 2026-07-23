#import <UIKit/UIKit.h>
#import <mach/mach.h>
#import <mach-o/dyld.h>
#import <objc/runtime.h>

// ============================================================
// 1. الأوفستات
// ============================================================
#define RVA_OVERRIDE_SEED           0x19B602C
#define FORCE_SEED_OFFSET           0x20

// ============================================================
// 2. البحث عن RouteConfig
// ============================================================
static uintptr_t routeConfigAddress = 0;

uintptr_t findRouteConfig() {
    if (routeConfigAddress != 0) return routeConfigAddress;

    // محاولة الحصول على الكلاس عبر الـ Runtime
    Class routeClass = objc_getClass("SYBO.Subway.RouteConfig");
    if (!routeClass) {
        // محاولة البحث المباشر في الذاكرة
        // (هنا يمكنك استخدام الـ FindObjects أو البحث عن النمط)
        return 0;
    }

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

    return 0;
}

// ============================================================
// 3. تطبيق الـ Seed (باستخدام العنوان الديناميكي)
// ============================================================
void applyRouteSeed(int seed) {
    uintptr_t addr = findRouteConfig();
    if (addr == 0) {
        NSLog(@"❌ RouteConfig not found, cannot apply seed");
        return;
    }

    uintptr_t seedAddress = addr + FORCE_SEED_OFFSET;
    int toggle[2] = {1, seed}; // enabled = 1, value = seed
    if (safeWrite(seedAddress, toggle, sizeof(toggle))) {
        NSLog(@"✅ Route Seed set to: %d", seed);
    }
}
