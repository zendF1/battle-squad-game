#pragma once
// WebAuth: the engine singleton "WebAuth" (macOS and iOS) that shows a web sign-in page in the system's
// ASWebAuthenticationSession and hands back the URL the page redirected to.
//
// GDScript:
//   var wa = Engine.get_singleton("WebAuth")
//   wa.finished.connect(func(status, url, message): ...)
//   wa.start(auth_url, callback_scheme, ephemeral)  # OK, ERR_BUSY, ERR_UNAVAILABLE or ERR_CANT_CREATE
//
// finished(status: int, callback_url: String, message: String) fires once per started session, on the
// main thread (deferred): status STATUS_OK (callback_url set), STATUS_CANCELLED (the player closed the
// sheet, or cancel()), STATUS_FAILED (message: the system's error).

#include <godot_cpp/classes/object.hpp>
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/string.hpp>

namespace godot {

class WebAuth : public Object {
	GDCLASS(WebAuth, Object);

	static WebAuth *singleton;

protected:
	static void _bind_methods();

public:
	enum Status {
		STATUS_OK = 0,
		STATUS_CANCELLED = 1,
		STATUS_FAILED = 2,
	};

	static WebAuth *get_singleton();

	WebAuth();
	~WebAuth();

	bool is_available() const;
	bool is_running() const;
	Error start(const String &url, const String &callback_scheme, bool ephemeral);
	void cancel();

	// Called by the Objective-C side on the main thread when the session ends.
	void finish(int status, const String &callback_url, const String &message);
};

} // namespace godot

VARIANT_ENUM_CAST(WebAuth::Status);
