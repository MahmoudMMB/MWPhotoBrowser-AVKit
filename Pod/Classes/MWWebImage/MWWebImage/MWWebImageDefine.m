/*
 * This file is part of the MWWebImage package.
 * (c) Olivier Poitrey <rs@dailymotion.com>
 *
 * For the full copyright and license information, please view the LICENSE
 * file that was distributed with this source code.
 */

#import "MWWebImageDefine.h"
#import "UIImage+Metadata.h"
#import "NSImage+Compatibility.h"
#import "MWAssociatedObject.h"

#pragma mark - Image scale

static inline NSArray<NSNumber *> * _Nonnull MWImageScaleFactors() {
    return @[@2, @3];
}

inline CGFloat MWImageScaleFactorForKey(NSString * _Nullable key) {
    CGFloat scale = 1;
    if (!key) {
        return scale;
    }
    // Check if target OS support scale
#if MW_WATCH
    if ([[WKInterfaceDevice currentDevice] respondsToSelector:@selector(screenScale)])
#elif MW_UIKIT
    if ([[UIScreen mainScreen] respondsToSelector:@selector(scale)])
#elif MW_MAC
    if ([[NSScreen mainScreen] respondsToSelector:@selector(backingScaleFactor)])
#endif
    {
        // a@2x.png -> 8
        if (key.length >= 8) {
            // Fast check
            BOOL isURL = [key hasPrefix:@"http://"] || [key hasPrefix:@"https://"];
            for (NSNumber *scaleFactor in MWImageScaleFactors()) {
                // @2x. for file name and normal url
                NSString *fileScale = [NSString stringWithFormat:@"@%@x.", scaleFactor];
                if ([key containsString:fileScale]) {
                    scale = scaleFactor.doubleValue;
                    return scale;
                }
                if (isURL) {
                    // %402x. for url encode
                    NSString *urlScale = [NSString stringWithFormat:@"%%40%@x.", scaleFactor];
                    if ([key containsString:urlScale]) {
                        scale = scaleFactor.doubleValue;
                        return scale;
                    }
                }
            }
        }
    }
    return scale;
}

inline UIImage * _Nullable MWScaledImageForKey(NSString * _Nullable key, UIImage * _Nullable image) {
    if (!image) {
        return nil;
    }
    CGFloat scale = MWImageScaleFactorForKey(key);
    return MWScaledImageForScaleFactor(scale, image);
}

inline UIImage * _Nullable MWScaledImageForScaleFactor(CGFloat scale, UIImage * _Nullable image) {
    if (!image) {
        return nil;
    }
    if (scale <= 1) {
        return image;
    }
    if (scale == image.scale) {
        return image;
    }
    UIImage *scaledImage;
    if (image.MW_isAnimated) {
        UIImage *animatedImage;
#if MW_UIKIT || MW_WATCH
        // `UIAnimatedImage` images share the same size and scale.
        NSMutableArray<UIImage *> *scaledImages = [NSMutableArray array];
        
        for (UIImage *tempImage in image.images) {
            UIImage *tempScaledImage = [[UIImage alloc] initWithCGImage:tempImage.CGImage scale:scale orientation:tempImage.imageOrientation];
            [scaledImages addObject:tempScaledImage];
        }
        
        animatedImage = [UIImage animatedImageWithImages:scaledImages duration:image.duration];
        animatedImage.MW_imageLoopCount = image.MW_imageLoopCount;
#else
        // Animated GIF for `NSImage` need to grab `NSBitmapImageRep`;
        NSRect imageRect = NSMakeRect(0, 0, image.size.width, image.size.height);
        NSImageRep *imageRep = [image bestRepresentationForRect:imageRect context:nil hints:nil];
        NSBitmapImageRep *bitmapImageRep;
        if ([imageRep isKindOfClass:[NSBitmapImageRep class]]) {
            bitmapImageRep = (NSBitmapImageRep *)imageRep;
        }
        if (bitmapImageRep) {
            NSSize size = NSMakeSize(image.size.width / scale, image.size.height / scale);
            animatedImage = [[NSImage alloc] initWithSize:size];
            bitmapImageRep.size = size;
            [animatedImage addRepresentation:bitmapImageRep];
        }
#endif
        scaledImage = animatedImage;
    } else {
#if MW_UIKIT || MW_WATCH
        scaledImage = [[UIImage alloc] initWithCGImage:image.CGImage scale:scale orientation:image.imageOrientation];
#else
        scaledImage = [[UIImage alloc] initWithCGImage:image.CGImage scale:scale orientation:kCGImagePropertyOrientationUp];
#endif
    }
    MWImageCopyAssociatedObject(image, scaledImage);
    
    return scaledImage;
}

#pragma mark - Context option

MWWebImageContextOption const MWWebImageContextSetImageOperationKey = @"setImageOperationKey";
MWWebImageContextOption const MWWebImageContextCustomManager = @"customManager";
MWWebImageContextOption const MWWebImageContextImageCache = @"imageCache";
MWWebImageContextOption const MWWebImageContextImageLoader = @"imageLoader";
MWWebImageContextOption const MWWebImageContextImageCoder = @"imageCoder";
MWWebImageContextOption const MWWebImageContextImageTransformer = @"imageTransformer";
MWWebImageContextOption const MWWebImageContextImageScaleFactor = @"imageScaleFactor";
MWWebImageContextOption const MWWebImageContextImagePreserveAspectRatio = @"imagePreserveAspectRatio";
MWWebImageContextOption const MWWebImageContextImageThumbnailPixelSize = @"imageThumbnailPixelSize";
MWWebImageContextOption const MWWebImageContextQueryCacheType = @"queryCacheType";
MWWebImageContextOption const MWWebImageContextStoreCacheType = @"storeCacheType";
MWWebImageContextOption const MWWebImageContextOriginalQueryCacheType = @"originalQueryCacheType";
MWWebImageContextOption const MWWebImageContextOriginalStoreCacheType = @"originalStoreCacheType";
MWWebImageContextOption const MWWebImageContextAnimatedImageClass = @"animatedImageClass";
MWWebImageContextOption const MWWebImageContextDownloadRequestModifier = @"downloadRequestModifier";
MWWebImageContextOption const MWWebImageContextDownloadResponseModifier = @"downloadResponseModifier";
MWWebImageContextOption const MWWebImageContextDownloadDecryptor = @"downloadDecryptor";
MWWebImageContextOption const MWWebImageContextCacheKeyFilter = @"cacheKeyFilter";
MWWebImageContextOption const MWWebImageContextCacheSerializer = @"cacheSerializer";
