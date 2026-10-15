extends Control
## "Chơi": Quick Play (idle practice target) and Play vs bot (QuickPlay {"bot": "ai"}); both open
## the Loadout screen, which sends the request (screens/quick_play.gd).

const Ui := preload("res://ui/ui.gd")

var _conn: Label


func _ready() -> void:
	var col := Ui.center_column(self)
	var quick_play := Ui.button("Chơi nhanh (Luyện tập)", 34)
	quick_play.custom_minimum_size = Vector2(560, 110)
	quick_play.pressed.connect(_open_loadout.bind({}))
	col.add_child(quick_play)
	var vs_bot := Ui.button("Đấu với máy", 34)
	vs_bot.custom_minimum_size = Vector2(560, 110)
	vs_bot.pressed.connect(_open_loadout.bind({"bot": "ai"}))
	col.add_child(vs_bot)
	_conn = Ui.label("", 24)
	col.add_child(_conn)

	GameSocket.connected.connect(_update_conn)
	GameSocket.disconnected.connect(_update_conn)
	_update_conn()


func _update_conn() -> void:
	_conn.text = "● Online" if GameSocket.is_open() else "○ Đang kết nối..."


func _open_loadout(base: Dictionary) -> void:
	Router.quick_play_base = base
	Router.go(Router.LOADOUT)
