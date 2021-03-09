/*
* This file is part of the MWWebImage package.
* (c) Olivier Poitrey <rs@dailymotion.com>
* (c) Fabrice Aneche
*
* For the full copyright and license information, please view the LICENSE
* file that was distributed with this source code.
*/

#import "UIImage+ExtendedCacheData.h"
#import <objc/runtime.h>

@implementation UIImage (ExtendedCacheData)

- (id<NSObject, NSCoding>)MW_extendedObject {
    return objc_getAssociatedObject(self, @selector(MW_extendedObject));
}

- (void)setMW_extendedObject:(id<NSObject, NSCoding>)MW_extendedObject {
    objc_setAssociatedObject(self, @selector(MW_extendedObject), MW_extendedObject, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

@end
