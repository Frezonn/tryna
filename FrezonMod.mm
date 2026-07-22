#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#import <objc/runtime.h>
#import <dlfcn.h>
#import <mach/mach.h>

// ============================================================
// ===== 1. تحميل UnityFramework =====
// ============================================================
static void *unityFrameworkHandle = NULL;
static dispatch_once_t unityLoadOnce;

void loadUnityFramework() {
    dispatch_once(&unityLoadOnce, ^{
        const char *paths[] = {
            "Subwaysurf.app/Frameworks/UnityFramework.framework/UnityFramework",
            "Frameworks/UnityFramework.framework/UnityFramework",
            "/System/Library/Frameworks/UnityFramework.framework/UnityFramework",
            "UnityFramework"
        };
        
        int pathCount = sizeof(paths) / sizeof(paths[0]);
        for (int i = 0; i < pathCount; i++) {
            unityFrameworkHandle = dlopen(paths[i], RTLD_LAZY);
            if (unityFrameworkHandle) {
                NSLog(@"UnityFramework loaded from: %s", paths[i]);
                return;
            }
        }
        
        NSString *bundlePath = [[NSBundle mainBundle] bundlePath];
        NSString *frameworkPath = [bundlePath stringByAppendingPathComponent:@"Frameworks/UnityFramework.framework/UnityFramework"];
        unityFrameworkHandle = dlopen([frameworkPath UTF8String], RTLD_LAZY);
        
        if (unityFrameworkHandle) {
            NSLog(@"UnityFramework loaded from bundle path: %@", frameworkPath);
        } else {
            NSLog(@"Failed to load UnityFramework: %s", dlerror());
        }
    });
}

// ============================================================
// ===== 2. IL2CPP دوال البحث =====
// ============================================================
typedef void *(*il2cpp_class_from_name_t)(void *image, const char *namespaze, const char *name);
typedef void *(*il2cpp_assembly_get_image_t)(void *assembly);
typedef void *(*il2cpp_domain_get_assemblies_t)(void *domain, size_t *size);
typedef void *(*il2cpp_domain_get_t)(void);

static il2cpp_class_from_name_t il2cpp_class_from_name = NULL;
static il2cpp_assembly_get_image_t il2cpp_assembly_get_image = NULL;
static il2cpp_domain_get_assemblies_t il2cpp_domain_get_assemblies = NULL;
static il2cpp_domain_get_t il2cpp_domain_get = NULL;

void init_il2cpp_functions() {
    if (!unityFrameworkHandle) {
        NSLog(@"UnityFramework not loaded");
        return;
    }
    
    il2cpp_class_from_name = (il2cpp_class_from_name_t)dlsym(unityFrameworkHandle, "il2cpp_class_from_name");
    il2cpp_assembly_get_image = (il2cpp_assembly_get_image_t)dlsym(unityFrameworkHandle, "il2cpp_assembly_get_image");
    il2cpp_domain_get_assemblies = (il2cpp_domain_get_assemblies_t)dlsym(unityFrameworkHandle, "il2cpp_domain_get_assemblies");
    il2cpp_domain_get = (il2cpp_domain_get_t)dlsym(unityFrameworkHandle, "il2cpp_domain_get");
    
    if (!il2cpp_class_from_name || !il2cpp_assembly_get_image || !il2cpp_domain_get_assemblies) {
        NSLog(@"Failed to load IL2CPP functions");
    }
}

void *find_class_in_il2cpp(const char *namespaze, const char *name) {
    if (!il2cpp_class_from_name || !il2cpp_domain_get_assemblies || !il2cpp_domain_get) {
        NSLog(@"IL2CPP functions not initialized");
        return NULL;
    }
    
    size_t assembly_count = 0;
    void *domain = il2cpp_domain_get();
    if (!domain) return NULL;
    
    void **assemblies = il2cpp_domain_get_assemblies(domain, &assembly_count);
    if (!assemblies) return NULL;
    
    for (size_t i = 0; i < assembly_count; i++) {
        void *image = il2cpp_assembly_get_image(assemblies[i]);
        if (!image) continue;
        
        void *klass = il2cpp_class_from_name(image, namespaze, name);
        if (klass) return klass;
    }
    return NULL;
}

