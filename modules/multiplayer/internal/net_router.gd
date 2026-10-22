extends Node
## Opens the host's port on the home router (UPnP) so crew can join over the internet, and
## finds the router's external address to give them. Router work blocks for a second or
## two, so it runs on a thread; results come back on the main thread through `changed`.
## Owned by MultiplayerBus, which opens on hosting and closes when the session ends.

signal changed(info: Dictionary)

const DESCRIPTION := "BSX Ltd"
const DISCOVER_MS := 2000

## "off" (not hosting), "opening", "open" (port mapped, external known), "failed".
var info: Dictionary = {"state": "off", "external": "", "port": 0, "reason": ""}
var _upnp: UPNP
var _thread: Thread
var _mapped_port := 0


func open(port: int) -> void:
	if _busy():
		return
	_set_info({"state": "opening", "external": "", "port": port, "reason": ""})
	_thread = Thread.new()
	_thread.start(_open_work.bind(port))


func close() -> void:
	if info.state == "off":
		return
	_set_info({"state": "off", "external": "", "port": 0, "reason": ""})
	if _mapped_port == 0 or _busy():
		return
	_thread = Thread.new()
	_thread.start(_close_work.bind(_mapped_port))
	_mapped_port = 0


func _notification(what: int) -> void:
	# Leave nothing open on the router when the game closes.
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_PREDELETE:
		if _thread and _thread.is_started():
			_thread.wait_to_finish()
		if _upnp and _mapped_port != 0:
			_upnp.delete_port_mapping(_mapped_port, "UDP")
			_mapped_port = 0


func _busy() -> bool:
	if _thread == null:
		return false
	if _thread.is_alive():
		return true
	_thread.wait_to_finish()
	_thread = null
	return false


func _open_work(port: int) -> void:
	var upnp := UPNP.new()
	var err := upnp.discover(DISCOVER_MS, 2, "")
	var result := {"state": "failed", "external": "", "port": port, "reason": ""}
	if err != UPNP.UPNP_RESULT_SUCCESS or upnp.get_gateway() == null or not upnp.get_gateway().is_valid_gateway():
		result.reason = "no router answered (UPnP is off or not supported)"
	else:
		var map := upnp.add_port_mapping(port, port, DESCRIPTION, "UDP", 0)
		var external := upnp.query_external_address()
		result.external = external
		if map != UPNP.UPNP_RESULT_SUCCESS:
			result.reason = "the router would not open port %d" % port
		elif external == "":
			result.reason = "the router did not give its internet address"
		elif shared_address(external):
			result.reason = "your internet provider shares one address between homes (CGNAT)"
		else:
			result.state = "open"
	_finish_open.call_deferred(upnp, result)


func _finish_open(upnp: UPNP, result: Dictionary) -> void:
	_busy()
	if result.state == "open":
		_upnp = upnp
		_mapped_port = int(result.port)
	if info.state != "opening":  # the session ended while the router was asked
		if _mapped_port != 0:
			close_now()
		return
	_set_info(result)


func close_now() -> void:
	if _upnp and _mapped_port != 0:
		_upnp.delete_port_mapping(_mapped_port, "UDP")
	_mapped_port = 0


func _close_work(port: int) -> void:
	if _upnp:
		_upnp.delete_port_mapping(port, "UDP")


func _set_info(new_info: Dictionary) -> void:
	info = new_info
	changed.emit(info.duplicate())


## Addresses that can't be reached from the internet: private, carrier-grade NAT, loopback.
static func shared_address(ip: String) -> bool:
	var p := ip.split(".")
	if p.size() != 4:
		return false
	var a := int(p[0])
	var b := int(p[1])
	return a == 10 or a == 127 or (a == 100 and b >= 64 and b <= 127) \
			or (a == 172 and b >= 16 and b <= 31) or (a == 192 and b == 168)
