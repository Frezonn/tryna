#import <UIKit/UIKit.h>
#import <WebKit/WebKit.h>
#import <objc/runtime.h>
#import "WalletManager.h"

static UIWindow *menuWindow;
static UIButton *floatingButton;
static WKWebView *webView;
static BOOL menuInitialized = NO;

@interface DraggableButton : UIButton
@property (nonatomic, assign) CGPoint offset;
@end

@implementation DraggableButton
- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    UITouch *touch = [touches anyObject];
    self.offset = [touch locationInView:self];
}

- (void)touchesMoved:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    UITouch *touch = [touches anyObject];
    CGPoint location = [touch locationInView:self.superview];
    CGPoint newCenter = CGPointMake(location.x - self.offset.x, location.y - self.offset.y);
    self.center = newCenter;
}

- (void)touchesEnded:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    UITouch *touch = [touches anyObject];
    CGPoint endPoint = [touch locationInView:self.superview];
    CGFloat distance = sqrt(pow(endPoint.x - self.center.x, 2) + pow(endPoint.y - self.center.y, 2));
    if (distance < 15) {
        [self openMenu];
    }
}

- (void)openMenu {
    if (menuWindow) {
        menuWindow.hidden = !menuWindow.hidden;
        if (!menuWindow.hidden) {
            [webView reload];
            [UIApplication sharedApplication].keyWindow.windowLevel = UIWindowLevelNormal;
            [menuWindow makeKeyAndVisible];
        }
    }
}
@end

@interface MenuMessageHandler : NSObject <WKScriptMessageHandler>
@end

@implementation MenuMessageHandler
- (void)userContentController:(WKUserContentController *)userContentController didReceiveScriptMessage:(WKScriptMessage *)message {
    if ([message.name isEqualToString:@"modAction"]) {
        NSString *action = message.body;
        NSLog(@"[FrezonMod] Received action: %@", action);
        
        if ([action isEqualToString:@"unlimited_on"]) {
            [WalletManager modifyWalletWithUnlimited:YES];
            NSLog(@"[FrezonMod] Unlimited coins enabled");
        } else if ([action isEqualToString:@"unlimited_off"]) {
            [WalletManager modifyWalletWithUnlimited:NO];
            NSLog(@"[FrezonMod] Unlimited coins disabled");
        } else if ([action isEqualToString:@"restore"]) {
            [WalletManager restoreWallet];
            NSLog(@"[FrezonMod] Wallet restored");
        } else if ([action isEqualToString:@"close_menu"]) {
            menuWindow.hidden = YES;
        }
    }
}
@end

static NSString* getDefaultMenuHTML() {
    return @"<!DOCTYPE html><html><head><meta charset='UTF-8'><meta name='viewport' content='width=device-width, initial-scale=1.0'><title>Frezon Mod</title><style>*{margin:0;padding:0;box-sizing:border-box}body{font-family:Arial,sans-serif;background:linear-gradient(135deg,#667eea 0%,#764ba2 100%);display:flex;justify-content:center;align-items:center;height:100vh}#menu-container{background:rgba(255,255,255,0.95);border-radius:20px;padding:30px;box-shadow:0 20px 60px rgba(0,0,0,0.3);text-align:center;max-width:280px;width:100%}h1{color:#333;margin-bottom:25px;font-size:24px}button{background:linear-gradient(135deg,#667eea,#764ba2);color:white;border:none;padding:12px 20px;margin:10px 0;border-radius:10px;font-size:16px;cursor:pointer;transition:transform 0.2s;width:100%}button:active{transform:scale(0.95)}.btn-danger{background:linear-gradient(135deg,#f093fb,#f5576c)}.status{margin-top:20px;font-size:14px;color:#666}</style></head><body><div id='menu-container'><h1>🎮 Frezon Mod</h1><button onclick='sendAction(\"unlimited_on\")'>♾️ Enable Unlimited</button><button onclick='sendAction(\"unlimited_off\")'>❌ Disable Unlimited</button><button onclick='sendAction(\"restore\")' class='btn-danger'>🔄 Restore Wallet</button><button onclick='sendAction(\"close_menu\")' class='btn-danger'>Close Menu</button><div class='status'><p>Ready to modify!</p></div></div><script>function sendAction(action){window.webkit.messageHandlers.modAction.postMessage(action)}</script></body></html>";
}

static void createMenuInterface() {
    if (menuInitialized) return;
    menuInitialized = YES;
    
    NSLog(@"[FrezonMod] Creating menu interface...");
    
    dispatch_async(dispatch_get_main_queue(), ^{
        UIWindow *keyWindow = [UIApplication sharedApplication].keyWindow;
        if (!keyWindow) {
            NSLog(@"[FrezonMod] ERROR: keyWindow is nil");
            return;
        }
        
        NSString *htmlContent = getDefaultMenuHTML();
        
        WKWebViewConfiguration *config = [[WKWebViewConfiguration alloc] init];
        WKUserContentController *userContentController = [[WKUserContentController alloc] init];
        MenuMessageHandler *handler = [[MenuMessageHandler alloc] init];
        [userContentController addScriptMessageHandler:handler name:@"modAction"];
        config.userContentController = userContentController;
        
        CGFloat menuWidth = 320;
        CGFloat menuHeight = 380;
        CGFloat x = (keyWindow.bounds.size.width - menuWidth) / 2;
        CGFloat y = (keyWindow.bounds.size.height - menuHeight) / 2 - 40;
        
        webView = [[WKWebView alloc] initWithFrame:CGRectMake(0, 0, menuWidth, menuHeight) configuration:config];
        webView.backgroundColor = [UIColor clearColor];
        webView.opaque = NO;
        webView.scrollView.backgroundColor = [UIColor clearColor];
        webView.scrollView.scrollEnabled = NO;
        webView.layer.cornerRadius = 20;
        webView.clipsToBounds = YES;
        [webView loadHTMLString:htmlContent baseURL:nil];
        
        menuWindow = [[UIWindow alloc] initWithFrame:CGRectMake(x, y, menuWidth, menuHeight)];
        menuWindow.backgroundColor = [UIColor clearColor];
        menuWindow.windowLevel = UIWindowLevelAlert + 1;
        [menuWindow addSubview:webView];
        menuWindow.hidden = YES;
        [menuWindow makeKeyAndVisible];
        
        NSLog(@"[FrezonMod] Menu window created");
        
        floatingButton = [DraggableButton buttonWithType:UIButtonTypeCustom];
        floatingButton.frame = CGRectMake(20, 100, 60, 60);
        floatingButton.layer.cornerRadius = 30;
        floatingButton.clipsToBounds = YES;
        floatingButton.backgroundColor = [UIColor colorWithRed:0.1 green:0.5 blue:1.0 alpha:0.9];
        [floatingButton setTitle:@"FM" forState:UIControlStateNormal];
        floatingButton.titleLabel.font = [UIFont boldSystemFontOfSize:16];
        [floatingButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        floatingButton.layer.shadowColor = [UIColor blackColor].CGColor;
        floatingButton.layer.shadowOffset = CGSizeMake(0, 4);
        floatingButton.layer.shadowRadius = 8;
        floatingButton.layer.shadowOpacity = 0.7;
        
        [keyWindow addSubview:floatingButton];
        
        NSLog(@"[FrezonMod] Floating button created");
    });
}

__attribute__((constructor))
static void tweakConstructor() {
    NSLog(@"[FrezonMod] Tweak loaded and initialized");
    createMenuInterface();
}
