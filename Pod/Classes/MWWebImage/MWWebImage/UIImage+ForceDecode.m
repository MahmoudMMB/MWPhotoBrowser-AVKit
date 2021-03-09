/*
 * This file is part of the MWWebImage package.
 * (c) Olivier Poitrey <rs@dailymotion.com>
 *
 * For the full copyright and license information, please view the LICENSE
 * file that was distributed with this source code.
 */

#import "UIImage+ForceDecode.h"
#import "MWImageCoderHelper.h"
#import "objc/runtime.h"

@implementation UIImage (ForceDecode)

- (BOOL)MW_iMWecoded {
    NSNumber *value = objc_getAssociatedObject(self, @selector(MW_iMWecoded));
    return value.boolValue;
}

- (void)setMW_iMWecoded:(BOOL)MW_iMWecoded {
    objc_setAssociatedObject(self, @selector(MW_iMWecoded), @(MW_iMWecoded), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

+ (nullable UIImage *)MW_decodedImageWithImage:(nullable UIImage *)image {
    if (!image) {
        return nil;
    }
    return [MWImageCoderHelper decodedImageWithImage:image];
}

+ (nullable UIImage *)MW_decodedAndScaledDownImageWithImage:(nullable UIImage *)image {
    return [self MW_decodedAndScaledDownImageWithImage:image limitBytes:0];
}

+ (nullable UIImage *)MW_decodedAndScaledDownImageWithImage:(nullable UIImage *)image limitBytes:(NSUInteger)bytes {
    if (!image) {
        return nil;
    }
    return [MWImageCoderHelper decodedAndScaledDownImageWithImage:image limitBytes:bytes];
}

@end
