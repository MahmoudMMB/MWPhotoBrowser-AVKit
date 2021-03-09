/*
 * This file is part of the MWWebImage package.
 * (c) Olivier Poitrey <rs@dailymotion.com>
 *
 * For the full copyright and license information, please view the LICENSE
 * file that was distributed with this source code.
 */

#import <Foundation/Foundation.h>
#import "MWmetamacros.h"

#ifndef MW_LOCK
#define MW_LOCK(lock) dispatch_semaphore_wait(lock, DISPATCH_TIME_FOREVER);
#endif

#ifndef MW_UNLOCK
#define MW_UNLOCK(lock) dispatch_semaphore_signal(lock);
#endif

#ifndef MW_OPTIONS_CONTAINS
#define MW_OPTIONS_CONTAINS(options, value) (((options) & (value)) == (value))
#endif

#ifndef MW_CSTRING
#define MW_CSTRING(str) #str
#endif

#ifndef MW_NSSTRING
#define MW_NSSTRING(str) @(MW_CSTRING(str))
#endif

#ifndef MW_SEL_SPI
#define MW_SEL_SPI(name) NSSelectorFromString([NSString stringWithFormat:@"_%@", MW_NSSTRING(name)])
#endif

#ifndef weakify
#define weakify(...) \
MW_keywordify \
metamacro_foreach_cxt(MW_weakify_,, __weak, __VA_ARGS__)
#endif

#ifndef strongify
#define strongify(...) \
MW_keywordify \
_Pragma("clang diagnostic push") \
_Pragma("clang diagnostic ignored \"-Wshadow\"") \
metamacro_foreach(MW_strongify_,, __VA_ARGS__) \
_Pragma("clang diagnostic pop")
#endif

#define MW_weakify_(INDEX, CONTEXT, VAR) \
CONTEXT __typeof__(VAR) metamacro_concat(VAR, _weak_) = (VAR);

#define MW_strongify_(INDEX, VAR) \
__strong __typeof__(VAR) VAR = metamacro_concat(VAR, _weak_);

#if DEBUG
#define MW_keywordify autoreleasepool {}
#else
#define MW_keywordify try {} @catch (...) {}
#endif

#ifndef onExit
#define onExit \
MW_keywordify \
__strong MW_cleanupBlock_t metamacro_concat(MW_exitBlock_, __LINE__) __attribute__((cleanup(MW_executeCleanupBlock), unused)) = ^
#endif

typedef void (^MW_cleanupBlock_t)(void);

#if defined(__cplusplus)
extern "C" {
#endif
    void MW_executeCleanupBlock (__strong MW_cleanupBlock_t *block);
#if defined(__cplusplus)
}
#endif
