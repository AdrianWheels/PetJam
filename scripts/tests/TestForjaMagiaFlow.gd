extends Node
## 🧪 Test: Verifica el flujo completo de forjamagia per-hit
## Ejecutar: godot --headless --path <project> res://scenes/tests/TestForjaMagiaFlow.tscn
## Resultados se guardan en user://test_results.txt y se muestran por consola

var _cm: Node  # CraftingManager
var _pass_count := 0
var _fail_count := 0
var _test_log: Array[String] = []
var _output_path := "res://test_results.txt"

func _ready() -> void:
	_log("\n" + "=".repeat(60))
	_log("🧪 TEST: ForjaMagia Per-Hit Flow")
	_log("=".repeat(60))
	
	# Buscar CraftingManager
	_cm = get_node_or_null("/root/CraftingManager")
	if not _cm:
		_fail("CraftingManager not found as autoload")
		_print_results()
		_save_and_quit()
		return
	_pass("CraftingManager found")
	
	# Test 1: add_forjamagia exists and works
	_test_add_forjamagia()
	
	# Test 2: Signal emitted on forjamagia change
	_test_signal_emission()
	
	# Test 3: Simulate per-hit sequence
	_test_per_hit_sequence()
	
	# Test 4: Verify hit_scored signal exists on MinigameBase
	_test_hit_scored_signal()
	
	# Print results
	_print_results()
	_save_and_quit()


func _test_add_forjamagia() -> void:
	_log("\n--- Test: add_forjamagia ---")
	
	if not _cm.has_method("add_forjamagia"):
		_fail("CraftingManager.add_forjamagia() not found")
		return
	_pass("add_forjamagia() method exists")
	
	# Save current value
	var before: int = _cm.forjamagia
	
	# Add positive
	_cm.add_forjamagia(5)
	var after: int = _cm.forjamagia
	if after == before + 5:
		_pass("add_forjamagia(5): %d → %d" % [before, after])
	else:
		_fail("add_forjamagia(5): expected %d, got %d" % [before + 5, after])
	
	# Add negative
	var before2: int = _cm.forjamagia
	_cm.add_forjamagia(-2)
	var after2: int = _cm.forjamagia
	if after2 == before2 - 2:
		_pass("add_forjamagia(-2): %d → %d" % [before2, after2])
	else:
		_fail("add_forjamagia(-2): expected %d, got %d" % [before2 - 2, after2])
	
	# Reset for next tests
	_cm.reset_forjamagia()
	if _cm.forjamagia == 0:
		_pass("reset_forjamagia(): value is 0")
	else:
		_fail("reset_forjamagia(): expected 0, got %d" % _cm.forjamagia)


func _test_signal_emission() -> void:
	_log("\n--- Test: forjamagia_changed signal ---")
	
	if not _cm.has_signal("forjamagia_changed"):
		_fail("forjamagia_changed signal not found")
		return
	_pass("forjamagia_changed signal exists")
	
	_cm.reset_forjamagia()
	var signal_received := [false]
	var received_value := [0]
	var received_max := [0]
	
	var callback := func(val: int, max_val: int):
		signal_received[0] = true
		received_value[0] = val
		received_max[0] = max_val
	
	_cm.forjamagia_changed.connect(callback)
	_cm.add_forjamagia(3)
	
	# Signal should fire synchronously in Godot
	if signal_received[0]:
		_pass("Signal received after add_forjamagia(3)")
		_pass("  value=%d, max=%d" % [received_value[0], received_max[0]])
	else:
		_fail("Signal NOT received after add_forjamagia(3)")
	
	_cm.forjamagia_changed.disconnect(callback)
	_cm.reset_forjamagia()


func _test_per_hit_sequence() -> void:
	_log("\n--- Test: Per-Hit Sequence Simulation ---")
	
	_cm.reset_forjamagia()
	var initial: int = _cm.forjamagia
	
	# Simulate a Forge trial with 3 hits:
	# Hit 1: Perfect → +3
	# Hit 2: Good → +1
	# Hit 3: Miss → -1
	# Expected total: +3
	
	var hits := [
		{"quality": "Perfect", "delta": 3},
		{"quality": "Good", "delta": 1},
		{"quality": "Miss", "delta": -1},
	]
	
	var expected: int = initial
	for i in range(hits.size()):
		var hit = hits[i]
		expected += hit.delta
		_cm.add_forjamagia(hit.delta)
		var actual: int = _cm.forjamagia
		if actual == expected:
			_pass("Hit %d (%s, delta=%+d): fm=%d" % [
				i + 1, hit.quality, hit.delta, actual])
		else:
			_fail("Hit %d (%s): expected %d, got %d" % [
				i + 1, hit.quality, expected, actual])
	
	var final_expected: int = initial + 3  # 3+1-1 = 3
	if _cm.forjamagia == final_expected:
		_pass("Final forjamagia after 3 hits: %d" % _cm.forjamagia)
	else:
		_fail("Final forjamagia: expected %d, got %d" % [
			final_expected, _cm.forjamagia])
	
	_cm.reset_forjamagia()


func _test_hit_scored_signal() -> void:
	_log("\n--- Test: hit_scored signal in MinigameBase ---")
	
	# Load MinigameBase script and check for signal
	var mb_script: GDScript = load(
		"res://scripts/core/MinigameBase.gd")
	if mb_script == null:
		_fail("Could not load MinigameBase.gd")
		return
	_pass("MinigameBase.gd loaded")
	
	# Check signal list
	var signals := mb_script.get_script_signal_list()
	var found := false
	for sig in signals:
		if sig.name == "hit_scored":
			found = true
			_pass("hit_scored signal found in MinigameBase")
			var args = sig.args
			if args.size() == 2:
				_pass("hit_scored has 2 args (quality, points)")
			else:
				_fail("hit_scored has %d args (expected 2)" % args.size())
			break
	
	if not found:
		_fail("hit_scored signal NOT found in MinigameBase")


func _log(msg: String) -> void:
	print(msg)
	_test_log.append(msg)


func _pass(msg: String) -> void:
	_pass_count += 1
	var line := "  PASS: %s" % msg
	_log(line)


func _fail(msg: String) -> void:
	_fail_count += 1
	var line := "  FAIL: %s" % msg
	_log(line)


func _print_results() -> void:
	var total := _pass_count + _fail_count
	_log("\n" + "=".repeat(60))
	_log("RESULTS: %d/%d passed" % [_pass_count, total])
	if _fail_count == 0:
		_log("ALL TESTS PASSED!")
	else:
		_log("%d FAILURES" % _fail_count)
	_log("=".repeat(60))


func _save_and_quit() -> void:
	# Write results to file
	var file := FileAccess.open(_output_path, FileAccess.WRITE)
	if file:
		for line in _test_log:
			file.store_line(line)
		file.close()
		print("Results saved to: %s" % ProjectSettings.globalize_path(
			_output_path))
	
	# Quit the engine
	await get_tree().create_timer(0.1).timeout
	get_tree().quit(0 if _fail_count == 0 else 1)
