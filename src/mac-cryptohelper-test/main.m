//
//  main.m
//  ReceiptTester
//
//  Created by Vlad Shcherban on 2018-10-08.
//  Copyright © 2018 Vlad Shcherban. All rights reserved.
//

#import <Foundation/Foundation.h>

static id appleIAP_decryptReceipt(NSData *data) {
	id ret = nil;
	Class class = NSClassFromString(@"AppleIAP_CryptoHelper");
	if(class) {
		ret = [class performSelector:NSSelectorFromString(@"decryptReceipt:") withObject:data];
	}
	return ret;
}

int main(int argc, const char * argv[]) {
	NSString *file = [[NSString alloc] initWithUTF8String:argv[1]];
	NSData *data = [[NSData alloc] initWithContentsOfFile:file];
	[file release];
	
#if 1
	@autoreleasepool {
		// argv[1] == "$(PROJECT_DIR)/receipt"
		NSDictionary* result = appleIAP_decryptReceipt(data)?:@{};
		NSData *jsonData = [NSJSONSerialization dataWithJSONObject:result
														   options:NSJSONWritingPrettyPrinted
															 error:nil];

		NSString *json = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
		NSLog(@"%@", json);
	}
#else // for memory leaks
	for (int i=0; i<100; i++) {
		@autoreleasepool {
			NSDictionary* result = appleIAP_decryptReceipt(data);
			NSLog(@"%d: %d", i, result!=nil);
			[NSThread sleepForTimeInterval:0.5];
			kdebug_signpost(0,0,0,0,0);
			[NSThread sleepForTimeInterval:0.5];
		}
	}
#endif
	[data release];
	return 0;
}
