/*
 * This file is part of the MWWebImage package.
 * (c) Olivier Poitrey <rs@dailymotion.com>
 *
 * For the full copyright and license information, please view the LICENSE
 * file that was distributed with this source code.
 */

#import "MWWebImageManager.h"
#import "MWImageCache.h"
#import "MWWebImageDownloader.h"
#import "UIImage+Metadata.h"
#import "MWAssociatedObject.h"
#import "MWWebImageError.h"
#import "MWInternalMacros.h"

static id<MWImageCache> _defaultImageCache;
static id<MWImageLoader> _defaultImageLoader;

@interface MWWebImageCombinedOperation ()

@property (assign, nonatomic, getter = isCancelled) BOOL cancelled;
@property (strong, nonatomic, readwrite, nullable) id<MWWebImageOperation> loaderOperation;
@property (strong, nonatomic, readwrite, nullable) id<MWWebImageOperation> cacheOperation;
@property (weak, nonatomic, nullable) MWWebImageManager *manager;

@end

@interface MWWebImageManager ()

@property (strong, nonatomic, readwrite, nonnull) MWImageCache *imageCache;
@property (strong, nonatomic, readwrite, nonnull) id<MWImageLoader> imageLoader;
@property (strong, nonatomic, nonnull) NSMutableSet<NSURL *> *failedURLs;
@property (strong, nonatomic, nonnull) dispatch_semaphore_t failedURLsLock; // a lock to keep the access to `failedURLs` thread-safe
@property (strong, nonatomic, nonnull) NSMutableSet<MWWebImageCombinedOperation *> *runningOperations;
@property (strong, nonatomic, nonnull) dispatch_semaphore_t runningOperationsLock; // a lock to keep the access to `runningOperations` thread-safe

@end

@implementation MWWebImageManager

+ (id<MWImageCache>)defaultImageCache {
    return _defaultImageCache;
}

+ (void)setDefaultImageCache:(id<MWImageCache>)defaultImageCache {
    if (defaultImageCache && ![defaultImageCache conformsToProtocol:@protocol(MWImageCache)]) {
        return;
    }
    _defaultImageCache = defaultImageCache;
}

+ (id<MWImageLoader>)defaultImageLoader {
    return _defaultImageLoader;
}

+ (void)setDefaultImageLoader:(id<MWImageLoader>)defaultImageLoader {
    if (defaultImageLoader && ![defaultImageLoader conformsToProtocol:@protocol(MWImageLoader)]) {
        return;
    }
    _defaultImageLoader = defaultImageLoader;
}

+ (nonnull instancetype)sharedManager {
    static dispatch_once_t once;
    static id instance;
    dispatch_once(&once, ^{
        instance = [self new];
    });
    return instance;
}

- (nonnull instancetype)init {
    id<MWImageCache> cache = [[self class] defaultImageCache];
    if (!cache) {
        cache = [MWImageCache sharedImageCache];
    }
    id<MWImageLoader> loader = [[self class] defaultImageLoader];
    if (!loader) {
        loader = [MWWebImageDownloader sharedDownloader];
    }
    return [self initWithCache:cache loader:loader];
}

- (nonnull instancetype)initWithCache:(nonnull id<MWImageCache>)cache loader:(nonnull id<MWImageLoader>)loader {
    if ((self = [super init])) {
        _imageCache = cache;
        _imageLoader = loader;
        _failedURLs = [NSMutableSet new];
        _failedURLsLock = dispatch_semaphore_create(1);
        _runningOperations = [NSMutableSet new];
        _runningOperationsLock = dispatch_semaphore_create(1);
    }
    return self;
}

- (nullable NSString *)cacheKeyForURL:(nullable NSURL *)url {
    if (!url) {
        return @"";
    }
    
    NSString *key;
    // Cache Key Filter
    id<MWWebImageCacheKeyFilter> cacheKeyFilter = self.cacheKeyFilter;
    if (cacheKeyFilter) {
        key = [cacheKeyFilter cacheKeyForURL:url];
    } else {
        key = url.absoluteString;
    }
    
    return key;
}

