/*
 * This file is part of the MWWebImage package.
 * (c) Olivier Poitrey <rs@dailymotion.com>
 *
 * For the full copyright and license information, please view the LICENSE
 * file that was distributed with this source code.
 */

#import "MWAnimatedImage.h"
#import "NSImage+Compatibility.h"
#import "MWImageCoder.h"
#import "MWImageCodersManager.h"
#import "MWImageFrame.h"
#import "UIImage+MemoryCacheCost.h"
#import "UIImage+Metadata.h"
#import "UIImage+MultiFormat.h"
#import "MWImageCoderHelper.h"
#import "MWImageAssetManager.h"
#import "objc/runtime.h"

static CGFloat MWImageScaleFromPath(NSString *string) {
    if (string.length == 0 || [string hasSuffix:@"/"]) return 1;
    NSString *name = string.stringByDeletingPathExtension;
    __block CGFloat scale = 1;
    
    NSRegularExpression *pattern = [NSRegularExpression regularExpressionWithPattern:@"@[0-9]+\\.?[0-9]*x$" options:NSRegularExpressionAnchorsMatchLines error:nil];
    [pattern enumerateMatchesInString:name options:kNilOptions range:NSMakeRange(0, name.length) usingBlock:^(NSTextCheckingResult *result, NSMatchingFlags flags, BOOL *stop) {
        scale = [string substringWithRange:NSMakeRange(result.range.location + 1, result.range.length - 2)].doubleValue;
    }];
    
    return scale;
}

@interface MWAnimatedImage ()

@property (nonatomic, strong) id<MWAnimatedImageCoder> animatedCoder;
@property (nonatomic, assign, readwrite) MWImageFormat animatedImageFormat;
@property (atomic, copy) NSArray<MWImageFrame *> *loadedAnimatedImageFrames; // Mark as atomic to keep thread-safe
@property (nonatomic, assign, getter=isAllFramesLoaded) BOOL allFramesLoaded;

@end

@implementation MWAnimatedImage
@dynamic scale; // call super

#pragma mark - UIImage override method
+ (instancetype)imageNamed:(NSString *)name {
#if __has_include(<UIKit/UITraitCollection.h>)
    return [self imageNamed:name inBundle:nil compatibleWithTraitCollection:nil];
#else
    return [self imageNamed:name inBundle:nil];
#endif
}

#if __has_include(<UIKit/UITraitCollection.h>)
+ (instancetype)imageNamed:(NSString *)name inBundle:(NSBundle *)bundle compatibleWithTraitCollection:(UITraitCollection *)traitCollection {
    if (!traitCollection) {
        traitCollection = UIScreen.mainScreen.traitCollection;
    }
    CGFloat scale = traitCollection.displayScale;
    return [self imageNamed:name inBundle:bundle scale:scale];
}
#else
+ (instancetype)imageNamed:(NSString *)name inBundle:(NSBundle *)bundle {
    return [self imageNamed:name inBundle:bundle scale:0];
}
#endif

// 0 scale means automatically check
+ (instancetype)imageNamed:(NSString *)name inBundle:(NSBundle *)bundle scale:(CGFloat)scale {
    if (!name) {
        return nil;
    }
    if (!bundle) {
        bundle = [NSBundle mainBundle];
    }
    MWImageAssetManager *assetManager = [MWImageAssetManager sharedAssetManager];
    MWAnimatedImage *image = (MWAnimatedImage *)[assetManager imageForName:name];
    if ([image isKindOfClass:[MWAnimatedImage class]]) {
        return image;
    }
    NSString *path = [assetManager getPathForName:name bundle:bundle preferredScale:&scale];
    if (!path) {
        return image;
    }
    NSData *data = [NSData dataWithContentsOfFile:path];
    if (!data) {
        return image;
    }
    image = [[self alloc] initWithData:data scale:scale];
    if (image) {
        [assetManager storeImage:image forName:name];
    }
    
    return image;
}

+ (instancetype)imageWithContentsOfFile:(NSString *)path {
    return [[self alloc] initWithContentsOfFile:path];
}

+ (instancetype)imageWithData:(NSData *)data {
    return [[self alloc] initWithData:data];
}

+ (instancetype)imageWithData:(NSData *)data scale:(CGFloat)scale {
    return [[self alloc] initWithData:data scale:scale];
}

- (instancetype)initWithContentsOfFile:(NSString *)path {
    NSData *data = [NSData dataWithContentsOfFile:path];
    return [self initWithData:data scale:MWImageScaleFromPath(path)];
}

- (instancetype)initWithData:(NSData *)data {
    return [self initWithData:data scale:1];
}

- (instancetype)initWithData:(NSData *)data scale:(CGFloat)scale {
    return [self initWithData:data scale:scale options:nil];
}

