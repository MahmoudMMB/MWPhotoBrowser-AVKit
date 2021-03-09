/*
 * This file is part of the MWWebImage package.
 * (c) Olivier Poitrey <rs@dailymotion.com>
 *
 * For the full copyright and license information, please view the LICENSE
 * file that was distributed with this source code.
 */

#import "UIButton+WebCache.h"

#if MW_UIKIT

#import "objc/runtime.h"
#import "UIView+WebCacheOperation.h"
#import "UIView+WebCache.h"
#import "MWInternalMacros.h"

static char imageURLStorageKey;

typedef NSMutableDictionary<NSString *, NSURL *> MWStateImageURLDictionary;

static inline NSString * imageURLKeyForState(UIControlState state) {
    return [NSString stringWithFormat:@"image_%lu", (unsigned long)state];
}

static inline NSString * backgroundImageURLKeyForState(UIControlState state) {
    return [NSString stringWithFormat:@"backgroundImage_%lu", (unsigned long)state];
}

static inline NSString * imageOperationKeyForState(UIControlState state) {
    return [NSString stringWithFormat:@"UIButtonImageOperation%lu", (unsigned long)state];
}

static inline NSString * backgroundImageOperationKeyForState(UIControlState state) {
    return [NSString stringWithFormat:@"UIButtonBackgroundImageOperation%lu", (unsigned long)state];
}

@implementation UIButton (WebCache)

#pragma mark - Image

- (nullable NSURL *)MW_currentImageURL {
    NSURL *url = self.MW_imageURLStorage[imageURLKeyForState(self.state)];

    if (!url) {
        url = self.MW_imageURLStorage[imageURLKeyForState(UIControlStateNormal)];
    }

    return url;
}

- (nullable NSURL *)MW_imageURLForState:(UIControlState)state {
    return self.MW_imageURLStorage[imageURLKeyForState(state)];
}

- (void)MW_setImageWithURL:(nullable NSURL *)url forState:(UIControlState)state {
    [self MW_setImageWithURL:url forState:state placeholderImage:nil options:0 completed:nil];
}

- (void)MW_setImageWithURL:(nullable NSURL *)url forState:(UIControlState)state placeholderImage:(nullable UIImage *)placeholder {
    [self MW_setImageWithURL:url forState:state placeholderImage:placeholder options:0 completed:nil];
}

- (void)MW_setImageWithURL:(nullable NSURL *)url forState:(UIControlState)state placeholderImage:(nullable UIImage *)placeholder options:(MWWebImageOptions)options {
    [self MW_setImageWithURL:url forState:state placeholderImage:placeholder options:options progress:nil completed:nil];
}

- (void)MW_setImageWithURL:(nullable NSURL *)url forState:(UIControlState)state placeholderImage:(nullable UIImage *)placeholder options:(MWWebImageOptions)options context:(nullable MWWebImageContext *)context {
    [self MW_setImageWithURL:url forState:state placeholderImage:placeholder options:options context:context progress:nil completed:nil];
}

- (void)MW_setImageWithURL:(nullable NSURL *)url forState:(UIControlState)state completed:(nullable MWExternalCompletionBlock)completedBlock {
    [self MW_setImageWithURL:url forState:state placeholderImage:nil options:0 completed:completedBlock];
}

- (void)MW_setImageWithURL:(nullable NSURL *)url forState:(UIControlState)state placeholderImage:(nullable UIImage *)placeholder completed:(nullable MWExternalCompletionBlock)completedBlock {
    [self MW_setImageWithURL:url forState:state placeholderImage:placeholder options:0 completed:completedBlock];
}

- (void)MW_setImageWithURL:(nullable NSURL *)url forState:(UIControlState)state placeholderImage:(nullable UIImage *)placeholder options:(MWWebImageOptions)options completed:(nullable MWExternalCompletionBlock)completedBlock {
    [self MW_setImageWithURL:url forState:state placeholderImage:placeholder options:options progress:nil completed:completedBlock];
}

