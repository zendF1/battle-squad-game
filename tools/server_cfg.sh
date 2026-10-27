# Sourced by the build scripts: bakes the server into res://server.cfg (removed on exit).
# $1 is a host (http://host:9090 and ws://host:9091: a dev server, the Mac on the same Wi-Fi) or a
# base URL (https://domain: the API on it and the WebSocket on wss://domain/ws, deploy/nginx-host.conf.template).
write_server_cfg() {
	case "$1" in
	https://*) API=${1%/}; WS=wss://${API#https://} ;;
	http://*) API=${1%/}; WS=ws://${API#http://} ;;
	*) API=http://$1:9090; WS=ws://$1:9091 ;;
	esac
	printf '[server]\n\napi_url="%s"\nws_url="%s"\n' "$API" "$WS" > server.cfg
	trap 'rm -f server.cfg' EXIT
}