// ============================================================
// ===== 3. Offsets من Assembly-CSharp =====
// ============================================================
#define OFFSET_GRAVITY                      0x18
#define OFFSET_STICK_TO_GROUND              0x1C
#define OFFSET_SKIP_HOLES                   0x20
#define OFFSET_INITIAL_TARGET_SPEED         0x24
#define OFFSET_FINAL_TARGET_SPEED           0x28
#define OFFSET_SPEED_ACCELERATION_DURATION  0x2C
#define OFFSET_LANE_CHANGE_DURATION         0x30
#define OFFSET_JUMP_ON_GROUNDED_LANE_CHANGE 0x40
#define OFFSET_MIN_TRAVEL_BEFORE_LANE_CHANGE 0x44
#define OFFSET_ALLOW_LANE_CHANGE_TOWARDS_BOUNDARIES 0x48
#define OFFSET_JUMP_HEIGHT                  0x4C
#define OFFSET_AIR_JUMP_HEIGHT              0x50
#define OFFSET_GROUNDED_TIME_EXTENSION      0x54
#define OFFSET_JUMP_DIVE_VELOCITY_Y         0x58
#define OFFSET_ROLL_DURATION                0x5C
#define OFFSET_END_ROLL_AUTOMATICALLY       0x60
#define OFFSET_COLLIDER_HEIGHT              0x64
#define OFFSET_LOWER_IMPACT_MAX_HEIGHT      0x68
#define OFFSET_UPPER_IMPACT_MIN_HEIGHT      0x6C
#define OFFSET_FRONTAL_IMPACT_KNOCKBACK_DURATION 0x70
#define OFFSET_FRONTAL_IMPACT_KNOCKBACK_DISTANCE 0x74
#define OFFSET_FRONTAL_IMPACT_TIMEOUT       0x78
#define OFFSET_LOWER_IMPACT_HEIGHT_RATIO    0x7C
#define OFFSET_CORNER_IMPACT_REGION_DEPTH_MIN 0x80
#define OFFSET_CORNER_IMPACT_REGION_DEPTH_MAX 0x84
#define OFFSET_CORNER_IMPACT_REGION_WIDTH   0x88
#define OFFSET_SURFACE_MAX_UPWARDS_SPEED    0x8C
#define OFFSET_WALL_CLIMB_ENABLED           0x90
#define OFFSET_MAX_WALL_CLIMB_DISTANCE      0x94
#define OFFSET_WALL_CLIMB_FINISH_JUMP_HEIGHT 0x98
#define OFFSET_WALL_CLIMB_FINISH_JUMP_SPEED 0x9C
#define OFFSET_WALL_CLIMB_ACCELERATION      0xA0
#define OFFSET_WALL_CLIMB_TARGET_SPEED      0xA4
#define OFFSET_WALL_CLIMB_MAX_ZENITH_ANGLE  0xA8
#define OFFSET_SPEED_BOOST_MAX_SPEED        0xAC
#define OFFSET_SPEED_BOOST_DEACCELERATION_DELAY 0xB0

// RouteConfig Offsets
#define OFFSET_ROUTE_SEED                   0x20
#define OFFSET_ROUTE_FORCE_SEED             0x24

// ============================================================
// ===== 4. هيكل التخزين للقيم =====
// ============================================================
typedef struct {
    float jumpHeight;
    float airJumpHeight;
    float speed;
    float gravity;
    float rollDuration;
    float wallClimbSpeed;
    float diveVelocity;
    float surfaceMaxUpwardsSpeed;
    float speedBoostMax;
    bool godmode;
    bool noCoinPickup;
    bool wallClimbEnabled;
    bool stickToGround;
    int routeSeed;
    bool seedOverride;
} ModSettings;

static ModSettings g_settings = {
    .jumpHeight = 50.0f,
    .airJumpHeight = 50.0f,
    .speed = 200.0f,
    .gravity = -50.0f,
    .rollDuration = 0.1f,
    .wallClimbSpeed = 50.0f,
    .diveVelocity = -200.0f,
    .surfaceMaxUpwardsSpeed = 200.0f,
    .speedBoostMax = 300.0f,
    .godmode = true,
    .noCoinPickup = true,
    .wallClimbEnabled = true,
    .stickToGround = true,
    .routeSeed = 12345,
    .seedOverride = true
};

// ============================================================
// ===== 5. دوال تعديل الذاكرة =====
// ============================================================
static uintptr_t g_configAddress = 0;
static uintptr_t g_routeConfigAddress = 0;
static dispatch_once_t addressFindOnce;

void safe_write_float(mach_port_t task, uintptr_t addr, float value) {
    kern_return_t kr = vm_protect(task, (vm_address_t)addr, sizeof(float), 0, VM_PROT_READ | VM_PROT_WRITE);
    if (kr != KERN_SUCCESS) {
        NSLog(@"Failed to protect memory at 0x%llx: %d", addr, kr);
        return;
    }
    *(float *)addr = value;
    vm_protect(task, (vm_address_t)addr, sizeof(float), 0, VM_PROT_READ);
}

