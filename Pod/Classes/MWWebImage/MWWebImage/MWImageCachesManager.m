/*
 * This file is part of the MWWebImage package.
 * (c) Olivier Poitrey <rs@dailymotion.com>
 *
 * For the full copyright and license information, please view the LICENSE
 * file that was distributed with this source code.
 */

#import "MWImageCachesManager.h"
#import "MWImageCachesManagerOperation.h"
#import "MWImageCache.h"
#import "MWInternalMacros.h"

@interface MWImageCachesManager ()

@property (nonatomic, strong, nonnull) dispatch_semaphore_t cachesLock;

@end

@implementation MWImageCachesManager
{
    NSMutableArray<id<MWImageCache>> *_imageCaches;
}

+ (MWImageCachesManager *)sharedManager {
    static dispatch_once_t onceToken;
    static MWImageCachesManager *manager;
    dispatch_once(&onceToken, ^{
        manager = [[MWImageCachesManager alloc] init];
    });
    return manager;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        self.queryOperationPolicy = MWImageCachesManagerOperationPolicySerial;
        self.storeOperationPolicy = MWImageCachesManagerOperationPolicyHighestOnly;
        self.removeOperationPolicy = MWImageCachesManagerOperationPolicyConcurrent;
        self.containsOperationPolicy = MWImageCachesManagerOperationPolicySerial;
        self.clearOperationPolicy = MWImageCachesManagerOperationPolicyConcurrent;
        // initialize with default image caches
        _imageCaches = [NSMutableArray arrayWithObject:[MWImageCache sharedImageCache]];
        _cachesLock = dispatch_semaphore_create(1);
    }
    return self;
}

- (NSArray<id<MWImageCache>> *)caches {
    MW_LOCK(self.cachesLock);
    NSArray<id<MWImageCache>> *caches = [_imageCaches copy];
    MW_UNLOCK(self.cachesLock);
    return caches;
}

- (void)setCaches:(NSArray<id<MWImageCache>> *)caches {
    MW_LOCK(self.cachesLock);
    [_imageCaches removeAllObjects];
    if (caches.count) {
        [_imageCaches addObjectsFromArray:caches];
    }
    MW_UNLOCK(self.cachesLock);
}

#pragma mark - Cache IO operations

- (void)addCache:(id<MWImageCache>)cache {
    if (![cache conformsToProtocol:@protocol(MWImageCache)]) {
        return;
    }
    MW_LOCK(self.cachesLock);
    [_imageCaches addObject:cache];
    MW_UNLOCK(self.cachesLock);
}

- (void)removeCache:(id<MWImageCache>)cache {
    if (![cache conformsToProtocol:@protocol(MWImageCache)]) {
        return;
    }
    MW_LOCK(self.cachesLock);
    [_imageCaches removeObject:cache];
    MW_UNLOCK(self.cachesLock);
}

#pragma mark - MWImageCache

- (id<MWWebImageOperation>)queryImageForKey:(NSString *)key options:(MWWebImageOptions)options context:(MWWebImageContext *)context completion:(MWImageCacheQueryCompletionBlock)completionBlock {
    return [self queryImageForKey:key options:options context:context cacheType:MWImageCacheTypeAll completion:completionBlock];
}

- (id<MWWebImageOperation>)queryImageForKey:(NSString *)key options:(MWWebImageOptions)options context:(MWWebImageContext *)context cacheType:(MWImageCacheType)cacheType completion:(MWImageCacheQueryCompletionBlock)completionBlock {
    if (!key) {
        return nil;
    }
    NSArray<id<MWImageCache>> *caches = self.caches;
    NSUInteger count = caches.count;
    if (count == 0) {
        return nil;
    } else if (count == 1) {
        return [caches.firstObject queryImageForKey:key options:options context:context cacheType:cacheType completion:completionBlock];
    }
    switch (self.queryOperationPolicy) {
        case MWImageCachesManagerOperationPolicyHighestOnly: {
            id<MWImageCache> cache = caches.lastObject;
            return [cache queryImageForKey:key options:options context:context cacheType:cacheType completion:completionBlock];
        }
            break;
        case MWImageCachesManagerOperationPolicyLowestOnly: {
            id<MWImageCache> cache = caches.firstObject;
            return [cache queryImageForKey:key options:options context:context cacheType:cacheType completion:completionBlock];
        }
            break;
        case MWImageCachesManagerOperationPolicyConcurrent: {
            MWImageCachesManagerOperation *operation = [MWImageCachesManagerOperation new];
            [operation beginWithTotalCount:caches.count];
            [self concurrentQueryImageForKey:key options:options context:context cacheType:cacheType completion:completionBlock enumerator:caches.reverseObjectEnumerator operation:operation];
            return operation;
        }
            break;
        case MWImageCachesManagerOperationPolicySerial: {
            MWImageCachesManagerOperation *operation = [MWImageCachesManagerOperation new];
            [operation beginWithTotalCount:caches.count];
            [self serialQueryImageForKey:key options:options context:context cacheType:cacheType completion:completionBlock enumerator:caches.reverseObjectEnumerator operation:operation];
            return operation;
        }
            break;
        default:
            return nil;
            break;
    }
}

