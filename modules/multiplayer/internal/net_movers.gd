class_name NetMovers
extends RefCounted
## Continuous state for a NetSession: things that move every frame (a unit in a tractor beam,
## a hover trolley, the picking lift, avatars later). Whoever has authority over a mover sends
## its transform SEND_RATE times a second, stamped with the host clock; everyone else plays
## the samples back DELAY seconds behind, interpolated, so motion stays smooth through jitter.
## Ids are data ids, the same on every peer; each peer registers its own node under the id.

const SEND_RATE := 20.0
const DELAY := 0.1
const BUFFER := 12
## A mover that stands still is sent again this often, so a late sample can't be the last.
const KEEPALIVE := 1.0
## A sample this far behind the newest one means the sender's clock was put right: start over.
const CLOCK_JUMP := 1.0

var _nodes: Dictionary = {}  # id -> Node3D
var _samples: Dictionary = {}  # id -> Array of [time, Transform3D], oldest first
var _pending: Dictionary = {}  # id -> Transform3D from a join snapshot, before the node exists
var _sent: Dictionary = {}  # id -> [time, Transform3D] last sent


func register(id: String, node: Node3D) -> void:
	_nodes[id] = node
	_samples.erase(id)
	if _pending.has(id) and node.is_inside_tree():
		node.global_transform = _pending[id]
	_pending.erase(id)


func unregister(id: String) -> void:
	_nodes.erase(id)
	_samples.erase(id)
	_sent.erase(id)


func has(id: String) -> bool:
	return _nodes.has(id)


## Forget buffered motion, for when authority over the mover changes hands.
func clear(id: String) -> void:
	_samples.erase(id)


## Transforms of the movers this peer has authority over that moved since they were last
## sent, or stood still for KEEPALIVE: id -> Transform3D. `now` is the host clock.
func outgoing(is_mine: Callable, now: float) -> Dictionary:
	var out := {}
	for id in _nodes:
		var node: Node3D = _nodes[id]
		if not is_instance_valid(node) or not node.is_inside_tree() or not is_mine.call(id):
			continue
		var at := node.global_transform
		var last: Array = _sent.get(id, [])
		if not last.is_empty() and now - float(last[0]) < KEEPALIVE and (last[1] as Transform3D).is_equal_approx(at):
			continue
		_sent[id] = [now, at]
		out[id] = at
	return out


## Buffers the samples `accept(id)` allows and returns them, for a host to relay on.
func receive(t: float, batch: Dictionary, accept: Callable) -> Dictionary:
	var taken := {}
	for id in batch:
		if not batch[id] is Transform3D or not accept.call(id):
			continue
		var list: Array = _samples.get(id, [])
		if not list.is_empty() and t <= list.back()[0]:
			if float(list.back()[0]) - t < CLOCK_JUMP:
				continue
			list = []
		list.append([t, batch[id]])
		if list.size() > BUFFER:
			list.pop_front()
		_samples[id] = list
		taken[id] = batch[id]
	return taken


## Moves every mover this peer does not drive to where it was at `render_t`.
func play_back(render_t: float, is_mine: Callable) -> void:
	for id in _samples:
		var node: Node3D = _nodes.get(id)
		if not is_instance_valid(node) or not node.is_inside_tree() or is_mine.call(id):
			continue
		node.global_transform = sample_at(_samples[id], render_t)


func snapshot() -> Dictionary:
	var out := {}
	for id in _nodes:
		var node: Node3D = _nodes[id]
		if is_instance_valid(node) and node.is_inside_tree():
			out[id] = node.global_transform
	return out


func apply_snapshot(data: Dictionary) -> void:
	for id in data:
		if not data[id] is Transform3D:
			continue
		var node: Node3D = _nodes.get(id)
		if is_instance_valid(node) and node.is_inside_tree():
			node.global_transform = data[id]
		else:
			_pending[id] = data[id]


## The transform at time t from samples [[time, Transform3D], ...]: interpolated between
## the two around t, held at the ends (no guessing ahead of the last sample).
static func sample_at(list: Array, t: float) -> Transform3D:
	if t <= list[0][0]:
		return list[0][1]
	for i in range(1, list.size()):
		var b: Array = list[i]
		if t <= b[0]:
			var a: Array = list[i - 1]
			var t0: float = a[0]
			var f := (t - t0) / maxf(float(b[0]) - t0, 0.0001)
			return (a[1] as Transform3D).interpolate_with(b[1], f)
	return list.back()[1]
