//
//  Copyright (c) 2018 Coronalabs Inc. All rights reserved.
//

#include <CoronaLua.h>
#include <CoronaEvent.h>
#include <Foundation/Foundation.h>
#include <StoreKit/StoreKit.h>
#include <CoronaLuaObjCHelper.h>


CORONA_EXPORT int luaopen_plugin_apple_iap( lua_State *L );
void pushProductTable(lua_State *L, SKProduct *product);

static const char* kAppleIAP_ReceipEvent = "receiptRequest";
static const char* kAppleIAP_TransactionEvent = "storeTransaction";
static const char* kAppleIAP_AppStorePurchaseEvent = "appStorePurchase";
static const char* kAppleIAP_LoadEvent = "productList";

static const char* kAppleIAP_TransactionMetatdata = "kAppleIAP-2444635A037B";
static const char* kAppleIAP_PaymentMetatdata = "kApplePayment-2444635A037B";

@interface AppleIAPTransactionObserver : NSObject <SKPaymentTransactionObserver>

+(AppleIAPTransactionObserver*)toobserver:(lua_State*)L;


- (instancetype)initWithState:(lua_State*)L;

@property (retain, nonatomic) NSMutableDictionary<NSString*, SKProduct*>* loadedProducts;
@property (assign, nonatomic) CoronaLuaRef transactionListener;
@property (assign, nonatomic) CoronaLuaRef deferredPurchasesListener;
@property (assign, nonatomic) lua_State* luaState;

@end

@implementation AppleIAPTransactionObserver

@synthesize loadedProducts;

- (instancetype)initWithState:(lua_State*)L
{
	self = [super init];
	if (self) {
		self.luaState = L;
		self.loadedProducts = [[[NSMutableDictionary alloc] init] autorelease];
		self.transactionListener = 0;
        self.deferredPurchasesListener = 0;
	}
	return self;
}

+(AppleIAPTransactionObserver *)toobserver:(lua_State *)L {
	return (AppleIAPTransactionObserver*) CoronaLuaToUserdata( L, lua_upvalueindex( 1 ) );
}

-(void)start {
	[[SKPaymentQueue defaultQueue] removeTransactionObserver:self];
	[[SKPaymentQueue defaultQueue] addTransactionObserver:self];
}

-(void)stop {
	[[SKPaymentQueue defaultQueue] removeTransactionObserver:self];
}


- (void)paymentQueue:(nonnull SKPaymentQueue *)queue updatedTransactions:(nonnull NSArray<SKPaymentTransaction *> *)transactions {
	for (SKPaymentTransaction* transaction in transactions)
	{
		switch (transaction.transactionState)
		{
			case SKPaymentTransactionStatePurchased:
			case SKPaymentTransactionStateFailed:
			case SKPaymentTransactionStateRestored:
				dispatch_async(dispatch_get_main_queue(), ^{
					lua_State *L = self.luaState;
					
					CoronaLuaNewEvent(L, kAppleIAP_TransactionEvent);
					
					CoronaLuaPushUserdata(L, [transaction retain], kAppleIAP_TransactionMetatdata);
					lua_setfield(L, -2, "transaction");
					
					CoronaLuaDispatchEvent(L, self.transactionListener, 0);
				});
				break;
			case SKPaymentTransactionStatePurchasing:
			case SKPaymentTransactionStateDeferred:
				break;
		}
	}
}

-(BOOL)paymentQueue:(SKPaymentQueue *)queue shouldAddStorePayment:(SKPayment *)payment forProduct:(SKProduct *)product {
    if(self.deferredPurchasesListener) {
        lua_State *L = self.luaState;
        
        CoronaLuaNewEvent(L, kAppleIAP_AppStorePurchaseEvent);

        pushProductTable(L, product);
        lua_setfield(L, -2, "product");
        
        CoronaLuaPushUserdata(L, [payment retain], kAppleIAP_PaymentMetatdata);
        lua_setfield(L, -2, "payment");
        
        CoronaLuaDispatchEvent(L, self.deferredPurchasesListener, 0);
        return  NO;
    }
	return YES;
}


-(void)paymentQueue:(SKPaymentQueue *)queue removedTransactions:(NSArray<SKPaymentTransaction *> *)transactions {
	
}

