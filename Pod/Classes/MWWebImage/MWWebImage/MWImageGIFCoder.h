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
 Built in coder using ImageIO that supports animated GIF encoding/decoding
 @note `MWImageIOCoder` supports GIF but only as static (will use the 1st frame).
 @note Use `MWImageGIFCoder` for fully animated GIFs. For `UIImageView`, it will produce animated `UIImage`(`NSImage` on macOS) for rendering. For `MWAnimatedImageView`, it will use `MWAnimatedImage` for rendering.
 @note The recommended approach for animated GIFs is using `MWAnimatedImage` with `MWAnimatedImageView`. It's more performant than `UIImageView` for GIF displaying(especially on memory usage)
 */
@interface MWImageGIFCoder : MWImageIOAnimatedCoder <MWProgressiveImageCoder, MWAnimatedImageCoder>

@property (nonatomic, class, readonly, nonnull) MWImageGIFCoder *sharedCoder;

@end
