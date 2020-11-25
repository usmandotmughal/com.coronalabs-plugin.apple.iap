local metadata =
{
	plugin =
	{
		format = 'staticLibrary',
		staticLibs = { 'plugin_iap_cryptohelper', },
		frameworks = {},
		frameworksOptional = {},
		-- usesSwift = true,
	},
	coronaManifest = {
		dependencies = {
			["plugin.openssl"] = "com.coronalabs",
		}
	}
}

return metadata