-(void)paymentQueue:(SKPaymentQueue *)queue restoreCompletedTransactionsFailedWithError:(NSError *)error {
	dispatch_async(dispatch_get_main_queue(), ^{
		lua_State *L = self.luaState;
		
		CoronaLuaNewEvent(L, kAppleIAP_TransactionEvent);
	
		lua_createtable(L, 0, 5);

		lua_pushliteral(L, "restore");
		lua_setfield(L, -2, "type");

		lua_pushliteral(L, "failed");
		lua_setfield(L, -2, "state");

		lua_pushboolean(L, true);
		lua_setfield(L, -2, CoronaEventIsErrorKey());
		
		lua_pushliteral(L, "restoreFailed");
		lua_setfield(L, -2, "errorType");

		lua_pushstring(L, [[error localizedDescription] UTF8String]);
		lua_setfield(L, -2, "errorString");
		
		lua_setfield(L, -2, "transaction");
		
		CoronaLuaDispatchEvent(L, self.transactionListener, 0);
	});
}

-(void)paymentQueueRestoreCompletedTransactionsFinished:(SKPaymentQueue *)queue {
	dispatch_async(dispatch_get_main_queue(), ^{
		lua_State *L = self.luaState;
		
		CoronaLuaNewEvent(L, kAppleIAP_TransactionEvent);
		
		lua_createtable(L, 0, 3);
		
		lua_pushliteral(L, "restore");
		lua_setfield(L, -2, "type");
		
		lua_pushliteral(L, "restoreCompleted");
		lua_setfield(L, -2, "state");
		
		lua_pushboolean(L, false);
		lua_setfield(L, -2, CoronaEventIsErrorKey());
		
		lua_setfield(L, -2, "transaction");
		
		CoronaLuaDispatchEvent(L, self.transactionListener, 0);
	});
}

@end

static id appleIAP_decryptReceipt(NSData *data) {
	id ret = nil;
	Class class = NSClassFromString(@"AppleIAP_CryptoHelper");
	if(class) {
		ret = [class performSelector:NSSelectorFromString(@"decryptReceipt:") withObject:data];
	}
	return ret;
}

static int appleIAP_decryptedReceipt( lua_State *L ) {
	NSURL *url = [[NSBundle mainBundle] appStoreReceiptURL];
	if([url checkResourceIsReachableAndReturnError:nil]) {
		NSData *data = [NSData dataWithContentsOfURL:url];
		id result = appleIAP_decryptReceipt(data);
		if(result) {
			if(CoronaLuaPushValue(L, result) == 0) {
				lua_pushnil(L);
			}
		} else {
			lua_pushnil(L);
		}
	}
	else
	{
		lua_pushnil(L);
	}
	return 1;
}

static int appleIAP_base64ReceiptData( lua_State *L ) {
    NSURL *url = [[NSBundle mainBundle] appStoreReceiptURL];
    if([url checkResourceIsReachableAndReturnError:nil]) {
        NSData *data = [NSData dataWithContentsOfURL:url];
        lua_pushstring(L, [[data base64EncodedStringWithOptions:0] UTF8String]);
    }
    else
    {
        lua_pushnil(L);
    }
    return 1;
}

static int appleIAP_rawReceiptData( lua_State *L ) {
    NSURL *url = [[NSBundle mainBundle] appStoreReceiptURL];
    if([url checkResourceIsReachableAndReturnError:nil]) {
        NSData *data = [NSData dataWithContentsOfURL:url];
        lua_pushlstring(L, (const char *)data.bytes, data.length);
    }
    else
    {
        lua_pushnil(L);
    }
    return 1;
}


static int appleIAP_receiptAvailable( lua_State *L )
{
    NSURL *url = [[NSBundle mainBundle] appStoreReceiptURL];
    lua_pushboolean(L, [url checkResourceIsReachableAndReturnError:nil]);
    return 1;
}

@interface StoreReceiptDelegate : NSObject <SKRequestDelegate> {
    lua_State *L;
    CoronaLuaRef listener;
}
@end

@implementation StoreReceiptDelegate

- (instancetype)initWithLuaState:(lua_State*)L {
    self = [super init];
    if (self) {
        self->L = L;
        self->listener = NULL;
        if(CoronaLuaIsListener(L, 1, kAppleIAP_ReceipEvent)) {
            self->listener = CoronaLuaNewRef(L, 1);
        }
        
        SKRequest *request = [[SKReceiptRefreshRequest alloc] init];
        request.delegate = self;
        [request start];
    }
    return self;
}