- (nullable NSString *)cacheKeyForURL:(nullable NSURL *)url context:(nullable MWWebImageContext *)context {
    if (!url) {
        return @"";
    }
    
    NSString *key;
    // Cache Key Filter
    id<MWWebImageCacheKeyFilter> cacheKeyFilter = self.cacheKeyFilter;
    if (context[MWWebImageContextCacheKeyFilter]) {
        cacheKeyFilter = context[MWWebImageContextCacheKeyFilter];
    }
    if (cacheKeyFilter) {
        key = [cacheKeyFilter cacheKeyForURL:url];
    } else {
        key = url.absoluteString;
    }
    
    // Thumbnail Key Appending
    NSValue *thumbnailSizeValue = context[MWWebImageContextImageThumbnailPixelSize];
    if (thumbnailSizeValue != nil) {
        CGSize thumbnailSize = CGSizeZero;
#if MW_MAC
        thumbnailSize = thumbnailSizeValue.sizeValue;
#else
        thumbnailSize = thumbnailSizeValue.CGSizeValue;
#endif
        BOOL preserveAspectRatio = YES;
        NSNumber *preserveAspectRatioValue = context[MWWebImageContextImagePreserveAspectRatio];
        if (preserveAspectRatioValue != nil) {
            preserveAspectRatio = preserveAspectRatioValue.boolValue;
        }
        key = MWThumbnailedKeyForKey(key, thumbnailSize, preserveAspectRatio);
    }
    
    // Transformer Key Appending
    id<MWImageTransformer> transformer = self.transformer;
    if (context[MWWebImageContextImageTransformer]) {
        transformer = context[MWWebImageContextImageTransformer];
        if (![transformer conformsToProtocol:@protocol(MWImageTransformer)]) {
            transformer = nil;
        }
    }
    if (transformer) {
        key = MWTransformedKeyForKey(key, transformer.transformerKey);
    }
    
    return key;
}

- (MWWebImageCombinedOperation *)loadImageWithURL:(NSURL *)url options:(MWWebImageOptions)options progress:(MWImageLoaderProgressBlock)progressBlock completed:(MWInternalCompletionBlock)completedBlock {
    return [self loadImageWithURL:url options:options context:nil progress:progressBlock completed:completedBlock];
}

- (MWWebImageCombinedOperation *)loadImageWithURL:(nullable NSURL *)url
                                          options:(MWWebImageOptions)options
                                          context:(nullable MWWebImageContext *)context
                                         progress:(nullable MWImageLoaderProgressBlock)progressBlock
                                        completed:(nonnull MWInternalCompletionBlock)completedBlock {
    // Invoking this method without a completedBlock is pointless
    NSAssert(completedBlock != nil, @"If you mean to prefetch the image, use -[MWWebImagePrefetcher prefetchURLs] instead");

    // Very common mistake is to send the URL using NSString object instead of NSURL. For some strange reason, Xcode won't
    // throw any warning for this type mismatch. Here we failsafe this error by allowing URLs to be passed as NSString.
    if ([url isKindOfClass:NSString.class]) {
        url = [NSURL URLWithString:(NSString *)url];
    }

    // Prevents app crashing on argument type error like sending NSNull instead of NSURL
    if (![url isKindOfClass:NSURL.class]) {
        url = nil;
    }

    MWWebImageCombinedOperation *operation = [MWWebImageCombinedOperation new];
    operation.manager = self;

    BOOL isFailedUrl = NO;
    if (url) {
        MW_LOCK(self.failedURLsLock);
        isFailedUrl = [self.failedURLs containsObject:url];
        MW_UNLOCK(self.failedURLsLock);
    }

    if (url.absoluteString.length == 0 || (!(options & MWWebImageRetryFailed) && isFailedUrl)) {
        NSString *description = isFailedUrl ? @"Image url is blacklisted" : @"Image url is nil";
        NSInteger code = isFailedUrl ? MWWebImageErrorBlackListed : MWWebImageErrorInvalidURL;
        [self callCompletionBlockForOperation:operation completion:completedBlock error:[NSError errorWithDomain:MWWebImageErrorDomain code:code userInfo:@{NSLocalizedDescriptionKey : description}] url:url];
        return operation;
    }

    MW_LOCK(self.runningOperationsLock);
    [self.runningOperations addObject:operation];
    MW_UNLOCK(self.runningOperationsLock);
    
    // Preprocess the options and context arg to decide the final the result for manager
    MWWebImageOptionsResult *result = [self processedResultForURL:url options:options context:context];
    
    // Start the entry to load image from cache
    [self callCacheProcessForOperation:operation url:url options:result.options context:result.context progress:progressBlock completed:completedBlock];

    return operation;
}