- (instancetype)initWithData:(NSData *)data scale:(CGFloat)scale options:(MWImageCoderOptions *)options {
    if (!data || data.length == 0) {
        return nil;
    }
    data = [data copy]; // avoid mutable data
    id<MWAnimatedImageCoder> animatedCoder = nil;
    for (id<MWImageCoder>coder in [MWImageCodersManager sharedManager].coders.reverseObjectEnumerator) {
        if ([coder conformsToProtocol:@protocol(MWAnimatedImageCoder)]) {
            if ([coder canDecodeFromData:data]) {
                if (!options) {
                    options = @{MWImageCoderDecodeScaleFactor : @(scale)};
                }
                animatedCoder = [[[coder class] alloc] initWithAnimatedImageData:data options:options];
                break;
            }
        }
    }
    if (!animatedCoder) {
        return nil;
    }
    return [self initWithAnimatedCoder:animatedCoder scale:scale];
}

- (instancetype)initWithAnimatedCoder:(id<MWAnimatedImageCoder>)animatedCoder scale:(CGFloat)scale {
    if (!animatedCoder) {
        return nil;
    }
    UIImage *image = [animatedCoder animatedImageFrameAtIndex:0];
    if (!image) {
        return nil;
    }
#if MW_MAC
    self = [super initWithCGImage:image.CGImage scale:MAX(scale, 1) orientation:kCGImagePropertyOrientationUp];
#else
    self = [super initWithCGImage:image.CGImage scale:MAX(scale, 1) orientation:image.imageOrientation];
#endif
    if (self) {
        // Only keep the animated coder if frame count > 1, save RAM usage for non-animated image format (APNG/WebP)
        if (animatedCoder.animatedImageFrameCount > 1) {
            _animatedCoder = animatedCoder;
        }
        NSData *data = [animatedCoder animatedImageData];
        MWImageFormat format = [NSData MW_imageFormatForImageData:data];
        _animatedImageFormat = format;
    }
    return self;
}

#pragma mark - Preload
- (void)preloadAllFrames {
    if (!_animatedCoder) {
        return;
    }
    if (!self.isAllFramesLoaded) {
        NSMutableArray<MWImageFrame *> *frames = [NSMutableArray arrayWithCapacity:self.animatedImageFrameCount];
        for (size_t i = 0; i < self.animatedImageFrameCount; i++) {
            UIImage *image = [self animatedImageFrameAtIndex:i];
            NSTimeInterval duration = [self animatedImageDurationAtIndex:i];
            MWImageFrame *frame = [MWImageFrame frameWithImage:image duration:duration]; // through the image should be nonnull, used as nullable for `animatedImageFrameAtIndex:`
            [frames addObject:frame];
        }
        self.loadedAnimatedImageFrames = frames;
        self.allFramesLoaded = YES;
    }
}

- (void)unloadAllFrames {
    if (!_animatedCoder) {
        return;
    }
    if (self.isAllFramesLoaded) {
        self.loadedAnimatedImageFrames = nil;
        self.allFramesLoaded = NO;
    }
}