-(void)doneRequest:(SKRequest *)request withError:(NSError*)error {
    if(self->listener != NULL) {
        CoronaLuaNewEvent(L, kAppleIAP_ReceipEvent);
        
        lua_pushboolean(L, error!=nil);
        lua_setfield(L, -2, CoronaEventIsErrorKey());
        
        if(error) {
            lua_pushinteger(L, error.code);
            lua_setfield(L, -2, CoronaEventErrorCodeKey());
            
            lua_pushstring(L, [[error localizedDescription] UTF8String]);
            lua_setfield(L, -2, "errorMessage");
        }
        
        CoronaLuaDispatchEvent(L, self->listener, 0);
        CoronaLuaDeleteRef(L, self->listener);
    }
    
    request.delegate = nil;
    [request autorelease];
    [self autorelease];

}

-(void)requestDidFinish:(SKRequest *)request {
    [self doneRequest:request withError:nil];
}

-(void)request:(SKRequest *)request didFailWithError:(NSError *)error {
    [self doneRequest:request withError:error];
}

@end


static int appleIAP_requestReceipt( lua_State *L )
{
    [[StoreReceiptDelegate alloc] initWithLuaState:L];
    return 0;
}


static int cleanupIAPs( lua_State *L )
{
	AppleIAPTransactionObserver *observer = (AppleIAPTransactionObserver*)CoronaLuaToUserdata( L, 1 );
	[observer stop];
	CoronaLuaDeleteRef(L, observer.transactionListener);
    CoronaLuaDeleteRef(L, observer.deferredPurchasesListener);
	return 0;
}

static int appleIAP_StoreValues( lua_State *L )
{
	int nRet = 0;
	const char *key = luaL_checkstring( L, 2 );
	
	if ( 0 == strcmp( "isActive", key ) )
	{
		lua_pushboolean(L, 1);
		nRet = 1;
	}
	else if ( 0 == strcmp( "canMakePurchases", key ) )
	{
		lua_pushboolean(L, [SKPaymentQueue canMakePayments]);
		nRet = 1;
	}
	else if ( 0 == strcmp( "canLoadProducts", key ) )
	{
		lua_pushboolean(L, 1);
		nRet = 1;
	}
	else if ( 0 == strcmp( "target", key ) )
	{
		lua_pushliteral(L, "apple");
		nRet = 1;
	}
	
	return nRet;
}

static int appleIAP_init(lua_State *L)
{
	AppleIAPTransactionObserver *observer = [AppleIAPTransactionObserver toobserver:L];
	int nArg = 1;
	
	if(lua_isstring(L, nArg)) {
		nArg++;
	}
	
	if(observer.transactionListener) {
		CoronaLuaDeleteRef(L, observer.transactionListener);
		observer.transactionListener = NULL;
	}
	
	[[SKPaymentQueue defaultQueue] removeTransactionObserver:observer];
	if(CoronaLuaIsListener(L, nArg, kAppleIAP_TransactionEvent)) {
		CoronaLuaRef listener = CoronaLuaNewRef(L, nArg);
		observer.transactionListener = listener;
		dispatch_async(dispatch_get_main_queue(), ^{
			[[SKPaymentQueue defaultQueue] addTransactionObserver:observer];
		});
		
		dispatch_async(dispatch_get_main_queue(), ^{
			CoronaLuaNewEvent(L, "init");
			
			lua_pushboolean(L, NO);
			lua_setfield(L, -2, CoronaEventIsErrorKey());
						
			CoronaLuaDispatchEvent(L, listener, 0);
		});
		
	}
	
    return 0;
}

@interface AppleIAPProductRequestDelegate : NSObject<SKProductsRequestDelegate>

@property (retain, nonatomic) AppleIAPTransactionObserver* observer;
@property (assign, nonatomic) CoronaLuaRef listener;

@end

@implementation AppleIAPProductRequestDelegate

- (instancetype)initWithobserver:(AppleIAPTransactionObserver*)observer andListener:(CoronaLuaRef)listener
{
	self = [super init];
	if (self) {
		self.observer = observer;
		self.listener = listener;
	}
	return self;
}

