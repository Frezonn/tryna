#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#import <objc/runtime.h>
#import <dlfcn.h>
#import <mach/mach.h>

// ============================================================
// ===== 1. تحميل UnityFramework =====
// ============================================================
static void *unityFrameworkHandle = NULL;

void loadUnityFramework() {
    const char *paths[] = {
        "Subwaysurf.app/Frameworks/UnityFramework.framework/UnityFramework",
        "Frameworks/UnityFramework.framework/UnityFramework",
        "/System/Library/Frameworks/UnityFramework.framework/UnityFramework",
        "UnityFramework"
    };
    
    for (int i = 0; i < 4; i++) {
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
        NSLog(@"Failed to load UnityFramework");
    }
}

// ============================================================
// ===== 2. IL2CPP دوال البحث =====
// ============================================================
typedef void *(*il2cpp_class_from_name_t)(void *image, const char *namespaze, const char *name);
typedef void *(*il2cpp_assembly_get_image_t)(void *assembly);
typedef void *(*il2cpp_domain_get_assemblies_t)(void *domain, size_t *size);

static il2cpp_class_from_name_t il2cpp_class_from_name = NULL;
static il2cpp_assembly_get_image_t il2cpp_assembly_get_image = NULL;
static il2cpp_domain_get_assemblies_t il2cpp_domain_get_assemblies = NULL;

void init_il2cpp_functions() {
    if (!unityFrameworkHandle) return;
    
    il2cpp_class_from_name = (il2cpp_class_from_name_t)dlsym(unityFrameworkHandle, "il2cpp_class_from_name");
    il2cpp_assembly_get_image = (il2cpp_assembly_get_image_t)dlsym(unityFrameworkHandle, "il2cpp_assembly_get_image");
    il2cpp_domain_get_assemblies = (il2cpp_domain_get_assemblies_t)dlsym(unityFrameworkHandle, "il2cpp_domain_get_assemblies");
}

