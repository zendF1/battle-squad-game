#pragma once
// The bridge between WebAuth (C++, godot-cpp) and the platform code (web_auth_apple.mm, Objective-C,
// no Godot headers). Strings are UTF-8.

#ifdef __cplusplus
extern "C" {
#endif

// 1 when this OS has ASWebAuthenticationSession with a presentation anchor (macOS 10.15+, iOS 13+).
int web_auth_native_available(void);
// 0 started, 1 busy (a session is showing), 2 unavailable, 3 the system refused to start.
int web_auth_native_start(const char *url, const char *callback_scheme, int ephemeral);
void web_auth_native_cancel(void);
int web_auth_native_running(void);

// Implemented by web_auth.cpp; the platform code calls it once per started session, on the main thread.
// status: 0 ok (callback_url set), 1 cancelled, 2 failed (message set).
void web_auth_native_finished(int status, const char *callback_url, const char *message);

#ifdef __cplusplus
}
#endif