void pushProductTable(lua_State *L, SKProduct *product) {
	lua_createtable(L, 0, 6);

	lua_pushstring(L, [product.productIdentifier UTF8String]);
	lua_setfield(L, -2, "productIdentifier");
	
	lua_pushstring(L, [product.localizedTitle UTF8String]);
	lua_setfield(L, -2, "title");
	
	lua_pushstring(L, [product.localizedDescription UTF8String]);
	lua_setfield(L, -2, "description");
	
	lua_pushnumber(L, [product.price doubleValue]);
	lua_setfield(L, -2, "price");
	
	if (@available(iOS 11.2, macOS 10.13.2, tvOS 11.2, *)){
		if(product.subscriptionPeriod) {
			lua_pushinteger(L, [product.subscriptionPeriod numberOfUnits] );
			lua_setfield(L, -2, "subscriptionPeriodNumberOfUnits");
			
			switch ([product.subscriptionPeriod unit]) {
				case SKProductPeriodUnitDay:
					lua_pushliteral(L, "day");
					break;
				case SKProductPeriodUnitWeek:
					lua_pushliteral(L, "week");
					break;
				case SKProductPeriodUnitMonth:
					lua_pushliteral(L, "month");
					break;
				case SKProductPeriodUnitYear:
					lua_pushliteral(L, "year");
					break;
			}
			lua_setfield(L, -2, "subscriptionPeriodUnit");
		}
		
		if(product.introductoryPrice) {
			lua_newtable(L);
			{
				lua_pushnumber(L, [product.introductoryPrice.price doubleValue]);
				lua_setfield(L, -2, "price");
				
				NSNumberFormatter *numberFormatter = [[NSNumberFormatter alloc] init];
				[numberFormatter setFormatterBehavior:NSNumberFormatterBehavior10_4];
				[numberFormatter setNumberStyle:NSNumberFormatterCurrencyStyle];
				[numberFormatter setLocale:product.introductoryPrice.priceLocale];
				lua_pushstring(L, [[numberFormatter stringFromNumber:product.introductoryPrice.price] UTF8String]);
				lua_setfield(L, -2, "localizedPrice");
				[numberFormatter release];
				
				lua_pushstring(L, [[[product.introductoryPrice priceLocale] objectForKey:NSLocaleIdentifier] UTF8String]);
				lua_setfield(L, -2, "priceLocale");
				
				lua_pushstring(L, [[[product.introductoryPrice priceLocale] objectForKey:NSLocaleCurrencyCode] UTF8String]);
				lua_setfield(L, -2, "priceCurrencyCode");
				
				lua_pushinteger(L, [product.introductoryPrice.subscriptionPeriod numberOfUnits] );
				lua_setfield(L, -2, "subscriptionPeriodNumberOfUnits");
				
				switch ([product.introductoryPrice.subscriptionPeriod unit]) {
					case SKProductPeriodUnitDay:
						lua_pushliteral(L, "day");
						break;
					case SKProductPeriodUnitWeek:
						lua_pushliteral(L, "week");
						break;
					case SKProductPeriodUnitMonth:
						lua_pushliteral(L, "month");
						break;
					case SKProductPeriodUnitYear:
						lua_pushliteral(L, "year");
						break;
				}
				lua_setfield(L, -2, "subscriptionPeriodUnit");
				
				lua_pushinteger(L, [product.introductoryPrice numberOfPeriods] );
				lua_setfield(L, -2, "numberOfPeriods");
				
				switch (product.introductoryPrice.paymentMode) {
					case SKProductDiscountPaymentModePayAsYouGo:
						lua_pushliteral(L, "PayAsYouGo");
						break;
					case SKProductDiscountPaymentModePayUpFront:
						lua_pushliteral(L, "PayUpFront");
						break;
					case SKProductDiscountPaymentModeFreeTrial:
						lua_pushliteral(L, "FreeTrial");
						break;
				}
				lua_setfield(L, -2, "paymentMode");
			}
			lua_setfield(L, -2, "introductoryPrice");
		}
	}
	
	NSNumberFormatter *numberFormatter = [[NSNumberFormatter alloc] init];
	[numberFormatter setFormatterBehavior:NSNumberFormatterBehavior10_4];
	[numberFormatter setNumberStyle:NSNumberFormatterCurrencyStyle];
	[numberFormatter setLocale:product.priceLocale];
	lua_pushstring(L, [[numberFormatter stringFromNumber:product.price] UTF8String]);
	lua_setfield(L, -2, "localizedPrice");
	[numberFormatter release];
	
	lua_pushstring(L, [[[product priceLocale] objectForKey:NSLocaleIdentifier] UTF8String]);
	lua_setfield(L, -2, "priceLocale");
	
	lua_pushstring(L, [[[product priceLocale] objectForKey:NSLocaleCurrencyCode] UTF8String]);
	lua_setfield(L, -2, "priceCurrencyCode");
}

