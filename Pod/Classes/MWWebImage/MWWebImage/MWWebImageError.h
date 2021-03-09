/*
 * This file is part of the MWWebImage package.
 * (c) Olivier Poitrey <rs@dailymotion.com>
 * (c) Jamie Pinkham
 *
 * For the full copyright and license information, please view the LICENSE
 * file that was distributed with this source code.
 */

#import "MWWebImageCompat.h"

FOUNDATION_EXPORT NSErrorDomain const _Nonnull MWWebImageErrorDomain;

/// The HTTP status code for invalid download response (NSNumber *)
FOUNDATION_EXPORT NSErrorUserInfoKey const _Nonnull MWWebImageErrorDownloadStatusCodeKey;

/// MWWebImage error domain and codes
typedef NS_ERROR_ENUM(MWWebImageErrorDomain, MWWebImageError) {
    MWWebImageErrorInvalidURL = 1000, // The URL is invalid, such as nil URL or corrupted URL
    MWWebImageErrorBadImageData = 1001, // The image data can not be decoded to image, or the image data is empty
    MWWebImageErrorCacheNotModified = 1002, // The remote location specify that the cached image is not modified, such as the HTTP response 304 code. It's useful for `MWWebImageRefreshCached`
    MWWebImageErrorBlackListed = 1003, // The URL is blacklisted because of unrecoverable failure marked by downloader (such as 404), you can use `.retryFailed` option to avoid this
    MWWebImageErrorInvalidDownloadOperation = 2000, // The image download operation is invalid, such as nil operation or unexpected error occur when operation initialized
    MWWebImageErrorInvalidDownloadStatusCode = 2001, // The image download response a invalid status code. You can check the status code in error's userInfo under `MWWebImageErrorDownloadStatusCodeKey`
    MWWebImageErrorCancelled = 2002, // The image loading operation is cancelled before finished, during either async disk cache query, or waiting before actual network request. For actual network request error, check `NSURLErrorDomain` error domain and code.
    MWWebImageErrorInvalidDownloadResponse = 2003, // When using response modifier, the modified download response is nil and marked as failed.
};
