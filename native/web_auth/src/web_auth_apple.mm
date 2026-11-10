// ASWebAuthenticationSession for WebAuth (web_auth.cpp) on macOS and iOS. Objective-C++ with ARC, no
// Godot headers: it talks to the C++ side through web_auth_native.h.

#import <AuthenticationServices/AuthenticationServices.h>
#import <Foundation/Foundation.h>
#include <TargetConditionals.h>
#if TARGET_OS_OSX
#import <AppKit/AppKit.h>
#else
#import <UIKit/UIKit.h>
#endif

#include "web_auth_native.h"

// On iOS this is a static library the app links: ask that linker for the framework (Godot's iOS export
// does not list it, and ObjC++ #import does not auto-link).
__asm__(".linker_option \"-framework\", \"AuthenticationServices\"");

API_AVAILABLE(macos(10.15), ios(13.0))
@interface WebAuthAnchor : NSObject <ASWebAuthenticationPresentationContextProviding>
@end

@implementation WebAuthAnchor
- (ASPresentationAnchor)presentationAnchorForWebAuthenticationSession:(ASWebAuthenticationSession *)session {
#if TARGET_OS_OSX
	NSWindow *w = NSApp.keyWindow ?: NSApp.mainWindow;
	if (w == nil && NSApp.windows.count > 0) {
		w = NSApp.windows.firstObject;
	}
	return w ?: [[NSWindow alloc] init];
#else
	for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
		if (![scene isKindOfClass:UIWindowScene.class]) {
			continue;
		}
		for (UIWindow *win in ((UIWindowScene *)scene).windows) {
			if (win.isKeyWindow) {
				return win;
			}
		}
	}
	for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
		if ([scene isKindOfClass:UIWindowScene.class] && ((UIWindowScene *)scene).windows.count > 0) {
			return ((UIWindowScene *)scene).windows.firstObject;
		}
	}
	return [[UIWindow alloc] init];
#endif
}
@end

// The session showing (strong while it runs; the system does not retain it) and its anchor.
static id g_session = nil;
static id g_anchor = nil;
// Counts started sessions: a completion that is not the current session's is ignored.
static unsigned long g_serial = 0;

static void web_auth_end(int status, NSString *url, NSString *message) {
	g_session = nil;
	g_anchor = nil;
	web_auth_native_finished(status, url ? url.UTF8String : "", message ? message.UTF8String : "");
}

int web_auth_native_available(void) {
	if (@available(macOS 10.15, iOS 13.0, *)) {
		return 1;
	}
	return 0;
}

int web_auth_native_running(void) {
	return g_session != nil ? 1 : 0;
}

int web_auth_native_start(const char *url, const char *callback_scheme, int ephemeral) {
	if (@available(macOS 10.15, iOS 13.0, *)) {
		if (g_session != nil) {
			return 1;
		}
		NSURL *u = [NSURL URLWithString:[NSString stringWithUTF8String:url ? url : ""]];
		NSString *scheme = [NSString stringWithUTF8String:callback_scheme ? callback_scheme : ""];
		if (u == nil || scheme.length == 0 || !([u.scheme isEqualToString:@"https"] || [u.scheme isEqualToString:@"http"])) {
			return 3;
		}
		unsigned long serial = ++g_serial;
		ASWebAuthenticationSession *session = [[ASWebAuthenticationSession alloc] initWithURL:u
												callbackURLScheme:scheme
												completionHandler:^(NSURL *callbackURL, NSError *error) {
													dispatch_async(dispatch_get_main_queue(), ^{
														if (g_session == nil || serial != g_serial) {
															return; // an older session's late answer
														}
														if (callbackURL != nil) {
															web_auth_end(0, callbackURL.absoluteString, nil);
														} else if (error != nil && [error.domain isEqualToString:ASWebAuthenticationSessionErrorDomain] &&
																error.code == ASWebAuthenticationSessionErrorCodeCanceledLogin) {
															web_auth_end(1, nil, nil);
														} else {
															web_auth_end(2, nil, error != nil ? error.localizedDescription : @"no callback");
														}
													});
												}];
		WebAuthAnchor *anchor = [[WebAuthAnchor alloc] init];
		session.presentationContextProvider = anchor;
		session.prefersEphemeralWebBrowserSession = ephemeral != 0;
		g_session = session;
		g_anchor = anchor;
		if (![session start]) {
			g_session = nil;
			g_anchor = nil;
			return 3;
		}
		return 0;
	}
	return 2;
}

void web_auth_native_cancel(void) {
	if (@available(macOS 10.15, iOS 13.0, *)) {
		ASWebAuthenticationSession *session = g_session;
		if (session == nil) {
			return;
		}
		// cancel does not call the completion handler: report it here, once.
		[session cancel];
		web_auth_end(1, nil, nil);
	}
}