- (void)cancelAll {
    MW_LOCK(self.runningOperationsLock);
    NSSet<MWWebImageCombinedOperation *> *copiedOperations = [self.runningOperations copy];
    MW_UNLOCK(self.runningOperationsLock);
    [copiedOperations makeObjectsPerformSelector:@selector(cancel)]; // This will call `safelyRemoveOperationFromRunning:` and remove from the array
}

- (BOOL)isRunning {
    BOOL isRunning = NO;
    MW_LOCK(self.runningOperationsLock);
    isRunning = (self.runningOperations.count > 0);
    MW_UNLOCK(self.runningOperationsLock);
    return isRunning;
}

- (void)removeFailedURL:(NSURL *)url {
    if (!url) {
        return;
    }
    MW_LOCK(self.failedURLsLock);
    [self.failedURLs removeObject:url];
    MW_UNLOCK(self.failedURLsLock);
}

- (void)removeAllFailedURLs {
    MW_LOCK(self.failedURLsLock);
    [self.failedURLs removeAllObjects];
    MW_UNLOCK(self.failedURLsLock);
}

#pragma mark - Private

// Query normal cache process
- (void)callCacheProcessForOperation:(nonnull MWWebImageCombinedOperation *)operation
                                 url:(nonnull NSURL *)url
                             options:(MWWebImageOptions)options
                             context:(nullable MWWebImageContext *)context
                            progress:(nullable MWImageLoaderProgressBlock)progressBlock
                           completed:(nullable MWInternalCompletionBlock)completedBlock {
    // Grab the image cache to use
    id<MWImageCache> imageCache;
    if ([context[MWWebImageContextImageCache] conformsToProtocol:@protocol(MWImageCache)]) {
        imageCache = context[MWWebImageContextImageCache];
    } else {
        imageCache = self.imageCache;
    }
    
    // Get the query cache type
    MWImageCacheType queryCacheType = MWImageCacheTypeAll;
    if (context[MWWebImageContextQueryCacheType]) {
        queryCacheType = [context[MWWebImageContextQueryCacheType] integerValue];
    }
    
    // Check whether we should query cache
    BOOL shouldQueryCache = !MW_OPTIONS_CONTAINS(options, MWWebImageFromLoaderOnly);
    if (shouldQueryCache) {
        NSString *key = [self cacheKeyForURL:url context:context];
        @weakify(operation);
        operation.cacheOperation = [imageCache queryImageForKey:key options:options context:context cacheType:queryCacheType completion:^(UIImage * _Nullable cachedImage, NSData * _Nullable cachedData, MWImageCacheType cacheType) {
            @strongify(operation);
            if (!operation || operation.isCancelled) {
                // Image combined operation cancelled by user
                [self callCompletionBlockForOperation:operation completion:completedBlock error:[NSError errorWithDomain:MWWebImageErrorDomain code:MWWebImageErrorCancelled userInfo:@{NSLocalizedDescriptionKey : @"Operation cancelled by user during querying the cache"}] url:url];
                [self safelyRemoveOperationFromRunning:operation];
                return;
            } else if (context[MWWebImageContextImageTransformer] && !cachedImage) {
                // Have a chance to query original cache instead of downloading
                [self callOriginalCacheProcessForOperation:operation url:url options:options context:context progress:progressBlock completed:completedBlock];
                return;
            }
            
            // Continue download process
            [self callDownloadProcessForOperation:operation url:url options:options context:context cachedImage:cachedImage cachedData:cachedData cacheType:cacheType progress:progressBlock completed:completedBlock];
        }];
    } else {
        // Continue download process
        [self callDownloadProcessForOperation:operation url:url options:options context:context cachedImage:nil cachedData:nil cacheType:MWImageCacheTypeNone progress:progressBlock completed:completedBlock];
    }
}

