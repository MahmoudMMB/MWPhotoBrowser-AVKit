/*
 * This file is part of the MWWebImage package.
 * (c) Olivier Poitrey <rs@dailymotion.com>
 *
 * For the full copyright and license information, please view the LICENSE
 * file that was distributed with this source code.
 */

#import <Foundation/Foundation.h>
#import "MWImageIOAnimatedCoder.h"

/**
 Built in coder using ImageIO that supports APNG encoding/decoding
 */
@interface MWImageAPNGCoder : MWImageIOAnimatedCoder <MWProgressiveImageCoder, MWAnimatedImageCoder>

@property (nonatomic, class, readonly, nonnull) MWImageAPNGCoder *sharedCoder;

@end