void safe_write_bool(mach_port_t task, uintptr_t addr, bool value) {
    kern_return_t kr = vm_protect(task, (vm_address_t)addr, sizeof(bool), 0, VM_PROT_READ | VM_PROT_WRITE);
    if (kr != KERN_SUCCESS) {
        NSLog(@"Failed to protect memory at 0x%llx: %d", addr, kr);
        return;
    }
    *(bool *)addr = value;
    vm_protect(task, (vm_address_t)addr, sizeof(bool), 0, VM_PROT_READ);
}

void safe_write_int(mach_port_t task, uintptr_t addr, int value) {
    kern_return_t kr = vm_protect(task, (vm_address_t)addr, sizeof(int), 0, VM_PROT_READ | VM_PROT_WRITE);
    if (kr != KERN_SUCCESS) {
        NSLog(@"Failed to protect memory at 0x%llx: %d", addr, kr);
        return;
    }
    *(int *)addr = value;
    vm_protect(task, (vm_address_t)addr, sizeof(int), 0, VM_PROT_READ);
}

void find_motor_config_address() {
    if (g_configAddress != 0) return;
    
    mach_port_t task = mach_task_self();
    float targetValue = 20.0f;
    vm_address_t startAddress = 0x100000000;
    vm_size_t searchSize = 0x20000000;
    
    for (vm_address_t addr = startAddress; addr < startAddress + searchSize; addr += 4) {
        float value = 0;
        kern_return_t kr = vm_read_overwrite(task, addr, sizeof(float), (vm_address_t)&value, NULL);
        if (kr != KERN_SUCCESS) continue;
        
        if (value == targetValue) {
            float gravity = 0;
            kr = vm_read_overwrite(task, addr - OFFSET_JUMP_HEIGHT + OFFSET_GRAVITY, sizeof(float), (vm_address_t)&gravity, NULL);
            if (kr == KERN_SUCCESS && (gravity == -200.0f || gravity == -150.0f)) {
                g_configAddress = addr - OFFSET_JUMP_HEIGHT;
                NSLog(@"MotorConfig found at: 0x%llx", g_configAddress);
                return;
            }
        }
    }
    NSLog(@"MotorConfig not found in memory range");
}

void find_route_config_address() {
    if (g_routeConfigAddress != 0) return;
    
    Class routeConfigClass = objc_getClass("SYBO.Subway.RouteConfig");
    if (!routeConfigClass) {
        NSLog(@"RouteConfig class not found");
        return;
    }
    
    if (!class_getInstanceVariable(routeConfigClass, "_forceSeed")) {
        NSLog(@"_forceSeed ivar not found");
        return;
    }
    
    SEL instanceSelector = @selector(instance);
    if (!class_getClassMethod(routeConfigClass, instanceSelector)) {
        NSLog(@"instance method not found");
        return;
    }
    
    id instance = [routeConfigClass performSelector:instanceSelector];
    if (instance) {
        g_routeConfigAddress = (uintptr_t)instance;
        NSLog(@"RouteConfig found at: 0x%llx", g_routeConfigAddress);
    }
}

