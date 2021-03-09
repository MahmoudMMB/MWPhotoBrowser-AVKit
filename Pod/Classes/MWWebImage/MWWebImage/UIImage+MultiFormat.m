/*
 * This file is part of the MWWebImage package.
 * (c) Olivier Poitrey <rs@dailymotion.com>
 *
 * For the full copyright and license information, please view the LICENSE
 * file that was distributed with this source code.
 */

#import "UIImage+MultiFormat.h"
#import "MWImageCodersManager.h"

@implementation UIImage (MultiFormat)

+ (nullable UIImage *)MW_imageWithData:(nullable NSData *)data {
    return [self MW_imageWithData:data scale:1];
}

+ (nullable UIImage *)MW_imageWithData:(nullable NSData *)data scale:(CGFloat)scale {
    return [self MW_imageWithData:data scale:scale firstFrameOnly:NO];
}

+ (nullable UIImage *)MW_imageWithData:(nullable NSData *)data scale:(CGFloat)scale firstFrameOnly:(BOOL)firstFrameOnly {
    if (!data) {
        return nil;
    }
    MWImageCoderOptions *options = @{MWImageCoderDecodeScaleFactor : @(MAX(scale, 1)), MWImageCoderDecodeFirstFrameOnly : @(firstFrameOnly)};
    return [[MWImageCodersManager sharedManager] decodedImageWithData:data options:options];
}

- (nullable NSData *)MW_imageData {
    return [self MW_imageDataAsFormat:MWImageFormatUndefined];
}

- (nullable NSData *)MW_imageDataAsFormat:(MWImageFormat)imageFormat {
    return [self MW_imageDataAsFormat:imageFormat compressionQuality:1];
}

- (nullable NSData *)MW_imageDataAsFormat:(MWImageFormat)imageFormat compressionQuality:(double)compressionQuality {
    return [self MW_imageDataAsFormat:imageFormat compressionQuality:compressionQuality firstFrameOnly:NO];
}

- (nullable NSData *)MW_imageDataAsFormat:(MWImageFormat)imageFormat compressionQuality:(double)compressionQuality firstFrameOnly:(BOOL)firstFrameOnly {
    MWImageCoderOptions *options = @{MWImageCoderEncodeCompressionQuality : @(compressionQuality), MWImageCoderEncodeFirstFrameOnly : @(firstFrameOnly)};
    return [[MWImageCodersManager sharedManager] encodedDataWithImage:self format:imageFormat options:options];
}

@end
