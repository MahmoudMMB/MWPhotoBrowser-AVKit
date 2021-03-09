/*
 * This file is part of the MWWebImage package.
 * (c) Olivier Poitrey <rs@dailymotion.com>
 *
 * For the full copyright and license information, please view the LICENSE
 * file that was distributed with this source code.
 */

#import "MWWebImageTransition.h"

#if MW_UIKIT || MW_MAC

#if MW_MAC
#import "MWWebImageTransitionInternal.h"
#import "MWInternalMacros.h"

CAMediaTimingFunction * MWTimingFunctionFromAnimationOptions(MWWebImageAnimationOptions options) {
    if (MW_OPTIONS_CONTAINS(MWWebImageAnimationOptionCurveLinear, options)) {
        return [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionLinear];
    } else if (MW_OPTIONS_CONTAINS(MWWebImageAnimationOptionCurveEaseIn, options)) {
        return [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseIn];
    } else if (MW_OPTIONS_CONTAINS(MWWebImageAnimationOptionCurveEaseOut, options)) {
        return [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseOut];
    } else if (MW_OPTIONS_CONTAINS(MWWebImageAnimationOptionCurveEaseInOut, options)) {
        return [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
    } else {
        return [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionDefault];
    }
}

CATransition * MWTransitionFromAnimationOptions(MWWebImageAnimationOptions options) {
    if (MW_OPTIONS_CONTAINS(options, MWWebImageAnimationOptionTransitionCrosMWissolve)) {
        CATransition *trans = [CATransition animation];
        trans.type = kCATransitionFade;
        return trans;
    } else if (MW_OPTIONS_CONTAINS(options, MWWebImageAnimationOptionTransitionFlipFromLeft)) {
        CATransition *trans = [CATransition animation];
        trans.type = kCATransitionPush;
        trans.subtype = kCATransitionFromLeft;
        return trans;
    } else if (MW_OPTIONS_CONTAINS(options, MWWebImageAnimationOptionTransitionFlipFromRight)) {
        CATransition *trans = [CATransition animation];
        trans.type = kCATransitionPush;
        trans.subtype = kCATransitionFromRight;
        return trans;
    } else if (MW_OPTIONS_CONTAINS(options, MWWebImageAnimationOptionTransitionFlipFromTop)) {
        CATransition *trans = [CATransition animation];
        trans.type = kCATransitionPush;
        trans.subtype = kCATransitionFromTop;
        return trans;
    } else if (MW_OPTIONS_CONTAINS(options, MWWebImageAnimationOptionTransitionFlipFromBottom)) {
        CATransition *trans = [CATransition animation];
        trans.type = kCATransitionPush;
        trans.subtype = kCATransitionFromBottom;
        return trans;
    } else if (MW_OPTIONS_CONTAINS(options, MWWebImageAnimationOptionTransitionCurlUp)) {
        CATransition *trans = [CATransition animation];
        trans.type = kCATransitionReveal;
        trans.subtype = kCATransitionFromTop;
        return trans;
    } else if (MW_OPTIONS_CONTAINS(options, MWWebImageAnimationOptionTransitionCurlDown)) {
        CATransition *trans = [CATransition animation];
        trans.type = kCATransitionReveal;
        trans.subtype = kCATransitionFromBottom;
        return trans;
    } else {
        return nil;
    }
}
#endif

@implementation MWWebImageTransition

- (instancetype)init {
    self = [super init];
    if (self) {
        self.duration = 0.5;
    }
    return self;
}

@end

@implementation MWWebImageTransition (Conveniences)

+ (MWWebImageTransition *)fadeTransition {
    return [self fadeTransitionWithDuration:0.5];
}

+ (MWWebImageTransition *)fadeTransitionWithDuration:(NSTimeInterval)duration {
    MWWebImageTransition *transition = [MWWebImageTransition new];
    transition.duration = duration;
#if MW_UIKIT
    transition.animationOptions = UIViewAnimationOptionTransitionCrossDissolve | UIViewAnimationOptionAllowUserInteraction;
#else
    transition.animationOptions = MWWebImageAnimationOptionTransitionCrosMWissolve;
#endif
    return transition;
}

+ (MWWebImageTransition *)flipFromLeftTransition {
    return [self flipFromLeftTransitionWithDuration:0.5];
}

+ (MWWebImageTransition *)flipFromLeftTransitionWithDuration:(NSTimeInterval)duration {
    MWWebImageTransition *transition = [MWWebImageTransition new];
    transition.duration = duration;
#if MW_UIKIT
    transition.animationOptions = UIViewAnimationOptionTransitionFlipFromLeft | UIViewAnimationOptionAllowUserInteraction;
#else
    transition.animationOptions = MWWebImageAnimationOptionTransitionFlipFromLeft;
#endif
    return transition;
}

+ (MWWebImageTransition *)flipFromRightTransition {
    return [self flipFromRightTransitionWithDuration:0.5];
}

+ (MWWebImageTransition *)flipFromRightTransitionWithDuration:(NSTimeInterval)duration {
    MWWebImageTransition *transition = [MWWebImageTransition new];
    transition.duration = duration;
#if MW_UIKIT
    transition.animationOptions = UIViewAnimationOptionTransitionFlipFromRight | UIViewAnimationOptionAllowUserInteraction;
#else
    transition.animationOptions = MWWebImageAnimationOptionTransitionFlipFromRight;
#endif
    return transition;
}

+ (MWWebImageTransition *)flipFromTopTransition {
    return [self flipFromTopTransitionWithDuration:0.5];
}

+ (MWWebImageTransition *)flipFromTopTransitionWithDuration:(NSTimeInterval)duration {
    MWWebImageTransition *transition = [MWWebImageTransition new];
    transition.duration = duration;
#if MW_UIKIT
    transition.animationOptions = UIViewAnimationOptionTransitionFlipFromTop | UIViewAnimationOptionAllowUserInteraction;
#else
    transition.animationOptions = MWWebImageAnimationOptionTransitionFlipFromTop;
#endif
    return transition;
}

+ (MWWebImageTransition *)flipFromBottomTransition {
    return [self flipFromBottomTransitionWithDuration:0.5];
}

+ (MWWebImageTransition *)flipFromBottomTransitionWithDuration:(NSTimeInterval)duration {
    MWWebImageTransition *transition = [MWWebImageTransition new];
    transition.duration = duration;
#if MW_UIKIT
    transition.animationOptions = UIViewAnimationOptionTransitionFlipFromBottom | UIViewAnimationOptionAllowUserInteraction;
#else
    transition.animationOptions = MWWebImageAnimationOptionTransitionFlipFromBottom;
#endif
    return transition;
}

+ (MWWebImageTransition *)curlUpTransition {
    return [self curlUpTransitionWithDuration:0.5];
}

+ (MWWebImageTransition *)curlUpTransitionWithDuration:(NSTimeInterval)duration {
    MWWebImageTransition *transition = [MWWebImageTransition new];
    transition.duration = duration;
#if MW_UIKIT
    transition.animationOptions = UIViewAnimationOptionTransitionCurlUp | UIViewAnimationOptionAllowUserInteraction;
#else
    transition.animationOptions = MWWebImageAnimationOptionTransitionCurlUp;
#endif
    return transition;
}

+ (MWWebImageTransition *)curlDownTransition {
    return [self curlDownTransitionWithDuration:0.5];
}

+ (MWWebImageTransition *)curlDownTransitionWithDuration:(NSTimeInterval)duration {
    MWWebImageTransition *transition = [MWWebImageTransition new];
    transition.duration = duration;
#if MW_UIKIT
    transition.animationOptions = UIViewAnimationOptionTransitionCurlDown | UIViewAnimationOptionAllowUserInteraction;
#else
    transition.animationOptions = MWWebImageAnimationOptionTransitionCurlDown;
#endif
    transition.duration = duration;
    return transition;
}

@end

#endif
