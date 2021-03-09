/*
* This file is part of the MWWebImage package.
* (c) Olivier Poitrey <rs@dailymotion.com>
*
* For the full copyright and license information, please view the LICENSE
* file that was distributed with this source code.
*/

#import "MWImageHEICCoder.h"
#import "MWImageIOAnimatedCoderInternal.h"

// These constants are available from iOS 13+ and Xcode 11. This raw value is used for toolchain and firmware compatibility
static NSString * kMWCGImagePropertyHEICMWictionary = @"{HEICS}";
static NSString * kMWCGImagePropertyHEICSLoopCount = @"LoopCount";
static NSString * kMWCGImagePropertyHEICMWelayTime = @"DelayTime";
static NSString * kMWCGImagePropertyHEICSUnclampedDelayTime = @"UnclampedDelayTime";

@implementation MWImageHEICCoder

+ (void)initialize {
#if __IPHONE_13_0 || __TVOS_13_0 || __MAC_10_15 || __WATCHOS_6_0
    // Xcode 11
    if (@available(iOS 13, tvOS 13, macOS 10.15, watchOS 6, *)) {
        // Use MWK instead of raw value
        kMWCGImagePropertyHEICMWictionary = (__bridge NSString *)kCGImagePropertyHEICSDictionary;
        kMWCGImagePropertyHEICSLoopCount = (__bridge NSString *)kCGImagePropertyHEICSLoopCount;
        kMWCGImagePropertyHEICMWelayTime = (__bridge NSString *)kCGImagePropertyHEICSDelayTime;
        kMWCGImagePropertyHEICSUnclampedDelayTime = (__bridge NSString *)kCGImagePropertyHEICSUnclampedDelayTime;
    }
#endif
}

+ (instancetype)sharedCoder {
    static MWImageHEICCoder *coder;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        coder = [[MWImageHEICCoder alloc] init];
    });
    return coder;
}

#pragma mark - MWImageCoder

- (BOOL)canDecodeFromData:(nullable NSData *)data {
    switch ([NSData MW_imageFormatForImageData:data]) {
        case MWImageFormatHEIC:
            // Check HEIC decoding compatibility
            return [self.class canDecodeFromFormat:MWImageFormatHEIC];
        case MWImageFormatHEIF:
            // Check HEIF decoding compatibility
            return [self.class canDecodeFromFormat:MWImageFormatHEIF];
        default:
            return NO;
    }
}

- (BOOL)canIncrementalDecodeFromData:(NSData *)data {
    return [self canDecodeFromData:data];
}

- (BOOL)canEncodeToFormat:(MWImageFormat)format {
    switch (format) {
        case MWImageFormatHEIC:
            // Check HEIC encoding compatibility
            return [self.class canEncodeToFormat:MWImageFormatHEIC];
        case MWImageFormatHEIF:
            // Check HEIF encoding compatibility
            return [self.class canEncodeToFormat:MWImageFormatHEIF];
        default:
            return NO;
    }
}

#pragma mark - Subclass Override

+ (MWImageFormat)imageFormat {
    return MWImageFormatHEIC;
}

+ (NSString *)imageUTType {
    return (__bridge NSString *)kMWUTTypeHEIC;
}

+ (NSString *)dictionaryProperty {
    return kMWCGImagePropertyHEICMWictionary;
}

+ (NSString *)unclampedDelayTimeProperty {
    return kMWCGImagePropertyHEICSUnclampedDelayTime;
}

+ (NSString *)delayTimeProperty {
    return kMWCGImagePropertyHEICMWelayTime;
}

+ (NSString *)loopCountProperty {
    return kMWCGImagePropertyHEICSLoopCount;
}

+ (NSUInteger)defaultLoopCount {
    return 0;
}

@end
