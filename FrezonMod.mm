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
@property (nonatomic, strong) id motorConfigInstance;
@property (nonatomic, strong) NSMutableArray *fieldKeys;
@end

@implementation FrezonModOverlay

- (instancetype)init {
    self = [super initWithFrame:CGRectMake(kStartX, kStartY, 60, 60)];
    if (self) {
        self.backgroundColor = [UIColor clearColor];
        self.layer.zPosition = CGFLOAT_MAX;
        self.userInteractionEnabled = YES;
        self.fieldsUI = [NSMutableDictionary dictionary];
        self.fieldKeys = [NSMutableArray array];
        self.isMenuVisible = NO;
        
        // ===== زر المنيو الدائري =====
        [self setupMenuButton];
        
        // ===== نافذة المنيو =====
        [self setupMenuView];
        
        // ===== سحب الحر =====
        UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc]
            initWithTarget:self action:@selector(handlePan:)];
        [self addGestureRecognizer:pan];
        
        // ===== بدء البحث عن الكلاس =====
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
    _menuView.userInteractionEnabled = YES; // ✅ مهم
    [self addSubview:_menuView];
    
    // ===== الهيدر =====
    UIView *headerView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 280, 50)];
    headerView.backgroundColor = [UIColor colorWithWhite:0.1 alpha:1];
    headerView.userInteractionEnabled = NO;
    [_menuView addSubview:headerView];
    
    UIView *headerLine = [[UIView alloc] initWithFrame:CGRectMake(0, 49, 280, 1)];
    headerLine.backgroundColor = [UIColor colorWithWhite:0.3 alpha:1];
    [headerView addSubview:headerLine];
    
    UILabel *titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(10, 5, 200, 30)];
    titleLabel.text = @"Frezon Mod";
    titleLabel.font = [UIFont fontWithName:@"HelveticaNeue-Bold" size:18];
    titleLabel.textColor = [UIColor whiteColor];
    titleLabel.textAlignment = NSTextAlignmentLeft;
    [headerView addSubview:titleLabel];
    
    _versionLabel = [[UILabel alloc] initWithFrame:CGRectMake(10, 28, 200, 16)];
    _versionLabel.text = @"v0.1";
    _versionLabel.font = [UIFont fontWithName:@"HelveticaNeue-Light" size:11];
    _versionLabel.textColor = [UIColor colorWithWhite:0.5 alpha:1];
    _versionLabel.textAlignment = NSTextAlignmentLeft;
    [headerView addSubview:_versionLabel];
    
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
    
    // ===== ScrollView للمحتوى (مع تفعيل التمرير) =====
    _scrollView = [[UIScrollView alloc] initWithFrame:CGRectMake(5, 55, 270, 205)];
    _scrollView.backgroundColor = [UIColor clearColor];
    _scrollView.showsVerticalScrollIndicator = YES;
    _scrollView.alwaysBounceVertical = YES;
    _scrollView.userInteractionEnabled = YES;
    _scrollView.scrollEnabled = YES;
    _scrollView.bounces = YES;
    _scrollView.indicatorStyle = UIScrollViewIndicatorStyleWhite;
    [_menuView addSubview:_scrollView];
    
    _contentView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 260, 10)];
    _contentView.backgroundColor = [UIColor clearColor];
    _contentView.userInteractionEnabled = YES;
    [_scrollView addSubview:_contentView];
}

// ============================================================
// ===== 3. البحث عن CharacterMotorConfig وعرض حقوله =====
// ============================================================
- (void)initializeMod {
    [self findCharacterMotorConfig];
}

