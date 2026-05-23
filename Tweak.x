@import UIKit;
@import Foundation;

static const char *DYLIB_VERSION_STRING __attribute__((used)) = "@(#)cgss-patcher 20260523. Copyright (c) 2023-2024, the Holy Constituency of the Summer Triangle.";

static NSString *const kDefaultAPIEndpoint = @"apis.game.starlight-stage.jp/";
static NSString *const kDefaultAssetEndpoint = @"asset-starlight-stage.akamaized.net/";
static NSString *const kSettingAPIEndpoint = @"APIEndpoint";
static NSString *const kSettingAssetEndpoint = @"AssetEndpoint";

static NSString *trimString(NSString *s) {
	if (!s) {
		return @"";
	}
	return [s stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
}

static NSURLComponents *componentsFromEndpointInput(NSString *value) {
	if (value.length == 0) {
		return nil;
	}
	if ([value containsString:@"://"]) {
		return [NSURLComponents componentsWithString:value];
	}
	return [NSURLComponents componentsWithString:[@"https://" stringByAppendingString:value]];
}

static NSString *normalizeEndpointSetting(NSString *rawValue, NSString *fallbackEndpoint) {
	NSString *value = trimString(rawValue);
	if (value.length == 0) {
		return fallbackEndpoint;
	}

	NSURLComponents *components = componentsFromEndpointInput(value);

	NSString *host = trimString(components.host);
	if (host.length == 0) {
		return fallbackEndpoint;
	}

	NSString *normalizedHost = [host lowercaseString];
	if (components.port != nil) {
		normalizedHost = [NSString stringWithFormat:@"%@:%@", normalizedHost, components.port];
	}
	NSString *path = components.path ?: @"";
	if (path.length == 0) {
		path = @"/";
	} else if (![path hasSuffix:@"/"]) {
		path = [path stringByAppendingString:@"/"];
	}
	return [normalizedHost stringByAppendingString:path];
}

static NSString *configuredEndpoint(NSString *key, NSString *fallbackEndpoint) {
	NSUserDefaults *settings = [NSUserDefaults standardUserDefaults];
	NSString *raw = [settings stringForKey:key];
	NSString *normalized = normalizeEndpointSetting(raw, fallbackEndpoint);
	if (raw == nil || ![normalized isEqualToString:raw]) {
		[settings setObject:normalized forKey:key];
		[settings synchronize];
	}
	return normalized;
}

static NSString *configuredHost(NSString *key, NSString *fallbackEndpoint) {
	NSString *endpoint = configuredEndpoint(key, fallbackEndpoint);
	NSURLComponents *components = componentsFromEndpointInput(endpoint);
	NSString *host = trimString(components.host);
	if (host.length == 0) {
		components = componentsFromEndpointInput(fallbackEndpoint);
		host = trimString(components.host);
	}
	if (components.port != nil) {
		return [[NSString stringWithFormat:@"%@:%@", host, components.port] lowercaseString];
	}
	return [host lowercaseString];
}

static BOOL isCGSSAPIHost(NSString *host) {
	if (!host) {
		return NO;
	}
	NSString *lower = [host lowercaseString];
	return [lower isEqualToString:@"apis.game.starlight-stage.jp"] || [lower hasSuffix:@".starlight-stage.jp"];
}

static BOOL isCGSSAssetHost(NSString *host) {
	if (!host) {
		return NO;
	}
	return [[host lowercaseString] isEqualToString:@"asset-starlight-stage.akamaized.net"];
}

static NSString *rewriteURLString(NSString *urlString) {
	if (!urlString || urlString.length == 0) {
		return urlString;
	}

	NSURLComponents *components = [NSURLComponents componentsWithString:urlString];
	if (!components || components.host.length == 0) {
		return urlString;
	}

	NSString *oldHost = [components.host lowercaseString];
	NSString *targetHost = nil;

	if (isCGSSAssetHost(oldHost)) {
		targetHost = configuredHost(kSettingAssetEndpoint, kDefaultAssetEndpoint);
	} else if (isCGSSAPIHost(oldHost)) {
		targetHost = configuredHost(kSettingAPIEndpoint, kDefaultAPIEndpoint);
	}

	if (!targetHost || [oldHost isEqualToString:targetHost]) {
		return urlString;
	}

	components.host = targetHost;
	NSString *rewritten = components.string;
	if (!rewritten || rewritten.length == 0) {
		return urlString;
	}

	NSLog(@"[cgss-patcher] rewrite URL host: %@ -> %@", oldHost, targetHost);
	return rewritten;
}

%hook NSURL

+ (instancetype)URLWithString:(NSString *)URLString {
	return %orig(rewriteURLString(URLString));
}

+ (instancetype)URLWithString:(NSString *)URLString relativeToURL:(NSURL *)baseURL {
	return %orig(rewriteURLString(URLString), baseURL);
}

- (instancetype)initWithString:(NSString *)URLString {
	return %orig(rewriteURLString(URLString));
}

- (instancetype)initWithString:(NSString *)URLString relativeToURL:(NSURL *)baseURL {
	return %orig(rewriteURLString(URLString), baseURL);
}

%end

%hook NSMutableURLRequest

- (void)setURL:(NSURL *)URL {
	if (URL && URL.absoluteString.length > 0) {
		NSString *rewrittenString = rewriteURLString(URL.absoluteString);
		if (rewrittenString.length > 0 && ![rewrittenString isEqualToString:URL.absoluteString]) {
			NSURL *rewrittenURL = [NSURL URLWithString:rewrittenString];
			if (rewrittenURL) {
				%orig(rewrittenURL);
				return;
			}
		}
	}
	%orig;
}

%end
