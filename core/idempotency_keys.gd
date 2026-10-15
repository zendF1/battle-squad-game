extends RefCounted
## One key per target (a shop offer, an IAP product) for a request that must not take effect
## twice: POST /shop/purchase {idempotencyKey}, POST /iap/verify {purchaseToken} in mock mode.
## The server replays the original answer for a key it has already completed.
##
## A key is kept until a definite answer: 2xx (done) or 4xx (refused, nothing charged). On no
## answer (status 0) or a 5xx the request may still have gone through, so the retry must send
## the same key. Keys are saved to `path` (when given) so a retry after the app was closed or the
## Home scene rebuilt still reuses them.

const Uuid := preload("res://core/uuid.gd")

var _prefix: String
var _path: String
var _keys := {} # target id -> key


func _init(prefix: String = "", path: String = "") -> void:
	_prefix = prefix
	_path = path
	if _path == "":
		return
	var cfg := ConfigFile.new()
	if cfg.load(_path) != OK or not cfg.has_section("keys"):
		return
	for id in cfg.get_section_keys("keys"):
		_keys[id] = str(cfg.get_value("keys", id, ""))


## The key to send for `id`, created on first use.
func key_for(id: String) -> String:
	if not _keys.has(id):
		_keys[id] = _prefix + Uuid.v4()
		_save()
	return _keys[id]


func has_key(id: String) -> bool:
	return _keys.has(id)


static func is_definite(status: int) -> bool:
	return (status >= 200 and status < 300) or (status >= 400 and status < 500)


## Records the answer to a request sent with key_for(id). Returns true when the key was dropped.
func settle(id: String, status: int) -> bool:
	if not is_definite(status) or not _keys.has(id):
		return false
	_keys.erase(id)
	_save()
	return true


func _save() -> void:
	if _path == "":
		return
	var cfg := ConfigFile.new()
	for id in _keys:
		cfg.set_value("keys", id, _keys[id])
	cfg.save(_path)
