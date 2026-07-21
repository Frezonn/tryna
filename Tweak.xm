#import <UIKit/UIKit.h>
#import <WebKit/WebKit.h>
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
    return @"<!DOCTYPE html><html><head><meta charset='UTF-8'><meta name='viewport' content='width=device-width, initial-scale=1.0'><title>Frezon Mod</title><style>*{margin:0;padding:0;box-sizing:border-box}html,body{width:100%;height:100%;overflow:hidden}body{font-family:-apple-system,BlinkMacSystemFont,'Segoe UI','Helvetica Neue',sans-serif;background:linear-gradient(135deg,#667eea 0%,#764ba2 100%);color:#fff;padding:0;display:flex;flex-direction:column}.container{width:100%;padding:15px;flex:1;overflow-y:auto;display:flex;flex-direction:column}.header{text-align:center;margin-bottom:20px;padding-bottom:15px;border-bottom:1px solid rgba(255,255,255,.2)}.header h1{font-size:22px;font-weight:bold;margin-bottom:5px;text-shadow:0 2px 4px rgba(0,0,0,.3)}.header p{font-size:12px;opacity:.85;letter-spacing:.5px}.menu-section{margin-bottom:15px}.section-title{font-size:11px;font-weight:700;text-transform:uppercase;letter-spacing:1px;opacity:.7;margin-bottom:8px;padding-left:5px}.menu-item{background:rgba(255,255,255,.12);backdrop-filter:blur(10px);border-radius:12px;padding:12px 15px;margin-bottom:10px;border:1px solid rgba(255,255,255,.15);display:flex;align-items:center;justify-content:space-between;transition:all .3s ease;cursor:pointer}.menu-item:active{background:rgba(255,255,255,.2);transform:scale(.98)}.menu-item label{display:flex;align-items:center;cursor:pointer;font-size:15px;font-weight:500;flex:1;user-select:none}.menu-item-icon{font-size:18px;margin-right:12px;display:inline-block}.menu-item-text{display:flex;flex-direction:column}.menu-item-name{font-size:15px;font-weight:600}.menu-item-desc{font-size:11px;opacity:.7;margin-top:2px}.toggle-switch{width:52px;height:30px;background:rgba(255,255,255,.3);border-radius:15px;position:relative;transition:background .3s ease;flex-shrink:0;border:2px solid rgba(255,255,255,.2)}.toggle-switch.active{background:#4CAF50;border-color:#45a049}.toggle-switch::after{content:'';position:absolute;width:24px;height:24px;background:#fff;border-radius:50%;top:2px;left:2px;transition:left .3s ease;box-shadow:0 2px 4px rgba(0,0,0,.2)}.toggle-switch.active::after{left:22px}.button-group{display:flex;gap:8px;margin-top:10px}.btn{flex:1;padding:10px;background:rgba(255,255,255,.2);border:1px solid rgba(255,255,255,.3);border-radius:8px;color:#fff;font-size:12px;font-weight:600;cursor:pointer;transition:all .3s ease;text-transform:uppercase;letter-spacing:.5px}.btn:active{background:rgba(255,255,255,.3);transform:scale(.95)}.btn.danger{background:rgba(255,68,68,.3);border-color:rgba(255,68,68,.5)}.btn.danger:active{background:rgba(255,68,68,.4)}.status-bar{background:rgba(0,0,0,.2);padding:8px 12px;border-radius:8px;font-size:11px;text-align:center;margin-bottom:10px;border:1px solid rgba(255,255,255,.1)}.status-indicator{display:inline-block;width:8px;height:8px;background:#4CAF50;border-radius:50%;margin-right:6px;animation:pulse 2s infinite}@keyframes pulse{0%,100%{opacity:1}50%{opacity:.5}}.footer{text-align:center;padding:10px;border-top:1px solid rgba(255,255,255,.1);font-size:10px;opacity:.6;margin-top:auto}.version{font-size:10px;font-weight:600;letter-spacing:.5px;margin-top:3px}</style></head><body><div class='container'><div class='header'><h1>🎮 Frezon Mod</h1><p>Subway Surfers Enhancement</p></div><div class='status-bar'><span class='status-indicator'></span><span>Mod Active & Running</span></div><div class='menu-section'><div class='section-title'>💰 Currency</div><div class='menu-item'><label><span class='menu-item-icon'>💎</span><span class='menu-item-text'><span class='menu-item-name'>Unlimited Coins</span><span class='menu-item-desc'>Enable infinite currency</span></span></label><div class='toggle-switch' id='unlimitedToggle' onclick='toggleUnlimited(event)'></div></div></div><div class='menu-section'><div class='section-title'>⚙️ Actions</div><div class='button-group'><button class='btn' onclick='restoreWallet()'>Restore</button><button class='btn danger' onclick='closeMenu()'>Close</button></div></div><div class='footer'><div><span class='status-indicator' style='background:#fff;animation:none;vertical-align:text-bottom;'></span> Made by Frezon</div><div class='version'>v1.1 - Fully Functional</div></div></div><script>let isEnabled=false;function toggleUnlimited(e){e.stopPropagation();const t=document.getElementById('unlimitedToggle');isEnabled=!isEnabled,t.classList.toggle('active'),console.log('[FrezonMod] Action: '+(isEnabled?'unlimited_on':'unlimited_off')),window.webkit&&window.webkit.messageHandlers&&window.webkit.messageHandlers.modAction?isEnabled?window.webkit.messageHandlers.modAction.postMessage('unlimited_on'):window.webkit.messageHandlers.modAction.postMessage('unlimited_off'):console.error('[FrezonMod] webkit not available')}function restoreWallet(){window.webkit&&window.webkit.messageHandlers&&window.webkit.messageHandlers.modAction&&window.webkit.messageHandlers.modAction.postMessage('restore'),console.log('[FrezonMod] Restore requested')}function closeMenu(){console.log('[FrezonMod] Closing menu'),window.webkit.messageHandlers.modAction.postMessage('close_menu')}window.addEventListener('load',function(){console.log('[FrezonMod] Menu loaded'),document.getElementById('unlimitedToggle').classList.remove('active')})</script></body></html>";
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
        
        NSString *htmlPath = [[NSBundle mainBundle] pathForResource:@"menu" ofType:@"html"];
        NSString *htmlContent;
        
        if ([[NSFileManager defaultManager] fileExistsAtPath:htmlPath]) {
            htmlContent = [NSString stringWithContentsOfFile:htmlPath encoding:NSUTF8StringEncoding error:nil];
            NSLog(@"[FrezonMod] Menu HTML loaded from Resources");
        } else {
            NSLog(@"[FrezonMod] Menu HTML not found, using default");
            htmlContent = getDefaultMenuHTML();
        }
        
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

%hook SpringBoard
- (void)applicationDidFinishLaunching:(UIApplication *)application {
    %orig;
    NSLog(@"[FrezonMod] SpringBoard launched - Initializing Tweak");
    createMenuInterface();
}
%end

__attribute__((constructor))
static void tweakConstructor() {
    NSLog(@"[FrezonMod] Tweak constructor called");
}
