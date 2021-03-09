/*
 * This file is part of the MWWebImage package.
 * (c) Olivier Poitrey <rs@dailymotion.com>
 *
 * For the full copyright and license information, please view the LICENSE
 * file that was distributed with this source code.
 */

#import "UIImageView+WebCache.h"
#import "objc/runtime.h"
#import "UIView+WebCacheOperation.h"
#import "UIView+WebCache.h"

@implementation UIImageView (WebCache)

- (void)MW_setImageWithURL:(nullable NSURL *)url {
    [self MW_setImageWithURL:url placeholderImage:nil options:0 progress:nil completed:nil];
}

- (void)MW_setImageWithURL:(nullable NSURL *)url placeholderImage:(nullable UIImage *)placeholder {
    [self MW_setImageWithURL:url placeholderImage:placeholder options:0 progress:nil completed:nil];
}

- (void)MW_setImageWithURL:(nullable NSURL *)url placeholderImage:(nullable UIImage *)placeholder options:(MWWebImageOptions)options {
    [self MW_setImageWithURL:url placeholderImage:placeholder options:options progress:nil completed:nil];
}

- (void)MW_setImageWithURL:(nullable NSURL *)url placeholderImage:(nullable UIImage *)placeholder options:(MWWebImageOptions)options context:(nullable MWWebImageContext *)context {
    [self MW_setImageWithURL:url placeholderImage:placeholder options:options context:context progress:nil completed:nil];
}

- (void)MW_setImageWithURL:(nullable NSURL *)url completed:(nullable MWExternalCompletionBlock)completedBlock {
    [self MW_setImageWithURL:url placeholderImage:nil options:0 progress:nil completed:completedBlock];
}

- (void)MW_setImageWithURL:(nullable NSURL *)url placeholderImage:(nullable UIImage *)placeholder completed:(nullable MWExternalCompletionBlock)completedBlock {
    [self MW_setImageWithURL:url placeholderImage:placeholder options:0 progress:nil completed:completedBlock];
}

- (void)MW_setImageWithURL:(nullable NSURL *)url placeholderImage:(nullable UIImage *)placeholder options:(MWWebImageOptions)options completed:(nullable MWExternalCompletionBlock)completedBlock {
    [self MW_setImageWithURL:url placeholderImage:placeholder options:options progress:nil completed:completedBlock];
}

- (void)MW_setImageWithURL:(nullable NSURL *)url placeholderImage:(nullable UIImage *)placeholder options:(MWWebImageOptions)options progress:(nullable MWImageLoaderProgressBlock)progressBlock completed:(nullable MWExternalCompletionBlock)completedBlock {
    [self MW_setImageWithURL:url placeholderImage:placeholder options:options context:nil progress:progressBlock completed:completedBlock];
}

- (void)MW_setImageWithURL:(nullable NSURL *)url
          placeholderImage:(nullable UIImage *)placeholder
                   options:(MWWebImageOptions)options
                   context:(nullable MWWebImageContext *)context
                  progress:(nullable MWImageLoaderProgressBlock)progressBlock
                 completed:(nullable MWExternalCompletionBlock)completedBlock {
    [self MW_internalSetImageWithURL:url
                    placeholderImage:placeholder
                             options:options
                             context:context
                       setImageBlock:nil
                            progress:progressBlock
                           completed:^(UIImage * _Nullable image, NSData * _Nullable data, NSError * _Nullable error, MWImageCacheType cacheType, BOOL finished, NSURL * _Nullable imageURL) {
                               if (completedBlock) {
                                   completedBlock(image, error, cacheType, imageURL);
                               }
                           }];
}

@end
