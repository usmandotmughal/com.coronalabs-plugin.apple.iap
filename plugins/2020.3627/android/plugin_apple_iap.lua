local lib = require('CoronaLibrary'):new{name = 'plugin.apple.iap', publisherId = 'com.coronalabs'}

lib.target = 'apple'
lib.isActive = false
lib.canMakePurchases = false
lib.canloadProducts = false

local functions = {"receiptRawData", "receiptBase64Data", "receiptAvailable", "receiptRequest", "receiptDecrypted" , "init", "loadProducts", "purchase", "finishTransaction", "restore", }


for i = 1, #functions do
    local f = functions[i]
    lib[f] = function()
        print('plugin.apple.iap: ' .. f .. '() is not supported on this platform.')
        if f == 'isSandboxMode' then
            return true
        end
    end
end

lib.init = function( a, b )
	if type(a) == "string" then
		a = b
	end
	if type(b) == "function" then
		b({name="init"})
	end
end

return lib
