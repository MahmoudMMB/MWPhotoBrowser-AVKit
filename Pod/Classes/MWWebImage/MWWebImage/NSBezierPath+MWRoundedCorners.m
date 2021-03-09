/*
 * This file is part of the MWWebImage package.
 * (c) Olivier Poitrey <rs@dailymotion.com>
 *
 * For the full copyright and license information, please view the LICENSE
 * file that was distributed with this source code.
 */

#import "NSBezierPath+MWRoundedCorners.h"

#if MW_MAC

@implementation NSBezierPath (MWRoundedCorners)

+ (instancetype)MW_bezierPathWithRoundedRect:(NSRect)rect byRoundingCorners:(MWRectCorner)corners cornerRadius:(CGFloat)cornerRadius {
    NSBezierPath *path = [NSBezierPath bezierPath];
    
    CGFloat maxCorner = MIN(NSWidth(rect), NSHeight(rect)) / 2;
    
    CGFloat topLeftRadius = MIN(maxCorner, (corners & MWRectCornerTopLeft) ? cornerRadius : 0);
    CGFloat topRightRadius = MIN(maxCorner, (corners & MWRectCornerTopRight) ? cornerRadius : 0);
    CGFloat bottomLeftRadius = MIN(maxCorner, (corners & MWRectCornerBottomLeft) ? cornerRadius : 0);
    CGFloat bottomRightRadius = MIN(maxCorner, (corners & MWRectCornerBottomRight) ? cornerRadius : 0);
    
    NSPoint topLeft = NSMakePoint(NSMinX(rect), NSMaxY(rect));
    NSPoint topRight = NSMakePoint(NSMaxX(rect), NSMaxY(rect));
    NSPoint bottomLeft = NSMakePoint(NSMinX(rect), NSMinY(rect));
    NSPoint bottomRight = NSMakePoint(NSMaxX(rect), NSMinY(rect));
    
    [path moveToPoint:NSMakePoint(NSMidX(rect), NSMaxY(rect))];
    [path appendBezierPathWithArcFromPoint:topLeft toPoint:bottomLeft radius:topLeftRadius];
    [path appendBezierPathWithArcFromPoint:bottomLeft toPoint:bottomRight radius:bottomLeftRadius];
    [path appendBezierPathWithArcFromPoint:bottomRight toPoint:topRight radius:bottomRightRadius];
    [path appendBezierPathWithArcFromPoint:topRight toPoint:topLeft radius:topRightRadius];
    [path closePath];
    
    return path;
}

@end

#endif
