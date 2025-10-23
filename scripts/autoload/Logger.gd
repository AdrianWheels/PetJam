extends Node

# Note: avoid class_name Logger to not hide native class

enum Level { DEBUG, INFO, WARN, ERROR }

var level: int = Level.INFO
var to_file: bool = true
var to_stdout: bool = true
var flush_interval_ms: int = 250
var max_size_kb: int = 512

var _buffer: Array = []
var _flush_timer = null

func _ready() -> void:
	# Load defaults from ProjectSettings if present
	level = int(ProjectSettings.get_setting("application/log/level", level))
	to_file = bool(ProjectSettings.get_setting("application/log/to_file", to_file))
	to_stdout = bool(ProjectSettings.get_setting("application/log/to_stdout", to_stdout))
	flush_interval_ms = int(ProjectSettings.get_setting("application/log/flush_interval_ms", flush_interval_ms))
	max_size_kb = int(ProjectSettings.get_setting("application/log/max_size_kb", max_size_kb))

	# Ensure logs directory exists
	var logs_dir := ProjectSettings.globalize_path("user://logs")
	DirAccess.make_dir_recursive_absolute(logs_dir)

	# Create and start a Timer for periodic flush
	_flush_timer = Timer.new()
	_flush_timer.wait_time = float(flush_interval_ms) / 1000.0
	_flush_timer.one_shot = false
	_flush_timer.autostart = true
	add_child(_flush_timer)
	_flush_timer.timeout.connect(Callable(self, "_on_flush_timer"))

	print("Logger: ready (to_file=%s, to_stdout=%s, level=%d)" % [to_file, to_stdout, level])

func set_level(new_level: int) -> void:
	level = new_level

func debug(msg: String, ctx: Dictionary = {}) -> void:
	if level <= Level.DEBUG:
		_enqueue(Level.DEBUG, msg, ctx)

func info(msg: String, ctx: Dictionary = {}) -> void:
	if level <= Level.INFO:
		_enqueue(Level.INFO, msg, ctx)

func warn(msg: String, ctx: Dictionary = {}) -> void:
	if level <= Level.WARN:
		_enqueue(Level.WARN, msg, ctx)

func error(msg: String, ctx: Dictionary = {}) -> void:
	if level <= Level.ERROR:
		_enqueue(Level.ERROR, msg, ctx)

func trace(event: String, data: Dictionary = {}, lvl: int = Level.INFO) -> void:
	# JSON-line for telemetry
	var ts := _format_timestamp(Time.get_time_dict_from_system())
	var record := {"ts": ts, "event": event, "data": data, "lvl": lvl}
	var json := JSON.stringify(record, "")
	_buffer.append(json + "\n")
	if to_stdout:
		print(json)

func flush_now() -> void:
	if _buffer.size() == 0:
		return
	var logs_dir := ProjectSettings.globalize_path("user://logs")
	DirAccess.make_dir_recursive_absolute(logs_dir)
	var d := Time.get_time_dict_from_system()
	var td := _extract_time_components(d)
	var date_str := "%04d%02d%02d" % [td.get("year", 0), td.get("month", 0), td.get("day", 0)]
	var base_path := logs_dir + "/app-%s.log" % date_str

	var target := _choose_log_file(base_path)

	var sb := "".join(_buffer)
	var f := FileAccess.open(target, FileAccess.ModeFlags.WRITE_READ)
	if not f:
		# try create
		f = FileAccess.open(target, FileAccess.ModeFlags.WRITE)
	if f:
		f.seek_end()
		f.store_string(sb)
		f.close()
	else:
		push_error("Logger: failed to open log file %s" % target)

	_buffer.clear()

func _enqueue(lvl: int, msg: String, ctx: Dictionary) -> void:
	# Format: YYYY-MM-DD HH:MM:SS [LEVEL] message {json_ctx}
	var ts := _format_timestamp(Time.get_time_dict_from_system())
	var lvl_str := _level_to_string(lvl)
	var ctx_part := ""
	if ctx and ctx.size() > 0:
		ctx_part = " " + JSON.stringify(ctx, "")
	var line := "%s [%s] %s%s\n" % [ts, lvl_str, msg, ctx_part]
	_buffer.append(line)

	# optional stdout/stderr
	if to_stdout:
		match lvl:
			Level.DEBUG, Level.INFO:
				print(line)
			Level.WARN:
				push_warning(line)
			Level.ERROR:
				push_error(line)

func _format_timestamp(d: Dictionary) -> String:
	# Accept either a Dictionary or an object; extract components safely
	var td := _extract_time_components(d)
	return "%04d-%02d-%02d %02d:%02d:%02d" % [td.get("year", 0), td.get("month", 0), td.get("day", 0), td.get("hour", 0), td.get("minute", 0), int(td.get("second", 0))]

func _extract_time_components(d: Variant) -> Dictionary:
	var out := {"year": 0, "month": 0, "day": 0, "hour": 0, "minute": 0, "second": 0}
	if typeof(d) == TYPE_DICTIONARY:
		for k in out.keys():
			out[k] = int(d.get(k, 0))
		return out
	# If not a Dictionary, try to read as object with properties
	# Use safe get with hasattr-style checks where available
	# We'll attempt property access and fall back to 0
	# Note: this assumes the object exposes .year etc.
	if d != null:
		# Try to read known keys either via get() or as attributes; guard with typeof checks
		for k in out.keys():
			# try dictionary-style access
			if typeof(d) == TYPE_DICTIONARY:
				out[k] = int(d.get(k, 0))
			else:
				# attribute-style safe access
				var val = null
				if k == "year" and typeof(d.year) != TYPE_NIL:
					val = d.year
				elif k == "month" and typeof(d.month) != TYPE_NIL:
					val = d.month
				elif k == "day" and typeof(d.day) != TYPE_NIL:
					val = d.day
				elif k == "hour" and typeof(d.hour) != TYPE_NIL:
					val = d.hour
				elif k == "minute" and typeof(d.minute) != TYPE_NIL:
					val = d.minute
				elif k == "second" and typeof(d.second) != TYPE_NIL:
					val = d.second
				out[k] = int(val if val != null else 0)
	return out

func _level_to_string(lvl: int) -> String:
	match lvl:
		Level.DEBUG:
			return "DEBUG"
		Level.INFO:
			return "INFO"
		Level.WARN:
			return "WARN"
		Level.ERROR:
			return "ERROR"
	return "INFO"

func _choose_log_file(base_path: String) -> String:
	# If base_path doesn't exceed size limit, return it.
	var max_bytes := int(max_size_kb) * 1024
	if not FileAccess.file_exists(base_path):
		return base_path
	var f := FileAccess.open(base_path, FileAccess.ModeFlags.READ)
	if f:
		var flen := f.get_length()
		f.close()
		if flen < max_bytes:
			return base_path

	# need to find a rotated file
	var idx := 1
	while true:
		var candidate := base_path.get_basename() + "-%d.log" % idx
		# get_basename returns path without extension; we need directory + filename
		# simpler: insert before .log
		var dot := base_path.rfind(".log")
		if dot == -1:
			candidate = base_path + "-%d" % idx
		else:
			candidate = base_path.substr(0, dot) + "-%d.log" % idx
		if not FileAccess.file_exists(candidate):
			return candidate
		var cf := FileAccess.open(candidate, FileAccess.ModeFlags.READ)
		if cf:
			var clen := cf.get_length()
			cf.close()
			if clen < max_bytes:
				return candidate
		idx += 1
	# fallback
	return base_path

func _on_flush_timer() -> void:
	flush_now()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		flush_now()
