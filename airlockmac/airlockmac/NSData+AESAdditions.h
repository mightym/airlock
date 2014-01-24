//
//  NSData+AESAdditions.h
//  airlockmac
//
//  Created by Tobias Liebig on 13.01.14.
//  Copyright (c) 2014 Mark Wirblich. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSData (AESAdditions)

- (NSData*)AES256EncryptWithKey:(NSString*)key iv:(NSString*)iv;
- (NSData*)AES256DecryptWithKey:(NSString*)key iv:(NSString*)iv;

@end
