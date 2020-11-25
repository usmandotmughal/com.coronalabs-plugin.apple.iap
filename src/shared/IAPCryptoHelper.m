//
//  IAPCryptoHelper.m
//  IAPCryptoHelper
//
//  Created by Vlad Shcherban on 2018-10-07.
//

#import <Foundation/Foundation.h>
#if TARGET_OS_IPHONE
#import <UIKit/UIKit.h>
#elif TARGET_OS_OSX
#import <IOKit/IOKitLib.h>
#endif

#include <openssl/pkcs7.h>
#include <openssl/objects.h>
#include <openssl/sha.h>
#include <openssl/x509.h>
#include <openssl/err.h>


NSString* appleInc = @"MIIEuzCCA6OgAwIBAgIBAjANBgkqhkiG9w0BAQUFADBiMQswCQYDVQQGEwJVUzETMBEGA1UECh"
						"MKQXBwbGUgSW5jLjEmMCQGA1UECxMdQXBwbGUgQ2VydGlmaWNhdGlvbiBBdXRob3JpdHkxFjAU"
						"BgNVBAMTDUFwcGxlIFJvb3QgQ0EwHhcNMDYwNDI1MjE0MDM2WhcNMzUwMjA5MjE0MDM2WjBiMQ"
						"swCQYDVQQGEwJVUzETMBEGA1UEChMKQXBwbGUgSW5jLjEmMCQGA1UECxMdQXBwbGUgQ2VydGlm"
						"aWNhdGlvbiBBdXRob3JpdHkxFjAUBgNVBAMTDUFwcGxlIFJvb3QgQ0EwggEiMA0GCSqGSIb3DQ"
						"EBAQUAA4IBDwAwggEKAoIBAQDkkakJH5HbHkdQ6wXtXnmELes2oldMVeyLGYne+Uts9QerIjAC"
						"6Bg++FAJ039BqJj50cpmnCRrEdCju+QbKsMflZ56DKRHi1vUFjczy8QPTc4UadHJGXL1XQ7Vf1"
						"+b8iUDulWPTV0N8WQ1IxVLFVkds5T39pyez1C6wVhQZ48ItCD3y6wsIG9wtj8BMIy3Q88PnT3z"
						"K0koGsj+zrW5DtleHNbLPbU6rfQPDgCSC7EhFi501TwN22IWq6NxkkdTVcGvL0Gz+PvjcM3mo0"
						"xFfh9Ma1CWQYnEdGILEINBhzOKgbEwWOxaBDKMaLOPHd5lc/9nXmW8Sdh2nzMUZaF3lMktAgMB"
						"AAGjggF6MIIBdjAOBgNVHQ8BAf8EBAMCAQYwDwYDVR0TAQH/BAUwAwEB/zAdBgNVHQ4EFgQUK9"
						"BpR5R2Cf70a40uQKb3R01/CF4wHwYDVR0jBBgwFoAUK9BpR5R2Cf70a40uQKb3R01/CF4wggER"
						"BgNVHSAEggEIMIIBBDCCAQAGCSqGSIb3Y2QFATCB8jAqBggrBgEFBQcCARYeaHR0cHM6Ly93d3"
						"cuYXBwbGUuY29tL2FwcGxlY2EvMIHDBggrBgEFBQcCAjCBthqBs1JlbGlhbmNlIG9uIHRoaXMg"
						"Y2VydGlmaWNhdGUgYnkgYW55IHBhcnR5IGFzc3VtZXMgYWNjZXB0YW5jZSBvZiB0aGUgdGhlbi"
						"BhcHBsaWNhYmxlIHN0YW5kYXJkIHRlcm1zIGFuZCBjb25kaXRpb25zIG9mIHVzZSwgY2VydGlm"
						"aWNhdGUgcG9saWN5IGFuZCBjZXJ0aWZpY2F0aW9uIHByYWN0aWNlIHN0YXRlbWVudHMuMA0GCS"
						"qGSIb3DQEBBQUAA4IBAQBcNplMLXi37Yyb3PN3m/J20ncwT8EfhYOFG5k9RzfyqZtAjizUsZAS"
						"2L70c5vu0mQPy3lPNNiiPvl4/2vIB+x9OYOLUyDTOMSxv5pPCmv/K/xZpwUJfBdAVhEedNO3iy"
						"M7R6PVbyTi69G3cN8PReEnyvFteO3ntRcXqNx+IjXKJdXZD9Zr1KIkIxH3oayPc4FgxhtbCS+S"
						"svhESPBgOJ4V9T0mZyCKM2r3DYLP3uujL/lTaltkwGMzd/c6ByxW69oPIQ7aunMZT7XZNn/Bh1"
						"XZp5m5MkL72NVxnn6hUrcbvZNCJBIqxw8dtk2cXmPIS4AXUKqK1drk/NAJBzewdXUh";