- (void)productsRequest:(nonnull SKProductsRequest *)request didReceiveResponse:(nonnull SKProductsResponse *)response {
	dispatch_async(dispatch_get_main_queue(), ^{
		lua_State *L = self.observer.luaState;

		CoronaLuaNewEvent(L, kAppleIAP_LoadEvent);
		
		lua_createtable(L, (int)response.products.count, 0);
		int i=1;
		for (SKProduct *product in response.products) {
			
			[self.observer.loadedProducts setObject:product forKey:product.productIdentifier];
						
			pushProductTable(L, product);

			lua_rawseti(L, -2, i++);
		}
		lua_setfield(L, -2, "products");

		lua_createtable(L, (int)response.invalidProductIdentifiers.count, 0);
		i=1;
		for (NSString *invalidProduct in response.invalidProductIdentifiers) {
			lua_pushstring(L, [invalidProduct UTF8String]);
			lua_rawseti(L, -2, i++);
		}
		lua_setfield(L, -2, "invalidProducts");
		
		CoronaLuaDispatchEvent(L, self.listener, 0);
		
		[request.delegate autorelease];
		[request autorelease];
	});
}

- (void)request:(SKRequest *)request didFailWithError:(NSError *)error {
	dispatch_async(dispatch_get_main_queue(), ^{
		lua_State *L = self.observer.luaState;
		CoronaLuaNewEvent(L, kAppleIAP_LoadEvent);
		
		lua_pushboolean(L, true);
		lua_setfield(L, -2, CoronaEventIsErrorKey());
		
		CoronaLuaDispatchEvent(L, self.listener, 0);
		
		[request.delegate autorelease];
		[request autorelease];
	});
}

@end

static int appleIAP_loadProducts(lua_State *L)
{
	AppleIAPTransactionObserver *observer = [AppleIAPTransactionObserver toobserver:L];
	
	if(!lua_istable(L, 1) || !CoronaLuaIsListener(L, 2, kAppleIAP_LoadEvent)) {
		NSLog(@"Apple IAP: ERROR check parameters! Expect table and listener, got '%s' and '%s'", luaL_typename(L, 1), luaL_typename(L, 2));
		return 0;
	}
	CoronaLuaRef listener = CoronaLuaNewRef(L, 2);
	
	int length = (int)lua_objlen( L, 1 );
	NSMutableSet<NSString*> *productsSet = [[NSMutableSet alloc] initWithCapacity:length];
	for ( int i = 0; i < length; i++ )
	{
		lua_rawgeti( L, 1, i + 1 );
		if(lua_type(L, -1) == LUA_TSTRING) {
			NSString* s = [[NSString alloc] initWithUTF8String:lua_tostring( L, -1 )];
			[productsSet addObject:s];
			[s release];
		}
		lua_pop( L, 1 );
	}
	
	SKProductsRequest* request = [[SKProductsRequest alloc] initWithProductIdentifiers:productsSet];
	request.delegate = [[AppleIAPProductRequestDelegate alloc] initWithobserver:observer andListener:listener];
	[request start];
    return 0;
}

static int appleIAP_purchase(lua_State *L)
{
	AppleIAPTransactionObserver *observer = [AppleIAPTransactionObserver toobserver:L];
	
	NSMutableArray* productIdentifiers = [[NSMutableArray alloc] init];
	if ( lua_istable( L, 1 )	)
	{
		lua_getfield( L, -1, "productIdentifier");
		if(lua_type(L, -1) == LUA_TSTRING) {
			NSString* s = [[NSString alloc] initWithUTF8String:lua_tostring( L, -1 )];
			[productIdentifiers addObject:s];
			[s release];
		}
		lua_pop( L, 1 );

		int length = (int)lua_objlen( L, 1 );
		for ( int i = 0; i < length; i++ ) {
			lua_rawgeti( L, 1, i + 1 );
			
			if( lua_istable( L, -1) ) {
				lua_getfield( L, -1, "productIdentifier");
				if(lua_type(L, -1) == LUA_TSTRING) {
					NSString* s = [[NSString alloc] initWithUTF8String:lua_tostring( L, -1 )];
					[productIdentifiers addObject:s];
					[s release];
				}
				lua_pop( L, 1 );
			} else if( lua_isstring( L, -1) ) {
				NSString* s = [[NSString alloc] initWithUTF8String:lua_tostring( L, -1 )];
				[productIdentifiers addObject:s];
				[s release];
			}
			
			lua_pop( L, 1 );
		}
	}
	else if ( lua_type( L, 1 ) == LUA_TSTRING )
	{
		NSString* s = [[NSString alloc] initWithUTF8String:lua_tostring( L, -1 )];
		[productIdentifiers addObject:s];
		[s release];
	}
	
	NSCountedSet* counted_set = [[[NSCountedSet alloc] initWithArray:productIdentifiers] autorelease];
	for( NSString* productId in counted_set )
	{
		SKMutablePayment* payment = nil;
		SKProduct *product = [observer.loadedProducts objectForKey:productId];
		if(product)
		{
			payment = [SKMutablePayment paymentWithProduct:product];
		}
		else
		{
#if TARGET_OS_IOS
			if([SKMutablePayment respondsToSelector:@selector(paymentWithProductIdentifier:)])
			{
				payment = [SKMutablePayment performSelector:@selector(paymentWithProductIdentifier:) withObject:productId];
			}
#else
			payment = nil;
#endif
		}
		if(payment)
		{
			payment.quantity = [counted_set countForObject:productId];
			[[SKPaymentQueue defaultQueue] addPayment:payment];
		}
	}
	
	[productIdentifiers release];
	return 0;
}

