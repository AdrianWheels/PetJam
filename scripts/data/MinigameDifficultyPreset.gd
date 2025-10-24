extends Resource
class_name MinigameDifficultyPreset

## Preset de dificultad configurable por tier para minijuegos
## Uso: define difficulty_budget (0-100) y distribúyelo entre minijuegos

@export_group("Tier Configuration")
@export_enum("Común:1", "Raro:2", "Legendario:3") var tier: int = 1
@export_range(0.0, 100.0, 1.0) var difficulty_budget: float = 50.0

@export_group("Minigame Shares")
@export_range(0.0, 1.0, 0.05) var temp_share: float = 0.25
@export_range(0.0, 1.0, 0.05) var hammer_share: float = 0.25
@export_range(0.0, 1.0, 0.05) var sew_share: float = 0.25
@export_range(0.0, 1.0, 0.05) var quench_share: float = 0.25

## Genera configuración para minijuego de Temperatura
func get_temp_config() -> Dictionary:
	var local_diff = difficulty_budget * temp_share
	return {
		"hardness": remap(local_diff, 0, 100, 0.2, 0.875),
		"precision": remap(local_diff, 0, 100, 0.6, 0.1),
		"temp_window_base": remap(local_diff, 0, 100, 100, 60)
	}

## Genera configuración para minijuego de Martillo
func get_hammer_config() -> Dictionary:
	var local_diff = difficulty_budget * hammer_share
	return {
		"tempo_bpm": remap(local_diff, 0, 100, 70, 180),
		"precision": remap(local_diff, 0, 100, 0.3, 0.9),
		"weight": 0.5,  # Neutro por defecto
		"notes": int(remap(local_diff, 0, 100, 4, 8))
	}

## Genera configuración para minijuego de Coser
func get_sew_config() -> Dictionary:
	var local_diff = difficulty_budget * sew_share
	return {
		"stitch_speed": remap(local_diff, 0, 100, 0.7, 1.7),
		"precision": remap(local_diff, 0, 100, 0.5, 0.1),
		"agility": remap(local_diff, 0, 100, 0.4, 0.0)
	}

## Genera configuración para minijuego de Temple
func get_quench_config() -> Dictionary:
	var local_diff = difficulty_budget * quench_share
	var window_size = remap(local_diff, 0, 100, 80, 15)
	return {
		"cool_rate": remap(local_diff, 0, 100, 0.25, 0.85),
		"catalyst": local_diff < 50,  # Solo en dificultades bajas
		"intelligence": remap(local_diff, 0, 100, 0.5, 0.0),
		"temp_low": 550,
		"temp_high": 550 + window_size
	}

## Genera configuración completa para todos los minijuegos
func get_all_configs() -> Dictionary:
	return {
		"temp": get_temp_config(),
		"hammer": get_hammer_config(),
		"sew": get_sew_config(),
		"quench": get_quench_config()
	}

## Crea preset común
static func create_common() -> MinigameDifficultyPreset:
	var preset := MinigameDifficultyPreset.new()
	preset.tier = 1
	preset.difficulty_budget = 30.0
	preset.temp_share = 0.25
	preset.hammer_share = 0.25
	preset.sew_share = 0.25
	preset.quench_share = 0.25
	return preset

## Crea preset raro
static func create_rare() -> MinigameDifficultyPreset:
	var preset := MinigameDifficultyPreset.new()
	preset.tier = 2
	preset.difficulty_budget = 60.0
	preset.temp_share = 0.3
	preset.hammer_share = 0.3
	preset.sew_share = 0.2
	preset.quench_share = 0.2
	return preset

## Crea preset legendario
static func create_legendary() -> MinigameDifficultyPreset:
	var preset := MinigameDifficultyPreset.new()
	preset.tier = 3
	preset.difficulty_budget = 90.0
	preset.temp_share = 0.35
	preset.hammer_share = 0.35
	preset.sew_share = 0.15
	preset.quench_share = 0.15
	return preset
