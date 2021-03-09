/*
 * This file is part of the MWWebImage package.
 * (c) Olivier Poitrey "rs@dailymotion.com"
 * (c) Florent Vilmart
 *
 * For the full copyright and license information, please view the LICENSE
 * file that was distributed with this source code.
 */

#import "MWWebImageCompat.h"

//! Project version number for MWWebImage.
FOUNDATION_EXPORT double MWWebImageVersionNumber;

//! Project version string for MWWebImage.
FOUNDATION_EXPORT const unsigned char MWWebImageVersionString[];

// In this header, you should import all the public headers of your framework using statements like #import "PublicHeader.h"

#import "MWWebImageManager.h"
#import "MWWebImageCacheKeyFilter.h"
#import "MWWebImageCacheSerializer.h"
#import "MWImageCacheConfig.h"
#import "MWImageCache.h"
#import "MWMemoryCache.h"
#import "MWDiskCache.h"
#import "MWImageCacheDefine.h"
#import "MWImageCachesManager.h"
#import "UIView+WebCache.h"
#import "UIImageView+WebCache.h"
#import "UIImageView+HighlightedWebCache.h"
#import "MWWebImageDownloaderConfig.h"
#import "MWWebImageDownloaderOperation.h"
#import "MWWebImageDownloaderRequestModifier.h"
#import "MWWebImageDownloaderResponseModifier.h"
#import "MWWebImageDownloaderDecryptor.h"
#import "MWImageLoader.h"
#import "MWImageLoadersManager.h"
#import "UIButton+WebCache.h"
#import "MWWebImagePrefetcher.h"
#import "UIView+WebCacheOperation.h"
#import "UIImage+Metadata.h"
#import "UIImage+MultiFormat.h"
#import "UIImage+MemoryCacheCost.h"
#import "UIImage+ExtendedCacheData.h"
#import "MWWebImageOperation.h"
#import "MWWebImageDownloader.h"
#import "MWWebImageTransition.h"
#import "MWWebImageIndicator.h"
#import "MWImageTransformer.h"
#import "UIImage+Transform.h"
#import "MWAnimatedImage.h"
#import "MWAnimatedImageView.h"
#import "MWAnimatedImageView+WebCache.h"
#import "MWAnimatedImagePlayer.h"
#import "MWImageCodersManager.h"
#import "MWImageCoder.h"
#import "MWImageAPNGCoder.h"
#import "MWImageGIFCoder.h"
#import "MWImageIOCoder.h"
#import "MWImageFrame.h"
#import "MWImageCoderHelper.h"
#import "MWImageGraphics.h"
#import "MWGraphicsImageRenderer.h"
#import "UIImage+GIF.h"
#import "UIImage+ForceDecode.h"
#import "NMWata+ImageContentType.h"
#import "MWWebImageDefine.h"
#import "MWWebImageError.h"
#import "MWWebImageOptionsProcessor.h"
#import "MWImageIOAnimatedCoder.h"
#import "MWImageHEICCoder.h"
#import "MWImageAWebPCoder.h"

// Mac
#if __has_include("NSImage+Compatibility.h")
#import "NSImage+Compatibility.h"
#endif
#if __has_include("NSButton+WebCache.h")
#import "NSButton+WebCache.h"
#endif
#if __has_include("MWAnimatedImageRep.h")
#import "MWAnimatedImageRep.h"
#endif

// MapKit
#if __has_include("MKAnnotationView+WebCache.h")
#import "MKAnnotationView+WebCache.h"
#endif