- (void)storeImage:(UIImage *)image imageData:(NSData *)imageData forKey:(NSString *)key cacheType:(MWImageCacheType)cacheType completion:(MWWebImageNoParamsBlock)completionBlock {
    if (!key) {
        return;
    }
    NSArray<id<MWImageCache>> *caches = self.caches;
    NSUInteger count = caches.count;
    if (count == 0) {
        return;
    } else if (count == 1) {
        [caches.firstObject storeImage:image imageData:imageData forKey:key cacheType:cacheType completion:completionBlock];
        return;
    }
    switch (self.storeOperationPolicy) {
        case MWImageCachesManagerOperationPolicyHighestOnly: {
            id<MWImageCache> cache = caches.lastObject;
            [cache storeImage:image imageData:imageData forKey:key cacheType:cacheType completion:completionBlock];
        }
            break;
        case MWImageCachesManagerOperationPolicyLowestOnly: {
            id<MWImageCache> cache = caches.firstObject;
            [cache storeImage:image imageData:imageData forKey:key cacheType:cacheType completion:completionBlock];
        }
            break;
        case MWImageCachesManagerOperationPolicyConcurrent: {
            MWImageCachesManagerOperation *operation = [MWImageCachesManagerOperation new];
            [operation beginWithTotalCount:caches.count];
            [self concurrentStoreImage:image imageData:imageData forKey:key cacheType:cacheType completion:completionBlock enumerator:caches.reverseObjectEnumerator operation:operation];
        }
            break;
        case MWImageCachesManagerOperationPolicySerial: {
            [self serialStoreImage:image imageData:imageData forKey:key cacheType:cacheType completion:completionBlock enumerator:caches.reverseObjectEnumerator];
        }
            break;
        default:
            break;
    }
}

- (void)removeImageForKey:(NSString *)key cacheType:(MWImageCacheType)cacheType completion:(MWWebImageNoParamsBlock)completionBlock {
    if (!key) {
        return;
    }
    NSArray<id<MWImageCache>> *caches = self.caches;
    NSUInteger count = caches.count;
    if (count == 0) {
        return;
    } else if (count == 1) {
        [caches.firstObject removeImageForKey:key cacheType:cacheType completion:completionBlock];
        return;
    }
    switch (self.removeOperationPolicy) {
        case MWImageCachesManagerOperationPolicyHighestOnly: {
            id<MWImageCache> cache = caches.lastObject;
            [cache removeImageForKey:key cacheType:cacheType completion:completionBlock];
        }
            break;
        case MWImageCachesManagerOperationPolicyLowestOnly: {
            id<MWImageCache> cache = caches.firstObject;
            [cache removeImageForKey:key cacheType:cacheType completion:completionBlock];
        }
            break;
        case MWImageCachesManagerOperationPolicyConcurrent: {
            MWImageCachesManagerOperation *operation = [MWImageCachesManagerOperation new];
            [operation beginWithTotalCount:caches.count];
            [self concurrentRemoveImageForKey:key cacheType:cacheType completion:completionBlock enumerator:caches.reverseObjectEnumerator operation:operation];
        }
            break;
        case MWImageCachesManagerOperationPolicySerial: {
            [self serialRemoveImageForKey:key cacheType:cacheType completion:completionBlock enumerator:caches.reverseObjectEnumerator];
        }
            break;
        default:
            break;
    }
}

