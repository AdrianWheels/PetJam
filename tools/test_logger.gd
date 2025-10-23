extends SceneTree

# Test Logger API: call info/debug/trace and give the flush timer a moment.
func _ready() -> void:
    var logger = preload("res://scripts/autoload/Logger.gd").new()
    # Manually initialize logger (avoid needing it attached to tree)
    logger._ready()
    logger.info("test info", {"phase":"start"})
    logger.debug("test debug", {"x": 1})
    logger.trace("test_event", {"score": 42})
    # wait a bit then force flush
    await create_timer(0.3).timeout
    logger.flush_now()
    print("TEST_DONE")
    quit()
