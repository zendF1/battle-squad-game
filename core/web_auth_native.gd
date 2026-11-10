extends RefCounted
## The system sign-in sheet: the "WebAuth" singleton of the native extension (addons/web_auth, source
## native/web_auth: ASWebAuthenticationSession on macOS and iOS, also in the macOS editor). Elsewhere
## (Windows, Linux, headless runs) the singleton is missing or the display is headless: available()
## is false and the Google buttons say "Sắp ra mắt".

const SINGLETON := "WebAuth"
## run() result statuses (the extension's WebAuth.STATUS_*).
const OK_STATUS := 0
const CANCELLED := 1
const FAILED := 2


static func available() -> bool:
	if DisplayServer.get_name() == "headless" or not Engine.has_singleton(SINGLETON):
		return false
	return bool(Engine.get_singleton(SINGLETON).call("is_available"))


## Shows `url` in the sheet until it redirects to `scheme:`; {status, url, message}. Never call it
## while another run is showing (status FAILED, message "busy").
func run(url: String, scheme: String) -> Dictionary:
	if not available():
		return {"status": FAILED, "url": "", "message": "unavailable"}
	var wa: Object = Engine.get_singleton(SINGLETON)
	var err: int = wa.call("start", url, scheme, false)
	if err != OK:
		return {"status": FAILED, "url": "", "message": "busy" if err == ERR_BUSY else "start %d" % err}
	var r: Array = await wa.finished
	return {"status": int(r[0]), "url": str(r[1]), "message": str(r[2])}
