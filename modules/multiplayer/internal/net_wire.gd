extends Node
## The RPC surface of a NetSession. It sits at the same path under every session's own
## SceneMultiplayer root, so calls line up between peers; each call is passed straight to
## the session. "authority" calls only come from the host.

var session: NetSession


# Peer -> host.

@rpc("any_peer", "call_remote", "reliable")
func hello(info: Dictionary) -> void:
	session._on_hello(multiplayer.get_remote_sender_id(), info)


@rpc("any_peer", "call_remote", "reliable")
func request(event_name: String, payload: Dictionary) -> void:
	session._on_request(multiplayer.get_remote_sender_id(), event_name, payload)


@rpc("any_peer", "call_remote", "unreliable", 1)
func ping(t_client: float) -> void:
	session._on_ping(multiplayer.get_remote_sender_id(), t_client)


# Host -> peer.

@rpc("authority", "call_remote", "reliable")
func welcome(peers: Dictionary, seq: int, snapshot: Dictionary) -> void:
	session._on_welcome(peers, seq, snapshot)


@rpc("authority", "call_remote", "reliable")
func refused(reason: String) -> void:
	session._on_refused(reason)


@rpc("authority", "call_remote", "reliable")
func event(seq: int, event_name: String, payload: Dictionary) -> void:
	session._on_event(seq, event_name, payload)


@rpc("authority", "call_remote", "reliable")
func rejected(event_name: String, reason: String) -> void:
	session._on_rejected(event_name, reason)


@rpc("authority", "call_remote", "reliable")
func peer_added(id: int, profile: Dictionary) -> void:
	session._on_peer_added(id, profile)


@rpc("authority", "call_remote", "reliable")
func peer_removed(id: int, reason: String) -> void:
	session._on_peer_removed(id, reason)


@rpc("authority", "call_remote", "unreliable", 1)
func pong(t_client: float, t_host: float) -> void:
	session._on_pong(t_client, t_host)
