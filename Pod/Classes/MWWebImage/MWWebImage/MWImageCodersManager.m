/*
 * This file is part of the MWWebImage package.
 * (c) Olivier Poitrey <rs@dailymotion.com>
 *
 * For the full copyright and license information, please view the LICENSE
 * file that was distributed with this source code.
 */

#import "MWImageCodersManager.h"
#import "MWImageIOCoder.h"
#import "MWImageGIFCoder.h"
#import "MWImageAPNGCoder.h"
#import "MWImageHEICCoder.h"
#import "MWInternalMacros.h"

@interface MWImageCodersManager ()

@property (nonatomic, strong, nonnull) dispatch_semaphore_t codersLock;

@end

@implementation MWImageCodersManager
{
    NSMutableArray<id<MWImageCoder>> *_imageCoders;
}

+ (nonnull instancetype)sharedManager {
    static dispatch_once_t once;
    static id instance;
    dispatch_once(&once, ^{
        instance = [self new];
    });
    return instance;
}

- (instancetype)init {
    if (self = [super init]) {
        // initialize with default coders
        _imageCoders = [NSMutableArray arrayWithArray:@[[MWImageIOCoder sharedCoder], [MWImageGIFCoder sharedCoder], [MWImageAPNGCoder sharedCoder]]];
        _codersLock = dispatch_semaphore_create(1);
    }
    return self;
}

- (NSArray<id<MWImageCoder>> *)coders
{
    MW_LOCK(self.codersLock);
    NSArray<id<MWImageCoder>> *coders = [_imageCoders copy];
    MW_UNLOCK(self.codersLock);
    return coders;
}

- (void)setCoders:(NSArray<id<MWImageCoder>> *)coders
{
    MW_LOCK(self.codersLock);
    [_imageCoders removeAllObjects];
    if (coders.count) {
        [_imageCoders addObjectsFromArray:coders];
    }
    MW_UNLOCK(self.codersLock);
}

#pragma mark - Coder IO operations

- (void)addCoder:(nonnull id<MWImageCoder>)coder {
    if (![coder conformsToProtocol:@protocol(MWImageCoder)]) {
        return;
    }
    MW_LOCK(self.codersLock);
    [_imageCoders addObject:coder];
    MW_UNLOCK(self.codersLock);
}

- (void)removeCoder:(nonnull id<MWImageCoder>)coder {
    if (![coder conformsToProtocol:@protocol(MWImageCoder)]) {
        return;
    }
    MW_LOCK(self.codersLock);
    [_imageCoders removeObject:coder];
    MW_UNLOCK(self.codersLock);
}

#pragma mark - MWImageCoder
- (BOOL)canDecodeFromData:(NSData *)data {
    NSArray<id<MWImageCoder>> *coders = self.coders;
    for (id<MWImageCoder> coder in coders.reverseObjectEnumerator) {
        if ([coder canDecodeFromData:data]) {
            return YES;
        }
    }
    return NO;
}

- (BOOL)canEncodeToFormat:(MWImageFormat)format {
    NSArray<id<MWImageCoder>> *coders = self.coders;
    for (id<MWImageCoder> coder in coders.reverseObjectEnumerator) {
        if ([coder canEncodeToFormat:format]) {
            return YES;
        }
    }
    return NO;
}

- (UIImage *)decodedImageWithData:(NSData *)data options:(nullable MWImageCoderOptions *)options {
    if (!data) {
        return nil;
    }
    UIImage *image;
    NSArray<id<MWImageCoder>> *coders = self.coders;
    for (id<MWImageCoder> coder in coders.reverseObjectEnumerator) {
        if ([coder canDecodeFromData:data]) {
            image = [coder decodedImageWithData:data options:options];
            break;
        }
    }
    
    return image;
}

- (NSData *)encodedDataWithImage:(UIImage *)image format:(MWImageFormat)format options:(nullable MWImageCoderOptions *)options {
    if (!image) {
        return nil;
    }
    NSArray<id<MWImageCoder>> *coders = self.coders;
    for (id<MWImageCoder> coder in coders.reverseObjectEnumerator) {
        if ([coder canEncodeToFormat:format]) {
            return [coder encodedDataWithImage:image format:format options:options];
        }
    }
    return nil;
}

@end
