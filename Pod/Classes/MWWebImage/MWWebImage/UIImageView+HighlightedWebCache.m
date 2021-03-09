/*
 * This file is part of the MWWebImage package.
 * (c) Olivier Poitrey <rs@dailymotion.com>
 *
 * For the full copyright and license information, please view the LICENSE
 * file that was distributed with this source code.
 */

#import "UIImageView+HighlightedWebCache.h"

#if MW_UIKIT

#import "UIView+WebCacheOperation.h"
#import "UIView+WebCache.h"
#import "MWInternalMacros.h"

static NSString * const MWHighlightedImageOperationKey = @"UIImageViewImageOperationHighlighted";

@implementation UIImageView (HighlightedWebCache)

- (void)MW_setHighlightedImageWithURL:(nullable NSURL *)url {
    [self MW_setHighlightedImageWithURL:url options:0 progress:nil completed:nil];
}

- (void)MW_setHighlightedImageWithURL:(nullable NSURL *)url options:(MWWebImageOptions)options {
    [self MW_setHighlightedImageWithURL:url options:options progress:nil completed:nil];
}

- (void)MW_setHighlightedImageWithURL:(nullable NSURL *)url options:(MWWebImageOptions)options context:(nullable MWWebImageContext *)context {
    [self MW_setHighlightedImageWithURL:url options:options context:context progress:nil completed:nil];
}

- (void)MW_setHighlightedImageWithURL:(nullable NSURL *)url completed:(nullable MWExternalCompletionBlock)completedBlock {
    [self MW_setHighlightedImageWithURL:url options:0 progress:nil completed:completedBlock];
}

- (void)MW_setHighlightedImageWithURL:(nullable NSURL *)url options:(MWWebImageOptions)options completed:(nullable MWExternalCompletionBlock)completedBlock {
    [self MW_setHighlightedImageWithURL:url options:options progress:nil completed:completedBlock];
}

- (void)MW_setHighlightedImageWithURL:(NSURL *)url options:(MWWebImageOptions)options progress:(nullable MWImageLoaderProgressBlock)progressBlock completed:(nullable MWExternalCompletionBlock)completedBlock {
    [self MW_setHighlightedImageWithURL:url options:options context:nil progress:progressBlock completed:completedBlock];
}

- (void)MW_setHighlightedImageWithURL:(nullable NSURL *)url
                              options:(MWWebImageOptions)options
                              context:(nullable MWWebImageContext *)context
                             progress:(nullable MWImageLoaderProgressBlock)progressBlock
                            completed:(nullable MWExternalCompletionBlock)completedBlock {
    @weakify(self);
    MWWebImageMutableContext *mutableContext;
    if (context) {
        mutableContext = [context mutableCopy];
    } else {
        mutableContext = [NSMutableDictionary dictionary];
    }
    mutableContext[MWWebImageContextSetImageOperationKey] = MWHighlightedImageOperationKey;
    [self MW_internalSetImageWithURL:url
                    placeholderImage:nil
                             options:options
                             context:mutableContext
                       setImageBlock:^(UIImage * _Nullable image, NSData * _Nullable imageData, MWImageCacheType cacheType, NSURL * _Nullable imageURL) {
                           @strongify(self);
                           self.highlightedImage = image;
                       }
                            progress:progressBlock
                           completed:^(UIImage * _Nullable image, NSData * _Nullable data, NSError * _Nullable error, MWImageCacheType cacheType, BOOL finished, NSURL * _Nullable imageURL) {
                               if (completedBlock) {
                                   completedBlock(image, error, cacheType, imageURL);
                               }
                           }];
}

@end

#endif
