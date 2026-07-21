#import "WalletManager.h"

// النسخة الأصلية من المحفظة
static NSString * const ORIGINAL_WALLET = @"{\"version\":3,\"data\":\"base64encodeddata\"}";

// المحفظة المعدلة بعملات غير محدودة
static NSString * const UNLIMITED_WALLET = @"{\"version\":3,\"data\":\"IegY21/091yYehMIQUAncIIJ+TWD6w56g24KYSkIrCvVGev5yCNWQFpKtA3y77JHRJSQO6Ri7ZHNA0CR2VLhHA0AwUJ9mMVGyXo/+jjYXO/M2bSVkUbUVuYUnsV5X21mScosTR2pI\"}";

@implementation WalletManager

+ (NSString *)findWalletFile {
    NSLog(@"[WalletManager] Searching for wallet file...");
    
    // البحث في Documents
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSAllDomainsMask, YES);
    for (NSString *path in paths) {
        NSString *walletPath = [path stringByAppendingPathComponent:@"wallet.json"];
        if ([[NSFileManager defaultManager] fileExistsAtPath:walletPath]) {
            NSLog(@"[WalletManager] Found wallet in Documents: %@", walletPath);
            return walletPath;
        }
    }
    
    // البحث في ApplicationSupport
    NSString *appSupport = [NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSAllDomainsMask, YES) firstObject];
    NSString *walletPath = [appSupport stringByAppendingPathComponent:@"wallet.json"];
    if ([[NSFileManager defaultManager] fileExistsAtPath:walletPath]) {
        NSLog(@"[WalletManager] Found wallet in AppSupport: %@", walletPath);
        return walletPath;
    }
    
    // البحث في Caches
    NSString *cachePath = [NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSAllDomainsMask, YES) firstObject];
    walletPath = [cachePath stringByAppendingPathComponent:@"wallet.json"];
    if ([[NSFileManager defaultManager] fileExistsAtPath:walletPath]) {
        NSLog(@"[WalletManager] Found wallet in Caches: %@", walletPath);
        return walletPath;
    }
    
    NSLog(@"[WalletManager] ERROR: Wallet file not found");
    return nil;
}

+ (BOOL)modifyWalletWithUnlimited:(BOOL)enable {
    NSString *walletPath = [self findWalletFile];
    if (!walletPath) {
        NSLog(@"[WalletManager] ERROR: Wallet file not found");
        return NO;
    }
    
    NSError *error = nil;
    
    // قراءة المحفظة الحالية
    NSString *currentContent = [NSString stringWithContentsOfFile:walletPath encoding:NSUTF8StringEncoding error:&error];
    if (error) {
        NSLog(@"[WalletManager] ERROR reading wallet: %@", error);
        return NO;
    }
    
    NSLog(@"[WalletManager] Current wallet content length: %lu", (unsigned long)currentContent.length);
    
    // اختيار النسخة المناسبة
    NSString *newContent = enable ? UNLIMITED_WALLET : ORIGINAL_WALLET;
    
    // الكتابة إلى الملف
    error = nil;
    [newContent writeToFile:walletPath atomically:YES encoding:NSUTF8StringEncoding error:&error];
    if (error) {
        NSLog(@"[WalletManager] ERROR writing wallet: %@", error);
        return NO;
    }
    
    // التحقق من الكتابة
    NSString *verifyContent = [NSString stringWithContentsOfFile:walletPath encoding:NSUTF8StringEncoding error:nil];
    if ([verifyContent isEqualToString:newContent]) {
        NSLog(@"[WalletManager] ✓ Wallet modified successfully - Unlimited: %@", enable ? @"YES" : @"NO");
        return YES;
    } else {
        NSLog(@"[WalletManager] ERROR: Wallet verification failed");
        return NO;
    }
}

+ (void)restoreWallet {
    NSLog(@"[WalletManager] Restoring original wallet...");
    [self modifyWalletWithUnlimited:NO];
}

@end
