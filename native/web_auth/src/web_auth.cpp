#include "web_auth.h"
#include "web_auth_native.h"

using namespace godot;

WebAuth *WebAuth::singleton = nullptr;

WebAuth *WebAuth::get_singleton() {
	return singleton;
}

WebAuth::WebAuth() {
	singleton = this;
}

WebAuth::~WebAuth() {
	if (singleton == this) {
		singleton = nullptr;
	}
}

void WebAuth::_bind_methods() {
	ClassDB::bind_method(D_METHOD("is_available"), &WebAuth::is_available);
	ClassDB::bind_method(D_METHOD("is_running"), &WebAuth::is_running);
	ClassDB::bind_method(D_METHOD("start", "url", "callback_scheme", "ephemeral"), &WebAuth::start, DEFVAL(false));
	ClassDB::bind_method(D_METHOD("cancel"), &WebAuth::cancel);
	ClassDB::bind_method(D_METHOD("_finish", "status", "callback_url", "message"), &WebAuth::finish);
	ADD_SIGNAL(MethodInfo("finished", PropertyInfo(Variant::INT, "status"), PropertyInfo(Variant::STRING, "callback_url"),
			PropertyInfo(Variant::STRING, "message")));
	BIND_ENUM_CONSTANT(STATUS_OK);
	BIND_ENUM_CONSTANT(STATUS_CANCELLED);
	BIND_ENUM_CONSTANT(STATUS_FAILED);
}

bool WebAuth::is_available() const {
	return web_auth_native_available() != 0;
}

bool WebAuth::is_running() const {
	return web_auth_native_running() != 0;
}

Error WebAuth::start(const String &url, const String &callback_scheme, bool ephemeral) {
	CharString u = url.utf8();
	CharString s = callback_scheme.utf8();
	switch (web_auth_native_start(u.get_data(), s.get_data(), ephemeral ? 1 : 0)) {
		case 0:
			return OK;
		case 1:
			return ERR_BUSY;
		case 2:
			return ERR_UNAVAILABLE;
		default:
			return ERR_CANT_CREATE;
	}
}

void WebAuth::cancel() {
	web_auth_native_cancel();
}

void WebAuth::finish(int status, const String &callback_url, const String &message) {
	emit_signal("finished", status, callback_url, message);
}

extern "C" void web_auth_native_finished(int status, const char *callback_url, const char *message) {
	WebAuth *wa = WebAuth::get_singleton();
	if (wa == nullptr) {
		return;
	}
	// Deferred: the system calls back from inside the OS event pump; GDScript resumes on the next frame.
	wa->call_deferred("_finish", status, String::utf8(callback_url ? callback_url : ""), String::utf8(message ? message : ""));
}
