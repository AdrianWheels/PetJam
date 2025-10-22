extends Node

class_name TelemetryManager

var logs: Array = []

func log_event(event: String, data: Dictionary = {}):
	logs.append({"event": event, "data": data, "timestamp": Time.get_unix_time_from_system()})
	print("[Telemetry] %s: %s" % [event, data])

func get_events():
	return logs

func clear():
	logs.clear()

var metrics := {
    "perfect": 0,
    "good": 0,
    "regular": 0,
    "miss": 0,
    "rooms_cleared": 0,
    "hero_deaths": 0
}

func _ready() -> void:
	print("TelemetryManager ready")

func record_judgement(result: String) -> void:
	if metrics.has(result):
		metrics[result] += 1
	else:
		metrics[result] = 1
	print("TelemetryManager: Recorded judgement '%s' (total: %d)" % [result, metrics[result]])

func record_room_cleared() -> void:
	metrics["rooms_cleared"] += 1
	print("TelemetryManager: Recorded room cleared (total: %d)" % metrics["rooms_cleared"])

func record_hero_death() -> void:
	metrics["hero_deaths"] += 1
	print("TelemetryManager: Recorded hero death (total: %d)" % metrics["hero_deaths"])

func export_metrics(path: String = "user://run_metrics.json") -> bool:
	var f := FileAccess.open(path, FileAccess.ModeFlags.WRITE)
	if f == null:
		print("TelemetryManager: Failed to open file for export: %s" % path)
		return false
	f.store_string(JSON.stringify(metrics))
	f.close()
	print("TelemetryManager: Exported metrics to %s" % path)
	return true