- (void)findCharacterMotorConfig {
    NSLog(@"🔍 Searching for CharacterMotorConfig...");
    
    // محاولة تحميل Unity Framework
    void *unityHandle = dlopen("/System/Library/Frameworks/UnityFramework.framework/UnityFramework", RTLD_LAZY);
    if (!unityHandle) {
        unityHandle = dlopen("UnityFramework", RTLD_LAZY);
    }
    
    if (unityHandle) {
        NSLog(@"✅ Unity Framework loaded");
    } else {
        NSLog(@"⚠️ Unity Framework not found, using fallback");
    }
    
    // البحث عن الكلاس باستخدام objc_getClass
    Class motorConfigClass = objc_getClass("CharacterMotorConfig");
    if (!motorConfigClass) {
        // محاولة البحث عن الكلاس بالاسم الكامل
        motorConfigClass = objc_getClass("SYBO.RunnerCore.Character.CharacterMotorConfig");
    }
    
    if (motorConfigClass) {
        NSLog(@"✅ Found CharacterMotorConfig class");
        self.motorConfigInstance = [self findInstanceOfClass:motorConfigClass];
        
        if (self.motorConfigInstance) {
            NSLog(@"✅ Found CharacterMotorConfig instance");
            [self displayFieldsOfObject:self.motorConfigInstance];
        } else {
            NSLog(@"⚠️ No instance found, creating fallback fields");
            [self addFallbackFields];
        }
    } else {
        NSLog(@"❌ CharacterMotorConfig class not found");
        [self addFallbackFields];
    }
}

- (id)findInstanceOfClass:(Class)targetClass {
    // ===== الطريقة 1: البحث عن الـ singleton =====
    Ivar instanceIvar = class_getClassVariable(targetClass, "s_Instance");
    if (instanceIvar) {
        id instance = object_getIvar(targetClass, instanceIvar);
        if (instance) {
            NSLog(@"✅ Found via s_Instance");
            return instance;
        }
    }
    
    // ===== الطريقة 2: البحث عن property "instance" =====
    objc_property_t property = class_getProperty(targetClass, "instance");
    if (property) {
        id instance = [targetClass valueForKey:@"instance"];
        if (instance) {
            NSLog(@"✅ Found via instance property");
            return instance;
        }
    }
    
    // ===== الطريقة 3: البحث عن property "sharedInstance" =====
    property = class_getProperty(targetClass, "sharedInstance");
    if (property) {
        id instance = [targetClass valueForKey:@"sharedInstance"];
        if (instance) {
            NSLog(@"✅ Found via sharedInstance property");
            return instance;
        }
    }
    
    // ===== الطريقة 4: البحث عن property "default" =====
    property = class_getProperty(targetClass, "default");
    if (property) {
        id instance = [targetClass valueForKey:@"default"];
        if (instance) {
            NSLog(@"✅ Found via default property");
            return instance;
        }
    }
    
    // ===== الطريقة 5: البحث عن static field "Default" =====
    Ivar defaultIvar = class_getClassVariable(targetClass, "Default");
    if (defaultIvar) {
        id instance = object_getIvar(targetClass, defaultIvar);
        if (instance) {
            NSLog(@"✅ Found via Default ivar");
            return instance;
        }
    }
    
    // ===== الطريقة 6: البحث في جميع الكائنات =====
    int numClasses;
    Class *classes = NULL;
    numClasses = objc_getClassList(NULL, 0);
    
    if (numClasses > 0) {
        classes = (Class *)malloc(sizeof(Class) * numClasses);
        numClasses = objc_getClassList(classes, numClasses);
        
        for (int i = 0; i < numClasses; i++) {
            Class cls = classes[i];
            if (cls == targetClass) {
                // محاولة الحصول على الكائن من static field
                Ivar staticIvar = class_getClassVariable(cls, "instance");
                if (staticIvar) {
                    id instance = object_getIvar(cls, staticIvar);
                    if (instance) {
                        free(classes);
                        return instance;
                    }
                }
            }
        }
        free(classes);
    }
    
    // ===== الطريقة 7: محاولة إنشاء كائن جديد =====
    id newInstance = [[targetClass alloc] init];
    if (newInstance) {
        NSLog(@"✅ Created new instance");
        return newInstance;
    }
    
    return nil;
}