- (void)containsImageForKey:(NSString *)key cacheType:(MWImageCacheType)cacheType completion:(MWImageCacheContainsCompletionBlock)completionBlock {
    if (!key) {
        return;
    }
    NSArray<id<MWImageCache>> *caches = self.caches;
    NSUInteger count = caches.count;
    if (count == 0) {
        return;
    } else if (count == 1) {
        [caches.firstObject containsImageForKey:key cacheType:cacheType completion:completionBlock];
        return;
    }
    switch (self.clearOperationPolicy) {
        case MWImageCachesManagerOperationPolicyHighestOnly: {
            id<MWImageCache> cache = caches.lastObject;
            [cache containsImageForKey:key cacheType:cacheType completion:completionBlock];
        }
            break;
        case MWImageCachesManagerOperationPolicyLowestOnly: {
            id<MWImageCache> cache = caches.firstObject;
            [cache containsImageForKey:key cacheType:cacheType completion:completionBlock];
        }
            break;
        case MWImageCachesManagerOperationPolicyConcurrent: {
            MWImageCachesManagerOperation *operation = [MWImageCachesManagerOperation new];
            [operation beginWithTotalCount:caches.count];
            [self concurrentContainsImageForKey:key cacheType:cacheType completion:completionBlock enumerator:caches.reverseObjectEnumerator operation:operation];
        }
            break;
        case MWImageCachesManagerOperationPolicySerial: {
            MWImageCachesManagerOperation *operation = [MWImageCachesManagerOperation new];
            [operation beginWithTotalCount:caches.count];
            [self serialContainsImageForKey:key cacheType:cacheType completion:completionBlock enumerator:caches.reverseObjectEnumerator operation:operation];
        }
            break;
        default:
            break;
    }
}

- (void)clearWithCacheType:(MWImageCacheType)cacheType completion:(MWWebImageNoParamsBlock)completionBlock {
    NSArray<id<MWImageCache>> *caches = self.caches;
    NSUInteger count = caches.count;
    if (count == 0) {
        return;
    } else if (count == 1) {
        [caches.firstObject clearWithCacheType:cacheType completion:completionBlock];
        return;
    }
    switch (self.clearOperationPolicy) {
        case MWImageCachesManagerOperationPolicyHighestOnly: {
            id<MWImageCache> cache = caches.lastObject;
            [cache clearWithCacheType:cacheType completion:completionBlock];
        }
            break;
        case MWImageCachesManagerOperationPolicyLowestOnly: {
            id<MWImageCache> cache = caches.firstObject;
            [cache clearWithCacheType:cacheType completion:completionBlock];
        }
            break;
        case MWImageCachesManagerOperationPolicyConcurrent: {
            MWImageCachesManagerOperation *operation = [MWImageCachesManagerOperation new];
            [operation beginWithTotalCount:caches.count];
            [self concurrentClearWithCacheType:cacheType completion:completionBlock enumerator:caches.reverseObjectEnumerator operation:operation];
        }
            break;
        case MWImageCachesManagerOperationPolicySerial: {
            [self serialClearWithCacheType:cacheType completion:completionBlock enumerator:caches.reverseObjectEnumerator];
        }
            break;
        default:
            break;
    }
}

#pragma mark - Concurrent Operation

- (void)concurrentQueryImageForKey:(NSString *)key options:(MWWebImageOptions)options context:(MWWebImageContext *)context cacheType:(MWImageCacheType)queryCacheType completion:(MWImageCacheQueryCompletionBlock)completionBlock enumerator:(NSEnumerator<id<MWImageCache>> *)enumerator operation:(MWImageCachesManagerOperation *)operation {
    NSParameterAssert(enumerator);
    NSParameterAssert(operation);
    for (id<MWImageCache> cache in enumerator) {
        [cache queryImageForKey:key options:options context:context cacheType:queryCacheType completion:^(UIImage * _Nullable image, NSData * _Nullable data, MWImageCacheType cacheType) {
            if (operation.isCancelled) {
                // Cancelled
                return;
            }
            if (operation.isFinished) {
                // Finished
                return;
            }
            [operation completeOne];
            if (image) {
                // Success
                [operation done];
                if (completionBlock) {
                    completionBlock(image, data, cacheType);
                }
                return;
            }
            if (operation.pendingCount == 0) {
                // Complete
                [operation done];
                if (completionBlock) {
                    completionBlock(nil, nil, MWImageCacheTypeNone);
                }
            }
        }];
    }
}