// Query original cache process
- (void)callOriginalCacheProcessForOperation:(nonnull MWWebImageCombinedOperation *)operation
                                         url:(nonnull NSURL *)url
                                     options:(MWWebImageOptions)options
                                     context:(nullable MWWebImageContext *)context
                                    progress:(nullable MWImageLoaderProgressBlock)progressBlock
                                   completed:(nullable MWInternalCompletionBlock)completedBlock {
    // Grab the image cache to use
    id<MWImageCache> imageCache;
    if ([context[MWWebImageContextImageCache] conformsToProtocol:@protocol(MWImageCache)]) {
        imageCache = context[MWWebImageContextImageCache];
    } else {
        imageCache = self.imageCache;
    }
    
    // Get the original query cache type
    MWImageCacheType originalQueryCacheType = MWImageCacheTypeNone;
    if (context[MWWebImageContextOriginalQueryCacheType]) {
        originalQueryCacheType = [context[MWWebImageContextOriginalQueryCacheType] integerValue];
    }
    
    // Check whether we should query original cache
    BOOL shouldQueryOriginalCache = (originalQueryCacheType != MWImageCacheTypeNone);
    if (shouldQueryOriginalCache) {
        // Change originContext to mutable
        MWWebImageMutableContext * __block originContext;
        if (context) {
            originContext = [context mutableCopy];
        } else {
            originContext = [NSMutableDictionary dictionary];
        }
        
        // Disable transformer for cache key generation
        id<MWImageTransformer> transformer = originContext[MWWebImageContextImageTransformer];
        originContext[MWWebImageContextImageTransformer] = [NSNull null];
        
        NSString *key = [self cacheKeyForURL:url context:originContext];
        @weakify(operation);
        operation.cacheOperation = [imageCache queryImageForKey:key options:options context:context cacheType:originalQueryCacheType completion:^(UIImage * _Nullable cachedImage, NSData * _Nullable cachedData, MWImageCacheType cacheType) {
            @strongify(operation);
            if (!operation || operation.isCancelled) {
                // Image combined operation cancelled by user
                [self callCompletionBlockForOperation:operation completion:completedBlock error:[NSError errorWithDomain:MWWebImageErrorDomain code:MWWebImageErrorCancelled userInfo:@{NSLocalizedDescriptionKey : @"Operation cancelled by user during querying the cache"}] url:url];
                [self safelyRemoveOperationFromRunning:operation];
                return;
            }
            
            // Add original transformer
            if (transformer) {
                originContext[MWWebImageContextImageTransformer] = transformer;
            }
            
            // Use the store cache process instead of downloading, and ignore .refreshCached option for now
            [self callStoreCacheProcessForOperation:operation url:url options:options context:context downloadedImage:cachedImage downloadedData:cachedData finished:YES progress:progressBlock completed:completedBlock];
            
            [self safelyRemoveOperationFromRunning:operation];
        }];
    } else {
        // Continue download process
        [self callDownloadProcessForOperation:operation url:url options:options context:context cachedImage:nil cachedData:nil cacheType:originalQueryCacheType progress:progressBlock completed:completedBlock];
    }
}