static int appleIAP_deferPurchases(lua_State *L)
{
    AppleIAPTransactionObserver *observer = [AppleIAPTransactionObserver toobserver:L];
    int nArg = 1;
    
    if(observer.deferredPurchasesListener) {
        CoronaLuaDeleteRef(L, observer.deferredPurchasesListener);
        observer.deferredPurchasesListener = NULL;
    }
    
    if(CoronaLuaIsListener(L, nArg, kAppleIAP_AppStorePurchaseEvent)) {
        CoronaLuaRef listener = CoronaLuaNewRef(L, nArg);
        observer.deferredPurchasesListener = listener;
    }
    
    return 0;
}

static int appleIAP_continueDeferred(lua_State *L)
{
	lua_getmetatable(L, 1);
	lua_getfield(L, LUA_REGISTRYINDEX, kAppleIAP_PaymentMetatdata);
	bool isPayment = lua_rawequal(L, -1, -2);
	lua_pop(L, 2);
	SKPayment* payment = NULL;
	if(isPayment) {
		payment = (SKPayment*)CoronaLuaToUserdata(L, 1);
	}
	if(payment) {
		[[SKPaymentQueue defaultQueue] addPayment:payment];
	}
	lua_pushboolean(L, payment!=NULL);
    return 1;
}

static int appleIAP_finishTransaction(lua_State *L)
{
	lua_getmetatable(L, 1);
	lua_getfield(L, LUA_REGISTRYINDEX, kAppleIAP_TransactionMetatdata);
	bool isTransaction = lua_rawequal(L, -1, -2);
	lua_pop(L, 2);
	SKPaymentTransaction* transaction = NULL;
	if(isTransaction) {
		transaction = (SKPaymentTransaction*)CoronaLuaToUserdata(L, 1);
	}
	if(transaction) {
		[[SKPaymentQueue defaultQueue] finishTransaction:transaction];
	}
    return 0;
}

static int appleIAP_restoreCompletedTransactions(lua_State *L)
{
	[[SKPaymentQueue defaultQueue] restoreCompletedTransactions];
	return 0;
}

