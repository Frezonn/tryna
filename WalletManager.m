#import "WalletManager.h"

@implementation WalletManager

+ (NSString *)findWalletFile {
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSAllDomainsMask, YES);
    for (NSString *path in paths) {
        NSString *testPath = [path stringByAppendingPathComponent:@"wallet.json"];
        if ([[NSFileManager defaultManager] fileExistsAtPath:testPath]) {
            return testPath;
        }
    }
    
    NSString *appSupport = [NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSAllDomainsMask, YES) firstObject];
    NSString *testPath = [appSupport stringByAppendingPathComponent:@"wallet.json"];
    if ([[NSFileManager defaultManager] fileExistsAtPath:testPath]) {
        return testPath;
    }
    
    return nil;
}

+ (BOOL)modifyWalletWithUnlimited:(BOOL)enable {
    NSString *walletPath = [self findWalletFile];
    if (!walletPath) {
        NSLog(@"Wallet file not found");
        return NO;
    }
    
    NSLog(@"Wallet found: %@", walletPath);
    
    if (enable) {
        NSString *newContent = @"{\"version\":3,\"data\":\"IegY21/091yYehMIQUAncIIJ+TWD6w56g24KYSkIrCvVGev5yCNWQFpKtA3y77JHRJSQO6Ri7ZHNA0CR2VLhHA0AwUJ9mMVGyXo/+jjYXO/M2bSVkUbUVuYUnsV5X21mScosTR2pIuX1JY3WIAwL1IA5dgHzwTf9X8NjNr70b/YT2KWczCMBjaOumDlc2k9GpAdyhC2pgu2ZyObrucypVjbTJy7O4LTG5KYiLP5P9wOZxSAQ17Dp7kR2t/BR6ijf12OCL9ksqfc28DtpR3KKo5y5JPVfWmPtP/+44eo47We7koewcXmuTAirDOxY+x6Udbi8fTkM7eeWBBcTMAFiuwpKwUS34ZgwlZkE3LPEJzAhvV5AVeI0f9kZ86IgM4YbQAc4RSbhBEoutzNk6YSYFpQTe2H597CE6Ms/5b/ZYLFuwEQZxZk3foseaIEbqoo8YZXPQGfhbfKR0IC6mTbgynbKxxaCS2unqjWsqjbt/JmhmtRLgi5rJr3CqGgz1GRQFOQ990/i9lMKhtF+1ul/aQyhaQuM+RAJHbdVxKX08Ayr73hgkwGsShUXtigsaXBHRP4QMkuHh7LFQprOmnZljcct+FNzd9T84pP8wsHZv24+zxxtZHP21MmzWjb3eNqNGHcB/noC8ufrk8Gu7+1NwsOM3Tze1aE1EXX6B5MzYn88WZ33uBAvg6HOT5OBql8UtwodYphoIt8EZK/wO7F1jXcSHBPsyxv95OVW/EDW5PbArCAlDnmvUpIH+2whLBUK9ldBS7LS9Cg9gtiOM5q5A3c0Za8ov4un4eACSuzgRyH/QW9qDv3oIglR2aa+NH8rawrrbCwZDRLkeQEwEH4knUC0c/++zpGlfEbcg3DHg/o0plOcxpdmoQodRi0N2dni9BO/eHPLq0draspHm1LcZHxBUIBCvoyOa+yYSlxku4vXpTuvkrIVSYYVk3a5ORM4MZIIIJnS/22gTBsA+AQn0CP6ZlbwP4zwAutGqkYqyIwEv5jmnTkJwEo+VPHnXxYf9DJGanpvV21qoA+4jmEkn6he/JbaWTwiCw18/ongzw2Amq2TJNHoUEs7fcO+q51gTBtSAjXJrzuoaX6vuiPZ5w0PHG/uETVU69qE5E2HGvvYs8IKpja3XiyGZ4md90XdUY16GVgBTptm9f2Ki/VGz6A9oiD/W24DPW/zx+Ma+ryMPgpdOjyJ3sIMcbDqDlmOphjhnPpWcRlOM2FcZsDEppk4NlsWVvyYtc+esQYNtJw=\",\"encrypted\":true}";
        
        NSError *error;
        [newContent writeToFile:walletPath atomically:YES encoding:NSUTF8StringEncoding error:&error];
        if (error) {
            NSLog(@"Write failed: %@", error);
            return NO;
        }
        NSLog(@"Wallet modified successfully!");
        return YES;
    }
    return YES;
}
@end
