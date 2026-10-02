extends RefCounted

## Representa un item crafteado con calidad y stats calculados
class_name CraftedItem

## Precio de venta según la calidad (antes en ShopPanel), por el multiplicador de oro de su rango.
const SELL_PRICE_BY_TIER := {"legendary": 500, "epic": 250, "rare": 120, "uncommon": 60, "common": 25}

# Referencias
var item_resource: ItemResource
var quality: float = 0.5  # 0.0 - 1.0 (normalizado)
var calculated_stats: Dictionary = {}

# Metadatos
var crafted_timestamp: int = 0
var rank: int = 1  # rango del plano con que se forjó (1 = rango I)
# Sitio en el inventario (spec del inventario en rejilla, apartado 3). Lo mantiene InventoryManager.
var place: StringName = &"loot"  ## &"hero" (rejilla de Tico), &"bag" (mochila) o &"loot" (botín)
var cell: Vector2i = Vector2i.ZERO  ## esquina de arriba a la izquierda de su caja en la rejilla
var rot: int = 0  ## cuartos de vuelta en el sentido de las agujas del reloj (0-3)
var aristas: Array[Vector2i] = []  ## casillas de más, en coordenadas de la pieza sin girar (PieceShape)

func _init(item_res: ItemResource, craft_quality: float, craft_rank: int = 1) -> void:
	item_resource = item_res
	quality = clampf(craft_quality, 0.0, 1.0)
	rank = maxi(1, craft_rank)
	crafted_timestamp = Time.get_ticks_msec()
	
	if item_resource:
		calculated_stats = Ranks.scale_stats(item_resource.calculate_stats(quality), rank)

## Retorna la calidad como porcentaje (0-100)
func get_quality_percent() -> int:
	return roundi(quality * 100.0)

## Retorna el tier de rareza según umbrales de calidad
func get_quality_tier() -> String:
	var percent = get_quality_percent()
	if percent >= 99:
		return "legendary"  # Naranja (99-100%)
	elif percent >= 90:
		return "epic"  # Morado (90-98%)
	elif percent >= 70:
		return "rare"  # Azul (70-89%)
	elif percent >= 40:
		return "uncommon"  # Verde (40-69%)
	else:
		return "common"  # Blanco (0-39%)

## Retorna color de outline según tier (mismos tonos que el equipo dibujado en el héroe)
func get_quality_color() -> Color:
	match get_quality_tier():
		"legendary":
			return Color("ffa629")  # naranja
		"epic":
			return Color("b46bff")  # morado
		"rare":
			return Color("4ea3ff")  # azul
		"uncommon":
			return Color("6ad16a")  # verde
		_:
			return Color("cfd6dc")  # acero

## Nombre de la calidad en el idioma del jugador: los mismos nombres y en el mismo orden que
## CraftResultScreen.TIERS (BÁSICO … LEGENDARIO), traducidos con locale/textos.csv.
func get_quality_label() -> String:
	match get_quality_tier():
		"legendary":
			return tr("LEGENDARIO")
		"epic":
			return tr("ÉPICO")
		"rare":
			return tr("RARO")
		"uncommon":
			return tr("BUENO")
		_:
			return tr("BÁSICO")

func get_sell_price() -> int:
	return roundi(SELL_PRICE_BY_TIER.get(get_quality_tier(), 25) * Ranks.gold_mult(rank))

## Nombre del objeto con su rango y su calidad, en el idioma del jugador ("Espada maestra III (93%)")
func get_display_name() -> String:
	if item_resource:
		return "%s (%d%%)" % [get_name_with_rank(), get_quality_percent()]
	return tr("Objeto desconocido")

## Nombre con el numeral del rango, ya traducido: "Espada maestra III" (sin numeral en el rango I).
func get_name_with_rank() -> String:
	if item_resource == null:
		return tr("Objeto desconocido")
	return tr(item_resource.display_name) + Ranks.suffix(rank)

## Retorna el slot de equipamiento
func get_equipment_slot() -> String:
	if item_resource:
		return item_resource.equipment_slot
	return ""

## Retorna el tipo de item
func get_item_type() -> String:
	if item_resource:
		return item_resource.item_type
	return ""

## Retorna el icono del item
func get_icon() -> Texture2D:
	if item_resource:
		return item_resource.get_icon()
	return null

## Serialización para inventario persistente
func to_dict() -> Dictionary:
	return {
		"item_id": String(item_resource.item_id) if item_resource else "",
		"quality": quality,
		"stats": calculated_stats.duplicate(),
		"timestamp": crafted_timestamp,
		"rank": rank,
		"place": String(place),
		"x": cell.x,
		"y": cell.y,
		"rot": rot,
		"aristas": aristas.map(func(a): return [a.x, a.y]),
	}

## Deserialización desde diccionario
static func from_dict(data: Dictionary, item_res: ItemResource) -> CraftedItem:
	var item = CraftedItem.new(item_res, data.get("quality", 0.5), maxi(1, int(data.get("rank", 1))))
	item.calculated_stats = data.get("stats", {}).duplicate()
	item.crafted_timestamp = data.get("timestamp", 0)
	item.place = StringName(data.get("place", "loot"))
	item.cell = Vector2i(int(data.get("x", 0)), int(data.get("y", 0)))
	item.rot = posmod(int(data.get("rot", 0)), 4)
	var ar: Array[Vector2i] = []
	for pair in data.get("aristas", []):
		if pair is Array and pair.size() == 2:
			ar.append(Vector2i(int(pair[0]), int(pair[1])))
	item.aristas = ar
	return item