static int appleIAP_transactionIndex(lua_State *L) {
	SKPaymentTransaction *transaction = (SKPaymentTransaction*)CoronaLuaCheckUserdata( L, 1, kAppleIAP_TransactionMetatdata );
	if(!transaction)
		return 0;
	
	const char *key = luaL_checkstring( L, 2 );
	int nRet = 1;
	
	if (0 == strcmp( "type", key )) {
		lua_pushliteral(L, "transaction");
	} else if ( 0 == strcmp( "state", key ) ) {
		switch( transaction.transactionState )
		{
			case SKPaymentTransactionStatePurchased:
				lua_pushliteral(L, "purchased");
				break;
			case SKPaymentTransactionStateFailed:
				if ( transaction.error && ( SKErrorPaymentCancelled == transaction.error.code ) ) {
					lua_pushliteral(L, "cancelled");
				} else {
					lua_pushliteral(L, "failed");
				}
				break;
			case SKPaymentTransactionStateRestored:
				lua_pushliteral(L, "restored");
				break;
			case SKPaymentTransactionStatePurchasing:
				lua_pushliteral(L, "purchasing");
				break;
			case SKPaymentTransactionStateDeferred:
				lua_pushliteral(L, "deferred"); // Should never be here
				break;
		}
	} else if ( 0 == strcmp( "errorType", key ) ) {
		if(transaction.error) {
			lua_pushliteral(L, "none");
		} else {
			switch( transaction.error.code ) {
				case SKErrorPaymentCancelled:
					lua_pushliteral(L, "cancelled"); // result = kTransactionErrorPaymentCancelled;
					break;
				case SKErrorClientInvalid:
					lua_pushliteral(L, "invalidClient"); //kTransactionErrorClientInvalid;
					break;
				case SKErrorPaymentInvalid:
					lua_pushliteral(L, "invalidPayment"); //kTransactionErrorPaymentInvalid;
					break;
				case SKErrorPaymentNotAllowed:
					lua_pushliteral(L, "paymentNotAllowed"); //kTransactionErrorPaymentNotAllowed;
					break;
				default:
					lua_pushliteral(L, "unknown"); //kTransactionErrorUnknown;
					break;
			}
		}
	} else if ( 0 == strcmp( "errorString", key ) ) {
		lua_pushstring( L, [[[transaction error] localizedDescription] UTF8String] );
	} else if ( 0 == strcmp( "productIdentifier", key ) ) {
		lua_pushstring( L, [[[transaction payment] productIdentifier] UTF8String] );
	} else if ( 0 == strcmp( "signature", key ) ) {
		lua_pushnil(L);
	} else if ( 0 == strcmp( "identifier", key ) ) {
		lua_pushstring(L, [[transaction transactionIdentifier] UTF8String]);
	} else if ( 0 == strcmp( "date", key ) ) {
		lua_pushstring(L, [[[transaction transactionDate] description] UTF8String]);
	}
#if TARGET_OS_IOS
	else if ( 0 == strcmp( "receipt", key ) ) {
		lua_pushstring(L, [[[transaction performSelector:@selector(transactionReceipt)] base64EncodedStringWithOptions:0] UTF8String]);
	} else if ( 0 == strcmp( "originalReceipt", key ) ) {
		lua_pushstring(L, [[[[transaction performSelector:@selector(originalTransaction)] performSelector:@selector(transactionReceipt)] base64EncodedStringWithOptions:0] UTF8String]);
	}
#endif
	else if ( 0 == strcmp( "originalIdentifier", key ) ) {
		lua_pushstring( L, [[[transaction originalTransaction] transactionIdentifier] UTF8String]);
	} else if ( 0 == strcmp( "originalDate", key ) ) {
		lua_pushstring( L, [[[[transaction originalTransaction] transactionDate] description] UTF8String]);
	} else {
		nRet = 0;
	}
	
	return nRet;
}

static int appleIAP_transactionGC(lua_State *L) {
	SKPaymentTransaction* transaction = (SKPaymentTransaction*)CoronaLuaCheckUserdata(L, 1, kAppleIAP_TransactionMetatdata);
	[transaction release];
	return 0;
}


static int appleIAP_PaymentIndex(lua_State *L) {
	SKPayment *payment = (SKPayment*)CoronaLuaCheckUserdata( L, 1, kAppleIAP_PaymentMetatdata );
	if(!payment)
		return 0;
	
	const char *key = luaL_checkstring( L, 2 );
	int nRet = 1;

	if (0 == strcmp( "type", key )) {
		lua_pushliteral(L, "payment");
	} else if ( 0 == strcmp( "productIdentifier", key ) ) {
		lua_pushstring( L, [[payment productIdentifier] UTF8String] );
	} else if ( 0 == strcmp( "requestData", key ) ) {
		lua_pushstring( L, [[[payment requestData] base64EncodedStringWithOptions:0] UTF8String]);
	} else if ( 0 == strcmp( "quantity", key ) ) {
		lua_pushinteger(L, [payment quantity]);
	} else if ( 0 == strcmp( "applicationUsername", key ) ) {
		lua_pushstring(L, [[payment applicationUsername] UTF8String]);
	} else if ( 0 == strcmp( "simulatesAskToBuyInSandbox", key ) ) {
		if (@available(iOS 12.2, macOS 10.14.4, tvOS 12.2, *)) {
			lua_pushboolean(L, [payment simulatesAskToBuyInSandbox]);
		} else {
			lua_pushnil(L);
		}
	} else if ( 0 == strcmp( "paymentDiscount", key ) ) {
		if (@available(iOS 12.2, macOS 10.14.4, tvOS 12.2, *)) {
			SKPaymentDiscount *discount = [payment paymentDiscount];
			lua_createtable(L, 0, 5);
			
			lua_pushstring(L, [[discount identifier] UTF8String]);
			lua_setfield(L, -2, "identifier");

			lua_pushstring(L, [[discount keyIdentifier] UTF8String]);
			lua_setfield(L, -2, "keyIdentifier");
			
			lua_pushstring(L, [[[discount nonce] UUIDString] UTF8String]);
			lua_setfield(L, -2, "nonce");
			
			lua_pushstring(L, [[discount signature] UTF8String]);
			lua_setfield(L, -2, "signature");

			lua_pushinteger(L, [[discount timestamp] longValue]);
			lua_setfield(L, -2, "timestamp");

		} else {
			lua_pushnil(L);
		}
	} else {
		nRet = 0;
	}
	
	return nRet;
}

