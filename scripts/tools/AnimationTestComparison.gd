extends Control
# =====================================================
# AnimationTestComparison.gd
# Escena de prueba para comparar variantes de FPS
# =====================================================

@onready var sprite8: Sprite2D = $GridContainer/Panel8FPS/CenterContainer/Sprite8
@onready var sprite10: Sprite2D = $GridContainer/Panel10FPS/CenterContainer/Sprite10
@onready var sprite12: Sprite2D = $GridContainer/Panel12FPS/CenterContainer/Sprite12
@onready var sprite15: Sprite2D = $GridContainer/Panel15FPS/CenterContainer/Sprite15

@onready var panel8: VBoxContainer = $GridContainer/Panel8FPS
@onready var panel10: VBoxContainer = $GridContainer/Panel10FPS
@onready var panel12: VBoxContainer = $GridContainer/Panel12FPS
@onready var panel15: VBoxContainer = $GridContainer/Panel15FPS

@onready var current_fps_label: Label = $CurrentFPSLabel

# Configuración de cada variante
var animations = {
	"8fps": {"sprite": null, "hframes": 41, "fps": 8, "panel": null, "time_acc": 0.0, "current_frame": 0},
	"10fps": {"sprite": null, "hframes": 51, "fps": 10, "panel": null, "time_acc": 0.0, "current_frame": 0},
	"12fps": {"sprite": null, "hframes": 62, "fps": 12, "panel": null, "time_acc": 0.0, "current_frame": 0},
	"15fps": {"sprite": null, "hframes": 77, "fps": 15, "panel": null, "time_acc": 0.0, "current_frame": 0}
}

var is_playing: bool = true
var show_mode: String = "all"  # "all", "8fps", "10fps", "12fps", "15fps"
var speed_multiplier: float = 1.0  # Multiplicador de velocidad (0.5x - 3.0x)

func _ready() -> void:
	# Asignar referencias
	animations["8fps"]["sprite"] = sprite8
	animations["8fps"]["panel"] = panel8
	animations["10fps"]["sprite"] = sprite10
	animations["10fps"]["panel"] = panel10
	animations["12fps"]["sprite"] = sprite12
	animations["12fps"]["panel"] = panel12
	animations["15fps"]["sprite"] = sprite15
	animations["15fps"]["panel"] = panel15
	
	# Inicializar todos en frame 0
	for anim in animations.values():
		anim["sprite"].frame = 0
		anim["time_acc"] = 0.0
		anim["current_frame"] = 0
	
	update_visibility()
	update_speed_label()
	print("🎬 Comparador de animaciones cargado")
	print("   1-4: Mostrar solo esa variante | 0: Mostrar todas")
	print("   SPACE: Pause/Resume")
	print("   O/P: Disminuir/Aumentar velocidad")

func _process(delta: float) -> void:
	if not is_playing:
		return
	
	# Aplicar multiplicador de velocidad al delta
	var modified_delta = delta * speed_multiplier
	
	# Actualizar cada animación independientemente según su FPS
	for key in animations.keys():
		var anim = animations[key]
		var sprite: Sprite2D = anim["sprite"]
		var frame_time = 1.0 / float(anim["fps"])
		
		# Acumular tiempo específico para esta animación (con velocidad modificada)
		anim["time_acc"] += modified_delta
		
		# Si pasó suficiente tiempo, avanzar frame
		if anim["time_acc"] >= frame_time:
			anim["current_frame"] = (anim["current_frame"] + 1) % anim["hframes"]
			sprite.frame = anim["current_frame"]
			anim["time_acc"] = 0.0

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_SPACE:
				is_playing = !is_playing
				update_speed_label()
			
			KEY_O:
				# Disminuir velocidad (mínimo 0.25x)
				speed_multiplier = max(0.25, speed_multiplier - 0.25)
				update_speed_label()
				print("⏪ Velocidad: %.2fx" % speed_multiplier)
			
			KEY_P:
				# Aumentar velocidad (máximo 3.0x)
				speed_multiplier = min(3.0, speed_multiplier + 0.25)
				update_speed_label()
				print("⏩ Velocidad: %.2fx" % speed_multiplier)
			
			KEY_0:
				show_mode = "all"
				update_visibility()
			
			KEY_1:
				show_mode = "8fps"
				update_visibility()
			
			KEY_2:
				show_mode = "10fps"
				update_visibility()
			
			KEY_3:
				show_mode = "12fps"
				update_visibility()
			
			KEY_4:
				show_mode = "15fps"
				update_visibility()
			
			KEY_ESCAPE:
				get_tree().change_scene_to_file("res://scenes/Main.tscn")

func update_visibility() -> void:
	if show_mode == "all":
		# Mostrar todas en grid 2x2
		panel8.visible = true
		panel10.visible = true
		panel12.visible = true
		panel15.visible = true
	else:
		# Mostrar solo la seleccionada
		panel8.visible = (show_mode == "8fps")
		panel10.visible = (show_mode == "10fps")
		panel12.visible = (show_mode == "12fps")
		panel15.visible = (show_mode == "15fps")
	
	# Reiniciar frames al cambiar modo
	for anim in animations.values():
		anim["sprite"].frame = 0
		anim["time_acc"] = 0.0
		anim["current_frame"] = 0
	
	update_speed_label()

func update_speed_label() -> void:
	var status = ""
	
	if not is_playing:
		status = "⏸ PAUSADO"
	else:
		if show_mode == "all":
			status = "Mostrando: TODAS"
		else:
			var fps_num = show_mode.replace("fps", "")
			status = "Mostrando: " + fps_num + " FPS"
	
	# Agregar velocidad
	if speed_multiplier != 1.0:
		status += " | Velocidad: %.2fx" % speed_multiplier
	
	current_fps_label.text = status
