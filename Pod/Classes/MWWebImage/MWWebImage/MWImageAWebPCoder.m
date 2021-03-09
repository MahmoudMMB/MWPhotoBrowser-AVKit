/*
* This file is part of the MWWebImage package.
* (c) Olivier Poitrey <rs@dailymotion.com>
*
* For the full copyright and license information, please view the LICENSE
* file that was distributed with this source code.
*/

#import "MWImageAWebPCoder.h"
#import "MWImageIOAnimatedCoderInternal.h"

// These constants are available from iOS 14+ and Xcode 12. This raw value is used for toolchain and firmware compatibility
static NSString * kMWCGImagePropertyWebPDictionary = @"{WebP}";
static NSString * kMWCGImagePropertyWebPLoopCount = @"LoopCount";
static NSString * kMWCGImagePropertyWebPDelayTime = @"DelayTime";
static NSString * kMWCGImagePropertyWebPUnclampedDelayTime = @"UnclampedDelayTime";

@implementation MWImageAWebPCoder

+ (void)initialize {
#if __IPHONE_14_0 || __TVOS_14_0 || __MAC_11_0 || __WATCHOS_7_0
    // Xcode 12
    if (@available(iOS 14, tvOS 14, macOS 11, watchOS 7, *)) {
        // Use MWK instead of raw value
        kMWCGImagePropertyWebPDictionary = (__bridge NSString *)kCGImagePropertyWebPDictionary;
        kMWCGImagePropertyWebPLoopCount = (__bridge NSString *)kCGImagePropertyWebPLoopCount;
        kMWCGImagePropertyWebPDelayTime = (__bridge NSString *)kCGImagePropertyWebPDelayTime;
        kMWCGImagePropertyWebPUnclampedDelayTime = (__bridge NSString *)kCGImagePropertyWebPUnclampedDelayTime;
    }
#endif
}

+ (instancetype)sharedCoder {
    static MWImageAWebPCoder *coder;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        coder = [[MWImageAWebPCoder alloc] init];
    });
    return coder;
}

#pragma mark - MWImageCoder

- (BOOL)canDecodeFromData:(nullable NSData *)data {
    switch ([NSData MW_imageFormatForImageData:data]) {
        case MWImageFormatWebP:
            // Check WebP decoding compatibility
            return [self.class canDecodeFromFormat:MWImageFormatWebP];
        default:
            return NO;
    }
}

- (BOOL)canIncrementalDecodeFromData:(NSData *)data {
    return [self canDecodeFromData:data];
}

- (BOOL)canEncodeToFormat:(MWImageFormat)format {
    switch (format) {
        case MWImageFormatWebP:
            // Check WebP encoding compatibility
            return [self.class canEncodeToFormat:MWImageFormatWebP];
        default:
            return NO;
    }
}

#pragma mark - Subclass Override

+ (MWImageFormat)imageFormat {
    return MWImageFormatWebP;
}

+ (NSString *)imageUTType {
    return (__bridge NSString *)kMWUTTypeWebP;
}

+ (NSString *)dictionaryProperty {
    return kMWCGImagePropertyWebPDictionary;
}

+ (NSString *)unclampedDelayTimeProperty {
    return kMWCGImagePropertyWebPUnclampedDelayTime;
}

+ (NSString *)delayTimeProperty {
    return kMWCGImagePropertyWebPDelayTime;
}

+ (NSString *)loopCountProperty {
    return kMWCGImagePropertyWebPLoopCount;
}

+ (NSUInteger)defaultLoopCount {
    return 0;
}

@end
