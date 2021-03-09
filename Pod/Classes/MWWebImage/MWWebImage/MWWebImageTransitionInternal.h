/*
* This file is part of the MWWebImage package.
* (c) Olivier Poitrey <rs@dailymotion.com>
*
* For the full copyright and license information, please view the LICENSE
* file that was distributed with this source code.
*/

#import "MWWebImageCompat.h"

#if MW_MAC

#import <QuartzCore/QuartzCore.h>

/// Helper method for Core Animation transition
FOUNDATION_EXPORT CAMediaTimingFunction * _Nullable MWTimingFunctionFromAnimationOptions(MWWebImageAnimationOptions options);
FOUNDATION_EXPORT CATransition * _Nullable MWTransitionFromAnimationOptions(MWWebImageAnimationOptions options);

#endif
