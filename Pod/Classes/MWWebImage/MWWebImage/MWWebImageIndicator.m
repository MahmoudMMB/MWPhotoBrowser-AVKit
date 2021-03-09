/*
 * This file is part of the MWWebImage package.
 * (c) Olivier Poitrey <rs@dailymotion.com>
 *
 * For the full copyright and license information, please view the LICENSE
 * file that was distributed with this source code.
 */

#import "MWWebImageIndicator.h"

#if MW_UIKIT || MW_MAC

#if MW_MAC
#import <QuartzCore/QuartzCore.h>
#endif

#if MW_UIKIT
#if __IPHONE_13_0 || __TVOS_13_0 || __MAC_10_15
// Xcode 11
#else
// Supports Xcode 10 users, for those users, define these enum
static NSInteger UIActivityIndicatorViewStyleMedium = 100;
static NSInteger UIActivityIndicatorViewStyleLarge = 101;
#endif
#endif

#pragma mark - Activity Indicator

@interface MWWebImageActivityIndicator ()

#if MW_UIKIT
@property (nonatomic, strong, readwrite, nonnull) UIActivityIndicatorView *indicatorView;
#else
@property (nonatomic, strong, readwrite, nonnull) NSProgressIndicator *indicatorView;
#endif

@end

@implementation MWWebImageActivityIndicator

- (instancetype)init {
    self = [super init];
    if (self) {
        [self commonInit];
    }
    return self;
}

#if MW_UIKIT
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
- (void)commonInit {
    self.indicatorView = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhite];
    self.indicatorView.autoresizingMask = UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleBottomMargin;
}
#pragma clang diagnostic pop
#endif

#if MW_MAC
- (void)commonInit {
    self.indicatorView = [[NSProgressIndicator alloc] initWithFrame:NSZeroRect];
    self.indicatorView.style = NSProgressIndicatorStyleSpinning;
    self.indicatorView.controlSize = NSControlSizeSmall;
    [self.indicatorView sizeToFit];
    self.indicatorView.autoresizingMask = NSViewMaxXMargin | NSViewMinXMargin | NSViewMaxYMargin | NSViewMinYMargin;
}
#endif

- (void)startAnimatingIndicator {
#if MW_UIKIT
    [self.indicatorView startAnimating];
#else
    [self.indicatorView startAnimation:nil];
#endif
    self.indicatorView.hidden = NO;
}

- (void)stopAnimatingIndicator {
#if MW_UIKIT
    [self.indicatorView stopAnimating];
#else
    [self.indicatorView stopAnimation:nil];
#endif
    self.indicatorView.hidden = YES;
}

@end

@implementation MWWebImageActivityIndicator (Conveniences)

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
+ (MWWebImageActivityIndicator *)grayIndicator {
    MWWebImageActivityIndicator *indicator = [MWWebImageActivityIndicator new];
#if MW_UIKIT
#if MW_IOS
    indicator.indicatorView.activityIndicatorViewStyle = UIActivityIndicatorViewStyleGray;
#else
    indicator.indicatorView.color = [UIColor colorWithWhite:0 alpha:0.45]; // Color from `UIActivityIndicatorViewStyleGray`
#endif
#else
    indicator.indicatorView.appearance = [NSAppearance appearanceNamed:NSAppearanceNameAqua]; // Disable dark mode support
#endif
    return indicator;
}

+ (MWWebImageActivityIndicator *)grayLargeIndicator {
    MWWebImageActivityIndicator *indicator = MWWebImageActivityIndicator.grayIndicator;
#if MW_UIKIT
    UIColor *grayColor = indicator.indicatorView.color;
    indicator.indicatorView.activityIndicatorViewStyle = UIActivityIndicatorViewStyleWhiteLarge;
    indicator.indicatorView.color = grayColor;
#else
    indicator.indicatorView.appearance = [NSAppearance appearanceNamed:NSAppearanceNameAqua]; // Disable dark mode support
    indicator.indicatorView.controlSize = NSControlSizeRegular;
#endif
    [indicator.indicatorView sizeToFit];
    return indicator;
}

+ (MWWebImageActivityIndicator *)whiteIndicator {
    MWWebImageActivityIndicator *indicator = [MWWebImageActivityIndicator new];
#if MW_UIKIT
    indicator.indicatorView.activityIndicatorViewStyle = UIActivityIndicatorViewStyleWhite;
#else
    indicator.indicatorView.appearance = [NSAppearance appearanceNamed:NSAppearanceNameAqua]; // Disable dark mode support
    CIFilter *lighten = [CIFilter filterWithName:@"CIColorControls"];
    [lighten setDefaults];
    [lighten setValue:@(1) forKey:kCIInputBrightnessKey];
    indicator.indicatorView.contentFilters = @[lighten];
#endif
    return indicator;
}

