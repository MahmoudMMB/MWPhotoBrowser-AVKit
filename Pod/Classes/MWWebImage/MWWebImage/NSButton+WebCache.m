/*
 * This file is part of the MWWebImage package.
 * (c) Olivier Poitrey <rs@dailymotion.com>
 *
 * For the full copyright and license information, please view the LICENSE
 * file that was distributed with this source code.
 */

#import "NSButton+WebCache.h"

#if MW_MAC

#import "objc/runtime.h"
#import "UIView+WebCacheOperation.h"
#import "UIView+WebCache.h"
#import "MWInternalMacros.h"

static NSString * const MWAlternateImageOperationKey = @"NSButtonAlternateImageOperation";

@implementation NSButton (WebCache)

#pragma mark - Image

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
    self.MW_currentImageURL = url;
    [self MW_internalSetImageWithURL:url
                    placeholderImage:placeholder
                             options:options
                             context:context
                       setImageBlock:nil
                            progress:progressBlock
                           completed:^(NSImage * _Nullable image, NSData * _Nullable data, NSError * _Nullable error, MWImageCacheType cacheType, BOOL finished, NSURL * _Nullable imageURL) {
                               if (completedBlock) {
                                   completedBlock(image, error, cacheType, imageURL);
                               }
                           }];
}

#pragma mark - Alternate Image

- (void)MW_setAlternateImageWithURL:(nullable NSURL *)url {
    [self MW_setAlternateImageWithURL:url placeholderImage:nil options:0 progress:nil completed:nil];
}

- (void)MW_setAlternateImageWithURL:(nullable NSURL *)url placeholderImage:(nullable UIImage *)placeholder {
    [self MW_setAlternateImageWithURL:url placeholderImage:placeholder options:0 progress:nil completed:nil];
}

- (void)MW_setAlternateImageWithURL:(nullable NSURL *)url placeholderImage:(nullable UIImage *)placeholder options:(MWWebImageOptions)options {
    [self MW_setAlternateImageWithURL:url placeholderImage:placeholder options:options progress:nil completed:nil];
}

- (void)MW_setAlternateImageWithURL:(nullable NSURL *)url placeholderImage:(nullable UIImage *)placeholder options:(MWWebImageOptions)options context:(nullable MWWebImageContext *)context {
    [self MW_setAlternateImageWithURL:url placeholderImage:placeholder options:options context:context progress:nil completed:nil];
}

- (void)MW_setAlternateImageWithURL:(nullable NSURL *)url completed:(nullable MWExternalCompletionBlock)completedBlock {
    [self MW_setAlternateImageWithURL:url placeholderImage:nil options:0 progress:nil completed:completedBlock];
}

- (void)MW_setAlternateImageWithURL:(nullable NSURL *)url placeholderImage:(nullable UIImage *)placeholder completed:(nullable MWExternalCompletionBlock)completedBlock {
    [self MW_setAlternateImageWithURL:url placeholderImage:placeholder options:0 progress:nil completed:completedBlock];
}

- (void)MW_setAlternateImageWithURL:(nullable NSURL *)url placeholderImage:(nullable UIImage *)placeholder options:(MWWebImageOptions)options completed:(nullable MWExternalCompletionBlock)completedBlock {
    [self MW_setAlternateImageWithURL:url placeholderImage:placeholder options:options progress:nil completed:completedBlock];
}

- (void)MW_setAlternateImageWithURL:(nullable NSURL *)url placeholderImage:(nullable UIImage *)placeholder options:(MWWebImageOptions)options progress:(nullable MWImageLoaderProgressBlock)progressBlock completed:(nullable MWExternalCompletionBlock)completedBlock {
    [self MW_setAlternateImageWithURL:url placeholderImage:placeholder options:options context:nil progress:progressBlock completed:completedBlock];
}

- (void)MW_setAlternateImageWithURL:(nullable NSURL *)url
                   placeholderImage:(nullable UIImage *)placeholder
                            options:(MWWebImageOptions)options
                            context:(nullable MWWebImageContext *)context
                           progress:(nullable MWImageLoaderProgressBlock)progressBlock
                          completed:(nullable MWExternalCompletionBlock)completedBlock {
    self.MW_currentAlternateImageURL = url;
    
    MWWebImageMutableContext *mutableContext;
    if (context) {
        mutableContext = [context mutableCopy];
    } else {
        mutableContext = [NSMutableDictionary dictionary];
    }
    mutableContext[MWWebImageContextSetImageOperationKey] = MWAlternateImageOperationKey;
    @weakify(self);
    [self MW_internalSetImageWithURL:url
                    placeholderImage:placeholder
                             options:options
                             context:mutableContext
                       setImageBlock:^(NSImage * _Nullable image, NSData * _Nullable imageData, MWImageCacheType cacheType, NSURL * _Nullable imageURL) {
                           @strongify(self);
                           self.alternateImage = image;
                       }
                            progress:progressBlock
                           completed:^(NSImage * _Nullable image, NSData * _Nullable data, NSError * _Nullable error, MWImageCacheType cacheType, BOOL finished, NSURL * _Nullable imageURL) {
                               if (completedBlock) {
                                   completedBlock(image, error, cacheType, imageURL);
                               }
                           }];
}

#pragma mark - Cancel

- (void)MW_cancelCurrentImageLoad {
    [self MW_cancelImageLoadOperationWithKey:NSStringFromClass([self class])];
}

- (void)MW_cancelCurrentAlternateImageLoad {
    [self MW_cancelImageLoadOperationWithKey:MWAlternateImageOperationKey];
}

#pragma mar - Private

- (NSURL *)MW_currentImageURL {
    return objc_getAssociatedObject(self, @selector(MW_currentImageURL));
}

- (void)setMW_currentImageURL:(NSURL *)MW_currentImageURL {
    objc_setAssociatedObject(self, @selector(MW_currentImageURL), MW_currentImageURL, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (NSURL *)MW_currentAlternateImageURL {
    return objc_getAssociatedObject(self, @selector(MW_currentAlternateImageURL));
}

- (void)setMW_currentAlternateImageURL:(NSURL *)MW_currentAlternateImageURL {
    objc_setAssociatedObject(self, @selector(MW_currentAlternateImageURL), MW_currentAlternateImageURL, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

@end

#endif