// Download process
- (void)callDownloadProcessForOperation:(nonnull MWWebImageCombinedOperation *)operation
                                    url:(nonnull NSURL *)url
                                options:(MWWebImageOptions)options
                                context:(MWWebImageContext *)context
                            cachedImage:(nullable UIImage *)cachedImage
                             cachedData:(nullable NSData *)cachedData
                              cacheType:(MWImageCacheType)cacheType
                               progress:(nullable MWImageLoaderProgressBlock)progressBlock
                              completed:(nullable MWInternalCompletionBlock)completedBlock {
    // Grab the image loader to use
    id<MWImageLoader> imageLoader;
    if ([context[MWWebImageContextImageLoader] conformsToProtocol:@protocol(MWImageLoader)]) {
        imageLoader = context[MWWebImageContextImageLoader];
    } else {
        imageLoader = self.imageLoader;
    }
    
    // Check whether we should download image from network
    BOOL shouldDownload = !MW_OPTIONS_CONTAINS(options, MWWebImageFromCacheOnly);
    shouldDownload &= (!cachedImage || options & MWWebImageRefreshCached);
    shouldDownload &= (![self.delegate respondsToSelector:@selector(imageManager:shouldDownloadImageForURL:)] || [self.delegate imageManager:self shouldDownloadImageForURL:url]);
    shouldDownload &= [imageLoader canRequestImageForURL:url];
    if (shouldDownload) {
        if (cachedImage && options & MWWebImageRefreshCached) {
            // If image was found in the cache but MWWebImageRefreshCached is provided, notify about the cached image
            // AND try to re-download it in order to let a chance to NSURLCache to refresh it from server.
            [self callCompletionBlockForOperation:operation completion:completedBlock image:cachedImage data:cachedData error:nil cacheType:cacheType finished:YES url:url];
            // Pass the cached image to the image loader. The image loader should check whether the remote image is equal to the cached image.
            MWWebImageMutableContext *mutableContext;
            if (context) {
                mutableContext = [context mutableCopy];
            } else {
                mutableContext = [NSMutableDictionary dictionary];
            }
            mutableContext[MWWebImageContextLoaderCachedImage] = cachedImage;
            context = [mutableContext copy];
        }
        
        @weakify(operation);
        operation.loaderOperation = [imageLoader requestImageWithURL:url options:options context:context progress:progressBlock completed:^(UIImage *downloadedImage, NSData *downloadedData, NSError *error, BOOL finished) {
            @strongify(operation);
            if (!operation || operation.isCancelled) {
                // Image combined operation cancelled by user
                [self callCompletionBlockForOperation:operation completion:completedBlock error:[NSError errorWithDomain:MWWebImageErrorDomain code:MWWebImageErrorCancelled userInfo:@{NSLocalizedDescriptionKey : @"Operation cancelled by user during sending the request"}] url:url];
            } else if (cachedImage && options & MWWebImageRefreshCached && [error.domain isEqualToString:MWWebImageErrorDomain] && error.code == MWWebImageErrorCacheNotModified) {
                // Image refresh hit the NSURLCache cache, do not call the completion block
            } else if ([error.domain isEqualToString:MWWebImageErrorDomain] && error.code == MWWebImageErrorCancelled) {
                // Download operation cancelled by user before sending the request, don't block failed URL
                [self callCompletionBlockForOperation:operation completion:completedBlock error:error url:url];
            } else if (error) {
                [self callCompletionBlockForOperation:operation completion:completedBlock error:error url:url];
                BOOL shouldBlockFailedURL = [self shouldBlockFailedURLWithURL:url error:error options:options context:context];
                
                if (shouldBlockFailedURL) {
                    MW_LOCK(self.failedURLsLock);
                    [self.failedURLs addObject:url];
                    MW_UNLOCK(self.failedURLsLock);
                }
            } else {
                if ((options & MWWebImageRetryFailed)) {
                    MW_LOCK(self.failedURLsLock);
                    [self.failedURLs removeObject:url];
                    MW_UNLOCK(self.failedURLsLock);
                }
                // Continue store cache process
                [self callStoreCacheProcessForOperation:operation url:url options:options context:context downloadedImage:downloadedImage downloadedData:downloadedData finished:finished progress:progressBlock completed:completedBlock];
            }
            
            if (finished) {
                [self safelyRemoveOperationFromRunning:operation];
            }
        }];
    } else if (cachedImage) {
        [self callCompletionBlockForOperation:operation completion:completedBlock image:cachedImage data:cachedData error:nil cacheType:cacheType finished:YES url:url];
        [self safelyRemoveOperationFromRunning:operation];
    } else {
        // Image not in cache and download disallowed by delegate
        [self callCompletionBlockForOperation:operation completion:completedBlock image:nil data:nil error:nil cacheType:MWImageCacheTypeNone finished:YES url:url];
        [self safelyRemoveOperationFromRunning:operation];
    }
}