- (void)MW_setImageWithURL:(nullable NSURL *)url forState:(UIControlState)state placeholderImage:(nullable UIImage *)placeholder options:(MWWebImageOptions)options progress:(nullable MWImageLoaderProgressBlock)progressBlock completed:(nullable MWExternalCompletionBlock)completedBlock {
    [self MW_setImageWithURL:url forState:state placeholderImage:placeholder options:options context:nil progress:progressBlock completed:completedBlock];
}

- (void)MW_setImageWithURL:(nullable NSURL *)url
                  forState:(UIControlState)state
          placeholderImage:(nullable UIImage *)placeholder
                   options:(MWWebImageOptions)options
                   context:(nullable MWWebImageContext *)context
                  progress:(nullable MWImageLoaderProgressBlock)progressBlock
                 completed:(nullable MWExternalCompletionBlock)completedBlock {
    if (!url) {
        [self.MW_imageURLStorage removeObjectForKey:imageURLKeyForState(state)];
    } else {
        self.MW_imageURLStorage[imageURLKeyForState(state)] = url;
    }
    
    MWWebImageMutableContext *mutableContext;
    if (context) {
        mutableContext = [context mutableCopy];
    } else {
        mutableContext = [NSMutableDictionary dictionary];
    }
    mutableContext[MWWebImageContextSetImageOperationKey] = imageOperationKeyForState(state);
    @weakify(self);
    [self MW_internalSetImageWithURL:url
                    placeholderImage:placeholder
                             options:options
                             context:mutableContext
                       setImageBlock:^(UIImage * _Nullable image, NSData * _Nullable imageData, MWImageCacheType cacheType, NSURL * _Nullable imageURL) {
                           @strongify(self);
                           [self setImage:image forState:state];
                       }
                            progress:progressBlock
                           completed:^(UIImage * _Nullable image, NSData * _Nullable data, NSError * _Nullable error, MWImageCacheType cacheType, BOOL finished, NSURL * _Nullable imageURL) {
                               if (completedBlock) {
                                   completedBlock(image, error, cacheType, imageURL);
                               }
                           }];
}

#pragma mark - Background Image

- (nullable NSURL *)MW_currentBackgroundImageURL {
    NSURL *url = self.MW_imageURLStorage[backgroundImageURLKeyForState(self.state)];
    
    if (!url) {
        url = self.MW_imageURLStorage[backgroundImageURLKeyForState(UIControlStateNormal)];
    }
    
    return url;
}

- (nullable NSURL *)MW_backgroundImageURLForState:(UIControlState)state {
    return self.MW_imageURLStorage[backgroundImageURLKeyForState(state)];
}

- (void)MW_setBackgroundImageWithURL:(nullable NSURL *)url forState:(UIControlState)state {
    [self MW_setBackgroundImageWithURL:url forState:state placeholderImage:nil options:0 completed:nil];
}

- (void)MW_setBackgroundImageWithURL:(nullable NSURL *)url forState:(UIControlState)state placeholderImage:(nullable UIImage *)placeholder {
    [self MW_setBackgroundImageWithURL:url forState:state placeholderImage:placeholder options:0 completed:nil];
}

- (void)MW_setBackgroundImageWithURL:(nullable NSURL *)url forState:(UIControlState)state placeholderImage:(nullable UIImage *)placeholder options:(MWWebImageOptions)options {
    [self MW_setBackgroundImageWithURL:url forState:state placeholderImage:placeholder options:options progress:nil completed:nil];
}

- (void)MW_setBackgroundImageWithURL:(nullable NSURL *)url forState:(UIControlState)state placeholderImage:(nullable UIImage *)placeholder options:(MWWebImageOptions)options context:(nullable MWWebImageContext *)context {
    [self MW_setBackgroundImageWithURL:url forState:state placeholderImage:placeholder options:options context:context progress:nil completed:nil];
}