static int appleIAP_PaymentGC(lua_State *L) {
	SKPayment* payment = (SKPayment*)CoronaLuaCheckUserdata(L, 1, kAppleIAP_PaymentMetatdata);
	[payment release];
	return 0;
}


#ifdef TARGET_OS_OSX
static int apple_IAPSimulatorDummy(lua_State *L) {
	printf("WARNING, Apple IAP Plugin won't work in Simulator\n");
	return 0;
}
#endif

CORONA_EXPORT int luaopen_plugin_apple_iap( lua_State *L )
{
	luaL_Reg kVTable[] =
	{
		{ "init", appleIAP_init },
		{ "loadProducts", appleIAP_loadProducts },
		{ "purchase", appleIAP_purchase },
		{ "finishTransaction", appleIAP_finishTransaction },
		{ "restore", appleIAP_restoreCompletedTransactions },

		{ "deferStorePurchases", appleIAP_deferPurchases },
		{ "proceedToPayment", appleIAP_continueDeferred },

		{ "receiptRawData", appleIAP_rawReceiptData },
		{ "receiptBase64Data", appleIAP_base64ReceiptData },
		{ "receiptDecrypted", appleIAP_decryptedReceipt },
		{ "receiptAvailable", appleIAP_receiptAvailable },
		{ "receiptRequest", appleIAP_requestReceipt },
		{ NULL, NULL }
	};
#ifdef TARGET_OS_OSX
	bool simulator = false;
	lua_getglobal( L, "system" );
	if (lua_istable( L, -1 ))
	{
		lua_getfield( L, -1, "getInfo" );
		if(lua_isfunction( L, -1 ))
		{
			lua_pushstring( L, "environment" );
			if( CoronaLuaDoCall( L, 1, 1 ) == 0 )
			{
				if ( lua_type( L, -1) == LUA_TSTRING )
				{
					simulator = (strcmp("simulator", lua_tostring( L, -1)) == 0);
				}
			}
			lua_pop( L, 1 ); //remove result or error
		}
		else
		{
			lua_pop( L, 1 );
		}
	}
	lua_pop( L, 1);
	if (simulator)
	{
		int i = 0;
		do
		{
			kVTable[i].func = apple_IAPSimulatorDummy;
		} while ( kVTable[++i].name );
		CoronaLuaWarning( L, "IAP plugin would not work in Corona Simulator." );
	
		luaL_openlib( L, "plugin.apple.iap", kVTable, 0 );

		lua_pushliteral(L, "apple");
		lua_setfield(L, -2, "target");
		
		lua_pushboolean(L, false);
		lua_setfield(L, -2, "isActive");

		lua_pushboolean(L, false);
		lua_setfield(L, -2, "canMakePurchases");
		
		lua_pushboolean(L, false);
		lua_setfield(L, -2, "canLoadProducts");

		return 1;
	}
#endif
	
	const luaL_Reg kTransactionVTable[] =
	{
		{ "__index", appleIAP_transactionIndex },
		{"__gc", appleIAP_transactionGC },
		
		{ NULL, NULL }
	};
	CoronaLuaInitializeMetatable( L, kAppleIAP_TransactionMetatdata, kTransactionVTable );
	
	const luaL_Reg kPaymentVTable[] =
	{
		{ "__index", appleIAP_PaymentIndex },
		{"__gc", appleIAP_PaymentGC },
		
		{ NULL, NULL }
	};
	CoronaLuaInitializeMetatable( L, kAppleIAP_PaymentMetatdata, kPaymentVTable );

	
	const char* kMetatableName = "AppleIAP-FF02A024808F";
	CoronaLuaInitializeGCMetatable(L, kMetatableName, cleanupIAPs);
	
	AppleIAPTransactionObserver *observer = [[AppleIAPTransactionObserver alloc] initWithState:L];
	CoronaLuaPushUserdata( L, observer, kMetatableName );
    luaL_openlib( L, "plugin.apple.iap", kVTable, 1 );
	
	const luaL_Reg kIndexMetatable[] =
	{
		{ "__index", appleIAP_StoreValues },
		{ NULL, NULL }
	};
	luaL_register( L, "LuaLibStore", kIndexMetatable );
	lua_setmetatable( L, -2 );
	
    return 1;
}