// Store cache process
- (void)callStoreCacheProcessForOperation:(nonnull MWWebImageCombinedOperation *)operation
                                      url:(nonnull NSURL *)url
                                  options:(MWWebImageOptions)options
                                  context:(MWWebImageContext *)context
                          downloadedImage:(nullable UIImage *)downloadedImage
                           downloadedData:(nullable NSData *)downloadedData
                                 finished:(BOOL)finished
                                 progress:(nullable MWImageLoaderProgressBlock)progressBlock
                                completed:(nullable MWInternalCompletionBlock)completedBlock {
    // the target image store cache type
    MWImageCacheType storeCacheType = MWImageCacheTypeAll;
    if (context[MWWebImageContextStoreCacheType]) {
        storeCacheType = [context[MWWebImageContextStoreCacheType] integerValue];
    }
    // the original store image cache type
    MWImageCacheType originalStoreCacheType = MWImageCacheTypeNone;
    if (context[MWWebImageContextOriginalStoreCacheType]) {
        originalStoreCacheType = [context[MWWebImageContextOriginalStoreCacheType] integerValue];
    }
    // origin cache key
    MWWebImageMutableContext *originContext = [context mutableCopy];
    // disable transformer for cache key generation
    originContext[MWWebImageContextImageTransformer] = [NSNull null];
    NSString *key = [self cacheKeyForURL:url context:originContext];
    id<MWImageTransformer> transformer = context[MWWebImageContextImageTransformer];
    if (![transformer conformsToProtocol:@protocol(MWImageTransformer)]) {
        transformer = nil;
    }
    id<MWWebImageCacheSerializer> cacheSerializer = context[MWWebImageContextCacheSerializer];
    
    BOOL shouldTransformImage = downloadedImage && transformer;
    shouldTransformImage = shouldTransformImage && (!downloadedImage.MW_isAnimated || (options & MWWebImageTransformAnimatedImage));
    shouldTransformImage = shouldTransformImage && (!downloadedImage.MW_isVector || (options & MWWebImageTransformVectorImage));
    BOOL shouldCacheOriginal = downloadedImage && finished;
    
    // if available, store original image to cache
    if (shouldCacheOriginal) {
        // normally use the store cache type, but if target image is transformed, use original store cache type instead
        MWImageCacheType targetStoreCacheType = shouldTransformImage ? originalStoreCacheType : storeCacheType;
        if (cacheSerializer && (targetStoreCacheType == MWImageCacheTypeDisk || targetStoreCacheType == MWImageCacheTypeAll)) {
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
                @autoreleasepool {
                    NSData *cacheData = [cacheSerializer cacheDataWithImage:downloadedImage originalData:downloadedData imageURL:url];
                    [self storeImage:downloadedImage imageData:cacheData forKey:key cacheType:targetStoreCacheType options:options context:context completion:^{
                        // Continue transform process
                        [self callTransformProcessForOperation:operation url:url options:options context:context originalImage:downloadedImage originalData:downloadedData finished:finished progress:progressBlock completed:completedBlock];
                    }];
                }
            });
        } else {
            [self storeImage:downloadedImage imageData:downloadedData forKey:key cacheType:targetStoreCacheType options:options context:context completion:^{
                // Continue transform process
                [self callTransformProcessForOperation:operation url:url options:options context:context originalImage:downloadedImage originalData:downloadedData finished:finished progress:progressBlock completed:completedBlock];
            }];
        }
    } else {
        // Continue transform process
        [self callTransformProcessForOperation:operation url:url options:options context:context originalImage:downloadedImage originalData:downloadedData finished:finished progress:progressBlock completed:completedBlock];
    }
}

