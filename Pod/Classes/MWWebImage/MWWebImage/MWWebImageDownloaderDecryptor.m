/*
* This file is part of the MWWebImage package.
* (c) Olivier Poitrey <rs@dailymotion.com>
*
* For the full copyright and license information, please view the LICENSE
* file that was distributed with this source code.
*/

#import "MWWebImageDownloaderDecryptor.h"

@interface MWWebImageDownloaderDecryptor ()

@property (nonatomic, copy, nonnull) MWWebImageDownloaderDecryptorBlock block;

@end

@implementation MWWebImageDownloaderDecryptor

- (instancetype)initWithBlock:(MWWebImageDownloaderDecryptorBlock)block {
    self = [super init];
    if (self) {
        self.block = block;
    }
    return self;
}

+ (instancetype)decryptorWithBlock:(MWWebImageDownloaderDecryptorBlock)block {
    MWWebImageDownloaderDecryptor *decryptor = [[MWWebImageDownloaderDecryptor alloc] initWithBlock:block];
    return decryptor;
}

- (nullable NSData *)decryptedDataWithData:(nonnull NSData *)data response:(nullable NSURLResponse *)response {
    if (!self.block) {
        return nil;
    }
    return self.block(data, response);
}

@end

@implementation MWWebImageDownloaderDecryptor (Conveniences)

+ (MWWebImageDownloaderDecryptor *)base64Decryptor {
    static MWWebImageDownloaderDecryptor *decryptor;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        decryptor = [MWWebImageDownloaderDecryptor decryptorWithBlock:^NSData * _Nullable(NSData * _Nonnull data, NSURLResponse * _Nullable response) {
            NSData *modifiedData = [[NSData alloc] initWithBase64EncodedData:data options:NSDataBase64DecodingIgnoreUnknownCharacters];
            return modifiedData;
        }];
    });
    return decryptor;
}

@end
