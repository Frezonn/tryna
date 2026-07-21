#import <UIKit/UIKit.h>
#import <WebKit/WebKit.h>
#import "WalletManager.h"

static UIWindow *menuWindow;
static UIButton *floatingButton;
static WKWebView *webView;

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
    CGPoint newCenter = CGPointMake(location.x, location.y);
    self.center = newCenter;
}

- (void)touchesEnded:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    UITouch *touch = [touches anyObject];
    CGPoint endPoint = [touch locationInView:self.superview];
    CGFloat distance = sqrt(pow(endPoint.x - self.center.x, 2) + pow(endPoint.y - self.center.y, 2));
    if (distance < 10) {
        [self openMenu];
    }
}

- (void)openMenu {
    menuWindow.hidden = !menuWindow.hidden;
    if (!menuWindow.hidden) {
        [webView reload];
    }
}
@end

@interface MenuMessageHandler : NSObject <WKScriptMessageHandler>
@end

@implementation MenuMessageHandler
- (void)userContentController:(WKUserContentController *)userContentController didReceiveScriptMessage:(WKScriptMessage *)message {
    if ([message.name isEqualToString:@"modAction"]) {
        NSString *action = message.body;
        if ([action isEqualToString:@"unlimited_on"]) {
            [WalletManager modifyWalletWithUnlimited:YES];
        } else if ([action isEqualToString:@"unlimited_off"]) {
            [WalletManager modifyWalletWithUnlimited:NO];
        }
    }
}
@end

%ctor {
    dispatch_async(dispatch_get_main_queue(), ^{
        UIWindow *keyWindow = [UIApplication sharedApplication].keyWindow;
        if (!keyWindow) return;
        
        NSString *htmlPath = [[NSBundle mainBundle] pathForResource:@"menu" ofType:@"html"];
        NSString *htmlContent = [NSString stringWithContentsOfFile:htmlPath encoding:NSUTF8StringEncoding error:nil];
        if (!htmlContent) {
            htmlContent = @"<html><body style='background:#222;color:#fff;text-align:center;padding-top:50px;'><h1>Menu not found</h1></body></html>";
        }
        
        WKWebViewConfiguration *config = [[WKWebViewConfiguration alloc] init];
        MenuMessageHandler *handler = [[MenuMessageHandler alloc] init];
        [config.userContentController addScriptMessageHandler:handler name:@"modAction"];
        
        CGFloat menuWidth = 300;
        CGFloat menuHeight = 280;
        CGFloat x = (keyWindow.bounds.size.width - menuWidth) / 2;
        CGFloat y = (keyWindow.bounds.size.height - menuHeight) / 2 - 40;
        
        webView = [[WKWebView alloc] initWithFrame:CGRectMake(0, 0, menuWidth, menuHeight) configuration:config];
        webView.backgroundColor = [UIColor clearColor];
        webView.opaque = NO;
        webView.scrollView.backgroundColor = [UIColor clearColor];
        webView.layer.cornerRadius = 25;
        webView.clipsToBounds = YES;
        [webView loadHTMLString:htmlContent baseURL:nil];
        
        menuWindow = [[UIWindow alloc] initWithFrame:CGRectMake(x, y, menuWidth, menuHeight)];
        menuWindow.backgroundColor = [UIColor clearColor];
        menuWindow.windowLevel = UIWindowLevelAlert + 1;
        [menuWindow addSubview:webView];
        menuWindow.hidden = YES;
        [menuWindow makeKeyAndVisible];
        
        UIImage *buttonImage = [UIImage imageWithData:[NSData dataWithContentsOfURL:[NSURL URLWithString:@"https://i.ibb.co/v43CFpDJ/IMG-6158.jpg"]]];
        floatingButton = [DraggableButton buttonWithType:UIButtonTypeCustom];
        floatingButton.frame = CGRectMake(20, 100, 60, 60);
        floatingButton.layer.cornerRadius = 30;
        floatingButton.clipsToBounds = YES;
        [floatingButton setImage:buttonImage forState:UIControlStateNormal];
        floatingButton.imageView.contentMode = UIViewContentModeScaleAspectFill;
        floatingButton.layer.shadowColor = [UIColor blackColor].CGColor;
        floatingButton.layer.shadowOffset = CGSizeMake(0, 4);
        floatingButton.layer.shadowRadius = 8;
        floatingButton.layer.shadowOpacity = 0.5;
        
        [keyWindow addSubview:floatingButton];
    });
}
