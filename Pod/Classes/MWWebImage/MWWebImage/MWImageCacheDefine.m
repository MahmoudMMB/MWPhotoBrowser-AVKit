/*
 * This file is part of the MWWebImage package.
 * (c) Olivier Poitrey <rs@dailymotion.com>
 *
 * For the full copyright and license information, please view the LICENSE
 * file that was distributed with this source code.
 */

#import "MWImageCacheDefine.h"
#import "MWImageCodersManager.h"
#import "MWImageCoderHelper.h"
#import "MWAnimatedImage.h"
#import "UIImage+Metadata.h"
#import "MWInternalMacros.h"

UIImage * _Nullable MWImageCacheDecodeImageData(NSData * _Nonnull imageData, NSString * _Nonnull cacheKey, MWWebImageOptions options, MWWebImageContext * _Nullable context) {
    UIImage *image;
    BOOL decodeFirstFrame = MW_OPTIONS_CONTAINS(options, MWWebImageDecodeFirstFrameOnly);
    NSNumber *scaleValue = context[MWWebImageContextImageScaleFactor];
    CGFloat scale = scaleValue.doubleValue >= 1 ? scaleValue.doubleValue : MWImageScaleFactorForKey(cacheKey);
    NSNumber *preserveAspectRatioValue = context[MWWebImageContextImagePreserveAspectRatio];
    NSValue *thumbnailSizeValue;
    BOOL shouldScaleDown = MW_OPTIONS_CONTAINS(options, MWWebImageScaleDownLargeImages);
    if (shouldScaleDown) {
        CGFloat thumbnailPixels = MWImageCoderHelper.defaultScaleDownLimitBytes / 4;
        CGFloat dimension = ceil(sqrt(thumbnailPixels));
        thumbnailSizeValue = @(CGSizeMake(dimension, dimension));
    }
    if (context[MWWebImageContextImageThumbnailPixelSize]) {
        thumbnailSizeValue = context[MWWebImageContextImageThumbnailPixelSize];
    }
    
    MWImageCoderMutableOptions *mutableCoderOptions = [NSMutableDictionary dictionaryWithCapacity:2];
    mutableCoderOptions[MWImageCoderDecodeFirstFrameOnly] = @(decodeFirstFrame);
    mutableCoderOptions[MWImageCoderDecodeScaleFactor] = @(scale);
    mutableCoderOptions[MWImageCoderDecodePreserveAspectRatio] = preserveAspectRatioValue;
    mutableCoderOptions[MWImageCoderDecodeThumbnailPixelSize] = thumbnailSizeValue;
    mutableCoderOptions[MWImageCoderWebImageContext] = context;
    MWImageCoderOptions *coderOptions = [mutableCoderOptions copy];
    
    // Grab the image coder
    id<MWImageCoder> imageCoder;
    if ([context[MWWebImageContextImageCoder] conformsToProtocol:@protocol(MWImageCoder)]) {
        imageCoder = context[MWWebImageContextImageCoder];
    } else {
        imageCoder = [MWImageCodersManager sharedManager];
    }
    
    if (!decodeFirstFrame) {
        Class animatedImageClass = context[MWWebImageContextAnimatedImageClass];
        // check whether we should use `MWAnimatedImage`
        if ([animatedImageClass isSubclassOfClass:[UIImage class]] && [animatedImageClass conformsToProtocol:@protocol(MWAnimatedImage)]) {
            image = [[animatedImageClass alloc] initWithData:imageData scale:scale options:coderOptions];
            if (image) {
                // Preload frames if supported
                if (options & MWWebImagePreloadAllFrames && [image respondsToSelector:@selector(preloadAllFrames)]) {
                    [((id<MWAnimatedImage>)image) preloadAllFrames];
                }
            } else {
                // Check image class matching
                if (options & MWWebImageMatchAnimatedImageClass) {
                    return nil;
                }
            }
        }
    }
    if (!image) {
        image = [imageCoder decodedImageWithData:imageData options:coderOptions];
    }
    if (image) {
        BOOL shouldDecode = !MW_OPTIONS_CONTAINS(options, MWWebImageAvoidDecodeImage);
        if ([image.class conformsToProtocol:@protocol(MWAnimatedImage)]) {
            // `MWAnimatedImage` do not decode
            shouldDecode = NO;
        } else if (image.MW_isAnimated) {
            // animated image do not decode
            shouldDecode = NO;
        }
        if (shouldDecode) {
            image = [MWImageCoderHelper decodedImageWithImage:image];
        }
    }
    
    return image;
}