// Transform process
- (void)callTransformProcessForOperation:(nonnull MWWebImageCombinedOperation *)operation
                                     url:(nonnull NSURL *)url
                                 options:(MWWebImageOptions)options
                                 context:(MWWebImageContext *)context
                           originalImage:(nullable UIImage *)originalImage
                            originalData:(nullable NSData *)originalData
                                finished:(BOOL)finished
                                progress:(nullable MWImageLoaderProgressBlock)progressBlock
                               completed:(nullable MWInternalCompletionBlock)completedBlock {
    // the target image store cache type
    MWImageCacheType storeCacheType = MWImageCacheTypeAll;
    if (context[MWWebImageContextStoreCacheType]) {
        storeCacheType = [context[MWWebImageContextStoreCacheType] integerValue];
    }
    // transformed cache key
    NSString *key = [self cacheKeyForURL:url context:context];
    id<MWImageTransformer> transformer = context[MWWebImageContextImageTransformer];
    if (![transformer conformsToProtocol:@protocol(MWImageTransformer)]) {
        transformer = nil;
    }
    id<MWWebImageCacheSerializer> cacheSerializer = context[MWWebImageContextCacheSerializer];
    
    BOOL shouldTransformImage = originalImage && transformer;
    shouldTransformImage = shouldTransformImage && (!originalImage.MW_isAnimated || (options & MWWebImageTransformAnimatedImage));
    shouldTransformImage = shouldTransformImage && (!originalImage.MW_isVector || (options & MWWebImageTransformVectorImage));
    // if available, store transformed image to cache
    if (shouldTransformImage) {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
            @autoreleasepool {
                UIImage *transformedImage = [transformer transformedImageWithImage:originalImage forKey:key];
                if (transformedImage && finished) {
                    BOOL imageWasTransformed = ![transformedImage isEqual:originalImage];
                    NSData *cacheData;
                    // pass nil if the image was transformed, so we can recalculate the data from the image
                    if (cacheSerializer && (storeCacheType == MWImageCacheTypeDisk || storeCacheType == MWImageCacheTypeAll)) {
                        cacheData = [cacheSerializer cacheDataWithImage:transformedImage originalData:(imageWasTransformed ? nil : originalData) imageURL:url];
                    } else {
                        cacheData = (imageWasTransformed ? nil : originalData);
                    }
                    [self storeImage:transformedImage imageData:cacheData forKey:key cacheType:storeCacheType options:options context:context completion:^{
                        [self callCompletionBlockForOperation:operation completion:completedBlock image:transformedImage data:originalData error:nil cacheType:MWImageCacheTypeNone finished:finished url:url];
                    }];
                } else {
                    [self callCompletionBlockForOperation:operation completion:completedBlock image:transformedImage data:originalData error:nil cacheType:MWImageCacheTypeNone finished:finished url:url];
                }
            }
        });
    } else {
        [self callCompletionBlockForOperation:operation completion:completedBlock image:originalImage data:originalData error:nil cacheType:MWImageCacheTypeNone finished:finished url:url];
    }
}

#pragma mark - Helper

- (void)safelyRemoveOperationFromRunning:(nullable MWWebImageCombinedOperation*)operation {
    if (!operation) {
        return;
    }
    MW_LOCK(self.runningOperationsLock);
    [self.runningOperations removeObject:operation];
    MW_UNLOCK(self.runningOperationsLock);
}

- (void)storeImage:(nullable UIImage *)image
         imageData:(nullable NSData *)data
            forKey:(nullable NSString *)key
         cacheType:(MWImageCacheType)cacheType
           options:(MWWebImageOptions)options
           context:(nullable MWWebImageContext *)context
        completion:(nullable MWWebImageNoParamsBlock)completion {
    id<MWImageCache> imageCache;
    if ([context[MWWebImageContextImageCache] conformsToProtocol:@protocol(MWImageCache)]) {
        imageCache = context[MWWebImageContextImageCache];
    } else {
        imageCache = self.imageCache;
    }
    BOOL waitStoreCache = MW_OPTIONS_CONTAINS(options, MWWebImageWaitStoreCache);
    // Check whether we should wait the store cache finished. If not, callback immediately
    [imageCache storeImage:image imageData:data forKey:key cacheType:cacheType completion:^{
        if (waitStoreCache) {
            if (completion) {
                completion();
            }
        }
    }];
    if (!waitStoreCache) {
        if (completion) {
            completion();
        }
    }
}

