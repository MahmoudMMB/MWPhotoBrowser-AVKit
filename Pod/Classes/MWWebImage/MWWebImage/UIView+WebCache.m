/*
 * This file is part of the MWWebImage package.
 * (c) Olivier Poitrey <rs@dailymotion.com>
 *
 * For the full copyright and license information, please view the LICENSE
 * file that was distributed with this source code.
 */

#import "UIView+WebCache.h"
#import "objc/runtime.h"
#import "UIView+WebCacheOperation.h"
#import "MWWebImageError.h"
#import "MWInternalMacros.h"
#import "MWWebImageTransitionInternal.h"

const int64_t MWWebImageProgressUnitCountUnknown = 1LL;

@implementation UIView (WebCache)

- (nullable NSURL *)MW_imageURL {
    return objc_getAssociatedObject(self, @selector(MW_imageURL));
}

- (void)setMW_imageURL:(NSURL * _Nullable)MW_imageURL {
    objc_setAssociatedObject(self, @selector(MW_imageURL), MW_imageURL, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (nullable NSString *)MW_latestOperationKey {
    return objc_getAssociatedObject(self, @selector(MW_latestOperationKey));
}

- (void)setMW_latestOperationKey:(NSString * _Nullable)MW_latestOperationKey {
    objc_setAssociatedObject(self, @selector(MW_latestOperationKey), MW_latestOperationKey, OBJC_ASSOCIATION_COPY_NONATOMIC);
}

- (NSProgress *)MW_imageProgress {
    NSProgress *progress = objc_getAssociatedObject(self, @selector(MW_imageProgress));
    if (!progress) {
        progress = [[NSProgress alloc] initWithParent:nil userInfo:nil];
        self.MW_imageProgress = progress;
    }
    return progress;
}

- (void)setMW_imageProgress:(NSProgress *)MW_imageProgress {
    objc_setAssociatedObject(self, @selector(MW_imageProgress), MW_imageProgress, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (void)MW_internalSetImageWithURL:(nullable NSURL *)url
                  placeholderImage:(nullable UIImage *)placeholder
                           options:(MWWebImageOptions)options
                           context:(nullable MWWebImageContext *)context
                     setImageBlock:(nullable MWSetImageBlock)setImageBlock
                          progress:(nullable MWImageLoaderProgressBlock)progressBlock
                         completed:(nullable MWInternalCompletionBlock)completedBlock {
    if (context) {
        // copy to avoid mutable object
        context = [context copy];
    } else {
        context = [NSDictionary dictionary];
    }
    NSString *validOperationKey = context[MWWebImageContextSetImageOperationKey];
    if (!validOperationKey) {
        // pass through the operation key to downstream, which can used for tracing operation or image view class
        validOperationKey = NSStringFromClass([self class]);
        MWWebImageMutableContext *mutableContext = [context mutableCopy];
        mutableContext[MWWebImageContextSetImageOperationKey] = validOperationKey;
        context = [mutableContext copy];
    }
    self.MW_latestOperationKey = validOperationKey;
    [self MW_cancelImageLoadOperationWithKey:validOperationKey];
    self.MW_imageURL = url;
    
    if (!(options & MWWebImageDelayPlaceholder)) {
        dispatch_main_async_safe(^{
            [self MW_setImage:placeholder imageData:nil basedOnClassOrViaCustomSetImageBlock:setImageBlock cacheType:MWImageCacheTypeNone imageURL:url];
        });
    }
    
    if (url) {
        // reset the progress
        NSProgress *imageProgress = objc_getAssociatedObject(self, @selector(MW_imageProgress));
        if (imageProgress) {
            imageProgress.totalUnitCount = 0;
            imageProgress.completedUnitCount = 0;
        }
        
#if MW_UIKIT || MW_MAC
        // check and start image indicator
        [self MW_startImageIndicator];
        id<MWWebImageIndicator> imageIndicator = self.MW_imageIndicator;
#endif
        MWWebImageManager *manager = context[MWWebImageContextCustomManager];
        if (!manager) {
            manager = [MWWebImageManager sharedManager];
        } else {
            // remove this manager to avoid retain cycle (manger -> loader -> operation -> context -> manager)
            MWWebImageMutableContext *mutableContext = [context mutableCopy];
            mutableContext[MWWebImageContextCustomManager] = nil;
            context = [mutableContext copy];
        }
        
        MWImageLoaderProgressBlock combinedProgressBlock = ^(NSInteger receivedSize, NSInteger expectedSize, NSURL * _Nullable targetURL) {
            if (imageProgress) {
                imageProgress.totalUnitCount = expectedSize;
                imageProgress.completedUnitCount = receivedSize;
            }
#if MW_UIKIT || MW_MAC
            if ([imageIndicator respondsToSelector:@selector(updateIndicatorProgress:)]) {
                double progress = 0;
                if (expectedSize != 0) {
                    progress = (double)receivedSize / expectedSize;
                }
                progress = MAX(MIN(progress, 1), 0); // 0.0 - 1.0
                dispatch_async(dispatch_get_main_queue(), ^{
                    [imageIndicator updateIndicatorProgress:progress];
                });
            }
#endif
            if (progressBlock) {
                progressBlock(receivedSize, expectedSize, targetURL);
            }
        };
        @weakify(self);
        id <MWWebImageOperation> operation = [manager loadImageWithURL:url options:options context:context progress:combinedProgressBlock completed:^(UIImage *image, NSData *data, NSError *error, MWImageCacheType cacheType, BOOL finished, NSURL *imageURL) {
            @strongify(self);
            if (!self) { return; }
            // if the progress not been updated, mark it to complete state
            if (imageProgress && finished && !error && imageProgress.totalUnitCount == 0 && imageProgress.completedUnitCount == 0) {
                imageProgress.totalUnitCount = MWWebImageProgressUnitCountUnknown;
                imageProgress.completedUnitCount = MWWebImageProgressUnitCountUnknown;
            }
            
#if MW_UIKIT || MW_MAC
            // check and stop image indicator
            if (finished) {
                [self MW_stopImageIndicator];
            }
#endif
            
            BOOL shouldCallCompletedBlock = finished || (options & MWWebImageAvoidAutoSetImage);
            BOOL shouldNotSetImage = ((image && (options & MWWebImageAvoidAutoSetImage)) ||
                                      (!image && !(options & MWWebImageDelayPlaceholder)));
            MWWebImageNoParamsBlock callCompletedBlockClojure = ^{
                if (!self) { return; }
                if (!shouldNotSetImage) {
                    [self MW_setNeedsLayout];
                }
                if (completedBlock && shouldCallCompletedBlock) {
                    completedBlock(image, data, error, cacheType, finished, url);
                }
            };
            
            // case 1a: we got an image, but the MWWebImageAvoidAutoSetImage flag is set
            // OR
            // case 1b: we got no image and the MWWebImageDelayPlaceholder is not set
            if (shouldNotSetImage) {
                dispatch_main_async_safe(callCompletedBlockClojure);
                return;
            }
            
            UIImage *targetImage = nil;
            NSData *targetData = nil;
            if (image) {
                // case 2a: we got an image and the MWWebImageAvoidAutoSetImage is not set
                targetImage = image;
                targetData = data;
            } else if (options & MWWebImageDelayPlaceholder) {
                // case 2b: we got no image and the MWWebImageDelayPlaceholder flag is set
                targetImage = placeholder;
                targetData = nil;
            }
            
#if MW_UIKIT || MW_MAC
            // check whether we should use the image transition
            MWWebImageTransition *transition = nil;
            BOOL shouldUseTransition = NO;
            if (options & MWWebImageForceTransition) {
                // Always
                shouldUseTransition = YES;
            } else if (cacheType == MWImageCacheTypeNone) {
                // From network
                shouldUseTransition = YES;
            } else {
                // From disk (and, user don't use sync query)
                if (cacheType == MWImageCacheTypeMemory) {
                    shouldUseTransition = NO;
                } else if (cacheType == MWImageCacheTypeDisk) {
                    if (options & MWWebImageQueryMemoryDataSync || options & MWWebImageQueryDiskDataSync) {
                        shouldUseTransition = NO;
                    } else {
                        shouldUseTransition = YES;
                    }
                } else {
                    // Not valid cache type, fallback
                    shouldUseTransition = NO;
                }
            }
            if (finished && shouldUseTransition) {
                transition = self.MW_imageTransition;
            }
#endif
            dispatch_main_async_safe(^{
#if MW_UIKIT || MW_MAC
                [self MW_setImage:targetImage imageData:targetData basedOnClassOrViaCustomSetImageBlock:setImageBlock transition:transition cacheType:cacheType imageURL:imageURL];
#else
                [self MW_setImage:targetImage imageData:targetData basedOnClassOrViaCustomSetImageBlock:setImageBlock cacheType:cacheType imageURL:imageURL];
#endif
                callCompletedBlockClojure();
            });
        }];
        [self MW_setImageLoadOperation:operation forKey:validOperationKey];
    } else {
#if MW_UIKIT || MW_MAC
        [self MW_stopImageIndicator];
#endif
        dispatch_main_async_safe(^{
            if (completedBlock) {
                NSError *error = [NSError errorWithDomain:MWWebImageErrorDomain code:MWWebImageErrorInvalidURL userInfo:@{NSLocalizedDescriptionKey : @"Image url is nil"}];
                completedBlock(nil, nil, error, MWImageCacheTypeNone, YES, url);
            }
        });
    }
}

- (void)MW_cancelCurrentImageLoad {
    [self MW_cancelImageLoadOperationWithKey:self.MW_latestOperationKey];
    self.MW_latestOperationKey = nil;
}

- (void)MW_setImage:(UIImage *)image imageData:(NSData *)imageData basedOnClassOrViaCustomSetImageBlock:(MWSetImageBlock)setImageBlock cacheType:(MWImageCacheType)cacheType imageURL:(NSURL *)imageURL {
#if MW_UIKIT || MW_MAC
    [self MW_setImage:image imageData:imageData basedOnClassOrViaCustomSetImageBlock:setImageBlock transition:nil cacheType:cacheType imageURL:imageURL];
#else
    // watchOS does not support view transition. Simplify the logic
    if (setImageBlock) {
        setImageBlock(image, imageData, cacheType, imageURL);
    } else if ([self isKindOfClass:[UIImageView class]]) {
        UIImageView *imageView = (UIImageView *)self;
        [imageView setImage:image];
    }
#endif
}

#if MW_UIKIT || MW_MAC
- (void)MW_setImage:(UIImage *)image imageData:(NSData *)imageData basedOnClassOrViaCustomSetImageBlock:(MWSetImageBlock)setImageBlock transition:(MWWebImageTransition *)transition cacheType:(MWImageCacheType)cacheType imageURL:(NSURL *)imageURL {
    UIView *view = self;
    MWSetImageBlock finalSetImageBlock;
    if (setImageBlock) {
        finalSetImageBlock = setImageBlock;
    } else if ([view isKindOfClass:[UIImageView class]]) {
        UIImageView *imageView = (UIImageView *)view;
        finalSetImageBlock = ^(UIImage *setImage, NSData *setImageData, MWImageCacheType setCacheType, NSURL *setImageURL) {
            imageView.image = setImage;
        };
    }
#if MW_UIKIT
    else if ([view isKindOfClass:[UIButton class]]) {
        UIButton *button = (UIButton *)view;
        finalSetImageBlock = ^(UIImage *setImage, NSData *setImageData, MWImageCacheType setCacheType, NSURL *setImageURL) {
            [button setImage:setImage forState:UIControlStateNormal];
        };
    }
#endif
#if MW_MAC
    else if ([view isKindOfClass:[NSButton class]]) {
        NSButton *button = (NSButton *)view;
        finalSetImageBlock = ^(UIImage *setImage, NSData *setImageData, MWImageCacheType setCacheType, NSURL *setImageURL) {
            button.image = setImage;
        };
    }
#endif
    
    if (transition) {
        NSString *originalOperationKey = view.MW_latestOperationKey;

#if MW_UIKIT
        [UIView transitionWithView:view duration:0 options:0 animations:^{
            if (!view.MW_latestOperationKey || ![originalOperationKey isEqualToString:view.MW_latestOperationKey]) {
                return;
            }
            // 0 duration to let UIKit render placeholder and prepares block
            if (transition.prepares) {
                transition.prepares(view, image, imageData, cacheType, imageURL);
            }
        } completion:^(BOOL finished) {
            [UIView transitionWithView:view duration:transition.duration options:transition.animationOptions animations:^{
                if (!view.MW_latestOperationKey || ![originalOperationKey isEqualToString:view.MW_latestOperationKey]) {
                    return;
                }
                if (finalSetImageBlock && !transition.avoidAutoSetImage) {
                    finalSetImageBlock(image, imageData, cacheType, imageURL);
                }
                if (transition.animations) {
                    transition.animations(view, image);
                }
            } completion:^(BOOL finished) {
                if (!view.MW_latestOperationKey || ![originalOperationKey isEqualToString:view.MW_latestOperationKey]) {
                    return;
                }
                if (transition.completion) {
                    transition.completion(finished);
                }
            }];
        }];
#elif MW_MAC
        [NSAnimationContext runAnimationGroup:^(NSAnimationContext * _Nonnull prepareContext) {
            if (!view.MW_latestOperationKey || ![originalOperationKey isEqualToString:view.MW_latestOperationKey]) {
                return;
            }
            // 0 duration to let AppKit render placeholder and prepares block
            prepareContext.duration = 0;
            if (transition.prepares) {
                transition.prepares(view, image, imageData, cacheType, imageURL);
            }
        } completionHandler:^{
            [NSAnimationContext runAnimationGroup:^(NSAnimationContext * _Nonnull context) {
                if (!view.MW_latestOperationKey || ![originalOperationKey isEqualToString:view.MW_latestOperationKey]) {
                    return;
                }
                context.duration = transition.duration;
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
                CAMediaTimingFunction *timingFunction = transition.timingFunction;
#pragma clang diagnostic pop
                if (!timingFunction) {
                    timingFunction = MWTimingFunctionFromAnimationOptions(transition.animationOptions);
                }
                context.timingFunction = timingFunction;
                context.allowsImplicitAnimation = MW_OPTIONS_CONTAINS(transition.animationOptions, MWWebImageAnimationOptionAllowsImplicitAnimation);
                if (finalSetImageBlock && !transition.avoidAutoSetImage) {
                    finalSetImageBlock(image, imageData, cacheType, imageURL);
                }
                CATransition *trans = MWTransitionFromAnimationOptions(transition.animationOptions);
                if (trans) {
                    [view.layer addAnimation:trans forKey:kCATransition];
                }
                if (transition.animations) {
                    transition.animations(view, image);
                }
            } completionHandler:^{
                if (!view.MW_latestOperationKey || ![originalOperationKey isEqualToString:view.MW_latestOperationKey]) {
                    return;
                }
                if (transition.completion) {
                    transition.completion(YES);
                }
            }];
        }];
#endif
    } else {
        if (finalSetImageBlock) {
            finalSetImageBlock(image, imageData, cacheType, imageURL);
        }
    }
}
#endif

- (void)MW_setNeedsLayout {
#if MW_UIKIT
    [self setNeedsLayout];
#elif MW_MAC
    [self setNeedsLayout:YES];
#elif MW_WATCH
    // Do nothing because WatchKit automatically layout the view after property change
#endif
}

#if MW_UIKIT || MW_MAC

#pragma mark - Image Transition
- (MWWebImageTransition *)MW_imageTransition {
    return objc_getAssociatedObject(self, @selector(MW_imageTransition));
}

- (void)setMW_imageTransition:(MWWebImageTransition *)MW_imageTransition {
    objc_setAssociatedObject(self, @selector(MW_imageTransition), MW_imageTransition, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

#pragma mark - Indicator
- (id<MWWebImageIndicator>)MW_imageIndicator {
    return objc_getAssociatedObject(self, @selector(MW_imageIndicator));
}

- (void)setMW_imageIndicator:(id<MWWebImageIndicator>)MW_imageIndicator {
    // Remove the old indicator view
    id<MWWebImageIndicator> previousIndicator = self.MW_imageIndicator;
    [previousIndicator.indicatorView removeFromSuperview];
    
    objc_setAssociatedObject(self, @selector(MW_imageIndicator), MW_imageIndicator, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    
    // Add the new indicator view
    UIView *view = MW_imageIndicator.indicatorView;
    if (CGRectEqualToRect(view.frame, CGRectZero)) {
        view.frame = self.bounds;
    }
    // Center the indicator view
#if MW_MAC
    [view setFrameOrigin:CGPointMake(round((NSWidth(self.bounds) - NSWidth(view.frame)) / 2), round((NSHeight(self.bounds) - NSHeight(view.frame)) / 2))];
#else
    view.center = CGPointMake(CGRectGetMidX(self.bounds), CGRectGetMidY(self.bounds));
#endif
    view.hidden = NO;
    [self addSubview:view];
}

- (void)MW_startImageIndicator {
    id<MWWebImageIndicator> imageIndicator = self.MW_imageIndicator;
    if (!imageIndicator) {
        return;
    }
    dispatch_main_async_safe(^{
        [imageIndicator startAnimatingIndicator];
    });
}

- (void)MW_stopImageIndicator {
    id<MWWebImageIndicator> imageIndicator = self.MW_imageIndicator;
    if (!imageIndicator) {
        return;
    }
    dispatch_main_async_safe(^{
        [imageIndicator stopAnimatingIndicator];
    });
}

#endif

@end
