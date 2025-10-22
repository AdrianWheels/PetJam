extends Node

var materials: Dictionary = {}
var blueprints: Dictionary = {}
var tuning: Dictionary = {}

func _load_json_file(path: String) -> Dictionary:
	"""Safely load and parse a JSON file. Returns a Dictionary with keys:
	- ok: bool
	- result: parsed value or null
	- error: error code or null
	"""
	var out := {"ok": false, "result": null, "error": null}
	if not FileAccess.file_exists(path):
		out.error = ERR_DOES_NOT_EXIST
		return out

	var text := FileAccess.get_file_as_string(path)
	if text == "":
		out.error = ERR_INVALID_DATA
		return out

	var parse_result = JSON.parse_string(text)
	if typeof(parse_result) == TYPE_DICTIONARY:
		var err = parse_result.get("error", ERR_PARSE_ERROR)
		if err == OK:
			out.ok = true
			out.result = parse_result.get("result")
		else:
			out.error = err
	else:
		# JSONParseResult
		if parse_result.error == OK:
			out.ok = true
			out.result = parse_result.result
		else:
			out.error = parse_result.error
	return out

func _write_json_debug_log(path: String, raw_text: String, err_code: int, parse_res: Variant) -> void:
	var safe_name := path.get_file().replace(".", "_")
	var proj_dir := "project://logs"
	# ensure project logs dir exists
	var da := DirAccess.open("project://")
	if da:
		da.make_dir_recursive("logs")
		da.close()

	var proj_log_path := "%s/datamanager_debug_%s.log" % [proj_dir, safe_name]
	var user_log_path := "user://datamanager_debug_%s.log" % safe_name

	var sb: String = ""
	sb += "Path: %s\n" % path
	sb += "Error code: %s\n" % str(err_code)
	sb += "Raw length: %s\n" % str(raw_text.length())
	sb += "--- Raw preview (512 chars) ---\n"
	sb += raw_text.substr(0, min(raw_text.length(), 512)) + "\n"
	sb += "--- End preview ---\n"
	sb += "Parse result repr: %s\n" % str(parse_res)

	# Try write to project logs first
	var fproj := FileAccess.open(proj_log_path, FileAccess.ModeFlags.WRITE)
	if fproj != null:
		fproj.store_string(sb)
		fproj.close()
	else:
		push_error("DataManager: failed to write debug log to %s" % proj_log_path)

	# Also write to user:// as fallback
	var fuser := FileAccess.open(user_log_path, FileAccess.ModeFlags.WRITE)
	if fuser != null:
		fuser.store_string(sb)
		fuser.close()
	else:
		push_error("DataManager: failed to write debug log to %s" % user_log_path)

func _ready() -> void:
	print("DataManager: Initializing...")
	_load_data()

func _load_data() -> void:
	print("DataManager: Loading data from JSON files...")
	var mat_file := "res://data/materials.json"
	var bp_file := "res://data/blueprints.json"
	var tune_file := "res://data/tuning.json"
	var mat_load := _load_json_file(mat_file)
	if mat_load.ok:
		if typeof(mat_load.result) == TYPE_DICTIONARY:
			materials = mat_load.result
			print("DataManager: Loaded materials.json successfully (%d items)" % materials.size())
		else:
			push_error("DataManager: materials.json parsed but root is not a Dictionary")
	else:
		push_error("DataManager: failed to load materials.json (err=%s)" % str(mat_load.error))

	var bp_load := _load_json_file(bp_file)
	if bp_load.ok:
		if typeof(bp_load.result) == TYPE_DICTIONARY:
			blueprints = bp_load.result
			print("DataManager: Loaded blueprints.json successfully (%d items)" % blueprints.size())
		else:
			push_error("DataManager: blueprints.json parsed but root is not a Dictionary")
	else:
		push_error("DataManager: failed to load blueprints.json (err=%s)" % str(bp_load.error))

	var tune_load := _load_json_file(tune_file)
	if tune_load.ok:
		if typeof(tune_load.result) == TYPE_DICTIONARY:
			tuning = tune_load.result
			print("DataManager: Loaded tuning.json successfully (%d items)" % tuning.size())
		else:
			push_error("DataManager: tuning.json parsed but root is not a Dictionary")
	else:
		push_error("DataManager: failed to load tuning.json (err=%s)" % str(tune_load.error))

	print("DataManager: Data loading complete.")

func get_material(id: String):
	var result = materials.get(id, null)
	if result == null:
		print("DataManager: Material '%s' not found" % id)
	else:
		print("DataManager: Retrieved material '%s'" % id)
	return result

func get_blueprint(id: String):
	var result = blueprints.get(id, null)
	if result == null:
		print("DataManager: Blueprint '%s' not found" % id)
	else:
		print("DataManager: Retrieved blueprint '%s'" % id)
	return result

func get_blueprints() -> Dictionary:
	return blueprints
