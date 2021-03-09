/*
 * This file is part of the MWWebImage package.
 * (c) Olivier Poitrey <rs@dailymotion.com>
 *
 * For the full copyright and license information, please view the LICENSE
 * file that was distributed with this source code.
 */

#import <Foundation/Foundation.h>
#import "MWWebImageCompat.h"
#import "MWWebImageOperation.h"
#import "MWWebImageDefine.h"

/// Image Cache Type
typedef NS_ENUM(NSInteger, MWImageCacheType) {
    /**
     * For query and contains op in response, means the image isn't available in the image cache
     * For op in request, this type is not available and take no effect.
     */
    MWImageCacheTypeNone,
    /**
     * For query and contains op in response, means the image was obtained from the disk cache.
     * For op in request, means process only disk cache.
     */
    MWImageCacheTypeDisk,
    /**
     * For query and contains op in response, means the image was obtained from the memory cache.
     * For op in request, means process only memory cache.
     */
    MWImageCacheTypeMemory,
    /**
     * For query and contains op in response, this type is not available and take no effect.
     * For op in request, means process both memory cache and disk cache.
     */
    MWImageCacheTypeAll
};

typedef void(^MWImageCacheCheckCompletionBlock)(BOOL isInCache);
typedef void(^MWImageCacheQueryDataCompletionBlock)(NSData * _Nullable data);
typedef void(^MWImageCacheCalculateSizeBlock)(NSUInteger fileCount, NSUInteger totalSize);
typedef NSString * _Nullable (^MWImageCacheAdditionalCachePathBlock)(NSString * _Nonnull key);
typedef void(^MWImageCacheQueryCompletionBlock)(UIImage * _Nullable image, NSData * _Nullable data, MWImageCacheType cacheType);
typedef void(^MWImageCacheContainsCompletionBlock)(MWImageCacheType containsCacheType);

/**
 This is the built-in decoding process for image query from cache.
 @note If you want to implement your custom loader with `queryImageForKey:options:context:completion:` API, but also want to keep compatible with MWWebImage's behavior, you'd better use this to produce image.
 
 @param imageData The image data from the cache. Should not be nil
 @param cacheKey The image cache key from the input. Should not be nil
 @param options The options arg from the input
 @param context The context arg from the input
 @return The decoded image for current image data query from cache
 */
FOUNDATION_EXPORT UIImage * _Nullable MWImageCacheDecodeImageData(NSData * _Nonnull imageData, NSString * _Nonnull cacheKey, MWWebImageOptions options, MWWebImageContext * _Nullable context);

/**
 This is the image cache protocol to provide custom image cache for `MWWebImageManager`.
 Though the best practice to custom image cache, is to write your own class which conform `MWMemoryCache` or `MWDiskCache` protocol for `MWImageCache` class (See more on `MWImageCacheConfig.memoryCacheClass & MWImageCacheConfig.diskCacheClass`).
 However, if your own cache implementation contains more advanced feature beyond `MWImageCache` itself, you can consider to provide this instead. For example, you can even use a cache manager like `MWImageCachesManager` to register multiple caches.
 */
@protocol MWImageCache <NSObject>

@required
/**
 Query the cached image from image cache for given key. The operation can be used to cancel the query.
 If image is cached in memory, completion is called synchronously, else asynchronously and depends on the options arg (See `MWWebImageQueryDiskSync`)

 @param key The image cache key
 @param options A mask to specify options to use for this query
 @param context A context contains different options to perform specify changes or processes, see `MWWebImageContextOption`. This hold the extra objects which `options` enum can not hold.
 @param completionBlock The completion block. Will not get called if the operation is cancelled
 @return The operation for this query
 */
- (nullable id<MWWebImageOperation>)queryImageForKey:(nullable NSString *)key
                                             options:(MWWebImageOptions)options
                                             context:(nullable MWWebImageContext *)context
                                          completion:(nullable MWImageCacheQueryCompletionBlock)completionBlock;

/**
 Query the cached image from image cache for given key. The operation can be used to cancel the query.
 If image is cached in memory, completion is called synchronously, else asynchronously and depends on the options arg (See `MWWebImageQueryDiskSync`)

 @param key The image cache key
 @param options A mask to specify options to use for this query
 @param context A context contains different options to perform specify changes or processes, see `MWWebImageContextOption`. This hold the extra objects which `options` enum can not hold.
 @param cacheType Specify where to query the cache from. By default we use `.all`, which means both memory cache and disk cache. You can choose to query memory only or disk only as well. Pass `.none` is invalid and callback with nil immediately.
 @param completionBlock The completion block. Will not get called if the operation is cancelled
 @return The operation for this query
 */
- (nullable id<MWWebImageOperation>)queryImageForKey:(nullable NSString *)key
                                             options:(MWWebImageOptions)options
                                             context:(nullable MWWebImageContext *)context
                                           cacheType:(MWImageCacheType)cacheType
                                          completion:(nullable MWImageCacheQueryCompletionBlock)completionBlock;

/**
 Store the image into image cache for the given key. If cache type is memory only, completion is called synchronously, else asynchronously.

 @param image The image to store
 @param imageData The image data to be used for disk storage
 @param key The image cache key
 @param cacheType The image store op cache type
 @param completionBlock A block executed after the operation is finished
 */
- (void)storeImage:(nullable UIImage *)image
         imageData:(nullable NSData *)imageData
            forKey:(nullable NSString *)key
         cacheType:(MWImageCacheType)cacheType
        completion:(nullable MWWebImageNoParamsBlock)completionBlock;

/**
 Remove the image from image cache for the given key. If cache type is memory only, completion is called synchronously, else asynchronously.

 @param key The image cache key
 @param cacheType The image remove op cache type
 @param completionBlock A block executed after the operation is finished
 */
- (void)removeImageForKey:(nullable NSString *)key
                cacheType:(MWImageCacheType)cacheType
               completion:(nullable MWWebImageNoParamsBlock)completionBlock;

/**
 Check if image cache contains the image for the given key (does not load the image). If image is cached in memory, completion is called synchronously, else asynchronously.

 @param key The image cache key
 @param cacheType The image contains op cache type
 @param completionBlock A block executed after the operation is finished.
 */
- (void)containsImageForKey:(nullable NSString *)key
                  cacheType:(MWImageCacheType)cacheType
                 completion:(nullable MWImageCacheContainsCompletionBlock)completionBlock;

/**
 Clear all the cached images for image cache. If cache type is memory only, completion is called synchronously, else asynchronously.

 @param cacheType The image clear op cache type
 @param completionBlock A block executed after the operation is finished
 */
- (void)clearWithCacheType:(MWImageCacheType)cacheType
                completion:(nullable MWWebImageNoParamsBlock)completionBlock;

@end