- (void)concurrentStoreImage:(UIImage *)image imageData:(NSData *)imageData forKey:(NSString *)key cacheType:(MWImageCacheType)cacheType completion:(MWWebImageNoParamsBlock)completionBlock enumerator:(NSEnumerator<id<MWImageCache>> *)enumerator operation:(MWImageCachesManagerOperation *)operation {
    NSParameterAssert(enumerator);
    NSParameterAssert(operation);
    for (id<MWImageCache> cache in enumerator) {
        [cache storeImage:image imageData:imageData forKey:key cacheType:cacheType completion:^{
            if (operation.isCancelled) {
                // Cancelled
                return;
            }
            if (operation.isFinished) {
                // Finished
                return;
            }
            [operation completeOne];
            if (operation.pendingCount == 0) {
                // Complete
                [operation done];
                if (completionBlock) {
                    completionBlock();
                }
            }
        }];
    }
}

- (void)concurrentRemoveImageForKey:(NSString *)key cacheType:(MWImageCacheType)cacheType completion:(MWWebImageNoParamsBlock)completionBlock enumerator:(NSEnumerator<id<MWImageCache>> *)enumerator operation:(MWImageCachesManagerOperation *)operation {
    NSParameterAssert(enumerator);
    NSParameterAssert(operation);
    for (id<MWImageCache> cache in enumerator) {
        [cache removeImageForKey:key cacheType:cacheType completion:^{
            if (operation.isCancelled) {
                // Cancelled
                return;
            }
            if (operation.isFinished) {
                // Finished
                return;
            }
            [operation completeOne];
            if (operation.pendingCount == 0) {
                // Complete
                [operation done];
                if (completionBlock) {
                    completionBlock();
                }
            }
        }];
    }
}

- (void)concurrentContainsImageForKey:(NSString *)key cacheType:(MWImageCacheType)cacheType completion:(MWImageCacheContainsCompletionBlock)completionBlock enumerator:(NSEnumerator<id<MWImageCache>> *)enumerator operation:(MWImageCachesManagerOperation *)operation {
    NSParameterAssert(enumerator);
    NSParameterAssert(operation);
    for (id<MWImageCache> cache in enumerator) {
        [cache containsImageForKey:key cacheType:cacheType completion:^(MWImageCacheType containsCacheType) {
            if (operation.isCancelled) {
                // Cancelled
                return;
            }
            if (operation.isFinished) {
                // Finished
                return;
            }
            [operation completeOne];
            if (containsCacheType != MWImageCacheTypeNone) {
                // Success
                [operation done];
                if (completionBlock) {
                    completionBlock(containsCacheType);
                }
                return;
            }
            if (operation.pendingCount == 0) {
                // Complete
                [operation done];
                if (completionBlock) {
                    completionBlock(MWImageCacheTypeNone);
                }
            }
        }];
    }
}

- (void)concurrentClearWithCacheType:(MWImageCacheType)cacheType completion:(MWWebImageNoParamsBlock)completionBlock enumerator:(NSEnumerator<id<MWImageCache>> *)enumerator operation:(MWImageCachesManagerOperation *)operation {
    NSParameterAssert(enumerator);
    NSParameterAssert(operation);
    for (id<MWImageCache> cache in enumerator) {
        [cache clearWithCacheType:cacheType completion:^{
            if (operation.isCancelled) {
                // Cancelled
                return;
            }
            if (operation.isFinished) {
                // Finished
                return;
            }
            [operation completeOne];
            if (operation.pendingCount == 0) {
                // Complete
                [operation done];
                if (completionBlock) {
                    completionBlock();
                }
            }
        }];
    }
}

#pragma mark - Serial Operation

