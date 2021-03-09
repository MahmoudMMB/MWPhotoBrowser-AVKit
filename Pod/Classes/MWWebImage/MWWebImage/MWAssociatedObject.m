/*
* This file is part of the MWWebImage package.
* (c) Olivier Poitrey <rs@dailymotion.com>
*
* For the full copyright and license information, please view the LICENSE
* file that was distributed with this source code.
*/

#import "MWAssociatedObject.h"
#import "UIImage+Metadata.h"
#import "UIImage+ExtendedCacheData.h"
#import "UIImage+MemoryCacheCost.h"
#import "UIImage+ForceDecode.h"

void MWImageCopyAssociatedObject(UIImage * _Nullable source, UIImage * _Nullable target) {
    if (!source || !target) {
        return;
    }
    // Image Metadata
    target.MW_isIncremental = source.MW_isIncremental;
    target.MW_imageLoopCount = source.MW_imageLoopCount;
    target.MW_imageFormat = source.MW_imageFormat;
    // Force Decode
    target.MW_iMWecoded = source.MW_iMWecoded;
    // Extended Cache Data
    target.MW_extendedObject = source.MW_extendedObject;
}
