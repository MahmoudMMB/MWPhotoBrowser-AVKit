/*
 * This file is part of the MWWebImage package.
 * (c) Olivier Poitrey <rs@dailymotion.com>
 *
 * For the full copyright and license information, please view the LICENSE
 * file that was distributed with this source code.
 */

#import "UIView+WebCacheOperation.h"
#import "objc/runtime.h"

static char loadOperationKey;

// key is strong, value is weak because operation instance is retained by MWWebImageManager's runningOperations property
// we should use lock to keep thread-safe because these method may not be accessed from main queue
typedef NSMapTable<NSString *, id<MWWebImageOperation>> MWOperatioNSDictionary;

@implementation UIView (WebCacheOperation)

- (MWOperatioNSDictionary *)MW_operationDictionary {
    @synchronized(self) {
        MWOperatioNSDictionary *operations = objc_getAssociatedObject(self, &loadOperationKey);
        if (operations) {
            return operations;
        }
        operations = [[NSMapTable alloc] initWithKeyOptions:NSPointerFunctionsStrongMemory valueOptions:NSPointerFunctionsWeakMemory capacity:0];
        objc_setAssociatedObject(self, &loadOperationKey, operations, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        return operations;
    }
}

- (nullable id<MWWebImageOperation>)MW_imageLoadOperationForKey:(nullable NSString *)key  {
    id<MWWebImageOperation> operation;
    if (key) {
        MWOperatioNSDictionary *operationDictionary = [self MW_operationDictionary];
        @synchronized (self) {
            operation = [operationDictionary objectForKey:key];
        }
    }
    return operation;
}

- (void)MW_setImageLoadOperation:(nullable id<MWWebImageOperation>)operation forKey:(nullable NSString *)key {
    if (key) {
        [self MW_cancelImageLoadOperationWithKey:key];
        if (operation) {
            MWOperatioNSDictionary *operationDictionary = [self MW_operationDictionary];
            @synchronized (self) {
                [operationDictionary setObject:operation forKey:key];
            }
        }
    }
}

- (void)MW_cancelImageLoadOperationWithKey:(nullable NSString *)key {
    if (key) {
        // Cancel in progress downloader from queue
        MWOperatioNSDictionary *operationDictionary = [self MW_operationDictionary];
        id<MWWebImageOperation> operation;
        
        @synchronized (self) {
            operation = [operationDictionary objectForKey:key];
        }
        if (operation) {
            if ([operation conformsToProtocol:@protocol(MWWebImageOperation)]) {
                [operation cancel];
            }
            @synchronized (self) {
                [operationDictionary removeObjectForKey:key];
            }
        }
    }
}

- (void)MW_removeImageLoadOperationWithKey:(nullable NSString *)key {
    if (key) {
        MWOperatioNSDictionary *operationDictionary = [self MW_operationDictionary];
        @synchronized (self) {
            [operationDictionary removeObjectForKey:key];
        }
    }
}

@end
