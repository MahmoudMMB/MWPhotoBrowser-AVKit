/*
 * This file is part of the MWWebImage package.
 * (c) Olivier Poitrey <rs@dailymotion.com>
 *
 * For the full copyright and license information, please view the LICENSE
 * file that was distributed with this source code.
 */

#import "MWImageLoadersManager.h"
#import "MWWebImageDownloader.h"
#import "MWInternalMacros.h"

@interface MWImageLoadersManager ()

@property (nonatomic, strong, nonnull) dispatch_semaphore_t loadersLock;

@end

@implementation MWImageLoadersManager
{
    NSMutableArray<id<MWImageLoader>>* _imageLoaders;
}

+ (MWImageLoadersManager *)sharedManager {
    static dispatch_once_t onceToken;
    static MWImageLoadersManager *manager;
    dispatch_once(&onceToken, ^{
        manager = [[MWImageLoadersManager alloc] init];
    });
    return manager;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        // initialize with default image loaders
        _imageLoaders = [NSMutableArray arrayWithObject:[MWWebImageDownloader sharedDownloader]];
        _loadersLock = dispatch_semaphore_create(1);
    }
    return self;
}

- (NSArray<id<MWImageLoader>> *)loaders {
    MW_LOCK(self.loadersLock);
    NSArray<id<MWImageLoader>>* loaders = [_imageLoaders copy];
    MW_UNLOCK(self.loadersLock);
    return loaders;
}

- (void)setLoaders:(NSArray<id<MWImageLoader>> *)loaders {
    MW_LOCK(self.loadersLock);
    [_imageLoaders removeAllObjects];
    if (loaders.count) {
        [_imageLoaders addObjectsFromArray:loaders];
    }
    MW_UNLOCK(self.loadersLock);
}

#pragma mark - Loader Property

- (void)addLoader:(id<MWImageLoader>)loader {
    if (![loader conformsToProtocol:@protocol(MWImageLoader)]) {
        return;
    }
    MW_LOCK(self.loadersLock);
    [_imageLoaders addObject:loader];
    MW_UNLOCK(self.loadersLock);
}

- (void)removeLoader:(id<MWImageLoader>)loader {
    if (![loader conformsToProtocol:@protocol(MWImageLoader)]) {
        return;
    }
    MW_LOCK(self.loadersLock);
    [_imageLoaders removeObject:loader];
    MW_UNLOCK(self.loadersLock);
}

#pragma mark - MWImageLoader

- (BOOL)canRequestImageForURL:(nullable NSURL *)url {
    NSArray<id<MWImageLoader>> *loaders = self.loaders;
    for (id<MWImageLoader> loader in loaders.reverseObjectEnumerator) {
        if ([loader canRequestImageForURL:url]) {
            return YES;
        }
    }
    return NO;
}

- (id<MWWebImageOperation>)requestImageWithURL:(NSURL *)url options:(MWWebImageOptions)options context:(MWWebImageContext *)context progress:(MWImageLoaderProgressBlock)progressBlock completed:(MWImageLoaderCompletedBlock)completedBlock {
    if (!url) {
        return nil;
    }
    NSArray<id<MWImageLoader>> *loaders = self.loaders;
    for (id<MWImageLoader> loader in loaders.reverseObjectEnumerator) {
        if ([loader canRequestImageForURL:url]) {
            return [loader requestImageWithURL:url options:options context:context progress:progressBlock completed:completedBlock];
        }
    }
    return nil;
}

- (BOOL)shouldBlockFailedURLWithURL:(NSURL *)url error:(NSError *)error {
    NSArray<id<MWImageLoader>> *loaders = self.loaders;
    for (id<MWImageLoader> loader in loaders.reverseObjectEnumerator) {
        if ([loader canRequestImageForURL:url]) {
            return [loader shouldBlockFailedURLWithURL:url error:error];
        }
    }
    return NO;
}

@end