void apply_modifications() {
    mach_port_t task = mach_task_self();
    find_motor_config_address();
    find_route_config_address();
    
    if (g_configAddress == 0) {
        NSLog(@"MotorConfig not found");
        return;
    }
    
    // ===== القسم 1: Godmode (تعطيل التصادمات) =====
    if (g_settings.godmode) {
        float zero = 0.0f;
        float huge = 1000.0f;
        float tiny = 0.01f;
        
        safe_write_float(task, g_configAddress + OFFSET_FRONTAL_IMPACT_KNOCKBACK_DURATION, zero);
        safe_write_float(task, g_configAddress + OFFSET_FRONTAL_IMPACT_KNOCKBACK_DISTANCE, zero);
        safe_write_float(task, g_configAddress + OFFSET_LOWER_IMPACT_MAX_HEIGHT, huge);
        safe_write_float(task, g_configAddress + OFFSET_UPPER_IMPACT_MIN_HEIGHT, -huge);
        safe_write_float(task, g_configAddress + OFFSET_FRONTAL_IMPACT_TIMEOUT, zero);
        safe_write_float(task, g_configAddress + OFFSET_COLLIDER_HEIGHT, tiny);
        safe_write_float(task, g_configAddress + OFFSET_LOWER_IMPACT_HEIGHT_RATIO, zero);
        safe_write_float(task, g_configAddress + OFFSET_CORNER_IMPACT_REGION_DEPTH_MIN, zero);
        safe_write_float(task, g_configAddress + OFFSET_CORNER_IMPACT_REGION_DEPTH_MAX, zero);
        safe_write_float(task, g_configAddress + OFFSET_CORNER_IMPACT_REGION_WIDTH, zero);
        
        NSLog(@"Godmode activated");
    }
    
    // ===== القسم 2: تعديل القفز =====
    safe_write_float(task, g_configAddress + OFFSET_JUMP_HEIGHT, g_settings.jumpHeight);
    safe_write_float(task, g_configAddress + OFFSET_AIR_JUMP_HEIGHT, g_settings.airJumpHeight);
    NSLog(@"Jump Height: %.2f", g_settings.jumpHeight);
    
    // ===== القسم 3: تعديل السرعة =====
    safe_write_float(task, g_configAddress + OFFSET_INITIAL_TARGET_SPEED, g_settings.speed);
    safe_write_float(task, g_configAddress + OFFSET_FINAL_TARGET_SPEED, g_settings.speed);
    NSLog(@"Speed: %.2f", g_settings.speed);
    
    // ===== القسم 4: تعديل الجاذبية =====
    safe_write_float(task, g_configAddress + OFFSET_GRAVITY, g_settings.gravity);
    NSLog(@"Gravity: %.2f", g_settings.gravity);
    
    // ===== القسم 5: تعديل الـ Roll =====
    safe_write_float(task, g_configAddress + OFFSET_ROLL_DURATION, g_settings.rollDuration);
    NSLog(@"Roll Duration: %.2f", g_settings.rollDuration);
    
    // ===== القسم 6: تعديل الـ Wall Climb =====
    safe_write_bool(task, g_configAddress + OFFSET_WALL_CLIMB_ENABLED, g_settings.wallClimbEnabled);
    safe_write_float(task, g_configAddress + OFFSET_WALL_CLIMB_TARGET_SPEED, g_settings.wallClimbSpeed);
    NSLog(@"Wall Climb: %d, Speed: %.2f", g_settings.wallClimbEnabled, g_settings.wallClimbSpeed);
    
    // ===== القسم 7: الالتصاق بالأرض =====
    safe_write_bool(task, g_configAddress + OFFSET_STICK_TO_GROUND, g_settings.stickToGround);
    NSLog(@"Stick to Ground: %d", g_settings.stickToGround);
    
    // ===== القسم 8: تعديل الـ Dive =====
    safe_write_float(task, g_configAddress + OFFSET_JUMP_DIVE_VELOCITY_Y, g_settings.diveVelocity);
    NSLog(@"Dive Velocity: %.2f", g_settings.diveVelocity);
    
    // ===== القسم 9: Surface Max Upwards Speed =====
    safe_write_float(task, g_configAddress + OFFSET_SURFACE_MAX_UPWARDS_SPEED, g_settings.surfaceMaxUpwardsSpeed);
    NSLog(@"Surface Max Upwards Speed: %.2f", g_settings.surfaceMaxUpwardsSpeed);
    
    // ===== القسم 10: Speed Boost =====
    safe_write_float(task, g_configAddress + OFFSET_SPEED_BOOST_MAX_SPEED, g_settings.speedBoostMax);
    NSLog(@"Speed Boost Max: %.2f", g_settings.speedBoostMax);
    
    // ===== القسم 11: Route Seed (Override) =====
    if (g_routeConfigAddress != 0 && g_settings.seedOverride) {
        safe_write_int(task, g_routeConfigAddress + OFFSET_ROUTE_SEED, g_settings.routeSeed);
        safe_write_int(task, g_routeConfigAddress + OFFSET_ROUTE_FORCE_SEED, 1);
        NSLog(@"Route Seed: %d", g_settings.routeSeed);
    }
}

// ============================================================
// ===== 6. واجهة المستخدم (مود منيو مقسم) =====
// ============================================================
static UIWindow *menuWindow;
static BOOL isMenuVisible = NO;
static UIScrollView *scrollView;
static UIView *contentView;
static NSMutableDictionary *inputFields;
static FrezonModViewController *gViewController;

@interface FrezonModViewController : UIViewController
@end

@implementation FrezonModViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor clearColor];
}

@end

