extends Node

class_name TelemetryManager

var logs: Array = []
var _telemetry_log_path: String = ""
var trial_aggregates := {}

func log_event(event: String, data: Dictionary = {}):
	var rec := {"event": event, "data": data, "timestamp": Time.get_unix_time_from_system()}
	logs.append(rec)
	print("[Telemetry] %s: %s" % [event, data])
	# Persist immediately to user://telemetry.log (append JSON-line)
	var ok := _append_telemetry_to_disk(rec)
	if not ok:
		push_warning("TelemetryManager: failed to persist event to disk")

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
	# prepare user:// telemetry log path and ensure directory
	_telemetry_log_path = ProjectSettings.globalize_path("user://telemetry.log")
	var dir := _telemetry_log_path.get_base_dir()
	DirAccess.make_dir_recursive_absolute(dir)

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

func record_trial(blueprint_id, trial_id, result: TrialResult) -> void:
        var bp_id := StringName(str(blueprint_id))
        var tr_id := StringName(str(trial_id))
        var key := "%s::%s" % [String(bp_id), String(tr_id)]
        if not trial_aggregates.has(key):
                trial_aggregates[key] = {
                        "blueprint_id": bp_id,
                        "trial_id": tr_id,
                        "attempts": 0,
                        "successes": 0,
                        "best_score": -INF,
                        "last_result": null
                }
        var entry: Dictionary = trial_aggregates[key]
        entry["attempts"] += 1
        if result and result.success:
                entry["successes"] += 1
        if result:
                entry["best_score"] = max(entry["best_score"], result.score)
                entry["last_result"] = result
        trial_aggregates[key] = entry
        log_event("trial_recorded", {
                "blueprint_id": String(bp_id),
                "trial_id": String(tr_id),
                "score": result.score if result else 0,
                "max_score": result.max_score if result else 0,
                "success": result.success if result else false
        })

func export_metrics(path: String = "user://run_metrics.json") -> bool:
	# Ensure path is under user:// to avoid writing into res://
	if not path.begins_with("user://"):
		push_warning("TelemetryManager.export_metrics: path must be user://, forcing to user://")
		var fname := path.get_file()
		path = "user://%s" % fname

	var dir := ProjectSettings.globalize_path(path).get_base_dir()
	DirAccess.make_dir_recursive_absolute(dir)

	var abs_path := ProjectSettings.globalize_path(path)
	var f := FileAccess.open(abs_path, FileAccess.ModeFlags.WRITE)
	if f == null:
		print("TelemetryManager: Failed to open file for export: %s" % abs_path)
		return false
	f.store_string(JSON.stringify(metrics))
	f.close()
	print("TelemetryManager: Exported metrics to %s" % abs_path)
	return true


func _append_telemetry_to_disk(record: Dictionary) -> bool:
	# Writes one JSON-line to user://telemetry.log (creates directory if needed)
	if _telemetry_log_path == "":
		_telemetry_log_path = ProjectSettings.globalize_path("user://telemetry.log")
		DirAccess.make_dir_recursive_absolute(_telemetry_log_path.get_base_dir())

	var line := JSON.stringify(record, "") + "\n"
	var target := _telemetry_log_path
	var f := FileAccess.open(target, FileAccess.ModeFlags.WRITE_READ)
	if not f:
		f = FileAccess.open(target, FileAccess.ModeFlags.WRITE)
	if not f:
		return false
	f.seek_end()
	f.store_string(line)
	f.close()
	return true
