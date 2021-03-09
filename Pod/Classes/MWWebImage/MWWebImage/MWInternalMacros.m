/*
 * This file is part of the MWWebImage package.
 * (c) Olivier Poitrey <rs@dailymotion.com>
 *
 * For the full copyright and license information, please view the LICENSE
 * file that was distributed with this source code.
 */

#import "MWInternalMacros.h"

void MW_executeCleanupBlock (__strong MW_cleanupBlock_t *block) {
    (*block)();
}