#pragma mark - NSSecureCoding
- (instancetype)initWithCoder:(NSCoder *)aDecoder {
    self = [super initWithCoder:aDecoder];
    if (self) {
        _animatedImageFormat = [aDecoder decodeIntegerForKey:NSStringFromSelector(@selector(animatedImageFormat))];
        NSData *animatedImageData = [aDecoder decodeObjectOfClass:[NSData class] forKey:NSStringFromSelector(@selector(animatedImageData))];
        if (!animatedImageData) {
            return self;
        }
        CGFloat scale = self.scale;
        id<MWAnimatedImageCoder> animatedCoder = nil;
        for (id<MWImageCoder>coder in [MWImageCodersManager sharedManager].coders.reverseObjectEnumerator) {
            if ([coder conformsToProtocol:@protocol(MWAnimatedImageCoder)]) {
                if ([coder canDecodeFromData:animatedImageData]) {
                    animatedCoder = [[[coder class] alloc] initWithAnimatedImageData:animatedImageData options:@{MWImageCoderDecodeScaleFactor : @(scale)}];
                    break;
                }
            }
        }
        if (!animatedCoder) {
            return self;
        }
        if (animatedCoder.animatedImageFrameCount > 1) {
            _animatedCoder = animatedCoder;
        }
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)aCoder {
    [super encodeWithCoder:aCoder];
    [aCoder encodeInteger:self.animatedImageFormat forKey:NSStringFromSelector(@selector(animatedImageFormat))];
    NSData *animatedImageData = self.animatedImageData;
    if (animatedImageData) {
        [aCoder encodeObject:animatedImageData forKey:NSStringFromSelector(@selector(animatedImageData))];
    }
}

+ (BOOL)supportsSecureCoding {
    return YES;
}

#pragma mark - MWAnimatedImageProvider

- (NSData *)animatedImageData {
    return [self.animatedCoder animatedImageData];
}

- (NSUInteger)animatedImageLoopCount {
    return [self.animatedCoder animatedImageLoopCount];
}

- (NSUInteger)animatedImageFrameCount {
    return [self.animatedCoder animatedImageFrameCount];
}

- (UIImage *)animatedImageFrameAtIndex:(NSUInteger)index {
    if (index >= self.animatedImageFrameCount) {
        return nil;
    }
    if (self.isAllFramesLoaded) {
        MWImageFrame *frame = [self.loadedAnimatedImageFrames objectAtIndex:index];
        return frame.image;
    }
    return [self.animatedCoder animatedImageFrameAtIndex:index];
}

- (NSTimeInterval)animatedImageDurationAtIndex:(NSUInteger)index {
    if (index >= self.animatedImageFrameCount) {
        return 0;
    }
    if (self.isAllFramesLoaded) {
        MWImageFrame *frame = [self.loadedAnimatedImageFrames objectAtIndex:index];
        return frame.duration;
    }
    return [self.animatedCoder animatedImageDurationAtIndex:index];
}

@end

@implementation MWAnimatedImage (MemoryCacheCost)

- (NSUInteger)MW_memoryCost {
    NSNumber *value = objc_getAssociatedObject(self, @selector(MW_memoryCost));
    if (value != nil) {
        return value.unsignedIntegerValue;
    }
    
    CGImageRef imageRef = self.CGImage;
    if (!imageRef) {
        return 0;
    }
    NSUInteger bytesPerFrame = CGImageGetBytesPerRow(imageRef) * CGImageGetHeight(imageRef);
    NSUInteger frameCount = 1;
    if (self.isAllFramesLoaded) {
        frameCount = self.animatedImageFrameCount;
    }
    frameCount = frameCount > 0 ? frameCount : 1;
    NSUInteger cost = bytesPerFrame * frameCount;
    return cost;
}

@end

@implementation MWAnimatedImage (Metadata)

- (BOOL)MW_isAnimated {
    return YES;
}

- (NSUInteger)MW_imageLoopCount {
    return self.animatedImageLoopCount;
}

- (void)setMW_imageLoopCount:(NSUInteger)MW_imageLoopCount {
    return;
}

- (MWImageFormat)MW_imageFormat {
    return self.animatedImageFormat;
}

- (void)setMW_imageFormat:(MWImageFormat)MW_imageFormat {
    return;
}

- (BOOL)MW_isVector {
    return NO;
}

@end

@implementation MWAnimatedImage (MultiFormat)

+ (nullable UIImage *)MW_imageWithData:(nullable NSData *)data {
    return [self MW_imageWithData:data scale:1];
}

+ (nullable UIImage *)MW_imageWithData:(nullable NSData *)data scale:(CGFloat)scale {
    return [self MW_imageWithData:data scale:scale firstFrameOnly:NO];
}

+ (nullable UIImage *)MW_imageWithData:(nullable NSData *)data scale:(CGFloat)scale firstFrameOnly:(BOOL)firstFrameOnly {
    if (!data) {
        return nil;
    }
    return [[self alloc] initWithData:data scale:scale options:@{MWImageCoderDecodeFirstFrameOnly : @(firstFrameOnly)}];
}

- (nullable NSData *)MW_imageData {
    NSData *imageData = self.animatedImageData;
    if (imageData) {
        return imageData;
    } else {
        return [self MW_imageDataAsFormat:self.animatedImageFormat];
    }
}

- (nullable NSData *)MW_imageDataAsFormat:(MWImageFormat)imageFormat {
    return [self MW_imageDataAsFormat:imageFormat compressionQuality:1];
}

- (nullable NSData *)MW_imageDataAsFormat:(MWImageFormat)imageFormat compressionQuality:(double)compressionQuality {
    return [self MW_imageDataAsFormat:imageFormat compressionQuality:compressionQuality firstFrameOnly:NO];
}

- (nullable NSData *)MW_imageDataAsFormat:(MWImageFormat)imageFormat compressionQuality:(double)compressionQuality firstFrameOnly:(BOOL)firstFrameOnly {
    if (firstFrameOnly) {
        // First frame, use super implementation
        return [super MW_imageDataAsFormat:imageFormat compressionQuality:compressionQuality firstFrameOnly:firstFrameOnly];
    }
    NSUInteger frameCount = self.animatedImageFrameCount;
    if (frameCount <= 1) {
        // Static image, use super implementation
        return [super MW_imageDataAsFormat:imageFormat compressionQuality:compressionQuality firstFrameOnly:firstFrameOnly];
    }
    // Keep animated image encoding, loop each frame.
    NSMutableArray<MWImageFrame *> *frames = [NSMutableArray arrayWithCapacity:frameCount];
    for (size_t i = 0; i < frameCount; i++) {
        UIImage *image = [self animatedImageFrameAtIndex:i];
        NSTimeInterval duration = [self animatedImageDurationAtIndex:i];
        MWImageFrame *frame = [MWImageFrame frameWithImage:image duration:duration];
        [frames addObject:frame];
    }
    UIImage *animatedImage = [MWImageCoderHelper animatedImageWithFrames:frames];
    NSData *imageData = [animatedImage MW_imageDataAsFormat:imageFormat compressionQuality:compressionQuality firstFrameOnly:firstFrameOnly];
    return imageData;
}

@end
