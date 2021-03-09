/*
 * This file is part of the MWWebImage package.
 * (c) Olivier Poitrey <rs@dailymotion.com>
 *
 * For the full copyright and license information, please view the LICENSE
 * file that was distributed with this source code.
 */

#import "MWWebImageCacheKeyFilter.h"

@interface MWWebImageCacheKeyFilter ()

@property (nonatomic, copy, nonnull) MWWebImageCacheKeyFilterBlock block;

@end

@implementation MWWebImageCacheKeyFilter

- (instancetype)initWithBlock:(MWWebImageCacheKeyFilterBlock)block {
    self = [super init];
    if (self) {
        self.block = block;
    }
    return self;
}

+ (instancetype)cacheKeyFilterWithBlock:(MWWebImageCacheKeyFilterBlock)block {
    MWWebImageCacheKeyFilter *cacheKeyFilter = [[MWWebImageCacheKeyFilter alloc] initWithBlock:block];
    return cacheKeyFilter;
}

- (NSString *)cacheKeyForURL:(NSURL *)url {
    if (!self.block) {
        return nil;
    }
    return self.block(url);
}

@end
