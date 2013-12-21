//
//  ALChallengeHelper.m
//  airlockmac
//
//  Created by Tobias Liebig on 21.12.13.
//  Copyright (c) 2013 Mark Wirblich. All rights reserved.
//

#import "ALChallengeHelper.h"
#import <CommonCrypto/CommonDigest.h>

#define kALChallengeSecret @"FBC29689-D890-4DCD-A7D2-41A95CAFBB5D"

@implementation ALChallengeHelper

+ (NSString*)calculateResponseForIncomingChallenge:(NSString*)incomingChallenge outgoingChallenge:(NSString*)outgoingChallenge
{
    return [NSString stringWithFormat:@"%@.%@",
                    [self sha1:[NSString stringWithFormat:@"%@%@%@",
                                incomingChallenge,
                                outgoingChallenge,
                                kALChallengeSecret]],
                          outgoingChallenge];

}

+ (NSString*)generateNewChallenge
{
    return [self sha1:[self generateRandomString:40]];
}

+ (NSString*)generateRandomString:(int)num
{
    NSMutableString* string = [NSMutableString stringWithCapacity:num];
    for (int i = 0; i < num; i++) {
        [string appendFormat:@"%C", (unichar)('a' + arc4random_uniform(25))];
    }
    return string;
}


+ (NSString *)sha1:(NSString*)string
{
    NSData *data = [string dataUsingEncoding:NSUTF8StringEncoding];
    uint8_t digest[CC_SHA1_DIGEST_LENGTH];
    
    CC_SHA1(data.bytes, (unsigned int)data.length, digest);
    
    NSMutableString *output = [NSMutableString stringWithCapacity:CC_SHA1_DIGEST_LENGTH * 2];
    
    for (int i = 0; i < CC_SHA1_DIGEST_LENGTH; i++) {
        [output appendFormat:@"%02x", digest[i]];
    }
    
    return output;
}


@end