+ (MWWebImageActivityIndicator *)whiteLargeIndicator {
    MWWebImageActivityIndicator *indicator = MWWebImageActivityIndicator.whiteIndicator;
#if MW_UIKIT
    indicator.indicatorView.activityIndicatorViewStyle = UIActivityIndicatorViewStyleWhiteLarge;
#else
    indicator.indicatorView.appearance = [NSAppearance appearanceNamed:NSAppearanceNameAqua]; // Disable dark mode support
    indicator.indicatorView.controlSize = NSControlSizeRegular;
    [indicator.indicatorView sizeToFit];
#endif
    return indicator;
}

+ (MWWebImageActivityIndicator *)largeIndicator {
    MWWebImageActivityIndicator *indicator = [MWWebImageActivityIndicator new];
#if MW_UIKIT
    if (@available(iOS 13.0, tvOS 13.0, *)) {
        indicator.indicatorView.activityIndicatorViewStyle = UIActivityIndicatorViewStyleLarge;
    } else {
        indicator.indicatorView.activityIndicatorViewStyle = UIActivityIndicatorViewStyleWhiteLarge;
    }
#else
    indicator.indicatorView.controlSize = NSControlSizeRegular;
    [indicator.indicatorView sizeToFit];
#endif
    return indicator;
}

+ (MWWebImageActivityIndicator *)mediumIndicator {
    MWWebImageActivityIndicator *indicator = [MWWebImageActivityIndicator new];
#if MW_UIKIT
    if (@available(iOS 13.0, tvOS 13.0, *)) {
        indicator.indicatorView.activityIndicatorViewStyle = UIActivityIndicatorViewStyleMedium;
    } else {
        indicator.indicatorView.activityIndicatorViewStyle = UIActivityIndicatorViewStyleWhite;
    }
#else
    indicator.indicatorView.controlSize = NSControlSizeSmall;
    [indicator.indicatorView sizeToFit];
#endif
    return indicator;
}
#pragma clang diagnostic pop

@end

#pragma mark - Progress Indicator

@interface MWWebImageProgressIndicator ()

#if MW_UIKIT
@property (nonatomic, strong, readwrite, nonnull) UIProgressView *indicatorView;
#else
@property (nonatomic, strong, readwrite, nonnull) NSProgressIndicator *indicatorView;
#endif

@end

@implementation MWWebImageProgressIndicator

- (instancetype)init {
    self = [super init];
    if (self) {
        [self commonInit];
    }
    return self;
}

#if MW_UIKIT
- (void)commonInit {
    self.indicatorView = [[UIProgressView alloc] initWithProgressViewStyle:UIProgressViewStyleDefault];
    self.indicatorView.autoresizingMask = UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleBottomMargin;
}
#endif

#if MW_MAC
- (void)commonInit {
    self.indicatorView = [[NSProgressIndicator alloc] initWithFrame:NSMakeRect(0, 0, 160, 0)]; // Width from `UIProgressView` default width
    self.indicatorView.style = NSProgressIndicatorStyleBar;
    self.indicatorView.controlSize = NSControlSizeSmall;
    [self.indicatorView sizeToFit];
    self.indicatorView.autoresizingMask = NSViewMaxXMargin | NSViewMinXMargin | NSViewMaxYMargin | NSViewMinYMargin;
}
#endif

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wunguarded-availability"
- (void)startAnimatingIndicator {
    self.indicatorView.hidden = NO;
#if MW_UIKIT
    if ([self.indicatorView respondsToSelector:@selector(observedProgress)] && self.indicatorView.observedProgress) {
        // Ignore NSProgress
    } else {
        self.indicatorView.progress = 0;
    }
#else
    self.indicatorView.indeterminate = YES;
    self.indicatorView.doubleValue = 0;
    [self.indicatorView startAnimation:nil];
#endif
}

- (void)stopAnimatingIndicator {
    self.indicatorView.hidden = YES;
#if MW_UIKIT
    if ([self.indicatorView respondsToSelector:@selector(observedProgress)] && self.indicatorView.observedProgress) {
        // Ignore NSProgress
    } else {
        self.indicatorView.progress = 1;
    }
#else
    self.indicatorView.indeterminate = NO;
    self.indicatorView.doubleValue = 100;
    [self.indicatorView stopAnimation:nil];
#endif
}

- (void)updateIndicatorProgress:(double)progress {
#if MW_UIKIT
    if ([self.indicatorView respondsToSelector:@selector(observedProgress)] && self.indicatorView.observedProgress) {
        // Ignore NSProgress
    } else {
        [self.indicatorView setProgress:progress animated:YES];
    }
#else
    self.indicatorView.indeterminate = progress > 0 ? NO : YES;
    self.indicatorView.doubleValue = progress * 100;
#endif
}
#pragma clang diagnostic pop

@end

@implementation MWWebImageProgressIndicator (Conveniences)

+ (MWWebImageProgressIndicator *)defaultIndicator {
    MWWebImageProgressIndicator *indicator = [MWWebImageProgressIndicator new];
    return indicator;
}

#if MW_IOS
+ (MWWebImageProgressIndicator *)barIndicator {
    MWWebImageProgressIndicator *indicator = [MWWebImageProgressIndicator new];
    indicator.indicatorView.progressViewStyle = UIProgressViewStyleBar;
    return indicator;
}
#endif

@end

#endif