- (void)displayFieldsOfObject:(id)object {
    Class cls = [object class];
    unsigned int count;
    Ivar *ivars = class_copyIvarList(cls, &count);
    
    NSLog(@"📌 Found %d fields in CharacterMotorConfig", count);
    
    for (unsigned int i = 0; i < count; i++) {
        Ivar ivar = ivars[i];
        const char *name = ivar_getName(ivar);
        const char *type = ivar_getTypeEncoding(ivar);
        
        NSString *fieldName = [NSString stringWithUTF8String:name];
        NSString *fieldType = [NSString stringWithUTF8String:type];
        
        // تجاهل الحقول الخاصة (ت starts with _)
        if ([fieldName hasPrefix:@"_"]) {
            continue;
        }
        
        // جلب القيمة الحالية
        id value = object_getIvar(object, ivar);
        NSString *valueString = [NSString stringWithFormat:@"%@", value];
        
        // تحديد نوع الحقل
        NSString *displayType = @"unknown";
        if (strcmp(type, "f") == 0 || strcmp(type, "d") == 0) {
            displayType = @"float";
        } else if (strcmp(type, "i") == 0 || strcmp(type, "l") == 0 || strcmp(type, "q") == 0) {
            displayType = @"int";
        } else if (strcmp(type, "B") == 0 || strcmp(type, "c") == 0) {
            displayType = @"bool";
        } else if (strcmp(type, "@") == 0) {
            displayType = @"object";
        } else if (strcmp(type, "s") == 0) {
            displayType = @"string";
        }
        
        NSLog(@"📌 %@ = %@ (%@)", fieldName, valueString, displayType);
        
        // إضافة الحقل إلى المنيو
        [self addFieldToMenu:fieldName value:valueString type:displayType ivar:ivar];
        [self.fieldKeys addObject:fieldName];
    }
    
    free(ivars);
    
    if (count == 0) {
        [self addFallbackFields];
    }
    
    [self updateContentSize];
}

- (void)addFallbackFields {
    // إذا لم نجد الكلاس، نضيف حقول افتراضية
    NSArray *fallbackFields = @[
        @[@"JumpHeight", @"20.000000", @"float"],
        @[@"Gravity", @"-200.000000", @"float"],
        @[@"Speed", @"110.000000", @"float"],
        @[@"StickToGround", @"True", @"bool"],
        @[@"ColliderHeight", @"9.000000", @"float"],
        @[@"WallClimbEnabled", @"False", @"bool"],
        @[@"RollDuration", @"0.600000", @"float"]
    ];
    
    for (NSArray *field in fallbackFields) {
        [self addFieldToMenu:field[0] value:field[1] type:field[2] ivar:nil];
        [self.fieldKeys addObject:field[0]];
    }
    
    [self updateContentSize];
}

