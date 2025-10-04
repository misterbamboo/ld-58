extends Node

var _subscribers: Dictionary = {}

func publish(topic: String, data: Dictionary = {}) -> void:
	print("[MessageBus] Published: ", topic, " | Data: ", data)

	if not _subscribers.has(topic):
		return

	for callback in _subscribers[topic]:
		callback.call(data)

func subscribe(topic: String, callback: Callable) -> void:
	if not _subscribers.has(topic):
		_subscribers[topic] = []

	if not _subscribers[topic].has(callback):
		_subscribers[topic].append(callback)

func unsubscribe(topic: String, callback: Callable) -> void:
	if not _subscribers.has(topic):
		return

	_subscribers[topic].erase(callback)

	if _subscribers[topic].is_empty():
		_subscribers.erase(topic)
