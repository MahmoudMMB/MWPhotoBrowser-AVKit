/*
 * This file is part of the MWWebImage package.
 * (c) Olivier Poitrey <rs@dailymotion.com>
 *
 * For the full copyright and license information, please view the LICENSE
 * file that was distributed with this source code.
 */

#import "MWWebImageCompat.h"

#if MW_MAC

#import "UIImage+Transform.h"

@interface NSBezierPath (MWRoundedCorners)

/**
 Convenience way to create a bezier path with the specify rounding corners on macOS. Same as the one on `UIBezierPath`.
 */
+ (nonnull instancetype)MW_bezierPathWithRoundedRect:(NSRect)rect byRoundingCorners:(MWRectCorner)corners cornerRadius:(CGFloat)cornerRadius;

@end

#endif