// ============================================================
// ===== 4. إضافة حقل إلى المنيو =====
// ============================================================
- (void)addFieldToMenu:(NSString *)label value:(NSString *)defaultValue type:(NSString *)type ivar:(Ivar)ivar {
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
    UILabel *nameLabel = [[UILabel alloc] initWithFrame:CGRectMake(8, 5, 100, 30)];
    nameLabel.text = label;
    nameLabel.font = [UIFont fontWithName:@"HelveticaNeue" size:12];
    nameLabel.textColor = [UIColor colorWithWhite:0.8 alpha:1];
    nameLabel.userInteractionEnabled = NO;
    nameLabel.adjustsFontSizeToFitWidth = YES;
    nameLabel.minimumScaleFactor = 0.7;
    [itemView addSubview:nameLabel];
    
    if ([type isEqualToString:@"bool"]) {
        // ===== مفتاح تبديل (Toggle) =====
        UISwitch *toggle = [[UISwitch alloc] initWithFrame:CGRectMake(195, 5, 50, 30)];
        toggle.onTintColor = [UIColor whiteColor];
        toggle.tintColor = [UIColor colorWithWhite:0.3 alpha:1];
        toggle.thumbTintColor = [UIColor colorWithWhite:0.1 alpha:1];
        toggle.on = [defaultValue isEqualToString:@"1"] || [defaultValue isEqualToString:@"YES"] || [defaultValue isEqualToString:@"True"];
        toggle.userInteractionEnabled = YES;
        [toggle addTarget:self action:@selector(toggleChanged:) forControlEvents:UIControlEventValueChanged];
        [itemView addSubview:toggle];
        
        // تخزين البيانات
        self.fieldsUI[label] = @{
            @"type": type,
            @"ivar": [NSValue valueWithPointer:ivar],
            @"toggle": toggle,
            @"itemView": itemView
        };
    } else {
        // ===== حقل الإدخال =====
        UITextField *inputField = [[UITextField alloc] initWithFrame:CGRectMake(120, 5, 80, 30)];
        inputField.text = defaultValue;
        inputField.textColor = [UIColor whiteColor];
        inputField.backgroundColor = [UIColor colorWithWhite:0.2 alpha:0.8];
        inputField.layer.cornerRadius = 5;
        inputField.layer.borderColor = [UIColor colorWithWhite:0.3 alpha:1].CGColor;
        inputField.layer.borderWidth = 0.5;
        inputField.font = [UIFont fontWithName:@"HelveticaNeue" size:12];
        inputField.keyboardType = UIKeyboardTypeDecimalPad;
        inputField.userInteractionEnabled = YES;
        inputField.textAlignment = NSTextAlignmentCenter;
        inputField.tag = 100;
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
        
        // تخزين البيانات
        self.fieldsUI[label] = @{
            @"type": type,
            @"ivar": [NSValue valueWithPointer:ivar],
            @"inputField": inputField,
            @"applyBtn": applyBtn,
            @"itemView": itemView
        };
    }
}

// ============================================================
// ===== 5. معالجة التبديل (Toggle) =====
// ============================================================
- (void)toggleChanged:(UISwitch *)sender {
    UIView *itemView = sender.superview;
    if (!itemView) return;
    
    UILabel *label = nil;
    for (UIView *subview in itemView.subviews) {
        if ([subview isKindOfClass:[UILabel class]]) {
            label = (UILabel *)subview;
            break;
        }
    }
    
    if (!label) return;
    
    NSString *fieldName = label.text;
    BOOL newValue = sender.isOn;
    
    NSLog(@"✅ Toggle: %@ = %@", fieldName, newValue ? @"YES" : @"NO");
    
    // تعديل القيمة في الكائن
    [self setValue:newValue ? @"1" : @"0" forField:fieldName];
    
    [self showFeedback:[NSString stringWithFormat:@"%@ = %@", fieldName, newValue ? @"ON" : @"OFF"]];
}

// ============================================================
// ===== 6. معالجة زر التطبيق =====
// ============================================================
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
    
    // تعديل القيمة في الكائن
    BOOL success = [self setValue:newValue forField:fieldName];
    
    if (success) {
        [self showFeedback:[NSString stringWithFormat:@"✅ %@ = %@", fieldName, newValue]];
    } else {
        [self showFeedback:[NSString stringWithFormat:@"❌ Failed to set %@", fieldName]];
    }
}

