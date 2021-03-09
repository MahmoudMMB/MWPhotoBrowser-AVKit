/*
 * This file is part of the MWWebImage package.
 * (c) Olivier Poitrey <rs@dailymotion.com>
 *
 * For the full copyright and license information, please view the LICENSE
 * file that was distributed with this source code.
 */

#import <Foundation/Foundation.h>
#import "MWWebImageCompat.h"
#import "MWWebImageDefine.h"

@class MWWebImageOptionsResult;

typedef MWWebImageOptionsResult * _Nullable(^MWWebImageOptionsProcessorBlock)(NSURL * _Nullable url, MWWebImageOptions options, MWWebImageContext * _Nullable context);

/**
 The options result contains both options and context.
 */
@interface MWWebImageOptionsResult : NSObject

/**
 WebCache options.
 */
@property (nonatomic, assign, readonly) MWWebImageOptions options;

/**
 Context options.
 */
@property (nonatomic, copy, readonly, nullable) MWWebImageContext *context;

/**
 Create a new options result.

 @param options options
 @param context context
 @return The options result contains both options and context.
 */
- (nonnull instancetype)initWithOptions:(MWWebImageOptions)options context:(nullable MWWebImageContext *)context;

@end

/**
 This is the protocol for options processor.
 Options processor can be used, to control the final result for individual image request's `MWWebImageOptions` and `MWWebImageContext`
 Implements the protocol to have a global control for each indivadual image request's option.
 */
@protocol MWWebImageOptionsProcessor <NSObject>

/**
 Return the processed options result for specify image URL, with its options and context

 @param url The URL to the image
 @param options A mask to specify options to use for this request
 @param context A context contains different options to perform specify changes or processes, see `MWWebImageContextOption`. This hold the extra objects which `options` enum can not hold.
 @return The processed result, contains both options and context
 */
- (nullable MWWebImageOptionsResult *)processedResultForURL:(nullable NSURL *)url
                                                    options:(MWWebImageOptions)options
                                                    context:(nullable MWWebImageContext *)context;

@end

/**
 A options processor class with block.
 */
@interface MWWebImageOptionsProcessor : NSObject<MWWebImageOptionsProcessor>

- (nonnull instancetype)initWithBlock:(nonnull MWWebImageOptionsProcessorBlock)block;
+ (nonnull instancetype)optionsProcessorWithBlock:(nonnull MWWebImageOptionsProcessorBlock)block;

@end