void createMenuUI() {
    UIWindow *window = [UIApplication sharedApplication].keyWindow;
    if (!window) return;
    
    menuWindow = [[UIWindow alloc] initWithFrame:CGRectMake(20, 60, 340, 520)];
    menuWindow.backgroundColor = [UIColor colorWithWhite:0.05 alpha:0.97];
    menuWindow.layer.cornerRadius = 16;
    menuWindow.layer.borderColor = [UIColor colorWithWhite:0.3 alpha:1].CGColor;
    menuWindow.layer.borderWidth = 0.5;
    menuWindow.hidden = YES;
    menuWindow.windowLevel = UIWindowLevelAlert + 1;
    menuWindow.userInteractionEnabled = YES;
    
    gViewController = [[FrezonModViewController alloc] init];
    menuWindow.rootViewController = gViewController;
    
    // ===== الهيدر =====
    UIView *header = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 340, 50)];
    header.backgroundColor = [UIColor colorWithWhite:0.1 alpha:1];
    [menuWindow addSubview:header];
    
    UILabel *title = [[UILabel alloc] initWithFrame:CGRectMake(10, 10, 200, 30)];
    title.text = @"Frezon Mod v0.2";
    title.font = [UIFont boldSystemFontOfSize:18];
    title.textColor = [UIColor whiteColor];
    [header addSubview:title];
    
    UIButton *closeBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    closeBtn.frame = CGRectMake(300, 10, 30, 30);
    [closeBtn setTitle:@"X" forState:UIControlStateNormal];
    [closeBtn setTitleColor:[UIColor grayColor] forState:UIControlStateNormal];
    [closeBtn addTarget:gViewController action:@selector(closeMenu) forControlEvents:UIControlEventTouchUpInside];
    [header addSubview:closeBtn];
    
    // ===== ScrollView =====
    scrollView = [[UIScrollView alloc] initWithFrame:CGRectMake(0, 50, 340, 470)];
    scrollView.backgroundColor = [UIColor clearColor];
    scrollView.showsVerticalScrollIndicator = YES;
    scrollView.userInteractionEnabled = YES;
    scrollView.scrollEnabled = YES;
    scrollView.bounces = YES;
    [menuWindow addSubview:scrollView];
    
    contentView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 340, 10)];
    contentView.backgroundColor = [UIColor clearColor];
    contentView.userInteractionEnabled = YES;
    [scrollView addSubview:contentView];
    
    inputFields = [NSMutableDictionary dictionary];
    
    CGFloat yOffset = 10;
    
    yOffset = addSectionHeader(contentView, yOffset, @"Godmode");
    yOffset = addToggleWithLabel(contentView, yOffset, @"Godmode", g_settings.godmode, @"godmode_toggle");
    yOffset = addSeparator(contentView, yOffset);
    
    yOffset = addSectionHeader(contentView, yOffset, @"Player Physics");
    yOffset = addFloatField(contentView, yOffset, @"Jump Height", g_settings.jumpHeight, @"jump_height");
    yOffset = addFloatField(contentView, yOffset, @"Air Jump Height", g_settings.airJumpHeight, @"air_jump");
    yOffset = addFloatField(contentView, yOffset, @"Speed", g_settings.speed, @"speed");
    yOffset = addFloatField(contentView, yOffset, @"Gravity", g_settings.gravity, @"gravity");
    yOffset = addFloatField(contentView, yOffset, @"Roll Duration", g_settings.rollDuration, @"roll_duration");
    yOffset = addFloatField(contentView, yOffset, @"Dive Velocity", g_settings.diveVelocity, @"dive_velocity");
    yOffset = addFloatField(contentView, yOffset, @"Surface Max Upwards Speed", g_settings.surfaceMaxUpwardsSpeed, @"surface_speed");
    yOffset = addToggleWithLabel(contentView, yOffset, @"Stick to Ground", g_settings.stickToGround, @"stick_toggle");
    yOffset = addSeparator(contentView, yOffset);
    
    yOffset = addSectionHeader(contentView, yOffset, @"Wall Climb");
    yOffset = addToggleWithLabel(contentView, yOffset, @"Wall Climb Enabled", g_settings.wallClimbEnabled, @"wall_toggle");
    yOffset = addFloatField(contentView, yOffset, @"Wall Climb Speed", g_settings.wallClimbSpeed, @"wall_speed");
    yOffset = addSeparator(contentView, yOffset);
    
    yOffset = addSectionHeader(contentView, yOffset, @"Speed Boost");
    yOffset = addFloatField(contentView, yOffset, @"Speed Boost Max", g_settings.speedBoostMax, @"boost_max");
    yOffset = addSeparator(contentView, yOffset);
    
    yOffset = addSectionHeader(contentView, yOffset, @"Route Seed Override");
    yOffset = addToggleWithLabel(contentView, yOffset, @"Seed Override", g_settings.seedOverride, @"seed_toggle");
    yOffset = addIntField(contentView, yOffset, @"Route Seed", g_settings.routeSeed, @"route_seed");
    yOffset = addSeparator(contentView, yOffset);
    
    yOffset = addSectionHeader(contentView, yOffset, @"Coin Pickup");
    yOffset = addToggleWithLabel(contentView, yOffset, @"No Coin Pickup", g_settings.noCoinPickup, @"coin_toggle");
    yOffset = addSeparator(contentView, yOffset);
    
    // ===== زر تطبيق الكل =====
    UIButton *applyBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    applyBtn.frame = CGRectMake(20, yOffset + 10, 300, 44);
    applyBtn.backgroundColor = [UIColor colorWithWhite:0.2 alpha:1];
    applyBtn.layer.cornerRadius = 10;
    [applyBtn setTitle:@"Apply All Settings" forState:UIControlStateNormal];
    [applyBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    applyBtn.titleLabel.font = [UIFont boldSystemFontOfSize:16];
    [applyBtn addTarget:gViewController action:@selector(applyAllSettings) forControlEvents:UIControlEventTouchUpInside];
    [contentView addSubview:applyBtn];
    yOffset += 60;
    
    CGRect frame = contentView.frame;
    frame.size.height = yOffset + 20;
    contentView.frame = frame;
    scrollView.contentSize = CGSizeMake(340, frame.size.height);
    
    [menuWindow makeKeyAndVisible];
}

