/*
 * This file is part of the MWWebImage package.
 * (c) Olivier Poitrey <rs@dailymotion.com>
 *
 * For the full copyright and license information, please view the LICENSE
 * file that was distributed with this source code.
 */

#import <Foundation/Foundation.h>
#import "MWWebImageCompat.h"

/// This is used for operation management, but not for operation queue execute
@interface MWImageCachesManagerOperation : NSOperation

@property (nonatomic, assign, readonly) NSUInteger pendingCount;

- (void)beginWithTotalCount:(NSUInteger)totalCount;
- (void)completeOne;
- (void)done;

@end