- (void)MW_setBackgroundImageWithURL:(nullable NSURL *)url forState:(UIControlState)state completed:(nullable MWExternalCompletionBlock)completedBlock {
    [self MW_setBackgroundImageWithURL:url forState:state placeholderImage:nil options:0 completed:completedBlock];
}

- (void)MW_setBackgroundImageWithURL:(nullable NSURL *)url forState:(UIControlState)state placeholderImage:(nullable UIImage *)placeholder completed:(nullable MWExternalCompletionBlock)completedBlock {
    [self MW_setBackgroundImageWithURL:url forState:state placeholderImage:placeholder options:0 completed:completedBlock];
}

- (void)MW_setBackgroundImageWithURL:(nullable NSURL *)url forState:(UIControlState)state placeholderImage:(nullable UIImage *)placeholder options:(MWWebImageOptions)options completed:(nullable MWExternalCompletionBlock)completedBlock {
    [self MW_setBackgroundImageWithURL:url forState:state placeholderImage:placeholder options:options progress:nil completed:completedBlock];
}

- (void)MW_setBackgroundImageWithURL:(nullable NSURL *)url forState:(UIControlState)state placeholderImage:(nullable UIImage *)placeholder options:(MWWebImageOptions)options progress:(nullable MWImageLoaderProgressBlock)progressBlock completed:(nullable MWExternalCompletionBlock)completedBlock {
    [self MW_setBackgroundImageWithURL:url forState:state placeholderImage:placeholder options:options context:nil progress:progressBlock completed:completedBlock];
}

- (void)MW_setBackgroundImageWithURL:(nullable NSURL *)url
                            forState:(UIControlState)state
                    placeholderImage:(nullable UIImage *)placeholder
                             options:(MWWebImageOptions)options
                             context:(nullable MWWebImageContext *)context
                            progress:(nullable MWImageLoaderProgressBlock)progressBlock
                           completed:(nullable MWExternalCompletionBlock)completedBlock {
    if (!url) {
        [self.MW_imageURLStorage removeObjectForKey:backgroundImageURLKeyForState(state)];
    } else {
        self.MW_imageURLStorage[backgroundImageURLKeyForState(state)] = url;
    }
    
    MWWebImageMutableContext *mutableContext;
    if (context) {
        mutableContext = [context mutableCopy];
    } else {
        mutableContext = [NSMutableDictionary dictionary];
    }
    mutableContext[MWWebImageContextSetImageOperationKey] = backgroundImageOperationKeyForState(state);
    @weakify(self);
    [self MW_internalSetImageWithURL:url
                    placeholderImage:placeholder
                             options:options
                             context:mutableContext
                       setImageBlock:^(UIImage * _Nullable image, NSData * _Nullable imageData, MWImageCacheType cacheType, NSURL * _Nullable imageURL) {
                           @strongify(self);
                           [self setBackgroundImage:image forState:state];
                       }
                            progress:progressBlock
                           completed:^(UIImage * _Nullable image, NSData * _Nullable data, NSError * _Nullable error, MWImageCacheType cacheType, BOOL finished, NSURL * _Nullable imageURL) {
                               if (completedBlock) {
                                   completedBlock(image, error, cacheType, imageURL);
                               }
                           }];
}

#pragma mark - Cancel

- (void)MW_cancelImageLoadForState:(UIControlState)state {
    [self MW_cancelImageLoadOperationWithKey:imageOperationKeyForState(state)];
}

- (void)MW_cancelBackgroundImageLoadForState:(UIControlState)state {
    [self MW_cancelImageLoadOperationWithKey:backgroundImageOperationKeyForState(state)];
}

#pragma mark - Private

- (MWStateImageURLDictionary *)MW_imageURLStorage {
    MWStateImageURLDictionary *storage = objc_getAssociatedObject(self, &imageURLStorageKey);
    if (!storage) {
        storage = [NSMutableDictionary dictionary];
        objc_setAssociatedObject(self, &imageURLStorageKey, storage, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }

    return storage;
}

@end

#endif