// ===== دوال مساعدة لبناء UI =====
CGFloat addSectionHeader(UIView *parent, CGFloat y, NSString *title) {
    UILabel *label = [[UILabel alloc] initWithFrame:CGRectMake(15, y, 300, 30)];
    label.text = title;
    label.font = [UIFont boldSystemFontOfSize:16];
    label.textColor = [UIColor colorWithWhite:0.7 alpha:1];
    label.backgroundColor = [UIColor colorWithWhite:0.1 alpha:1];
    label.layer.cornerRadius = 4;
    label.clipsToBounds = YES;
    label.textAlignment = NSTextAlignmentCenter;
    [parent addSubview:label];
    return y + 35;
}

CGFloat addSeparator(UIView *parent, CGFloat y) {
    UIView *line = [[UIView alloc] initWithFrame:CGRectMake(10, y, 320, 1)];
    line.backgroundColor = [UIColor colorWithWhite:0.2 alpha:1];
    [parent addSubview:line];
    return y + 10;
}

CGFloat addFloatField(UIView *parent, CGFloat y, NSString *label, float value, NSString *key) {
    UIView *container = [[UIView alloc] initWithFrame:CGRectMake(10, y, 320, 40)];
    container.backgroundColor = [UIColor colorWithWhite:0.1 alpha:0.8];
    container.layer.cornerRadius = 6;
    [parent addSubview:container];
    
    UILabel *nameLabel = [[UILabel alloc] initWithFrame:CGRectMake(10, 5, 140, 30)];
    nameLabel.text = label;
    nameLabel.font = [UIFont systemFontOfSize:13];
    nameLabel.textColor = [UIColor colorWithWhite:0.8 alpha:1];
    [container addSubview:nameLabel];
    
    UITextField *field = [[UITextField alloc] initWithFrame:CGRectMake(155, 5, 100, 30)];
    field.text = [NSString stringWithFormat:@"%.2f", value];
    field.textColor = [UIColor whiteColor];
    field.backgroundColor = [UIColor colorWithWhite:0.2 alpha:0.8];
    field.layer.cornerRadius = 4;
    field.font = [UIFont systemFontOfSize:13];
    field.keyboardType = UIKeyboardTypeDecimalPad;
    field.textAlignment = NSTextAlignmentCenter;
    field.tag = 100;
    [container addSubview:field];
    
    UIButton *setBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    setBtn.frame = CGRectMake(260, 5, 50, 30);
    setBtn.backgroundColor = [UIColor colorWithWhite:0.3 alpha:1];
    setBtn.layer.cornerRadius = 4;
    [setBtn setTitle:@"Set" forState:UIControlStateNormal];
    [setBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    setBtn.titleLabel.font = [UIFont boldSystemFontOfSize:12];
    [setBtn addTarget:gViewController action:@selector(setFloatValue:) forControlEvents:UIControlEventTouchUpInside];
    [container addSubview:setBtn];
    
    inputFields[key] = @{@"field": field, @"container": container};
    return y + 45;
}

CGFloat addIntField(UIView *parent, CGFloat y, NSString *label, int value, NSString *key) {
    UIView *container = [[UIView alloc] initWithFrame:CGRectMake(10, y, 320, 40)];
    container.backgroundColor = [UIColor colorWithWhite:0.1 alpha:0.8];
    container.layer.cornerRadius = 6;
    [parent addSubview:container];
    
    UILabel *nameLabel = [[UILabel alloc] initWithFrame:CGRectMake(10, 5, 140, 30)];
    nameLabel.text = label;
    nameLabel.font = [UIFont systemFontOfSize:13];
    nameLabel.textColor = [UIColor colorWithWhite:0.8 alpha:1];
    [container addSubview:nameLabel];
    
    UITextField *field = [[UITextField alloc] initWithFrame:CGRectMake(155, 5, 100, 30)];
    field.text = [NSString stringWithFormat:@"%d", value];
    field.textColor = [UIColor whiteColor];
    field.backgroundColor = [UIColor colorWithWhite:0.2 alpha:0.8];
    field.layer.cornerRadius = 4;
    field.font = [UIFont systemFontOfSize:13];
    field.keyboardType = UIKeyboardTypeNumberPad;
    field.textAlignment = NSTextAlignmentCenter;
    field.tag = 101;
    [container addSubview:field];
    
    UIButton *setBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    setBtn.frame = CGRectMake(260, 5, 50, 30);
    setBtn.backgroundColor = [UIColor colorWithWhite:0.3 alpha:1];
    setBtn.layer.cornerRadius = 4;
    [setBtn setTitle:@"Set" forState:UIControlStateNormal];
    [setBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    setBtn.titleLabel.font = [UIFont boldSystemFontOfSize:12];
    [setBtn addTarget:gViewController action:@selector(setIntValue:) forControlEvents:UIControlEventTouchUpInside];
    [container addSubview:setBtn];
    
    inputFields[key] = @{@"field": field, @"container": container};
    return y + 45;
}

CGFloat addToggleWithLabel(UIView *parent, CGFloat y, NSString *label, BOOL value, NSString *key) {
    UIView *container = [[UIView alloc] initWithFrame:CGRectMake(10, y, 320, 40)];
    container.backgroundColor = [UIColor colorWithWhite:0.1 alpha:0.8];
    container.layer.cornerRadius = 6;
    [parent addSubview:container];
    
    UILabel *nameLabel = [[UILabel alloc] initWithFrame:CGRectMake(10, 5, 220, 30)];
    nameLabel.text = label;
    nameLabel.font = [UIFont systemFontOfSize:13];
    nameLabel.textColor = [UIColor colorWithWhite:0.8 alpha:1];
    [container addSubview:nameLabel];
    
    UISwitch *toggle = [[UISwitch alloc] initWithFrame:CGRectMake(250, 5, 50, 30)];
    toggle.on = value;
    toggle.onTintColor = [UIColor whiteColor];
    toggle.tintColor = [UIColor colorWithWhite:0.3 alpha:1];
    toggle.thumbTintColor = [UIColor colorWithWhite:0.1 alpha:1];
    toggle.tag = 200;
    [toggle addTarget:gViewController action:@selector(toggleChanged:) forControlEvents:UIControlEventValueChanged];
    [container addSubview:toggle];
    
    inputFields[key] = @{@"toggle": toggle, @"container": container};
    return y + 45;
}

// ===== دوال الأزرار =====
void toggleMenu() {
    if (!menuWindow) {
        createMenuUI();
    }
    isMenuVisible = !isMenuVisible;
    menuWindow.hidden = !isMenuVisible;
    if (!menuWindow.hidden) {
        [menuWindow makeKeyAndVisible];
    }
}

@interface FrezonModViewController (Actions)
- (void)toggleMenu;
- (void)closeMenu;
- (void)setFloatValue:(id)sender;
- (void)setIntValue:(id)sender;
- (void)toggleChanged:(UISwitch *)sender;
- (void)applyAllSettings;
- (void)showFeedback:(NSString *)message;
@end

@implementation FrezonModViewController (Actions)

- (void)toggleMenu {
    ::toggleMenu();
}

- (void)closeMenu {
    isMenuVisible = NO;
    menuWindow.hidden = YES;
}

- (void)setFloatValue:(id)sender {
    UIButton *btn = (UIButton *)sender;
    UIView *container = btn.superview;
    UITextField *field = nil;
    for (UIView *subview in container.subviews) {
        if ([subview isKindOfClass:[UITextField class]]) {
            field = (UITextField *)subview;
            break;
        }
    }
    if (!field) return;
    
    float value = [field.text floatValue];
    NSString *key = nil;
    for (NSString *k in inputFields.allKeys) {
        NSDictionary *data = inputFields[k];
        if ([data[@"field"] isEqual:field]) {
            key = k;
            break;
        }
    }
    if (!key) return;
    
    // تحديث الإعدادات
    if ([key isEqualToString:@"jump_height"]) g_settings.jumpHeight = value;
    else if ([key isEqualToString:@"air_jump"]) g_settings.airJumpHeight = value;
    else if ([key isEqualToString:@"speed"]) g_settings.speed = value;
    else if ([key isEqualToString:@"gravity"]) g_settings.gravity = value;
    else if ([key isEqualToString:@"roll_duration"]) g_settings.rollDuration = value;
    else if ([key isEqualToString:@"dive_velocity"]) g_settings.diveVelocity = value;
    else if ([key isEqualToString:@"surface_speed"]) g_settings.surfaceMaxUpwardsSpeed = value;
    else if ([key isEqualToString:@"wall_speed"]) g_settings.wallClimbSpeed = value;
    else if ([key isEqualToString:@"boost_max"]) g_settings.speedBoostMax = value;
    
    [self showFeedback:[NSString stringWithFormat:@"Set to %.2f", value]];
}

- (void)setIntValue:(id)sender {
    UIButton *btn = (UIButton *)sender;
    UIView *container = btn.superview;
    UITextField *field = nil;
    for (UIView *subview in container.subviews) {
        if ([subview isKindOfClass:[UITextField class]]) {
            field = (UITextField *)subview;
            break;
        }
    }
    if (!field) return;
    
    int value = [field.text intValue];
    NSString *key = nil;
    for (NSString *k in inputFields.allKeys) {
        NSDictionary *data = inputFields[k];
        if ([data[@"field"] isEqual:field]) {
            key = k;
            break;
        }
    }
    if (!key) return;
    
    if ([key isEqualToString:@"route_seed"]) {
        g_settings.routeSeed = value;
        [self showFeedback:[NSString stringWithFormat:@"Seed set to %d", value]];
    }
}

- (void)toggleChanged:(UISwitch *)sender {
    NSString *key = nil;
    for (NSString *k in inputFields.allKeys) {
        NSDictionary *data = inputFields[k];
        if ([data[@"toggle"] isEqual:sender]) {
            key = k;
            break;
        }
    }
    if (!key) return;
    
    BOOL value = sender.isOn;
    
    if ([key isEqualToString:@"godmode_toggle"]) g_settings.godmode = value;
    else if ([key isEqualToString:@"stick_toggle"]) g_settings.stickToGround = value;
    else if ([key isEqualToString:@"wall_toggle"]) g_settings.wallClimbEnabled = value;
    else if ([key isEqualToString:@"seed_toggle"]) g_settings.seedOverride = value;
    else if ([key isEqualToString:@"coin_toggle"]) g_settings.noCoinPickup = value;
    
    [self showFeedback:value ? @"Enabled" : @"Disabled"];
}

- (void)applyAllSettings {
    NSLog(@"Applying all settings...");
    apply_modifications();
    [self showFeedback:@"All settings applied!"];
}

- (void)showFeedback:(NSString *)message {
    dispatch_async(dispatch_get_main_queue(), ^{
        UIWindow *window = menuWindow;
        if (!window) return;
        
        UILabel *feedback = [[UILabel alloc] initWithFrame:CGRectMake(10, 480, 320, 20)];
        feedback.text = message;
        feedback.font = [UIFont systemFontOfSize:12];
        feedback.textColor = [UIColor colorWithWhite:0.6 alpha:1];
        feedback.textAlignment = NSTextAlignmentCenter;
        feedback.tag = 999;
        
        for (UIView *view in window.subviews) {
            if (view.tag == 999) [view removeFromSuperview];
        }
        
        [window addSubview:feedback];
        
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 2.5 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
            [feedback removeFromSuperview];
        });
    });
}