- (void)serialQueryImageForKey:(NSString *)key options:(MWWebImageOptions)options context:(MWWebImageContext *)context cacheType:(MWImageCacheType)queryCacheType completion:(MWImageCacheQueryCompletionBlock)completionBlock enumerator:(NSEnumerator<id<MWImageCache>> *)enumerator operation:(MWImageCachesManagerOperation *)operation {
    NSParameterAssert(enumerator);
    NSParameterAssert(operation);
    id<MWImageCache> cache = enumerator.nextObject;
    if (!cache) {
        // Complete
        [operation done];
        if (completionBlock) {
            completionBlock(nil, nil, MWImageCacheTypeNone);
        }
        return;
    }
    @weakify(self);
    [cache queryImageForKey:key options:options context:context cacheType:queryCacheType completion:^(UIImage * _Nullable image, NSData * _Nullable data, MWImageCacheType cacheType) {
        @strongify(self);
        if (operation.isCancelled) {
            // Cancelled
            return;
        }
        if (operation.isFinished) {
            // Finished
            return;
        }
        [operation completeOne];
        if (image) {
            // Success
            [operation done];
            if (completionBlock) {
                completionBlock(image, data, cacheType);
            }
            return;
        }
        // Next
        [self serialQueryImageForKey:key options:options context:context cacheType:queryCacheType completion:completionBlock enumerator:enumerator operation:operation];
    }];
}

- (void)serialStoreImage:(UIImage *)image imageData:(NSData *)imageData forKey:(NSString *)key cacheType:(MWImageCacheType)cacheType completion:(MWWebImageNoParamsBlock)completionBlock enumerator:(NSEnumerator<id<MWImageCache>> *)enumerator {
    NSParameterAssert(enumerator);
    id<MWImageCache> cache = enumerator.nextObject;
    if (!cache) {
        // Complete
        if (completionBlock) {
            completionBlock();
        }
        return;
    }
    @weakify(self);
    [cache storeImage:image imageData:imageData forKey:key cacheType:cacheType completion:^{
        @strongify(self);
        // Next
        [self serialStoreImage:image imageData:imageData forKey:key cacheType:cacheType completion:completionBlock enumerator:enumerator];
    }];
}

- (void)serialRemoveImageForKey:(NSString *)key cacheType:(MWImageCacheType)cacheType completion:(MWWebImageNoParamsBlock)completionBlock enumerator:(NSEnumerator<id<MWImageCache>> *)enumerator {
    NSParameterAssert(enumerator);
    id<MWImageCache> cache = enumerator.nextObject;
    if (!cache) {
        // Complete
        if (completionBlock) {
            completionBlock();
        }
        return;
    }
    @weakify(self);
    [cache removeImageForKey:key cacheType:cacheType completion:^{
        @strongify(self);
        // Next
        [self serialRemoveImageForKey:key cacheType:cacheType completion:completionBlock enumerator:enumerator];
    }];
}

- (void)serialContainsImageForKey:(NSString *)key cacheType:(MWImageCacheType)cacheType completion:(MWImageCacheContainsCompletionBlock)completionBlock enumerator:(NSEnumerator<id<MWImageCache>> *)enumerator operation:(MWImageCachesManagerOperation *)operation {
    NSParameterAssert(enumerator);
    NSParameterAssert(operation);
    id<MWImageCache> cache = enumerator.nextObject;
    if (!cache) {
        // Complete
        [operation done];
        if (completionBlock) {
            completionBlock(MWImageCacheTypeNone);
        }
        return;
    }
    @weakify(self);
    [cache containsImageForKey:key cacheType:cacheType completion:^(MWImageCacheType containsCacheType) {
        @strongify(self);
        if (operation.isCancelled) {
            // Cancelled
            return;
        }
        if (operation.isFinished) {
            // Finished
            return;
        }
        [operation completeOne];
        if (containsCacheType != MWImageCacheTypeNone) {
            // Success
            [operation done];
            if (completionBlock) {
                completionBlock(containsCacheType);
            }
            return;
        }
        // Next
        [self serialContainsImageForKey:key cacheType:cacheType completion:completionBlock enumerator:enumerator operation:operation];
    }];
}

- (void)serialClearWithCacheType:(MWImageCacheType)cacheType completion:(MWWebImageNoParamsBlock)completionBlock enumerator:(NSEnumerator<id<MWImageCache>> *)enumerator {
    NSParameterAssert(enumerator);
    id<MWImageCache> cache = enumerator.nextObject;
    if (!cache) {
        // Complete
        if (completionBlock) {
            completionBlock();
        }
        return;
    }
    @weakify(self);
    [cache clearWithCacheType:cacheType completion:^{
        @strongify(self);
        // Next
        [self serialClearWithCacheType:cacheType completion:completionBlock enumerator:enumerator];
    }];
}

@end
