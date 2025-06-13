local json = require "json"
local store = require "plugin.apple.iap"

print("Store target", store.target)

local y = 70
local x = display.contentCenterX

local isPromotionalOfferPurchase = false
local purchaseAdditionalTest = (isPromotionalOfferPurchase == true) and "Promotional Offer: " or ""

local prodList = {
    "com.coronalabs.IapTest.pc10",
    "com.coronalabs.IapTest.pc50",
    "com.coronalabs.IapTest.badApple1",
    "com.coronalabs.IapTest.badApple2",
    "com.coronalabs.IapTest.sub",
    "com.coronalabs.IapTest.subplus",
    "com.coronalabs.IapTest.goodies",
    "com.coronalabs.IapTest.onetime",
}

local function verifyPurchase( originalIdentifier )
    print("Verifying", originalIdentifier)
    local iaps = store.receiptDecrypted().in_app
    for i=1,#iaps do
        local iap = iaps[i]
        if iap.original_transaction_id == originalIdentifier then
            return true
        end
    end
    return false
end


store.init( "apple", function(event) 
    local t = event.transaction
    if t then
        local rc = display.newText(tostring(t.state) .. ": " .. tostring(t.productIdentifier), x, y)
        y = y+rc.height*1.2
        if t.state == "restored" or t.state == "purchased" then
            local verified = verifyPurchase(t.originalIdentifier or t.identifier)
            print("Verified purchase", verified)
            native.showAlert("Purchase Verified", tostring(verified), {"OK"})
        end
    end
    store.finishTransaction( t )
    native.setActivityIndicator( false )
end)

local rc = display.newText("Read receipts", x, y)
rc:addEventListener("tap", function()
    if store.receiptAvailable() then
        print("Receipt is already available")
        print("Raw regular len ", #tostring(store.receiptRawData()))
        print("Raw base64 len", #tostring(store.receiptBase64Data(true)))
        print("Decrypted receipt", json.prettify(store.receiptDecrypted() or {}))
    else
        print("Requesting receipt")
        store.receiptRequest(function(event)
            print("Request is done!", json.encode(event))
            if store.receiptAvailable() then
                print("Raw regular len ", #tostring(store.receiptRawData()))
                print("Raw base64 len", #tostring(store.receiptRawData()))
                print("Decrypted receipt", json.prettify(store.receiptDecrypted() or {}))
            else
                print("There are no receipts!)")
            end
        end)
    end
end)
y = y+rc.height*1.2

local rc = display.newText("Restore Purchases", x, y)
rc:addEventListener("tap", function()
    store.restore()
    native.setActivityIndicator( true )
end)
y = y+rc.height*1.2

local rc = display.newText("Check Intro Offer Eligibility", x, y)
rc:addEventListener("tap", function()
    native.setActivityIndicator( true )
    store.isEligibleForIntroOffer("com.coronalabs.IapTest.sub", function(event)
        print( "isEligibleForIntroOffer event : ", json.encode(event) )
        if event.eligibility then
            print("intro offer is available")
        else
            print("intro offer is not available")
        end
        native.setActivityIndicator( false )
    end)
end)
y = y+rc.height*1.5

store.loadProducts(prodList, function(event)
    print("LOADED PRODUCTS", json.prettify(event))
    local products = event.products or {}
    for i=1, #products do
        local p = products[i]
        local rc = display.newText(purchaseAdditionalTest .. p.title .. ' ' .. p.localizedPrice, x, y)
        rc:addEventListener("tap", function()
            if isPromotionalOfferPurchase then
                -- https://developer.apple.com/documentation/StoreKit/generating-a-promotional-offer-signature-on-the-server
                -- https://github.com/apple/app-store-server-library-node
                -- https://developer.apple.com/documentation/storekit/implementing-promotional-offers-in-your-app
                local offerParameters = {
                    keyIdentifier = "FKJB7P8VN6",
                    productIdentifier = p.productIdentifier,
                    offerIdentifier = "free_for_1_year",
                    signature = "MEUCIEfJm+oJM4w+eMe+HZguhFFlbUj2Qk/juACY3u7WK9LRAiEA9ips3wL2BST2VdA5Fiyl7ANigLrcrUKaDHBC8iraTQw=",
                    appAccountToken = "user_1",
                    nonce = "1c047e53-8dde-497b-ae63-cb0cd4ca1f30",
                    timestamp = 1748348199738
                }
                store.purchasePromotionalOffer(offerParameters)
            else
                store.purchase(p.productIdentifier)    
            end
            native.setActivityIndicator( true )
        end)
        y = y+rc.height*1.2
    end
end )


local function onKey( event )
    if event.keyName == "buttonA" and event.phase == "up" then
        store.purchase("com.coronalabs.IapTest.pc10")
        print("BUYING!")
    end
end

Runtime:addEventListener( "key", onKey )

local function deferPurchasesListener(event)
    print("PURCHASE DEFERRED!", json.prettify( event ), event.payment.productIdentifier)
    local rc = display.newText("Continue... " .. event.payment.productIdentifier, x, y)
    rc:addEventListener("tap", function()
        store.proceedToPayment(event.payment)
    end)
    y = y+rc.height*1.2

end
store.deferStorePurchases(deferPurchasesListener)