- (void)callCompletionBlockForOperation:(nullable MWWebImageCombinedOperation*)operation
                             completion:(nullable MWInternalCompletionBlock)completionBlock
                                  error:(nullable NSError *)error
                                    url:(nullable NSURL *)url {
    [self callCompletionBlockForOperation:operation completion:completionBlock image:nil data:nil error:error cacheType:MWImageCacheTypeNone finished:YES url:url];
}

- (void)callCompletionBlockForOperation:(nullable MWWebImageCombinedOperation*)operation
                             completion:(nullable MWInternalCompletionBlock)completionBlock
                                  image:(nullable UIImage *)image
                                   data:(nullable NSData *)data
                                  error:(nullable NSError *)error
                              cacheType:(MWImageCacheType)cacheType
                               finished:(BOOL)finished
                                    url:(nullable NSURL *)url {
    dispatch_main_async_safe(^{
        if (completionBlock) {
            completionBlock(image, data, error, cacheType, finished, url);
        }
    });
}

- (BOOL)shouldBlockFailedURLWithURL:(nonnull NSURL *)url
                              error:(nonnull NSError *)error
                            options:(MWWebImageOptions)options
                            context:(nullable MWWebImageContext *)context {
    id<MWImageLoader> imageLoader;
    if ([context[MWWebImageContextImageLoader] conformsToProtocol:@protocol(MWImageLoader)]) {
        imageLoader = context[MWWebImageContextImageLoader];
    } else {
        imageLoader = self.imageLoader;
    }
    // Check whether we should block failed url
    BOOL shouldBlockFailedURL;
    if ([self.delegate respondsToSelector:@selector(imageManager:shouldBlockFailedURL:withError:)]) {
        shouldBlockFailedURL = [self.delegate imageManager:self shouldBlockFailedURL:url withError:error];
    } else {
        shouldBlockFailedURL = [imageLoader shouldBlockFailedURLWithURL:url error:error];
    }
    
    return shouldBlockFailedURL;
}

- (MWWebImageOptionsResult *)processedResultForURL:(NSURL *)url options:(MWWebImageOptions)options context:(MWWebImageContext *)context {
    MWWebImageOptionsResult *result;
    MWWebImageMutableContext *mutableContext = [MWWebImageMutableContext dictionary];
    
    // Image Transformer from manager
    if (!context[MWWebImageContextImageTransformer]) {
        id<MWImageTransformer> transformer = self.transformer;
        [mutableContext setValue:transformer forKey:MWWebImageContextImageTransformer];
    }
    // Cache key filter from manager
    if (!context[MWWebImageContextCacheKeyFilter]) {
        id<MWWebImageCacheKeyFilter> cacheKeyFilter = self.cacheKeyFilter;
        [mutableContext setValue:cacheKeyFilter forKey:MWWebImageContextCacheKeyFilter];
    }
    // Cache serializer from manager
    if (!context[MWWebImageContextCacheSerializer]) {
        id<MWWebImageCacheSerializer> cacheSerializer = self.cacheSerializer;
        [mutableContext setValue:cacheSerializer forKey:MWWebImageContextCacheSerializer];
    }
    
    if (mutableContext.count > 0) {
        if (context) {
            [mutableContext addEntriesFromDictionary:context];
        }
        context = [mutableContext copy];
    }
    
    // Apply options processor
    if (self.optionsProcessor) {
        result = [self.optionsProcessor processedResultForURL:url options:options context:context];
    }
    if (!result) {
        // Use default options result
        result = [[MWWebImageOptionsResult alloc] initWithOptions:options context:context];
    }
    
    return result;
}

@end


@implementation MWWebImageCombinedOperation

- (void)cancel {
    @synchronized(self) {
        if (self.isCancelled) {
            return;
        }
        self.cancelled = YES;
        if (self.cacheOperation) {
            [self.cacheOperation cancel];
            self.cacheOperation = nil;
        }
        if (self.loaderOperation) {
            [self.loaderOperation cancel];
            self.loaderOperation = nil;
        }
        [self.manager safelyRemoveOperationFromRunning:self];
    }
}

@end
