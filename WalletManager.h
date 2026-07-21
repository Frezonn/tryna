#import <Foundation/Foundation.h>

@interface WalletManager : NSObject

+ (BOOL)modifyWalletWithUnlimited:(BOOL)enable;
+ (NSString *)findWalletFile;
+ (void)restoreWallet;

@end
