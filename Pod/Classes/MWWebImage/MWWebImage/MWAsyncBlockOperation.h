/*
 * This file is part of the MWWebImage package.
 * (c) Olivier Poitrey <rs@dailymotion.com>
 *
 * For the full copyright and license information, please view the LICENSE
 * file that was distributed with this source code.
 */

#import "MWWebImageCompat.h"

@class MWAsyncBlockOperation;
typedef void (^MWAsyncBlock)(MWAsyncBlockOperation * __nonnull asyncOperation);

/// A async block operation, success after you call `completer` (not like `NSBlockOperation` which is for sync block, success on return)
@interface MWAsyncBlockOperation : NSOperation

- (nonnull instancetype)initWithBlock:(nonnull MWAsyncBlock)block;
+ (nonnull instancetype)blockOperationWithBlock:(nonnull MWAsyncBlock)block;
- (void)complete;

@end
