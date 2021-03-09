/*
 * This file is part of the MWWebImage package.
 * (c) Olivier Poitrey <rs@dailymotion.com>
 *
 * For the full copyright and license information, please view the LICENSE
 * file that was distributed with this source code.
 */

#import "MWImageLoader.h"
#import "MWWebImageCacheKeyFilter.h"
#import "MWImageCodersManager.h"
#import "MWImageCoderHelper.h"
#import "MWAnimatedImage.h"
#import "UIImage+Metadata.h"
#import "MWInternalMacros.h"
#import "objc/runtime.h"

static void * MWImageLoaderProgressiveCoderKey = &MWImageLoaderProgressiveCoderKey;

UIImage * _Nullable MWImageLoaderDecodeImageData(NSData * _Nonnull imageData, NSURL * _Nonnull imageURL, MWWebImageOptions options, MWWebImageContext * _Nullable context) {
    NSCParameterAssert(imageData);
    NSCParameterAssert(imageURL);
    
    UIImage *image;
    id<MWWebImageCacheKeyFilter> cacheKeyFilter = context[MWWebImageContextCacheKeyFilter];
    NSString *cacheKey;
    if (cacheKeyFilter) {
        cacheKey = [cacheKeyFilter cacheKeyForURL:imageURL];
    } else {
        cacheKey = imageURL.absoluteString;
    }
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
        // check whether we should use `MWAnimatedImage`
        Class animatedImageClass = context[MWWebImageContextAnimatedImageClass];
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

UIImage * _Nullable MWImageLoaderDecodeProgressiveImageData(NSData * _Nonnull imageData, NSURL * _Nonnull imageURL, BOOL finished,  id<MWWebImageOperation> _Nonnull operation, MWWebImageOptions options, MWWebImageContext * _Nullable context) {
    NSCParameterAssert(imageData);
    NSCParameterAssert(imageURL);
    NSCParameterAssert(operation);
    
    UIImage *image;
    id<MWWebImageCacheKeyFilter> cacheKeyFilter = context[MWWebImageContextCacheKeyFilter];
    NSString *cacheKey;
    if (cacheKeyFilter) {
        cacheKey = [cacheKeyFilter cacheKeyForURL:imageURL];
    } else {
        cacheKey = imageURL.absoluteString;
    }
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
    
    // Grab the progressive image coder
    id<MWProgressiveImageCoder> progressiveCoder = objc_getAssociatedObject(operation, MWImageLoaderProgressiveCoderKey);
    if (!progressiveCoder) {
        id<MWProgressiveImageCoder> imageCoder = context[MWWebImageContextImageCoder];
        // Check the progressive coder if provided
        if ([imageCoder conformsToProtocol:@protocol(MWProgressiveImageCoder)]) {
            progressiveCoder = [[[imageCoder class] alloc] initIncrementalWithOptions:coderOptions];
        } else {
            // We need to create a new instance for progressive decoding to avoid conflicts
            for (id<MWImageCoder> coder in [MWImageCodersManager sharedManager].coders.reverseObjectEnumerator) {
                if ([coder conformsToProtocol:@protocol(MWProgressiveImageCoder)] &&
                    [((id<MWProgressiveImageCoder>)coder) canIncrementalDecodeFromData:imageData]) {
                    progressiveCoder = [[[coder class] alloc] initIncrementalWithOptions:coderOptions];
                    break;
                }
            }
        }
        objc_setAssociatedObject(operation, MWImageLoaderProgressiveCoderKey, progressiveCoder, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    // If we can't find any progressive coder, disable progressive download
    if (!progressiveCoder) {
        return nil;
    }
    
    [progressiveCoder updateIncrementalData:imageData finished:finished];
    if (!decodeFirstFrame) {
        // check whether we should use `MWAnimatedImage`
        Class animatedImageClass = context[MWWebImageContextAnimatedImageClass];
        if ([animatedImageClass isSubclassOfClass:[UIImage class]] && [animatedImageClass conformsToProtocol:@protocol(MWAnimatedImage)] && [progressiveCoder conformsToProtocol:@protocol(MWAnimatedImageCoder)]) {
            image = [[animatedImageClass alloc] initWithAnimatedCoder:(id<MWAnimatedImageCoder>)progressiveCoder scale:scale];
            if (image) {
                // Progressive decoding does not preload frames
            } else {
                // Check image class matching
                if (options & MWWebImageMatchAnimatedImageClass) {
                    return nil;
                }
            }
        }
    }
    if (!image) {
        image = [progressiveCoder incrementalDecodedImageWithOptions:coderOptions];
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
        // mark the image as progressive (completionBlock one are not mark as progressive)
        image.MW_isIncremental = YES;
    }
    
    return image;
}

MWWebImageContextOption const MWWebImageContextLoaderCachedImage = @"loaderCachedImage";
