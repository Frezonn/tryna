#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#import <objc/runtime.h>
#import <dlfcn.h>
#import <mach/mach.h>

// ============================================================
// ===== Offsets =====
// ============================================================
#define OFFSET_JUMP_HEIGHT       0x4C
#define OFFSET_GRAVITY           0x18
#define OFFSET_INITIAL_TARGET_SPEED 0x24
#define OFFSET_FINAL_TARGET_SPEED 0x28
#define OFFSET_ROLL_DURATION     0x5C
#define OFFSET_COLLIDER_HEIGHT   0x64
#define OFFSET_STICK_TO_GROUND   0x1C
#define OFFSET_WALL_CLIMB_ENABLED 0x90
#define OFFSET_WALL_CLIMB_TARGET_SPEED 0xA4
#define OFFSET_SPEED_BOOST_MAX_SPEED 0xAC
#define OFFSET_SURFACE_MAX_UPWARDS_SPEED 0x8C

// ============================================================
// ===== الإعدادات =====
// ============================================================
uintptr_t g_configAddress = 0;
static UIWindow *menuWindow = nil;
static BOOL isMenuVisible = NO;

// ============================================================
// ===== دوال الذاكرة =====
// ============================================================
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

void apply_modifications() {
    mach_port_t task = mach_task_self();
    find_motor_config_address();
    
    if (g_configAddress == 0) {
        NSLog(@"MotorConfig not found");
        return;
    }
    
    // Godmode
    float zero = 0.0f, huge = 1000.0f, tiny = 0.01f;
    
    uintptr_t addrs[] = {
        g_configAddress + 0x70, // FrontalImpactKnockbackDuration
        g_configAddress + 0x74, // FrontalImpactKnockbackDistance
        g_configAddress + 0x68, // LowerImpactMaxHeight
        g_configAddress + 0x6C, // UpperImpactMinHeight
        g_configAddress + 0x78, // FrontalImpactTimeout
        g_configAddress + 0x7C, // LowerImpactHeightRatio
        g_configAddress + 0x80, // CornerImpactRegionDepthMin
        g_configAddress + 0x84, // CornerImpactRegionDepthMax
        g_configAddress + 0x88  // CornerImpactRegionWidth
    };
    float values[] = {zero, zero, huge, -huge, zero, zero, zero, zero, zero};
    
    for (int i = 0; i < 9; i++) {
        vm_protect(task, (vm_address_t)addrs[i], sizeof(float), 0, VM_PROT_READ | VM_PROT_WRITE);
        *(float *)addrs[i] = values[i];
    }
    
    vm_protect(task, (vm_address_t)(g_configAddress + OFFSET_COLLIDER_HEIGHT), sizeof(float), 0, VM_PROT_READ | VM_PROT_WRITE);
    *(float *)(g_configAddress + OFFSET_COLLIDER_HEIGHT) = tiny;
    
    // Jump Height
    vm_protect(task, (vm_address_t)(g_configAddress + OFFSET_JUMP_HEIGHT), sizeof(float), 0, VM_PROT_READ | VM_PROT_WRITE);
    *(float *)(g_configAddress + OFFSET_JUMP_HEIGHT) = 50.0f;
    
    // Speed
    vm_protect(task, (vm_address_t)(g_configAddress + OFFSET_INITIAL_TARGET_SPEED), sizeof(float), 0, VM_PROT_READ | VM_PROT_WRITE);
    vm_protect(task, (vm_address_t)(g_configAddress + OFFSET_FINAL_TARGET_SPEED), sizeof(float), 0, VM_PROT_READ | VM_PROT_WRITE);
    *(float *)(g_configAddress + OFFSET_INITIAL_TARGET_SPEED) = 200.0f;
    *(float *)(g_configAddress + OFFSET_FINAL_TARGET_SPEED) = 200.0f;
    
    // Gravity
    vm_protect(task, (vm_address_t)(g_configAddress + OFFSET_GRAVITY), sizeof(float), 0, VM_PROT_READ | VM_PROT_WRITE);
    *(float *)(g_configAddress + OFFSET_GRAVITY) = -50.0f;
    
    // Roll Duration
    vm_protect(task, (vm_address_t)(g_configAddress + OFFSET_ROLL_DURATION), sizeof(float), 0, VM_PROT_READ | VM_PROT_WRITE);
    *(float *)(g_configAddress + OFFSET_ROLL_DURATION) = 0.1f;
    
    // Stick to Ground
    vm_protect(task, (vm_address_t)(g_configAddress + OFFSET_STICK_TO_GROUND), sizeof(bool), 0, VM_PROT_READ | VM_PROT_WRITE);
    *(bool *)(g_configAddress + OFFSET_STICK_TO_GROUND) = true;
    
    // Wall Climb
    vm_protect(task, (vm_address_t)(g_configAddress + OFFSET_WALL_CLIMB_ENABLED), sizeof(bool), 0, VM_PROT_READ | VM_PROT_WRITE);
    *(bool *)(g_configAddress + OFFSET_WALL_CLIMB_ENABLED) = true;
    
    vm_protect(task, (vm_address_t)(g_configAddress + OFFSET_WALL_CLIMB_TARGET_SPEED), sizeof(float), 0, VM_PROT_READ | VM_PROT_WRITE);
    *(float *)(g_configAddress + OFFSET_WALL_CLIMB_TARGET_SPEED) = 50.0f;
    
    // Surface Max Upwards Speed
    vm_protect(task, (vm_address_t)(g_configAddress + OFFSET_SURFACE_MAX_UPWARDS_SPEED), sizeof(float), 0, VM_PROT_READ | VM_PROT_WRITE);
    *(float *)(g_configAddress + OFFSET_SURFACE_MAX_UPWARDS_SPEED) = 200.0f;
    
    // Speed Boost
    vm_protect(task, (vm_address_t)(g_configAddress + OFFSET_SPEED_BOOST_MAX_SPEED), sizeof(float), 0, VM_PROT_READ | VM_PROT_WRITE);
    *(float *)(g_configAddress + OFFSET_SPEED_BOOST_MAX_SPEED) = 300.0f;
    
    NSLog(@"All settings applied!");
}