// ============================================================
// ===== 7. دالة تعديل القيمة فعلياً =====
// ============================================================
- (BOOL)setValue:(NSString *)newValue forField:(NSString *)fieldName {
    if (!self.motorConfigInstance) {
        NSLog(@"❌ No motor config instance");
        return NO;
    }
    
    // البحث عن الـ Ivar
    Ivar ivar = class_getInstanceVariable([self.motorConfigInstance class], [fieldName UTF8String]);
    if (!ivar) {
        // محاولة البحث بالاسم بدون تغيير
        NSString *searchName = fieldName;
        ivar = class_getInstanceVariable([self.motorConfigInstance class], [searchName UTF8String]);
    }
    
    if (!ivar) {
        NSLog(@"❌ Field '%@' not found", fieldName);
        return NO;
    }
    
    const char *type = ivar_getTypeEncoding(ivar);
    NSLog(@"📌 Setting %@ to %@ (type: %s)", fieldName, newValue, type);
    
    @try {
        if (strcmp(type, "f") == 0) {
            float floatValue = [newValue floatValue];
            object_setIvar(self.motorConfigInstance, ivar, [NSNumber numberWithFloat:floatValue]);
        } else if (strcmp(type, "d") == 0) {
            double doubleValue = [newValue doubleValue];
            object_setIvar(self.motorConfigInstance, ivar, [NSNumber numberWithDouble:doubleValue]);
        } else if (strcmp(type, "i") == 0 || strcmp(type, "l") == 0 || strcmp(type, "q") == 0) {
            int intValue = [newValue intValue];
            object_setIvar(self.motorConfigInstance, ivar, [NSNumber numberWithInt:intValue]);
        } else if (strcmp(type, "B") == 0 || strcmp(type, "c") == 0) {
            BOOL boolValue = [newValue boolValue] || [newValue isEqualToString:@"1"] || [newValue isEqualToString:@"YES"] || [newValue isEqualToString:@"True"];
            object_setIvar(self.motorConfigInstance, ivar, [NSNumber numberWithBool:boolValue]);
        } else if (strcmp(type, "@") == 0) {
            // كائن (Object)
            object_setIvar(self.motorConfigInstance, ivar, newValue);
        } else if (strcmp(type, "s") == 0) {
            // سلسلة نصية (String)
            object_setIvar(self.motorConfigInstance, ivar, newValue);
        } else {
            NSLog(@"⚠️ Unsupported type: %s", type);
            return NO;
        }
        
        NSLog(@"✅ Successfully set %@ = %@", fieldName, newValue);
        return YES;
    } @catch (NSException *exception) {
        NSLog(@"❌ Exception: %@", exception);
        return NO;
    }
}

// ============================================================
// ===== 8. دوال التحكم في المينو =====
// ============================================================
- (void)toggleMenu {
    _isMenuVisible = !_isMenuVisible;
    _menuView.hidden = !_isMenuVisible;
    if (_isMenuVisible) {
        [self.superview bringSubviewToFront:self];
        // إعادة تحميل القيم عند فتح المينو
        [self refreshValues];
    }
}

- (void)refreshValues {
    // تحديث القيم المعروضة في المينو
    for (NSString *key in self.fieldsUI.allKeys) {
        NSDictionary *data = self.fieldsUI[key];
        if (!data) continue;
        
        // البحث عن القيمة الحالية
        Ivar ivar = [[data objectForKey:@"ivar"] pointerValue];
        if (ivar && self.motorConfigInstance) {
            id value = object_getIvar(self.motorConfigInstance, ivar);
            NSString *valueString = [NSString stringWithFormat:@"%@", value];
            
            UITextField *inputField = [data objectForKey:@"inputField"];
            if (inputField) {
                inputField.text = valueString;
            }
            
            UISwitch *toggle = [data objectForKey:@"toggle"];
            if (toggle) {
                toggle.on = [valueString isEqualToString:@"1"] || [valueString isEqualToString:@"YES"] || [valueString isEqualToString:@"True"];
            }
        }
    }
}

- (void)showFeedback:(NSString *)message {
    // إزالة أي رسالة سابقة
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
    feedbackLabel.userInteractionEnabled = NO;
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
    if (totalHeight < 200) totalHeight = 200;
    CGRect frame = self.contentView.frame;
    frame.size.height = totalHeight;
    self.contentView.frame = frame;
    self.scrollView.contentSize = CGSizeMake(260, totalHeight);
}

- (void)handlePan:(UIPanGestureRecognizer *)gr {
    CGPoint translation = [gr translationInView:self.superview];
    self.center = CGPointMake(self.center.x + translation.x, self.center.y + translation.y);
    [gr setTranslation:CGPointZero inView:self.superview];
}

@end

// ============================================================
// ===== 9. دوال الحقن (Injection) =====
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
