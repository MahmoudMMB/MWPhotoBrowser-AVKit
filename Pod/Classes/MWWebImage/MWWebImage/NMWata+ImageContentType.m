/*
 * This file is part of the MWWebImage package.
 * (c) Olivier Poitrey <rs@dailymotion.com>
 * (c) Fabrice Aneche
 *
 * For the full copyright and license information, please view the LICENSE
 * file that was distributed with this source code.
 */

#import "NMWata+ImageContentType.h"
#if MW_MAC
#import <CoreServices/CoreServices.h>
#else
#import <MobileCoreServices/MobileCoreServices.h>
#endif
#import "MWImageIOAnimatedCoderInternal.h"

#define kSVGTagEnd @"</svg>"

@implementation NSData (ImageContentType)

+ (MWImageFormat)MW_imageFormatForImageData:(nullable NSData *)data {
    if (!data) {
        return MWImageFormatUndefined;
    }
    
    // File signatures table: http://www.garykessler.net/library/file_sigs.html
    uint8_t c;
    [data getBytes:&c length:1];
    switch (c) {
        case 0xFF:
            return MWImageFormatJPEG;
        case 0x89:
            return MWImageFormatPNG;
        case 0x47:
            return MWImageFormatGIF;
        case 0x49:
        case 0x4D:
            return MWImageFormatTIFF;
        case 0x52: {
            if (data.length >= 12) {
                //RIFF....WEBP
                NSString *testString = [[NSString alloc] initWithData:[data subdataWithRange:NSMakeRange(0, 12)] encoding:NSASCIIStringEncoding];
                if ([testString hasPrefix:@"RIFF"] && [testString hasSuffix:@"WEBP"]) {
                    return MWImageFormatWebP;
                }
            }
            break;
        }
        case 0x00: {
            if (data.length >= 12) {
                //....ftypheic ....ftypheix ....ftyphevc ....ftyphevx
                NSString *testString = [[NSString alloc] initWithData:[data subdataWithRange:NSMakeRange(4, 8)] encoding:NSASCIIStringEncoding];
                if ([testString isEqualToString:@"ftypheic"]
                    || [testString isEqualToString:@"ftypheix"]
                    || [testString isEqualToString:@"ftyphevc"]
                    || [testString isEqualToString:@"ftyphevx"]) {
                    return MWImageFormatHEIC;
                }
                //....ftypmif1 ....ftypmsf1
                if ([testString isEqualToString:@"ftypmif1"] || [testString isEqualToString:@"ftypmsf1"]) {
                    return MWImageFormatHEIF;
                }
            }
            break;
        }
        case 0x25: {
            if (data.length >= 4) {
                //%PDF
                NSString *testString = [[NSString alloc] initWithData:[data subdataWithRange:NSMakeRange(1, 3)] encoding:NSASCIIStringEncoding];
                if ([testString isEqualToString:@"PDF"]) {
                    return MWImageFormatPDF;
                }
            }
        }
        case 0x3C: {
            // Check end with SVG tag
            if ([data rangeOfData:[kSVGTagEnd dataUsingEncoding:NSUTF8StringEncoding] options:NSDataSearchBackwards range: NSMakeRange(data.length - MIN(100, data.length), MIN(100, data.length))].location != NSNotFound) {
                return MWImageFormatSVG;
            }
        }
    }
    return MWImageFormatUndefined;
}

+ (nonnull CFStringRef)MW_UTTypeFromImageFormat:(MWImageFormat)format {
    CFStringRef UTType;
    switch (format) {
        case MWImageFormatJPEG:
            UTType = kUTTypeJPEG;
            break;
        case MWImageFormatPNG:
            UTType = kUTTypePNG;
            break;
        case MWImageFormatGIF:
            UTType = kUTTypeGIF;
            break;
        case MWImageFormatTIFF:
            UTType = kUTTypeTIFF;
            break;
        case MWImageFormatWebP:
            UTType = kMWUTTypeWebP;
            break;
        case MWImageFormatHEIC:
            UTType = kMWUTTypeHEIC;
            break;
        case MWImageFormatHEIF:
            UTType = kMWUTTypeHEIF;
            break;
        case MWImageFormatPDF:
            UTType = kUTTypePDF;
            break;
        case MWImageFormatSVG:
            UTType = kUTTypeScalableVectorGraphics;
            break;
        default:
            // default is kUTTypeImage abstract type
            UTType = kUTTypeImage;
            break;
    }
    return UTType;
}

+ (MWImageFormat)MW_imageFormatFromUTType:(CFStringRef)uttype {
    if (!uttype) {
        return MWImageFormatUndefined;
    }
    MWImageFormat imageFormat;
    if (CFStringCompare(uttype, kUTTypeJPEG, 0) == kCFCompareEqualTo) {
        imageFormat = MWImageFormatJPEG;
    } else if (CFStringCompare(uttype, kUTTypePNG, 0) == kCFCompareEqualTo) {
        imageFormat = MWImageFormatPNG;
    } else if (CFStringCompare(uttype, kUTTypeGIF, 0) == kCFCompareEqualTo) {
        imageFormat = MWImageFormatGIF;
    } else if (CFStringCompare(uttype, kUTTypeTIFF, 0) == kCFCompareEqualTo) {
        imageFormat = MWImageFormatTIFF;
    } else if (CFStringCompare(uttype, kMWUTTypeWebP, 0) == kCFCompareEqualTo) {
        imageFormat = MWImageFormatWebP;
    } else if (CFStringCompare(uttype, kMWUTTypeHEIC, 0) == kCFCompareEqualTo) {
        imageFormat = MWImageFormatHEIC;
    } else if (CFStringCompare(uttype, kMWUTTypeHEIF, 0) == kCFCompareEqualTo) {
        imageFormat = MWImageFormatHEIF;
    } else if (CFStringCompare(uttype, kUTTypePDF, 0) == kCFCompareEqualTo) {
        imageFormat = MWImageFormatPDF;
    } else if (CFStringCompare(uttype, kUTTypeScalableVectorGraphics, 0) == kCFCompareEqualTo) {
        imageFormat = MWImageFormatSVG;
    } else {
        imageFormat = MWImageFormatUndefined;
    }
    return imageFormat;
}

@end
