/*
 * This file is part of the MWWebImage package.
 * (c) Olivier Poitrey <rs@dailymotion.com>
 *
 * For the full copyright and license information, please view the LICENSE
 * file that was distributed with this source code.
 */

#import "MWWebImageOptionsProcessor.h"

@interface MWWebImageOptionsResult ()

@property (nonatomic, assign) MWWebImageOptions options;
@property (nonatomic, copy, nullable) MWWebImageContext *context;

@end

@implementation MWWebImageOptionsResult

- (instancetype)initWithOptions:(MWWebImageOptions)options context:(MWWebImageContext *)context {
    self = [super init];
    if (self) {
        self.options = options;
        self.context = context;
    }
    return self;
}

@end

@interface MWWebImageOptionsProcessor ()

@property (nonatomic, copy, nonnull) MWWebImageOptionsProcessorBlock block;

@end

@implementation MWWebImageOptionsProcessor

- (instancetype)initWithBlock:(MWWebImageOptionsProcessorBlock)block {
    self = [super init];
    if (self) {
        self.block = block;
    }
    return self;
}

+ (instancetype)optionsProcessorWithBlock:(MWWebImageOptionsProcessorBlock)block {
    MWWebImageOptionsProcessor *optionsProcessor = [[MWWebImageOptionsProcessor alloc] initWithBlock:block];
    return optionsProcessor;
}

- (MWWebImageOptionsResult *)processedResultForURL:(NSURL *)url options:(MWWebImageOptions)options context:(MWWebImageContext *)context {
    if (!self.block) {
        return nil;
    }
    return self.block(url, options, context);
}

@end
