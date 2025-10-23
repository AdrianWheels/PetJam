extends Node

class_name DataManager

signal data_ready

var materials: Dictionary = {}
var blueprints: Dictionary[StringName, BlueprintResource] = {}
var tuning: Dictionary = {}

const BLUEPRINT_LIBRARY_PATH := "res://data/blueprints/BlueprintLibrary.tres"

func _load_json_file(path: String) -> Dictionary:
    var out := {"ok": false, "result": null, "error": null}
    # Try multiple candidate paths: the provided path and its globalized version
    var candidates := []
    candidates.append(path)
    if path.begins_with("res://"):
        candidates.append(ProjectSettings.globalize_path(path))
    else:
        # also try to treat as res:// if a resource exists
        var res_path := "res://data/" + path.get_file()
        candidates.append(res_path)
        candidates.append(ProjectSettings.globalize_path(res_path))

    var file_path: String = ""
    for c in candidates:
        if c == null:
            continue
        print("DataManager: candidate path %s exists=%s" % [str(c), str(FileAccess.file_exists(c))])
        if FileAccess.file_exists(c):
            file_path = c
            break

    if file_path == "":
        out.error = ERR_DOES_NOT_EXIST
        _write_json_debug_log(path, "", out.error, null)
        return out

    print("DataManager: selected file_path = %s" % file_path)
    # Diagnostic: show alternative backslash path
    var alt_path := file_path.replace("/", "\\")
    print("DataManager: alt_path = %s" % alt_path)
    # Read file robustly
    var raw_text := FileAccess.get_file_as_string(file_path)
    if raw_text == null:
        # try alternative path with backslashes
        print("DataManager: primary read returned null, trying alt_path")
        raw_text = FileAccess.get_file_as_string(alt_path)
    if raw_text == null:
        out.error = ERR_CANT_OPEN
        print("DataManager: get_file_as_string returned null for %s and %s" % [file_path, alt_path])
        _write_json_debug_log(file_path, "", out.error, null)
        return out
    print("DataManager: raw_text length for %s = %d" % [file_path, raw_text.length()])
    if raw_text == "":
        out.error = ERR_INVALID_DATA
        _write_json_debug_log(file_path, raw_text, out.error, null)
        return out

    var parse_res = JSON.parse_string(raw_text)

    # Diagnostic: log the raw parse result and type so we can trace err codes in runtime log
    if has_node('/root/Logger'):
        var repr := str(parse_res)
        var ptype := typeof(parse_res)
        get_node('/root/Logger').info("DataManager: parse_res_debug", {"path": file_path, "type": ptype, "repr": repr})
    # JSON.parse_string may return a Dictionary (older style) or a JSONParseResult object
    if typeof(parse_res) == TYPE_DICTIONARY:
        var err: int = int(parse_res.get("error", ERR_PARSE_ERROR))
        if err == OK:
            out.ok = true
            out.result = parse_res.get("result")
        else:
            out.error = err
    else:
        # Assume JSONParseResult-like object with .error and .result
        if typeof(parse_res) != TYPE_NIL and parse_res.error == OK:
            out.ok = true
            out.result = parse_res.result
        else:
            out.error = (parse_res.error if typeof(parse_res) != TYPE_NIL else ERR_PARSE_ERROR)

    # Defensive fallback: if parsing did not mark success, attempt a second parse and accept a direct Dictionary
    if not out.ok:
        if has_node('/root/Logger'):
            get_node('/root/Logger').info("DataManager: parse_fallback_attempt", {"path": file_path})
        var alt = JSON.parse_string(raw_text)
        if typeof(alt) == TYPE_DICTIONARY:
            out.ok = true
            out.result = alt
            if has_node('/root/Logger'):
                get_node('/root/Logger').info("DataManager: parse_fallback_used", {"path": file_path, "keys": out.result.keys()})

    return out


func _write_json_debug_log(path: String, raw_text: String, err_code: int, parse_res: Variant) -> void:
    var safe_name := path.get_file().replace(".", "_")
    var user_logs_dir := ProjectSettings.globalize_path("user://logs")
    DirAccess.make_dir_recursive_absolute(user_logs_dir)
    var user_log_path: String = user_logs_dir + "/datamanager_debug_%s.log" % safe_name

    var sb: String = ""
    sb += "Path: %s\n" % path
    sb += "Error code: %s\n" % str(err_code)
    sb += "Raw length: %s\n" % str(raw_text.length())
    sb += "--- Raw preview (512 chars) ---\n"
    sb += raw_text.substr(0, min(raw_text.length(), 512)) + "\n"
    sb += "--- End preview ---\n"
    sb += "Parse result repr: %s\n" % str(parse_res)

    # Write debug log to user://logs
    var fuser := FileAccess.open(user_log_path, FileAccess.ModeFlags.WRITE)
    if fuser:
        fuser.store_string(sb)
        fuser.close()
    else:
        push_error("DataManager: failed to write debug log to %s" % user_log_path)