@end

// ============================================================
// ===== 7. نقطة الدخول =====
// ============================================================
__attribute__((constructor))
static void frezonmod_entry() {
    dispatch_async(dispatch_get_main_queue(), ^{
        UIWindow *window = [UIApplication sharedApplication].keyWindow;
        if (!window) return;
        
        // تحميل UnityFramework
        loadUnityFramework();
        init_il2cpp_functions();
        
        // زر المنيو
        UIButton *menuBtn = [UIButton buttonWithType:UIButtonTypeCustom];
        menuBtn.frame = CGRectMake(20, 100, 60, 60);
        menuBtn.layer.cornerRadius = 30;
        menuBtn.backgroundColor = [UIColor blackColor];
        menuBtn.layer.borderColor = [UIColor whiteColor].CGColor;
        menuBtn.layer.borderWidth = 1.5;
        [menuBtn setTitle:@"F" forState:UIControlStateNormal];
        [menuBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        menuBtn.titleLabel.font = [UIFont boldSystemFontOfSize:24];
        [menuBtn addTarget:gViewController action:@selector(toggleMenu) forControlEvents:UIControlEventTouchUpInside];
        [window addSubview:menuBtn];
        
        // البحث عن العناوين
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 3 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
            find_motor_config_address();
            find_route_config_address();
            apply_modifications();
        });
    });
}
