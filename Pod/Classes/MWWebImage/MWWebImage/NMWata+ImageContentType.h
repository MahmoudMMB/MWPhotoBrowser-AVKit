/*
 * This file is part of the MWWebImage package.
 * (c) Olivier Poitrey <rs@dailymotion.com>
 * (c) Fabrice Aneche
 *
 * For the full copyright and license information, please view the LICENSE
 * file that was distributed with this source code.
 */

#import <Foundation/Foundation.h>
#import "MWWebImageCompat.h"

/**
 You can use switch case like normal enum. It's also recommended to add a default case. You should not assume anything about the raw value.
 For custom coder plugin, it can also extern the enum for supported format. See `MWImageCoder` for more detailed information.
 */
typedef NSInteger MWImageFormat NS_TYPED_EXTENSIBLE_ENUM;
static const MWImageFormat MWImageFormatUndefined = -1;
static const MWImageFormat MWImageFormatJPEG      = 0;
static const MWImageFormat MWImageFormatPNG       = 1;
static const MWImageFormat MWImageFormatGIF       = 2;
static const MWImageFormat MWImageFormatTIFF      = 3;
static const MWImageFormat MWImageFormatWebP      = 4;
static const MWImageFormat MWImageFormatHEIC      = 5;
static const MWImageFormat MWImageFormatHEIF      = 6;
static const MWImageFormat MWImageFormatPDF       = 7;
static const MWImageFormat MWImageFormatSVG       = 8;

/**
 NSData category about the image content type and UTI.
 */
@interface NSData (ImageContentType)

/**
 *  Return image format
 *
 *  @param data the input image data
 *
 *  @return the image format as `MWImageFormat` (enum)
 */
+ (MWImageFormat)MW_imageFormatForImageData:(nullable NSData *)data;

/**
 *  Convert MWImageFormat to UTType
 *
 *  @param format Format as MWImageFormat
 *  @return The UTType as CFStringRef
 *  @note For unknown format, `kUTTypeImage` abstract type will return
 */
+ (nonnull CFStringRef)MW_UTTypeFromImageFormat:(MWImageFormat)format CF_RETURNS_NOT_RETAINED NS_SWIFT_NAME(MW_UTType(from:));

/**
 *  Convert UTType to MWImageFormat
 *
 *  @param uttype The UTType as CFStringRef
 *  @return The Format as MWImageFormat
 *  @note For unknown type, `MWImageFormatUndefined` will return
 */
+ (MWImageFormat)MW_imageFormatFromUTType:(nonnull CFStringRef)uttype;

@end