func _ready() -> void:
    print("DataManager: Initializing...")
    var timer := Timer.new()
    timer.one_shot = true
    timer.wait_time = 0.05
    add_child(timer)
    timer.timeout.connect(_load_data)
    timer.start()

func _load_data() -> void:
    print("DataManager: Loading data from JSON files...")
    var mat_file := "res://data/materials.json"
    var tune_file := "res://data/tuning.json"

    print("DataManager: will try res paths: %s, %s" % [mat_file, tune_file])

    var mat_load := _load_json_file(mat_file)
    if mat_load.ok:
        if typeof(mat_load.result) == TYPE_DICTIONARY:
            materials = mat_load.result
            print("DataManager: Loaded materials.json successfully (%d items)" % materials.size())
            if has_node('/root/Logger'):
                get_node('/root/Logger').info("Loaded materials.json", {"items": materials.size()})
        else:
            push_error("DataManager: materials.json parsed but root is not a Dictionary")
    else:
        push_error("DataManager: failed to load materials.json (err=%s)" % str(mat_load.error))
        if has_node('/root/Logger'):
            get_node('/root/Logger').error("Failed to load materials.json", {"err": mat_load.error})

    _load_blueprint_library()

    var tune_load := _load_json_file(tune_file)
    if tune_load.ok:
        if typeof(tune_load.result) == TYPE_DICTIONARY:
            tuning = tune_load.result
            print("DataManager: Loaded tuning.json successfully (%d items)" % tuning.size())
            if has_node('/root/Logger'):
                get_node('/root/Logger').info("Loaded tuning.json", {"items": tuning.size()})
        else:
            push_error("DataManager: tuning.json parsed but root is not a Dictionary")
    else:
        push_error("DataManager: failed to load tuning.json (err=%s)" % str(tune_load.error))
        if has_node('/root/Logger'):
            get_node('/root/Logger').error("Failed to load tuning.json", {"err": tune_load.error})

    print("DataManager: Data loading complete.")

    # Notify listeners that data is ready
    emit_signal("data_ready")

func get_material(id: String):
    var result = materials.get(id, null)
    if result == null:
        print("DataManager: Material '%s' not found" % id)
    else:
        print("DataManager: Retrieved material '%s'" % id)
    return result

func _load_blueprint_library() -> void:
    var res := ResourceLoader.load(BLUEPRINT_LIBRARY_PATH)
    if res == null:
        push_error("DataManager: failed to load blueprint library at %s" % BLUEPRINT_LIBRARY_PATH)
        if has_node('/root/Logger'):
            get_node('/root/Logger').error("Failed to load blueprint library", {"path": BLUEPRINT_LIBRARY_PATH})
        return

    if not (res is BlueprintLibrary):
        push_error("DataManager: resource at %s is not a BlueprintLibrary" % BLUEPRINT_LIBRARY_PATH)
        return

    blueprints.clear()
    for blueprint in res.blueprints:
        if blueprint == null:
            continue
        if not (blueprint is BlueprintResource):
            push_error("DataManager: blueprint entry %s is not BlueprintResource" % str(blueprint))
            continue
        var key: StringName = blueprint.blueprint_id if blueprint.blueprint_id != StringName() else StringName(blueprint.resource_name)
        if key == StringName():
            push_error("DataManager: blueprint without id %s" % blueprint)
            continue
        blueprints[key] = blueprint

    print("DataManager: Loaded blueprint library successfully (%d items)" % blueprints.size())
    if has_node('/root/Logger'):
        get_node('/root/Logger').info("Loaded blueprint library", {"items": blueprints.size(), "path": BLUEPRINT_LIBRARY_PATH})


func get_blueprint(id: StringName) -> BlueprintResource:
    var result: BlueprintResource = blueprints.get(id, null)
    if result == null:
        print("DataManager: Blueprint '%s' not found" % String(id))
    else:
        print("DataManager: Retrieved blueprint '%s'" % String(id))
    return result

func get_blueprints() -> Dictionary[StringName, BlueprintResource]:
    return blueprints