void *find_class_in_il2cpp(const char *namespaze, const char *name) {
    if (!il2cpp_class_from_name) return NULL;
    
    size_t assembly_count = 0;
    void *domain = NULL;
    void *assemblies = il2cpp_domain_get_assemblies(domain, &assembly_count);
    
    if (!assemblies) return NULL;
    
    // في IL2CPP، assemblies هو مصفوفة من المؤشرات
    void **assemblyArray = (void **)assemblies;
    for (size_t i = 0; i < assembly_count; i++) {
        void *image = il2cpp_assembly_get_image(assemblyArray[i]);
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
#define OFFSET_INITIAL_TARGET_SPEED         0x24
#define OFFSET_FINAL_TARGET_SPEED           0x28
#define OFFSET_JUMP_HEIGHT                  0x4C
#define OFFSET_AIR_JUMP_HEIGHT              0x50
#define OFFSET_ROLL_DURATION                0x5C
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
#define OFFSET_WALL_CLIMB_TARGET_SPEED      0xA4
#define OFFSET_SPEED_BOOST_MAX_SPEED        0xAC

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
uintptr_t g_configAddress = 0;
uintptr_t g_routeConfigAddress = 0;

void find_motor_config_address() {
    if (g_configAddress != 0) return;
    
    mach_port_t task = mach_task_self();
    float targetValue = 20.0f;
    vm_address_t startAddress = 0x100000000;
    vm_size_t searchSize = 0x20000000;
    
    for (vm_address_t addr = startAddress; addr < startAddress + searchSize; addr += 4) {
        float value = 0;
        vm_read_overwrite(task, addr, sizeof(float), (vm_address_t)&value, NULL);
        if (value == targetValue) {
            float gravity = 0;
            vm_read_overwrite(task, addr - OFFSET_JUMP_HEIGHT + OFFSET_GRAVITY, sizeof(float), (vm_address_t)&gravity, NULL);
            if (gravity == -200.0f || gravity == -150.0f) {
                g_configAddress = addr - OFFSET_JUMP_HEIGHT;
                NSLog(@"MotorConfig found at: 0x%lx", (unsigned long)g_configAddress);
                return;
            }
        }
    }
}

void find_route_config_address() {
    if (g_routeConfigAddress != 0) return;
    
    Class routeConfigClass = objc_getClass("SYBO.Subway.RouteConfig");
    if (routeConfigClass) {
        Ivar seedIvar = class_getInstanceVariable(routeConfigClass, "_forceSeed");
        if (seedIvar) {
            id instance = [routeConfigClass performSelector:@selector(instance)];
            if (instance) {
                g_routeConfigAddress = (uintptr_t)instance;
                NSLog(@"RouteConfig found at: 0x%lx", (unsigned long)g_routeConfigAddress);
                return;
            }
        }
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
    
    // Godmode
    if (g_settings.godmode) {
        float zero = 0.0f;
        float huge = 1000.0f;
        float tiny = 0.01f;
        
        uintptr_t addrs[] = {
            g_configAddress + OFFSET_FRONTAL_IMPACT_KNOCKBACK_DURATION,
            g_configAddress + OFFSET_FRONTAL_IMPACT_KNOCKBACK_DISTANCE,
            g_configAddress + OFFSET_LOWER_IMPACT_MAX_HEIGHT,
            g_configAddress + OFFSET_UPPER_IMPACT_MIN_HEIGHT,
            g_configAddress + OFFSET_FRONTAL_IMPACT_TIMEOUT,
            g_configAddress + OFFSET_LOWER_IMPACT_HEIGHT_RATIO,
            g_configAddress + OFFSET_CORNER_IMPACT_REGION_DEPTH_MIN,
            g_configAddress + OFFSET_CORNER_IMPACT_REGION_DEPTH_MAX,
            g_configAddress + OFFSET_CORNER_IMPACT_REGION_WIDTH
        };
        
        float values[] = {zero, zero, huge, -huge, zero, zero, zero, zero, zero};
        
        for (int i = 0; i < 9; i++) {
            vm_protect(task, (vm_address_t)addrs[i], sizeof(float), 0, VM_PROT_READ | VM_PROT_WRITE);
            *(float *)addrs[i] = values[i];
        }
        
        uintptr_t colliderAddr = g_configAddress + OFFSET_COLLIDER_HEIGHT;
        vm_protect(task, (vm_address_t)colliderAddr, sizeof(float), 0, VM_PROT_READ | VM_PROT_WRITE);
        *(float *)colliderAddr = tiny;
        
        NSLog(@"Godmode activated");
    }
    
    // Jump Height
    uintptr_t jumpAddr = g_configAddress + OFFSET_JUMP_HEIGHT;
    uintptr_t airJumpAddr = g_configAddress + OFFSET_AIR_JUMP_HEIGHT;
    vm_protect(task, (vm_address_t)jumpAddr, sizeof(float), 0, VM_PROT_READ | VM_PROT_WRITE);
    vm_protect(task, (vm_address_t)airJumpAddr, sizeof(float), 0, VM_PROT_READ | VM_PROT_WRITE);
    *(float *)jumpAddr = g_settings.jumpHeight;
    *(float *)airJumpAddr = g_settings.airJumpHeight;
    
    // Speed
    uintptr_t initSpeed = g_configAddress + OFFSET_INITIAL_TARGET_SPEED;
    uintptr_t finalSpeed = g_configAddress + OFFSET_FINAL_TARGET_SPEED;
    vm_protect(task, (vm_address_t)initSpeed, sizeof(float), 0, VM_PROT_READ | VM_PROT_WRITE);
    vm_protect(task, (vm_address_t)finalSpeed, sizeof(float), 0, VM_PROT_READ | VM_PROT_WRITE);
    *(float *)initSpeed = g_settings.speed;
    *(float *)finalSpeed = g_settings.speed;
    
    // Gravity
    uintptr_t gravityAddr = g_configAddress + OFFSET_GRAVITY;
    vm_protect(task, (vm_address_t)gravityAddr, sizeof(float), 0, VM_PROT_READ | VM_PROT_WRITE);
    *(float *)gravityAddr = g_settings.gravity;
    
    // Roll Duration
    uintptr_t rollAddr = g_configAddress + OFFSET_ROLL_DURATION;
    vm_protect(task, (vm_address_t)rollAddr, sizeof(float), 0, VM_PROT_READ | VM_PROT_WRITE);
    *(float *)rollAddr = g_settings.rollDuration;
    
    // Wall Climb
    uintptr_t wallClimbAddr = g_configAddress + OFFSET_WALL_CLIMB_ENABLED;
    vm_protect(task, (vm_address_t)wallClimbAddr, sizeof(bool), 0, VM_PROT_READ | VM_PROT_WRITE);
    *(bool *)wallClimbAddr = g_settings.wallClimbEnabled;
    
    uintptr_t wallSpeedAddr = g_configAddress + OFFSET_WALL_CLIMB_TARGET_SPEED;
    vm_protect(task, (vm_address_t)wallSpeedAddr, sizeof(float), 0, VM_PROT_READ | VM_PROT_WRITE);
    *(float *)wallSpeedAddr = g_settings.wallClimbSpeed;
    
    // Stick to Ground
    uintptr_t stickAddr = g_configAddress + OFFSET_STICK_TO_GROUND;
    vm_protect(task, (vm_address_t)stickAddr, sizeof(bool), 0, VM_PROT_READ | VM_PROT_WRITE);
    *(bool *)stickAddr = g_settings.stickToGround;
    
    // Dive Velocity
    uintptr_t diveAddr = g_configAddress + OFFSET_JUMP_DIVE_VELOCITY_Y;
    vm_protect(task, (vm_address_t)diveAddr, sizeof(float), 0, VM_PROT_READ | VM_PROT_WRITE);
    *(float *)diveAddr = g_settings.diveVelocity;
    
    // Surface Max Upwards Speed
    uintptr_t surfaceAddr = g_configAddress + OFFSET_SURFACE_MAX_UPWARDS_SPEED;
    vm_protect(task, (vm_address_t)surfaceAddr, sizeof(float), 0, VM_PROT_READ | VM_PROT_WRITE);
    *(float *)surfaceAddr = g_settings.surfaceMaxUpwardsSpeed;
    
    // Speed Boost
    uintptr_t boostAddr = g_configAddress + OFFSET_SPEED_BOOST_MAX_SPEED;
    vm_protect(task, (vm_address_t)boostAddr, sizeof(float), 0, VM_PROT_READ | VM_PROT_WRITE);
    *(float *)boostAddr = g_settings.speedBoostMax;
    
    // Route Seed
    if (g_routeConfigAddress != 0 && g_settings.seedOverride) {
        uintptr_t seedAddr = g_routeConfigAddress + OFFSET_ROUTE_SEED;
        uintptr_t forceSeedAddr = g_routeConfigAddress + OFFSET_ROUTE_FORCE_SEED;
        vm_protect(task, (vm_address_t)seedAddr, sizeof(int), 0, VM_PROT_READ | VM_PROT_WRITE);
        vm_protect(task, (vm_address_t)forceSeedAddr, sizeof(int), 0, VM_PROT_READ | VM_PROT_WRITE);
        *(int *)seedAddr = g_settings.routeSeed;
        *(int *)forceSeedAddr = 1;
    }
    
    NSLog(@"All settings applied!");
}

// ============================================================
// ===== 6. واجهة المستخدم =====
// ============================================================
static UIWindow *menuWindow;
static BOOL isMenuVisible = NO;

// دوال UI
CGFloat addSectionHeader(UIView *parent, CGFloat y, NSString *title);
CGFloat addSeparator(UIView *parent, CGFloat y);
CGFloat addFloatField(UIView *parent, CGFloat y, NSString *label, float value, NSString *key);
CGFloat addIntField(UIView *parent, CGFloat y, NSString *label, int value, NSString *key);
CGFloat addToggleWithLabel(UIView *parent, CGFloat y, NSString *label, BOOL value, NSString *key);
void setFloatValue(id sender);
void setIntValue(id sender);
void toggleChanged(UISwitch *sender);
void applyAllSettings();
void showFeedback(NSString *message);

// تنفيذ دوال UI
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
    [setBtn addTarget:self action:@selector(setFloatValue:) forControlEvents:UIControlEventTouchUpInside];
    [container addSubview:setBtn];
    
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
    [setBtn addTarget:self action:@selector(setIntValue:) forControlEvents:UIControlEventTouchUpInside];
    [container addSubview:setBtn];
    
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
    [toggle addTarget:self action:@selector(toggleChanged:) forControlEvents:UIControlEventValueChanged];
    [container addSubview:toggle];
    
    return y + 45;
}

void setFloatValue(id sender) {
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
    
    // تحديث الإعدادات حسب الـ label
    UILabel *label = nil;
    for (UIView *subview in container.subviews) {
        if ([subview isKindOfClass:[UILabel class]]) {
            label = (UILabel *)subview;
            break;
        }
    }
    
    NSString *labelText = label ? label.text : @"";
    if ([labelText containsString:@"Jump"]) {
        g_settings.jumpHeight = value;
    } else if ([labelText containsString:@"Air"]) {
        g_settings.airJumpHeight = value;
    } else if ([labelText containsString:@"Speed"]) {
        g_settings.speed = value;
    } else if ([labelText containsString:@"Gravity"]) {
        g_settings.gravity = value;
    } else if ([labelText containsString:@"Roll"]) {
        g_settings.rollDuration = value;
    } else if ([labelText containsString:@"Dive"]) {
        g_settings.diveVelocity = value;
    } else if ([labelText containsString:@"Surface"]) {
        g_settings.surfaceMaxUpwardsSpeed = value;
    } else if ([labelText containsString:@"Wall"]) {
        g_settings.wallClimbSpeed = value;
    } else if ([labelText containsString:@"Boost"]) {
        g_settings.speedBoostMax = value;
    }
    
    showFeedback([NSString stringWithFormat:@"Set to %.2f", value]);
}

void setIntValue(id sender) {
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
    g_settings.routeSeed = value;
    showFeedback([NSString stringWithFormat:@"Seed set to %d", value]);
}

void toggleChanged(UISwitch *sender) {
    UIView *container = sender.superview;
    UILabel *label = nil;
    for (UIView *subview in container.subviews) {
        if ([subview isKindOfClass:[UILabel class]]) {
            label = (UILabel *)subview;
            break;
        }
    }
    
    NSString *labelText = label ? label.text : @"";
    BOOL value = sender.isOn;
    
    if ([labelText containsString:@"Godmode"]) g_settings.godmode = value;
    else if ([labelText containsString:@"Stick"]) g_settings.stickToGround = value;
    else if ([labelText containsString:@"Wall Climb Enabled"]) g_settings.wallClimbEnabled = value;
    else if ([labelText containsString:@"Seed Override"]) g_settings.seedOverride = value;
    else if ([labelText containsString:@"No Coin"]) g_settings.noCoinPickup = value;
    
    showFeedback(value ? @"Enabled" : @"Disabled");
}

void applyAllSettings() {
    apply_modifications();
    showFeedback(@"All settings applied!");
}

void showFeedback(NSString *message) {
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

// ============================================================
// ===== 7. بناء واجهة المنيو =====
// ============================================================
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
    
    // ===== الهيدر =====
    UIView *header = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 340, 50)];
    header.backgroundColor = [UIColor colorWithWhite:0.1 alpha:1];
    [menuWindow addSubview:header];
    
    UILabel *title = [[UILabel alloc] initWithFrame:CGRectMake(10, 10, 200, 30)];
    title.text = @"Frezon Mod v0.1";
    title.font = [UIFont boldSystemFontOfSize:18];
    title.textColor = [UIColor whiteColor];
    [header addSubview:title];
    
    UIButton *closeBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    closeBtn.frame = CGRectMake(300, 10, 30, 30);
    [closeBtn setTitle:@"X" forState:UIControlStateNormal];
    [closeBtn setTitleColor:[UIColor grayColor] forState:UIControlStateNormal];
    [closeBtn addTarget:self action:@selector(closeMenu) forControlEvents:UIControlEventTouchUpInside];
    [header addSubview:closeBtn];
    
    // ===== ScrollView =====
    UIScrollView *scrollView = [[UIScrollView alloc] initWithFrame:CGRectMake(0, 50, 340, 470)];
    scrollView.backgroundColor = [UIColor clearColor];
    scrollView.showsVerticalScrollIndicator = YES;
    scrollView.userInteractionEnabled = YES;
    scrollView.scrollEnabled = YES;
    scrollView.bounces = YES;
    [menuWindow addSubview:scrollView];
    
    UIView *contentView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 340, 10)];
    contentView.backgroundColor = [UIColor clearColor];
    contentView.userInteractionEnabled = YES;
    [scrollView addSubview:contentView];
    
    CGFloat yOffset = 10;
    
    // ===== Godmode =====
    yOffset = addSectionHeader(contentView, yOffset, @"Godmode");
    yOffset = addToggleWithLabel(contentView, yOffset, @"Godmode", g_settings.godmode, @"godmode_toggle");
    yOffset = addSeparator(contentView, yOffset);
    
    // ===== Player Physics =====
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
    
    // ===== Wall Climb =====
    yOffset = addSectionHeader(contentView, yOffset, @"Wall Climb");
    yOffset = addToggleWithLabel(contentView, yOffset, @"Wall Climb Enabled", g_settings.wallClimbEnabled, @"wall_toggle");
    yOffset = addFloatField(contentView, yOffset, @"Wall Climb Speed", g_settings.wallClimbSpeed, @"wall_speed");
    yOffset = addSeparator(contentView, yOffset);
    
    // ===== Speed Boost =====
    yOffset = addSectionHeader(contentView, yOffset, @"Speed Boost");
    yOffset = addFloatField(contentView, yOffset, @"Speed Boost Max", g_settings.speedBoostMax, @"boost_max");
    yOffset = addSeparator(contentView, yOffset);
    
    // ===== Route Seed =====
    yOffset = addSectionHeader(contentView, yOffset, @"Route Seed Override");
    yOffset = addToggleWithLabel(contentView, yOffset, @"Seed Override", g_settings.seedOverride, @"seed_toggle");
    yOffset = addIntField(contentView, yOffset, @"Route Seed", g_settings.routeSeed, @"route_seed");
    yOffset = addSeparator(contentView, yOffset);
    
    // ===== Coin Pickup =====
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
    [applyBtn addTarget:self action:@selector(applyAllSettings) forControlEvents:UIControlEventTouchUpInside];
    [contentView addSubview:applyBtn];
    yOffset += 60;
    
    // تحديث حجم المحتوى
    CGRect frame = contentView.frame;
    frame.size.height = yOffset + 20;
    contentView.frame = frame;
    scrollView.contentSize = CGSizeMake(340, frame.size.height);
    
    [menuWindow makeKeyAndVisible];
}

// ============================================================
// ===== 8. دوال التحكم =====
// ============================================================
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

void closeMenu() {
    isMenuVisible = NO;
    menuWindow.hidden = YES;
}

// ============================================================
// ===== 9. نقطة الدخول =====
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
