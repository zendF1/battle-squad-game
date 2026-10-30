#include <gdextension_interface.h>
#include <godot_cpp/classes/engine.hpp>
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/core/defs.hpp>
#include <godot_cpp/godot.hpp>

#include "web_auth.h"

using namespace godot;

static WebAuth *web_auth_singleton = nullptr;

static void initialize_web_auth(ModuleInitializationLevel p_level) {
	if (p_level != MODULE_INITIALIZATION_LEVEL_SCENE) {
		return;
	}
	GDREGISTER_CLASS(WebAuth);
	web_auth_singleton = memnew(WebAuth);
	Engine::get_singleton()->register_singleton("WebAuth", web_auth_singleton);
}

static void uninitialize_web_auth(ModuleInitializationLevel p_level) {
	if (p_level != MODULE_INITIALIZATION_LEVEL_SCENE) {
		return;
	}
	if (web_auth_singleton != nullptr) {
		Engine::get_singleton()->unregister_singleton("WebAuth");
		memdelete(web_auth_singleton);
		web_auth_singleton = nullptr;
	}
}

extern "C" {
// The entry point named in addons/web_auth/web_auth.gdextension; unique because iOS links it statically.
GDExtensionBool GDE_EXPORT web_auth_library_init(GDExtensionInterfaceGetProcAddress p_get_proc_address,
		const GDExtensionClassLibraryPtr p_library, GDExtensionInitialization *r_initialization) {
	GDExtensionBinding::InitObject init_obj(p_get_proc_address, p_library, r_initialization);
	init_obj.register_initializer(initialize_web_auth);
	init_obj.register_terminator(uninitialize_web_auth);
	init_obj.set_minimum_library_initialization_level(MODULE_INITIALIZATION_LEVEL_SCENE);
	return init_obj.init();
}
}
