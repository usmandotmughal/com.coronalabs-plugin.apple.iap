local metadata =
{
	plugin =
	{
		format = 'framework',
		staticLibs = {},
		frameworks = { "Corona_plugin_apple_iap_cryptohelper", "Corona_plugin_openssl", },
		frameworksOptional = {},
	},
	coronaManifest = {
		dependencies = {
			["plugin.openssl"] = "com.coronalabs",
		}
	}	
}

return metadata