// ============================================================
// ===== دوال UI (بدون self) =====
// ============================================================
void toggleMenu() {
    UIWindow *window = [UIApplication sharedApplication].keyWindow;
    if (!window) return;
    
    if (!menuWindow) {
        menuWindow = [[UIWindow alloc] initWithFrame:CGRectMake(20, 100, 280, 300)];
        menuWindow.backgroundColor = [UIColor colorWithWhite:0.05 alpha:0.95];
        menuWindow.layer.cornerRadius = 16;
        menuWindow.layer.borderColor = [UIColor grayColor].CGColor;
        menuWindow.layer.borderWidth = 0.5;
        menuWindow.windowLevel = UIWindowLevelAlert + 1;
        menuWindow.userInteractionEnabled = YES;
        
        // عنوان
        UILabel *title = [[UILabel alloc] initWithFrame:CGRectMake(10, 10, 260, 30)];
        title.text = @"Frezon Mod v0.1";
        title.textColor = [UIColor whiteColor];
        title.textAlignment = NSTextAlignmentCenter;
        title.font = [UIFont boldSystemFontOfSize:18];
        [menuWindow addSubview:title];
        
        // زر إغلاق
        UIButton *closeBtn = [UIButton buttonWithType:UIButtonTypeSystem];
        closeBtn.frame = CGRectMake(240, 10, 30, 30);
        [closeBtn setTitle:@"X" forState:UIControlStateNormal];
        [closeBtn setTitleColor:[UIColor grayColor] forState:UIControlStateNormal];
        [closeBtn addTarget:menuWindow action:@selector(closeMenu) forControlEvents:UIControlEventTouchUpInside];
        [menuWindow addSubview:closeBtn];
        
        // زر Godmode
        UIButton *godmodeBtn = [UIButton buttonWithType:UIButtonTypeSystem];
        godmodeBtn.frame = CGRectMake(20, 60, 240, 40);
        godmodeBtn.backgroundColor = [UIColor colorWithWhite:0.2 alpha:1];
        godmodeBtn.layer.cornerRadius = 8;
        [godmodeBtn setTitle:@"Godmode" forState:UIControlStateNormal];
        [godmodeBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        [godmodeBtn addTarget:menuWindow action:@selector(applyMods) forControlEvents:UIControlEventTouchUpInside];
        [menuWindow addSubview:godmodeBtn];
        
        // زر Jump
        UIButton *jumpBtn = [UIButton buttonWithType:UIButtonTypeSystem];
        jumpBtn.frame = CGRectMake(20, 110, 240, 40);
        jumpBtn.backgroundColor = [UIColor colorWithWhite:0.2 alpha:1];
        jumpBtn.layer.cornerRadius = 8;
        [jumpBtn setTitle:@"Jump Height = 50" forState:UIControlStateNormal];
        [jumpBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        [jumpBtn addTarget:menuWindow action:@selector(applyMods) forControlEvents:UIControlEventTouchUpInside];
        [menuWindow addSubview:jumpBtn];
        
        // زر Speed
        UIButton *speedBtn = [UIButton buttonWithType:UIButtonTypeSystem];
        speedBtn.frame = CGRectMake(20, 160, 240, 40);
        speedBtn.backgroundColor = [UIColor colorWithWhite:0.2 alpha:1];
        speedBtn.layer.cornerRadius = 8;
        [speedBtn setTitle:@"Speed = 200" forState:UIControlStateNormal];
        [speedBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        [speedBtn addTarget:menuWindow action:@selector(applyMods) forControlEvents:UIControlEventTouchUpInside];
        [menuWindow addSubview:speedBtn];
        
        // زر Apply All
        UIButton *applyBtn = [UIButton buttonWithType:UIButtonTypeSystem];
        applyBtn.frame = CGRectMake(20, 220, 240, 44);
        applyBtn.backgroundColor = [UIColor colorWithWhite:0.3 alpha:1];
        applyBtn.layer.cornerRadius = 10;
        [applyBtn setTitle:@"Apply All" forState:UIControlStateNormal];
        [applyBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        [applyBtn addTarget:menuWindow action:@selector(applyMods) forControlEvents:UIControlEventTouchUpInside];
        [menuWindow addSubview:applyBtn];
        
        [menuWindow makeKeyAndVisible];
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

void applyMods() {
    apply_modifications();
}

// ============================================================
// ===== نقطة الدخول =====
// ============================================================
__attribute__((constructor))
static void frezonmod_entry() {
    dispatch_async(dispatch_get_main_queue(), ^{
        UIWindow *window = [UIApplication sharedApplication].keyWindow;
        if (!window) return;
        
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
        [menuBtn addTarget:window action:@selector(toggleMenu) forControlEvents:UIControlEventTouchUpInside];
        [window addSubview:menuBtn];
        
        // البحث عن العناوين بعد 3 ثواني
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 3 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
            find_motor_config_address();
            apply_modifications();
        });
    });
}
