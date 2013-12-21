//
//  ALChallengeHelper.h
//  airlockmac
//
//  Created by Tobias Liebig on 21.12.13.
//  Copyright (c) 2013 Mark Wirblich. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface ALChallengeHelper : NSObject

+ (NSString*)calculateResponseForIncomingChallenge:(NSString*)incomingChallenge outgoingChallenge:(NSString*)outgoingChallenge;
+ (NSString*)generateNewChallenge;
+ (NSString*)generateRandomString:(int)num;
+ (NSString *)sha1:(NSString*)string;

@end