@interface AppleIAP_CryptoHelper : NSObject
+(NSDictionary*)decryptReceipt:(NSData*)receiptData;
@end

@implementation AppleIAP_CryptoHelper
+(NSDictionary*)decryptReceipt:(NSData *)receiptData {
	if(!receiptData)
		return nil;
	
	NSDictionary* ret = [[[NSMutableDictionary alloc] init] autorelease];
	NSMutableArray *iaps = [[[NSMutableArray alloc] init] autorelease];
	[ret setValue:iaps forKey:@"in_app"];
	
	
	BIO *receiptBIO = BIO_new(BIO_s_mem());
	BIO_write(receiptBIO, [receiptData bytes], (int) [receiptData length]);
	PKCS7 *receiptPKCS7 = d2i_PKCS7_bio(receiptBIO, NULL);
	BIO_free_all(receiptBIO);
	if (!receiptPKCS7) {
		return nil;
	}
	if (!PKCS7_type_is_signed(receiptPKCS7)) {
		PKCS7_free(receiptPKCS7);
		return nil;
	}
	
	if (!PKCS7_type_is_data(receiptPKCS7->d.sign->contents)) {
		PKCS7_free(receiptPKCS7);
		return nil;
	}
	
	
	NSData *appleRootData = [[NSData alloc] initWithBase64EncodedString:appleInc options:0];
	BIO *appleRootBIO = BIO_new(BIO_s_mem());
	BIO_write(appleRootBIO, (const void *) [appleRootData bytes], (int) [appleRootData length]);
	X509 *appleRootX509 = d2i_X509_bio(appleRootBIO, NULL);
	
	// Create a certificate store
	X509_STORE *store = X509_STORE_new();
	X509_STORE_add_cert(store, appleRootX509);
	
	X509_free(appleRootX509);
	BIO_free_all(appleRootBIO);
	[appleRootData release];
	
	// Be sure to load the digests before the verification
	OpenSSL_add_all_digests();
	
	
	int result = PKCS7_verify(receiptPKCS7, NULL, store, NULL, NULL, 0);
	if (result != 1) {
		PKCS7_free(receiptPKCS7);
		return nil;
	}
	
	X509_STORE_free(store);
	EVP_cleanup();
	
	
	// Get a pointer to the ASN.1 payload
	ASN1_OCTET_STRING *octets = receiptPKCS7->d.sign->contents->d.data;
	const unsigned char *ptr = octets->data;
	const unsigned char *end = ptr + octets->length;
	const unsigned char *str_ptr;
	
	int type = 0, str_type = 0;
	int xclass = 0, str_xclass = 0;
	long length = 0, str_length = 0;
	
	// Store for the receipt information
	NSString *bundleIdString = nil;
	NSString *bundleVersionString = nil;
	NSData *bundleIdData = nil;
	NSData *hashData = nil;
	NSData *opaqueData = nil;
	NSDate *expirationDate = nil;
	
	// Date formatter to handle RFC 3339 dates in GMT time zone
	NSDateFormatter *formatter = [[[NSDateFormatter alloc] init] autorelease];
	[formatter setLocale:[[[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"] autorelease]];
	[formatter setDateFormat:@"yyyy'-'MM'-'dd'T'HH':'mm':'ss'Z'"];
	[formatter setTimeZone:[NSTimeZone timeZoneForSecondsFromGMT:0]];
	
	// Decode payload (a SET is expected)
	ASN1_get_object(&ptr, &length, &type, &xclass, end - ptr);
	if (type != V_ASN1_SET) {
		PKCS7_free(receiptPKCS7);
		return nil;
	}
	
	while (ptr < end) {
		ASN1_INTEGER *integer;
		
		// Parse the attribute sequence (a SEQUENCE is expected)
		ASN1_get_object(&ptr, &length, &type, &xclass, end - ptr);
		if (type != V_ASN1_SEQUENCE) {
			PKCS7_free(receiptPKCS7);
			return nil;
		}
		
		const unsigned char *seq_end = ptr + length;
		long attr_type = 0;
		long attr_version = 0;
		
		// Parse the attribute type (an INTEGER is expected)
		ASN1_get_object(&ptr, &length, &type, &xclass, end - ptr);
		if (type != V_ASN1_INTEGER) {
			PKCS7_free(receiptPKCS7);
			return nil;
		}
		integer = c2i_ASN1_INTEGER(NULL, &ptr, length);
		attr_type = ASN1_INTEGER_get(integer);
		ASN1_INTEGER_free(integer);
		
		// Parse the attribute version (an INTEGER is expected)
		ASN1_get_object(&ptr, &length, &type, &xclass, end - ptr);
		if (type != V_ASN1_INTEGER) {
			PKCS7_free(receiptPKCS7);
			return nil;
		}
		integer = c2i_ASN1_INTEGER(NULL, &ptr, length);
		attr_version = ASN1_INTEGER_get(integer);
		ASN1_INTEGER_free(integer);
		
		// Check the attribute value (an OCTET STRING is expected)
		ASN1_get_object(&ptr, &length, &type, &xclass, end - ptr);
		if (type != V_ASN1_OCTET_STRING) {
			PKCS7_free(receiptPKCS7);
			return nil;
		}
		
		// see https://developer.apple.com/library/archive/releasenotes/General/ValidateAppStoreReceipt/Chapters/ReceiptFields.html
		switch (attr_type) {
			case 2:
				// Bundle identifier
				str_ptr = ptr;
				ASN1_get_object(&str_ptr, &str_length, &str_type, &str_xclass, seq_end - str_ptr);
				if (str_type == V_ASN1_UTF8STRING) {
					// We store both the decoded string and the raw data for later
					// The raw is data will be used when computing the GUID hash
					bundleIdString = [[[NSString alloc] initWithBytes:str_ptr length:str_length encoding:NSUTF8StringEncoding] autorelease];
					bundleIdData = [[[NSData alloc] initWithBytes:(const void *)ptr length:length] autorelease];
					[ret setValue:bundleIdString forKey:@"bundle_id"];
				}
				break;
			case 3:
				// Bundle version
				str_ptr = ptr;
				ASN1_get_object(&str_ptr, &str_length, &str_type, &str_xclass, seq_end - str_ptr);
				if (str_type == V_ASN1_UTF8STRING) {
					// We store the decoded string for later
					bundleVersionString = [[[NSString alloc] initWithBytes:str_ptr length:str_length encoding:NSUTF8StringEncoding] autorelease];
					[ret setValue:bundleVersionString forKey:@"application_version"];
				}
				break;
			case 4:
				// Opaque value
				opaqueData = [[[NSData alloc] initWithBytes:(const void *)ptr length:length] autorelease];
				break;
			case 5:
				// Computed GUID (SHA-1 Hash)
				hashData = [[[NSData alloc] initWithBytes:(const void *)ptr length:length] autorelease];
				break;
			case 17:
				// In-App Purchase Receipt
				str_ptr = ptr;
				ASN1_get_object(&str_ptr, &str_length, &str_type, &str_xclass, seq_end - str_ptr);
				if (str_type == V_ASN1_SET) {
					const unsigned char *ptr = str_ptr;
					const unsigned char *end = ptr+str_length;
					long length = 0, str_length = 0;
					NSMutableDictionary *iap = [[NSMutableDictionary alloc] init];
					
					while (ptr < end) {
						ASN1_INTEGER *integer;
						
						// Parse the attribute sequence (a SEQUENCE is expected)
						ASN1_get_object(&ptr, &length, &type, &xclass, end - ptr);
						if (type != V_ASN1_SEQUENCE) {
							PKCS7_free(receiptPKCS7);
							return nil;
						}
						
						const unsigned char *seq_end = ptr + length;
						long attr_type = 0;
						long attr_version = 0;
						
						// Parse the attribute type (an INTEGER is expected)
						ASN1_get_object(&ptr, &length, &type, &xclass, end - ptr);
						if (type != V_ASN1_INTEGER) {
							PKCS7_free(receiptPKCS7);
							return nil;
						}
						integer = c2i_ASN1_INTEGER(NULL, &ptr, length);
						attr_type = ASN1_INTEGER_get(integer);
						ASN1_INTEGER_free(integer);
						
						// Parse the attribute version (an INTEGER is expected)
						ASN1_get_object(&ptr, &length, &type, &xclass, end - ptr);
						if (type != V_ASN1_INTEGER) {
							PKCS7_free(receiptPKCS7);
							return nil;
						}
						integer = c2i_ASN1_INTEGER(NULL, &ptr, length);
						attr_version = ASN1_INTEGER_get(integer);
						ASN1_INTEGER_free(integer);
						
						// Check the attribute value (an OCTET STRING is expected)
						ASN1_get_object(&ptr, &length, &type, &xclass, end - ptr);
						if (type != V_ASN1_OCTET_STRING) {
							PKCS7_free(receiptPKCS7);
							return nil;
						}
						
						// see https://developer.apple.com/library/archive/releasenotes/General/ValidateAppStoreReceipt/Chapters/ReceiptFields.html
						switch (attr_type) {
							case 1701:
								// Quantity
								str_ptr = ptr;
								ASN1_get_object(&str_ptr, &str_length, &str_type, &str_xclass, seq_end - str_ptr);
								if (str_type == V_ASN1_INTEGER) {
									integer = c2i_ASN1_INTEGER(NULL, &str_ptr, str_length);
									long quantity = ASN1_INTEGER_get(integer);
									ASN1_INTEGER_free(integer);
									[iap setObject:[NSNumber numberWithLong:quantity] forKey:@"quantity"];
								}
								break;
							case 1702:
								// Product Identifier
								str_ptr = ptr;
								ASN1_get_object(&str_ptr, &str_length, &str_type, &str_xclass, seq_end - str_ptr);
								if (str_type == V_ASN1_UTF8STRING) {
									// We store the decoded string for later
									NSString *productIdentifier = [[NSString alloc] initWithBytes:str_ptr length:str_length encoding:NSUTF8StringEncoding];
									[iap setObject:productIdentifier forKey:@"product_id"];
									[productIdentifier release];
								}
								break;
							case 1703:
								// Transaction Identifier
								str_ptr = ptr;
								ASN1_get_object(&str_ptr, &str_length, &str_type, &str_xclass, seq_end - str_ptr);
								if (str_type == V_ASN1_UTF8STRING) {
									// We store the decoded string for later
									NSString *transactionId = [[NSString alloc] initWithBytes:str_ptr length:str_length encoding:NSUTF8StringEncoding];
									[iap setObject:transactionId forKey:@"transaction_id"];
									[transactionId release];
								}
								break;
							case 1705:
								// Original Transaction Identifier
								str_ptr = ptr;
								ASN1_get_object(&str_ptr, &str_length, &str_type, &str_xclass, seq_end - str_ptr);
								if (str_type == V_ASN1_UTF8STRING) {
									// We store the decoded string for later
									NSString *origTransactionId = [[NSString alloc] initWithBytes:str_ptr length:str_length encoding:NSUTF8StringEncoding];
									[iap setObject:origTransactionId forKey:@"original_transaction_id"];
									[origTransactionId release];
								}
								break;
							case 1704:
								// Purchase Date
								str_ptr = ptr;
								ASN1_get_object(&str_ptr, &str_length, &str_type, &str_xclass, seq_end - str_ptr);
								if (str_type == V_ASN1_IA5STRING) {
									// The date is stored as a string that needs to be parsed
									NSString *dateString = [[NSString alloc] initWithBytes:str_ptr length:str_length encoding:NSASCIIStringEncoding];
									NSDate* purchaseDate = [formatter dateFromString:dateString];
									[iap setObject:[NSNumber numberWithLong:[purchaseDate timeIntervalSince1970]] forKey:@"purchase_date"];
									[dateString release];
								}
								break;
							case 1706:
								// Original Purchase Date
								str_ptr = ptr;
								ASN1_get_object(&str_ptr, &str_length, &str_type, &str_xclass, seq_end - str_ptr);
								if (str_type == V_ASN1_IA5STRING) {
									// The date is stored as a string that needs to be parsed
									NSString *dateString = [[NSString alloc] initWithBytes:str_ptr length:str_length encoding:NSASCIIStringEncoding];
									NSDate* origPurchaseDate = [formatter dateFromString:dateString];
									[iap setObject:[NSNumber numberWithLong:[origPurchaseDate timeIntervalSince1970]] forKey:@"original_purchase_date"];
									[dateString release];
									
								}
								break;
							case 1708:
								// Subscription Expiration Date
								str_ptr = ptr;
								ASN1_get_object(&str_ptr, &str_length, &str_type, &str_xclass, seq_end - str_ptr);
								if (str_type == V_ASN1_IA5STRING) {
									// The date is stored as a string that needs to be parsed
									NSString *dateString = [[NSString alloc] initWithBytes:str_ptr length:str_length encoding:NSASCIIStringEncoding];
									NSDate* expiresDate = [formatter dateFromString:dateString];
									[iap setObject:[NSNumber numberWithLong:[expiresDate timeIntervalSince1970]] forKey:@"expires_date"];
									[dateString release];
								}
								break;
							case 1719:
								// Subscription Introductory Price Period
								str_ptr = ptr;
								ASN1_get_object(&str_ptr, &str_length, &str_type, &str_xclass, seq_end - str_ptr);
								if (str_type == V_ASN1_INTEGER) {
									integer = c2i_ASN1_INTEGER(NULL, &str_ptr, str_length);
									long intro = ASN1_INTEGER_get(integer);
									ASN1_INTEGER_free(integer);
									[iap setObject:[NSNumber numberWithLong:intro] forKey:@"is_in_intro_offer_period"];
								}
								break;
							case 1712:
								// Cancellation Date
								str_ptr = ptr;
								ASN1_get_object(&str_ptr, &str_length, &str_type, &str_xclass, seq_end - str_ptr);
								if (str_type == V_ASN1_IA5STRING) {
									// The date is stored as a string that needs to be parsed
									NSString *dateString = [[NSString alloc] initWithBytes:str_ptr length:str_length encoding:NSASCIIStringEncoding];
									NSDate* cancelDate = [formatter dateFromString:dateString];
									[iap setObject:[NSNumber numberWithLong:[cancelDate timeIntervalSince1970]] forKey:@"cancellation_date"];
									[dateString release];
								}
								break;
							case 1711:
								// Web Order Line Item ID
								str_ptr = ptr;
								ASN1_get_object(&str_ptr, &str_length, &str_type, &str_xclass, seq_end - str_ptr);
								if (str_type == V_ASN1_INTEGER) {
									integer = c2i_ASN1_INTEGER(NULL, &str_ptr, str_length);
									long webOrder = ASN1_INTEGER_get(integer);
									ASN1_INTEGER_free(integer);
									[iap setObject:[[NSNumber numberWithLong:webOrder] stringValue] forKey:@"web_order_line_item_id"];
									
								}
								break;
							default:
								break;
						}
						// Move past the value
						ptr += length;
					}
					
					[iaps addObject:iap];
					[iap release];
				}
				break;
			case 19:
				// Original Application Version
				str_ptr = ptr;
				ASN1_get_object(&str_ptr, &str_length, &str_type, &str_xclass, seq_end - str_ptr);
				if (str_type == V_ASN1_UTF8STRING) {
					NSString * str = [[NSString alloc] initWithBytes:str_ptr length:str_length encoding:NSUTF8StringEncoding];
					[ret setValue:str forKey:@"original_application_version"];
					[str release];
				}
				break;
			case 12:
				// Receipt Creation Date
				str_ptr = ptr;
				ASN1_get_object(&str_ptr, &str_length, &str_type, &str_xclass, seq_end - str_ptr);
				if (str_type == V_ASN1_IA5STRING) {
					// The date is stored as a string that needs to be parsed
					NSString *dateString = [[NSString alloc] initWithBytes:str_ptr length:str_length encoding:NSASCIIStringEncoding];
					NSDate* creationDate = [formatter dateFromString:dateString];
					[ret setValue:[NSNumber numberWithLong:[creationDate timeIntervalSince1970]] forKey:@"receipt_creation_date"];
					[dateString release];
				}
				break;
			case 21:
				// Expiration date
				str_ptr = ptr;
				ASN1_get_object(&str_ptr, &str_length, &str_type, &str_xclass, seq_end - str_ptr);
				if (str_type == V_ASN1_IA5STRING) {
					// The date is stored as a string that needs to be parsed
					NSString *dateString = [[NSString alloc] initWithBytes:str_ptr length:str_length encoding:NSASCIIStringEncoding];
					expirationDate = [formatter dateFromString:dateString];
					[ret setValue:[NSNumber numberWithLong:[expirationDate timeIntervalSince1970]] forKey:@"receipt_creation_date"];
					[dateString release];
				}
				break;
			default:
				break;
		}
		// Move past the value
		ptr += length;
	}
	
	PKCS7_free(receiptPKCS7);
	
	// Be sure that all information is present
	if (bundleIdString == nil ||
		bundleVersionString == nil ||
		opaqueData == nil ||
		hashData == nil) {
		return nil;
	}
	
#if TARGET_OS_IPHONE
	UIDevice *device = [UIDevice currentDevice];
	NSUUID *identifier = [device identifierForVendor];
	uuid_t uuid;
	[identifier getUUIDBytes:uuid];
	NSData *guidData = [NSData dataWithBytes:(const void *)uuid length:16];
#elif defined(IAP_TESTBED)
	NSUUID *identifier = [[[NSUUID alloc] initWithUUIDString:@"96303374-EE06-4A3B-88AE-D69C9DB5E255"] autorelease];
	uuid_t uuid;
	[identifier getUUIDBytes:uuid];
	NSData *guidData = [NSData dataWithBytes:(const void *)uuid length:16];
#elif TARGET_OS_OSX
	// Open a MACH port
	mach_port_t master_port;
	kern_return_t kernResult = IOMasterPort(MACH_PORT_NULL, &master_port);
	if (kernResult != KERN_SUCCESS) {
		return nil;
	}
	
	// Create a search for primary interface
	CFMutableDictionaryRef matching_dict = IOBSDNameMatching(master_port, 0, "en0");
	if (!matching_dict) {
		return nil;
	}
	
	// Perform the search
	io_iterator_t iterator;
	kernResult = IOServiceGetMatchingServices(master_port, matching_dict, &iterator);
	if (kernResult != KERN_SUCCESS) {
		return nil;
	}
	
	// Iterate over the result
	CFDataRef guid_cf_data = nil;
	io_object_t service, parent_service;
	while((service = IOIteratorNext(iterator)) != 0) {
		kernResult = IORegistryEntryGetParentEntry(service, kIOServicePlane, &parent_service);
		if (kernResult == KERN_SUCCESS) {
			// Store the result
			if (guid_cf_data) CFRelease(guid_cf_data);
			guid_cf_data = (CFDataRef) IORegistryEntryCreateCFProperty(parent_service, CFSTR("IOMACAddress"), NULL, 0);
			IOObjectRelease(parent_service);
		}
		IOObjectRelease(service);
		if (guid_cf_data) {
			break;
		}
	}
	IOObjectRelease(iterator);
	
	NSData *guidData = [NSData dataWithData:(__bridge NSData *) guid_cf_data];
	if (guid_cf_data) CFRelease(guid_cf_data);
	
#endif
	
	unsigned char hash[20];
	
	// Create a hashing context for computation
	SHA_CTX ctx;
	SHA1_Init(&ctx);
	SHA1_Update(&ctx, [guidData bytes], (size_t) [guidData length]);
	SHA1_Update(&ctx, [opaqueData bytes], (size_t) [opaqueData length]);
	SHA1_Update(&ctx, [bundleIdData bytes], (size_t) [bundleIdData length]);
	SHA1_Final(hash, &ctx);
	
	// Do the comparison
	NSData *computedHashData = [NSData dataWithBytes:hash length:20];
	if (![computedHashData isEqualToData:hashData]) {
		return nil;
	}
	
	return ret;
}
@end
